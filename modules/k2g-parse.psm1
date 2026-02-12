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
    ClusterMeta([string]$name, [string]$url) {
        # Cluster friendly name
        $this.name = $name
        # clean URL input
        $this.url = if ($url -match "Data Source=") {
            # removes data source tag, port, etc
            ($url.Replace("Data Source=", "") -split ":443" -split ";")[0]
        }
        else {
            $url
        }
    }
}

#
#
#
function Initialize-ConnectionsXML() {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )
    [xml](Get-Content $Path)
}


#
#
#
function Get-KClusters() {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [xml]$ConnectionsXML
    )
    $ConnectionsXML.ArrayOfServerDescriptionBase.ServerDescriptionBase 
    | select-object Name, Details
    | ForEach-Object { [ClusterMeta]::new($_.Name, $_.Details) }
}

