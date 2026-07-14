#!/usr/bin/env python3

import argparse
import os
import subprocess

from pathlib import Path


def get_version():
    version_path = Path(os.path.realpath(__file__)).resolve().parent.parent / "version"
    print(f"version_path = {version_path}")
    with open(version_path, "r") as f:
        return f.read().strip()


def docker_login(profile: str):
    account = run_cmd(
        ["aws", "sts", "get-caller-identity", "--profile", profile, "--query", "Account", "--output", "text"]
    )
    if not account:
        raise Exception("AWS Profile Has no Account")
    print(f"account = {account}")

    password = run_cmd(
        ["aws", "ecr", "get-login-password", "--region", "us-west-2", "--profile", profile]
    )
    print(f"password = {password}")

    docker_url = f"{account}.dkr.ecr.us-west-2.amazonaws.com"
    print(f"docker_url = {docker_url}")

    res = run_cmd(
        ["docker", "login", "--username", "AWS", "--password-stdin", docker_url],
        password
    )
    print(f"Docker Login: {res}")

    return docker_url


def run_cmd(cmd, input_str=None):
    print(' '.join(cmd))
    if input_str is None:
        p = subprocess.run(cmd, encoding='utf-8', capture_output=True)
    else:
        p = subprocess.run(cmd, input=input_str, encoding='utf-8', capture_output=True)
    if p.returncode != 0:
        raise Exception(f"Command failed:\n{p.stdout}\n{p.stderr}")
    return p.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description="Build and deploy Docker Image to ERC")
    parser.add_argument("-p", "--profile", type=str, help="AWS Profile", required=True)
    # parser.add_argument("-v", "--verbose", help="Enable verbose output", action="store_true" )
    args = parser.parse_args()

    profile = args.profile
    if not profile:
        raise Exception("AWS Profile Required")

    docker_url = docker_login(args.profile)
    module = "swipe"
    # version="latest"

    image_tags = [
        "latest",
        get_version(),
    ]

    # --platform linux/amd64,linux/arm64
    cmd = ["docker", "buildx", "build", "--platform", "linux/amd64", "."]
    for image_tag in image_tags:
        cmd += ["--tag", f"{docker_url}/{module}:{image_tag}"]
    cmd += ["--push"]
    run_cmd(cmd)


if __name__ == "__main__":
    main()
