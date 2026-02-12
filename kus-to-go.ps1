#
#
# Kus-to-go - Kusto Metadata Scrapper
#
# Written by:
# - James Immer
# - Creston Lockerd
# - Func documentation by Copilot
#
#
# High-Level Architecture
#
# - Acquires an Access token for Kusto.
# - Grabs clusters from the Kusto-exported 'connections.xml' file.
# - Iterates Clusters.
# - Uses Cluster name to call an API for the databases.
# - Iterates the Databases.
# - Uses Cluster name + Database name to get tables via API call.
# - Iterates tables.
# - Uses Cluster name, Database name, and table name to get column via API call.
# - All data is compiled to one excel sheet per-Cluster [$output/<cluster_name>.xlsx]
# - Data is stored in rows per-table
#   <Column structure>
#       Cluster | Database | Table | Column(s)
#
#

#
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
    [string]$LogLevel = "INFO",

    [string]$LogDir = "./logs/",

    [string]$Output = "./output/",
    
    [string]$ConnectionsXML = "./kusto_connections.xml",

    # Force will ignore if a file already exists, and rescan the cluster anyways.
    [switch]$Force
)

#
# Imports
# Uses "$PSScriptRoot" so the path is relative to the script and now the user working dir
import-module $PSScriptRoot/modules/k2g-common.psm1 -Force
import-module $PSScriptRoot/modules/k2g-auth.psm1 -Force
import-module $PSScriptRoot/modules/k2g-http.psm1 -Force
import-module $PSScriptRoot/modules/k2g-excel.psm1 -Force
import-module $PSScriptRoot/modules/k2g-parse.psm1 -Force

#
# Create required Dirs. Ignore if dir already exists
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
New-Item -Path $Output -ItemType Directory -Force | Out-Null
# Create log file and grab output absolute path
# have to use "yyyy-MM-ddTh_m_s" as ':' is not valid for windows file names
$OUTPUT_LOG = (New-Item -Path "$LogDir" -ItemType File -Name "$(Get-Date -Format "yyyy-MM-ddTh_m_s").log" -force).ResolvedTarget

#
# Changed write-log to use pipe to control logging based on env log level
$LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text "Initializing Script"

#
# get cluster connections from *.xml data
$LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text "Importing connections.xml"
$clusters = $ConnectionsXML | Initialize-ConnectionsXML | Get-KClusters
$LogLevel | Write-Log -file "$OUTPUT_LOG" -level DEBUG -text "[$($clusters.count)] Clusters found in [$ConnectionsXML]"

#
# Create excel handler
$LogLevel | Write-Log -file "$OUTPUT_LOG" -level DEBUG -text "Opening an Excel handler..."
$excel = Initialize-Excel

#
# Initial login
$LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text "Acquiring Token"
$token = New-AccessToken -TenantId $TenantId # Silly jmurrito forgot to add the variable they created!
$LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text "Token valid until [$($token.expiry)]"


#
# Iterates through every Cluster in the connections xml.
foreach ($cluster in $clusters) {
    #
    # check if cluster already has an excel file in the output dir
    $excel_output = "${output}/$($cluster.Name).xlsx"
    if ((Test-Path -path $excel_output) -and !$force) {
        # File already exists, and we are not forcing.
        # Skip this cluster.
        $LogLevel | Write-Log -file "$OUTPUT_LOG" -level WARN -text "Cluster [$($cluster.Name)] has already been scrapped to [$excel_output]. Skipping Cluster"
        # Advances the for-loop to the next instance
        continue
    }

    #
    # If you have made it this far, we will be scrapping the cluster metadata
    
    #
    # Create workbook + sheet via [ExcelWorkSpace] class
    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level DEBUG -text "Creating Excel workbook [$excel_output]..."
    $excel_workspace = $excel | New-ExcelWorkbook
    # Add header to excel sheet.
    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level DEBUG -text "Adding headers to Excel Workbook [$excel_output] sheet 1..."
    $excel_workspace.AddHeader(@("Cluster", "Cluster-URI", "Database", "Table", "Columns", "Details"))

    #
    # Create Connection class
    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level DEBUG -text "Creating Connection class for cluster [$($cluster.name)]..."
    $conn = New-ClusterConnection -ClusterUrl $cluster.url -Token $token.Token

    $conn
    
    exit    


    #
    #
    $cluster_name = $cluster.Name
    $cluster_url = $cluster.Details
    #
    # clean url
    $cluster_url = if ($cluster_url -match "Data Source=") {
        # removes data source tag
        ($cluster_url.Replace("Data Source=", "") -split ":443" -split ";")[0]
    }
    else {
        $cluster_url
    }
    #
    #
    # blank cluster output
    $cluster = @{
        "Cluster"    = $cluster_name
        "ClusterURI" = $cluster_url
        "Connected"  = $false
        "Databases"  = @()
    }
    #
    #
    # Create URI
    $get_db_uri = "$cluster_url/v1/rest/mgmt?csl=.show%20databases"
    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Scraping Cluster '$cluster_name' => '$get_db_uri'.")
    Write-host "Scraping Cluster '$cluster_name' => '$get_db_uri'."
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
        $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Cluster '$cluster_name' has ($db_count) database(s).")
        #Write-Host "Cluster '$cluster_name' has ($db_count) database(s)."
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
                $get_tb_uri = "$cluster_url/v1/rest/mgmt?csl=.show%20tables&db=$db_name"
                #
                $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Scraping Tables '$cluster_name' | '$db_name' => '$get_tb_uri'.")
                #Write-host "Scraping Tables '$cluster_name' | '$db_name' => '$get_tb_uri'."
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
                    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Database '$db_name' has ($tb_count) tables(s).")
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
                            $get_tb_col_uri = "$cluster_url/v1/rest/mgmt?csl=.show%20table%20$tb_name%20&db=$db_name"
                            $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Scraping Table Columns '$cluster_name' | '$db_name($tb_name)' => '$get_tb_col_uri'.")
                            #Write-host "Scraping Table Columns '$cluster_name' | '$db_name($tb_name)' => '$get_tb_col_uri'."
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
                                $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Table '$tb_name' has ($tb_count) columns.")
                                #Write-Host "Table '$tb_name' has ($tb_count) columns."
                                #
                                # Write to tabl map
                                $table.Columns = $table_cols
                            }
                            #
                            # Failed to get Columns for tables
                            catch {
                                Write-Host "'$cluster_name' failed to connect via RestAPI. Error: [$_]"
                                $LogLevel | Write-Log -file "$OUTPUT_LOG" -level ERROR -text ("'$cluster_name' failed to connect via RestAPI. Error: [$_]")
                                # 429 backoff
                                if ($_ -match "429") {
                                    $backoff_mod = set-backoff -backoff_mod $backoff_mod -error_log "$OUTPUT_LOG"
                                }
                                elseif ($_ -match "401") {
                                    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Refreshing Token.")
                                    Write-host "Access Token has expired or you are not on VPN!"
                                    $token = get-accessToken -tenantId $TenantId #in. Every. Incarnation.
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
                    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level ERROR -text ("'$cluster_name' failed to connect via RestAPI. Error: [$_]")
                    Write-Host "'$cluster_name' failed to connect via RestAPI. Error: [$_]"
                    # 429 backoff
                    if ($_ -match "429") {
                        $backoff_mod = set-backoff -backoff_mod $backoff_mod -error_log "$OUTPUT_LOG"
                    }
                    elseif ($_ -match "401") {
                        $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Refreshing Token.")
                        Write-host "Access Token has expired or you are not on VPN!"
                        $token = get-accessToken -tenantId $TenantId
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
        $LogLevel | Write-Log -file "$OUTPUT_LOG" -level ERROR -text ("'$cluster_name' failed to connect via RestAPI. Error: [$_]")
        Write-Host "'$cluster_name' failed to connect via RestAPI. Error: [$_]"
        # 429 backoff
        if ($_ -match "429") {
            $backoff_mod = set-backoff -backoff_mod $backoff_mod -error_log "$OUTPUT_LOG"
        }
        elseif ($_ -match "401") {
            $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Refreshing Token.")
            Write-host "Access Token has expired or you are not on VPN!"
            $token = get-accessToken -tenantId $TenantId
        }
    }
    #
    # Output from cluster run
    $stopwatch.Stop()
    $Output = @{
        "DateCompleted"   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        "DurationSeconds" = $stopwatch.Elapsed.TotalSeconds
        "APIRequestCount" = $request_acc
        "Metadata"        = $cluster
    }
    $LogLevel | Write-Log -file "$OUTPUT_LOG" -level INFO -text ("Run complete after " + $stopwatch.Elapsed.TotalSeconds + 's')
    write-host "Scrape complete after " + $stopwatch.Elapsed.TotalSeconds + 's'
    #
    Set-Content -Value ($Output | ConvertTo-Json -dept 10) -Path ".\output_raw\$cluster_name.json"
    #
}
