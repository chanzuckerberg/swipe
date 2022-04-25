# miniwdl-s3parcp

This Python package is a [MiniWDL](https://github.com/chanzuckerberg/miniwdl) plugin to handle S3 URI downloads using
[s3parcp](https://github.com/chanzuckerberg/s3parcp).

## Installation
```
pip3 install miniwdl-s3parcp
```
To check that the installation was successful, run `miniwdl --version`, which will list available plugins, including this one.

## Usage
The plugin will automatically be used to handle `s3://bucket/key` URIs found in workflow inputs.
