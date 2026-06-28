# **Disclaimer:**

# The author of this script provides it "as is" without any guarantees or warranties of any kind. 
# By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution. 
# It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting. 
# The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.

# Prompt the user to enter the resource group name
$resourceGroupName = Read-Host -Prompt "This script uninstalls AMA extension on Windows VMs in a specific resource group; specify your resource group name to continue"

# Get all VMs in the specified resource group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName

# Loop through each VM and remove the Azure Monitor Agent extension
foreach ($vm in $vms) {
    try {
        Remove-AzVMExtension -ResourceGroupName $resourceGroupName `
                             -VMName $vm.Name `
                             -Name "AzureMonitorWindowsAgent" `
                             -Force

        Write-Host "Successfully uninstalled Azure Monitor Agent from VM: $($vm.Name)" -ForegroundColor Green
    } catch {
        Write-Host "Failed to uninstall Azure Monitor Agent from VM: $($vm.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Uninstallation process completed."
