# Sentinel MCP Governance Queries

This folder contains portable KQL queries for governing Microsoft Sentinel MCP server activity. The queries help security teams answer:

- Which Sentinel MCP endpoint was used?
- Which Log Analytics or Sentinel table was reached by the MCP-initiated query?
- Did the query succeed or fail?
- Which user, application, or service principal initiated the activity?
- How many rows were returned, how long did the query take, and how much data was scanned?

## Files

| File | Purpose |
| --- | --- |
| `mcp-table-access-detail.kql` | Event-level view of MCP endpoint usage, table reached, caller, status, response code, and raw query text. |
| `mcp-table-access-summary.kql` | Governance summary by MCP endpoint, target workspace, and table reached. |

## Data source

The queries use `LAQueryLogs`, which is the Log Analytics query audit table. `LAQueryLogs` is required because MCP table access is runtime telemetry, not Azure resource configuration.

Azure Resource Graph can help inventory workspaces, diagnostic settings, Sentinel resources, and RBAC posture, but it cannot show which tables an MCP endpoint queried. Table-level query activity must come from `LAQueryLogs`.

## Where to run the queries

Run the queries in the workspace where `LAQueryLogs` is stored.

In many environments, workspace audit logs are routed to a central Log Analytics workspace instead of the Sentinel workspace being queried. In that design:

1. Open the central audit workspace.
2. Run one of the queries from this folder.
3. Set `TargetWorkspace` to the resource ID of the Sentinel workspace you want to govern.

If `LAQueryLogs` is stored in the same workspace as Sentinel, you can leave `TargetWorkspace` as an empty string to include all audited query targets visible in that workspace.

```kql
let TargetWorkspace = "";
```

For a centralized audit workspace, set it like this:

```kql
let TargetWorkspace = "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.OperationalInsights/workspaces/<sentinel-workspace-name>";
```

## Why the queries track MCP URL paths

The queries track MCP activity by URL path instead of local MCP server name.

MCP server names are client-side labels and can vary across users, tools, and environments. URL paths are more portable governance indicators. The included Sentinel MCP endpoints are:

| MCP endpoint | URL path |
| --- | --- |
| Sentinel MCP - Agent Creation | `/mcp/security-copilot-agent-creation` |
| Sentinel MCP - Data Exploration | `/mcp/data-exploration` |
| Sentinel MCP - Triage | `/mcp/triage` |

If Microsoft adds more Sentinel MCP endpoints, add them to the `McpEndpoints` datatable:

```kql
let McpEndpoints = datatable(McpEndpoint:string, McpUrlPath:string)
[
    "Sentinel MCP - Agent Creation", "/mcp/security-copilot-agent-creation",
    "Sentinel MCP - Data Exploration", "/mcp/data-exploration",
    "Sentinel MCP - Triage", "/mcp/triage"
];
```

## Table discovery approach

The queries avoid hardcoded Sentinel table lists. They build a dynamic table inventory from the `Usage` table:

```kql
Usage
| where TimeGenerated >= ago(TableInventoryLookback)
| where isnotempty(DataType)
| summarize by TableReached = tostring(DataType)
```

This makes the query more portable and allows it to detect custom tables, such as tables ending in `_CL`, when those tables have had recent ingestion.

The queries also include an `AdditionalTables` datatable for audit and Sentinel operational tables that may not appear in recent `Usage` results:

```kql
let AdditionalTables = datatable(TableReached:string)
[
    "LAQueryLogs",
    "SentinelAudit",
    "SentinelHealth"
];
```

Add organization-specific custom tables to `AdditionalTables` if:

- Audit logs are centralized in a different workspace than the queried Sentinel workspace.
- The custom table has not had recent ingestion.
- The table is referenced in queries but does not appear in `Usage` during `TableInventoryLookback`.

## Important limitations

These queries identify tables directly referenced in `LAQueryLogs.QueryText`. This is appropriate for governance reporting, but there are a few limitations:

- If a query calls a function, saved query, or parser, the underlying tables used inside that function may not be visible in the submitted query text.
- If an MCP client does not stamp the Sentinel MCP URL path into `QueryText`, `RequestContext`, `RequestClientApp`, or `RequestTarget`, the query may need to filter by `AADClientId`, `RequestClientApp`, or service principal identity instead.
- If `LAQueryLogs` is not enabled or is routed to another workspace, the Sentinel workspace itself may show zero rows.
- `Usage` only discovers tables with ingestion during `TableInventoryLookback`; add older or low-volume custom tables to `AdditionalTables`.

## Prerequisites

1. Enable diagnostic settings for the Sentinel or Log Analytics workspace.
2. Ensure the `Audit` category or `audit` category group is enabled.
3. Route the diagnostic logs to a Log Analytics workspace.
4. Run Sentinel MCP activity after enabling audit logging. `LAQueryLogs` does not backfill historical activity.

You can check whether query audit data exists with:

```kql
LAQueryLogs
| where TimeGenerated >= ago(30d)
| summarize
    TotalRows = count(),
    FirstSeen = min(TimeGenerated),
    LastSeen = max(TimeGenerated),
    ClientApps = make_set(RequestClientApp, 20),
    Targets = make_set(RequestTarget, 20)
```

## Troubleshooting

### `LAQueryLogs` returns no rows

Check the workspace diagnostic settings. The most common causes are:

- Audit diagnostics are not enabled.
- Audit diagnostics are routed to a different Log Analytics workspace.
- No queries were run after audit diagnostics were enabled.

### MCP activity does not appear

First check whether MCP markers are present in the audit logs:

```kql
LAQueryLogs
| where TimeGenerated >= ago(30d)
| extend Raw = strcat(
    tolower(tostring(QueryText)),
    " ",
    tolower(tostring(RequestContext)),
    " ",
    tolower(tostring(RequestClientApp)),
    " ",
    tolower(tostring(RequestTarget))
)
| summarize
    TotalRows = count(),
    McpMarkerRows = countif(Raw has_any (
        "security-copilot-agent-creation",
        "data-exploration",
        "triage",
        "sentinel.microsoft.com/mcp"
    )),
    ClientApps = make_set(RequestClientApp, 20),
    AADClientIds = make_set(AADClientId, 20),
    Callers = make_set(coalesce(AADEmail, AADObjectId, AADClientId), 20)
```

If `McpMarkerRows` is zero but MCP activity is known to have occurred, identify the client identity and adapt the filter:

```kql
LAQueryLogs
| where TimeGenerated >= ago(30d)
| summarize
    QueryCount = count(),
    FirstSeen = min(TimeGenerated),
    LastSeen = max(TimeGenerated),
    SampleQueries = make_set(substring(tostring(QueryText), 0, 300), 5)
    by
    AADEmail,
    AADObjectId,
    AADClientId,
    RequestClientApp,
    RequestTarget
| order by QueryCount desc
```

### KQL join or regex errors

The queries intentionally avoid these unsupported patterns:

```kql
join ... on $left.Raw contains $right.McpUrlPath
```

and:

```kql
matches regex strcat("...", TableReached, "...")
```

KQL joins require equality expressions in `on`, and `matches regex` requires a scalar constant pattern. These queries use equality joins with a small `JoinKey` and then apply `contains` or `has` in a normal `where` clause.

## Recommended governance workflow

1. Run `mcp-table-access-detail.kql` to inspect raw MCP activity and verify endpoint detection.
2. Run `mcp-table-access-summary.kql` for recurring governance reporting.
3. Review `FailedQueries` and `UnknownStatusQueries`.
4. Review sensitive table usage, high row counts, high scanned GB, and unexpected callers.
5. Convert the summary query into a scheduled analytics rule or workbook visualization as needed.

## Security note

Treat the output as security audit data. It may include user identities, application IDs, queried table names, and raw query text.
