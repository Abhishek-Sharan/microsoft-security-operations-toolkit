# ================== DISCLAIMER ==================
$disclaimer = @"
DISCLAIMER:
The author of this script provides it "as is" without any guarantees or warranties of any kind.
By using this script, you acknowledge that you are solely responsible for any damage, data loss,
or other issues that may arise from its execution.
It is your responsibility to thoroughly test the script in a controlled environment before
deploying it in a production setting.
The author will not be held liable for any consequences resulting from the use of this script.
Use at your own risk.
"@

Write-Host $disclaimer -ForegroundColor Yellow

$consent = Read-Host "Do you acknowledge this disclaimer and want to proceed? (Y/N)"
if ($consent -notin @("Y", "y")) {
    Write-Host "Execution cancelled by user." -ForegroundColor Red
    exit
}

# ================== CONFIGURATION ==================
Set-AzContext -Subscription "YOUR SUBSCRIPTION"

$resourceGroup = "YOUR RESOURCE GROUP"

# Tag used to identify machines
$tagName  = "YOUR_TAG_NAME"
$tagValue = "YOUR_TAG_VALUE"

# ================== DISCOVER MACHINES ==================
Write-Host "`nDiscovering Azure Arc machines with tag '$tagName = $tagValue'..." -ForegroundColor Cyan

$machines = Get-AzResource `
    -ResourceGroupName $resourceGroup `
    -ResourceType "Microsoft.HybridCompute/machines" |
    Where-Object { $_.Tags[$tagName] -eq $tagValue }

if (-not $machines) {
    Write-Warning "No machines found with the specified tag. Exiting."
    exit
}

Write-Host "Found $($machines.Count) machine(s)." -ForegroundColor Green

# ================== UPDATE MACHINES ==================
$results = @()

foreach ($machine in $machines) {
    Write-Host "Updating agent settings for $($machine.Name)..." -ForegroundColor White
    $status = "Failed"

    try {
        $params = @{
            ResourceGroupName    = $resourceGroup
            ResourceProviderName = "Microsoft.HybridCompute"
            ResourceType         = "Machines"
            ApiVersion           = "2024-05-20-preview"
            Name                 = $machine.Name
            Method               = "PATCH"
            Payload              = '{"properties":{"agentUpgrade":{"enableAutomaticUpgrade":true}}}'
        }

        Invoke-AzRestMethod @params -ErrorAction Stop
        $status = "Success"
        Write-Host "✔ $($machine.Name) updated successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "✖ $($machine.Name) failed — $($_.Exception.Message)"
    }

    $results += [PSCustomObject]@{
        MachineName            = $machine.Name
        EnableAutomaticUpgrade = $true
        Result                 = $status
    }
}

# ================== FINAL OUTPUT ==================
Write-Host "`n===== Final Summary =====" -ForegroundColor Cyan
$results | Format-Table -AutoSize
