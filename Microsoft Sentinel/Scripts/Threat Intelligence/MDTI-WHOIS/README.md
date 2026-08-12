# MDTI WHOIS lookup for domain lists

This sample retrieves WHOIS information for a list of domains by using the Microsoft Defender Threat Intelligence APIs in Microsoft Graph.

The script is read-only. It reads domains from a text file, calls Microsoft Graph, and writes normalized CSV plus raw JSON output. It does not modify Microsoft Sentinel, Microsoft Defender, tenant settings, or domain records.

## Disclaimer

This project is provided for educational and demonstration purposes only.

The software, workflows, prompts, scripts, and examples included in this repository are provided "as is", without warranties or guarantees of any kind, express or implied. The authors and contributors make no representations regarding reliability, safety, suitability, security, legality, or fitness for any particular purpose.

By using this project, you acknowledge and agree that:

- You are solely responsible for how you use, modify, deploy, or distribute the software.
- You must thoroughly test the project in a controlled and secure environment before using it in production or with sensitive systems or data.
- AI agents and automated systems may produce unexpected, inaccurate, incomplete, or harmful outputs and actions.
- This project may contain experimental features, unsafe behaviors, or incomplete safeguards.
- The authors are not responsible for any damage, losses, security incidents, operational failures, legal issues, compliance violations, data loss, financial losses, or other consequences resulting from the use of this project.
- Users are responsible for ensuring compliance with all applicable laws, regulations, platform policies, licensing requirements, and organizational security practices.

This repository is not intended for use in safety-critical, regulated, or production environments without independent review, validation, monitoring, and appropriate safeguards.

## API used

```http
GET https://graph.microsoft.com/v1.0/security/threatIntelligence/hosts/{domain}/whois
```

References:

- [Get WHOIS record using Microsoft Graph MDTI](https://learn.microsoft.com/graph/api/security-whoisrecord-get?view=graph-rest-1.0)
- [WHOIS record resource schema](https://learn.microsoft.com/graph/api/resources/security-whoisrecord?view=graph-rest-1.0)
- [Microsoft Threat Intelligence APIs overview](https://learn.microsoft.com/graph/api/resources/security-threatintelligence-overview?view=graph-rest-1.0)

## Requirements

Create an Entra ID app registration with the following Microsoft Graph application permission:

```text
ThreatIntelligence.Read.All
```

Grant admin consent for the permission. The tenant must also have access to Microsoft Defender Threat Intelligence APIs.

## Input file

Create a text file with one domain per line. Lines starting with `#` are ignored.

Example `domains.txt`:

```text
# Domains to enrich
contoso.com
example.com
microsoft.com
```

## Recommended secret handling

Avoid placing client secrets in scripts or committing secrets to source control.

Set the client secret in an environment variable:

```powershell
$env:MDTI_CLIENT_SECRET = "<client-secret>"
```

Then run the script without passing `-ClientSecret`.

## Usage

```powershell
.\Get-MDTIWhois.ps1 -TenantId "<tenant-id>" -ClientId "<client-id>" -InputTxt ".\domains.txt" -OutputCsv ".\mdti_whois_results.csv" -OutputJson ".\mdti_whois_raw.json"
```

You can also pass a custom environment variable name:

```powershell
.\Get-MDTIWhois.ps1 -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecretEnvironmentVariable "MY_GRAPH_SECRET" -InputTxt ".\domains.txt"
```

If no secret is passed and the environment variable isn't set, the script prompts for the secret securely.

## Outputs

The script creates:

- `mdti_whois_results.csv` - normalized output for analyst review.
- `mdti_whois_raw.json` - full raw API responses for deeper investigation or audit reference.

Normalized fields include:

- Domain
- Status
- Registrar
- Registrant organization
- Registrant email
- Admin email
- Technical email
- Abuse email
- Registration date
- Expiration date
- Last update date
- WHOIS server
- Domain status
- Nameservers

## Notes

- HTTP 404 can mean no current WHOIS record was found for the host in MDTI.
- HTTP 429 and transient 5xx responses are retried.
- WHOIS fields vary across registrars. Keep the raw JSON output for deeper review.
- Validate output handling requirements before storing or sharing enrichment results.
