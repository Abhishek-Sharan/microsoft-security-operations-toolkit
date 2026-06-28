# **Disclaimer:**
#
# The author of this script provides it "as is" without any guarantees or warranties of any kind.
# By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution.
# It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting.
# The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.

# Purpose:
# Upgrade the Azure Monitor Agent extension on one or more Linux Azure Arc-enabled servers.
#
# Required modules:
# Install-Module Az.Accounts, Az.ConnectedMachine -Scope CurrentUser

$publisher = "Microsoft.Azure.Monitor"
$extensionName = "AzureMonitorLinuxAgent"

$resourceGroupName = Read-Host -Prompt "Enter the Azure resource group name"
$machineNamesInput = Read-Host -Prompt "Enter Linux Azure Arc server name(s), separated by commas"
$typeHandlerVersion = Read-Host -Prompt "Enter the target AMA Type Handler Version"

if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
    Write-Host "Resource group name cannot be empty." -ForegroundColor Red
    exit
}

if ([string]::IsNullOrWhiteSpace($machineNamesInput)) {
    Write-Host "Azure Arc server name list cannot be empty." -ForegroundColor Red
    exit
}

if ([string]::IsNullOrWhiteSpace($typeHandlerVersion)) {
    Write-Host "Target Type Handler Version cannot be empty." -ForegroundColor Red
    exit
}

$machineNames = $machineNamesInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if ($machineNames.Count -eq 0) {
    Write-Host "No valid Azure Arc server names were provided." -ForegroundColor Red
    exit
}

foreach ($machineName in $machineNames) {
    try {
    Write-Host "Processing Linux Azure Arc server: $machineName" -ForegroundColor Cyan

    $arcServer = Get-AzConnectedMachine -ResourceGroupName $resourceGroupName `
                                        -Name $machineName `
                                        -ErrorAction Stop

    if (($null -ne $arcServer.OSName) -and ($arcServer.OSName -ne "Linux")) {
        Write-Host "The specified Azure Arc server is not Linux. Detected OS: $($arcServer.OSName)" -ForegroundColor Red
        continue
    }

    $existingExtension = Get-AzConnectedMachineExtension -ResourceGroupName $resourceGroupName `
                                                        -MachineName $machineName `
                                                        -Name $extensionName `
                                                        -ErrorAction SilentlyContinue

    if ($null -eq $existingExtension) {
        Write-Host "Azure Monitor Agent Linux extension is not installed on server: $machineName" -ForegroundColor Red
        Write-Host "Install the extension first, then rerun this upgrade script." -ForegroundColor Yellow
        continue
    }

    $extensionTarget = @{
        "$publisher.$extensionName" = @{
            targetVersion = $typeHandlerVersion
        }
    }

    Update-AzConnectedExtension -ResourceGroupName $resourceGroupName `
                                -MachineName $machineName `
                                -ExtensionTarget $extensionTarget `
                                -ErrorAction Stop | Out-Null

    Set-AzConnectedMachineExtension -Name $extensionName `
                                    -ExtensionType $extensionName `
                                    -Publisher $publisher `
                                    -ResourceGroupName $resourceGroupName `
                                    -MachineName $machineName `
                                    -Location $arcServer.Location `
                                    -TypeHandlerVersion $typeHandlerVersion `
                                    -EnableAutomaticUpgrade `
                                    -AutoUpgradeMinorVersion `
                                    -ErrorAction Stop | Out-Null

    Write-Host "Successfully submitted AMA upgrade for Linux Azure Arc server: $machineName" -ForegroundColor Green
    Write-Host "Target AMA version: $typeHandlerVersion" -ForegroundColor Green
    Write-Host "Automatic extension upgrade is enabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to upgrade AMA on Linux Azure Arc server: $machineName" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
}

Write-Host "AMA upgrade process completed."
