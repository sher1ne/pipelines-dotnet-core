@description('Environment name (dev, staging, prod, or custom)')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('App Service Plan SKU')
@allowed(['F1', 'B1', 'B2', 'S1', 'S2', 'P1v2', 'P2v2'])
param appServicePlanSku string = 'B1'

@description('Application runtime stack')
@allowed(['NODE|18-lts', 'NODE|16-lts', 'DOTNETCORE|6.0', 'PYTHON|3.9'])
param runtimeStack string = 'NODE|18-lts'

// Variables
var appName = 'myapp-${environmentName}'
var appServicePlanName = 'asp-${environmentName}'

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: runtimeStack
      alwaysOn: appServicePlanSku != 'F1' // Free tier doesn't support Always On
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: environmentName
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '18-lts'
        }
      ]
    }
    httpsOnly: true
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Application Insights (optional but recommended)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${environmentName}'
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

// Configure App Insights in Web App
resource webAppAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    ENVIRONMENT: environmentName
    WEBSITE_NODE_DEFAULT_VERSION: '18-lts'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
  }
}

// Outputs
output appServiceUrl string = 'https://${webApp.properties.defaultHostName}'
output appServiceName string = webApp.name
output resourceGroupName string = resourceGroup().name
output appInsightsName string = appInsights.name