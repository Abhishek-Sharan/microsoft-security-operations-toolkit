targetScope = 'resourceGroup'

@description('Name of the Logic App Consumption playbook.')
param playbookName string = 'sentinel-incident-comment-upsert'

@description('Azure region for the Logic App.')
param location string = resourceGroup().location

@description('Name of the existing Microsoft Sentinel / Log Analytics workspace in this resource group.')
param workspaceName string

@description('Built-in role definition ID for Microsoft Sentinel Contributor.')
param sentinelContributorRoleDefinitionId string = 'ab8e14d6-4a74-4a29-9ba8-549422addade'

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

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
      defaultSubscriptionId: {
        value: subscription().subscriptionId
      }
      defaultResourceGroupName: {
        value: resourceGroup().name
      }
      defaultWorkspaceName: {
        value: workspaceName
      }
      logAnalyticsWorkspaceCustomerId: {
        value: workspace.properties.customerId
      }
    }
  }
}

resource sentinelContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspace.id, playbook.id, sentinelContributorRoleDefinitionId)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sentinelContributorRoleDefinitionId)
    principalId: playbook.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output playbookResourceId string = playbook.id
output principalId string = playbook.identity.principalId

@secure()
output callbackUrl string = listCallbackURL('${playbook.id}/triggers/manual', '2019-05-01').value
