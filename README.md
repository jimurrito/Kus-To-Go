# Kus-to-go
Kusto metadata scrapper.

[[TOC]]

## FAQ

### What is this?

Kus-to-go, or "Kusto-to-go", is a set of scripts that help facilitate the scrapping and compiling of Kusto Metadata.

### What is *Kusto Metadata*? Do you mean the data stored in the Tables?!?!

No. The metadata is the data that describes the structure and schema of the Kusto environment.
Data like the column names of tables, the database that holds the table, and its parent cluster is the core of what is being scrapped.
One thing the script does __not__ collect is statistics. Size of the cluster/DB/table, number of rows, or number or requests.
The primary focus of this script is to break down the schema of a large multi-cluster Kusto environment.


## How to use `kus-to-go.ps1`

### Requirements

- `kusto_connections.xml` file containing a list of Kusto cluster endpoints. (This can be exported from Kusto Explorer)
- `acces_token` file containing a access token to your target Kusto environment.

