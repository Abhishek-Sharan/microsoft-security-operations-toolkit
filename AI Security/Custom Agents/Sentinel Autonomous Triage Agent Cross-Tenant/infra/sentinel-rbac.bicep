targetScope = 'resourceGroup'

@description('Object ID of the Logic App system-assigned managed identity.')
param logicAppPrincipalId string

@description('Resource ID of the Logic App, used to create a deterministic role assignment ID.')
param logicAppResourceId string

@description('Log Analytics workspace used by Microsoft Sentinel.')
param sentinelWorkspaceName string

var sentinelResponderRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '3e150937-b8fe-4cfb-8069-0eaf05ecd056'
)

resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: sentinelWorkspaceName
}

resource sentinelResponderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sentinelWorkspace.id, logicAppResourceId, sentinelResponderRoleDefinitionId)
  scope: sentinelWorkspace
  properties: {
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: sentinelResponderRoleDefinitionId
    description: 'Allows the triage Logic App to read Sentinel data and upsert incident comments.'
  }
}