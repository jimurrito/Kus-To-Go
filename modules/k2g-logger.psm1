#
#
# Kus-to-go Logging library
#
# Written by:
# - James Immer
# - Func documentation by Copilot
#
#

#
# Log Level enum
enum LogLevel { 
    DEBUG = 4
    INFO = 3
    WARN = 2
    ERROR = 1
}

#
# Static class for env Log Level
class Logger {
    [Int]$LogLevel
    [string]$LogFile

    #
    # Bindings for ::new
    Logger([LogLevel]$LogLevel, [string]$LogFile) {
        $this.LogLevel = $LogLevel
        $this.LogFile = $LogFile
    }

    #
    # generic log writer
    [void] WriteLog([LogLevel]$Level, [string]$Text) {
        # If input log level is less then env, print
        if ($level -le $this.LogLevel) {
            Add-Content -Path $this.LogFile -Value "$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss") $Level $Text"
        }
    }

    #
    # Log level handlers
    [void] LogDebug([string]$text) {
        $this.WriteLog([LogLevel]::DEBUG, $text)
    }
    [void] LogInfo([string]$text) {
        $this.WriteLog([LogLevel]::INFO, $text)
    }
    [void] LogWarn([string]$text) {
        $this.WriteLog([LogLevel]::WARN, $text)
    }
    [void] LogError([string]$text) {
        $this.WriteLog([LogLevel]::ERROR, $text)
    }
}


#
#
#
<#
.SYNOPSIS
    Creates a new Logger instance with the specified log level and output file.

.DESCRIPTION
    New-Logger is a convenience wrapper for instantiating the Logger class.
    It accepts a LogLevel enum value and a file path, then returns a fully
    initialized Logger object ready for use.

.PARAMETER EnvLogLevel
    The minimum log level required for messages to be written. Messages with
    a severity numerically less than or equal to this value will be logged.

.PARAMETER LogFile
    The path to the file where log entries will be written. The file will be
    created automatically if it does not already exist.

.OUTPUTS
    Logger
        Returns a Logger object configured with the provided log level and file.

.EXAMPLE
    $log = New-Logger -EnvLogLevel INFO -LogFile "C:\logs\app.log"

    Creates a logger that writes INFO, WARN, and ERROR messages to app.log.

.EXAMPLE
    $log = New-Logger -EnvLogLevel DEBUG -LogFile "./debug.log"
    $log.LogDebug("Starting process")

    Creates a verbose logger and writes a DEBUG message.
#>
function New-Logger {
    param(
        [Parameter(Mandatory)]
        [LogLevel]$EnvLogLevel,

        [Parameter(Mandatory)]
        [string]$LogFile
    )
    [Logger]::new($EnvLogLevel, $LogFile)
}
