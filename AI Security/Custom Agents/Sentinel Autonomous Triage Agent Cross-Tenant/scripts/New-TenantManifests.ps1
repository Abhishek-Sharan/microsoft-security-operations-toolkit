[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [string] $OutputDirectory = (Join-Path $PSScriptRoot '..\generated'),

    [string] $AgentSourcePath = (Join-Path $PSScriptRoot '..\templates\agent.template.yaml'),

    [string] $PluginSourcePath = (Join-Path $PSScriptRoot '..\templates\logic-app-plugin.template.yaml')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$placeholderGuid = '00000000-0000-0000-0000-000000000000'

function Assert-Value {
    param([string] $Name, [object] $Value)
    if ([string]::IsNullOrWhiteSpace([string] $Value)) {
        throw "Configuration value '$Name' is required."
    }
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$required = @(
    'tenantId',
    'azureSubscriptionId',
    'logicAppResourceGroupName',
    'logicAppName',
    'sentinelSubscriptionId',
    'sentinelResourceGroupName',
    'sentinelWorkspaceName',
    'solutionPrefix'
)
foreach ($name in $required) {
    Assert-Value -Name $name -Value $config.$name
}

foreach ($name in @('tenantId', 'azureSubscriptionId', 'sentinelSubscriptionId')) {
    if ([string] $config.$name -eq $placeholderGuid) {
        throw "Configuration value '$name' must be replaced with a destination-tenant value."
    }
    $parsedGuid = [guid]::Empty
    if (-not [guid]::TryParse([string] $config.$name, [ref] $parsedGuid)) {
        throw "Configuration value '$name' must be a valid GUID."
    }
}

if ($config.solutionPrefix -notmatch '^[A-Za-z][A-Za-z0-9]{2,30}$') {
    throw 'solutionPrefix must start with a letter and contain 3-31 alphanumeric characters.'
}

$workspaceCustomerId = [string] $config.sentinelWorkspaceCustomerId
if ($workspaceCustomerId -eq $placeholderGuid) {
    throw "Configuration value 'sentinelWorkspaceCustomerId' must be replaced or left blank for Azure lookup."
}
if (-not [string]::IsNullOrWhiteSpace($workspaceCustomerId)) {
    $parsedWorkspaceGuid = [guid]::Empty
    if (-not [guid]::TryParse($workspaceCustomerId, [ref] $parsedWorkspaceGuid)) {
        throw "Configuration value 'sentinelWorkspaceCustomerId' must be a valid GUID or left blank."
    }
}
if ([string]::IsNullOrWhiteSpace($workspaceCustomerId)) {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI is required to retrieve sentinelWorkspaceCustomerId when it is blank.'
    }
    $workspaceUri = "https://management.azure.com/subscriptions/$($config.sentinelSubscriptionId)/resourceGroups/$($config.sentinelResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($config.sentinelWorkspaceName)?api-version=2023-09-01"
    $workspace = az rest --method get --url $workspaceUri -o json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $workspace.properties.customerId) {
        throw 'Could not retrieve the destination Sentinel workspace customer ID.'
    }
    $workspaceCustomerId = [string] $workspace.properties.customerId
}

$agentText = [IO.File]::ReadAllText((Resolve-Path $AgentSourcePath))
$pluginText = [IO.File]::ReadAllText((Resolve-Path $PluginSourcePath))

$agentSkillset = "$($config.solutionPrefix)SentinelTriageAgentSkillset"
$agentName = "$($config.solutionPrefix)SentinelTriageAgent"
$agentDisplayName = "$($config.solutionPrefix) Sentinel Triage Agent"
$pluginSkillset = "$($config.solutionPrefix)SentinelCommentUpsertSkillset"
$pluginSkill = "$($config.solutionPrefix)SentinelCommentUpsert"
$pluginDisplayName = "$($config.solutionPrefix) Sentinel Comment Upsert"

$agentReplacements = [ordered]@{
    '__AGENT_SKILLSET__' = $agentSkillset
    '__AGENT_NAME__' = $agentName
    '__AGENT_DISPLAY_NAME__' = $agentDisplayName
    '__PLUGIN_SKILLSET__' = $pluginSkillset
    '__PLUGIN_SKILL__' = $pluginSkill
    '__TENANT_ID__' = [string] $config.tenantId
    '__AZURE_SUBSCRIPTION_ID__' = [string] $config.azureSubscriptionId
    '__LOGIC_APP_RESOURCE_GROUP__' = [string] $config.logicAppResourceGroupName
    '__LOGIC_APP_NAME__' = [string] $config.logicAppName
    '__SENTINEL_SUBSCRIPTION_ID__' = [string] $config.sentinelSubscriptionId
    '__SENTINEL_RESOURCE_GROUP__' = [string] $config.sentinelResourceGroupName
    '__SENTINEL_WORKSPACE__' = [string] $config.sentinelWorkspaceName
}
foreach ($entry in $agentReplacements.GetEnumerator()) {
    if (-not $agentText.Contains($entry.Key)) {
        throw "Expected agent template value '$($entry.Key)' was not found."
    }
    $agentText = $agentText.Replace($entry.Key, $entry.Value)
}

$pluginReplacements = [ordered]@{
    '__PLUGIN_SKILLSET__' = $pluginSkillset
    '__PLUGIN_DISPLAY_NAME__' = $pluginDisplayName
    '__PLUGIN_SKILL__' = $pluginSkill
    '__AZURE_SUBSCRIPTION_ID__' = [string] $config.azureSubscriptionId
    '__LOGIC_APP_RESOURCE_GROUP__' = [string] $config.logicAppResourceGroupName
    '__LOGIC_APP_NAME__' = [string] $config.logicAppName
}
foreach ($entry in $pluginReplacements.GetEnumerator()) {
    if (-not $pluginText.Contains($entry.Key)) {
        throw "Expected plugin template value '$($entry.Key)' was not found."
    }
    $pluginText = $pluginText.Replace($entry.Key, $entry.Value)
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$agentOutput = Join-Path $OutputDirectory 'agent.securitycopilot.yaml'
$pluginOutput = Join-Path $OutputDirectory 'logic-app-plugin.securitycopilot.yaml'
[IO.File]::WriteAllText($agentOutput, $agentText, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($pluginOutput, $pluginText, [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    AgentManifest = (Resolve-Path $agentOutput).Path
    PluginManifest = (Resolve-Path $pluginOutput).Path
    AgentSkillset = $agentSkillset
    AgentName = $agentName
    PluginSkillset = $pluginSkillset
    PluginSkill = $pluginSkill
    SentinelWorkspaceCustomerId = $workspaceCustomerId
} | ConvertTo-Json