#
#
# Kus-to-go Auth library
#
# Written by:
# - James Immer
# - Func documentation by Copilot
#
#

#
#
#
<#
.SYNOPSIS
    Represents an authentication token and its expiration timestamp.

.DESCRIPTION
    AccessToken stores a token string, the tenant ID it was issued for, and
    an expiry timestamp. The constructor automatically retrieves a fresh token
    using Get-AccessToken and computes the expiry time based on the provided
    number of minutes.

    The class also provides IsExpired() and Refresh() methods for token
    lifecycle management.

.NOTES
    Author: James
    Purpose: Strongly typed token container for authentication workflows.
#>
class AccessToken {

    [string]$TenantId
    [string]$Token
    [datetime]$Expiry

    <#
    .SYNOPSIS
        Creates a new AccessToken instance.

    .DESCRIPTION
        Retrieves a fresh access token for the specified tenant and computes
        an expiry timestamp based on the provided number of minutes.

    .PARAMETER TenantId
        The Azure AD tenant ID used to request the token.

    .PARAMETER expiry_mins
        Number of minutes the token should be considered valid.

    .EXAMPLE
        $t = [AccessToken]::new("00000000-0000-0000-0000-000000000000", 30)
    #>
    AccessToken([string]$TenantId, [int]$expiry_mins) {
        $this.TenantId = $TenantId
        $this.Token = Get-AADKustoAccessToken -TenantId $TenantId
        $this.Expiry = (Get-Date).AddMinutes($expiry_mins)
    }

    <#
    .SYNOPSIS
        Determines whether the token has expired.

    .DESCRIPTION
        Returns $true if the current system time is later than the token's
        expiry timestamp.

    .OUTPUTS
        [bool]
    #>
    [bool] IsExpired() {
        return (Get-Date) -gt $this.Expiry
    }

    <#
    .SYNOPSIS
        Refreshes the token and updates the expiry timestamp.

    .DESCRIPTION
        Retrieves a new token using the stored TenantId and recomputes the
        expiry timestamp based on the provided number of minutes.

    .PARAMETER expiry_mins
        Number of minutes the refreshed token should be valid for.
    #>
    [void] Refresh() {
        $this.Token = Get-AADKustoAccessToken -TenantId $this.TenantId
        $this.Expiry = (Get-Date).AddMinutes(60) # hard coded for now. I do not think changing is needed.... for now...
    }
}

#
#
#
<#
.SYNOPSIS
    Creates a new AccessToken instance for the specified tenant.

.DESCRIPTION
    New-AccessToken is a convenience wrapper around the AccessToken class
    constructor. It retrieves a fresh access token for the provided TenantId
    and returns a strongly typed AccessToken object containing the token
    string and its computed expiry timestamp.

.PARAMETER TenantId
    The Azure Active Directory tenant ID used to request the token.

.OUTPUTS
    [AccessToken]

.EXAMPLE
    $token = New-AccessToken -TenantId "00000000-0000-0000-0000-000000000000"

.EXAMPLE
    if ((New-AccessToken -TenantId $tid).IsExpired()) {
        Write-Host "Token expired"
    }
#>
function New-AccessToken {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId
    )

    [AccessToken]::new($TenantId, 60)
}



#
#
#
function Get-AADKustoAccessToken {
    <#
    .SYNOPSIS
        Retrieves an Azure access token for the Kusto (Azure Data Explorer) resource.
        DO NOT USE. Use 'New-AccessToken' instead.

    .DESCRIPTION
        Authenticates to Azure using the provided tenant ID and retrieves an
        access token scoped to the Kusto resource endpoint
        (https://api.kusto.windows.net). The function returns only the raw
        token string.

    .PARAMETER TenantId
        The Azure Active Directory tenant ID used when authenticating with Azure CLI.

    .EXAMPLE
        $token = Get-AccessToken -TenantId "00000000-0000-0000-0000-000000000000"

    .EXAMPLE
        Invoke-WebRequest -Uri "https://api.kusto.windows.net" `
            -Headers @{ Authorization = "Bearer $(Get-AccessToken -TenantId $tid)" }

    .NOTES
        Requires Azure CLI (az) to be installed and authenticated.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$TenantId
    )

    $null = az login --allow-no-subscriptions -t $TenantId

    (az account get-access-token `
        --resource "https://api.kusto.windows.net" `
        --query "accessToken") -replace '"'
}


#
#
