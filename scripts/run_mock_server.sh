#!/bin/bash

set -euo pipefail
trap "exit" INT TERM
trap "kill 0" EXIT

if ! [[ -e sfn_local ]]; then
    mkdir -p sfn_local
    curl https://docs.aws.amazon.com/step-functions/latest/dg/samples/StepFunctionsLocal.tar.gz | tar -xzC sfn_local
fi

moto_server --host 0.0.0.0 --port 9000 &

java -jar sfn_local/StepFunctionsLocal.jar --batch-endpoint http://localhost:9000 --lambda-endpoint http://localhost:9000 --aws-account 123456789012
