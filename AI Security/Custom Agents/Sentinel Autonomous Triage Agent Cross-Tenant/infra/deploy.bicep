targetScope = 'subscription'

@description('Resource group in which the Logic App is deployed.')
param logicAppResourceGroupName string

@description('Azure region for the Logic App resource group.')
param logicAppLocation string

@description('Name of the Logic App workflow.')
param logicAppName string

@description('Subscription containing the Microsoft Sentinel workspace.')
param sentinelSubscriptionId string

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

resource logicAppResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: logicAppResourceGroupName
  location: logicAppLocation
  tags: tags
}

module solution 'main.bicep' = {
  name: 'sentinel-triage-solution'
  scope: logicAppResourceGroup
  params: {
    location: logicAppLocation
    logicAppName: logicAppName
    sentinelSubscriptionId: sentinelSubscriptionId
    sentinelResourceGroupName: sentinelResourceGroupName
    sentinelWorkspaceName: sentinelWorkspaceName
    sentinelWorkspaceCustomerId: sentinelWorkspaceCustomerId
    deploySentinelRoleAssignment: deploySentinelRoleAssignment
    tags: tags
  }
}

output logicAppName string = solution.outputs.logicAppName
output logicAppResourceId string = solution.outputs.logicAppResourceId
output logicAppPrincipalId string = solution.outputs.logicAppPrincipalId
output sentinelWorkspaceResourceId string = solution.outputs.sentinelWorkspaceResourceId