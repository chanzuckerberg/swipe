import os
import json
import logging
import itertools
import concurrent.futures
from typing import List

from . import batch, stepfunctions, s3_object

logger = logging.getLogger()


def list_jobs_worker(list_jobs_worker_args):
    queue, status = list_jobs_worker_args
    return [j["jobId"] for j in batch.list_jobs(jobQueue=queue, jobStatus=status)["jobSummaryList"]]


def describe_jobs(queues, statuses, page_size=100):
    with concurrent.futures.ThreadPoolExecutor() as executor:
        job_ids: List = sum(executor.map(list_jobs_worker, itertools.product(queues, statuses)), [])

        def describe_jobs_worker(start_index):
            return batch.describe_jobs(jobs=job_ids[start_index:start_index + page_size])["jobs"]

        return sum(executor.map(describe_jobs_worker, range(0, len(job_ids), page_size)), [])


def archive_sfn_history(execution_arn):
    desc = stepfunctions.describe_execution(executionArn=execution_arn)
    output_prefix = json.loads(desc["input"])["OutputPrefix"]
    s3_object(os.path.join(output_prefix, "sfn-desc", execution_arn)).put(Body=json.dumps(desc, default=str).encode())
    hist = stepfunctions.get_execution_history(executionArn=execution_arn)
    s3_object(os.path.join(output_prefix, "sfn-hist", execution_arn)).put(Body=json.dumps(hist, default=str).encode())
