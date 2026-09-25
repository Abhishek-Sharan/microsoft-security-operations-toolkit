## ⚠️ Disclaimer

This project is provided for educational and demonstration purposes only.

The software, agents, workflows, prompts, and examples included in this repository are provided **"as is"**, without warranties or guarantees of any kind, express or implied. The authors and contributors make no representations regarding reliability, safety, suitability, security, legality, or fitness for any particular purpose.

By using this project, you acknowledge and agree that:

- 🧑‍💻 You are solely responsible for how you use, modify, deploy, or distribute the software.
- 🧪 You must thoroughly test the project in a controlled and secure environment before using it in production or with sensitive systems/data.
- 🤖 AI agents and automated systems may produce unexpected, inaccurate, incomplete, or harmful outputs and actions.
- ⚠️ This project may contain experimental features, unsafe behaviors, or incomplete safeguards.
- 🚫 The authors are not responsible for any damage, losses, security incidents, operational failures, legal issues, compliance violations, data loss, financial losses, or other consequences resulting from the use of this project.
- 📜 Users are responsible for ensuring compliance with all applicable laws, regulations, platform policies, licensing requirements, and organizational security practices.

This repository is not intended for use in safety-critical, regulated, or production environments without independent review, validation, monitoring, and appropriate safeguards.

### 🚨 Use at your own risk.

## Custom Agents

- [SOC Malware Investigator Portable](Custom%20Agents/SOC%20Malware%20Investigator%20Portable/README.md) - a portable defensive SOC agent for Microsoft Defender XDR and Microsoft Sentinel malware incident triage.
- [Sentinel SOC Triage Autopilot](Custom%20Agents/Sentinel%20SOC%20Triage%20Autopilot/read.md) - a portable Copilot custom agent that uses Sentinel MCP to triage an incident and write back a verified incident comment via a Logic App.
- [Sentinel Autonomous Triage Agent - Cross-Tenant Deployment Kit](Custom%20Agents/Sentinel%20Autonomous%20Triage%20Agent%20Cross-Tenant/README.md) - a self-contained Microsoft Security Copilot agent, Logic App, managed identity, and workspace-scoped RBAC package for portable Sentinel incident triage and verified comment writeback.
- [Sentinel SOC Triage Reasoner (No-Agent)](Custom%20Agents/Sentinel%20SOC%20Triage%20Reasoner%20(No-Agent)/read.md) - an agent-free, connector-triggerable pipeline that collects evidence with KQL and uses a direct Security Copilot prompt (no agent, no MCP) to triage a Sentinel incident and post an HTML report back as a comment.

## Governance Queries

- [Sentinel MCP Governance Queries](Sentinel%20MCP%20Governance/README.md) - portable KQL queries to track Microsoft Sentinel MCP endpoint activity, queried tables, caller identity, and query status using `LAQueryLogs`.
