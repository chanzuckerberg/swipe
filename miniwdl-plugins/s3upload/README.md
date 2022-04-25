# miniwdl-s3upload

This Python package is a [MiniWDL](https://github.com/chanzuckerberg/miniwdl) plugin to handle the orchestration of S3 upload (delocalization) for S3 URIs in WDL workflow I/O.

## Installation
```
pip3 install miniwdl-s3upload
```
To check that the installation was successful, run `miniwdl --version`, which will list available plugins, including this one.

## Usage
Set the environment variable `MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX` to an S3 URL where the task outputs should be uploaded.
