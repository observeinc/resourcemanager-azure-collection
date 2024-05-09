targetScope = 'subscription'

// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters
// Corresponds to terraform variables.
param observe_customer string
@secure()
param observe_token string
param observe_domain string = 'observeinc.com'
param timer_resources_func_schedule string = '0 */10 * * * *'
param timer_vm_metrics_func_schedule string = '30 */5 * * * *'
param func_url string = 'https://observeinc.s3.us-west-2.amazonaws.com/azure/azure-collection-functions-0.11.2.zip'
param location string = deployment().location
param location_abbreviation object = {
  australiacentral: 'ac'
  australiacentral2: 'ac2'
  australiaeast: 'ae'
  asiapacific: 'ap'
  australia: 'as'
  australiasoutheast: 'ase'
  brazil: 'b'
  brazilsouth: 'bs'
  brazilsoutheast: 'bse'
  canada: 'c'
  canadacentral: 'cc'
  canadaeast: 'ce'
  centralindia: 'ci'
  centralus: 'cu'
  centraluseuap: 'cue'
  centralusstage: 'cus'
  europe: 'e'
  eastasia: 'ea'
  eastasiastage: 'eas'
  eastus: 'eu'
  eastus2: 'eu2'
  eastus2euap: 'eu2e'
  eastus2stage: 'eu2s'
  eastusstage: 'eus'
  eastusstg: 'eustg'
  france: 'f'
  francecentral: 'fc'
  francesouth: 'fs'
  germany: 'g'
  global: 'glob'
  germanynorth: 'gn'
  germanywestcentral: 'gwc'
  india: 'i'
  japan: 'j'
  japaneast: 'je'
  jioindiacentral: 'jic'
  jioindiawest: 'jiw'
  japanwest: 'jw'
  korea: 'k'
  koreacentral: 'kc'
  koreasouth: 'ks'
  norway: 'n'
  northcentralus: 'ncu'
  northcentralusstage: 'ncus'
  northeurope: 'ne'
  norwayeast: 'nwe'
  norwaywest: 'nww'
  qatarcentral: 'qc'
  singapore: 's'
  southafrica: 'sa'
  southafricanorth: 'san'
  southeastasiastage: 'sas'
  southafricawest: 'saw'
  swedencentral: 'sc'
  southcentralus: 'scu'
  southcentralusstage: 'scus'
  southcentralusstg: 'sctg'
  southeastasia: 'sea'
  southindia: 'si'
  switzerlandnorth: 'sn'
  switzerlandwest: 'sw'
  switzerland: 'sz'
  uae: 'uae'
  uaecentral: 'uc'
  uk: 'uk'
  uaenorth: 'un'
  uksouth: 'us'
  unitedstates: 'us'
  unitedstateseuap: 'use'
  ukwest: 'uw'
  westcentralus: 'wcu'
  westeurope: 'we'
  westindia: 'wi'
  westus: 'wu'
  westus2: 'wu2'
  westus2stage: 'wu2s'
  westus3: 'wu3'
  westusstage: 'wus'
}

// https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/deployment-script-azcli-graph-azure-ad/
// As of October 2022, you have to create and assign AD roles manually before you can create an Azure AD app registration through a script.
// So, it's easier for users to create the App Registration and Client Secret manually.
param objectId string
param applicationId string
param enterpriseAppObjectId string
@secure()
param clientSecretValue string

// https://learn.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments?pivots=deployment-language-bicep
resource azurerm_role_assignment_observe_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(enterpriseAppObjectId) // Hack because name must be a GUID and we should only create 1 role assignment per enterprise app
  properties: {
    principalId: enterpriseAppObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05') // Monitoring Reader according to https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
  }
}

var sub = substring(subscription().subscriptionId, length(subscription().subscriptionId) - 4, 4)

// https://learn.microsoft.com/en-us/azure/templates/microsoft.resources/resourcegroups?pivots=deployment-language-bicep
resource azurerm_resource_group_observe_resource_group 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'observeResources-${observe_customer}-${location}-${sub}'
  location: location
}

module services 'services.bicep' = {
  name: 'services'
  params: {
    observe_customer: observe_customer
    observe_token: observe_token
    observe_domain: observe_domain
    timer_resources_func_schedule: timer_resources_func_schedule
    timer_vm_metrics_func_schedule: timer_vm_metrics_func_schedule
    func_url: func_url
    location: location
    location_abbreviation: location_abbreviation
    sub: sub

    objectId: objectId
    applicationId: applicationId
    clientSecretValue: clientSecretValue
  }
  scope: azurerm_resource_group_observe_resource_group
}
