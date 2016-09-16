## Description
Ruby program to help interacting with the Nessus 6 API. Currently only supports downloading the most recent scan file in CSV format for all scans in a folder.

### Setup environment variables
```
export NESSUS_HOST=<the hostname>
export NESSUS_ACCESS_KEY=<your access key>
export NESSUS_SECRET_KEY=<your secret key>
```

### Example Usage
```
Usage:
  nessus-api-helper.rb [options]

Examples:

  Find JIRA issue by key and display
    nessus-api-helper.rb -p 8834 -f 3

Options:
    -d, --directory DIR              Where to put the downloaded files
    -p, --port PORT                  Port the Nessus server is running on
    -f, --folder ID                  Nessus "folder id" (integer) to search for scans
    -l, --last_modified HH:MM        Time since a scan was last modified, can be any string that DateTime.parse will accept
    -v, --verbose                    Show things like risk level in the output
```

```
ruby nessus-api-helper.rb -p 8834 -f 3 -l "00:00" -d scan_results
```
