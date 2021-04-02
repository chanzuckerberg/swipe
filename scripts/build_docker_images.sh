#!/usr/bin/env bash

set -euo pipefail

if [[ -z ${APP_NAME:-} ]]; then
    echo "Please source the environment file before running this script."
    exit 1
fi

for dockerfile in ${APP_HOME}/docker/*/Dockerfile; do
    DOCKER_IMAGE_NAME="idseq-$(basename $(dirname $dockerfile))"
    DOCKERFILE_HASH="sha-$(cat $(dirname $dockerfile)/* | shasum | head -c 16)"
    $(dirname $0)/build_docker_image.sh "$dockerfile" "$DOCKER_IMAGE_NAME" "$DOCKERFILE_HASH"
done
