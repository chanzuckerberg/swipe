# SWIPE: SFN-WDL infrastructure for pipeline execution

Swipe is a terraform module for creating AWS infrastructure to run WDL workflows. Swipe uses Step Functions, Batch, S3, and Lambda to run WDL workflows in a scalable, performant, reliable, and observable way.

With swipe you can run a WDL workflow with S3 inputs with a single call to the AWS Step Functions API and get your results in S3 as well as paths to your results in your Step Function Output.

## Why use swipe?

- **Minimal infrastructure setup**: Swipe is an infrastructure module first so you won't need to do much infrastructure configuration like you might have to do with other tools that are primarily software. Once you configure the minimal swipe configuration variables in the terraform module and apply you can start using swipe at high scale right away.
- **Highly optimized for working with large files**: Many bioinformatics tools are local tools designed to take files as input and produce files as input. Often, these files can get very large though many tools either don't support distributed approaches or would be made much slower with a distributed approach. Swipe is highly optimized for this use case. By default swipe:
    - Configures AWS Batch to work with NVME drives for super fast file I/O operations
    - Has a built in multi-threaded S3 uploader and downloader that can saturate 10 GB/sec network connection so your input and output files can be downloaded quickly
    - Has a built in input cache so inputs common to all of your pipeline runs can be safely re-used across jobs. This is particularly useful if your pipeline uses large reference databases that don't change from run to run which is typical of many bioinformatics workloads.
- **Cost savings while preserving pipeline throughput and latency**: Swipe tries each workflow first on a Spot instance for cost savings, then retries the workflow on-demand after the first failure. This results in high cost savings with a minimal sacrifice to both throughput and latency. If swipe retried on spot throughput may still be high, but by retrying on demand swipe also keeps latency (time for a single pipeline to complete) relatively low. This is useful if you have users waiting on results.
- **Built in monitoring**: Swipe automatically monitors key workflow metrics and you can analyzing failures in the AWS console
- **Easy integration**: Using AWS eventbridge you can easily route SNS notifications to notify other services of workflow status

## Why not use swipe?

- **You are not using AWS**: Swipe is highly opinionated about the infrastructure it runs on. If you are not using AWS you can't use swipe.
- **You are running distributed big data jobs**: At time of writing, swipe is optimized for workflows with local files. If you intend to run distributed big data jobs, like Map Reduce jobs, swipe is probably not the right choice.

## Usage

### Basic Usage


#### Create swipe infrastructure

To use swipe you first need to create the infrastructure with terraform. You will need an S3 bucket to store your inputs and outputs called a `workspace` and an S3 bucket to store your wdl files. They can be the same bucket but for clarity I will use two different buckets, and I recommend you do the same.


```terraform
resource "aws_s3_bucket" "workspace" {
  bucket = "my-test-app-swipe-workspace"
}

resource "aws_s3_bucket" "wdls" {
  bucket = "my-test-app-swipe-wdls"
}

module "swipe" {
    source = "github.com/chanzuckerberg/swipe?ref=v0.7.0-beta"

    app_name               = "my-test-app"
    workspace_s3_prefix    = aws_s3_bucket.workspace.bucket
    wdl_workflow_s3_prefix = aws_s3_bucket.workspace.bucket
}
```

This will produce an output called `sfn_arns`, a map of stepfunction names to their ARNs. By default swipe creates a single default stepfunction called `default`.

#### Upload your WDL workflow to S3

Now we need to define a workflow to run. Here is a basic WDL workflow that leverages some files:

```WDL
version 1.0
workflow hello_swipe {
  input {
    File hello
    String docker_image_id
  }

  call add_world {
    input:
      hello = hello,
      docker_image_id = docker_image_id
  }

  output {
    File out = add_world.out
  }
}

task add_world {
  input {
    File hello
    String docker_image_id
  }

  command <<<
    cat {hello} > out.txt
    cat world >> out.txt
  >>>

  output {
    File out = out.txt
  }

  runtime {
      docker: docker_image_id
  }
}
```

Let's save this one as `hello.wdl` and upload it:

```bash
aws s3 cp hello.wdl s3://my-test-app-swipe-wdls/hello.wdl
```

Let's also make a test input for file for it and upload that:

```bash
cat hello >> input.txt
aws s3 cp input.txt s3://my-test-app-swipe-workspace/input.txt
```

#### Run your wdl

You can run you WDL with inputs and an output path using the AWS API. Here I will use python and boto3 for easy readability:

```python
import boto3
import json

client = boto3.client('stepfunctions')

response = client.start_execution(
    stateMachineArn='DEFAULT_STEP_FUNCTION_ARN',
    name='my-swipe-run',
    input=json.dumps({
      "RUN_WDL_URI": "s3://my-test-app-swipe-wdls/hello.wdl",
      "OutputPrefix": "s3://my-test-app-swipe-workspace/outputs/",
      "Input": {
          "Run": {
              "hello": "s3://my-test-app-swipe-workspace/input.txt",
          }
      }
    }),
)
```

Once your step function is complete your output should be at `s3://my-test-app-swipe-workspace/outputs/out.txt`. Note that `out.txt` came from the WDL workflow.
