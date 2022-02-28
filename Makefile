SHELL=/bin/bash -o pipefail

deploy-mock:
	rm terraform.tfstate || true
	aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	cp test/mock.tf .; unset TF_CLI_ARGS_init; terraform init; TF_VAR_mock=true TF_VAR_app_name=swipe-test TF_VAR_batch_ec2_instance_types='["optimal"]' TF_VAR_call_cache=true TF_VAR_sqs_queues='{"notifications":{"dead_letter": false}}' TF_VAR_sfn_template_files='{"stage-test":"test/stage-test.yml"}' TF_VAR_stage_memory_defaults='{"Run": {"spot": 12800, "on_demand": 256000}, "One": {"spot": 12800, "on_demand": 256000}, "Two": {"spot": 12800, "on_demand": 256000}}' terraform apply --auto-approve

lint:
	flake8 .
	yq . terraform/modules/swipe-sfn/default-wdl.yml > single-wdl.json
	statelint single-wdl.json
	mypy --check-untyped-defs --no-strict-optional .

format:
	terraform fmt --recursive .

test:
	python -m unittest discover .

get-logs:
	aegea logs --start-time=-5m --no-export /aws/lambda/$(app_name)

.PHONY: deploy init-tf lint format test
