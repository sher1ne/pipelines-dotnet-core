@description('Environment name')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

// Simple storage account for testing
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'store${environmentName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    Environment: environmentName
  }
}

// Outputs
output storageAccountName string = storageAccount.name
output resourceGroupName string = resourceGroup().name