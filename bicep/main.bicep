// Minimal Bicep template for testing
@description('Environment name')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location


// Just create a simple storage account to test
var cleanEnvName = toLower(replace(environmentName, '-', ''))
var storageAccountName = take('st${cleanEnvName}${uniqueString(resourceGroup().id)}', 24)
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    Environment: environmentName
    Purpose: 'Testing'
  }
}

// Output the storage account name
output storageAccountName string = storageAccount.name
output resourceGroupName string = resourceGroup().name