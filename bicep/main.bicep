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

// Variables for consistent naming
var cleanEnvName = toLower(replace(environmentName, '-', ''))
var storageAccountName = take('st${cleanEnvName}${uniqueString(resourceGroup().id)}', 24)
var vnetName = 'vnet-${environmentName}-${uniqueString(resourceGroup().id)}'
var publicIpName = 'pip-agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var appGatewayName = 'agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var nsgName = 'nsg-agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var loadBalancerName = 'lb-${environmentName}-${uniqueString(resourceGroup().id)}'
var lbPublicIpName = 'pip-lb-${environmentName}-${uniqueString(resourceGroup().id)}'
var availabilitySetName = 'avset-${environmentName}-${uniqueString(resourceGroup().id)}'
var vmNsgName = 'nsg-vm-${environmentName}-${uniqueString(resourceGroup().id)}'

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

// Network Security Group for VMs
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
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
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
      {
        name: 'AllowLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 400
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
      {
        name: 'loadbalancer-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
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

// Public IP for Load Balancer
resource lbPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: lbPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'lb-${cleanEnvName}-${uniqueString(resourceGroup().id)}'
    }
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Availability Set for VMs
resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-03-01' = {
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

// Load Balancer
resource loadBalancer 'Microsoft.Network/loadBalancers@2023-04-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: lbPublicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'HTTPRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'LoadBalancerFrontEnd')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'HTTPProbe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
    ]
    probes: [
      {
        name: 'HTTPProbe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/health'
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    inboundNatRules: [for i in range(0, vmCount): {
      name: 'SSH-VM${i}'
      properties: {
        frontendIPConfiguration: {
          id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'LoadBalancerFrontEnd')
        }
        protocol: 'Tcp'
        frontendPort: 2200 + i
        backendPort: 22
      }
    }]
  }
  tags: {
    Environment: environmentName
    Project: 'MyApp'
  }
}

// Network Interfaces for VMs
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
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool')
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/inboundNatRules', loadBalancerName, 'SSH-VM${i}')
            }
          ]
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
    loadBalancer
  ]
}]

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

resource dataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'data'
  properties: {
    publicAccess: 'None'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'None'
  }
}

// Virtual Machines
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, vmCount): {
  name: 'vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm${i}-${environmentName}'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      customData: base64('''#!/bin/bash
        # Update system
        apt-get update
        apt-get install -y nginx
        
        # Get VM metadata
        VMNAME=$(hostname)
        ENVIRONMENT="${ENVIRONMENT}"
        VM_NUMBER="${VM_NUMBER}"
        
        # Create a custom index page
        cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$VMNAME - $ENVIRONMENT</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { 
            background-color: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px; 
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }
        h1 { color: #fff; text-align: center; margin-bottom: 30px; }
        .info { 
            background-color: rgba(255,255,255,0.1); 
            padding: 20px; 
            border-radius: 10px; 
            margin: 15px 0;
            border-left: 4px solid #4CAF50;
        }
        .status { text-align: center; color: #4CAF50; font-weight: bold; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 20px; }
        .card { background-color: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ Welcome to $VMNAME</h1>
        <div class="status">✅ VM is Online and Healthy</div>
        
        <div class="grid">
            <div class="card">
                <h3>📋 VM Information</h3>
                <p><strong>Environment:</strong> $ENVIRONMENT</p>
                <p><strong>VM Name:</strong> $VMNAME</p>
                <p><strong>VM Number:</strong> $VM_NUMBER</p>
                <p><strong>Hostname:</strong> $(hostname)</p>
            </div>
            
            <div class="card">
                <h3>⏰ System Info</h3>
                <p><strong>Date:</strong> $(date)</p>
                <p><strong>Uptime:</strong> $(uptime -p)</p>
                <p><strong>Load Avg:</strong> $(uptime | awk -F'load average:' '{print $2}')</p>
            </div>
        </div>
        
        <div class="info">
            <h3>🌐 Load Balancer Information</h3>
            <p>This VM is part of a load-balanced backend pool serving the <strong>$ENVIRONMENT</strong> environment.</p>
            <p>Each request may be served by any VM in the pool for high availability and scalability.</p>
        </div>
        
        <div class="info">
            <h3>🔗 Access Methods</h3>
            <p><strong>Application Gateway:</strong> Provides SSL termination and advanced routing</p>
            <p><strong>Load Balancer:</strong> Distributes traffic across all healthy VMs</p>
            <p><strong>Direct SSH:</strong> Available via load balancer NAT rules</p>
        </div>
    </div>
</body>
</html>
EOF
        
        # Replace placeholders with actual values
        sed -i "s/\${VM_NUMBER}/${i}/g" /var/www/html/index.html
        sed -i "s/\${ENVIRONMENT}/${environmentName}/g" /var/www/html/index.html
        
        # Create health check endpoint
        echo "OK" > /var/www/html/health
        
        # Create a simple API endpoint for testing
        cat > /var/www/html/api << EOF
{
  "status": "healthy",
  "vm": "$VMNAME",
  "environment": "$ENVIRONMENT",
  "timestamp": "$(date -Iseconds)",
  "vm_number": ${i}
}
EOF
        
        # Configure nginx
        cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
    
    location /api {
        add_header Content-Type application/json;
        try_files \$uri =404;
    }
}
EOF
        
        # Enable and start nginx
        systemctl enable nginx
        systemctl restart nginx
        
        # Install additional monitoring tools
        apt-get install -y htop curl wget net-tools
        
        # Log successful completion
        echo "VM ${i} configuration completed successfully" >> /var/log/vm-setup.log
        ''')
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

// Application Gateway
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
          pickHostNameFromBackendAddress: false
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'healthProbe')
          }
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
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Http'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
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
output storageAccountId string = storageAccount.id
output primaryEndpoint string = storageAccount.properties.primaryEndpoints.blob
output resourceGroupName string = resourceGroup().name
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
output applicationGatewayName string = applicationGateway.name
output applicationGatewayPublicIP string = publicIp.properties.ipAddress
output applicationGatewayFQDN string = publicIp.properties.dnsSettings.fqdn
output virtualNetworkName string = virtualNetwork.name
output loadBalancerName string = loadBalancer.name
output loadBalancerPublicIP string = lbPublicIp.properties.ipAddress
output loadBalancerFQDN string = lbPublicIp.properties.dnsSettings.fqdn
output vmNames array = [for i in range(0, vmCount): 'vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}']
output sshConnections array = [for i in range(0, vmCount): {
  vmName: 'vm${i}-${environmentName}-${uniqueString(resourceGroup().id)}'
  sshCommand: 'ssh ${vmAdminUsername}@${lbPublicIp.properties.dnsSettings.fqdn} -p ${2200 + i}'
}]
output availabilitySetName string = availabilitySet.name
output vmPrivateIPs array = [for i in range(0, vmCount): networkInterface[i].properties.ipConfigurations[0].properties.privateIPAddress]