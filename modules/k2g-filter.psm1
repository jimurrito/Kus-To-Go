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
#
# BLACK LIST
function Get-BlackList {
    <#
    .SYNOPSIS
        Returns a list of blacklist patterns used for filtering names or identifiers.

    .DESCRIPTION
        Get-BlackList returns a predefined set of strings and pattern fragments
        used to exclude items during filtering operations. These values are
        typically consumed by functions that perform substring or regex-based
        matching to remove unwanted entries such as temporary names, test
        identifiers, environment-specific markers, or known non-production
        prefixes.

        The list includes both literal strings (e.g., "temp", "alpha") and
        regex-compatible fragments (e.g., "V[0-9]", "V[0-9][0-9]") to support
        flexible matching scenarios.

    .OUTPUTS
        string[]
            An array of blacklist terms and pattern fragments.

    .EXAMPLE
        $patterns = Get-BlackList
        $filtered = $items | Where-Object { $_ -notmatch ($patterns -join '|') }

        Retrieves the blacklist and filters out any items matching the patterns.

    .NOTES
        - This function returns only the blacklist values; it does not perform
          any filtering itself.
        - Some entries are intended for regex-based matching and should be
          escaped or handled appropriately depending on the filtering method.
    #>

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
        "test"
        "V[0-9]"
        "V[0-9][0-9]"
        "."
        "RDFE"
    )
}


#
#
#
function Remove-BlackListed {
    <#
    .SYNOPSIS
        Removes items from a list that match any blacklist pattern.

    .DESCRIPTION
        Remove-BlackListed filters an input list of strings by comparing each
        element against the patterns returned by Get-BlackList. The blacklist
        contains both literal strings and regex-compatible fragments. To ensure
        safe and predictable matching, each blacklist entry is escaped before
        being combined into a single regex pattern.

        Any input item that matches one or more blacklist patterns is excluded
        from the output. Items that do not match are returned unchanged.

    .PARAMETER InputList
        The list of strings to be filtered. Any element that matches a blacklist
        pattern will be removed from the output.

    .OUTPUTS
        string[]
            A filtered list containing only items that do not match any
            blacklist pattern.

    .EXAMPLE
        $items = @("tempfile", "prod-data", "alpha-test", "report")
        Remove-BlackListed -InputList $items

        Returns only "prod-data" and "report", because "temp" and "alpha"
        appear in the blacklist.

    .EXAMPLE
        $items | Remove-BlackListed

        Demonstrates pipeline-style usage.

    .NOTES
        - Blacklist values are escaped before being combined into a regex
          pattern to prevent unintended regex interpretation.
        - This function performs partial/substring matching using -notmatch.
        - Get-BlackList defines the authoritative set of exclusion patterns.
    #>

    param(
        [Parameter(Mandatory)]
        [string[]]$InputList
    )

    # Create a safe, escaped regex pattern from the blacklist
    $pattern = (Get-BlackList |
        Where-Object { $_.Trim() -ne "" } |
        ForEach-Object { [regex]::Escape($_) }
    ) -join '|'

    # Return only items that do not match the blacklist
    $InputList | Where-Object { $_ -notmatch $pattern }
}


