AWSCLI := $(shell /usr/bin/which aws)
ACCOUNTID := `$(AWSCLI) sts get-caller-identity --query 'Account' --output text`
PIP := $(shell /usr/bin/which pip)

APP_NAME = ParamterStore

STACKNAME := $(ENV_NAME)-$(APP_NAME)-stack
UPDATESYSTEMNAME := $(ENV_NAME)-Update-CFn-stack
BUCKET_NAME := ci-$(ACCOUNTID)-deploy
TESTSTACKNAME := $(ENV_NAME)-Customer-stack

ifeq ($(PHASE),)
	PHASE = prod
else
	PHASE = $(PHASE)
endif


lib.update:
	@$(PIP) install awscli==1.16.289 aws-sam-cli==0.35.0

deploy:
	@echo "ENV_NAME: $(ENV_NAME)"
	@echo "PHASE: $(PHASE)"
	@echo "Deploy parameter store"; \
	make deploy.secure_string; \
	make param.package; \
	make param.deploy;
	@echo "Deploy complete"

undeploy:
	@echo Undeploy stack
	@make cfn.sam.undeploy

create.layer:
	@$(shell mkdir python)
	@$(PIP) install -r requirements.txt -t ./python
	@zip -r parameterstore-stack-python.zip ./python

param.package:
	@$(AWSCLI) \
		cloudformation package \
			--template-file Template/parameter.yml \
			--output-template-file Template/package.yml \
			--s3-bucket $(BUCKET_NAME)

param.deploy:
	@$(AWSCLI) \
		cloudformation deploy \
			--template-file Template/package.yml \
			--stack-name $(STACKNAME) \
			--capabilities CAPABILITY_NAMED_IAM \
			--no-fail-on-empty-changeset \
			--parameter-overrides EnvName=$(ENV_NAME) Phase=$(PHASE)
	@$(AWSCLI) cloudformation describe-stacks --stack-name $(STACKNAME)

param.undeploy:
	@$(AWSCLI) \
		cloudfomation delete-stack --stack-name $(STACKNAME)
	@$(AAWSCLI) cloudformation wait stack-delete-complete --stack-name $(STACKNAME)

sam.package:
	#@make create.layer
	@sam package --template-file Template/template.yml \
		--output-template-file Template/package-lambda.yml \
		--s3-bucket $(BUCKET_NAME) \
		--region ap-northeast-1

sam.deploy:
	@sam deploy --template-file Template/package-lambda.yml \
		--stack-name $(UPDATESYSTEMNAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--s3-bucket $(BUCKET_NAME) \
		--region ap-northeast-1 \
		--parameter-overrides EnvName=$(ENV_NAME) Phase=$(PHASE) NotifyEmail=$(NotifyEmail)

sam.undeploy:
	@$(AWSCLI) cloudformation delete-stack --stack-name $(UPDATESYSTEMNAME)
	@$(AWSCLI) cloudformation wait stack-delete-complete --stack-name $(UPDATESYSTEMNAME)

deploy.secure_string:
	@$(AWSCLI) ssm put-parameter \
		--name webhookURL \
		--value ${WEBHOOKURL} \
		--type SecureString \
		--overwrite

create.bucket:
	@echo $(ACCOUNTID)
	@$(AWSCLI) s3 mb s3://ci-$(ACCOUNTID)-deploy

test.package:
	@$(AWSCLI) \
		cloudformation package \
			--template-file Template/test-template.yml \
			--output-template-file Template/test-package.yml \
			--s3-bucket $(BUCKET_NAME)

test.deploy:
	@$(AWSCLI) \
		cloudformation deploy \
			--template-file Template/test-package.yml \
			--stack-name $(TESTSTACKNAME) \
			--capabilities CAPABILITY_NAMED_IAM \
			--no-fail-on-empty-changeset \
			--parameter-overrides EnvName=$(ENV_NAME) Phase=$(PHASE) \
				LambdaMemorySize=/Cloud/$(PHASE)/Customer/LambdaMemorySize \
    			LambdaTimeout=/Cloud/$(PHASE)/Customer/LambdaTimeout
	@$(AWSCLI) cloudformation describe-stacks --stack-name $(TESTSTACKNAME)

test.undeploy:
	@$(AWSCLI) \
		cloudfomation delete-stack --stack-name $(TESTSTACKNAME)
	@$(AAWSCLI) cloudformation wait stack-delete-complete --stack-name $(TESTSTACKNAME)