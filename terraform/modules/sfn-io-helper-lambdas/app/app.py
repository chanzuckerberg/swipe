import json


def preprocess_input(sfn_data, _):
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "foo ": "bar",
        })
    }


def process_stage_output(sfn_data, _):
    return "{}"


def handle_success(sfn_data, _):
    return "{}"


def handle_failure(sfn_data, _):
    pass


def process_batch_event(event):
    pass


def process_sfn_event(event):
    pass


def report_metrics(event):
    pass


def report_spot_interruption(event):
    pass
