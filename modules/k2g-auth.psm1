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
# AAD/Kusto Access token tracking class
class AccessToken {

    [string]$TenantId
    [string]$Token
    [datetime]$Expiry

    # Bindings for ::new
    AccessToken([string]$TenantId, [int]$expiry_mins) {
        $this.TenantId = $TenantId
        $this.Token = Get-AADKustoAccessToken -TenantId $TenantId
        $this.Expiry = (Get-Date).AddMinutes($expiry_mins)
    }

    # Should be self-explaintory
    [bool] IsExpired() {
        return (Get-Date) -gt $this.Expiry
    }

    # Refreshes the access token by prompting the user again
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
