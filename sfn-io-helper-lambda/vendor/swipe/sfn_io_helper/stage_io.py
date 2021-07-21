import os
import re
import json
import logging
import signal

from botocore import xform_name

from . import s3_object

logger = logging.getLogger()


def get_input_uri_key(stage):
    return f"{xform_name(stage).upper()}_INPUT_URI"


def get_output_uri_key(stage):
    return f"{xform_name(stage).upper()}_OUTPUT_URI"


def get_stage_input(sfn_state, stage):
    input_uri = sfn_state[get_input_uri_key(stage)]
    return json.loads(s3_object(input_uri).get()["Body"].read().decode())


def put_stage_input(sfn_state, stage, stage_input):
    input_uri = sfn_state[get_input_uri_key(stage)]
    s3_object(input_uri).put(Body=json.dumps(stage_input).encode())


def get_stage_output(sfn_state, stage):
    output_uri = sfn_state[get_output_uri_key(stage)]
    return json.loads(s3_object(output_uri).get()["Body"].read().decode())


def read_state_from_s3(sfn_state, current_state):
    stage = current_state.replace("ReadOutput", "")
    sfn_state.setdefault("Result", {})
    stage_output = get_stage_output(sfn_state, stage)

    # Extract Batch job error, if any, and drop error metadata to avoid overrunning the Step Functions state size limit
    batch_job_error = sfn_state.pop("BatchJobError", {})
    # If the stage succeeded, don't throw an error
    if not sfn_state.get("BatchJobDetails", {}).get(stage):
        if batch_job_error and next(iter(batch_job_error)).startswith(stage):
            error_type = type(stage_output["error"], (Exception,), dict())
            raise error_type(stage_output["cause"])

    sfn_state["Result"].update(stage_output)

    return sfn_state


def trim_batch_job_details(sfn_state):
    """
    Remove large redundant batch job description items from Step Function state to avoid overrunning the Step Functions
    state size limit.
    """
    for job_details in sfn_state["BatchJobDetails"].values():
        job_details["Attempts"] = []
        job_details["Container"] = {}
    return sfn_state


def get_workflow_name(sfn_state):
    for k, v in sfn_state.items():
        if k.endswith("_WDL_URI"):
            return os.path.splitext(os.path.basename(s3_object(v).key))[0]


def preprocess_sfn_input(sfn_state, aws_region, aws_account_id, state_machine_name):
    # TODO: add input validation assertions here (use JSON schema?)
    assert sfn_state["OutputPrefix"].startswith("s3://")
    output_prefix = sfn_state["OutputPrefix"]
    output_path = os.path.join(output_prefix, re.sub(r"v(\d+)\..+", r"\1", get_workflow_name(sfn_state)))
    stages = ["Run"]
    for stage in stages:
        sfn_state[get_input_uri_key(stage)] = os.path.join(output_path, f"{xform_name(stage)}_input.json")
        sfn_state[get_output_uri_key(stage)] = os.path.join(output_path, f"{xform_name(stage)}_output.json")
        for compute_env in "SPOT", "EC2":
            memory_key = stage + compute_env + "Memory"
            sfn_state.setdefault(memory_key, int(os.environ[memory_key + "Default"]))
        stage_input = sfn_state["Input"].get(stage, {})
        ecr_repo = f"{aws_account_id}.dkr.ecr.{aws_region}.amazonaws.com"
        if "docker_image_id" not in stage_input:
            workflow_name, workflow_version = get_workflow_name(sfn_state).rsplit("-v", 1)
            default_docker_image_id = f"{ecr_repo}/swipe-{workflow_name}:v{workflow_version}"
            stage_input["docker_image_id"] = default_docker_image_id
        put_stage_input(sfn_state=sfn_state, stage=stage, stage_input=stage_input)
    return sfn_state
