"""
Send SNS notifications after each miniwdl step
"""

import os
import json
from typing import Dict
from datetime import datetime
from WDL import values_to_json
from WDL._util import StructuredLogMessage as _

import boto3

sns_client = boto3.client("sns", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
topic_arn = os.getenv('STEP_NOTIFICATION_TOPIC_ARN')


def process_outputs(outputs: Dict):
    """process outputs dict into string to be passed into SQS"""
    # only stringify for now
    return json.dumps(outputs)


def send_message(attr, body):
    """send message to SNS"""
    sns_resp = sns_client.publish(
        TopicArn=topic_arn,
        Message=body,
        MessageAttributes=attr,
    )
    return sns_resp


def task(cfg, logger, run_id, run_dir, task, **recv):
    """
    on completion of any task sends a message to sns with the output files
    """
    log = logger.getChild("sns_step_notification")

    # ignore inputs
    recv = yield recv
    # ignore command/runtime/container
    recv = yield recv

    log.info(_("sending message to sns"))

    message_attributes = {
        "WorkflowName": {"DataType": "String", "StringValue": run_id[0]},
        "TaskName": {"DataType": "String", "StringValue": run_id[-1]},
        "ExecutionId": {
            "DataType": "String",
            "StringValue": "execution_id_to_be_passed_in",
        },
    }

    outputs = process_outputs(values_to_json(recv["outputs"]))
    message_body = {
        "version": "0",
        "id": "0",
        "detail-type": "Step Functions Execution Step Notification",
        "source": "aws.batch",
        "account": "",
        "time": datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "resources": [],
        "detail": outputs,
    }
    send_message(message_attributes, json.dumps(message_body))

    yield recv


def workflow(cfg, logger, run_id, run_dir, workflow, **recv):
    log = logger.getChild("sns_step_notification")

    # ignore inputs
    recv = yield recv

    log.info(_("ignores workflow calls"))
    yield recv
