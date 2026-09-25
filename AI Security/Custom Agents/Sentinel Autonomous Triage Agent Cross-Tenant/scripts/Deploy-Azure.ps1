[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [switch] $Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$placeholderGuid = '00000000-0000-0000-0000-000000000000'
$tagFile = $null

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required. Install it from https://aka.ms/installazurecliwindows.'
}
$required = @(
    'tenantId',
    'azureSubscriptionId',
    'deploymentLocation',
    'logicAppResourceGroupName',
    'logicAppLocation',
    'logicAppName',
    'sentinelSubscriptionId',
    'sentinelResourceGroupName',
    'sentinelWorkspaceName'
)
foreach ($name in $required) {
    if ([string]::IsNullOrWhiteSpace([string] $config.$name)) {
        throw "Configuration value '$name' is required."
    }
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

az bicep version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI Bicep is required. Run: az bicep install'
}

$account = az account show -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI authentication is required. Run: az login --tenant $($config.tenantId)"
}
if ($account.tenantId -ne $config.tenantId) {
    throw "Azure CLI is signed in to tenant $($account.tenantId). Run: az login --tenant $($config.tenantId)"
}

az account set --subscription $config.azureSubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Unable to select the deployment subscription.' }

$workspaceUri = "https://management.azure.com/subscriptions/$($config.sentinelSubscriptionId)/resourceGroups/$($config.sentinelResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($config.sentinelWorkspaceName)?api-version=2023-09-01"
$workspace = az rest --method get --url $workspaceUri -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $workspace.properties.customerId) {
    throw 'The destination Microsoft Sentinel workspace was not found or is not accessible.'
}

$templateFile = Join-Path $PSScriptRoot '..\infra\deploy.bicep'
$deploymentName = "sentinel-triage-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$parameters = @(
    "logicAppResourceGroupName=$($config.logicAppResourceGroupName)",
    "logicAppLocation=$($config.logicAppLocation)",
    "logicAppName=$($config.logicAppName)",
    "sentinelSubscriptionId=$($config.sentinelSubscriptionId)",
    "sentinelResourceGroupName=$($config.sentinelResourceGroupName)",
    "sentinelWorkspaceName=$($config.sentinelWorkspaceName)",
    "sentinelWorkspaceCustomerId=$($workspace.properties.customerId)"
)

if ($config.tags) {
    $tagFile = Join-Path ([IO.Path]::GetTempPath()) "sentinel-triage-tags-$PID.json"
    $config.tags | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tagFile -Encoding utf8
    $parameters += "tags=@$tagFile"
}

try {
    $operation = if ($Apply) { 'create' } else { 'what-if' }
    Write-Host "Running subscription deployment $operation in tenant $($config.tenantId)..."
    az deployment sub $operation `
        --name $deploymentName `
        --location $config.deploymentLocation `
        --template-file $templateFile `
        --parameters $parameters
    if ($LASTEXITCODE -ne 0) { throw "Azure deployment $operation failed." }
}
finally {
    if ($tagFile -and (Test-Path $tagFile)) { Remove-Item $tagFile -Force }
}

if (-not $Apply) {
    Write-Host 'What-if completed. Re-run with -Apply to deploy.'
}