import sys
import json
import time
import unittest
from typing import Dict, Any


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
        self.wdl_two_obj = self.test_bucket.Object("test-two-v1.0.0.wdl")
        self.wdl_two_obj.put(Body=test_two_wdl.encode())
        self.map_obj = self.test_bucket.Object("stage_io_map.json")
        self.map_obj.put(Body=json.dumps(test_stage_io_map).encode())
        self.input_obj = self.test_bucket.Object("input.txt")
        self.input_obj.put(Body=test_input.encode())
        state_machines = self.sfn.list_state_machines()["stateMachines"]
        self.single_sfn_arn = [sfn["stateMachineArn"] for sfn in state_machines if "default" in sfn["name"]][0]
        self.stage_sfn_arn = [sfn["stateMachineArn"] for sfn in state_machines if "stage-test" in sfn["name"]][0]
        self.state_change_queue_url = self.sqs.list_queues()["QueueUrls"][0]

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
          }
        }

        execution_name = "swipe-test-{}".format(int(time.time()))
        res = self.sfn.start_execution(stateMachineArn=self.single_sfn_arn,
                                       name=execution_name,
                                       input=json.dumps(sfn_input))

        arn = res["executionArn"]
        start = time.time()
        description = self.sfn.describe_execution(executionArn=arn)
        while description["status"] == "RUNNING" and time.time() < start + 2 * 60:
            time.sleep(10)
            description = self.sfn.describe_execution(executionArn=arn)
        print("printing execution history", file=sys.stderr)
        for event in self.sfn.get_execution_history(executionArn=arn)["events"]:
            print(event, file=sys.stderr)

        self.assertEqual(description["status"], "SUCCEEDED")

        output = json.loads(description["output"])
        output_path = f"s3://{self.input_obj.bucket_name}/{output_prefix}/test-1/out.txt"
        self.assertEqual(output["Result"], {"swipe_test.out": output_path})

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out.txt")
        output_text = outputs_obj.get()['Body'].read().decode()
        self.assertEqual(output_text, "hello\nworld\n")

        res = self.sqs.receive_message(QueueUrl=self.state_change_queue_url)
        self.assertEqual(json.loads(res["Messages"][0]["Body"])["detail"]["lastCompletedStage"], "run")

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
              }
          }
        }

        execution_name = "swipe-test-{}".format(int(time.time()))
        res = self.sfn.start_execution(stateMachineArn=self.stage_sfn_arn,
                                       name=execution_name,
                                       input=json.dumps(sfn_input))

        arn = res["executionArn"]
        start = time.time()
        description = self.sfn.describe_execution(executionArn=arn)
        while description["status"] == "RUNNING" and time.time() < start + 2 * 60:
            time.sleep(10)
            description = self.sfn.describe_execution(executionArn=arn)
        print("printing execution history", file=sys.stderr)
        for event in self.sfn.get_execution_history(executionArn=arn)["events"]:
            print(event, file=sys.stderr)

        self.assertEqual(description["status"], "SUCCEEDED")

        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/happy_message.txt")
        output_text = outputs_obj.get()['Body'].read().decode()
        self.assertEqual(output_text, "hello\nworld\n:)\n")

        res = self.sqs.receive_message(QueueUrl=self.state_change_queue_url)
        self.assertEqual(json.loads(res["Messages"][0]["Body"])["detail"]["lastCompletedStage"], "one")
        self.assertEqual(json.loads(res["Messages"][0]["Body"])["detail"]["lastCompletedStage"], "two")

if __name__ == "__main__":
    unittest.main()
