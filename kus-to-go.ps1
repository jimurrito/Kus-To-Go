#
# Metadata scrapper for Kusto
#
param(
    [Parameter(Mandatory = $true)]
    [string]$tenantId
)


# Check if required output folders exist, create if not
if (-not(Test-Path Logs/ -PathType Container)) {
    New-Item -path Logs/ -ItemType Directory
}
if (-not(Test-Path output_raw/ -PathType Container)) {
    New-Item -path output_raw/ -ItemType Directory
}

$error_log="Logs/" + $(Get-Date -Format "yyMd.HH.mm") + ".log"

Add-LogData -log_name $error_log -log_level INFO -log_message "Initializing Script"
import-module ./kus-to-go.psm1

#
# get connections .xml data
Add-LogData -log_name $error_log -log_level INFO -log_message "Importing connections.xml"
[xml]$connections = Get-Content .\kusto_connections.xml
$svrs = $connections.ArrayOfServerDescriptionBase.ServerDescriptionBase | select-object Name, Details

#
# Work on each endpoint
foreach ($srvr in $svrs) {
    # Check last completion time for this server, skip if recent AND "connected" on previous run
    if (Test-Path -Path ".\output_raw\$($srvr.Name).json") {
        $existingJson = get-content ".\output_raw\$($srvr.Name).json" -Raw | ConvertFrom-Json
        $completedDate = [DateTime]::Parse($existingJson.DateCompleted)
        $timeDiff = (Get-Date) - $completedDate
        if ($timeDiff.TotalHours -lt 240 -and $existingJson.Metadata.Connected) {
            Add-LogData -log_name $error_log -log_level INFO -log_message ("Skipping '$($srvr.Name)' as it was completed recently on $($existingJson.DateCompleted).")
            Write-Host "Skipping '$($srvr.Name)' as it was completed recently on $($existingJson.DateCompleted)."
            continue
        }
    }
    # Script metadata
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $request_acc = 0
    $backoff_mod = 0
    #
    #
    Add-LogData -log_name $error_log -log_level INFO -log_message "Acquiring Token"
    $token = get-accessToken -tenantId $tenantId #Silly jmurrito forgot to add the variable they created!
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
    Add-LogData -log_name $error_log -log_level INFO -log_message ("Scraping Cluster '$srvr_name' => '$get_db_uri'.")
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
        Add-LogData -log_name $error_log -log_level INFO -log_message ("Cluster '$srvr_name' has ($db_count) database(s).")
        #Write-Host "Cluster '$srvr_name' has ($db_count) database(s)."
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
                Add-LogData -log_name $error_log -log_level INFO -log_message ("Scraping Tables '$srvr_name' | '$db_name' => '$get_tb_uri'.")
                #Write-host "Scraping Tables '$srvr_name' | '$db_name' => '$get_tb_uri'."
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
                    Add-LogData -log_name $error_log -log_level INFO -log_message ("Database '$db_name' has ($tb_count) tables(s).")
                    #Write-Host "Database '$db_name' has ($tb_count) tables(s)."
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
                            Add-LogData -log_name $error_log -log_level INFO -log_message ("Scraping Table Columns '$srvr_name' | '$db_name($tb_name)' => '$get_tb_col_uri'.")
                            #Write-host "Scraping Table Columns '$srvr_name' | '$db_name($tb_name)' => '$get_tb_col_uri'."
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
                                Add-LogData -log_name $error_log -log_level INFO -log_message ("Table '$tb_name' has ($tb_count) columns.")
                                #Write-Host "Table '$tb_name' has ($tb_count) columns."
                                #
                                # Write to tabl map
                                $table.Columns = $table_cols
                            }
                            #
                            # Failed to get Columns for tables
                            catch {
                                Write-Host "'$srvr_name' failed to connect via RestAPI. Error: [$_]"
                                Add-LogData -log_name $error_log -log_level ERROR -log_message ("'$srvr_name' failed to connect via RestAPI. Error: [$_]")
                                # 429 backoff
                                if ($_ -match "429") {
                                    $backoff_mod = set-backoff -backoff_mod $backoff_mod -error_log $error_log
                                }
                                elseif ($_ -match "401") {
                                    Add-LogData -log_name $error_log -log_level INFO -log_message ("Refreshing Token.")
                                    Write-host "Access Token has expired or you are not on VPN!"
                                    $token = get-accessToken -tenantId $tenantId #in. Every. Incarnation.
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
                    Add-LogData -log_name $error_log -log_level ERROR -log_message ("'$srvr_name' failed to connect via RestAPI. Error: [$_]")
                    Write-Host "'$srvr_name' failed to connect via RestAPI. Error: [$_]"
                    # 429 backoff
                    if ($_ -match "429") {
                        $backoff_mod = set-backoff -backoff_mod $backoff_mod -error_log $error_log
                    }
                    elseif ($_ -match "401") {
                        Add-LogData -log_name $error_log -log_level INFO -log_message ("Refreshing Token.")
                        Write-host "Access Token has expired or you are not on VPN!"
                        $token = get-accessToken -tenantId $tenantId
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
        Add-LogData -log_name $error_log -log_level ERROR -log_message ("'$srvr_name' failed to connect via RestAPI. Error: [$_]")
        Write-Host "'$srvr_name' failed to connect via RestAPI. Error: [$_]"
        # 429 backoff
        if ($_ -match "429") {
            $backoff_mod = set-backoff -backoff_mod $backoff_mod -error_log $error_log
        }
        elseif ($_ -match "401") {
            Add-LogData -log_name $error_log -log_level INFO -log_message ("Refreshing Token.")
            Write-host "Access Token has expired or you are not on VPN!"
            $token = get-accessToken -tenantId $tenantId
        }
    }
    #
    # Output from cluster run
    $stopwatch.Stop()
    $output = @{
        "DateCompleted"    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        "DurationSeconds" = $stopwatch.Elapsed.TotalSeconds
        "APIRequestCount" = $request_acc
        "Metadata"        = $cluster
    }
    Add-LogData -log_name $error_log -log_level INFO -log_message ("Run complete after " + $stopwatch.Elapsed.TotalSeconds + 's')
    write-host "Scrape complete after " + $stopwatch.Elapsed.TotalSeconds + 's'
    #
    Set-Content -Value ($output | ConvertTo-Json -dept 10) -Path ".\output_raw\$srvr_name.json"
    #
}
