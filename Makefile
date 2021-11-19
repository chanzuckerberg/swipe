SHELL=/bin/bash -o pipefail

ifndef DEPLOYMENT_ENVIRONMENT
$(error Please run "source environment" in the repo root directory before running make commands)
endif

init-tf:
	-rm -f $(TF_DATA_DIR)/*.tfstate
	mkdir -p $(TF_DATA_DIR)
	jq -n ".region=\"us-west-2\" | .bucket=env.TF_S3_BUCKET | .key=env.APP_NAME+env.DEPLOYMENT_ENVIRONMENT" > $(TF_DATA_DIR)/aws_config.json
	terraform init

deploy: init-tf
	@if [[ $(DEPLOYMENT_ENVIRONMENT) == staging && $$(git symbolic-ref --short HEAD) != staging ]]; then echo Please deploy staging from the staging branch; exit 1; fi
	@if [[ $(DEPLOYMENT_ENVIRONMENT) == prod && $$(git symbolic-ref --short HEAD) != prod ]]; then echo Please deploy prod from the prod branch; exit 1; fi
	TF_VAR_APP_NAME=$(APP_NAME) TF_VAR_DEPLOYMENT_ENVIRONMENT=$(DEPLOYMENT_ENVIRONMENT) TF_VAR_BATCH_SSH_PUBLIC_KEY='$(BATCH_SSH_PUBLIC_KEY)' terraform apply

deploy-mock:
	aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	cp test/mock.tf .; unset TF_CLI_ARGS_init; terraform init; terraform apply --auto-approve

$(TFSTATE_FILE):
	terraform state pull > $(TFSTATE_FILE)

lint:
	flake8 .
	yq . terraform/modules/swipe-sfn/sfn-templates/single-wdl.yml > single-wdl.json
	statelint single-wdl.json
	mypy --check-untyped-defs --no-strict-optional .

format:
	terraform fmt --recursive .

test:
	python -m unittest discover .

get-logs:
	aegea logs --start-time=-5m --no-export /aws/lambda/$(APP_NAME)-$(DEPLOYMENT_ENVIRONMENT)

.PHONY: deploy init-tf lint format test
