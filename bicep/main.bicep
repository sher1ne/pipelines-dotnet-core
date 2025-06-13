@description('Environment name')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('App Service Plan SKU')
@allowed(['F1', 'B1', 'B2', 'S1', 'S2', 'P1v3', 'P2v3'])
param appServicePlanSku string = 'F1'

// Variables for consistent naming
var appName = 'app-${environmentName}-${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'asp-${environmentName}-${uniqueString(resourceGroup().id)}'
var cleanEnvName = toLower(replace(environmentName, '-', ''))
var storageAccountName = 'st${environmentName}${uniqueString(resourceGroup().id)}'
var appInsightsName = 'ai-${cleanEnvName}-${uniqueString(resourceGroup().id)}'

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
    tier: appServicePlanSku == 'F1' ? 'Free' : 'Basic'
  }
  kind: 'app'
  properties: {
    reserved: false
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: environmentName
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'STORAGE_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      alwaysOn: appServicePlanSku != 'F1'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Storage Container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/uploads'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccount
  ]
}

// Outputs
output appServiceUrl string = 'https://${webApp.properties.defaultHostName}'
output appServiceName string = webApp.name
output resourceGroupName string = resourceGroup().name
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name