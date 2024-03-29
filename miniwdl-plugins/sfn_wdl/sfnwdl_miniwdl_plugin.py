import json
import os
import re
import threading
import time
from typing import Any, Dict

import boto3
import botocore
from WDL._util import StructuredLogMessage as _
from WDL.runtime import config

s3 = boto3.resource("s3", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))


def s3_object(uri):
    assert uri.startswith("s3://")
    bucket, key = uri.split("/", 3)[2:]
    return s3.Bucket(bucket).Object(key)


def get_s3_put_prefix(cfg: config.Loader) -> str:
    s3prefix = cfg["s3_progressive_upload"]["uri_prefix"]
    assert s3prefix.startswith("s3://"), "MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX invalid"
    return s3prefix


def task(cfg, logger, run_id, run_dir, task, **recv):
    t_0 = time.time()

    s3_wd_uri = get_s3_put_prefix(cfg)
    update_status_json(
        logger,
        task,
        run_id,
        s3_wd_uri,
        {"status": "running", "start_time": str(time.time())},
    )

    # First yield point -- through which we'll get the task inputs. Also, the 'task' object is a
    # WDL.Task through which we have access to the full AST of the task source code.
    #   https://miniwdl.readthedocs.io/en/latest/WDL.html#WDL.Tree.Task
    # pending proper documentation for this interface, see the detailed comments in this example:
    #   https://github.com/chanzuckerberg/miniwdl/blob/main/examples/plugin_task_omnibus/miniwdl_task_omnibus_example.py
    recv = yield recv

    # provide a callback for stderr log messages that attempts to parse them as JSON and pass them
    # on in structured form
    stderr_logger = logger.getChild("stderr")
    last_stderr_json = None

    def stderr_callback(line):
        nonlocal last_stderr_json
        line2 = line.strip()
        parsed = False
        if line2.startswith("{") and line2.endswith("}"):
            try:
                d = json.loads(line)
                assert isinstance(d, dict)
                msg = ""
                if "message" in d:
                    msg = d["message"]
                    del d["message"]
                elif "msg" in d:
                    msg = d["msg"]
                    del d["msg"]
                stderr_logger.verbose(_(msg.strip(), **d))
                last_stderr_json = d
                parsed = True
            except Exception:
                pass
        if not parsed:
            stderr_logger.verbose(line.rstrip())

    recv["container"].stderr_callback = stderr_callback

    try:
        recv = yield recv

        # After task completion -- logging elapsed time in structured form, to be picked up by
        # CloudWatch Logs. We also have access to the task outputs in recv.
        t_elapsed = time.time() - t_0
        logger.notice(
            _(
                "SFN-WDL task done",
                run_id=run_id[-1],
                task_name=task.name,
                elapsed_seconds=round(t_elapsed, 3),
            )
        )
    except Exception as exn:
        if s3_wd_uri:
            # read the error message to determine status user_errored or pipeline_errored
            status = dict(status="pipeline_errored")
            msg = str(exn)
            if last_stderr_json and "wdl_error_message" in last_stderr_json:
                msg = last_stderr_json.get(
                    "cause", last_stderr_json["wdl_error_message"]
                )
                if last_stderr_json.get("error", None) == "InvalidInputFileError":
                    status = dict(status="user_errored")
                if "step_description_md" in last_stderr_json:
                    status.update(description=last_stderr_json["step_description_md"])
            status.update(error=msg, end_time=str(time.time()))
            update_status_json(logger, task, run_id, s3_wd_uri, status)
        raise

    if s3_wd_uri:
        status = {
            "status": "uploaded",
            "end_time": str(time.time()),
        }
        if "step_description_md" in recv["outputs"]:
            # idseq_dag steps may dynamically generate their description to reflect different
            # behaviors based on the input. The WDL tasks output this as a String value.
            status["description"] = recv["outputs"]["step_description_md"].value
        update_status_json(logger, task, run_id, s3_wd_uri, status)

    # do nothing with outputs
    yield recv


_status_json: Dict[str, Any] = {}
_status_json_lock = threading.Lock()


def update_status_json(logger, task, run_ids, s3_wd_uri, entries):
    """
    Post short-read-mngs workflow status JSON files to the output S3 bucket. These status files
    were originally created by idseq-dag, used to display pipeline progress in the IDseq webapp.
    We update it at the beginning and end of each task (carefully, because some tasks run
    concurrently).
    """
    global _status_json, _status_json_lock

    if not s3_wd_uri:
        return

    try:
        if os.getenv("OUTPUT_STATUS_JSON_FILES") == "true":
            # Figure out workflow and step names:
            # e.g. run_ids = ["host_filter", "call-validate_input"]
            workflow_name = run_ids[0]
            workflow_name = "_".join(workflow_name.split("_")[1:])
            # parse --step-name from the task command template. For historical reasons, the status JSON
            # keys use this name and it's not the same as the WDL task name.
            step_name = task.name  # use WDL task name as default
            step_name_re = re.compile(r"--step-name\s+(\S+)\s")
            for part in task.command.parts:
                m = step_name_re.search(part) if isinstance(part, str) else None
                if m:
                    step_name = m.group(1)
            assert step_name, "reading --step-name from task command"

            # Update _status_json which is accumulating over the course of workflow execution.
            with _status_json_lock:
                status_uri = os.path.join(s3_wd_uri, f"{workflow_name}_status2.json")

                # If the run is being resumed via call caching _status_json will be empty even
                #   though we should have step statuses. We need to populate it before
                #   updating or we will overwrite previous steps.
                #   This check will happen at the beginning of every run, whether or not it is
                #   resumed. If there was no previous run then the object won't be found and
                #   we do nothing
                if not _status_json:
                    try:
                        # Populate _status_json with the existing status_json
                        _status_json = json.loads(s3_object(status_uri).get().get()["Body"])
                    except botocore.exceptions.ClientError as e:
                        # If the error is not 404 it was something other than the object
                        #   not existing, so we want to raise it.
                        if e.response['Error']['Code'] != "NoSuchKey":
                            raise e

                status = _status_json.setdefault(step_name, {})
                for k, v in entries.items():
                    status[k] = v

                # Upload it
                logger.verbose(
                    _("update_status_json", step_name=step_name, status=status)
                )
                s3_object(status_uri).put(Body=json.dumps(_status_json).encode())
    except Exception as exn:
        logger.error(
            _(
                "update_status_json failed",
                error=str(exn),
                s3_wd_uri=s3_wd_uri,
                run_ids=run_ids,
            )
        )
        # Don't allow mere inability to update status to crash the whole workflow.
