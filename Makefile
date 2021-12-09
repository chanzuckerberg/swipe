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
	mypy --check-untyped-defs --no-strict-optional --exclude .venv .

format:
	terraform fmt --recursive .

test:
	python -m unittest discover .

get-logs:
	aegea logs --start-time=-5m --no-export /aws/lambda/$(app_name)

sfn-io-helper-lambdas:
	git add terraform/modules/sfn-io-helper-lambdas/app
	git commit -m "lambda commit"
	rm -r sfn-io-helper-lambdas-tmp || true
	git rev-parse HEAD:terraform/modules/sfn-io-helper-lambdas/app > terraform/modules/sfn-io-helper-lambdas/package-hash
	cp -r terraform/modules/sfn-io-helper-lambdas/app/ sfn-io-helper-lambdas-tmp
	pip install --target sfn-io-helper-lambdas-tmp -r sfn-io-helper-lambdas-tmp/requirements.txt
	cd sfn-io-helper-lambdas-tmp ; zip -r ../terraform/modules/sfn-io-helper-lambdas/deployment.zip *
	rm -r sfn-io-helper-lambdas-tmp

check-sfn-io-helper-lambdas:
	git rev-parse HEAD:terraform/modules/sfn-io-helper-lambdas/app > terraform/modules/sfn-io-helper-lambdas/package-hash
	git diff --exit-code || (echo 'Uncomitted changes to sfn-io-helper-lambdas page, please run: `make sfn-io-helper-lambdas` and commit the result' && exit 1)

.PHONY: deploy init-tf lint format test
