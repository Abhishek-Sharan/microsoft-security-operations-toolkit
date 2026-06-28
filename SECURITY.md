# Security Policy

## Supported use

This repository is intended for authorized defensive security operations, demonstrations, learning, and reusable Microsoft security operations patterns.

Do not use this content for unauthorized access, offensive activity, evasion, persistence, credential theft, malware deployment, or activity that could harm systems or people.

## Reporting a security issue

If you find a security issue in this repository, such as an exposed secret, unsafe default, risky automation behavior, or tenant-specific data, open an issue or contact the repository owner privately if the issue should not be disclosed publicly.

When reporting, include:

- The affected file path.
- A short description of the issue.
- The potential impact.
- Suggested remediation, if available.

## Secrets and tenant data

Do not commit:

- Client secrets, certificates, private keys, tokens, or passwords.
- Tenant IDs, subscription IDs, workspace IDs, or resource IDs from production environments unless intentionally sanitized.
- Machine IDs, user identifiers, IP addresses, incident exports, alert evidence, or customer data.
- CSV files or outputs generated from production security tools.

Use environment variables, managed identity, workload identity, local secure stores, or tenant-approved secret management instead of storing credentials in repository files.

## Production use

All queries, scripts, templates, and agents should be reviewed and tested before production use. Response actions such as endpoint isolation, tagging, incident closure, or automated email notifications should require appropriate authorization and validation.

