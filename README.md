# SWIPE: SFN-WDL infrastructure for pipeline execution

Swipe is a terraform module for creating AWS infrastructure to run WDL workflows. Swipe uses Step Functions, Batch, S3, and Lambda to run WDL workflows in a scalable, performant, reliable, and observable way.

## Why use swipe?

- **Minimal infrastructure setup**: Swipe is an infrastructure module first so you won't need to do much infrastructure configuration like you might have to do with other tools that are primarily software. Once you configure the minimal swipe configuration variables in the terraform module and apply you can start using swipe at high scale right away.
- **Highly optimized for working with large files**: Many bioinformatics tools are local tools designed to take files as input and produce files as input. Often, these files can get very large though many tools either don't support distributed approaches or would be made much slower with a distributed approach. Swipe is highly optimized for this use case. By default swipe:
    - Configures AWS Batch to work with NVME drives for super fast file I/O operations
    - Has a built in multi-threaded S3 uploader and downloader that can saturate 10 GB/sec network connection so your input and output files can be downloaded quickly
    - Has a built in input cache so inputs common to all of your pipeline runs can be safely re-used across jobs. This is particularly useful if your pipeline uses large reference databases that don't change from run to run which is typical of many bioinformatics workloads.
- **Cost savings while preserving pipeline throughput and latency**: Swipe tries each workflow first on a Spot instance for cost savings, then retries the workflow on-demand after the first failure. This results in high cost savings with a minimal sacrifice to both throughput and latency. If swipe retried on spot throughput may still be high, but by retrying on demand swipe also keeps latency (time for a single pipeline to complete) relatively low. This is useful if you have users waiting on results.

## Why not use swipe?

- **You are not using AWS**: Swipe is highly opinionated about the infrastructure it runs on. If you are not using AWS you can't use swipe.
- **You are running distributed big data jobs**: At time of writing, swipe is optimized for workflows with local files. If you intend to run distributed big data jobs, like Map Reduce jobs, swipe is probably not the right choice.


## Using SWIPE as a terraform module

## Running a WDL workflow
