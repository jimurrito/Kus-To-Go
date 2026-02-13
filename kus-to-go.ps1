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
    [switch]$Force,

    # Renders the excel windows instead of hiding them
    [switch]$Visualize
)

#
# Imports
# Uses "$PSScriptRoot" so the path is relative to the script and now the user working dir
import-module $PSScriptRoot/modules/k2g-common.psm1 -Force
import-module $PSScriptRoot/modules/k2g-auth.psm1 -Force
import-module $PSScriptRoot/modules/k2g-http.psm1 -Force
import-module $PSScriptRoot/modules/k2g-excel.psm1 -Force
import-module $PSScriptRoot/modules/k2g-parse.psm1 -Force
import-module $PSScriptRoot/modules/k2g-logger.psm1 -Force
import-module $PSScriptRoot/modules/k2g-filter.psm1 -Force

#
# Start timer
$TIMER_START = Get-Date

#
# Create required Dirs. Ignore if dir already exists
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
New-Item -Path $Output -ItemType Directory -Force | Out-Null

# Create log file and grab output absolute path
# have to use "yyyy-MM-ddTh_m_s" as ':' is not valid for windows file names
$output_log_path = (New-Item -Path "$LogDir" -ItemType File -Name "$(Get-Date -Format "yyyy-MM-ddTHH_mm_ss").log" -force).ResolvedTarget

#
# Create Logger obj
$LOGGER = New-Logger -EnvLogLevel $LogLevel -LogFile ($output_log_path)

#
# Changed write-log to use pipe to control logging based on env log level
$LOGGER.LogInfo("Initializing Script")

#
# get cluster connections from *.xml data
$LOGGER.LogInfo("Importing connections xml file provided")
$clusters = $ConnectionsXML | Initialize-ConnectionsXML | Get-KClusters
$LOGGER.LogDebug("[$($clusters.count)] Clusters found in [$ConnectionsXML]")

#
# Create excel handler
$LOGGER.LogDebug("Opening an Excel handler...")
$excel = Initialize-Excel -Visualize $Visualize

#
# Initial login
$LOGGER.LogInfo("Acquiring Token")
$token = New-AccessToken -TenantId $TenantId # Silly jmurrito forgot to add the variable they created!
$LOGGER.LogInfo("Token valid until [$($token.expiry)]")


#
# Iterates through every Cluster in the connections xml.
:CLUSTER_FOR foreach ($cluster in $clusters) {
    #
    # check if cluster already has an excel file in the output dir
    $excel_output = (Join-path "$PWD" "${output}$($cluster.Name).xlsx")
    if ((Test-Path -path $excel_output) -and !$force) {
        # File already exists, and we are not forcing.
        # Skip this cluster.
        $LOGGER.LogInfo("Cluster [$($cluster.Name)] has already been scrapped to [$excel_output]. Skipping Cluster")
        # Advances the for-loop to the next instance
        continue CLUSTER_FOR
    }

    #
    #
    # If you have made it this far, we will be scrapping the cluster metadata
    #
    #

    #
    # Validate token validity -> refresh if invalid due to time
    # Will be done if a 401 is provided, but this is proactive incase the timer has been exhausted
    if ($token.IsExpired()) {
        $LOGGER.LogWarn("Kusto Token has expired. Re-auth pop-up sent to user.")
        $token.Refresh()
    }

    #
    # Create Connection class
    $LOGGER.LogDebug("Creating Connection class for cluster [$($cluster.name)]...")
    $conn = New-ClusterConnection -ClusterUrl $cluster.url -Token $token.Token

    #
    # Stuck in loop until we hit a failure threshold, or succeed with databases
    :DB_While while ($true) {
        $LOGGER.LogInfo("Attempting to scrape Database(s) from [$($cluster.Name)].")
        # 
        # Check database query return
        $resp = $conn.GetDatabases()
        switch ($resp.code) {
            # Success
            200 {
                $LOGGER.LogInfo("Returned [$($resp.data.Count)] Databases from Cluster [$($cluster.Name)].")
                # If we found no DBs, move to next cluster
                if (!($resp.data.Count)) {
                    $LOGGER.LogWarn("No Databases found in Cluster [$($cluster.Name)]. Moving to next cluster.")
                    # Advance cluster for loop
                    continue CLUSTER_FOR
                }

                # Store response data in a new var
                $databases = $resp.data
                # break while and continue
                break DB_While

            }
            # 401 un-authorized. Token expired or no VPN
            401 {
                $LOGGER.LogWarn("401 returned while scrapping [$($cluster.Name)] for databases.")
                $conn.failCount += 1
                # hard coded failure limit of 3
                # After 3 401(s) we should probably take the hint. No means no.
                if ($conn.failCount -ge 3) {
                    $LOGGER.LogError("Failure limit for cluster has been reached [3]. Skipping Cluster.")
                    # Advance cluster loop
                    continue CLUSTER_FOR
                }
                #
                # verbose log and refresh token
                $LOGGER.LogDebug("Fail counter for cluster [$($cluster.Name)] is now at [$($conn.failCount)]")
                $LOGGER.LogWarn("Attempting reauthentication. Prompt sent to user...")
                $token.Refresh()
                $conn.RefreshToken($token.Token)
            }
            # 429 Too Many Requests
            429 {
                $LOGGER.LogError("429 returned while scrapping [$($cluster.Name)] for databases.")
                $conn.backoffCount += 1
                # Hard coded backoff limit is 6
                # 5th backoff would be 32 minutes log
                # 6th backoff would be 64 minutes log, and this will cause the next request to reauth. Skips cluster to void prolonged waiting.
                if ($conn.backoffCount -ge 6) {
                    $LOGGER.LogError("Backoff limit for cluster has been reached [6]. Skipping Cluster.")
                    # Advance cluster loop
                    continue CLUSTER_FOR
                }
                $backoff_time = 60 * [math]::Pow(2, $backoff_mod)
                $LOGGER.LogWarn("Starting backoff #[$($conn.backoffCount)] for [$backoff_time] seconds")
                Start-Sleep $backoff_time
            }
            # Unknown/Unmapped error
            default {
                $LOGGER.LogError("Unexpected error occurred while scrapping [$($cluster.Name)] for databases. Skipping Cluster.")
                $LOGGER.LogDebug("Unexpected error [ code: $($resp.data) data: $($resp.data)]")
                continue CLUSTER_FOR
            }
        }
    }

    #
    # Excel workbook is only opened if we have any databases in the Cluster

    #
    # Create workbook + sheet via [ExcelWorkSpace] class
    $LOGGER.LogDebug("Creating Excel workbook [$excel_output]...")
    $excel_workspace = $excel | New-ExcelWorkbook -FilePath $excel_output
    # Add header to excel sheet.
    $LOGGER.LogDebug("Adding headers to Excel Workbook [$excel_output] sheet (1) ...")
    $excel_workspace.AddRow(@("Cluster", "Cluster-URI", "Database", "Table", "Columns", "Details"))

    #
    # At this point, we have some databases from the cluster
    # $databases contains the list of names

    #
    # Enumerate the databases to get tables
    :DB_FOR foreach ($database in $databases[0]) {

        #
        # Set database name into connection obj
        $conn.database = $database

        #
        # Holds loop until we failout or succeed.
        :TBL_While while ($true) {
            $LOGGER.LogInfo("Attempting to scrape Table(s) from Database [$database].")
            # 
            # Check database query return
            $resp = $conn.GetTables()
            switch ($resp.code) {
                # Success
                200 {
                    #
                    # We have to filter out junk tables and tables which are related to sovreign clouds. 
                    #
                    # pre-filter debug output
                    $preFilterCount = $resp.data.Count
                    $LOGGER.LogDebug("[Pre-filter!] Returned [$preFilterCount] Tables from Database [$database].")
                    # run blacklist filter
                    # Must be a param as piped input works off each item individually
                    $resp.data = Remove-BlackListed -InputList $resp.data
                    $postFilterCount = $resp.data.Count
                    $LOGGER.LogDebug("Removed [$($preFilterCount - $postFilterCount)] Tables from the list due to blacklisting.")
                    $LOGGER.LogInfo("Returned [$postFilterCount] Table(s) from Database [$database].")
                    #
                    #

                    # If we found no TBLs, move to next DB
                    if (!($resp.data.Count)) {
                        $LOGGER.LogWarn("No Tables found in Database [$database]. Moving to next Database.")
                        # Advance DB for loop
                        continue DB_FOR
                    }

                    # Store response data in a new var
                    $tables = $resp.data
                    # break while and continue
                    break TBL_While

                }
                # 401 un-authorized. Token expired or no VPN
                401 {
                    $LOGGER.LogWarn("401 returned while scrapping Database [$database] for Tables.")
                    $conn.failCount += 1
                    # hard coded failure limit of 3
                    # After 3 401(s) we should probably take the hint. No means no.
                    if ($conn.failCount -ge 3) {
                        $LOGGER.LogError("Failure limit for cluster has been reached [3]. Skipping Cluster.")
                        # Advance cluster loop
                        continue CLUSTER_FOR
                    }
                    #
                    # verbose log and refresh token
                    $LOGGER.LogDebug("Fail counter for cluster [$($cluster.Name)] is now at [$($conn.failCount)]")
                    $LOGGER.LogWarn("Attempting reauthentication. Prompt sent to user...")
                    $token.Refresh()
                    $conn.RefreshToken($token.Token)

                }
                # 429 Too Many Requests
                429 {
                    $LOGGER.LogError("429 returned while scrapping Database [$database] for Tables.")
                    $conn.backoffCount += 1
                    # Hard coded backoff limit is 6
                    # 5th backoff would be 32 minutes log
                    # 6th backoff would be 64 minutes log, and this will cause the next request to reauth. Skips cluster to void prolonged waiting.
                    if ($conn.backoffCount -ge 6) {
                        $LOGGER.LogError("Backoff limit for cluster has been reached [6]. Skipping Cluster.")
                        # Advance cluster loop
                        continue CLUSTER_FOR
                    }
                    $backoff_time = 60 * [math]::Pow(2, $backoff_mod)
                    $LOGGER.LogWarn("Starting backoff #[$($conn.backoffCount)] for [$backoff_time] seconds")
                    Start-Sleep $backoff_time
                }
                # Unknown/Unmapped error
                default {
                    $LOGGER.LogError("Unexpected error occurred while scrapping Database [$database] for Tables. Skipping Database.")
                    $LOGGER.LogDebug("Unexpected error [ code: $($resp.data) data: $($resp.data)]")
                    # advance to next DB
                    continue DB_FOR
                }
            }
        }

        # $tables contains the list of names

        #
        # Enumerate Tables
        :TBL_FOR foreach ($table in $tables) {
            #
            # Set table name in connection obj
            $conn.table = $table

            #
            # Holds loop until we failout or succeed.
            :ColumnWhile while ($true) {
                $LOGGER.LogInfo("Attempting to scrape Column(s) from Table [$table].")
                # 
                # Check database query return
                $resp = $conn.GetColumns()
                switch ($resp.code) {
                    # Success
                    200 {
                        $LOGGER.LogInfo("Returned [$($resp.data.Count)] Columns from Table [$table].")
                        # If we found no TBLs, move to next DB
                        if (!($resp.data.Count)) {
                            $LOGGER.LogWarn("No Columns found in Table [$table]. Moving to next Table.")
                            # Advance DB for loop
                            continue DB_FOR
                        }

                        # Store response data in a new var
                        $columns = $resp.data
                        # break while and continue
                        break ColumnWhile

                    }
                    # 401 un-authorized. Token expired or no VPN
                    401 {
                        $LOGGER.LogWarn("401 returned while scrapping Table [$table] for Columns.")
                        $conn.failCount += 1
                        # hard coded failure limit of 3
                        # After 3 401(s) we should probably take the hint. No means no.
                        if ($conn.failCount -ge 3) {
                            $LOGGER.LogError("Failure limit for cluster has been reached [3]. Skipping Cluster.")
                            # Advance cluster loop
                            continue CLUSTER_FOR
                        }
                        #
                        # verbose log and refresh token
                        $LOGGER.LogDebug("Fail counter for cluster [$($cluster.Name)] is now at [$($conn.failCount)]")
                        $LOGGER.LogWarn("Attempting reauthentication. Prompt sent to user...")
                        $token.Refresh()
                        $conn.RefreshToken($token.Token)

                    }
                    # 429 Too Many Requests
                    429 {
                        $LOGGER.LogError("429 returned while scrapping Table [$table] for Columns.")
                        $conn.backoffCount += 1
                        # Hard coded backoff limit is 6
                        # 5th backoff would be 32 minutes log
                        # 6th backoff would be 64 minutes log, and this will cause the next request to reauth. Skips cluster to void prolonged waiting.
                        if ($conn.backoffCount -ge 6) {
                            $LOGGER.LogError("Backoff limit for cluster has been reached [6]. Skipping Cluster.")
                            # Advance cluster loop
                            continue CLUSTER_FOR
                        }
                        $backoff_time = 60 * [math]::Pow(2, $backoff_mod)
                        $LOGGER.LogWarn("Starting backoff #[$($conn.backoffCount)] for [$backoff_time] seconds")
                        Start-Sleep $backoff_time
                    }
                    # Unknown/Unmapped error
                    default {
                        $LOGGER.LogError("Unexpected error occurred while scrapping Table [$table] for Columns. Skipping Table.")
                        $LOGGER.LogDebug("Unexpected error [ code: $($resp.data) data: $($resp.data)]")
                        continue TBL_FOR
                    }
                }
            }

            #
            # $columns contains the list of columns for this table
        
            #
            # Write data to row in excel
            # One row per table
            $LOGGER.LogDebug("Saving data for Table [$table] to Excel sheet")
            # schema: @("Cluster", "Cluster-URI", "Database", "Table", "Columns", "Details")
            $excel_workspace.AddRow(@($cluster.name, $cluster.url, $database, $table, ($columns -join ", "), ""))
            #
            # End of Table iteration
        }

        #
        # End of DB iteration
    }

    #
    # Back to cluster level
    # If you are here, we have finished enumerating all the databases in the cluster

    # Write excel sheet to the output file
    $LOGGER.LogInfo("Saving Excel Workbook [$($excel_output)].")
    $excel_workspace.SaveAs()
    $excel_workspace.Close()

    #
    # End of cluster iteration
}

# Kill excel once we are done
$LOGGER.LogDebug("Closing Excel")
$excel.Quit()

#
# Stop timer
$elapsed = (Get-Date) - $TIMER_START

#
$LOGGER.LogInfo("Done. Completed run in ($($elapsed.TotalSeconds))s")
