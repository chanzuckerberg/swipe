#!/usr/bin/env python3
from setuptools import setup
from os import path

this_directory = path.abspath(path.dirname(__file__))
with open(path.join(path.dirname(__file__), "README.md")) as f:
    long_description = f.read()

setup(
    name="sqs_notification",
    version="0.0.1",
    description="miniwdl plugin for notification of task completion to Amazon SQS",
    url="https://github.com/chanzuckerberg/miniwdl-s3upload",
    project_urls={
    },
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="",
    py_modules=["sqs_notification"],
    python_requires=">=3.6",
    setup_requires=["reentry"],
    install_requires=["boto3"],
    reentry_register=True,
    entry_points={
        'miniwdl.plugin.task': ['sqs_notification_task = sqs_notification:task'],
        'miniwdl.plugin.workflow': ['sqs_notification_workflow = sqs_notification:workflow'],
    }
)
