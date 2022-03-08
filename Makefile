SHELL=/bin/bash -o pipefail

deploy-mock:
	- source environment.test; aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	source environment.test && \
	cd test/terraform/moto && \
	mkdir -p tmp && \
	unset TF_CLI_ARGS_init && \
	terraform init && \
	terraform apply --auto-approve

deploy-localstack:
	- source environment.test; aws ssm put-parameter --name /mock-aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id --value ami-12345678 --type String --endpoint-url http://localhost:9000
	source environment.test && \
	cd test/terraform/localstack && \
	mkdir -p tmp && \
	unset TF_CLI_ARGS_init && \
	terraform init && \
	terraform apply --auto-approve

up: image start deploy-mock

localstack-test: image start-localstack wait-for-healthy deploy-localstack test

image:
	source environment.test; \
	docker build --cache-from ghcr.io/chanzuckerberg/swipe:latest -t ghcr.io/chanzuckerberg/swipe:$$(cat version) .

wait-for-healthy:
	while true; do \
	    curl -s -m 1 http://localhost:9000; \
	    if [ $$? -eq 0 ]; then \
	        break; \
	    fi; \
	    echo "waiting..."; \
	    sleep 1; \
	done

start:
	source environment.test; \
	docker compose up -d

start-localstack:
	source environment.test; \
	docker compose up -d localstack

clean:
	docker compose --profile '*' down
	docker compose --profile '*' rm
	rm -rf test/terraform/moto/tmp
	rm -rf test/terraform/localstack/tmp
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

.PHONY: deploy up clean debug start init-tf lint format test get-logs deploy-localstack wait-for-healthy localstack image start-localstack
