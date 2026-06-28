# Microsoft Sentinel

This section contains Microsoft Sentinel queries, automation samples, scripts, and supporting tools for security operations scenarios.

## Folder structure

| Folder | Purpose |
| --- | --- |
| `Queries/` | KQL queries grouped by investigation or operations theme. |
| `Automation/` | Logic App and playbook templates for Sentinel-related workflows. |
| `Scripts/` | PowerShell and API examples for Sentinel administration or investigation. |
| `Tools/` | Supporting utilities and helper assets. |

## Query categories

| Category | Examples |
| --- | --- |
| `Queries/Identity/` | Sign-in anomalies, first sign-in discovery, failed-then-successful sign-in patterns. |
| `Queries/Network/` | Newly contacted domains and web-port connections by non-system accounts. |
| `Queries/Log-Ingestion/` | Table volume, CommonSecurityLog volume, ingestion spikes, and Syslog severity trends. |
| `Queries/Endpoint/` | Endpoint or VM telemetry health checks. |
| `Queries/User-Behavior/` | Behavior analytics and anomaly score review. |

## Notes

- KQL files use the `.kql` extension for easier discovery and editor syntax highlighting.
- Automation JSON files are templates and may require tenant-specific values before deployment.
- Scripts use placeholder values where subscription, resource group, workspace, or incident identifiers are required.

