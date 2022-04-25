"""
miniwdl download plugin for s3:// URIs using s3parcp -- https://github.com/chanzuckerberg/s3parcp
Requires s3parcp docker image tag supplied in miniwdl configuration, either via custom cfg file
(section s3parcp, key docker_image) or environment variable MINIWDL__S3PARCP__DOCKER_IMAGE.
Inherits AWS credentials from miniwdl's environment (as detected by boto3).

The plugin is installed using the "entry points" mechanism in setup.py. Furthermore, the miniwdl
configuration [plugins] section has options to enable/disable installed plugins. Installed &
enabled plugins can be observed using miniwdl --version and/or miniwdl run --debug.
"""

import os
import tempfile
import boto3


def main(cfg, logger, uri, **kwargs):
    # get AWS credentials from boto3
    b3 = boto3.session.Session()
    b3creds = b3.get_credentials()
    aws_credentials = {
        "AWS_ACCESS_KEY_ID": b3creds.access_key,
        "AWS_SECRET_ACCESS_KEY": b3creds.secret_key,
    }
    if b3creds.token:
        aws_credentials["AWS_SESSION_TOKEN"] = b3creds.token

    # s3parcp (or perhaps underlying golang AWS lib) seems to require region set to match the
    # bucket's; in contrast to awscli which can conveniently 'figure it out'
    aws_credentials["AWS_REGION"] = b3.region_name if b3.region_name else "us-west-2"

    # format them as env vars to be sourced in the WDL task command
    aws_credentials = "\n".join(f"export {k}='{v}'" for (k, v) in aws_credentials.items())

    # write them to a temp file that'll self-destruct automatically
    temp_dir = "/mnt"
    if cfg.has_option("s3parcp", "dir"):
        temp_dir = cfg["s3parcp"]["dir"]
    with tempfile.NamedTemporaryFile(
        prefix="miniwdl_download_s3parcp_credentials_", delete=True, mode="w", dir=temp_dir
    ) as aws_credentials_file:
        print(aws_credentials, file=aws_credentials_file, flush=True)
        # make file group-readable to ensure it'll be usable if the docker image runs as non-root
        os.chmod(aws_credentials_file.name, os.stat(aws_credentials_file.name).st_mode | 0o40)

        # yield WDL task and inputs (followed by outputs as well)
        recv = yield {
            "task_wdl": wdl,
            "inputs": {
                "uri": uri,
                "aws_credentials": aws_credentials_file.name,
                "docker": cfg["s3parcp"]["docker_image"],
            },
        }

    # yield task outputs (unchanged)
    yield recv


# WDL task source code
wdl = """
task s3parcp {
    input {
        String uri
        File aws_credentials
        String docker

        Int cpu = 4
    }

    command <<<
        set -euo pipefail
        source "~{aws_credentials}"
        mkdir __out
        cd __out
        # allocating one hardware thread to two concurrent part xfers
        s3parcp -c ~{cpu*2} "~{uri}" .
    >>>

    output {
        File file = glob("__out/*")[0]
    }

    runtime {
        cpu: cpu
        memory: "~{cpu}G"
        docker: docker
    }
}
"""
