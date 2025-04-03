#
# Metadata scrapper for Kusto
#

# token
# 
# IN CLOUDSHELL
# - az login
# - az account get-access-token --resource "https://api.kusto.windows.net" --query "accessToken"
#

#
# get connections .xml data
[xml]$connections = Get-Content .\kusto_connections.xml
$svrs = $connections.ArrayOfServerDescriptionBase.ServerDescriptionBase | select-object Name, Details

#
# Work on each endpoint
foreach ($srvr in $svrs) {
    # Script metadata
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $request_acc = 0
    $backoff_mod = 1
    #
    #
    $token = Get-Content .\access_token
    #
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-type"  = "application/json"
        "User-Agent"    = "Kus-to-go/v0.1.0"
    }
    #
    #
    $srvr_name = $srvr.Name
    $srvr_url = $srvr.Details
    #
    # clean url
    $srvr_url = if ($srvr_url -match "Data Source=") {
        # removes data source tag
        ($srvr_url.Replace("Data Source=", "") -split ":443" -split ";")[0]
    }
    else {
        $srvr_url
    }
    #
    #
    # blank cluster output
    $cluster = @{
        "Cluster"    = $srvr_name
        "ClusterURI" = $srvr_url
        "Connected"  = $false
        "Databases"  = @()
    }
    #
    #
    # Create URI
    $get_db_uri = "$srvr_url/v1/rest/mgmt?csl=.show%20databases"
    Write-host "Scraping Cluster '$srvr_name' => '$get_db_uri'."
    # Run REST API request
    try {
        $request_acc += 1
        $db_response = Invoke-WebRequest -Method GET -Headers $headers -Uri $get_db_uri
        # Set Cluster to connected
        $cluster.Connected = $true
        #
        # Parse rows
        $db_rows = ((($db_response).content | ConvertFrom-Json).tables[0]).rows
        #
        # DB name accumulator
        $db_names = @()
        # Get only DB names
        $db_rows | ForEach-Object {
            $db_names += $_[0]
        }
        # get count
        $db_count = $db_names.Count
        #
        Write-Host "Cluster '$srvr_name' has ($db_count) database(s)."
        #
        # only continue if count > 0
        if ($db_count -gt 0 ) {
            #
            # gets tables for the DBs
            foreach ($db_name in $db_names) {
                #
                # DB map
                $database = @{
                    "Database" = $db_name
                    "Tables"   = @()
                }
                #
                # make URI
                $get_tb_uri = "$srvr_url/v1/rest/mgmt?csl=.show%20tables&db=$db_name"
                #
                Write-host "Scraping Tables '$srvr_name' | '$db_name' => '$get_tb_uri'."
                #
                # Make request for DB Tables
                try {
                    #
                    $request_acc += 1
                    $tb_response = Invoke-WebRequest -Method GET -Headers $headers -Uri $get_tb_uri
                    # Parse rows
                    $tb_rows = ((($tb_response).content | ConvertFrom-Json).tables[0]).rows
                    #
                    # Table name output
                    $table_names = @()
                    # Get only table names
                    $tb_rows | ForEach-Object {
                        $table_names += $_[0]
                    }
                    # Table count
                    $tb_count = $table_names.Count
                    #
                    Write-Host "Database '$db_name' has ($tb_count) tables(s)."
                    #
                    #
                    # Continue only if there are tables within the DB
                    if ($tb_count -gt 0 ) {
                        # Get columnss for each table
                        foreach ($tb_name in $table_names) {
                            #
                            # Table Map
                            $table = @{
                                "Table"   = $tb_name
                                "Columns" = @()
                            }
                            #
                            # make URI
                            $get_tb_col_uri = "$srvr_url/v1/rest/mgmt?csl=.show%20table%20$tb_name%20&db=$db_name"
                            Write-host "Scraping Table Columns '$srvr_name' | '$db_name($tb_name)' => '$get_tb_col_uri'."
                            #
                            # Make request
                            try {
                                $request_acc += 1
                                $tb_col_response = Invoke-WebRequest -Method GET -Headers $headers -Uri $get_tb_col_uri
                                # Parse rows
                                $tb_col_rows = ((($tb_col_response).content | ConvertFrom-Json).tables[0]).rows
                                #
                                # Table Column name output
                                $table_cols = @()
                                # Get only table names
                                $tb_col_rows | ForEach-Object {
                                    $table_cols += $_[0]
                                }
                                #
                                # Table count
                                $tb_count = $table_cols.Count
                                #
                                Write-Host "Table '$tb_name' has ($tb_count) columns."
                                #
                                # Write to tabl map
                                $table.Columns = $table_cols
                            }
                            #
                            # Failed to get Columns for tables
                            catch {
                                Write-Host "'$srvr_name' failed to connect via RestAPI. Error: [$_]"
                                # 429 backoff
                                if ($_ -match "429") {
                                    Write-Host "Recieved 429 response! Backing off for (60 * $backoff_mod)s."
                                    Start-Sleep -Seconds 60 * $backoff_mod
                                }
                                elseif ($_ -match "401") {
                                    Read-Host "Access Token has expired or you are not on VPN! Fix the issue and press enter to continue"
                                }  
                            }
                            #
                            # Add Table to Database Map
                            $database.Tables += $table
                        }
                    }
                }
                # Failed to call Rest to get Tables
                catch {
                    Write-Host "'$srvr_name' failed to connect via RestAPI. Error: [$_]"
                    # 429 backoff
                    if ($_ -match "429") {
                        Write-Host "Recieved 429 response! Backing off for (60 * $backoff_mod)s."
                        Start-Sleep -Seconds 60 * $backoff_mod
                    }
                    elseif ($_ -match "401") {
                        Read-Host "Access Token has expired or you are not on VPN! Fix the issue and press enter to continue"
                    }  
                }
                #
                # Add Database info to cluster map
                $cluster.Databases += $database
            }
        }
        #
    }
    # Failed to call Cluster to get Databases
    catch {
        Write-Host "'$srvr_name' failed to connect via RestAPI. Error: [$_]"
        # 429 backoff
        if ($_ -match "429") {
            Write-Host "Recieved 429 response! Backing off for (60 * $backoff_mod)s."
            Start-Sleep -Seconds 60 * $backoff_mod
        }
        elseif ($_ -match "401") {
            Read-Host "Access Token has expired or you are not on VPN! Fix the issue and press enter to continue"
        }  
    }
    #
    # Output from cluster run
    $stopwatch.Stop()
    $output = @{
        "DurationSeconds" = $stopwatch.Elapsed.TotalSeconds
        "APIRequestCount" = $request_acc
        "Metadata"        = $cluster
    }
    #
    Set-Content -Value ($output | ConvertTo-Json -dept 10) -Path ".\out\$srvr_name.json"
    #
}
