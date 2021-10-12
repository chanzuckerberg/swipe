#!/bin/bash

set -euo pipefail
trap "exit" INT TERM
trap "kill 0" EXIT

#docker pull amazon/aws-stepfunctions-local

# moto_server --host 0.0.0.0 --port 4566 &

# docker run --network host -e BATCH_ENDPOINT=http://localhost:4566 -e LAMBDA_ENDPOINT=http://localhost:4566 -e AWS_ACCOUNT_ID=123456789012 amazon/aws-stepfunctions-local

docker-compose up