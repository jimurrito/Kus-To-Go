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
    #
    [void] WriteLog([LogLevel]$Level, [string]$Text) {
        # If input log level is less then env, print
        if ($level -le $this.LogLevel) {
            Add-Content -Path $this.LogFile -Value "$(Get-Date -Format "yyyy-MM-ddThh:mm:ss") $Level $Text"
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
# Powershell wrappers

function New-Logger () {
    param(
        [Parameter(Mandatory)]
        [LogLevel]$EnvLogLevel,

        [Parameter(Mandatory)]
        [string]$LogFile
    )
    [Logger]::new($EnvLogLevel, $LogFile)
}