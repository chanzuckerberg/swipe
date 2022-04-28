import json
import sys
import time
import unittest
from typing import Any, Dict, List, Tuple

import boto3

test_wdl = """
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

  call add_goodbye {
    input:
      hello_world = add_world.out,
      docker_image_id = docker_image_id
  }

  output {
    File out = add_world.out
    File out_goodbye = out_goodbye.out_goodbye
  }
}

task add_world {
  input {
    File hello
    String docker_image_id
  }

  command <<<
    cat ~{hello} > out.txt
    echo world >> out.txt
  >>>

  output {
    File out = "out.txt"
  }

  runtime {
      docker: docker_image_id
  }
}

task add_goodbye {
  input {
    File hello_world
    String docker_image_id
  }

  command <<<
    cat ~{hello_world} > out_goodbye.txt
    echo goodbye >> out_goodbye.txt
  >>>

  output {
    File out_goodbye = "out_goodbye.txt"
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
        "hello_world": "out",
    },
}

test_input = """hello
"""


class TestSFNWDL(unittest.TestCase):
    def setUp(self) -> None:
        self.s3 = boto3.resource("s3", endpoint_url="http://localhost:9000")
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
        self.state_change_queue_url = self.sqs.list_queues()["QueueUrls"][0]

        # Empty the SQS queue before running tests.
        _ = self.sqs.purge_queue(QueueUrl=self.state_change_queue_url)

    def tearDown(self) -> None:
        self.test_bucket.delete_objects(
            Delete={
                "Objects": [{"Key": obj.key} for obj in self.test_bucket.objects.all()],
            }
        )
        self.test_bucket.delete()

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
        assert res
        start = time.time()
        description = self.sfn.describe_execution(executionArn=arn)
        while description["status"] == "RUNNING" and time.time() < start + 2 * 60:
            time.sleep(10)
            description = self.sfn.describe_execution(executionArn=arn)
        print("printing execution history", file=sys.stderr)
        for event in self.sfn.get_execution_history(executionArn=arn)["events"]:
            print(event, file=sys.stderr)

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
        return arn, description, messages

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

        arn, description, messages = self._wait_sfn(sfn_input, self.single_sfn_arn)

        output = json.loads(description["output"])
        output_path = (
            f"s3://{self.input_obj.bucket_name}/{output_prefix}/test-1/out.txt"
        )
        self.assertEqual(output["Result"], {"swipe_test.out": output_path})

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        self.assertEqual(output_text, "hello\nworld\n")

        self.assertEqual(json.loads(messages[0]["Body"])["detail"]["executionArn"], arn)
        self.assertEqual(
            json.loads(messages[0]["Body"])["detail"]["lastCompletedStage"], "run"
        )

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

        arn, description, messages = self._wait_sfn(sfn_input, self.single_sfn_arn, expect_success=False)
        errorType = (self.sfn.get_execution_history(executionArn=arn)["events"]
                     [-1]["executionFailedEventDetails"]["error"])
        self.assertTrue(errorType in ["UncaughtError", "RunFailed"])

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

        _, _, messages = self._wait_sfn(sfn_input, self.stage_sfn_arn, 2)

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
            "RUN_WDL_URI": f"s3://{self.wdl_two_obj.bucket_name}/{self.wdl_two_obj.key}",
            "OutputPrefix": f"s3://{self.input_obj.bucket_name}/{output_prefix}",
            "Input": {
                "Run": {
                    "hello": f"s3://{self.input_obj.bucket_name}/{self.input_obj.key}",
                    "docker_image_id": "ubuntu",
                }
            },
        }

        self._wait_sfn(sfn_input, self.single_sfn_arn)
        self.sqs.receive_message(
            QueueUrl=self.state_change_queue_url, MaxNumberOfMessages=1
        )
        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        assert output_text == "hello\nworld\n", output_text

        self.test_bucket.Object(f"{output_prefix}/test-1/out.txt").put(
            Body="cache_break\n".encode()
        )
        self._wait_sfn(sfn_input, self.single_sfn_arn)

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out_goodbye.txt")
        output_text = outputs_obj.get()["Body"].read().decode()
        assert output_text == "cache_break\ngoodbye", output_text


if __name__ == "__main__":
    unittest.main()
