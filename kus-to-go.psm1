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
# Ad-hoc logging function
function Add-LogData {
    param (
        [string]$log_name,
        [string]$log_level,
        [string]$log_message
    )

    add-content -Path $log_name ($(Get-Date -Format 'MMM  dd HH:mm:ss') + ' ' + $log_level + ' '+ $log_message)
}


# 
# Backoff Handler Function
function Set-backoff {
    param (
        [int]$backoff_mod,
        [string]$error_log
    )

    $backoff_time = 60 * [math]::Pow(2, $backoff_mod)
    Add-LogData -log_name $error_log -log_level WARN -log_message ("Backing off for $backoff_time seconds...")
    Write-Host "Recieved 429 response! Backing off for $backoff_time seconds..."
    Start-Sleep -Seconds $backoff_time
    return $backoff_mod + 1
}