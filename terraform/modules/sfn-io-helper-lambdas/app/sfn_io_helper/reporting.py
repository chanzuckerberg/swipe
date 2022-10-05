import os
import os.path
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from sqlite3 import complete_statement
from sre_constants import FAILURE
from typing import DefaultDict
from xmlrpc.server import CGIXMLRPCRequestHandler

from . import batch, cloudwatch, stepfunctions, paginate, ec2


def notify_success(sfn_state):
    """Placeholder for sending a message to a queue for push based result processing"""


def notify_failure(sfn_state):
    """Placeholder for sending a message to a queue for push based result processing"""


# Publish job runtime, queue time, and status/billing type to CloudWatch
def emit_batch_metric_values(event, namespace=os.environ["APP_NAME"]):
    """Emit CloudWatch metrics for a Batch event"""
    batch_terminal_states = ["SUCCEEDED", "FAILED"]
    status = event["detail"]["status"]
    job_queue = event["detail"]["jobQueue"]
    # Skip events for job queues that don't belong to this app
    if f"job_queue/{namespace}-" not in job_queue:
        return

    # Is this spot or ondemand?
    billing_type = "spot"
    if job_queue.endswith("on_demand"):
        billing_type = "on_demand"

    # How long has it been since the job was created?
    start_time = event["detail"]["createdAt"] / 1000
    event_time = event["time"].strftime("%s")
    runtime = int(event_time) - int(start_time)

    # Which workflow is this?
    environment = event["detail"]["container"]["environment"]
    wdl_file = None
    for envvar in environment:
        if envvar["name"] == "WDL_WORKFLOW_URI":
            wdl_file = ".".join(os.path.basename(envvar["value"]).split(".")[:-1])
    if not wdl_file:
        # This isn't a swipe job.
        return

    # Add dimensions to the metric
    dimensions = [
        {"Name": "BillingType", "Value": billing_type},
        {"Name": "JobStatus", "Value": status},
        {"Name": "Workflow", "Value": wdl_file},
    ]
    metric_name = "RunTimeSeconds"
    if status == "RUNNING":
        metric_name = "QueueSeconds"
    elif status not in batch_terminal_states:
        return
    metrics = [{"MetricName": metric_name, "Value": runtime, "Dimensions": dimensions}]
    cloudwatch.put_metric_data(Namespace=namespace, MetricData=metrics)


def emit_sfn_metric_values(event, namespace=os.environ["APP_NAME"]):
    """Emit CloudWatch metrics for a SFN state change event"""


def emit_spot_interruption_metric(event, namespace=os.environ["APP_NAME"]):
    """Emit a CloudWatch metric for an EC2 spot instance interruption event"""
    # Get more information about the instance.
    instance = ec2.Instance(event["detail"]["instance-id"])
    instance_type = instance.instance_type
    dimensions = [
        {"Name": "InstanceType", "Value": instance_type},
    ]

    metrics = [
        {"MetricName": "SpotInterruptionEvents", "Value": 1, "Dimensions": dimensions}
    ]
    cloudwatch.put_metric_data(Namespace=namespace, MetricData=metrics)


def emit_periodic_metrics(
    namespace=os.environ["APP_NAME"], time_horizon=timedelta(days=1)
):
    """Emit CloudWatch metrics on a fixed schedule"""
    now = datetime.now(timezone.utc)
    terminal_states = {"SUCCEEDED", "ABORTED", "FAILED"}
    jobs_by_status = defaultdict(int)  # type: DefaultDict[str, int]
    for queue in paginate(batch.get_paginator("describe_job_queues")):
        if not queue["jobQueueName"].startswith(namespace):
            continue
        for job_status in (
            "SUBMITTED",
            "PENDING",
            "RUNNABLE",
            "STARTING",
            "RUNNING",
            "SUCCEEDED",
            "FAILED",
        ):
            for job in paginate(
                batch.get_paginator("list_jobs"),
                jobQueue=queue["jobQueueName"],
                jobStatus=job_status,
            ):
                job_created_at = datetime.fromtimestamp(
                    job["createdAt"] // 1000
                ).replace(tzinfo=timezone.utc)
                if (
                    now - job_created_at < time_horizon
                    or job_status not in terminal_states
                ):
                    jobs_by_status[job_status] += 1

    metrics = [
        dict(
            MetricName="BatchJobStatus",
            Dimensions=[dict(Name="BatchJobStatus", Value=k)],
            Value=v,
        )
        for k, v in jobs_by_status.items()
    ]
    if sum(jobs_by_status.values()) > 0:
        metrics.append(
            dict(
                MetricName="BatchPercentFailedJobs",
                Unit="Percent",
                Value=100 * jobs_by_status["FAILED"] / sum(jobs_by_status.values()),
            )
        )
    cloudwatch.put_metric_data(Namespace=namespace, MetricData=metrics)

    executions_by_status = defaultdict(int)  # type: DefaultDict[str, int]
    for state_machine in paginate(stepfunctions.get_paginator("list_state_machines")):
        state_machine_arn = state_machine["stateMachineArn"]
        if not state_machine_arn.split(":")[-1].startswith(namespace):
            continue
        for execution in paginate(
            stepfunctions.get_paginator("list_executions"),
            stateMachineArn=state_machine_arn,
        ):
            if (
                execution["status"] not in terminal_states
                or now - execution["stopDate"] < time_horizon
            ):
                executions_by_status[execution["status"]] += 1

    metrics = [
        dict(
            MetricName="SFNExecutionStatus",
            Dimensions=[dict(Name="SFNExecutionStatus", Value=k)],
            Value=v,
        )
        for k, v in executions_by_status.items()
    ]
    if sum(executions_by_status.values()) > 0:
        metrics.append(
            dict(
                MetricName="SFNPercentFailedExecutions",
                Unit="Percent",
                Value=100
                * executions_by_status["FAILED"]
                / sum(executions_by_status.values()),
            )
        )
    cloudwatch.put_metric_data(Namespace=namespace, MetricData=metrics)
    # TODO - write info about how many instances are running in SPOT/ON_DEMAND clusters,
    # what type they are, and how many jobs are running on them.
