import json
import logging
import sys
from tempfile import NamedTemporaryFile
import time
import unittest
from os.path import dirname, realpath, join
from typing import Any, Dict, List, Tuple

import boto3
from WDL import load, Zip

test_wdl = """
version 1.0
workflow swipe_test {
  input {
    File hello
    String docker_image_id
  }

  call add_world {
    input:
      input_file = hello,
      docker_image_id = docker_image_id
  }

  call add_goodbye {
    input:
      input_file = add_world.out_world,
      docker_image_id = docker_image_id
  }

  call add_farewell {
    input:
      input_file = add_goodbye.out_goodbye,
      docker_image_id = docker_image_id
  }

  output {
    File out_world = add_world.out_world
    File out_goodbye = add_goodbye.out_goodbye
    File out_farewell = add_farewell.out_farewell
  }
}

task add_world {
  input {
    File input_file
    String docker_image_id
  }

  command <<<
    cat ~{input_file} > out_world.txt
    echo world >> out_world.txt
  >>>

  output {
    File out_world = "out_world.txt"
  }

  runtime {
      docker: docker_image_id
  }
}

task add_goodbye {
  input {
    File input_file
    String docker_image_id
  }

  command <<<
    cat ~{input_file} > out_goodbye.txt
    echo goodbye >> out_goodbye.txt
  >>>

  output {
    File out_goodbye = "out_goodbye.txt"
  }

  runtime {
      docker: docker_image_id
  }
}

task add_farewell {
  input {
    File input_file
    String docker_image_id
  }

  command <<<
    cat ~{input_file} > out_farewell.txt
    echo farewell >> out_farewell.txt
  >>>

  output {
    File out_farewell = "out_farewell.txt"
  }

  runtime {
      docker: docker_image_id
  }
}
"""

test_wdl_temp = """
version 1.0
workflow swipe_test {
  input {
    File hello
    String docker_image_id
  }

  call add_world_temp {
    input:
      input_file = hello,
      docker_image_id = docker_image_id
  }

  output {
    File out_world = add_world_temp.out_world
  }
}

task add_world_temp {
  input {
    File input_file
    String docker_image_id
  }

  command <<<
    cat ~{input_file} > out_world.txt
    echo world >> out_world.txt
    echo "temporary file" > temporary.txt
  >>>

  output {
    File out_world = "out_world.txt"
    File temporary = "temporary.txt"
  }

  runtime {
      docker: docker_image_id
  }
}

"""

test_fail_wdl = """
version 1.0
workflow swipe_test {
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
    set -euxo pipefail
    cat ~{hello} > out.txt
    exit 1
    echo world >> out.txt
  >>>

  output {
    File out = "out.txt"
  }

  runtime {
      docker: docker_image_id
  }
}
"""

test_two_wdl = """
version 1.0
workflow swipe_test_two {
  input {
    File hello_world
    String docker_image_id
  }

  call add_smile {
    input:
      hello_world = hello_world,
      docker_image_id = docker_image_id
  }

  output {
    File happy_message = add_smile.happy_message
  }
}

task add_smile {
  input {
    File hello_world
    String docker_image_id
  }

  command <<<
    cat ~{hello_world} > happy_message.txt
    echo ":)" >> happy_message.txt
  >>>

  output {
    File happy_message = "happy_message.txt"
  }

  runtime {
      docker: docker_image_id
  }
}
"""

test_stage_io_map = {
    "Two": {
        "hello_world": "out_world",
    },
}

test_input = """hello
"""


class TestSFNWDL(unittest.TestCase):
    def setUp(self) -> None:
        self.logger = logging.getLogger('test-wdl')

        self.s3 = boto3.resource("s3", endpoint_url="http://localhost:9000")
        self.s3_client = boto3.client("s3", endpoint_url="http://localhost:9000")
        self.batch = boto3.client("batch", endpoint_url="http://localhost:9000")
        self.logs = boto3.client("logs", endpoint_url="http://localhost:9000")
        self.sfn = boto3.client("stepfunctions", endpoint_url="http://localhost:8083")
        self.test_bucket = self.s3.create_bucket(Bucket="swipe-test")
        self.lamb = boto3.client("lambda", endpoint_url="http://localhost:9000")
        self.sqs = boto3.client("sqs", endpoint_url="http://localhost:9000")
        self.wdl_obj = self.test_bucket.Object("test-v1.0.0.wdl")
        self.wdl_obj.put(Body=test_wdl.encode())
        self.wdl_fail_obj = self.test_bucket.Object("test-fail-v1.0.0.wdl")
        self.wdl_fail_obj.put(Body=test_fail_wdl.encode())
        self.wdl_two_obj = self.test_bucket.Object("test-two-v1.0.0.wdl")
        self.wdl_two_obj.put(Body=test_two_wdl.encode())
        self.wdl_obj_temp = self.test_bucket.Object("test-temp-v1.0.0.wdl")
        self.wdl_obj_temp.put(Body=test_wdl_temp.replace("swipe_test", "temp_test").encode())

        with NamedTemporaryFile(suffix=".wdl.zip") as f:
            Zip.build(load(join(dirname(realpath(__file__)), 'multi_wdl/run.wdl')), f.name, self.logger)
            self.wdl_zip_object = self.test_bucket.Object("test-v1.0.0.wdl.zip")
            self.wdl_zip_object.upload_file(f.name)

        self.map_obj = self.test_bucket.Object("stage_io_map.json")
        self.map_obj.put(Body=json.dumps(test_stage_io_map).encode())
        self.input_obj = self.test_bucket.Object("input.txt")
        self.input_obj.put(Body=test_input.encode())
        state_machines = self.sfn.list_state_machines()["stateMachines"]
        self.single_sfn_arn = [
            sfn["stateMachineArn"] for sfn in state_machines if "default" in sfn["name"]
        ][0]
        self.stage_sfn_arn = [
            sfn["stateMachineArn"]
            for sfn in state_machines
            if "stage-test" in sfn["name"]
        ][0]
        self.state_change_queue_url = [
            url
            for url in self.sqs.list_queues()["QueueUrls"]
            if "swipe-test-notifications" in url
        ][0]
        self.step_change_queue_url = [
            url
            for url in self.sqs.list_queues()["QueueUrls"]
            if "swipe-test-step" in url
        ][0]

        # Empty the SQS queue before running tests.
        _ = self.sqs.purge_queue(QueueUrl=self.state_change_queue_url)
        _ = self.sqs.purge_queue(QueueUrl=self.step_change_queue_url)


    def tearDown(self) -> None:
        self.test_bucket.delete_objects(
            Delete={
                "Objects": [{"Key": obj.key} for obj in self.test_bucket.objects.all()],
            }
        )
        self.test_bucket.delete()

    def retrieve_message(self, url) -> str:
      """ Retrieve a single SQS message and delete it from queue"""
      resp = self.sqs.receive_message(
          QueueUrl=url,
          MaxNumberOfMessages=1,
      )
      # If no messages, just return
      if not resp.get("Messages", None):
          return ""
      
      message = resp["Messages"][0]
      receipt_handle = message["ReceiptHandle"]
      self.sqs.delete_message(
          QueueUrl=url,
          ReceiptHandle=receipt_handle,
      )
      return message["Body"]

    def _wait_sfn(
        self,
        sfn_input: Dict,
        sfn_arn: str,
        n_stages: int = 1,
        expect_success: bool = True
    ) -> Tuple[str, Dict, List[Dict]]:
        execution_name = "swipe-test-{}".format(int(time.time()))
        res = self.sfn.start_execution(
            stateMachineArn=sfn_arn, name=execution_name, input=json.dumps(sfn_input)
        )
        arn = res["executionArn"]
        start = time.time()
        description = self.sfn.describe_execution(executionArn=arn)
        step_notifications = []
        while description["status"] == "RUNNING" and time.time() < start + 2 * 60:
            time.sleep(10)
            description = self.sfn.describe_execution(executionArn=arn)
        
        while messages := self.retrieve_message(self.step_change_queue_url): 
            step_notifications.append(
                messages
            )

        print("printing execution history", file=sys.stderr)

        seen_events = set()
        for event in sorted(self.sfn.get_execution_history(executionArn=arn)["events"], key=lambda x: x["id"]):
            if event["id"] not in seen_events:
                details = {}
                for key in event.keys():
                    if key.endswith("EventDetails") and event[key]:
                        details = event[key]
                print(
                    event["timestamp"],
                    event["type"],
                    details.get("resourceType", ""),
                    details.get("resource", ""),
                    details.get("name", ""),
                    json.loads(details.get("parameters", "{}")).get("FunctionName", ""),
                    file=sys.stderr,
                  )
                if "taskSubmittedEventDetails" in event:
                    if event.get("taskSubmittedEventDetails", {}).get("resourceType") == "batch":
                        job_id = json.loads(event["taskSubmittedEventDetails"]["output"])["JobId"]
                        print(f"Batch job ID {job_id}", file=sys.stderr)
                        job_desc = self.batch.describe_jobs(jobs=[job_id])["jobs"][0]
                        try:
                            log_group_name = job_desc["container"]["logConfiguration"]["options"]["awslogs-group"]
                        except KeyError:
                            log_group_name = "/aws/batch/job"
                        response = self.logs.get_log_events(
                            logGroupName=log_group_name,
                            logStreamName=job_desc["container"]["logStreamName"]
                        )
                        for log_event in response["events"]:
                            print(log_event["message"], file=sys.stderr)
                seen_events.add(event["id"])

        resp = self.sqs.receive_message(
            QueueUrl=self.state_change_queue_url,
            MaxNumberOfMessages=n_stages,
        )
        print(resp)
        messages = resp["Messages"]

        if expect_success:
            self.assertEqual(description["status"], "SUCCEEDED", description)
        else:
            self.assertEqual(description["status"], "FAILED", description)
        return arn, description, messages, step_notifications

    def test_simple_sfn_wdl_workflow(self):
        output_prefix = "out-1"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        arn, description, messages, step_notifications = self._wait_sfn(sfn_input, self.single_sfn_arn)

        output = json.loads(description["output"])
        self.assertEqual(output["Result"], {
          "swipe_test.out_world": f"s3://{self.input_obj.bucket_name}/{output_prefix}/test-1/out_world.txt",
          "swipe_test.out_goodbye": f"s3://{self.input_obj.bucket_name}/{output_prefix}/test-1/out_goodbye.txt",
          "swipe_test.out_farewell": f"s3://{self.input_obj.bucket_name}/{output_prefix}/test-1/out_farewell.txt",
        })

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out_world.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        self.assertEqual(output_text, "hello\nworld\n")

        self.assertEqual(json.loads(messages[0]["Body"])["detail"]["executionArn"], arn)
        self.assertEqual(
            json.loads(messages[0]["Body"])["detail"]["lastCompletedStage"], "run"
        )
        self.assertEqual(
            # TODO: bc of download caching this value can change, figure out if you want it to change or not
            len(step_notifications), 3
        )

    def test_https_inputs(self):
        output_prefix = "out-https-1"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": "https://raw.githubusercontent.com/chanzuckerberg/czid-workflows/main/README.md",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        self._wait_sfn(sfn_input, self.single_sfn_arn)

    def test_failing_wdl_workflow(self):
        output_prefix = "out-fail-1"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_fail_obj.bucket_name}/{self.wdl_fail_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        arn, description, messages, _ = self._wait_sfn(sfn_input, self.single_sfn_arn, expect_success=False)
        errorType = (self.sfn.get_execution_history(executionArn=arn)["events"]
                     [-1]["executionFailedEventDetails"]["error"])
        self.assertTrue(errorType in ["UncaughtError", "RunFailed"])

    def test_temp_tag(self):
        output_prefix = "out-temp-tag"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_obj_temp.bucket_name}/{self.wdl_obj_temp.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        self._wait_sfn(sfn_input, self.single_sfn_arn)

        # test temporary tag is there for intermediate file
        temporary_tagset = self.s3_client.get_object_tagging(
          Bucket="swipe-test",
          Key=f"{output_prefix}/test-temp-1/temporary.txt"
        ).get("TagSet", [])
        self.assertEqual(len(temporary_tagset), 1)
        self.assertEqual(temporary_tagset[0].get("Key"), "intermediate_output")
        self.assertEqual(temporary_tagset[0].get("Value"), "true")

        # test temporary tag got removed for output file
        output_tagset = self.s3_client.get_object_tagging(
          Bucket="swipe-test",
          Key=f"{output_prefix}/test-temp-1/out_world.txt"
        ).get("TagSet", [])
        self.assertEqual(len(output_tagset), 0)

    def test_staged_sfn_wdl_workflow(self):
        output_prefix = "out-2"
        sfn_input: Dict[str, Any] = {
            "ONE_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_obj.key}",
            "TWO_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_two_obj.key}",
            "STAGES_IO_MAP_JSON": f"s3://{self.wdl_obj.bucket_name}/{self.map_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "One": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                },
                "Two": {
                    "docker_image_id": "ubuntu",
                },
            },
        }

        _, _, messages, _ = self._wait_sfn(sfn_input, self.stage_sfn_arn, 2)

        outputs_obj = self.test_bucket.Object(
            f"{output_prefix}/test-1/happy_message.txt"
        )
        output_text = outputs_obj.get()["Body"].read().decode()
        self.assertEqual(output_text, "hello\nworld\n:)\n")

        self.assertEqual(
            json.loads(messages[0]["Body"])["detail"]["lastCompletedStage"], "one"
        )
        self.assertEqual(
            json.loads(messages[1]["Body"])["detail"]["lastCompletedStage"], "two"
        )

    def test_call_cache(self):
        output_prefix = "out-3"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        out_json_path = f"{output_prefix}/test-1/run_output.json"

        self._wait_sfn(sfn_input, self.single_sfn_arn)
        self.sqs.receive_message(
            QueueUrl=self.state_change_queue_url, MaxNumberOfMessages=1
        )
        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out_world.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        self.assertEqual(output_text, "hello\nworld\n")

        self.test_bucket.Object(f"{output_prefix}/test-1/out_goodbye.txt").put(
            Body="cache_break\n".encode()
        )
        self.test_bucket.Object(f"{output_prefix}/test-1/out_farewell.txt").delete()

        # clear cache to simulate getting cut off the step before this one
        objects = self.s3_client.list_objects_v2(
          Bucket=self.test_bucket.name,
          Prefix=f"{output_prefix}/test-1/cache/add_farewell/",
        )["Contents"]
        self.test_bucket.Object(objects[0]["Key"]).delete()
        objects = self.s3_client.list_objects_v2(
          Bucket=self.test_bucket.name,
          Prefix=f"{output_prefix}/test-1/cache/swipe_test/",
        )["Contents"]
        self.test_bucket.Object(objects[0]["Key"]).delete()
        self.test_bucket.Object(out_json_path).delete()

        self._wait_sfn(sfn_input, self.single_sfn_arn)

        outputs = json.loads(self.test_bucket.Object(out_json_path).get()["Body"].read().decode())
        for v in outputs.values():
            self.assert_(v.startswith("s3://"), f"{v} does not start with 's3://'")

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out_farewell.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        self.assertEqual(output_text, "cache_break\nfarewell\n")

    def test_zip_wdls(self):
        output_prefix = "zip-output"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_zip_object.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "starter_string": "starter",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        self._wait_sfn(sfn_input, self.single_sfn_arn)
        self.sqs.receive_message(
          QueueUrl=self.state_change_queue_url, MaxNumberOfMessages=1
        )

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out_bar.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        self.assertEqual(output_text, "starter\nfoo\nbar\n")

    def test_status_reporting(self):
        output_prefix = "out-4"
        sfn_input: Dict[str, Any] = {
            "RUN_WDL_URI": f"s3://{self.wdl_obj.bucket_name}/{self.wdl_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        self._wait_sfn(sfn_input, self.single_sfn_arn)

        status_json = json.loads(
            self.test_bucket.Object(
                f"{output_prefix}/test-1/test_status2.json",
            ).get()["Body"].read().decode(),
        )
        self.assertEqual(status_json["add_world"]["status"], "uploaded")
        self.assertEqual(status_json["add_goodbye"]["status"], "uploaded")


if __name__ == "__main__":
    unittest.main()
