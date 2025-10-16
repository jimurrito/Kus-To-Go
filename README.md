# Kus-to-go

Kusto metadata scraper.

---

## Table of Contents

- #faq
  - #what-is-this
  - #what-is-kusto-metadata-do-you-mean-the-data-stored-in-the-tables
- #how-to-use-kus-to-gops1
  - #requirements
  - #retrieve-an-access-token-for-kusto
  - #generating-a-kusto_connectionsxml-file
  - #expected-file-structure
  - #run-the-script
  - #get-the-output-files
  - #considerations
- #data-manipulation
  - #compressps1

---

## FAQ

### What is this?

Kus-to-go, or "Kusto-to-go", is a set of scripts that help facilitate the scraping and compiling of Kusto metadata.

### What is _Kusto Metadata_? Do you mean the data stored in the tables?!

No. The metadata describes the structure and schema of the Kusto environment.
Data like column names of tables, the database that holds the table, and its parent cluster is the core of what is being scraped.
One thing the script does **not** collect is statistics (size of the cluster/DB/table, number of rows, or number of requests).
The primary focus of this script is to break down the schema of a large multi-cluster Kusto environment.

---

## How to use `kus-to-go.ps1`

### Requirements

- `kusto_connections.xml` file containing a list of Kusto cluster endpoints (exported from Kusto Explorer).
- `access_token` file containing an access token for your target Kusto environment.

### Retrieve an access token for Kusto

> This step may be removed in future builds.

To gain an access token, run the following in the Azure CLI:

```bash
az login
az account get-access-token --resource "https://api.kusto.windows.net" --query "accessToken"
```

When running `az login`, you will be prompted to select a subscription.
Which one is chosen does not matter, as long as it is in the tenant attached to the Kusto cluster.
No subscription calls will be made; this is just a requirement of using `az login`.

This token is only valid for one hour.
If the script takes longer than one hour, you will need to update the `access_token` file.

---

### Generating a `kusto_connections.xml` file

> This step requires you to already have Kusto Explorer set up and working with the target Kusto clusters.

1. Open **Kusto Explorer** and select the **Connections** tab.
2. Find the **Export Connections** option on the second panel from the left.
3. Save the file to the current directory as `kusto_connections.xml`.

As of now, the file name needs to be `kusto_connections.xml`. Later builds will allow parameterization.

Please note that all connections in the XML file will be attempted during scraping.
If you do not want a connection scraped, manually remove it from the file.

---

### Expected file structure

```text
kus-to-go/
|
|- access_token
|- kusto_connections.xml
|- kus-to-go.ps1
|- README.md
|- ...
```

---

### Run the script

```powershell
.\kus-to-go.ps1
```

---

### Get the output files

Per cluster, a `.json` file will be created under `$PWD/output_raw`.
This makes it easier to prune unneeded cluster metadata, but the dataset will be segmented.

Using the scripts under `data_manipulation`, you can compile all smaller files into one monolithic file.
To learn more, see #data-manipulation.

---

### Considerations

- Depending on the size of your Kusto environment, this could take some time.
- If the script encounters any 401 errors, it will assume the access token has expired.
  When this occurs, the script will pause and expect you to manually update the file.
  Once done, you can return to the script and hit `Enter` to continue.

---

## Data Manipulation

### `compress.ps1`

This script compresses the raw output JSON into a single JSON array.
It contains a `-filter` parameter that allows granular selection of the raw JSON data.
