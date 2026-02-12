#
#
# Kus-to-go Http library
#
#
# Written by:
# - James Immer
# - Func documentation by Copilot
#
#

#
#
class ClusterConnection {
    [hashtable]$headers
    # Name of kusto cluster
    [string]$clusterUrl
    # Name of kusto cluster's DB
    [string]$database
    # Name of kusto DB's Table
    [string]$table
    # Accumulator for failures
    [int]$failCount
    # Backoff accumulator
    [int]$backoffCount

    #
    #
    ClusterConnection([string]$clusterUrl, [String]$token) {
        $this.clusterUrl = $clusterUrl
        $this.database = $null
        $this.table = $null
        $this.failCount = 0
        $this.backoffCount = 0
        $this.headers = @{
            "Authorization" = "Bearer $token"
            "Content-type"  = "application/json"
            "User-Agent"    = "Kus-to-go/v0.1.0"
        }
    }
}

<#
.SYNOPSIS
    Creates a new ClusterConnection instance.

.DESCRIPTION
    New-ClusterConnection is a convenience wrapper around the ClusterConnection
    class constructor. It accepts a cluster URL and an AccessToken object, then
    constructs a strongly typed ClusterConnection using the token's raw value.

.PARAMETER ClusterUrl
    The URL of the Kusto/ADE cluster to connect to.

.PARAMETER Token
    An AccessToken instance whose Token property will be used for authentication.

.OUTPUTS
    [ClusterConnection]

.EXAMPLE
    $token = New-AccessToken -TenantId $tid
    $conn  = New-ClusterConnection -ClusterUrl "https://mycluster.kusto.windows.net" -Token $token

.EXAMPLE
    New-ClusterConnection `
        -ClusterUrl $cluster.Url `
        -Token (New-AccessToken -TenantId $tid)
#>
function New-ClusterConnection {
    param(
        [Parameter(Mandatory)]
        [string]$ClusterUrl,

        [Parameter(Mandatory)]
        [string]$Token
    )

    [ClusterConnection]::new($ClusterUrl, $Token)
}


