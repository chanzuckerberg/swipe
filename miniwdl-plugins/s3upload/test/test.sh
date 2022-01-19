#!/bin/bash

# Quick plugin test. Assumes desired version of miniwdl is already installed. Installs plugin
# locally and runs a test workflow with file and directory outputs. The invoking shell must have
# MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX set to an appropriate test location, and a suitable
# AWS role configured for uploading there. Also, you must have s3parcp available in PATH.
#
# Example invocation from miniwdl-plugins/ (substitute your own S3 bucket):
# MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX=s3://idseq-samples-mlin/s3upload_test s3upload/test/test.sh --verbose

set -eo pipefail

if [[ -z $MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX ]]; then
    >&2 echo "MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX required"
    exit 1
fi
aws sts get-caller-identity

cd "$(dirname "${BASH_SOURCE[0]}")/.."
miniwdl check test/test.wdl
pip3 install .

miniwdl run test/test.wdl names=Alice names=Bob --dir "$(mktemp -d /tmp/miniwdl_s3upload_test.XXXXXXXX)/." $@

aws s3 ls --recursive "$MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX"
aws s3 cp "$MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX/outputs.s3.json" -
