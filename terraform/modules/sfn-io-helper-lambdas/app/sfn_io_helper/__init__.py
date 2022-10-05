import os

import boto3

s3 = boto3.resource("s3", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
batch = boto3.client("batch", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
stepfunctions = boto3.client(
    "stepfunctions", endpoint_url=os.getenv("AWS_ENDPOINT_URL")
)
cloudwatch = boto3.client("cloudwatch", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
sqs = boto3.client("sqs", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))
ec2 = boto3.resource("ec2", endpoint_url=os.getenv("AWS_ENDPOINT_URL"))


def s3_object(uri):
    assert uri.startswith("s3://")
    bucket, key = uri.split("/", 3)[2:]
    return s3.Bucket(bucket).Object(key)


def paginate(boto3_paginator, *args, **kwargs):
    for page in boto3_paginator.paginate(*args, **kwargs):
        for result_key in boto3_paginator.result_keys:
            for value in page.get(result_key.parsed.get("value"), []):
                yield value
