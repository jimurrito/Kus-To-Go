<#
.SYNOPSIS
Compress multiple JSON files into a single JSON file.

.DESCRIPTION
This script takes all JSON files from a specified directory, removes pretty formatting, and combines them into one compressed JSON file. The output file is saved in a designated output directory.

.PARAMETER path
The directory containing the JSON files. Defaults to the current directory (".").

.PARAMETER out_path
The directory where the combined JSON file will be saved. Defaults to "<path>/output".

.PARAMETER filter
The file filter for selecting JSON files. Defaults to "*.json".

.EXAMPLE
.\CompressJson.ps1 -path "C:\Data" -out_path "C:\Data\Compressed" -filter "*.json"
Combines all JSON files in C:\Data into a single compressed file saved in C:\Data\Compressed\full_set.json.

.NOTES
Author: Jimurrito
#>


param(
    [string]$path = ".",
    [string]$out_path = "$path/output",
    [string]$filter = "*.json"
)

$null = New-Item -ItemType directory $out_path -ErrorAction SilentlyContinue

$output = Get-item -Path "$path/$filter" |
    Foreach-Object { Get-Content -Path $_.FullName -Raw | ConvertFrom-Json | ConvertTo-Json -Compress -Depth 100 } |
    ConvertTo-Json -Compress -Depth 100
    
Set-Content -Path "$out_path/full_set.json" -Encoding UTF8 -value $output
