#!/bin/bash

set -euo pipefail
trap "exit" INT TERM
trap "kill 0" EXIT

docker-compose up
