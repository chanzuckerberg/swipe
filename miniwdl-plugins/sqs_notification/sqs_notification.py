"""
TODO
"""

import os
import json
from typing import Dict

from WDL import values_to_json

import boto3

sqs_client = boto3.client("sqs", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
queue_url = (
    "https://sqs.us-west-2.amazonaws.com/732052188396/RyansTestQueueDelete"  # TODO
)


def process_outputs(outputs: Dict):
    """process outputs dict into string to be passed into SQS"""
    # only stringify for now
    return json.dumps(outputs)


def send_message(attr, body):
    """send message to SQS, eventually wrap this in a try catch to deal with throttling"""
    sqs_resp = sqs_client.send_message(
        QueueUrl=queue_url,
        DelaySeconds=0,
        MessageAttributes=attr,
        MessageBody=body,
    )
    return sqs_resp


def task(cfg, logger, run_id, run_dir, task, **recv):
    """
    on completion of any task, upload its output files to S3, and record the S3 URI corresponding
    to each local file (keyed by inode) in _uploaded_files
    """
    logger = logger.getChild("s3_progressive_upload")

    # ignore inputs
    recv = yield recv

    # ignore command/runtime/container
    recv = yield recv

    message_attributes = {
        "WorkflowName": {"DataType": "String", "StringValue": run_id[0]},
        "TaskName": {"DataType": "String", "StringValue": run_id[-1]},
        "ExecutionId": {
            "DataType": "String",
            "StringValue": "execution_id_to_be_passed_in",
        },
    }

    outputs = process_outputs(values_to_json(recv["outputs"]))
    message_body = outputs

    send_message(message_attributes, message_body)

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

    yield recv
