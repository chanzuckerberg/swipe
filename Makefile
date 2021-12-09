SHELL=/bin/bash -o pipefail

deploy-mock:
	aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	cp test/mock.tf .; unset TF_CLI_ARGS_init; terraform init; TF_VAR_mock=true TF_VAR_app_name=swipe-test TF_VAR_batch_ec2_instance_types='["optimal"]' terraform apply --auto-approve

$(TFSTATE_FILE):
	terraform state pull > $(TFSTATE_FILE)

lint:
	flake8 .
	yq . terraform/modules/swipe-sfn/default-wdl.yml > single-wdl.json
	statelint single-wdl.json
	mypy --check-untyped-defs --no-strict-optional --exclude .venv --exclude vendor .

format:
	terraform fmt --recursive .

test:
	python -m unittest discover .

get-logs:
	aegea logs --start-time=-5m --no-export /aws/lambda/$(app_name)

.PHONY: deploy init-tf lint format test
