import os
import json
import time
import threading
import re
import urllib.parse
from typing import Dict, Any

import boto3

from WDL._util import StructuredLogMessage as _


# environment variables to be passed through from miniwdl runner environment to task containers
PASSTHROUGH_ENV_VARS = (
    "AWS_DEFAULT_REGION",
    "DEPLOYMENT_ENVIRONMENT",
    "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI",
)

s3 = boto3.resource("s3")


def s3_object(uri):
    assert uri.startswith("s3://")
    bucket, key = uri.split("/", 3)[2:]
    return s3.Bucket(bucket).Object(key)


def task(cfg, logger, run_id, run_dir, task, **recv):
    t_0 = time.time()

    s3_wd_uri = recv["inputs"].get("s3_wd_uri", None)
    if s3_wd_uri and s3_wd_uri.value:
        s3_wd_uri = s3_wd_uri.value
        update_status_json(
            logger,
            task,
            run_id,
            s3_wd_uri,
            {"status": "running", "start_time": time.time()},
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

    # pass through certain environment variables expected by idseq-dag
    recv["container"].create_service_kwargs = {
        "env": [f"{var}={os.environ[var]}" for var in PASSTHROUGH_ENV_VARS if var in os.environ],
    }

    if "AWS_ENDPOINT_URL" in os.environ:
        network = urllib.parse.urlparse(os.environ["AWS_ENDPOINT_URL"]).hostname
        recv["container"].create_service_kwargs["networks"] = [network]
        recv["container"].create_service_kwargs["env"].append(f"AWS_ENDPOINT_URL={os.environ['AWS_ENDPOINT_URL']}")
        recv["container"].create_service_kwargs["env"].append(f"S3PARCP_S3_URL={os.environ['AWS_ENDPOINT_URL']}")

    # inject command to log `aws sts get-caller-identity` to confirm AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
    # is passed through & effective
    if not run_id[-1].startswith("download-"):
        recv["command"] = (
            """aws sts get-caller-identity | jq -c '. + {message: "aws sts get-caller-identity"}' 1>&2\n\n"""
            + recv["command"]
        )

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
                msg = last_stderr_json.get("cause", last_stderr_json["wdl_error_message"])
                if last_stderr_json.get("error", None) == "InvalidInputFileError":
                    status = dict(status="user_errored")
                if "step_description_md" in last_stderr_json:
                    status.update(description=last_stderr_json["step_description_md"])
            status.update(error=msg, end_time=time.time())
            update_status_json(
                logger,
                task,
                run_id,
                s3_wd_uri,
                status
            )
        raise

    if s3_wd_uri:
        status = {
            "status": "uploaded",
            "end_time": time.time(),
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
        # Figure out workflow and step names:
        # e.g. run_ids = ["host_filter", "call-validate_input"]
        workflow_name = run_ids[0]
        if workflow_name in (
            "czid_host_filter",
            "czid_non_host_alignment",
            "czid_postprocess",
            "czid_experimental",
        ):
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
                status = _status_json.setdefault(step_name, {})
                for k, v in entries.items():
                    status[k] = v

                # Upload it
                logger.verbose(
                    _("update_status_json", step_name=step_name, status=status)
                )
                status_uri = os.path.join(s3_wd_uri, f"{workflow_name}_status2.json")
                s3_object(status_uri).put(Body=json.dumps(_status_json).encode())
    except Exception as exn:
        logger.error(
            _("update_status_json failed", error=str(exn), s3_wd_uri=s3_wd_uri, run_ids=run_ids)
        )
        # Don't allow mere inability to update status to crash the whole workflow.
