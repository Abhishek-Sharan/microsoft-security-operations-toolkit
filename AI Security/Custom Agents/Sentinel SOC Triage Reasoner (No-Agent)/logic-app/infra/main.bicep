targetScope = 'resourceGroup'

@description('Name of the Logic App Consumption playbook.')
param playbookName string = 'sentinel-soc-triage-reasoner'

@description('Azure region for the Logic App and API connections.')
param location string = resourceGroup().location

@description('Name of the existing Microsoft Sentinel / Log Analytics workspace in this resource group.')
param workspaceName string

@description('Display name for the Microsoft Sentinel managed API connection (used by the incident trigger).')
param azureSentinelConnectionName string = 'azuresentinel-triage-reasoner'

@description('Display name for the Security Copilot managed API connection (used by ProcessPrompt).')
param securityCopilotConnectionName string = 'securitycopilot-triage-reasoner'

@description('Built-in role: Microsoft Sentinel Responder (incident comment writeback).')
param sentinelResponderRoleId string = '3e150937-b8fe-4cfb-8069-0eaf05ecd056'

@description('Built-in role: Log Analytics Reader (KQL evidence retrieval).')
param logAnalyticsReaderRoleId string = '73c42c96-874c-492b-b04d-ab87d138a893'

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// ---- Managed API connections -----------------------------------------------
// Both connections are created as shells and MUST be authorized once after
// deployment (portal > the connection > "Authorize" / edit API connection),
// because managed connectors require an interactive OAuth consent.

resource azureSentinelApi 'Microsoft.Web/connections@2016-06-01' = {
  name: azureSentinelConnectionName
  location: location
  properties: {
    displayName: azureSentinelConnectionName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuresentinel')
    }
  }
}

resource securityCopilotApi 'Microsoft.Web/connections@2016-06-01' = {
  name: securityCopilotConnectionName
  location: location
  properties: {
    displayName: securityCopilotConnectionName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'securitycopilot')
    }
  }
}

// ---- Logic App playbook -----------------------------------------------------

resource playbook 'Microsoft.Logic/workflows@2019-05-01' = {
  name: playbookName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: loadJsonContent('workflow-definition.json')
    parameters: {
      logAnalyticsWorkspaceCustomerId: {
        value: workspace.properties.customerId
      }
      '$connections': {
        value: {
          azuresentinel: {
            connectionId: azureSentinelApi.id
            connectionName: azureSentinelConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuresentinel')
          }
          securitycopilot: {
            connectionId: securityCopilotApi.id
            connectionName: securityCopilotConnectionName
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'securitycopilot')
          }
        }
      }
    }
  }
}

// ---- RBAC for the playbook managed identity --------------------------------

resource sentinelResponderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspace.id, playbook.id, sentinelResponderRoleId)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sentinelResponderRoleId)
    principalId: playbook.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource logAnalyticsReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspace.id, playbook.id, logAnalyticsReaderRoleId)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReaderRoleId)
    principalId: playbook.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output playbookResourceId string = playbook.id
output principalId string = playbook.identity.principalId
output azureSentinelConnectionId string = azureSentinelApi.id
output securityCopilotConnectionId string = securityCopilotApi.id
