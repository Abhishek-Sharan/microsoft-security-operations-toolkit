targetScope = 'resourceGroup'

@description('Azure region for the Consumption Logic App.')
param location string = resourceGroup().location

@description('Name of the Logic App workflow.')
param logicAppName string = 'sentinel-incident-comment-upsert'

@description('Subscription containing the Microsoft Sentinel workspace.')
param sentinelSubscriptionId string = subscription().subscriptionId

@description('Resource group containing the Microsoft Sentinel workspace.')
param sentinelResourceGroupName string

@description('Log Analytics workspace used by Microsoft Sentinel.')
param sentinelWorkspaceName string

@description('Log Analytics workspace customer ID (workspace GUID).')
param sentinelWorkspaceCustomerId string

@description('Deploy the Microsoft Sentinel Responder role assignment for the Logic App identity.')
param deploySentinelRoleAssignment bool = true

@description('Optional resource tags.')
param tags object = {}

var workflowDefinition = loadJsonContent('workflow-definition.json')

resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(sentinelSubscriptionId, sentinelResourceGroupName)
  name: sentinelWorkspaceName
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: workflowDefinition
    parameters: {
      defaultSubscriptionId: {
        value: sentinelSubscriptionId
      }
      defaultResourceGroupName: {
        value: sentinelResourceGroupName
      }
      defaultWorkspaceName: {
        value: sentinelWorkspaceName
      }
      sentinelWorkspaceCustomerId: {
        value: sentinelWorkspaceCustomerId
      }
    }
  }
}

module sentinelRbac 'sentinel-rbac.bicep' = if (deploySentinelRoleAssignment) {
  name: 'sentinel-triage-rbac-${uniqueString(logicApp.id, sentinelWorkspace.id)}'
  scope: resourceGroup(sentinelSubscriptionId, sentinelResourceGroupName)
  params: {
    logicAppPrincipalId: logicApp.identity.principalId
    logicAppResourceId: logicApp.id
    sentinelWorkspaceName: sentinelWorkspaceName
  }
}

output logicAppName string = logicApp.name
output logicAppResourceId string = logicApp.id
output logicAppPrincipalId string = logicApp.identity.principalId
output sentinelWorkspaceResourceId string = sentinelWorkspace.id