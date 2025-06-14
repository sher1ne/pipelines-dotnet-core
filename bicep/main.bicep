param storageAccounts_sttestv2uctbalaua43sc_name string = 'sttestv2uctbalaua43sc'
param virtualNetworks_vnet_test_v2_uctbalaua43sc_name string = 'vnet-test-v2-uctbalaua43sc'
param applicationGateways_agw_test_v2_uctbalaua43sc_name string = 'agw-test-v2-uctbalaua43sc'
param publicIPAddresses_pip_agw_test_v2_uctbalaua43sc_name string = 'pip-agw-test-v2-uctbalaua43sc'
param networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name string = 'nsg-agw-test-v2-uctbalaua43sc'

resource networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_resource 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name
  location: 'eastus'
  tags: {
    Environment: 'test-v2'
    Project: 'MyApp'
  }
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        id: networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_AllowGatewayManager.id
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowHTTP'
        id: networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_AllowHTTP.id
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowHTTPS'
        id: networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_AllowHTTPS.id
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

resource publicIPAddresses_pip_agw_test_v2_uctbalaua43sc_name_resource 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIPAddresses_pip_agw_test_v2_uctbalaua43sc_name
  location: 'eastus'
  tags: {
    Environment: 'test-v2'
    Project: 'MyApp'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    ipAddress: '74.235.209.88'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: 'agw-testv2-uctbalaua43sc'
      fqdn: 'agw-testv2-uctbalaua43sc.eastus.cloudapp.azure.com'
    }
    ipTags: []
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

resource storageAccounts_sttestv2uctbalaua43sc_name_resource 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccounts_sttestv2uctbalaua43sc_name
  location: 'eastus'
  tags: {
    Environment: 'test-v2'
    Project: 'MyApp'
    Purpose: 'Testing'
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
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

resource networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_AllowGatewayManager 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  name: '${networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name}/AllowGatewayManager'
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '65200-65535'
    sourceAddressPrefix: 'GatewayManager'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 100
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_resource
  ]
}

resource networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_AllowHTTP 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  name: '${networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name}/AllowHTTP'
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '80'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 200
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_resource
  ]
}

resource networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_AllowHTTPS 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  name: '${networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name}/AllowHTTPS'
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 300
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_resource
  ]
}

resource virtualNetworks_vnet_test_v2_uctbalaua43sc_name_backend_subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_test_v2_uctbalaua43sc_name}/backend-subnet'
  properties: {
    addressPrefix: '10.0.2.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_test_v2_uctbalaua43sc_name_resource
  ]
}

resource storageAccounts_sttestv2uctbalaua43sc_name_default 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
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

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_sttestv2uctbalaua43sc_name_default 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_sttestv2uctbalaua43sc_name_default 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_sttestv2uctbalaua43sc_name_default 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource applicationGateways_agw_test_v2_uctbalaua43sc_name_resource 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: applicationGateways_agw_test_v2_uctbalaua43sc_name
  location: 'eastus'
  tags: {
    Environment: 'test-v2'
    Project: 'MyApp'
  }
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      family: 'Generation_1'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/gatewayIPConfigurations/appGatewayIpConfig'
        properties: {
          subnet: {
            id: virtualNetworks_vnet_test_v2_uctbalaua43sc_name_appgateway_subnet.id
          }
        }
      }
    ]
    sslCertificates: []
    trustedRootCertificates: []
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/frontendIPConfigurations/appGatewayFrontendIP'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_pip_agw_test_v2_uctbalaua43sc_name_resource.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort80'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/frontendPorts/appGatewayFrontendPort80'
        properties: {
          port: 80
        }
      }
      {
        name: 'appGatewayFrontendPort443'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/frontendPorts/appGatewayFrontendPort443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/backendAddressPools/appGatewayBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: 'httpbin.org'
            }
          ]
        }
      }
    ]
    loadDistributionPolicies: []
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayBackendHttpSettings'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/backendHttpSettingsCollection/appGatewayBackendHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
          probe: {
            id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/probes/healthProbe'
          }
        }
      }
    ]
    backendSettingsCollection: []
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/httpListeners/appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/frontendIPConfigurations/appGatewayFrontendIP'
          }
          frontendPort: {
            id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/frontendPorts/appGatewayFrontendPort80'
          }
          protocol: 'Http'
          hostNames: []
          requireServerNameIndication: false
        }
      }
    ]
    listeners: []
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: 'appGatewayRoutingRule'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/requestRoutingRules/appGatewayRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/httpListeners/appGatewayHttpListener'
          }
          backendAddressPool: {
            id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/backendAddressPools/appGatewayBackendPool'
          }
          backendHttpSettings: {
            id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/backendHttpSettingsCollection/appGatewayBackendHttpSettings'
          }
        }
      }
    ]
    routingRules: []
    probes: [
      {
        name: 'healthProbe'
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/probes/healthProbe'
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
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    enableHttp2: true
  }
}

resource virtualNetworks_vnet_test_v2_uctbalaua43sc_name_resource 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworks_vnet_test_v2_uctbalaua43sc_name
  location: 'eastus'
  tags: {
    Environment: 'test-v2'
    Project: 'MyApp'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'appgateway-subnet'
        id: virtualNetworks_vnet_test_v2_uctbalaua43sc_name_appgateway_subnet.id
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_resource.id
          }
          applicationGatewayIPConfigurations: [
            {
              id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/gatewayIPConfigurations/appGatewayIpConfig'
            }
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'backend-subnet'
        id: virtualNetworks_vnet_test_v2_uctbalaua43sc_name_backend_subnet.id
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource storageAccounts_sttestv2uctbalaua43sc_name_default_backups 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_default
  name: 'backups'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_sttestv2uctbalaua43sc_name_resource
  ]
}

resource storageAccounts_sttestv2uctbalaua43sc_name_default_data 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_default
  name: 'data'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_sttestv2uctbalaua43sc_name_resource
  ]
}

resource storageAccounts_sttestv2uctbalaua43sc_name_default_uploads 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: storageAccounts_sttestv2uctbalaua43sc_name_default
  name: 'uploads'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_sttestv2uctbalaua43sc_name_resource
  ]
}

resource virtualNetworks_vnet_test_v2_uctbalaua43sc_name_appgateway_subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_test_v2_uctbalaua43sc_name}/appgateway-subnet'
  properties: {
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroup: {
      id: networkSecurityGroups_nsg_agw_test_v2_uctbalaua43sc_name_resource.id
    }
    applicationGatewayIPConfigurations: [
      {
        id: '${applicationGateways_agw_test_v2_uctbalaua43sc_name_resource.id}/gatewayIPConfigurations/appGatewayIpConfig'
      }
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_test_v2_uctbalaua43sc_name_resource
  ]
}
