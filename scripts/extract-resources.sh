#!/bin/bash

# ==============================================================================
# SELECTIVE RESOURCE EXTRACTION SCRIPT
# This script analyzes an existing Azure resource group and lets you choose
# which resources to recreate in the new environment
# ==============================================================================

# Get resource group from parameter or environment variable
EXISTING_RG="${1:-$SOURCE_RG}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if resource group exists
if [ -z "$EXISTING_RG" ]; then
    print_error "No resource group specified. Usage: $0 <resource-group-name>"
    echo "Environment variable SOURCE_RG: $SOURCE_RG"
    echo "Parameter 1: $1"
    exit 1
fi

print_header "Analyzing Resource Group: $EXISTING_RG"

if ! az group show --name "$EXISTING_RG" &>/dev/null; then
    print_error "Resource group '$EXISTING_RG' not found or no access"
    echo "Available resource groups:"
    az group list --query "[].name" -o table
    exit 1
fi

print_success "Resource group found and accessible"

# Get basic info
LOCATION=$(az group show --name "$EXISTING_RG" --query "location" --output tsv)
print_success "Location: $LOCATION"

# Initialize detection variables
HAS_VMS=false
HAS_APP_GATEWAY=false
HAS_LOAD_BALANCER=false
HAS_STORAGE_ACCOUNT=false
HAS_VNET=false
HAS_AVAILABILITY_SET=false
HAS_NSG=false
HAS_PUBLIC_IPS=false
HAS_BASTION=false
HAS_NAT_GATEWAY=false
HAS_KEY_VAULT=false
HAS_LOG_ANALYTICS=false

# Resource details
VM_COUNT=0
VM_SIZE=""
ADMIN_USERNAME=""
APP_GATEWAY_SKU=""
APP_GATEWAY_TIER=""
STORAGE_SKU=""
STORAGE_CONTAINERS=""
VNET_ADDRESS_SPACE=""

print_header "Resource Discovery"

# Check for Virtual Machines
VMS=$(az vm list --resource-group "$EXISTING_RG" --query "[].name" --output tsv)
if [ ! -z "$VMS" ]; then
    HAS_VMS=true
    VM_COUNT=$(echo "$VMS" | wc -l)
    VM_SIZE=$(az vm list --resource-group "$EXISTING_RG" --query "[0].hardwareProfile.vmSize" --output tsv)
    ADMIN_USERNAME=$(az vm list --resource-group "$EXISTING_RG" --query "[0].osProfile.adminUsername" --output tsv)
    print_success "Found $VM_COUNT Virtual Machines (Size: $VM_SIZE)"
    
    echo "VM Details:"
    az vm list --resource-group "$EXISTING_RG" --query "[].{Name:name,Size:hardwareProfile.vmSize,Location:location}" --output table
else
    print_info "No Virtual Machines found"
fi

# Check for Application Gateway
AGW_NAME=$(az network application-gateway list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$AGW_NAME" ]; then
    HAS_APP_GATEWAY=true
    APP_GATEWAY_SKU=$(az network application-gateway show --resource-group "$EXISTING_RG" --name "$AGW_NAME" --query "sku.name" --output tsv)
    APP_GATEWAY_TIER=$(az network application-gateway show --resource-group "$EXISTING_RG" --name "$AGW_NAME" --query "sku.tier" --output tsv)
    print_success "Found Application Gateway: $AGW_NAME ($APP_GATEWAY_TIER)"
else
    print_info "No Application Gateway found"
fi

# Check for Load Balancer
LB_NAME=$(az network lb list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$LB_NAME" ]; then
    HAS_LOAD_BALANCER=true
    LB_SKU=$(az network lb show --resource-group "$EXISTING_RG" --name "$LB_NAME" --query "sku.name" --output tsv)
    print_success "Found Load Balancer: $LB_NAME ($LB_SKU)"
else
    print_info "No Load Balancer found"
fi

# Check for Storage Accounts
STORAGE_ACCOUNTS=$(az storage account list --resource-group "$EXISTING_RG" --query "[].name" --output tsv)
if [ ! -z "$STORAGE_ACCOUNTS" ]; then
    HAS_STORAGE_ACCOUNT=true
    STORAGE_NAME=$(echo "$STORAGE_ACCOUNTS" | head -n1)
    STORAGE_SKU=$(az storage account show --resource-group "$EXISTING_RG" --name "$STORAGE_NAME" --query "sku.name" --output tsv)
    print_success "Found Storage Account: $STORAGE_NAME ($STORAGE_SKU)"
    
    # Get containers
    CONTAINERS=$(az storage container list --account-name "$STORAGE_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ ! -z "$CONTAINERS" ]; then
        STORAGE_CONTAINERS=$(echo "$CONTAINERS" | tr '\n' ',' | sed 's/,$//')
        print_info "Containers: $STORAGE_CONTAINERS"
    fi
else
    print_info "No Storage Accounts found"
fi

# Check for Virtual Network
VNET_NAME=$(az network vnet list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$VNET_NAME" ]; then
    HAS_VNET=true
    VNET_ADDRESS_SPACE=$(az network vnet show --resource-group "$EXISTING_RG" --name "$VNET_NAME" --query "addressSpace.addressPrefixes[0]" --output tsv)
    print_success "Found Virtual Network: $VNET_NAME ($VNET_ADDRESS_SPACE)"
    
    echo "Subnets:"
    az network vnet subnet list --resource-group "$EXISTING_RG" --vnet-name "$VNET_NAME" --query "[].{Name:name,AddressPrefix:addressPrefix}" --output table
else
    print_info "No Virtual Network found"
fi

# Check for Availability Set
AVSET_NAME=$(az vm availability-set list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$AVSET_NAME" ]; then
    HAS_AVAILABILITY_SET=true
    print_success "Found Availability Set: $AVSET_NAME"
else
    print_info "No Availability Set found"
fi

# Check for Network Security Groups
NSGS=$(az network nsg list --resource-group "$EXISTING_RG" --query "[].name" --output tsv)
if [ ! -z "$NSGS" ]; then
    HAS_NSG=true
    NSG_COUNT=$(echo "$NSGS" | wc -l)
    print_success "Found $NSG_COUNT Network Security Groups"
else
    print_info "No Network Security Groups found"
fi

# Check for Public IPs
PUBLIC_IPS=$(az network public-ip list --resource-group "$EXISTING_RG" --query "[].name" --output tsv)
if [ ! -z "$PUBLIC_IPS" ]; then
    HAS_PUBLIC_IPS=true
    PIP_COUNT=$(echo "$PUBLIC_IPS" | wc -l)
    print_success "Found $PIP_COUNT Public IP addresses"
    
    # Check if any are associated with VMs
    VM_PIPS=$(az network public-ip list --resource-group "$EXISTING_RG" --query "[?contains(ipConfiguration.id, 'virtualMachines')].name" --output tsv)
    if [ ! -z "$VM_PIPS" ]; then
        VM_PIP_COUNT=$(echo "$VM_PIPS" | wc -l)
        print_info "$VM_PIP_COUNT Public IPs are associated with VMs"
    fi
else
    print_info "No Public IP addresses found"
fi

# Check for Bastion Host
BASTION_NAME=$(az network bastion list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$BASTION_NAME" ]; then
    HAS_BASTION=true
    print_success "Found Bastion Host: $BASTION_NAME"
else
    print_info "No Bastion Host found"
fi

# Check for NAT Gateway
NAT_NAME=$(az network nat gateway list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$NAT_NAME" ]; then
    HAS_NAT_GATEWAY=true
    print_success "Found NAT Gateway: $NAT_NAME"
else
    print_info "No NAT Gateway found"
fi

# Check for Key Vault
KV_NAME=$(az keyvault list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$KV_NAME" ]; then
    HAS_KEY_VAULT=true
    print_success "Found Key Vault: $KV_NAME"
else
    print_info "No Key Vault found"
fi

# Check for Log Analytics Workspace
LAW_NAME=$(az monitor log-analytics workspace list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$LAW_NAME" ]; then
    HAS_LOG_ANALYTICS=true
    print_success "Found Log Analytics Workspace: $LAW_NAME"
else
    print_info "No Log Analytics Workspace found"
fi

# Generate suggested environment name
SUGGESTED_ENV_NAME=$(echo "$EXISTING_RG" | sed 's/rg-//' | sed 's/myapp-//' | sed 's/-.*$//')
if [ -z "$SUGGESTED_ENV_NAME" ] || [ "$SUGGESTED_ENV_NAME" = "$EXISTING_RG" ]; then
    SUGGESTED_ENV_NAME="extracted"
fi

# Generate storage containers array for JSON
if [ ! -z "$STORAGE_CONTAINERS" ]; then
    CONTAINERS_JSON="[\"$(echo "$STORAGE_CONTAINERS" | sed 's/,/","/g')\"]"
else
    CONTAINERS_JSON="[\"uploads\"]"
fi

# Create JSON configuration file
cat > extracted-config.json << EOF
{
  "extractedFrom": "$EXISTING_RG",
  "extractedAt": "$(date -Iseconds)",
  "discoveredResources": {
    "virtualMachines": {
      "found": $HAS_VMS,
      "count": $VM_COUNT,
      "size": "$VM_SIZE",
      "adminUsername": "$ADMIN_USERNAME"
    },
    "applicationGateway": {
      "found": $HAS_APP_GATEWAY,
      "name": "$AGW_NAME",
      "sku": "$APP_GATEWAY_SKU",
      "tier": "$APP_GATEWAY_TIER"
    },
    "loadBalancer": {
      "found": $HAS_LOAD_BALANCER,
      "name": "$LB_NAME"
    },
    "storageAccount": {
      "found": $HAS_STORAGE_ACCOUNT,
      "name": "$STORAGE_NAME",
      "sku": "$STORAGE_SKU",
      "containers": $CONTAINERS_JSON
    },
    "virtualNetwork": {
      "found": $HAS_VNET,
      "name": "$VNET_NAME",
      "addressSpace": "$VNET_ADDRESS_SPACE"
    },
    "availabilitySet": {
      "found": $HAS_AVAILABILITY_SET,
      "name": "$AVSET_NAME"
    },
    "networkSecurityGroups": {
      "found": $HAS_NSG
    },
    "publicIPs": {
      "found": $HAS_PUBLIC_IPS,
      "vmPublicIPs": $([ ! -z "$VM_PIPS" ] && echo "true" || echo "false")
    },
    "bastionHost": {
      "found": $HAS_BASTION,
      "name": "$BASTION_NAME"
    },
    "natGateway": {
      "found": $HAS_NAT_GATEWAY,
      "name": "$NAT_NAME"
    },
    "keyVault": {
      "found": $HAS_KEY_VAULT,
      "name": "$KV_NAME"
    },
    "logAnalytics": {
      "found": $HAS_LOG_ANALYTICS,
      "name": "$LAW_NAME"
    },
    "location": "$LOCATION"
  },
  "recommendedParameters": {
    "createVMs": $HAS_VMS,
    "createApplicationGateway": $HAS_APP_GATEWAY,
    "createLoadBalancer": $HAS_LOAD_BALANCER,
    "createStorageAccount": $HAS_STORAGE_ACCOUNT,
    "createVirtualNetwork": $HAS_VNET,
    "createAvailabilitySet": $HAS_AVAILABILITY_SET,
    "createNetworkSecurityGroups": $HAS_NSG,
    "createVMPublicIPs": $([ ! -z "$VM_PIPS" ] && echo "true" || echo "false"),
    "createBastion": $HAS_BASTION,
    "createNATGateway": $HAS_NAT_GATEWAY,
    "createKeyVault": $HAS_KEY_VAULT,
    "createLogAnalytics": $HAS_LOG_ANALYTICS,
    "vmCount": $VM_COUNT,
    "vmSize": "$VM_SIZE",
    "appGatewaySkuName": "$APP_GATEWAY_SKU",
    "appGatewayTier": "$APP_GATEWAY_TIER",
    "storageAccountSku": "$STORAGE_SKU",
    "storageContainers": $CONTAINERS_JSON,
    "vnetAddressPrefix": "$VNET_ADDRESS_SPACE",
    "environmentName": "${SUGGESTED_ENV_NAME}-replica",
    "location": "$LOCATION"
  }
}
EOF

print_header "Resource Discovery Summary"
echo "Found Resources:"
echo "  🖥️  Virtual Machines: $([ "$HAS_VMS" = "true" ] && echo "✅ $VM_COUNT VMs" || echo "❌ None")"
echo "  🌐 Application Gateway: $([ "$HAS_APP_GATEWAY" = "true" ] && echo "✅ $AGW_NAME" || echo "❌ None")"
echo "  ⚖️  Load Balancer: $([ "$HAS_LOAD_BALANCER" = "true" ] && echo "✅ $LB_NAME" || echo "❌ None")"
echo "  💾 Storage Account: $([ "$HAS_STORAGE_ACCOUNT" = "true" ] && echo "✅ $STORAGE_NAME" || echo "❌ None")"
echo "  🔗 Virtual Network: $([ "$HAS_VNET" = "true" ] && echo "✅ $VNET_NAME" || echo "❌ None")"
echo "  📦 Availability Set: $([ "$HAS_AVAILABILITY_SET" = "true" ] && echo "✅ $AVSET_NAME" || echo "❌ None")"
echo "  🛡️  Network Security Groups: $([ "$HAS_NSG" = "true" ] && echo "✅ Found" || echo "❌ None")"
echo "  🌍 Public IPs: $([ "$HAS_PUBLIC_IPS" = "true" ] && echo "✅ Found" || echo "❌ None")"
echo "  🏰 Bastion Host: $([ "$HAS_BASTION" = "true" ] && echo "✅ $BASTION_NAME" || echo "❌ None")"
echo "  🚪 NAT Gateway: $([ "$HAS_NAT_GATEWAY" = "true" ] && echo "✅ $NAT_NAME" || echo "❌ None")"
echo "  🔐 Key Vault: $([ "$HAS_KEY_VAULT" = "true" ] && echo "✅ $KV_NAME" || echo "❌ None")"
echo "  📊 Log Analytics: $([ "$HAS_LOG_ANALYTICS" = "true" ] && echo "✅ $LAW_NAME" || echo "❌ None")"

print_header "Recommended Pipeline Parameters"
echo "Based on your existing resources, use these parameters:"
echo ""
echo "createVMs: $HAS_VMS"
echo "createApplicationGateway: $HAS_APP_GATEWAY"
echo "createLoadBalancer: $HAS_LOAD_BALANCER"
echo "createStorageAccount: $HAS_STORAGE_ACCOUNT"
echo "createVirtualNetwork: $HAS_VNET"
echo "createAvailabilitySet: $HAS_AVAILABILITY_SET"
echo "createNetworkSecurityGroups: $HAS_NSG"
echo "createVMPublicIPs: $([ ! -z "$VM_PIPS" ] && echo "true" || echo "false")"
echo "createBastion: $HAS_BASTION"
echo "createNATGateway: $HAS_NAT_GATEWAY"
echo "createKeyVault: $HAS_KEY_VAULT"
echo "createLogAnalytics: $HAS_LOG_ANALYTICS"

if [ "$HAS_VMS" = "true" ]; then
    echo "vmCount: $VM_COUNT"
    echo "vmSize: $VM_SIZE"
fi

if [ "$HAS_APP_GATEWAY" = "true" ]; then
    echo "appGatewaySkuName: $APP_GATEWAY_SKU"
    echo "appGatewayTier: $APP_GATEWAY_TIER"
fi

if [ "$HAS_STORAGE_ACCOUNT" = "true" ]; then
    echo "storageAccountSku: $STORAGE_SKU"
    echo "storageContainers: $CONTAINERS_JSON"
fi

print_success "Configuration saved to extracted-config.json"

print_header "Next Steps"
echo "1. Use the selective Bicep template for maximum control"
echo "2. Run your pipeline with operation: extract_and_recreate"
echo "3. Choose which resources to recreate using the parameters above"
echo "4. New resource group will be: rg-myapp-${SUGGESTED_ENV_NAME}-replica"

print_success "Selective extraction complete!"