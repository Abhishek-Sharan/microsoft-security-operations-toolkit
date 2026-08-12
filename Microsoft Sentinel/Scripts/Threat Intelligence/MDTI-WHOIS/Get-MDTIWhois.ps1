[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecretEnvironmentVariable = "MDTI_CLIENT_SECRET",

    [Parameter(Mandatory = $false)]
    [string]$InputTxt = ".\domains.txt",

    [Parameter(Mandatory = $false)]
    [string]$OutputCsv = ".\mdti_whois_results.csv",

    [Parameter(Mandatory = $false)]
    [string]$OutputJson = ".\mdti_whois_raw.json",

    [Parameter(Mandatory = $false)]
    [int]$MaxRetries = 3,

    [Parameter(Mandatory = $false)]
    [int]$DelayMilliseconds = 200
)

$ErrorActionPreference = "Stop"

function Get-PlainTextFromSecureString {
    param(
        [Parameter(Mandatory = $true)]
        [securestring]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-GraphAccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )

    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $body = @{
        client_id     = $ClientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $tokenUrl `
        -Body $body `
        -ContentType "application/x-www-form-urlencoded"

    return $response.access_token
}

function Get-NestedValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $current = $Object

    foreach ($part in $Path.Split(".")) {
        if ($null -eq $current) {
            return $null
        }

        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            return $null
        }
    }

    return $current
}

function Get-ErrorDetails {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $statusCode = $null
    if ($ErrorRecord.Exception.Response) {
        $statusCode = [int]$ErrorRecord.Exception.Response.StatusCode
    }

    $message = if ($ErrorRecord.ErrorDetails.Message) {
        $ErrorRecord.ErrorDetails.Message
    }
    else {
        $ErrorRecord.Exception.Message
    }

    return @{
        StatusCode = $statusCode
        Message    = $message
    }
}

function Invoke-MDTIWhoisLookup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $true)]
        [int]$MaxRetries
    )

    $normalizedDomain = $Domain.Trim().ToLowerInvariant()
    $encodedDomain = [System.Uri]::EscapeDataString($normalizedDomain)
    $uri = "https://graph.microsoft.com/v1.0/security/threatIntelligence/hosts/$encodedDomain/whois"

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $whois = Invoke-RestMethod `
                -Method Get `
                -Uri $uri `
                -Headers $Headers `
                -TimeoutSec 60

            return @{
                Whois = $whois
                Error = $null
            }
        }
        catch {
            $errorDetails = Get-ErrorDetails -ErrorRecord $_

            if ($errorDetails.StatusCode -in @(429, 500, 502, 503, 504) -and $attempt -lt $MaxRetries) {
                $sleepSeconds = 5 * $attempt
                Write-Warning "Lookup for $normalizedDomain failed with HTTP $($errorDetails.StatusCode). Retrying in $sleepSeconds seconds."
                Start-Sleep -Seconds $sleepSeconds
                continue
            }

            return @{
                Whois = $null
                Error = $errorDetails
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $InputTxt)) {
    throw "Input TXT file not found: $InputTxt"
}

if (-not $ClientSecret) {
    $ClientSecret = [Environment]::GetEnvironmentVariable($ClientSecretEnvironmentVariable)
}

if (-not $ClientSecret) {
    $secureSecret = Read-Host "Enter client secret" -AsSecureString
    $ClientSecret = Get-PlainTextFromSecureString -SecureString $secureSecret
}

$domains = Get-Content -LiteralPath $InputTxt |
    ForEach-Object { $_.Trim().ToLowerInvariant() } |
    Where-Object { $_ -and -not $_.StartsWith("#") } |
    Select-Object -Unique

if (-not $domains -or $domains.Count -eq 0) {
    throw "No domains found in input file: $InputTxt"
}

$accessToken = Get-GraphAccessToken `
    -TenantId $TenantId `
    -ClientId $ClientId `
    -ClientSecret $ClientSecret

$headers = @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json"
}

$results = @()
$rawResults = [ordered]@{}

foreach ($domain in $domains) {
    Write-Host "Fetching WHOIS for $domain..."

    $lookup = Invoke-MDTIWhoisLookup `
        -Domain $domain `
        -Headers $headers `
        -MaxRetries $MaxRetries

    $rawResults[$domain] = $lookup

    if ($lookup.Error) {
        $results += [PSCustomObject]@{
            Domain                 = $domain
            Status                 = "Failed"
            Error                  = ($lookup.Error | ConvertTo-Json -Compress)
            WhoisId                = $null
            Registrar              = $null
            RegistrantOrganization = $null
            RegistrantEmail        = $null
            AdminEmail             = $null
            TechnicalEmail         = $null
            AbuseEmail             = $null
            RegistrationDateTime   = $null
            ExpirationDateTime     = $null
            LastUpdateDateTime     = $null
            WhoisServer            = $null
            DomainStatus           = $null
            Nameservers            = $null
        }

        continue
    }

    $whois = $lookup.Whois

    $nameservers = @()
    if ($whois.nameservers) {
        foreach ($ns in $whois.nameservers) {
            if ($ns.host.id) {
                $nameservers += $ns.host.id
            }
        }
    }

    $results += [PSCustomObject]@{
        Domain                 = $domain
        Status                 = "Success"
        Error                  = $null
        WhoisId                = $whois.id
        Registrar              = (Get-NestedValue -Object $whois -Path "registrar.organization")
        RegistrantOrganization = (Get-NestedValue -Object $whois -Path "registrant.organization")
        RegistrantEmail        = (Get-NestedValue -Object $whois -Path "registrant.email")
        AdminEmail             = (Get-NestedValue -Object $whois -Path "admin.email")
        TechnicalEmail         = (Get-NestedValue -Object $whois -Path "technical.email")
        AbuseEmail             = (Get-NestedValue -Object $whois -Path "abuse.email")
        RegistrationDateTime   = $whois.registrationDateTime
        ExpirationDateTime     = $whois.expirationDateTime
        LastUpdateDateTime     = $whois.lastUpdateDateTime
        WhoisServer            = $whois.whoisServer
        DomainStatus           = $whois.domainStatus
        Nameservers            = ($nameservers -join ";")
    }

    if ($DelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
}

$results | Export-Csv `
    -Path $OutputCsv `
    -NoTypeInformation `
    -Encoding UTF8

$rawResults | ConvertTo-Json -Depth 25 |
    Out-File `
        -FilePath $OutputJson `
        -Encoding UTF8

Write-Host "Completed."
Write-Host "CSV output: $OutputCsv"
Write-Host "Raw JSON output: $OutputJson"
