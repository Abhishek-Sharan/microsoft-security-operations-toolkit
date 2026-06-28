param(
    [string]$TenantId = $env:MDE_TENANT_ID,
    [string]$ClientId = $env:MDE_CLIENT_ID,
    [string]$ClientSecret = $env:MDE_CLIENT_SECRET,
    [string]$MachineIdsCsvPath = "$HOME\MachineIDs.csv",
    [string]$TagValue = "API_Tag-Bulk"
)

$disclaimer = @"
Disclaimer:
The author of this script provides it "as is" without any guarantees or warranties of any kind.
By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution.
It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting.
The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.
"@

Write-Host $disclaimer -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Do you accept the disclaimer and wish to proceed? (Y/N)"
if ($confirmation -notmatch '^[Yy]$') {
    Write-Host "Operation cancelled by user." -ForegroundColor Red
    exit 1
}

$missingValues = @()
if ([string]::IsNullOrWhiteSpace($TenantId)) { $missingValues += "TenantId or MDE_TENANT_ID" }
if ([string]::IsNullOrWhiteSpace($ClientId)) { $missingValues += "ClientId or MDE_CLIENT_ID" }
if ([string]::IsNullOrWhiteSpace($ClientSecret)) { $missingValues += "ClientSecret or MDE_CLIENT_SECRET" }
if (!(Test-Path -LiteralPath $MachineIdsCsvPath)) { $missingValues += "MachineIdsCsvPath file: $MachineIdsCsvPath" }

if ($missingValues.Count -gt 0) {
    Write-Error "Missing required value(s): $($missingValues -join ', ')"
    exit 1
}

$scope = "https://api.securitycenter.microsoft.com/.default"
$tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$tokenRequestBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = $scope
    grant_type    = "client_credentials"
}

$tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $tokenRequestBody -ContentType "application/x-www-form-urlencoded"
$token = $tokenResponse.access_token

Write-Host "Access token acquired successfully."

$machineIds = Import-Csv -LiteralPath $MachineIdsCsvPath | Select-Object -ExpandProperty MachineId
$tagRequestBody = @{
    Value  = $TagValue
    Action = "Add"
} | ConvertTo-Json

foreach ($id in $machineIds) {
    $uri = "https://api.securitycenter.microsoft.com/api/machines/$id/tags"
    try {
        Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            Authorization  = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $tagRequestBody | Out-Null

        Write-Host "Tagged machine: $id"
    }
    catch {
        Write-Host "Failed to tag machine: $id. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
