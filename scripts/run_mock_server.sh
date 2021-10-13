#!/bin/bash

set -euo pipefail
trap "exit" INT TERM
trap "kill 0" EXIT

moto_server --host 0.0.0.0 --port 9000 &

docker run \
    -d \
    --network host \
    -e SERVICES=lambda \
    -e DEFAULT_REGION=$AWS_DEFAULT_REGION \
    -e DEBUG=1 \
    -e LAMBDA_EXECUTOR=local \
    -e EDGE_PORT=9001 \
    localstack/localstack lambda

docker run --network host -e BATCH_ENDPOINT=http://localhost:9000 -e LAMBDA_ENDPOINT=http://localhost:9001 -e AWS_ACCOUNT_ID=123456789012 amazon/aws-stepfunctions-local
