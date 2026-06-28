# Microsoft Defender for Cloud

This section contains Microsoft Defender for Cloud queries and automation templates.

## Folder structure

| Folder | Purpose |
| --- | --- |
| `Queries/` | KQL queries for Defender for Cloud posture and recommendation analysis. |
| `Automation/` | ARM, Logic App, or playbook templates that automate Defender for Cloud workflows. |

## Current content

| File | Description |
| --- | --- |
| `Queries/Posture-Management/ResourcesMovingFromHealthyToUnhealthyState.kql` | Finds resources that recently moved from healthy to unhealthy recommendation state. |
| `Automation/Logic-Apps/ResourcesMovingFromHealthyToUnhealthyState.arm.json` | ARM template for a Logic App that emails a report for resources moving from healthy to unhealthy state. |

Review parameters such as workspace name, resource group, API connections, and email recipient before deployment.

