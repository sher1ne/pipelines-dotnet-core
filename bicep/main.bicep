// Parameters for flexibility
param location string = 'eastus'
param environment string = 'dev'
param projectName string = 'MyApp'

// Variables for naming consistency
var uniqueSuffix = uniqueString(resourceGroup().id)
var storageAccountName = 'st${environment}${uniqueSuffix}'
var vnetName = 'vnet-${environment}-${uniqueSuffix}'
var agwName = 'agw-${environment}-${uniqueSuffix}'
var pipName = 'pip-agw-${environment}-${uniqueSuffix}'
var nsgName = 'nsg-agw-${environment}-${uniqueSuffix}'

// Common tags
var commonTags = {
  Environment: environment
  Project: projectName
}

// Network Security Group
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Public IP Address
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: pipName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: 'agw-${environment}-${uniqueSuffix}'
    }
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  tags: union(commonTags, {
    Purpose: 'Testing'
  })
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    enableDdosProtection: false
  }
}

// Application Gateway Subnet
resource appGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'appgateway-subnet'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Backend Subnet
resource backendSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'backend-subnet'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.2.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Application Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: agwName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort80'
        properties: {
          port: 80
        }
      }
      {
        name: 'appGatewayFrontendPort443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: 'httpbin.org'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayBackendHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', agwName, 'healthProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName, 'appGatewayFrontendPort80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'appGatewayRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName, 'appGatewayHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName, 'appGatewayBackendHttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    enableHttp2: true
  }
}

// Storage Account Blob Services
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

// Storage Account File Services
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Storage Account Queue Services
resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

// Storage Account Table Services
resource tableServices 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

// Storage Containers
resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blobServices
  name: 'backups'
  properties: {
    publicAccess: 'None'
  }
}

resource dataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blobServices
  name: 'data'
  properties: {
    publicAccess: 'None'
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blobServices
  name: 'uploads'
  properties: {
    publicAccess: 'None'
  }
}

// Outputs
output storageAccountName string = storageAccount.name
output applicationGatewayFQDN string = publicIPAddress.properties.dnsSettings.fqdn
output publicIPAddress string = publicIPAddress.properties.ipAddress
output virtualNetworkId string = virtualNetwork.id