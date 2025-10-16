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

### Retrieve an access token for Kusto

> This step maybe removed in future builds

To gain an access token, you must run the following in the Az CLI.

```bash
az login
az account get-access-token --resource "https://api.kusto.windows.net" --query "accessToken"
```

When running `az login`, you will be prompted to select a subscription.
Which one that is choosen does not matter, as long as it is in the tenant that is attached to the Kusto cluster.
No subscription calls will be made. This is just a requirement of using `az login`.

This token is only good for one hour.
If the script takes longer then one hour, you will need to update the `access_token` file.


### Generating a `kusto_connections.xml` file

> This step requires you to already have Kusto Explorer setup and working with the target Kusto Clusters.

1. Go to `Kusto Explorer` and select the `Connections` tab.
2. Fine the `Export Connections` option on the second panel from the left.
3. Save the file to the current directory as `kusto_connections.xml`

As of now, the file name needs to be `kusto_connections.xml`. Later builds will parameter.

Please note that all connections set on the xml file will be attempted in the scrapping.
If you do not want it scrapped, please manually remove it from the file.

### Expected file structure

```text
kus-to-go/
|
|- access_token
|- kusto_connections.xml
|- kus-to-go.ps1
|- README.md
|-...
```

### Run the script

```powershell
.\kus-to-go.ps1
```

### Get the output files

Per cluster, a `.json` file will be created under `$PWD/output_raw`.
This is done to make it easier to prune unneeded cluster metadata.
The downside of this is that the dataset is very segmented.

Using the scripts under `data_manipulation`, we can compile all the smaller files into one monolith file.
To lean more, go to the section on [Data Manipulation`](#data-manipulation)

### Considerations

- Depending on the size of your Kusto environment, this could take some time.
- If the script encounters any 401 errors, it will assume the access token has expired.
  When this occurs, the script will pause and expect you to manually update the file.
  Once done, you can go back to the script and hit `enter` to continue.
  

## Data Manipulation

### `compress.ps1`

This script will compress the raw output JSON into a single JSON array.
It contains a `-filter` parameter that can allow for grainular selections of the raw json data.
