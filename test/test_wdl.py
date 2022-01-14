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

test_input = """hello
"""


class TestSFNWDL(unittest.TestCase):
    def setUp(self) -> None:
        self.s3 = boto3.resource("s3", endpoint_url="http://localhost:9000")
        self.sfn = boto3.client("stepfunctions", endpoint_url="http://localhost:8083")
        self.test_bucket = self.s3.create_bucket(Bucket="swipe-test")
        self.lamb = boto3.client("lambda", endpoint_url="http://localhost:9000")

    def test_simple_sfn_wdl_workflow(self):
        wdl_obj = self.test_bucket.Object("test.wdl")
        wdl_obj.put(Body=test_wdl.encode())
        input_obj = self.test_bucket.Object("input.txt")
        input_obj.put(Body=test_input.encode())
        output_prefix = "out"
        sfn_input: Dict[str, Any] = {
          "RUN_WDL_URI": f"s3://{wdl_obj.bucket_name}/{wdl_obj.key}",
          "OutputPrefix": f"s3://{input_obj.bucket_name}/{output_prefix}",
          "Input": {
              "Run": {
                  "hello": f"s3://{input_obj.bucket_name}/{input_obj.key}",
                  "docker_image_id": "ubuntu",
              }
          }
        }

        execution_name = "swipe-test-{}".format(int(time.time()))
        sfn_arn = self.sfn.list_state_machines()["stateMachines"][0]["stateMachineArn"]
        res = self.sfn.start_execution(stateMachineArn=sfn_arn,
                                       name=execution_name,
                                       input=json.dumps(sfn_input))

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

        assert description["status"] == "SUCCEEDED", description
        outputs_obj = self.test_bucket.Object(f"{output_prefix}/test-1/out.txt")
        output_text = outputs_obj.get()['Body'].read().decode()
        assert output_text == "hello\nworld\n", output_text


if __name__ == "__main__":
    unittest.main()
