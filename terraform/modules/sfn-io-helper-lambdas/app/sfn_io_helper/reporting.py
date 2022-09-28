import os
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import DefaultDict

from . import batch, cloudwatch, stepfunctions, paginate


def notify_success(sfn_state):
    """Placeholder for sending a message to a queue for push based result processing"""


def notify_failure(sfn_state):
    """Placeholder for sending a message to a queue for push based result processing"""


# TODO - publish job runtime
# TODO - publish job queue time
# TODO - publish instance classes launched
# TODO - publish number of jobs per instance
def emit_batch_metric_values(event, namespace=os.environ["APP_NAME"]):
    """Emit CloudWatch metrics for a Batch event"""
    environment = event["detail"]["container"]["environment"]
    wdl_file = None
    for envvar in environment:
        if envvar["name"] == "WDL_WORKFLOW_URI":
            wdl_file = envvar["value"]
    if not wdl_file:
        # This isn't a swipe job.
        return
    job_created_at = datetime.fromtimestamp(event["detail"]["createdAt"] // 1000)
    queue = event["detail"]["jobQueue"]
    status = event["detail"]["status"]
    event_time = event["time"]
    if status == 

def emit_sfn_metric_values(event, namespace=os.environ["APP_NAME"]):
    """Emit CloudWatch metrics for a SFN state change event"""
    sfn_terminal_states = ["SUCCEEDED", "FAILED", "TIMED_OUT", "ABORTED"]
    status = event["detail"]["status"]
    if status not in sfn_terminal_states:
        return
    metrics = [{"MetricName": "SFNExecutionsWithOneBatchJob", "Value": 1}]
    metric_name = "SwipeSpotStatus"
    history = stepfunctions.get_execution_history(
        executionArn=event["detail"]["executionArn"]
    )
    num_batch_jobs = 0
    for event in history:
        if event["type"] == "TaskSubmitted":
            details = event["taskSubmittedEventDetails"]
            if (
                details["resourceType"] == "batch"
                and details["resource"] == "submitJob.sync"
            ):
                num_batch_jobs += 1
    # We're assuming that if we submitted more than one batch job, we're using OnDemand instances.
    if num_batch_jobs >= 1:
        metric_name = "SwipeOnDemandStatus"
    metrics = [
        {
            "MetricName": metric_name,
            "Dimensions": [{"Name": metric_name, "Value": status}],
            "Value": 1,
        }
    ]
    cloudwatch.put_metric_data(Namespace=namespace, MetricData=metrics)


def emit_spot_interruption_metric(event, namespace=os.environ["APP_NAME"]):
    """Emit a CloudWatch metric for an EC2 spot instance interruption event"""
    metrics = [{"MetricName": "SpotInterruptionEvents", "Value": 1}]
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
