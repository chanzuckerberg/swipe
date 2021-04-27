#!/usr/bin/env bash

set -euo pipefail

if [[ $# != 3 ]]; then
    echo "This script builds a Docker image for the given Dockerfile and uploads it to the Docker registry under the"
    echo "given name and tag. The Docker registry is ECR by default, or GitHub Packages if running on GitHub Actions."
    echo "Usage: $(basename $0) dockerfile image_name image_tag"
    exit 1
fi

print_docker_build_log() {
    if [[ -f docker_build.log ]]; then
        echo "$0: Error while building docker image; begin Docker build log:" > /dev/stderr
        cat docker_build.log > /dev/stderr
        echo "$0: End Docker build log" > /dev/stderr
    fi
}
trap print_docker_build_log ERR

dockerfile=$1
image_name=$2
image_tag=$3
echo "Checking if a Docker image exists for $dockerfile..."
if [[ -n ${GITHUB_ACTIONS:-} ]] && [[ ${DEPLOYMENT_ENVIRONMENT:-} == test ]]; then
    echo $GITHUB_TOKEN | docker login docker.pkg.github.com --username $(dirname $GITHUB_REPOSITORY) --password-stdin
    export DOCKER_IMAGE_URI="docker.pkg.github.com/${GITHUB_REPOSITORY}/${image_name}"
    DOCKER_API="https://docker.pkg.github.com/v2/${GITHUB_REPOSITORY}/${image_name}"
    if http -p Hh --check-status GET "${DOCKER_API}/manifests/${image_tag}" Authorization:"Bearer $GITHUB_TOKEN"; then
        echo "Docker image found at ${DOCKER_IMAGE_URI}:${image_tag}, skipping build"
        exit
    fi
else
    aws ecr get-login-password --region $AWS_DEFAULT_REGION \
        | docker login --username AWS --password-stdin      \
        "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
    export DOCKER_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${image_name}"
    aws ecr create-repository --repository-name=$image_name || true
    if aws ecr describe-images --repository-name=$image_name --image-ids=imageTag=$image_tag; then
        echo "Docker image found at ${DOCKER_IMAGE_URI}:${image_tag}, skipping build"
        exit
    fi
fi
CACHE_FROM=""; docker pull "$DOCKER_IMAGE_URI" && CACHE_FROM="--cache-from $DOCKER_IMAGE_URI"
(docker build "$(dirname $dockerfile)" --tag "${DOCKER_IMAGE_URI}:${image_tag}" $CACHE_FROM || docker build "$(dirname $dockerfile)" --tag "${DOCKER_IMAGE_URI}:${image_tag}" --no-cache) > docker_build.log 2>&1
docker push "${DOCKER_IMAGE_URI}:${image_tag}"
