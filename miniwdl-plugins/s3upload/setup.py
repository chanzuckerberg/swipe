#!/usr/bin/env python3
from setuptools import setup
from os import path

this_directory = path.abspath(path.dirname(__file__))
with open(path.join(path.dirname(__file__), "README.md")) as f:
    long_description = f.read()

setup(
    name="miniwdl-s3upload",
    version="0.0.8",
    description="miniwdl plugin for progressive upload of task output files to Amazon S3",
    url="https://github.com/chanzuckerberg/miniwdl-s3upload",
    project_urls={
        "Documentation": "https://github.com/chanzuckerberg/miniwdl-s3upload",
        "Source Code": "https://github.com/chanzuckerberg/miniwdl-s3upload",
        "Issue Tracker": "https://github.com/chanzuckerberg/miniwdl-s3upload/issues"
    },
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Mike Lin, Andrey Kislyuk",
    py_modules=["miniwdl_s3upload"],
    python_requires=">=3.6",
    setup_requires=["reentry"],
    install_requires=["boto3"],
    reentry_register=True,
    entry_points={
        'miniwdl.plugin.task': ['s3_progressive_upload_task = miniwdl_s3upload:task'],
        'miniwdl.plugin.workflow': ['s3_progressive_upload_workflow = miniwdl_s3upload:workflow'],
        'miniwdl.plugin.cache_backend': ['s3_progressive_upload_call_cache_backend = miniwdl_s3upload:CallCache'],
    }
)
