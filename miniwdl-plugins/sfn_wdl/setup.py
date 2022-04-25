#!/usr/bin/env python3
from setuptools import setup
from os import path

this_directory = path.abspath(path.dirname(__file__))
with open(path.join(path.dirname(__file__), "README.md")) as f:
    long_description = f.read()

setup(
    name="sfnwdl-miniwdl-plugin",
    version="0.1.0",
    description="miniwdl plugin for IDseq SFN-WDL customizations",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Mike Lin, Andrey Kislyuk",
    py_modules=["sfnwdl_miniwdl_plugin"],
    python_requires=">=3.6",
    setup_requires=["reentry"],
    install_requires=["boto3"],
    reentry_register=True,
    entry_points={
        # NOTE: the step status JSON function of this plugin has to run after the s3upload plugin
        # (so that the uploads really are complete once sets the status to say so). miniwdl runs
        # the plugins in alphabetical order, so "sfnwdl_miniwdl_plugin_task" has to follow the
        # corresponding upload plugin's name(s).
        "miniwdl.plugin.task": ["sfnwdl_miniwdl_plugin_task = sfnwdl_miniwdl_plugin:task"]
    },
)
