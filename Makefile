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
	TF_VAR_APP_NAME=$(APP_NAME) TF_VAR_DEPLOYMENT_ENVIRONMENT=$(DEPLOYMENT_ENVIRONMENT) TF_VAR_OWNER=$(OWNER) TF_VAR_BATCH_SSH_PUBLIC_KEY='$(BATCH_SSH_PUBLIC_KEY)' terraform apply

deploy-mock:
	aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	cp test/mock.tf .; unset TF_CLI_ARGS_init; terraform init; terraform apply --auto-approve

$(TFSTATE_FILE):
	terraform state pull > $(TFSTATE_FILE)

sfn-io-helper-lambdas:
	rm -r sfn-io-helper-lambdas-tmp || true
	git rev-parse HEAD:terraform/modules/sfn-io-helper-lambdas/app > terraform/modules/sfn-io-helper-lambdas/package-hash
	cp -r terraform/modules/sfn-io-helper-lambdas/app/ sfn-io-helper-lambdas-tmp
	pip install --target sfn-io-helper-lambdas-tmp -r sfn-io-helper-lambdas-tmp/requirements.txt
	zip -r terraform/modules/sfn-io-helper-lambdas/deployment.zip sfn-io-helper-lambdas-tmp
	rm -r sfn-io-helper-lambdas-tmp

check-sfn-io-helper-lambdas:
	git rev-parse HEAD:terraform/modules/sfn-io-helper-lambdas/app > terraform/modules/sfn-io-helper-lambdas/package-hash
	git diff --exit-code || (echo 'Uncomitted changes to sfn-io-helper-lambdas page, please run: `make sfn-io-helper-lambdas` and commit the result' && exit 1)

lint:
	flake8 .
	yq . terraform/modules/swipe-sfn/sfn-templates/single-wdl.yml > single-wdl.json
	statelint single-wdl.json
	mypy --check-untyped-defs --no-strict-optional .

test:
	python -m unittest discover .

get-logs:
	aegea logs --start-time=-5m --no-export /aws/lambda/$(APP_NAME)-$(DEPLOYMENT_ENVIRONMENT)

.PHONY: deploy init-tf sfn-io-helper-lambdas check-sfn-io-helper-lambdas lint test
