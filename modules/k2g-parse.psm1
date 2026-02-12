#
#
# Kus-to-go Parsing library
#
# Written by:
# - James Immer
# - Func documentation by Copilot
#
#

#
#
class ClusterMeta {
    [string]$name
    [string]$url
    #
    #
    ClusterMeta([string]$name, [string]$url) {
        # Cluster friendly name
        $this.name = $name
        # clean URL input
        # Some URLs are formatted like [Data Source=<kustoURL>:443;]
        $this.url = if ($url -match "Data Source=") {
            # removes data source tag, port, etc
            # Uses regex to remove bloat at the end of the URL
            ($url -replace '^Data Source=', '') -replace '(:443|;).*$', ''
        }
        else {
            $url
        }
    }
}

#
#
#
<#
.SYNOPSIS
    Loads a Kusto Connections XML file into a typed XML object.

.DESCRIPTION
    Initialize-ConnectionsXML reads the specified XML file and casts it to
    a PowerShell [xml] object. This function is typically used as the first
    step in extracting cluster metadata from a Kusto connections export.

.PARAMETER Path
    The file path to the XML document containing connection definitions.

.OUTPUTS
    [xml]
        Returns the parsed XML document as a typed XML object.

.EXAMPLE
    $xml = Initialize-ConnectionsXML -Path "C:\temp\connections.xml"

    Loads the XML file and returns it as a PowerShell XML object.

.EXAMPLE
    "connections.xml" | Initialize-ConnectionsXML

    Demonstrates pipeline support.
#>
function Initialize-ConnectionsXML {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )
    [xml](Get-Content $Path)
}



#
#
#
<#
.SYNOPSIS
    Extracts cluster metadata from a Kusto Connections XML document.

.DESCRIPTION
    Get-KClusters processes a Kusto connections XML file and returns a list
    of ClusterMeta objects. Each object contains a friendly cluster name and
    a cleaned cluster URL derived from the XML's Details field.

.PARAMETER ConnectionsXML
    The XML document returned by Initialize-ConnectionsXML. Must contain
    an ArrayOfServerDescriptionBase element with cluster entries.

.OUTPUTS
    ClusterMeta
        One object per cluster defined in the XML.

.EXAMPLE
    $xml = Initialize-ConnectionsXML "connections.xml"
    $clusters = Get-KClusters -ConnectionsXML $xml

    Returns a list of ClusterMeta objects.

.EXAMPLE
    Initialize-ConnectionsXML "connections.xml" | Get-KClusters

    Demonstrates pipeline usage.
#>
function Get-KClusters {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [xml]$ConnectionsXML
    )

    $ConnectionsXML.ArrayOfServerDescriptionBase.ServerDescriptionBase 
    | Select-Object Name, Details 
    | ForEach-Object { [ClusterMeta]::new($_.Name, $_.Details) }
}


