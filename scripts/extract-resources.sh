#!/bin/bash

# ==============================================================================
# RESOURCE GROUP EXTRACTION SCRIPT (Pipeline Version)
# This script analyzes an existing Azure resource group and provides
# the configuration needed for Bicep recreation
# ==============================================================================

# Get resource group from parameter or environment variable
EXISTING_RG="${1:-$SOURCE_RG}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if resource group exists
if [ -z "$EXISTING_RG" ]; then
    print_error "No resource group specified. Usage: $0 <resource-group-name>"
    exit 1
fi

if ! az group show --name "$EXISTING_RG" &>/dev/null; then
    print_error "Resource group '$EXISTING_RG' not found or no access"
    exit 1
fi

print_success "Analyzing resource group: $EXISTING_RG"

# Get basic info
LOCATION=$(az group show --name "$EXISTING_RG" --query "location" --output tsv)
print_success "Location: $LOCATION"

# Extract VM configuration
print_header "Analyzing Virtual Machines"

VMS=$(az vm list --resource-group "$EXISTING_RG" --query "[].name" --output tsv)

if [ -z "$VMS" ]; then
    print_warning "No VMs found"
    VM_COUNT=0
    VM_SIZE="Standard_B2s"
    ADMIN_USERNAME="azureuser"
else
    VM_COUNT=$(echo "$VMS" | wc -l)
    VM_SIZE=$(az vm list --resource-group "$EXISTING_RG" --query "[0].hardwareProfile.vmSize" --output tsv)
    ADMIN_USERNAME=$(az vm list --resource-group "$EXISTING_RG" --query "[0].osProfile.adminUsername" --output tsv)
    
    print_success "Found $VM_COUNT VMs"
    print_success "VM Size: $VM_SIZE"
    print_success "Admin Username: $ADMIN_USERNAME"
    
    # Check if all VMs have same size
    UNIQUE_SIZES=$(az vm list --resource-group "$EXISTING_RG" --query "[].hardwareProfile.vmSize" --output tsv | sort | uniq | wc -l)
    if [ "$UNIQUE_SIZES" -gt 1 ]; then
        print_warning "VMs have different sizes, using first VM size: $VM_SIZE"
    fi
fi

# Extract Application Gateway configuration
print_header "Analyzing Application Gateway"

AGW_NAME=$(az network application-gateway list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)

if [ -z "$AGW_NAME" ]; then
    print_warning "No Application Gateway found"
    APP_GATEWAY_SKU="Standard_v2"
    APP_GATEWAY_TIER="Standard_v2"
else
    APP_GATEWAY_SKU=$(az network application-gateway show --resource-group "$EXISTING_RG" --name "$AGW_NAME" --query "sku.name" --output tsv)
    APP_GATEWAY_TIER=$(az network application-gateway show --resource-group "$EXISTING_RG" --name "$AGW_NAME" --query "sku.tier" --output tsv)
    
    print_success "Found Application Gateway: $AGW_NAME"
    print_success "SKU: $APP_GATEWAY_SKU"
    print_success "Tier: $APP_GATEWAY_TIER"
fi

# Extract Load Balancer configuration
print_header "Analyzing Load Balancer"

LB_NAME=$(az network lb list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)

if [ -z "$LB_NAME" ]; then
    print_warning "No Load Balancer found"
else
    LB_SKU=$(az network lb show --resource-group "$EXISTING_RG" --name "$LB_NAME" --query "sku.name" --output tsv)
    print_success "Found Load Balancer: $LB_NAME (SKU: $LB_SKU)"
fi

# Extract VNet info
print_header "Analyzing Virtual Network"

VNET_NAME=$(az network vnet list --resource-group "$EXISTING_RG" --query "[0].name" --output tsv)
if [ ! -z "$VNET_NAME" ]; then
    print_success "Found VNet: $VNET_NAME"
    SUBNET_COUNT=$(az network vnet subnet list --resource-group "$EXISTING_RG" --vnet-name "$VNET_NAME" --query "length([])")
    print_success "Subnets: $SUBNET_COUNT"
fi

# Generate suggested environment name
SUGGESTED_ENV_NAME=$(echo "$EXISTING_RG" | sed 's/rg-//' | sed 's/myapp-//' | sed 's/-.*$//')
if [ -z "$SUGGESTED_ENV_NAME" ] || [ "$SUGGESTED_ENV_NAME" = "$EXISTING_RG" ]; then
    SUGGESTED_ENV_NAME="extracted"
fi

# Create JSON output for pipeline
cat > extracted-config.json << EOF
{
  "extractedFrom": "$EXISTING_RG",
  "extractedAt": "$(date -Iseconds)",
  "pipelineParameters": {
    "operation": "extract_and_recreate",
    "sourceResourceGroup": "$EXISTING_RG",
    "newEnvironmentName": "${SUGGESTED_ENV_NAME}-replica",
    "targetEnvironment": "staging",
    "vmCount": $VM_COUNT,
    "vmSize": "$VM_SIZE",
    "appGatewayTier": "$APP_GATEWAY_TIER",
    "location": "$LOCATION"
  },
  "discoveredResources": {
    "virtualMachines": {
      "count": $VM_COUNT,
      "size": "$VM_SIZE",
      "adminUsername": "$ADMIN_USERNAME"
    },
    "applicationGateway": {
      "name": "$AGW_NAME",
      "sku": "$APP_GATEWAY_SKU",
      "tier": "$APP_GATEWAY_TIER"
    },
    "loadBalancer": {
      "name": "$LB_NAME"
    },
    "virtualNetwork": {
      "name": "$VNET_NAME"
    },
    "location": "$LOCATION"
  }
}
EOF

print_header "Extraction Summary"
echo "Resource Group: $EXISTING_RG"
echo "VMs: $VM_COUNT x $VM_SIZE"
echo "App Gateway: $APP_GATEWAY_TIER"
echo "Location: $LOCATION"
echo "Suggested new environment: ${SUGGESTED_ENV_NAME}-replica"

print_success "Configuration saved to extracted-config.json"

# Display what will be created
print_header "What Will Be Created"
echo "New Resource Group: rg-myapp-${SUGGESTED_ENV_NAME}-replica"
echo "Virtual Machines: $VM_COUNT x $VM_SIZE"
echo "Application Gateway: $APP_GATEWAY_TIER tier"
echo "Load Balancer: Standard SKU"
echo "Virtual Network: Complete networking setup"
echo "Storage Account: For diagnostics"

print_success "Extraction complete!"