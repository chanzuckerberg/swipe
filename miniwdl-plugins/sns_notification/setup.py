#!/usr/bin/env python3
from setuptools import setup
from os import path

this_directory = path.abspath(path.dirname(__file__))
with open(path.join(path.dirname(__file__), "README.md")) as f:
    long_description = f.read()

setup(
    name="sns_notification",
    version="0.0.1",
    description="miniwdl plugin for notification of task completion to Amazon SQS",
    url="https://github.com/chanzuckerberg/swipe",
    project_urls={},
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="",
    py_modules=["sns_notification"],
    python_requires=">=3.6",
    setup_requires=["reentry"],
    install_requires=["boto3"],
    reentry_register=True,
    entry_points={
        "miniwdl.plugin.task": ["sns_notification_task = sns_notification:task"],
        "miniwdl.plugin.workflow": [
            "sns_notification_workflow = sns_notification:workflow"
        ],
    },
)
