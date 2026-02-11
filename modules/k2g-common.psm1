#
#
# Kus-to-go Common library
#
# Written by:
# - James Immer
# - Creston Lockerd
# - Func documentation by Copilot
#
#


#
#
#
function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log entry to a file if the log level is permitted.

    .DESCRIPTION
        Compares the message log level against an environment log level.
        If the message level is equal or higher priority, the message is appended
        to the specified log file with a syslog-style timestamp.

    .PARAMETER env_log_level
        The minimum log level required for messages to be written.
        Accepts: INFO, WARN, ERROR, DEBUG.
        Defaults to INFO.

    .PARAMETER file
        The path to the log file.

    .PARAMETER level
        The log level of the message being written.

    .PARAMETER text
        The message text to log.

    .EXAMPLE
        Write-Log -file "/tmp/app.log" -level "WARN" -text "Something happened"

    .NOTES
        Uses an internal anonymous function (scriptblock) to map log levels
        to numeric priority values.
    #>
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$env_log_level = "INFO",

        [Parameter(Mandatory)]
        [string]$file,

        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$level = "INFO",

        [Parameter(Mandatory)]
        [string]$text
    )
    # Map to convert log levels to num
    $matrix = @{ 
        ERROR = 1 
        WARN  = 2 
        INFO  = 3 
        DEBUG = 4 
    }
    # Only write if message level is <= environment level
    if ($matrix.$level -le $matrix.$env_log_level) {
        Add-Content -Path $file -Value "$(Get-Date -Format "yyyy-MM-ddTh:m:s") $level $text"
    }
}


#
#
#
function Set-Backoff {
    <#
    .SYNOPSIS
    Implements exponential backoff after receiving a throttling response.

    .DESCRIPTION
    The Set-Backoff function calculates a backoff delay using an exponential
    formula based on the provided backoff modifier. It logs a warning message,
    displays a notification to the console, sleeps for the calculated duration,
    and returns the next backoff modifier value.

    The backoff time is calculated as:
        60 * (2 ^ backoff_mod)

    .PARAMETER Backoff_Mod
    The current backoff modifier used to compute the exponential delay.

    .PARAMETER Error_Log
    The path to the log file where backoff events should be recorded.

    .EXAMPLE
    $backoff = 0
    $backoff = Set-Backoff -Backoff_Mod $backoff -Error_Log "C:\Logs\errors.log"

    Calculates a delay of 60 seconds, logs the event, sleeps, and returns 1.

    .EXAMPLE
    Set-Backoff 3 "C:\Logs\errors.log"

    Uses positional parameters to apply a backoff of 480 seconds (8 minutes).

    .NOTES
    This function depends on Add-LogData for logging.
    #>
    param (
        [Parameter(Mandatory)]
        [int]$backoff_mod,

        [Parameter(Mandatory)]
        [string]$error_log
    )
    $backoff_time = 60 * [math]::Pow(2, $backoff_mod)
    Add-LogData -file $error_log `
        -level WARN `
        -text "Backing off for $backoff_time seconds..."
    Write-Host "Received 429 response. Backing off for $backoff_time seconds..."
    Start-Sleep -Seconds $backoff_time
    return ($backoff_mod + 1)
}
