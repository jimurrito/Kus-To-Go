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
# Class to ensure token map is not anon
class AccessToken {
    [string]$Token
    [datetime]$Expiry
    # ::new bindings
    AccessToken([string]$token, [datetime]$expiry) {
        $this.Token = $token
        $this.Expiry = $expiry
    }
    # Method to check if token is valid
    [bool] IsExpired() { return (Get-Date) -gt $this.Expiry }
}


#
#
#
function Get-AccessToken {
    <#
    .SYNOPSIS
    Retrieves an Azure access token for the Kusto (Azure Data Explorer) resource and returns it with an expiry timestamp.

    .DESCRIPTION
    Get-AccessToken authenticates to Azure using the provided tenant ID and retrieves an access token scoped to the
    Kusto resource endpoint (https://api.kusto.windows.net). Instead of returning only the raw token string, the
    function now returns a hashtable containing both the token and a calculated expiry time based on the
    -expiry_mins parameter.

    .PARAMETER TenantId
    The Azure Active Directory tenant ID used when authenticating with Azure CLI.

    .PARAMETER expiry_mins
    The number of minutes the returned token should be considered valid. Defaults to 60 minutes.
    This value is used to compute the expiry timestamp included in the output.

    .EXAMPLE
    Get-AccessToken -TenantId "00000000-0000-0000-0000-000000000000"

    Authenticates to Azure using the specified tenant and returns a hashtable containing:
        token  – the raw access token string
        expiry – a DateTime value representing when the token should be treated as expired

    .EXAMPLE
    $auth = Get-AccessToken -TenantId "<tenant-guid>"
    Invoke-WebRequest -Uri "https://api.kusto.windows.net" -Headers @{ Authorization = "Bearer $($auth.token)" }

    Retrieves a token and uses the token value in an authenticated request. The caller may also inspect
    $auth.expiry to determine whether the token should be refreshed.

    .NOTES
    Requires Azure CLI (az) to be installed and authenticated. The function performs an `az login` for the
    specified tenant before requesting the access token.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$TenantId,
        [int]$expiry_mins = 60
    )

    # Authenticate to Azure for the given tenant
    $null = az login --allow-no-subscriptions -t $TenantId

    # Retrieve and clean the access token
    $token = (az account get-access-token `
            --resource "https://api.kusto.windows.net" `
            --query "accessToken") -replace '"'

    # Return map that contains token + expiry
    [AccessToken]::new($token, (Get-Date).AddMinutes($expiry_mins))
}

#
#
