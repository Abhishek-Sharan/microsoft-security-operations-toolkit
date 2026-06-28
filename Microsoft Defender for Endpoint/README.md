# Microsoft Defender for Endpoint

This section contains Microsoft Defender for Endpoint advanced hunting queries and operational scripts.

## Folder structure

| Folder | Purpose |
| --- | --- |
| `Queries/` | Advanced hunting queries for endpoint posture, secure configuration, and TVM data. |
| `Scripts/` | PowerShell scripts for MDE operational tasks. |

## Current content

| File | Description |
| --- | --- |
| `Queries/Secure-Configuration/AVAndEDRConfigurationsForKeySCIDs.kql` | Reports AV and EDR secure configuration assessment results for key Windows and Linux SCIDs. |
| `Queries/Secure-Configuration/SCIDDetailsFromTVMModule.kql` | Joins secure configuration assessment data with TVM knowledge base metadata for SCID details. |
| `Scripts/Device-Tagging/AddBulkTags.ps1` | Adds an MDE tag to machines listed in a CSV file. Credentials are supplied through parameters or environment variables, not hardcoded in the script. |

## Script credential handling

For `AddBulkTags.ps1`, provide credentials at runtime or through local environment variables:

```powershell
$env:MDE_TENANT_ID = "<tenant-id>"
$env:MDE_CLIENT_ID = "<client-id>"
$env:MDE_CLIENT_SECRET = "<client-secret>"
.\Scripts\Device-Tagging\AddBulkTags.ps1 -MachineIdsCsvPath "$HOME\MachineIDs.csv" -TagValue "API_Tag-Bulk"
```

Do not commit real tenant credentials, client secrets, machine IDs, or production CSV files to this repository.

