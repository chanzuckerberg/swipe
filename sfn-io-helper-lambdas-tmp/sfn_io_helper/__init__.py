import boto3

s3 = boto3.resource("s3")
batch = boto3.client("batch")
stepfunctions = boto3.client("stepfunctions")
cloudwatch = boto3.client("cloudwatch")


def s3_object(uri):
    assert uri.startswith("s3://")
    bucket, key = uri.split("/", 3)[2:]
    return s3.Bucket(bucket).Object(key)


def paginate(boto3_paginator, *args, **kwargs):
    for page in boto3_paginator.paginate(*args, **kwargs):
        for result_key in boto3_paginator.result_keys:
            for value in page.get(result_key.parsed.get("value"), []):
                yield value
