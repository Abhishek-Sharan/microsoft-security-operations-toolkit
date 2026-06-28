# **Disclaimer:**
#
# The author of this script provides it "as is" without any guarantees or warranties of any kind.
# By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution.
# It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting.
# The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.

[CmdletBinding(SupportsShouldProcess = $true)]
param()

Write-Host "Disclaimer:" -ForegroundColor Yellow
Write-Host "The author of this script provides it ""as is"" without any guarantees or warranties of any kind." -ForegroundColor Yellow
Write-Host "By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution." -ForegroundColor Yellow
Write-Host "It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting." -ForegroundColor Yellow
Write-Host "The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk." -ForegroundColor Yellow
Write-Host ""

$publisher = "Microsoft.Azure.Monitor"

function ConvertTo-VersionOrNull {
    param([string] $Version)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        return $null
    }

    try {
        return [version] $Version
    } catch {
        return $null
    }
}

function Set-AmaVmExtension {
    param(
        [Parameter(Mandatory)][string] $ResourceGroupName,
        [Parameter(Mandatory)][string] $VMName,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][string] $ExtensionName,
        [Parameter(Mandatory)][string] $Publisher,
        [Parameter(Mandatory)][string] $TypeHandlerVersion
    )

    $command = Get-Command Set-AzVMExtension -ErrorAction Stop
    $parameters = @{
        Name               = $ExtensionName
        ExtensionType      = $ExtensionName
        Publisher          = $Publisher
        ResourceGroupName  = $ResourceGroupName
        VMName             = $VMName
        Location           = $Location
        TypeHandlerVersion = $TypeHandlerVersion
        ErrorAction        = "Stop"
    }

    if ($command.Parameters.ContainsKey("EnableAutomaticUpgrade")) {
        $parameters["EnableAutomaticUpgrade"] = $true
    } else {
        Write-Host "This Az.Compute version does not support -EnableAutomaticUpgrade on Set-AzVMExtension. Skipping that setting for VM: $VMName" -ForegroundColor Yellow
    }

    if ($command.Parameters.ContainsKey("AutoUpgradeMinorVersion")) {
        $parameters["AutoUpgradeMinorVersion"] = $true
    } elseif ($command.Parameters.ContainsKey("DisableAutoUpgradeMinorVersion")) {
        $parameters["DisableAutoUpgradeMinorVersion"] = $false
    } else {
        Write-Host "This Az.Compute version does not support an auto-upgrade-minor-version parameter on Set-AzVMExtension. Skipping that setting for VM: $VMName" -ForegroundColor Yellow
    }

    Set-AzVMExtension @parameters | Out-Null
}

# Prompt the user to enter the resource group name
$resourceGroupPrompt = "This script can install/update/uninstall AMA extension on Azure VMs in a specific resource group; specify your resource group to continue"
Write-Host -NoNewline "$resourceGroupPrompt`: "
$resourceGroupName = ([Console]::ReadLine()).Trim()

# Prompt the user to enter the operating system (Windows/Linux)
$osType = (Read-Host -Prompt "Enter the Operating System (Windows/Linux)").Trim()

# Prompt the user to enter the operation (Install/Update/Uninstall)
$operation = (Read-Host -Prompt "Enter the Operation (Install/Update/Uninstall)").Trim()

if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
    Write-Host "Resource group name cannot be empty." -ForegroundColor Red
    exit
}

if (($osType -ne "Windows") -and ($osType -ne "Linux")) {
    Write-Host "Invalid Operating System specified. Please enter either 'Windows' or 'Linux'." -ForegroundColor Red
    exit
}

if (($operation -ne "Install") -and ($operation -ne "Update") -and ($operation -ne "Uninstall")) {
    Write-Host "Invalid Operation specified. Please enter 'Install', 'Update', or 'Uninstall'." -ForegroundColor Red
    exit
}

if (($operation -eq "Install") -or ($operation -eq "Update")) {
    $typeHandlerVersion = (Read-Host -Prompt "Enter the target Type Handler Version").Trim()

    if ([string]::IsNullOrWhiteSpace($typeHandlerVersion)) {
        Write-Host "Target Type Handler Version cannot be empty." -ForegroundColor Red
        exit
    }
}

if ($operation -eq "Uninstall") {
    $confirmation = Read-Host -Prompt "Uninstall removes AMA from all matching VMs in this resource group. Type UNINSTALL to continue"
    if ($confirmation -ne "UNINSTALL") {
        Write-Host "Uninstall cancelled." -ForegroundColor Yellow
        exit
    }
}

if ($osType -eq "Windows") {
    $extensionName = "AzureMonitorWindowsAgent"
} else {
    $extensionName = "AzureMonitorLinuxAgent"
}

try {
    Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Resource group not found or not accessible: $resourceGroupName" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Get all VMs in the specified resource group
$vms = @(Get-AzVM -ResourceGroupName $resourceGroupName -ErrorAction Stop)

# Check if there are any VMs with the specified operating system
$osVms = @($vms | Where-Object { $_.StorageProfile.OSDisk.OSType -eq $osType })

if ($osVms.Count -eq 0) {
    Write-Host "No VMs with the specified operating system found in the resource group." -ForegroundColor Red
    exit
}

Write-Host "Found $($osVms.Count) $osType VM(s) in resource group '$resourceGroupName'." -ForegroundColor Cyan
Write-Host "Operation: $operation; Extension: $extensionName" -ForegroundColor Cyan

# Loop through each VM and perform the specified operation
foreach ($vm in $osVms) {
    try {
        $existingExtension = Get-AzVMExtension -ResourceGroupName $resourceGroupName `
                                               -VMName $vm.Name `
                                               -Name $extensionName `
                                               -ErrorAction SilentlyContinue

        if ($operation -eq "Install") {
            if ($null -ne $existingExtension) {
                Write-Host "AMA extension already exists on VM: $($vm.Name). Use Update operation to change version." -ForegroundColor Yellow
                continue
            }

            if ($PSCmdlet.ShouldProcess($vm.Name, "Install $extensionName version $typeHandlerVersion")) {
                Set-AmaVmExtension -ResourceGroupName $resourceGroupName `
                                   -VMName $vm.Name `
                                   -Location $vm.Location `
                                   -ExtensionName $extensionName `
                                   -Publisher $publisher `
                                   -TypeHandlerVersion $typeHandlerVersion
            }

            Write-Host "Successfully submitted AMA install on VM: $($vm.Name)" -ForegroundColor Green
        } elseif ($operation -eq "Update") {
            if ($null -eq $existingExtension) {
                Write-Host "AMA extension is not installed on VM: $($vm.Name). Use Install operation first." -ForegroundColor Yellow
                continue
            }

            $currentVersion = $existingExtension.TypeHandlerVersion
            $currentParsed = ConvertTo-VersionOrNull -Version $currentVersion
            $targetParsed = ConvertTo-VersionOrNull -Version $typeHandlerVersion

            if (($null -ne $currentParsed) -and ($null -ne $targetParsed) -and ($currentParsed -ge $targetParsed)) {
                Write-Host "Skipping VM: $($vm.Name). Current version '$currentVersion' is already at or above target '$typeHandlerVersion'." -ForegroundColor Yellow
                continue
            }

            if ($PSCmdlet.ShouldProcess($vm.Name, "Update $extensionName from version '$currentVersion' to '$typeHandlerVersion'")) {
                Set-AmaVmExtension -ResourceGroupName $resourceGroupName `
                                   -VMName $vm.Name `
                                   -Location $vm.Location `
                                   -ExtensionName $extensionName `
                                   -Publisher $publisher `
                                   -TypeHandlerVersion $typeHandlerVersion
            }

            Write-Host "Successfully submitted AMA in-place update on VM: $($vm.Name)" -ForegroundColor Green
        } elseif ($operation -eq "Uninstall") {
            if ($null -eq $existingExtension) {
                Write-Host "AMA extension is not installed on VM: $($vm.Name)" -ForegroundColor Yellow
                continue
            }

            if ($PSCmdlet.ShouldProcess($vm.Name, "Uninstall $extensionName")) {
                Remove-AzVMExtension -ResourceGroupName $resourceGroupName `
                                     -VMName $vm.Name `
                                     -Name $extensionName `
                                     -Force `
                                     -ErrorAction Stop | Out-Null
            }

            Write-Host "Successfully submitted AMA uninstall from VM: $($vm.Name)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to process VM: $($vm.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Operation process completed."
