import os
import sys
import json
import time
import unittest
from typing import Dict, Any


import boto3


test_wdl = """
version 1.0
task idseq_test {
  input {
    Int x = 0
  }
  command {
    :
  }
  output {
    Int y = x + 1
  }
}
"""


class TestSFNWDL(unittest.TestCase):
    def setUp(self) -> None:
        self.s3 = boto3.resource("s3", endpoint_url="http://localhost:9000")
        self.sfn = boto3.client("stepfunctions", endpoint_url="http://localhost:9000")
        self.test_bucket = self.s3.create_bucket(Bucket="swipe-test")
        self.lamb = boto3.client("lambda", endpoint_url="http://localhost:9000")

    def test_simple_sfn_wdl_workflow(self):
        response = self.lamb.invoke(
            FunctionName="swipe-test-preprocess_input",
            InvocationType="RequestResponse",
            Payload=b'{}',
        )
        print("AAAAAAAAAAAAAAAAAAAAAAAAAA", response, response["Payload"].read(), file=sys.stderr)

        wdl_obj = self.test_bucket.Object("test.wdl")
        wdl_obj.put(Body=test_wdl.encode())
        sfn_input: Dict[str, Any] = {
          "RUN_WDL_URI": f"s3://{wdl_obj.bucket_name}/{wdl_obj.key}",
        }

        outputs_obj = self.test_bucket.Object("output.json")
        sfn_input["OutputPrefix"] = f"s3://{outputs_obj.bucket_name}/{os.path.dirname(outputs_obj.key)}"

        execution_name = "idseq-test-{}".format(int(time.time()))
        sfn_arn = self.sfn.list_state_machines()["stateMachines"][0]["stateMachineArn"]
        res = self.sfn.start_execution(stateMachineArn=sfn_arn,
                                       name=execution_name,
                                       input=json.dumps(sfn_input))

        arn = res["executionArn"]
        assert res

        start = time.time()
        description = self.sfn.describe_execution(executionArn=arn)
        while description["status"] == "RUNNING" and time.time() < start + 10 * 60:
            time.sleep(10)
            description = self.sfn.describe_execution(executionArn=arn)
            for event in self.sfn.get_execution_history(executionArn=arn)["events"]:
                print(event, file=sys.stderr)
            print("AAAAAAAAAAAAAAAAAAAAAAAAAA", file=sys.stderr)

        assert description["status"] == "SUCCEEDED", description


if __name__ == "__main__":
    unittest.main()
