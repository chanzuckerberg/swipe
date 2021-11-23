#!/usr/bin/env python3

import os
import sys
import boto3
import json
import logging
import argparse
import datetime

from aegea.sfn import watch, watch_parser
from aegea.util import Timestamp
from aegea.util.aws import ARN
from aegea.util.printing import YELLOW, RED, GREEN, BOLD, ENDC


def print_log_line(event):
    def format_log_level(level):
        log_colors = dict(ERROR=BOLD() + RED(), WARNING=YELLOW(), NOTICE=GREEN())
        if level == "VERBOSE":
            return ""
        elif level in log_colors:
            return " " + log_colors[level] + level + ENDC()
        return level
    try:
        if "aws sts get-caller-identity" in event["message"]:
            return
        ts = Timestamp(event["timestamp"]).astimezone()
        event.update(json.loads(event["message"]))
        for field in "levelno", "timestamp", "ingestionTime":
            event.pop(field, None)
        if event.get("source", "").endswith(".stderr"):
            if "data" in event or "aws sts get-caller-identity" in event.get("message", ""):
                return
            print(ts, event.pop("source", "") + format_log_level(event.pop("level", "")), event.pop("message"))
    except (TypeError, json.decoder.JSONDecodeError):
        print(Timestamp(event["timestamp"]).astimezone(), event["message"])


logging.basicConfig(level=logging.INFO)

logger = logging.getLogger("sfn_dispatch")

timestamp = datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")

parser = argparse.ArgumentParser("run_sfn", description="Run an SFN-WDL workflow")
parser.add_argument("--sfn-name")
parser.add_argument("--sfn-arn")
parser.add_argument("--stages", nargs="+")
parser.add_argument("--sfn-input", type=json.loads, default={})
parser.add_argument("--output-prefix", default=f"s3://sfn-wdl-dev/output-{timestamp}")
parser.add_argument("--wdl-uri", default="s3://sfn-wdl-dev/test-v0.0.1.wdl")
args = parser.parse_args()

s3 = boto3.resource("s3")
sfn = boto3.client("stepfunctions")
logs = boto3.client("logs")
batch = boto3.client("batch")

app_name = os.environ[["APP_NAME"]

if args.sfn_name is None:
    args.sfn_name = "single-wdl"

if args.stages is None:
    args.stages = ["run"]

if args.sfn_arn is None:
    args.sfn_arn = str(ARN(service="states",
                           resource=f"stateMachine:{app_name}-{args.sfn_name}-1"))

args.sfn_input.setdefault("Input", {
    "Run": {
    }
})

args.sfn_input.setdefault("OutputPrefix", args.output_prefix)

for stage in args.stages:
    wdl_uri = args.wdl_uri
    args.sfn_input[f"{stage.upper()}_WDL_URI"] = wdl_uri

execution_name = f"{app_name}-{timestamp}"

logger.info("Starting execution for %s", execution_name)
res = sfn.start_execution(stateMachineArn=args.sfn_arn,
                          name=execution_name,
                          input=json.dumps(args.sfn_input))
try:
    try:
        orig_stdout, sys.stdout = sys.stdout, sys.stderr
        result = watch(watch_parser.parse_args([res["executionArn"]]), print_event_fn=print_log_line)
    finally:
        sys.stdout = orig_stdout
    print(json.dumps(result, indent=4, default=str))
    if isinstance(result, BaseException):
        raise result
except KeyboardInterrupt as e:
    logger.error("Stopping execution %s", res["executionArn"])
    print(sfn.stop_execution(executionArn=res["executionArn"], error=type(e).__name__, cause=str(e)))
    exit(1)
