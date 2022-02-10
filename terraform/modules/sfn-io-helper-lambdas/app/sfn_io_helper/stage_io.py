import os
import re
import json
import logging
from typing import List
from datetime import datetime
from uuid import uuid4

from botocore import xform_name

from . import s3_object, sqs

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
            raise error_type(stage_output.get("cause", stage_output.get("message")))

    sfn_state["Result"].update(stage_output)

    return sfn_state


def trim_batch_job_details(sfn_state):
    """
    Remove large redundant batch job description items from Step Function state to avoid overrunning the Step Functions
    state size limit.
    """
    sfn_state["BatchJobDetails"] = {k: {} for k in sfn_state["BatchJobDetails"]}
    return sfn_state


def segment_path(path: str) -> List[str]:
    _path = path
    segments: List[str] = []
    while _path:
        _path, segment = os.path.split(_path)
        segments.insert(0, segment)
    return segments


def get_workflow_name(sfn_state):
    for k, v in sfn_state.items():
        if k.endswith("_WDL_URI"):
            segments = [s for s in segment_path(v) if re.match(r".*-v(\d+)", s)]
            name = segments[0] if segments else os.path.basename(v)
            return os.path.splitext(name)[0]


def link_outputs(sfn_state):
    if len(list(sfn_state["Input"])) == 0:
        return

    stages_json_uri = sfn_state.get("STAGES_IO_MAP_JSON")
    stage_io_dict = {}
    if stages_json_uri:
        stage_io_dict = json.loads(s3_object(stages_json_uri).get()["Body"].read().decode())

    stripped_result = {k.split(".")[1]: v for k, v in sfn_state.get("Result", {}).items()}

    for stage in sfn_state["Input"].keys():
        stage_input = sfn_state["Input"][stage]
        for input_name, source in stage_io_dict.get(stage, {}).items():
            if isinstance(source, list):
                stage_input[input_name] = sfn_state["Input"].get(source[0], {}).get(source[1])
            elif source in sfn_state.get("Result", {}):
                stage_input[input_name] = stripped_result[source]
        put_stage_input(sfn_state=sfn_state, stage=stage, stage_input=stage_input)


def preprocess_sfn_input(sfn_state, aws_region, aws_account_id, state_machine_name):
    # TODO: add input validation assertions here (use JSON schema?)
    assert sfn_state["OutputPrefix"].startswith("s3://")
    output_prefix = sfn_state["OutputPrefix"]
    output_path = os.path.join(output_prefix, re.sub(r"v(\d+)\..+", r"\1", get_workflow_name(sfn_state)))

    for stage in sfn_state["Input"].keys():
        sfn_state[get_input_uri_key(stage)] = os.path.join(output_path, f"{xform_name(stage)}_input.json")
        sfn_state[get_output_uri_key(stage)] = os.path.join(output_path, f"{xform_name(stage)}_output.json")
        for compute_env in "SPOT", "EC2":
            memory_key = stage + compute_env + "Memory"
            memory_default_key = memory_key + "Default"
            if memory_default_key in os.environ:
                sfn_state.setdefault(memory_key, int(os.environ[memory_default_key]))
            vcpu_key = stage + compute_env + "Vcpu"
            vcpu_default_key = vcpu_key + "Default"
            if vcpu_default_key in os.environ:
                sfn_state.setdefault(vcpu_key, int(os.environ[vcpu_key + "Default"]))

    link_outputs(sfn_state)

    return sfn_state


def broadcast_stage_complete(execution_id: str, stage: str):
    if "SQS_QUEUE_URLS" not in os.environ:
        return

    sqs_queue_urls = os.environ["SQS_QUEUE_URLS"].split(",")

    assert len(execution_id.split(":")) == 8
    _, _, _, aws_region, aws_account_id, _, state_machine_name, execution_name = execution_id.split(":")

    state_machine_arn = f"arn:aws:states:{aws_region}:{aws_account_id}:stateMachine:{state_machine_name}"
    execution_arn = f"arn:aws:states:{aws_region}:{aws_account_id}:execution:{execution_id}"

    body = json.dumps({
        "version": "0",
        "id": str(uuid4()),
        "detail-type": "Step Functions Execution Status Change",
        "source": "aws.states",
        "account": aws_account_id,
        "time": datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ'),
        "region": aws_region,
        "resources": [execution_arn],
        "detail": {
            "executionArn": execution_arn,
            "stateMachineArn": state_machine_arn,
            "name": execution_name,
            "status": "RUNNING",
            "lastCompletedStage": re.sub(r'(?<!^)(?=[A-Z])', '_', stage).lower(),
            # We don't set this because it isn't used yet and we don't have this
            #   field in the lambda, but it is part of the schema for these
            #   messages so we may need to add it.
            # "startDate": 1551225271984,
            "stopDate":  None,
            "input": "{}",
            "inputDetails": {
                 "included": None
            },
            "output": None,
            "outputDetails": None
        }
    })

    for squs_que_url in sqs_queue_urls:
        sqs.send_message(
            QueueUrl=squs_que_url,
            MessageBody=body,
        )
