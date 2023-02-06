targetScope = 'resourceGroup'

param observe_customer string
@secure()
param observe_token string
param observe_domain string
param timer_resources_func_schedule string
param timer_vm_metrics_func_schedule string
param func_url string
param location string
param location_abbreviation object

param objectId string
#disable-next-line secure-secrets-in-params
param clientSecretId string
@secure()
param clientSecretValue string

param sub string

var region = location_abbreviation[location]
var keyvault_name = '${region}${observe_customer}${sub}'

// https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-bicep
resource key_vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyvault_name
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }

    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: objectId
        permissions: {
          secrets: [
            'backup'
            'restore'
            'get'
            'set'
            'list'
            'delete'
            'purge'
          ]
        }
      }, {
        tenantId: tenant().tenantId
        objectId: website.identity.principalId
        permissions: {
          secrets: [
            'backup'
            'restore'
            'get'
            'set'
            'list'
            'delete'
            'purge'
          ]
        }
      }
    ]
  }

  resource azurerm_key_vault_secret_observe_token 'secrets@2022-07-01' = {
    name: 'observe-token'
    properties: {
      value: observe_token
    }
  }
}

// EventHub
// https://learn.microsoft.com/en-us/azure/templates/microsoft.eventhub/namespaces?pivots=deployment-language-bicep
resource azurerm_eventhub_namespace_observe_eventhub_namespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: keyvault_name
  location: location
  sku: {
    name: 'Standard'
    capacity: 2
  }

  tags: {
    created_by: 'Observe Resource Manager'
  }

  // https://learn.microsoft.com/en-us/azure/templates/microsoft.eventhub/namespaces/eventhubs?pivots=deployment-language-bicep
  resource azurerm_eventhub_observe_eventhub 'eventhubs' = {
    name: 'observeEventHub-${observe_customer}-${location}-${sub}'
    properties: {
      partitionCount: 32
      messageRetentionInDays: 7
    }

    // https://learn.microsoft.com/en-us/azure/templates/microsoft.eventhub/namespaces/eventhubs/authorizationrules?pivots=deployment-language-bicep
    resource azurerm_eventhub_authorization_rule_observe_eventhub_access_policy 'authorizationRules' = {
      name: 'observeSharedAccessPolicy-${observe_customer}-${location}-${sub}'
      properties: {
        rights: [
          'Listen'
        ]
      }
    }
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.web/serverfarms?pivots=deployment-language-bicep
// Some params copied from https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.web/function-app-linux-consumption/main.bicep
resource azurerm_service_plan_observe_service_plan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'observeServicePlan-${observe_customer}${location}-${sub}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/2022-05-01/storageaccounts?pivots=deployment-language-bicep
// Some params copied from https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.web/function-app-linux-consumption/main.bicep
resource azurerm_storage_account_observe_storage_account 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: toLower('${observe_customer}${region}${sub}')
  location: location
  sku: {
    name: 'Standard_LRS' // Probably want to use ZRS when we got prime time
  }
  kind: 'StorageV2'

  resource blob 'blobServices' = {
    name: 'default'

    // https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/2022-05-01/storageaccounts/blobservices/containers?pivots=deployment-language-bicep
    resource azurerm_storage_container_observe_storage_container 'containers' = {
      name: toLower('container${observe_customer}${region}-${sub}')
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.web/sites?pivots=deployment-language-bicep
// Some params copied from https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.web/function-app-linux-consumption/main.bicep
resource website 'Microsoft.Web/sites@2022-03-01' = {
  name: 'observeApp-${observe_customer}-${location}-${sub}'
  location: location
  kind: 'functionapp,linux'

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    reserved: true
    serverFarmId: azurerm_service_plan_observe_service_plan.id
    siteConfig: {
      // az webapp list-runtimes --linux but with | instead of :
      linuxFxVersion: 'PYTHON|3.9'

      appSettings: [
        // storage_account_name and storage_account_access_key in terraform
        // Source provider {name: 'code', value: https://github.com/hashicorp/terraform-provider-azurerm/blob/4ce0783b21fd4c07c4160aae37e910a5a8708870/internal/services/appservice/helpers/function_app_schema.go#L1480}
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account_observe_storage_account.name};AccountKey=${azurerm_storage_account_observe_storage_account.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}' }

        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: func_url }
        { name: 'AzureWebJobsDisableHomepage', value: 'true' }
        { name: 'OBSERVE_DOMAIN', value: observe_domain }
        { name: 'OBSERVE_CUSTOMER', value: observe_customer }
        { name: 'OBSERVE_TOKEN', value: '@Microsoft.KeyVault(SecretUri=https://${keyvault_name}.vault.azure.net/secrets/observe-token/)' }
        { name: 'AZURE_TENANT_ID', value: tenant().tenantId }
        { name: 'AZURE_CLIENT_ID', value: clientSecretId }
        { name: 'AZURE_CLIENT_SECRET', value: clientSecretValue }
        { name: 'AZURE_CLIENT_LOCATION', value: toLower(replace(location, ' ', '')) }
        { name: 'timer_resources_func_schedule', value: timer_resources_func_schedule }
        { name: 'timer_vm_metrics_func_schedule', value: timer_vm_metrics_func_schedule }

        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }

        { name: 'EVENTHUB_TRIGGER_FUNCTION_EVENTHUB_NAME', value: azurerm_eventhub_namespace_observe_eventhub_namespace::azurerm_eventhub_observe_eventhub.name }
        { name: 'EVENTHUB_TRIGGER_FUNCTION_EVENTHUB_CONNECTION', value: azurerm_eventhub_namespace_observe_eventhub_namespace::azurerm_eventhub_observe_eventhub::azurerm_eventhub_authorization_rule_observe_eventhub_access_policy.listKeys().primaryConnectionString }
      ]
    }
  }
}
