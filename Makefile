S3_CP_ARGS=aws s3 cp --acl public-read
PARAMS ?= "check https://docs.observeinc.com/en/latest/content/integrations/azure/azure.html"
VERSION ?= "should be set by github environment"

.PHONY: changelog
changelog:
	git-chglog -o CHANGELOG.md --next-tag `semtag final -s minor -o`

.PHONY: release
release: build
#   semtag final -s minor
	$(S3_CP_ARGS) main.json s3://observeinc/azure/resourcemanager-${VERSION}.json
	$(S3_CP_ARGS) main.json s3://observeinc/azure/resourcemanager-latest.json

# Dev command
.PHONY: validate
validate: build
	az deployment sub validate \
  --location westus \
  --template-file main.json \
  --parameters $(PARAMS)

# Dev command
.PHONY: deploy
deploy: build
	az deployment sub create \
  --name observe-arm-${USER} \
  --location westus \
  --template-file main.json \
  --parameters $(PARAMS)

# Dev command
.PHONY: undeploy
undeploy:
	az deployment sub delete --name observe-arm-${USER}
	# If desired, manually delete the resource group and the "Monitoring Reader" role assignment for the App Registration

.PHONY: build
build:
	az bicep build --file main.bicep
