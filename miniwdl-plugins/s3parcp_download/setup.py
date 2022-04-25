#!/usr/bin/env python3
from setuptools import setup
from os import path

this_directory = path.abspath(path.dirname(__file__))
with open(path.join(path.dirname(__file__), "README.md")) as f:
    long_description = f.read()

setup(
    name="miniwdl-s3parcp",
    version="0.0.5",
    url="https://github.com/chanzuckerberg/miniwdl-s3parcp",
    project_urls={
        "Documentation": "https://github.com/chanzuckerberg/miniwdl-s3parcp",
        "Source Code": "https://github.com/chanzuckerberg/miniwdl-s3parcp",
        "Issue Tracker": "https://github.com/chanzuckerberg/miniwdl-s3parcp/issues"
    },
    description="miniwdl download plugin for s3:// using s3parcp",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Mike Lin, Andrey Kislyuk",
    py_modules=["miniwdl_s3parcp"],
    python_requires=">=3.6",
    setup_requires=["reentry"],
    install_requires=["boto3"],
    reentry_register=True,
    entry_points={
        "miniwdl.plugin.file_download": ["s3 = miniwdl_s3parcp:main"],
    }
)
