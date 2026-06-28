# Disclaimer 
Write-Host "************************* DISCLAIMER *************************"
Write-Host "The author of this script provides it 'as is' without any guarantees or warranties of any kind."
Write-Host "By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution."
Write-Host "It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting."
Write-Host "The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk."
Write-Host "***************************************************************"
Write-Host ""

# Prompt the user for consent after displaying the disclaimer
$consent = Read-Host -Prompt "Do you consent to proceed with the script? (Type 'yes' to continue)"

# If the user does not consent, exit the script
if ($consent -ne "yes") {
    Write-Host "You did not consent. Exiting the script."
    exit
}

# If consent is given, continue with the rest of the script
Write-Host "Proceeding with the script..."

# Get all VMs in the subscription
$vms = Get-AzVM

# Initialize an array to collect the output
$outputData = @()

# Loop through each VM and check extensions
$vms | ForEach-Object {
    $vm = $_

    # Get the VM status with extensions
    $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    $extensions = ($vmStatus).Extensions | Where-Object { $_.Name -eq "MDE.Windows" -or $_.Name -eq "MDE.Linux" }

    # Get the VM OS type (Windows/Linux)
    $osType = $vm.StorageProfile.OsDisk.OsType

    if ($extensions.Count -eq 0) {
        # If no MDE extensions found, append a message indicating they are missing
        $outputData += [PSCustomObject]@{
            "Subscription Name" = (Get-AzContext).Subscription.Name
            "VM Name"           = $vm.Name
            "VM OS"             = $osType
            "Extension Name"    = "MDE Extensions Missing"
            "Display Status"    = "N/A"
            "Message"           = "MDE.Windows or MDE.Linux extensions are missing."
        }
    } else {
        # Process the extensions if found
        $extensions | ForEach-Object {
            # Get the message and parse it into a single line
            $message = $_.Statuses.Message

            # Remove line breaks or newlines and replace them with spaces
            $singleLineMessage = $message -replace "`r`n|`n|`r", " "

            # If the message is JSON, we can parse it (optional)
            try {
                $parsedMessage = $singleLineMessage | ConvertFrom-Json
                # Convert the JSON back to a single-line string
                $singleLineMessage = $parsedMessage | ConvertTo-Json -Compress
            } catch {
                # If it's not JSON, keep the message as is
            }

            # Create a custom object for the table output with the single-line message
            $outputData += [PSCustomObject]@{
                "Subscription Name" = (Get-AzContext).Subscription.Name
                "VM Name"           = $vm.Name
                "VM OS"             = $osType
                "Extension Name"    = $_.Name
                "Display Status"    = $_.Statuses.DisplayStatus
                "Message"           = $singleLineMessage
            }
        }
    }
}

# Output to the console in a formatted table
$outputData | Format-Table -Property "Subscription Name", "VM Name", "VM OS", "Extension Name", "Display Status", "Message"

# Specify the CSV file path
$csvFilePath = "/home/abhishek/MDEExtReport/mdeextreport_output.csv"  # Update the path to where you want to store the CSV

# Check if the directory exists
$directory = [System.IO.Path]::GetDirectoryName($csvFilePath)
if (-not (Test-Path -Path $directory)) {
    # Create the directory if it doesn't exist
    Write-Host "Directory does not exist. Creating directory: $directory"
    New-Item -ItemType Directory -Force -Path $directory
}

# Check if the file exists and create it if missing
if (-not (Test-Path -Path $csvFilePath)) {
    Write-Host "File does not exist. Creating file: $csvFilePath"
}

# Save the output to a CSV file locally
$outputData | Export-Csv -Path $csvFilePath -NoTypeInformation
Write-Host "The report has been saved to: $csvFilePath"
