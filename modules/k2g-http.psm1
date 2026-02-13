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

    # Bindings for ::new()
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

    #
    # Refreshes the cached token
    [void] RefreshToken([string]$Token) {
        $this.headers = @{
            "Authorization" = "Bearer $token"
            "Content-type"  = "application/json"
            "User-Agent"    = "Kus-to-go/v0.1.0"
        }
    }

    #
    # Generic Rest call + parse core data
    [hashtable] MakeRestRequest([string]$URI) {
        $resp = Invoke-KustoRestRequest -uri "$URI" -headers $this.headers
        if (($resp.code) -eq 200) {
            # Parses JSON response and outputs list of databases
            $resp.data = ($resp.data | ConvertFrom-Json).tables[0].rows | ForEach-Object { $_[0] }
            return $resp
        }
        else {
            return $resp
        }
    }

    #
    #
    #
    # Retrieves the Databases for the connected Cluster
    [hashtable] GetDatabases() {
        return $this.MakeRestRequest("$($this.clusterUrl)/v1/rest/mgmt?csl=.show%20databases")
    }

    #
    #
    #
    # Retrieve Tables for a given database within the connected cluster
    [hashtable] GetTables([string]$DatabaseName) {
        return $this.MakeRestRequest("$($this.clusterUrl)/v1/rest/mgmt?csl=.show%20tables&db=$DatabaseName")
    }
    # Retrieve Tables for a given database within the connected cluster
    [hashtable] GetTables() {
        return $this.GetTables($this.database)
    }

    #
    #
    #
    #
    # Retrieve Tables for a given database within the connected cluster
    [hashtable] GetColumns([string]$DatabaseName, [string]$TableName) {
        return $this.MakeRestRequest("$($this.clusterUrl)/v1/rest/mgmt?csl=.show%20table%20$TableName%20&db=$DatabaseName")
    }
    # Same as GetColumns/2 but does not require the database name
    [hashtable] GetColumns([string]$TableName) {
        return $this.GetColumns($this.database, $TableName)
    }
    # Same as GetColumns/2 but does not require the database name or table name
    [hashtable] GetColumns() {
        return $this.GetColumns($this.database, $this.table)
    }


    #
    #
}

#
#
#
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

#
#
# Wrapper to handle catching HTTP errors
function Invoke-KustoRestRequest {
    param (
        [parameter(Mandatory)]
        [string]$uri,

        [parameter(Mandatory)]
        [hashtable]$headers
    )
    #
    try {
        $resp = Invoke-WebRequest -Method GET -Headers $headers -Uri $uri
        @{
            code = 200 
            data = $resp
        }
    }
    catch {
        # Return http failure code + content
        @{
            code = $_.Exception.Response
            data = $resp
        }
    }
    #
}



