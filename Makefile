AWSCLI := $(shell /usr/bin/which aws)
ACCOUNTID := $(shell $(AWSCLI) sts get-caller-identity | grep Account | aws '{print $2}' | sed 's/[^0-9]//g')
PIP := $(shell /usr/bin/which pip)

APP_NAME = ParamterStore

STACKNAME := $(ENV_NAME)-$(APP_NAME)-stack
UPDATESYSTEMNAME := $(ENV_NAME)-Update-CFn-stack
BUCKET_NAME := ci-$(ACCOUNTID)-deploy

ifeq ($(PHASE),)
	PHASE = prod
else
	PHASE = $(PHASE)
endif

.PHONY: help
.DEFAULT_GOAL := help

lib.update:
	@$(PIP) install awscli==1.16.289 aws-sam-cli==0.35.0

deploy:
	@echo "ENV_NAME: $(ENV_NAME)"
	@echo "PHASE: $(PHASE)"
	@echo "Deploy parameter store"; \
	make cfn.package; \
	make cfn.deploy;
	@echo "Deploy complete"

undeploy:
	@echo Undeploy stack
	@make cfn.sam.undeploy

create.layer:
	@$(shelll mkdir python)
	@$(PIP) install -r requirementes.txt -t ./python
	@zip -r paramterstore-stack-python.zip ./python

cfn.package:
	@$(AWSCLI) \
		cloudformation package \
			--template-file paramter.yml
			--output-template-file package.yml \
			--s3-bucket $(BUCKET_NAME)

cfn.deploy:
	@$(AWSCLI) \
		cloudformation deploy \
			--template-file package.yml \
			--stack-name $(STACKNAME) \
			--capabilities CAPABILITY_NAMED_IAM \
			--no-fail-on-empty-changeset \
			--parameter-overrides EnvName=$(ENV_NAME) Phase=$(PHASE)
	@$(AWSCLI) cloudformation describe-stacks --stack-name $(STACKNAME)

cfn.undeploy:
	@$(AWSCLI) \
		cloudfomation delete-stack --stack-name $(STACKNAME)
	@$(AAWSCLI) cloudformation wait stack-delete-complete --stack-name $(STACKNAME)

sam.package:
	@make create.layer
	@sam package --template-file template.yml --output-template-file package-lambda.yml --s3-bucket (BUCKET_NAME) --region ap-northeast-1

sam.deploy:
	@sam deploy --template-file package-lambda.yml --stak-name $(UPDATESYSTEMNAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--s3-bucket $(BUCKET_NAME) \
		--region ap-northeast-1 \
		--parameter-overrides EnvName=$(ENV_NAME) Phase=$(PHASE) NotifyEmail=""

sam.undeploy:
	@$(AWSCLI) cloudformation delete-stack --stack-name $(UPDATESYSTEMNAME)
	@$(AWSCLI) cloudformation wait stack-delete-complete --stack-name $(UPDATESYSTEMNAME)