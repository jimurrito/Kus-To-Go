#
#
# Kus-to-go library
#

#
# Get access token
function get-accessToken {
    param (
        [string]$tenantId
    )
    $null = az login --allow-no-subscriptions -t $tenantId
    $(az account get-access-token --resource "https://api.kusto.windows.net" --query "accessToken") -replace '"'
}

#
# 



# 
# 
