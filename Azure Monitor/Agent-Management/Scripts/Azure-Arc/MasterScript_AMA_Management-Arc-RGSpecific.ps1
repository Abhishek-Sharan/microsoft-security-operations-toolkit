# **Disclaimer:**
#
# The author of this script provides it "as is" without any guarantees or warranties of any kind.
# By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution.
# It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting.
# The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.

[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Required modules:
# Install-Module Az.Accounts, Az.ConnectedMachine, Az.Compute -Scope CurrentUser

Write-Host "Disclaimer:" -ForegroundColor Yellow
Write-Host "The author of this script provides it ""as is"" without any guarantees or warranties of any kind." -ForegroundColor Yellow
Write-Host "By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution." -ForegroundColor Yellow
Write-Host "It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting." -ForegroundColor Yellow
Write-Host "The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk." -ForegroundColor Yellow
Write-Host ""

$publisher = "Microsoft.Azure.Monitor"
$versionAvailabilityCache = @{}

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

function Get-ArcExtensionVersion {
    param([Parameter(Mandatory)] $Extension)

    foreach ($propertyName in @("TypeHandlerVersion", "InstanceViewTypeHandlerVersion")) {
        if (($Extension.PSObject.Properties.Name -contains $propertyName) -and $Extension.$propertyName) {
            return [string] $Extension.$propertyName
        }
    }

    return $null
}

function Add-CompatibleAutomaticUpgradeParameters {
    param(
        [Parameter(Mandatory)][hashtable] $Parameters,
        [Parameter(Mandatory)][string] $CommandName,
        [Parameter(Mandatory)][string] $MachineName
    )

    $command = Get-Command $CommandName -ErrorAction Stop

    if ($command.Parameters.ContainsKey("EnableAutomaticUpgrade")) {
        $Parameters["EnableAutomaticUpgrade"] = $true
    } else {
        Write-Host "This Az.ConnectedMachine version does not support -EnableAutomaticUpgrade on $CommandName. Skipping that setting for server: $MachineName" -ForegroundColor Yellow
    }

    if ($command.Parameters.ContainsKey("AutoUpgradeMinorVersion")) {
        $Parameters["AutoUpgradeMinorVersion"] = $true
    } else {
        Write-Host "This Az.ConnectedMachine version does not support -AutoUpgradeMinorVersion on $CommandName. Skipping that setting for server: $MachineName" -ForegroundColor Yellow
    }
}

function New-AmaArcExtension {
    param(
        [Parameter(Mandatory)][string] $ResourceGroupName,
        [Parameter(Mandatory)][string] $MachineName,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][string] $ExtensionName,
        [Parameter(Mandatory)][string] $Publisher,
        [Parameter(Mandatory)][string] $TypeHandlerVersion
    )

    $parameters = @{
        Name               = $ExtensionName
        ExtensionType      = $ExtensionName
        Publisher          = $Publisher
        ResourceGroupName  = $ResourceGroupName
        MachineName        = $MachineName
        Location           = $Location
        TypeHandlerVersion = $TypeHandlerVersion
        ErrorAction        = "Stop"
    }

    Add-CompatibleAutomaticUpgradeParameters -Parameters $parameters -CommandName "New-AzConnectedMachineExtension" -MachineName $MachineName
    New-AzConnectedMachineExtension @parameters | Out-Null
}

function Set-AmaArcExtension {
    param(
        [Parameter(Mandatory)][string] $ResourceGroupName,
        [Parameter(Mandatory)][string] $MachineName,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][string] $ExtensionName,
        [Parameter(Mandatory)][string] $Publisher,
        [Parameter(Mandatory)][string] $TypeHandlerVersion
    )

    $parameters = @{
        Name               = $ExtensionName
        ExtensionType      = $ExtensionName
        Publisher          = $Publisher
        ResourceGroupName  = $ResourceGroupName
        MachineName        = $MachineName
        Location           = $Location
        TypeHandlerVersion = $TypeHandlerVersion
        ErrorAction        = "Stop"
    }

    Add-CompatibleAutomaticUpgradeParameters -Parameters $parameters -CommandName "Set-AzConnectedMachineExtension" -MachineName $MachineName
    Set-AzConnectedMachineExtension @parameters | Out-Null
}

function Test-AmaExtensionVersionAvailable {
    param(
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][string] $ExtensionName,
        [Parameter(Mandatory)][string] $TypeHandlerVersion
    )

    $cacheKey = "$Location|$ExtensionName|$TypeHandlerVersion"
    if ($versionAvailabilityCache.ContainsKey($cacheKey)) {
        return $versionAvailabilityCache[$cacheKey]
    }

    $matchingVersions = @(
        Get-AzVMExtensionImage -Location $Location `
                               -PublisherName "Microsoft.Azure.Monitor" `
                               -Type $ExtensionName `
                               -Version "$TypeHandlerVersion*" `
                               -ErrorAction Stop
    )

    $versionAvailabilityCache[$cacheKey] = ($matchingVersions.Count -gt 0)
    return $versionAvailabilityCache[$cacheKey]
}

# Prompt the user to enter the resource group name
$resourceGroupPrompt = "This script can install/update/uninstall AMA extension on Azure Arc servers in a specific resource group; specify your resource group to continue"
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
    $confirmation = Read-Host -Prompt "Uninstall removes AMA from all matching Azure Arc servers in this resource group. Type UNINSTALL to continue"
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
    # Get all Azure Arc-enabled servers in the specified resource group.
    $arcServers = @(Get-AzConnectedMachine -ResourceGroupName $resourceGroupName -ErrorAction Stop)
} catch {
    Write-Host "Resource group not found, not accessible, or Azure Arc server query failed: $resourceGroupName" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Check if there are any Arc servers with the specified operating system.
$osArcServers = @($arcServers | Where-Object {
    if ($null -ne $_.OSName) {
        $_.OSName -eq $osType
    } elseif ($null -ne $_.OSType) {
        $_.OSType -eq $osType
    }
})

if ($osArcServers.Count -eq 0) {
    Write-Host "No Azure Arc servers with the specified operating system found in the resource group." -ForegroundColor Red
    exit
}

Write-Host "Found $($osArcServers.Count) $osType Azure Arc server(s) in resource group '$resourceGroupName'." -ForegroundColor Cyan
Write-Host "Operation: $operation; Extension: $extensionName" -ForegroundColor Cyan

# Loop through each Arc server and perform the specified operation.
foreach ($arcServer in $osArcServers) {
    try {
        $existingExtension = Get-AzConnectedMachineExtension -ResourceGroupName $resourceGroupName `
                                                            -MachineName $arcServer.Name `
                                                            -Name $extensionName `
                                                            -ErrorAction SilentlyContinue

        if (($operation -eq "Install") -or ($operation -eq "Update")) {
            if (-not (Test-AmaExtensionVersionAvailable -Location $arcServer.Location -ExtensionName $extensionName -TypeHandlerVersion $typeHandlerVersion)) {
                Write-Host "Skipping Azure Arc server: $($arcServer.Name). AMA version '$typeHandlerVersion' was not found for extension '$extensionName' in location '$($arcServer.Location)'." -ForegroundColor Yellow
                continue
            }
        }

        if ($operation -eq "Install") {
            if ($null -ne $existingExtension) {
                Write-Host "AMA extension already exists on Azure Arc server: $($arcServer.Name). Use Update operation to change version." -ForegroundColor Yellow
                continue
            }

            if ($PSCmdlet.ShouldProcess($arcServer.Name, "Install $extensionName version $typeHandlerVersion")) {
                New-AmaArcExtension -ResourceGroupName $resourceGroupName `
                                    -MachineName $arcServer.Name `
                                    -Location $arcServer.Location `
                                    -ExtensionName $extensionName `
                                    -Publisher $publisher `
                                    -TypeHandlerVersion $typeHandlerVersion
            }

            Write-Host "Successfully submitted AMA install on Azure Arc server: $($arcServer.Name)" -ForegroundColor Green
        } elseif ($operation -eq "Update") {
            if ($null -eq $existingExtension) {
                Write-Host "AMA extension is not installed on Azure Arc server: $($arcServer.Name). Use Install operation first." -ForegroundColor Yellow
                continue
            }

            $currentVersion = Get-ArcExtensionVersion -Extension $existingExtension
            $currentParsed = ConvertTo-VersionOrNull -Version $currentVersion
            $targetParsed = ConvertTo-VersionOrNull -Version $typeHandlerVersion

            if (($null -ne $currentParsed) -and ($null -ne $targetParsed) -and ($currentParsed -ge $targetParsed)) {
                Write-Host "Skipping Azure Arc server: $($arcServer.Name). Current version '$currentVersion' is already at or above target '$typeHandlerVersion'." -ForegroundColor Yellow
                continue
            }

            $extensionTarget = @{
                "$publisher.$extensionName" = @{
                    targetVersion = $typeHandlerVersion
                }
            }

            if ($PSCmdlet.ShouldProcess($arcServer.Name, "Update $extensionName from version '$currentVersion' to '$typeHandlerVersion'")) {
                Update-AzConnectedExtension -ResourceGroupName $resourceGroupName `
                                            -MachineName $arcServer.Name `
                                            -ExtensionTarget $extensionTarget `
                                            -ErrorAction Stop | Out-Null

                Set-AmaArcExtension -ResourceGroupName $resourceGroupName `
                                    -MachineName $arcServer.Name `
                                    -Location $arcServer.Location `
                                    -ExtensionName $extensionName `
                                    -Publisher $publisher `
                                    -TypeHandlerVersion $typeHandlerVersion
            }

            Write-Host "Successfully submitted AMA in-place update on Azure Arc server: $($arcServer.Name)" -ForegroundColor Green
        } elseif ($operation -eq "Uninstall") {
            if ($null -eq $existingExtension) {
                Write-Host "AMA extension is not installed on Azure Arc server: $($arcServer.Name)" -ForegroundColor Yellow
                continue
            }

            if ($PSCmdlet.ShouldProcess($arcServer.Name, "Uninstall $extensionName")) {
                Remove-AzConnectedMachineExtension -ResourceGroupName $resourceGroupName `
                                                   -MachineName $arcServer.Name `
                                                   -Name $extensionName `
                                                   -ErrorAction Stop | Out-Null
            }

            Write-Host "Successfully submitted AMA uninstall from Azure Arc server: $($arcServer.Name)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to process Azure Arc server: $($arcServer.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Operation process completed."
