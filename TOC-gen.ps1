param(
    [string]$MarkdownFile = ".\README.md"
)

# Read all lines from the Markdown file
$content = Get-Content -Path $MarkdownFile

# Extract headings (lines starting with #)
$headings = $content | Where-Object { $_ -match '^\s*#{1,6}\s+' }

# Build TOC
$TOC = "## Table of Contents`n"
foreach ($line in $headings) {
    # Count heading level (# = 1, ## = 2, etc.)
    $level = ($line -split '\s+')[0].Length
    $text = ($line -replace '^\s*#{1,6}\s+', '').Trim()
    
    # Create GitHub anchor (lowercase, spaces -> -, remove special chars)
    $anchor = $text.ToLower() -replace '[^\w\s-]', '' -replace '\s+', '-'
    
    # Indent based on heading level
    $indent = '  ' * ($level - 1)
    $TOC += "$indent- #$anchor`n"
}

# Output TOC
$TOC | Set-Clipboard
Write-Host "✅ TOC generated and copied to clipboard!"