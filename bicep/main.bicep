// This template creates ONLY what was in your original resource group
// No extra load balancer, availability sets, etc.

@description('Environment name')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Application Gateway SKU')
@allowed(['Standard_Small', 'Standard_Medium', 'Standard_Large', 'WAF_Medium', 'WAF_Large', 'Standard_v2', 'WAF_v2'])
param appGatewaySkuName string = 'Standard_v2'

@description('Application Gateway tier')
@allowed(['Standard', 'WAF', 'Standard_v2', 'WAF_v2'])
param appGatewayTier string = 'Standard_v2'

@description('VM Admin Username')
param vmAdminUsername string = 'azureuser'

@description('VM Admin Password')
@secure()
param vmAdminPassword string

@description('VM Size')
param vmSize string = 'Standard_B2s'

@description('Number of VMs to create')
param vmCount int = 3

@description('Include Load Balancer (false = minimal recreation)')
param includeLoadBalancer bool = false

@description('Include Availability Set (false = minimal recreation)')
param includeAvailabilitySet bool = false

// Variables for consistent naming
var cleanEnvName = toLower(replace(environmentName, '-', ''))
var storageAccountName = take('st${cleanEnvName}${uniqueString(resourceGroup().id)}', 24)
var vnetName = 'vnet-${environmentName}-${uniqueString(resourceGroup().id)}'
var publicIpName = 'pip-agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var appGatewayName = 'agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var nsgName = 'nsg-agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var vmNsgName = 'nsg-vm-${environmentName}-${uniqueString(resourceGroup().id)}'

// Optional Load Balancer variables (only used if includeLoadBalancer = true)
var loadBalancerName = 'lb-${environmentName}-${uniqueString(resourceGroup().id)}'
var lbPublicIpName = 'pip-lb-${environmentName}-${uniqueString(resourceGroup().id)}'
var availabilitySetName = 'avset-${environmentName}-${uniqueString(resourceGroup().id)}'

// Network Security Group for Application Gateway
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
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
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Basic NSG for VMs (minimal rules)
resource vmNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: vmNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'appgateway-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: 'backend-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: vmNetworkSecurityGroup.id
          }
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Public IP for Application Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'agw-${cleanEnvName}-${uniqueString(resourceGroup().id)}'
    }
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

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
    accessTier: 'Hot'
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
    Purpose: 'Testing'
  }
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// Storage Containers
resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'uploads'
  properties: {
    publicAccess: 'None'
  }
}

// Optional: Availability Set (only if includeAvailabilitySet = true)
resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-03-01' = if (includeAvailabilitySet) {
  name: availabilitySetName
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 3
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Public IPs for VMs (if no load balancer)
resource vmPublicIps 'Microsoft.Network/publicIPAddresses@2023-04-01' = [for i in range(0, vmCount): if (!includeLoadBalancer) {
  name: 'pip-vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}]

// Network Interfaces for VMs (simplified - no load balancer dependencies)
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = [for i in range(0, vmCount): {
  name: 'nic-vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'backend-subnet')
          }
          publicIPAddress: !includeLoadBalancer ? {
            id: vmPublicIps[i].id
          } : null
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
  dependsOn: [
    virtualNetwork
  ]
}]

// Virtual Machines (minimal configuration)
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, vmCount): {
  name: 'vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    availabilitySet: includeAvailabilitySet ? {
      id: availabilitySet.id
    } : null
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm${i}-${environmentName}'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
    VMNumber: string(i)
  }
  dependsOn: [
    networkInterface
    storageAccount
  ]
}]

// Application Gateway (points directly to VM private IPs)
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: appGatewayName
  location: location
  properties: {
    sku: {
      name: appGatewaySkuName
      tier: appGatewayTier
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'appgateway-subnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIp.id
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
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          backendAddresses: [for i in range(0, vmCount): {
            ipAddress: networkInterface[i].properties.ipConfigurations[0].properties.privateIPAddress
          }]
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
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'appGatewayFrontendPort80')
          }
          protocol: 'Http'
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'appGatewayHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'appGatewayBackendHttpSettings')
          }
        }
      }
    ]
    enableHttp2: true
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
  dependsOn: [
    virtualNetwork
    networkInterface
  ]
}

// Outputs
output storageAccountName string = storageAccount.name
output applicationGatewayName string = applicationGateway.name
output applicationGatewayPublicIP string = publicIp.properties.ipAddress
output applicationGatewayFQDN string = publicIp.properties.dnsSettings.fqdn
output virtualNetworkName string = virtualNetwork.name
output vmNames array = [for i in range(0, vmCount): 'vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}']
output vmPublicIPs array = !includeLoadBalancer ? [for i in range(0, vmCount): vmPublicIps[i].properties.ipAddress] : []
output resourceSummary object = {
  includeLoadBalancer: includeLoadBalancer
  includeAvailabilitySet: includeAvailabilitySet
  vmCount: vmCount
  hasPublicIPs: !includeLoadBalancer
}