"""
Plugin for uploading output files to S3 "progressively," meaning to upload each task's output files
immediately upon task completion, instead of waiting for the whole workflow to finish. (The latter
technique, which doesn't need a plugin at all, is illustrated in ../upload_output_files.sh)
To enable, install this plugin (`pip3 install .` & confirm listed by `miniwdl --version`) and set
the environment variable MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX to a S3 URI prefix under which
to store the output files (e.g. "s3://my_bucket/workflow123_outputs"). The prefix should be set
uniquely for each run, to prevent different runs from overwriting each others' outputs.
Shells out to s3parcp, for which the environment must be set up to authorize upload to the
specified bucket (without explicit auth-related arguments).
Deposits into each successful task/workflow run directory and S3 folder, an additional file
outputs.s3.json which copies outputs.json replacing local file paths with the uploaded S3 URIs.
(The JSON printed to miniwdl standard output keeps local paths.)
Limitations:
1) All task output files are uploaded, even ones that aren't top-level workflow outputs. (We can't,
   at the moment of task completion, necessarily predict which files the calling workflow will
   finally output.)
2) Doesn't upload (or rewrite outputs JSON for) workflow output files that weren't generated by a
   task, e.g. outputting an input file, or a file generated by write_lines() etc. in the workflow.
   (We could handle such stragglers by uploading them at workflow completion; it just hasn't been
   needed yet.)
"""

import os
import re
import subprocess
import threading
import json
import logging
import time
import random
from pathlib import Path
from urllib.parse import urlparse
from typing import Callable, Dict, Optional, Tuple, Union
from uuid import uuid4

import WDL
from WDL import Env, Value, values_to_json
from WDL import Type
from WDL.runtime import cache, config
from WDL._util import StructuredLogMessage as _
from WDL.runtime.backend.docker_swarm import SwarmContainer
from WDL.runtime.error import Terminated

import boto3
import botocore
from botocore.config import Config

s3 = boto3.resource("s3", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
s3_client = boto3.client("s3", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
cloudwatch_logs_client = boto3.client("logs")


batch_config = Config(
    retries={
        "max_attempts": 20,
        "mode": "adaptive",
    }
)
batch_client = boto3.client("batch", config=batch_config)

def s3_object(uri: str):
    assert uri.startswith("s3://")
    bucket, key = uri.split("/", 3)[2:]
    return s3.Bucket(bucket).Object(key)


def get_s3_put_prefix(cfg: config.Loader) -> str:
    s3prefix = cfg["s3_progressive_upload"]["uri_prefix"]
    assert s3prefix.startswith("s3://"), "MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX invalid"
    return s3prefix


def get_s3_get_prefix(cfg: config.Loader) -> str:
    if not cfg.has_option("s3_progressive_upload", "call_cache_get_uri_prefix"):
        return get_s3_put_prefix(cfg)
    s3prefix = cfg["s3_progressive_upload"].get("call_cache_get_uri_prefix")
    assert s3prefix.startswith("s3://"), "MINIWDL__S3_PROGRESSIVE_UPLOAD__CALL_CACHE_GET_URI_PREFIX invalid"
    return s3prefix


def flag_temporary(s3uri):
    uri = urlparse(s3uri)
    bucket, key = uri.hostname, uri.path[1:]
    try:
        s3_client.put_object_tagging(
            Bucket=bucket,
            Key=key,
            Tagging={
                'TagSet': [
                    {
                        'Key': 'intermediate_output',
                        'Value': 'true'
                    },
                ]
            },
        )
    except botocore.exceptions.ClientError:
        # If we get throttled better not to tag the file at all
        pass


def remove_temporary_flag(s3uri, retry=0):
    """ Remove temporary flag from s3 if in outputs.json """
    uri = urlparse(s3uri)
    bucket, key = uri.hostname, uri.path[1:]
    tags = s3_client.get_object_tagging(
        Bucket=bucket,
        Key=key,
    )
    remaining_tags = []
    for tag in tags["TagSet"]:
        if not (tag["Key"] == "intermediate_output" and tag["Value"] == "true"):
            remaining_tags.append(tag)
    try:
        if remaining_tags:
            s3_client.put_object_tagging(
                Bucket=bucket,
                Key=key,
                Tagging={
                    'TagSet': remaining_tags
                },
            )
        elif len(tags["TagSet"]) > 0:  # Delete tags if they exist
            s3_client.delete_object_tagging(
                Bucket=bucket,
                Key=key,
            )
    except botocore.exceptions.ClientError as e:
        if retry > 3:
            raise e
        print(f"Error deleting tags for object {key} in bucket {bucket}: {e}")
        delay = 20 + random.randint(0, 10)
        print(f"Retrying in {delay} seconds...")
        time.sleep(delay)
        remove_temporary_flag(s3uri, retry+1)


def inode(link: str):
    if re.match(r'^\w+://', link):
        return link
    st = os.stat(os.path.realpath(link))
    return (st.st_dev, st.st_ino)


_uploaded_files: Dict[Tuple[int, int], str] = {}
_cached_files: Dict[Tuple[int, int], Tuple[str, Env.Bindings[Value.Base]]] = {}
_key_inputs: Dict[str, Env.Bindings[Value.Base]] = {}
_uploaded_files_lock = threading.Lock()
_saved_inputs = {}
_inputs_lock = threading.Lock()

def cache_put(cfg: config.Loader, logger: logging.Logger, key: str, outputs: Env.Bindings[Value.Base]):
    if not (cfg["call_cache"].get_bool("put") and
            cfg["call_cache"]["backend"] == "s3_progressive_upload_call_cache_backend"):
        return

    missing = False

    def cache(v: Union[Value.File, Value.Directory]) -> str:
        nonlocal missing
        missing = missing or inode(str(v.value)) not in _uploaded_files
        if missing:
            return ""
        return _uploaded_files[inode(str(v.value))]

    remapped_outputs = Value.rewrite_env_paths(outputs, cache)

    input_digest = Value.digest_env(
        Value.rewrite_env_paths(
            _key_inputs[key], lambda v: _uploaded_files.get(inode(str(v.value)), str(v.value))
        )
    )
    key_parts = key.split('/')
    key_parts[-1] = input_digest
    s3_cache_key = "/".join(key_parts)

    if not missing and cfg.has_option("s3_progressive_upload", "uri_prefix"):
        uri = os.path.join(get_s3_put_prefix(cfg), "cache", f"{s3_cache_key}.json")
        s3_object(uri).put(Body=json.dumps(values_to_json(remapped_outputs)).encode())
        flag_temporary(uri)
        logger.info(_("call cache insert", cache_file=uri))


class CallCache(cache.CallCache):
    def get(
        self, key: str, inputs: Env.Bindings[Value.Base], output_types: Env.Bindings[Type.Base]
    ) -> Optional[Env.Bindings[Value.Base]]:
        # HACK: in order to back the call cache in S3 we need to cache the S3 paths to the outputs.
        #   If we get a cache hit, those S3 paths will be passed to the next step. However,
        #   the cache key is computed using local inputs so this results in a cache miss.
        #   we need `put` to use a key based on S3 paths instead but put doesn't have access to step
        #   inputs. 'put' should always be run after a `get` is called so here we are storing the
        #   inputs based on the cache key so `put` can get the inputs.
        global _key_inputs
        _key_inputs[key] = inputs

        if not self._cfg.has_option("s3_progressive_upload", "uri_prefix"):
            return super().get(key, inputs, output_types)
        uri = urlparse(get_s3_get_prefix(self._cfg))
        bucket, prefix = uri.hostname, uri.path

        s3_key = os.path.join(prefix, "cache", f"{key}.json")[1:]
        abs_fn = os.path.join(self._cfg["call_cache"]["dir"], f"{key}.json")
        Path(abs_fn).parent.mkdir(parents=True, exist_ok=True)
        try:
            s3_client.download_file(bucket, s3_key, abs_fn)
        except botocore.exceptions.ClientError as e:
            if e.response['Error']['Code'] != "404":
                raise e

        return super().get(key, inputs, output_types)

    def put(self, key: str, outputs: Env.Bindings[Value.Base]) -> None:
        if not self._cfg["call_cache"].get_bool("put"):
            return

        def cache(v: Union[Value.File, Value.Directory]) -> str:
            _cached_files[inode(v.value)] = (key, outputs)
            return ""

        with _uploaded_files_lock:
            Value.rewrite_env_paths(outputs, cache)
            cache_put(self._cfg, self._logger, key, outputs)


def task(cfg, logger, run_id, run_dir, task, **recv):
    """
    on completion of any task, upload its output files to S3, and record the S3 URI corresponding
    to each local file (keyed by inode) in _uploaded_files
    """
    logger = logger.getChild("s3_progressive_upload")
    inputs_json = WDL.values_to_json(recv['inputs'])
    with _inputs_lock:
        _saved_inputs[run_id[-1]] = inputs_json
    # ignore inputs
    recv = yield recv
    # ignore command/runtime/container
    recv = yield recv

    def upload_file(abs_fn, s3uri, flag_temporary_file=False):
        s3cp(logger, abs_fn, s3uri, flag_temporary_file=flag_temporary_file)
        # record in _uploaded_files (keyed by inode, so that it can be found from any
        # symlink or hardlink)
        with _uploaded_files_lock:
            _uploaded_files[inode(abs_fn)] = s3uri
            if inode(abs_fn) in _cached_files:
                cache_put(cfg, logger, *_cached_files[inode(abs_fn)])
        logger.info(_("task output uploaded", file=abs_fn, uri=s3uri))

    if not cfg.has_option("s3_progressive_upload", "uri_prefix"):
        logger.debug("skipping because MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX is unset")
        yield recv
        return

    if run_id[-1].startswith("download-"):
        yield recv
        return

    s3prefix = get_s3_put_prefix(cfg)

    # for each file under out
    def _raise(ex):
        raise ex

    links_dir = os.path.join(run_dir, "out")
    for output in os.listdir(links_dir):
        abs_output = os.path.join(links_dir, output)
        assert os.path.isdir(abs_output)
        output_contents = [os.path.join(abs_output, fn) for fn in os.listdir(abs_output) if not fn.startswith(".")]
        assert output_contents
        if len(output_contents) == 1 and os.path.isdir(output_contents[0]) and os.path.islink(output_contents[0]):
            # directory output
            _uploaded_files[inode(output_contents[0])] = (
                os.path.join(s3prefix, os.path.basename(output_contents[0])) + "/"
            )
            for (dn, subdirs, files) in os.walk(output_contents[0], onerror=_raise):
                assert dn == output_contents[0] or dn.startswith(output_contents[0] + "/"), dn
                for fn in files:
                    abs_fn = os.path.join(dn, fn)
                    s3uri = os.path.join(s3prefix, os.path.relpath(abs_fn, abs_output))
                    upload_file(abs_fn, s3uri, flag_temporary_file=False)
        elif len(output_contents) == 1 and os.path.isfile(output_contents[0]):
            # file output
            basename = os.path.basename(output_contents[0])
            abs_fn = os.path.join(abs_output, basename)
            s3uri = os.path.join(s3prefix, basename)
            upload_file(abs_fn, s3uri, flag_temporary_file=True)
        else:
            # file array output
            assert all(os.path.basename(abs_fn).isdigit() for abs_fn in output_contents), output_contents
            for index_dir in output_contents:
                fns = [fn for fn in os.listdir(index_dir) if not fn.startswith(".")]
                assert len(fns) == 1
                abs_fn = os.path.join(index_dir, fns[0])
                s3uri = os.path.join(s3prefix, fns[0])
                upload_file(abs_fn, s3uri, flag_temporary_file=False)
    yield recv


def workflow(cfg, logger, run_id, run_dir, workflow, **recv):
    """
    on workflow completion, add a file outputs.s3.json to the run directory, which is outputs.json
    with local filenames rewritten to the uploaded S3 URIs (as previously recorded on completion of
    each task).
    """
    logger = logger.getChild("s3_progressive_upload")

    # ignore inputs
    recv = yield recv

    if cfg.has_option("s3_progressive_upload", "uri_prefix"):
        # write outputs.s3.json using _uploaded_files
        write_outputs_s3_json(
            logger,
            recv["outputs"],
            run_dir,
            os.path.join(get_s3_put_prefix(cfg), *run_id[1:]),
            workflow.name,
        )

    yield recv


def write_outputs_s3_json(logger, outputs, run_dir, s3prefix, namespace):
    # write to outputs.s3.json
    fn = os.path.join(run_dir, "outputs.s3.json")

    # rewrite uploaded files to their S3 URIs
    def rewriter(fd):
        if fd.value.startswith("s3://"):
            return fd.value

        try:
            return _uploaded_files[inode(fd.value)]
        except Exception:
            logger.warning(
                _(
                    "output file or directory wasn't uploaded to S3; keeping local path in outputs.s3.json",
                    path=fd.value,
                )
            )
            return fd.value

    with _uploaded_files_lock:
        outputs_s3 = WDL.Value.rewrite_env_paths(outputs, rewriter)

    # get json dict of rewritten outputs
    outputs_s3_json = WDL.values_to_json(outputs_s3, namespace=namespace)

    with open(fn, "w") as outfile:
        json.dump(outputs_s3_json, outfile, indent=2)
        outfile.write("\n")

    for output_file in outputs_s3_json.values():
        if isinstance(output_file, list):
            for filename in output_file:
                remove_temporary_flag(filename)
        elif output_file and output_file.startswith("s3://"):
            remove_temporary_flag(output_file)

    s3cp(
        logger,
        fn,
        os.environ.get("WDL_OUTPUT_URI", os.path.join(s3prefix, "outputs.s3.json")),
        flag_temporary_file=False
    )


_s3parcp_lock = threading.Lock()


def s3cp(logger, fn, s3uri, flag_temporary_file=False):
    with _s3parcp_lock:
        # when uploading many small outputs from the same pipeline you end up with a
        #   quick intense burst of load that can bump into the S3 rate limit
        #   allowing more retries should overcome this
        cmd = ["s3parcp", "--checksum", "--max-retries", "10", fn, s3uri]
        logger.debug(" ".join(cmd))
        rslt = subprocess.run(cmd, stderr=subprocess.PIPE)
        if rslt.returncode != 0:
            logger.error(
                _(
                    "failed uploading output file",
                    cmd=" ".join(cmd),
                    exit_status=rslt.returncode,
                    stderr=rslt.stderr.decode("utf-8"),
                )
            )
            raise WDL.Error.RuntimeError("failed: " + " ".join(cmd))
        if flag_temporary_file:
            flag_temporary(s3uri)


def cloudwatch_logs(log_group_name, log_stream_name):
    next_page_key = "nextForwardToken"
    next_page_token = None
    page = None
    get_args = dict(
        logGroupName=log_group_name,
        logStreamName=log_stream_name,
        limit=10000,
        startFromHead=True,
    )
    if next_page_token:
        get_args["nextToken"] = next_page_token
    while True:
        page = cloudwatch_logs_client.get_log_events(**get_args)
        for event in page["events"]:
            if "timestamp" in event and "message" in event:
                yield event['message']
        get_args["nextToken"] = page[next_page_key]
        if len(page["events"]) == 0:
            break
    if page:
        next_page_token = page[next_page_key]


class HybridBatch(SwarmContainer):
    @classmethod
    def global_init(cls, cfg: config.Loader, logger: logging.Logger) -> None:
        cls.s3_prefix = get_s3_get_prefix(cfg)
        cls.job_definition = cfg["s3_progressive_upload"]["batch_job_definition"]
        cls.batch_queues = json.loads(cfg["s3_progressive_upload"]["batch_queues"])
        return super().global_init(cfg, logger)

    def _run(self, logger: logging.Logger, terminating: Callable[[], bool], command: str) -> int:
        # example run_id: call-say_hello-1
        task_name = re.search(r'call-([^-]+)(-\d+)?$', self.run_id).group(1)
        chunk_number_match = re.search(r'-\d+$', self.run_id)
        chunk_number = int(chunk_number_match.group()[1:]) if chunk_number_match else None

        if task_name not in self.batch_queues:
            return super()._run(logger, terminating, command)

        memory = self.runtime_values.get("memory", 130816)
        cpu = self.runtime_values.get("cpu", 4)
        max_retries = self.runtime_values.get("maxRetries", 3)

        wdl_input_uri = os.path.join(self.s3_prefix, task_name, f"{self.run_id}-input.json")
        wdl_output_uri = os.path.join(self.s3_prefix, task_name, f"{self.run_id}-output.json")

        s3_object(wdl_input_uri).put(Body=json.dumps(_saved_inputs[self.run_id]).encode())

        # stdout not supported
        with open("stdout.txt", "w"):
            pass

        environment = {
            "WDL_WORKFLOW_URI": os.getenv("WDL_WORKFLOW_URI"),
            "WDL_INPUT_URI": wdl_input_uri,
            "WDL_OUTPUT_URI": wdl_output_uri,
            "SFN_EXECUTION_ID": os.getenv("SFN_EXECUTION_ID"),
            "SFN_CURRENT_STATE": os.getenv("SFN_CURRENT_STATE"),
            "TASK": task_name,
        }

        response = batch_client.submit_job(
            jobName=str(uuid4()),
            jobQueue=self.batch_queues[task_name],
            jobDefinition=self.job_definition,
            containerOverrides={
                "environment": [{"name": k, "value": v} for k, v in environment.items()],
                "memory": memory,
                "vcpus": cpu,
            },
            retryStrategy={"attempts": max_retries},
        )
        job_id = response["jobId"]
        last_status, job_done = None, False
        while True:
            if terminating():
                batch_client.terminate_job(
                    jobId=job_id,
                    reason="Job termination requested",
                )
                raise Terminated(quiet=False)
            job_desc = batch_client.describe_jobs(jobs=[job_id])["jobs"][0]
            if job_desc["status"] != last_status:
                logger.info("Job %s %s", job_id, job_desc["status"])
                last_status = job_desc["status"]
                if job_desc["status"] in {"RUNNING", "SUCCEEDED", "FAILED"}:
                    logger.info("Job %s log stream: %s", job_id, job_desc.get("container", {}).get("logStreamName"))
            container_desc = job_desc.get("container", {})
            if job_desc["status"] in {"RUNNING", "SUCCEEDED", "FAILED"}:
                try:
                    log_group_name = container_desc["logConfiguration"]["options"]["awslogs-group"]
                except KeyError:
                    log_group_name = "/aws/batch/job"
                if "logStreamName" in job_desc.get("container", {}):
                    log_stream_name = job_desc["container"]["logStreamName"]

                    with open("stdout.txt", "a") as f:
                        for event in cloudwatch_logs(log_group_name, log_stream_name):
                            self.stderr_callback(event)
                            f.write(event + "\n")
            if "statusReason" in job_desc:
                logger.info("Job %s: %s", job_id, job_desc["statusReason"])
            # When a job is finished, we do one last iteration to read any log lines that were still being delivered.
            if job_done:
                if job_desc.get("container", {}).get("exitCode"):
                    return job_desc["container"]["exitCode"]
                elif last_status == "FAILED":
                    return -1
                return 1
            if last_status in {"SUCCEEDED", "FAILED"}:
                job_done = True
            time.sleep(random.uniform(1.0, 2.0))
