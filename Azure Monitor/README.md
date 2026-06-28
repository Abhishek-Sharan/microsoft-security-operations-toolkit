# Azure Monitor

This section contains Azure Monitor operational scripts used for agent and extension management.

## Folder structure

| Folder | Purpose |
| --- | --- |
| `Agent-Management/` | Azure Monitor Agent installation, upgrade, cache, and Azure Arc extension management scripts. |

## Current content

| File or folder | Description |
| --- | --- |
| `Agent-Management/Scripts/Azure-VMs/` | PowerShell scripts for installing, uninstalling, and managing Azure Monitor Agent on Azure VMs by resource group. |
| `Agent-Management/Scripts/Azure-Arc/` | PowerShell scripts for Azure Arc extension auto-upgrade and AMA management. |
| `Agent-Management/Scripts/Linux/` | Shell scripts for AMA cache and disk cache checks/configuration on Linux. |
| `Agent-Management/Scripts/Reports/` | Reporting scripts related to security and monitoring extensions. |

These scripts were consolidated from the previous `ExtensionManagement` repository.

