# Kus‑to‑Go  
### A Kusto Metadata Scraper for Multi‑Cluster Environments

![PowerShell](https://img.shields.io/badge/PowerShell-5%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows)
![Excel COM](https://img.shields.io/badge/Requires-Microsoft%20Excel-yellow)
![License](https://img.shields.io/badge/License-GPLv3-green)


Kus‑to‑Go is a PowerShell‑based tool that automates the discovery and extraction of **Kusto (Azure Data Explorer)** metadata across large, multi‑cluster environments. It authenticates to Azure, walks each cluster, retrieves schema information, and produces a clean Excel workbook per cluster.

This project is built for engineers who need a fast, repeatable, and auditable way to inventory Kusto schema at scale.

---

## Table of Contents

- [Overview](#overview)  
- [What Kus‑to‑Go Scrapes](#what-kus-to-go-scrapes)  
- [Requirements](#requirements)  
- [Generating `kusto_connections.xml`](#generating-kusto_connectionsxml)  
- [Running the Script](#running-the-script)  
- [Output Structure](#output-structure)  
- [Considerations](#considerations)
- [AI Disclaimer](#ai-disclaimer)

---

## Overview

Kus‑to‑Go automates the process of walking a Kusto environment:

1. Authenticate to Azure and obtain a Kusto access token  
2. Parse a `kusto_connections.xml` file exported from Kusto Explorer  
3. Iterate each cluster  
4. Retrieve databases  
5. Retrieve tables  
6. Retrieve columns  
7. Write all metadata to an Excel workbook per cluster  

Each workbook contains one row per table:

```
Cluster | Cluster-URI | Database | Table | Columns | Details
```

This makes it easy to audit schema, compare clusters, or feed downstream automation.

---

## What Kus‑to‑Go Scrapes

Kus‑to‑Go collects **metadata**, not data.

It retrieves:

- Cluster name & URI  
- Database names  
- Table names  
- Column names  

It does **not** retrieve:

- Row counts  
- Table sizes  
- Query statistics  
- Data stored in tables  

The goal is to map the *shape* of your Kusto environment, not its contents.

---

## Requirements

- PowerShell 5+  
- Microsoft Excel installed (COM automation is required)  
- A valid Azure AD tenant ID  
- A `kusto_connections.xml` file exported from Kusto Explorer  

The script automatically creates:

- `./logs/`  
- `./output/`  

---

## Generating `kusto_connections.xml`

1. Open **Kusto Explorer**  
2. Go to the **Connections** tab  
3. Select **Export Connections**  
4. Save the file as `kusto_connections.xml` in the same directory as `kus-to-go.ps1`  

All connections in the file will be scraped.  
Remove any you do not want included.

---

## Running the Script

Basic usage:

```powershell
.\kus-to-go.ps1 -TenantId "<your-tenant-id>"
```

Optional parameters:

- `-LogLevel INFO|WARN|ERROR|DEBUG`  
- `-LogDir <path>`  
- `-Output <path>`  
- `-ConnectionsXML <path>`  
- `-Force` (re-scrape even if output file exists)  
- `-Visualize` (show Excel windows instead of running hidden)

Example:

```powershell
.\kus-to-go.ps1 -TenantId "00000000-0000-0000-0000-000000000000" -Visualize
```

---

## Output Structure

For each cluster, Kus‑to‑Go generates:

```
./output/<cluster-name>.xlsx
```

Each workbook contains:

- One sheet  
- One row per table  
- Columns:  
  - Cluster  
  - Cluster-URI  
  - Database  
  - Table  
  - Columns (comma‑separated)  
  - Details (reserved for future use)

This replaces all previous JSON‑based output formats.

---

## Considerations

- Large Kusto environments may take significant time to scrape  
- 401 responses trigger token refresh  
- 429 responses trigger exponential backoff  
- Blacklist filtering removes known noise tables  
- Excel must remain installed and functional for COM automation  

---

# AI disclaimer

AI was used to generate the documention for most functions and this very readme. 
However all code was human written and reviewed. "Vibe coded" PRs will not be merged.

---

Kus‑to‑Go is designed to be a reliable, repeatable tool for understanding the structure of complex Kusto deployments. 

Contributions and improvements are welcome.
