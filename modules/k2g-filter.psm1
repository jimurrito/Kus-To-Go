#
#
# Kus-to-go Filtering library
#
# Written by:
# - James Immer
# - Func documentation by Copilot
#
#


#
# BLACK LIST
function Get-BlackList() {
    @(
        "temp"
        "beta"
        "alpha"
        "fairfax"
        "blackforest"
        "mooncake"
        "fed"
        "sample"
        "kusto"
    )
}

function Remove-BlackListed {
    param(
        [Parameter(Mandatory)]
        [string[]]$InputList
    )
    # Creates a regex pattern for parsing    
    $pattern = (Get-BlackList | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
            [regex]::Escape($_)
        }) -join '|'
    # compares each element and rejects those that do not pass the regex pattern
    $InputList | Where-Object { $_ -notmatch $pattern }
}

