# Azure DevOps Pipeline for Environment Management (Fixed)
trigger: none

parameters:
- name: operation
  displayName: 'Operation Type'
  type: string
  default: 'create_new'
  values:
  - promote
  - create_new
  - destroy

- name: sourceEnvironment
  displayName: 'Source Environment (for promotion)'
  type: string
  default: 'dev'
  values:
  - dev
  - staging
  - prod

- name: targetEnvironment
  displayName: 'Target Environment'
  type: string
  default: 'staging'
  values:
  - dev
  - staging
  - prod

- name: newEnvironmentName
  displayName: 'New Environment Name (for new environments)'
  type: string
  default: 'test-v4'

- name: resourceGroupName
  displayName: 'Resource Group Name'
  type: string
  default: 'rg-myapp'

- name: infrastructureMethod
  displayName: 'Infrastructure Method'
  type: string
  default: 'bicep'
  values:
  - bicep
  - azure_cli

variables:
- name: subscriptionServiceConnection
  value: 'azure-service-connection-v2'
- name: location
  value: 'East US'

pool:
  vmImage: 'ubuntu-latest'

stages:
- stage: Validate
  displayName: 'Validate Parameters'
  jobs:
  - job: ValidateInputs
    displayName: 'Validate Pipeline Inputs'
    steps:
    - script: |
        echo "Operation: ${{ parameters.operation }}"
        echo "Infrastructure Method: ${{ parameters.infrastructureMethod }}"
        
        # Validate new environment name if creating new
        if [ "${{ parameters.operation }}" = "create_new" ] && [ -z "${{ parameters.newEnvironmentName }}" ]; then
          echo "##vso[task.logissue type=error]New environment name is required when creating a new environment"
          exit 1
        fi
      displayName: 'Validate Parameters'

- stage: Infrastructure
  displayName: 'Infrastructure Management'
  dependsOn: Validate
  condition: succeeded()
  jobs:
  - job: ManageInfrastructure
    displayName: 'Manage Infrastructure'
    steps:
    - checkout: self
    
    # Set environment variables
    - script: |
        # Set environment name
        if [ "${{ parameters.operation }}" = "create_new" ]; then
          ENV_NAME="${{ parameters.newEnvironmentName }}"
        else
          ENV_NAME="${{ parameters.targetEnvironment }}"
        fi
        echo "##vso[task.setvariable variable=ENV_NAME]$ENV_NAME"
        echo "##vso[task.setvariable variable=RESOURCE_GROUP_NAME]${{ parameters.resourceGroupName }}-$ENV_NAME"
        echo "Environment: $ENV_NAME"
        echo "Resource Group: ${{ parameters.resourceGroupName }}-$ENV_NAME"
      displayName: 'Set Environment Variables'
    
    # Deploy Infrastructure with Bicep (Fixed Version)
    - task: AzureCLI@2
      displayName: 'Deploy Infrastructure with Bicep'
      inputs:
        azureSubscription: $(subscriptionServiceConnection)
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          if [ "${{ parameters.operation }}" = "destroy" ]; then
            echo "Deleting resource group: $(RESOURCE_GROUP_NAME)"
            az group delete --name $(RESOURCE_GROUP_NAME) --yes --no-wait
            echo "✓ Resource group deletion initiated"
          else
            echo "Deploying infrastructure to: $(RESOURCE_GROUP_NAME)"
            
            # Create resource group if it doesn't exist
            echo "Creating resource group..."
            az group create --name $(RESOURCE_GROUP_NAME) --location "$(location)"
            
            # Check if bicep file exists
            if [ ! -f "bicep/main.bicep" ]; then
              echo "ERROR: bicep/main.bicep file not found!"
              echo "Current directory: $(pwd)"
              echo "Files in current directory:"
              ls -la
              echo "Files in bicep directory (if it exists):"
              ls -la bicep/ 2>/dev/null || echo "bicep directory does not exist"
              exit 1
            fi
            
            echo "Deploying Bicep template..."
            echo "Template file: bicep/main.bicep"
            echo "Parameters: environmentName=$(ENV_NAME), location=$(location)"
            
            # Deploy Bicep template without output capture to avoid "content consumed" error
            az deployment group create \
              --resource-group $(RESOURCE_GROUP_NAME) \
              --template-file bicep/main.bicep \
              --parameters environmentName=$(ENV_NAME) \
              --parameters location="$(location)" \
              --name "main-deployment-$(date +%s)"
            
            DEPLOYMENT_EXIT_CODE=$?
            
            if [ $DEPLOYMENT_EXIT_CODE -eq 0 ]; then
              echo "✓ Bicep deployment successful!"
              
              # List resources created
              echo "Resources created in $(RESOURCE_GROUP_NAME):"
              az resource list --resource-group $(RESOURCE_GROUP_NAME) --output table
              
            else
              echo "✗ Bicep deployment failed with exit code: $DEPLOYMENT_EXIT_CODE"
              
              # Show deployment errors
              echo "Checking for deployment errors..."
              az deployment group list --resource-group $(RESOURCE_GROUP_NAME) --output table
              
              exit 1
            fi
          fi

- stage: Notification
  displayName: 'Send Notifications'
  dependsOn: [Infrastructure]
  condition: always()
  jobs:
  - job: SendNotification
    displayName: 'Send Deployment Notification'
    steps:
    - script: |
        ENV_NAME="${{ parameters.targetEnvironment }}"
        if [ "${{ parameters.operation }}" = "create_new" ]; then
          ENV_NAME="${{ parameters.newEnvironmentName }}"
        fi
        
        if [ "$(Agent.JobStatus)" = "Succeeded" ]; then
          STATUS="✅ SUCCESS"
        else
          STATUS="❌ FAILED"
        fi
        
        echo "=== Deployment Summary ==="
        echo "Status: $STATUS"
        echo "Environment: $ENV_NAME"
        echo "Operation: ${{ parameters.operation }}"
        echo "Resource Group: ${{ parameters.resourceGroupName }}-$ENV_NAME"
        echo "=========================="
        
      displayName: 'Send Notification'