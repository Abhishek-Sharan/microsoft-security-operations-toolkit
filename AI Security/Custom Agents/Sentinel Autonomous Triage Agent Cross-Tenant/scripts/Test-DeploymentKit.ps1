[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$kitRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$infraRoot = Join-Path $kitRoot 'infra'
$generatedRoot = Join-Path $kitRoot 'generated'

Get-Content (Join-Path $infraRoot 'workflow-definition.json') -Raw | ConvertFrom-Json | Out-Null
Get-Content $ConfigPath -Raw | ConvertFrom-Json | Out-Null

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required. Install it from https://aka.ms/installazurecliwindows.'
}
az bicep build --file (Join-Path $infraRoot 'deploy.bicep') --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }

& (Join-Path $PSScriptRoot 'New-TenantManifests.ps1') -ConfigPath $ConfigPath -OutputDirectory $generatedRoot | Out-Null

$agent = Get-Content (Join-Path $generatedRoot 'agent.securitycopilot.yaml') -Raw
$plugin = Get-Content (Join-Path $generatedRoot 'logic-app-plugin.securitycopilot.yaml') -Raw
if ($agent -match '__[A-Z0-9_]+__' -or $plugin -match '__[A-Z0-9_]+__') {
    throw 'Generated manifests contain unresolved template tokens.'
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
foreach ($value in @($config.tenantId, $config.sentinelSubscriptionId, $config.sentinelResourceGroupName, $config.sentinelWorkspaceName, $config.logicAppName)) {
    if (-not $agent.Contains([string] $value)) {
        throw "Generated agent manifest is missing destination value '$value'."
    }
}
foreach ($value in @($config.azureSubscriptionId, $config.logicAppResourceGroupName, $config.logicAppName)) {
    if (-not $plugin.Contains([string] $value)) {
        throw "Generated plugin manifest is missing destination value '$value'."
    }
}

Write-Host 'PASS: deployment kit, Bicep, JSON, and generated tenant manifests validated.'