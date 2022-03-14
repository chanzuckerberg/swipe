SHELL=/bin/bash -o pipefail

deploy-mock:
	- source environment.test; aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	source environment.test; \
	cd test/terraform/moto; \
	unset TF_CLI_ARGS_init; \
	terraform init; \
	terraform apply --auto-approve

up: start deploy-mock

start:
	source environment.test; \
	docker build --cache-from ghcr.io/chanzuckerberg/swipe:latest -t ghcr.io/chanzuckerberg/swipe:$$(cat version) .; \
	docker-compose up -d

clean:
	docker-compose down
	docker-compose rm
	find test/terraform -name '*tfstate*' | xargs rm -f

lint:
	flake8 .
	yq . terraform/modules/swipe-sfn/default-wdl.yml > single-wdl.json
	statelint single-wdl.json
	mypy --check-untyped-defs --no-strict-optional .

format:
	terraform fmt --recursive .

test:
	source environment.test; \
	python3 -m unittest discover .

get-logs:
	aegea logs --start-time=-5m --no-export /aws/lambda/$(app_name)

debug:
	echo "Lambda Logs"
	source environment.test; \
	for i in $$(aws --endpoint-url http://localhost:9000 logs describe-log-groups | jq -r '.logGroups[].logGroupName'); do \
		echo; \
		echo; \
		echo "Log group: $$i"; \
		aws --endpoint-url http://localhost:9000 logs tail $$i; \
	done;

.PHONY: deploy up clean debug start init-tf lint format test get-logs
