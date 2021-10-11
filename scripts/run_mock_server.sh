#!/bin/bash

set -euo pipefail
trap "exit" INT TERM
trap "kill 0" EXIT

docker pull amazon/aws-stepfunctions-local

# moto_server --host 0.0.0.0 --port 9000 &

# docker run --network host -e BATCH_ENDPOINT=http://localhost:9000 -e LAMBDA_ENDPOINT=http://localhost:9000 -e AWS_ACCOUNT_ID=123456789012 amazon/aws-stepfunctions-local
