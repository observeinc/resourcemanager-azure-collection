S3_CP_ARGS=aws s3 cp --acl public-read

OBSERVE_CUSTOMER ?= 101
OBSERVE_TOKEN ?= "not-a-real-token"
OBSERVE_DOMAIN ?= observe-eng.com

.PHONY: changelog
changelog:
	git-chglog -o CHANGELOG.md --next-tag `semtag final -s minor -o`

.PHONY: release
release: build
	semtag final -s minor
	$(S3_CP_ARGS) main.json s3://observeinc/azure/resourcemanager-`semtag getcurrent`.json
	$(S3_CP_ARGS) main.json s3://observeinc/azure/resourcemanager-latest.json

# Dev command
.PHONY: validate
validate: build
	az deployment sub validate \
  --location westus \
  --template-file main.json \
  --parameters \
		observe_customer="$(OBSERVE_CUSTOMER)" \
		observe_token="$(OBSERVE_TOKEN)" \
		observe_domain="$(OBSERVE_DOMAIN)" \
		location="westus3" \
		objectId=6bb2971a-0579-49c8-bd59-8d0bcc91ccf9 \
		clientSecretId=7e1dba81-d526-4e52-8d63-3c5e6dc4a48f \
		clientSecretValue=gCs8Q~I1STWEhs77XK68PUo76nq9Kn~r7mSbNb9J \
		enterpriseAppObjectId=2638cb1f-6ef2-473e-b43c-3282b08b4934

# Dev command
.PHONY: deploy
deploy: build
	az deployment sub create \
  --name observe-arm-${USER} \
  --location westus \
  --template-file main.json \
  --parameters \
		observe_customer="$(OBSERVE_CUSTOMER)" \
		observe_token="$(OBSERVE_TOKEN)" \
		observe_domain="$(OBSERVE_DOMAIN)" \
		location="westus3" \
		objectId=6bb2971a-0579-49c8-bd59-8d0bcc91ccf9 \
		clientSecretId=7e1dba81-d526-4e52-8d63-3c5e6dc4a48f \
		clientSecretValue=gCs8Q~I1STWEhs77XK68PUo76nq9Kn~r7mSbNb9J \
		enterpriseAppObjectId=2638cb1f-6ef2-473e-b43c-3282b08b4934

# Dev command
.PHONY: undeploy
undeploy:
	az deployment sub delete --name observe-arm-${USER}
	# If desired, manually delete the resource group and the "Monitoring Reader" role assignment for the App Registration

.PHONY: build
build:
	az bicep build --file main.bicep
