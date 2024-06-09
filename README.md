# CrypQ
### 1. Extracting data from Big Query

Data should be extracted from "bigquery-public-data.crypto_ethereum" using extract.sql

In order to interact with Big Query through the command line, install gcloud CLI here:

https://cloud.google.com/sdk/docs/install

https://cloud.google.com/bigquery/docs/reference/libraries#client-libraries-install-python

Downloads can also be made through their web interface.

A sample data slice is provided here: https://duke.box.com/s/m6ygdkfhfh84b0kxmrkg50paeq1gtdkb

As the structure of bigquery-public-data.crypto_ethereum is periodically updated, we will continuously modify extract.sql to maintain compatibility with the schema defined by CrypQ. As of June 8th, 2024, the schema of bigquery-public-data.crypto_ethereum has changed following the completion of this benchmark. Consequently, the original extraction queries are no longer functional, but updates are forthcoming.

### 2. Post-processing to clean up the extracted data

Create a database called **fix_data**, run the following command:

```
\i /File_Path/Database-Benchmark/fix_data.sql
```
Within the fix_data.sql file, ensure that all paths to the downloaded JSON files have been set correctly

After completing this step, ***fix_data*** database can be deleted

Next, run fix_json.py

### 4. Import data, ready to be queried 

Create a database called ***CrypQ***, run the following command:
```
\i /File_Path/CrypQ/create_db.sql
```
Within the create_db.sql file, ensure that all paths to JSON files are correct

### 5. Update workload

Run the following command to prepare the update workload:
```
\i /File_Path/CrypQ/update_workload/setup_update.sql
```
Depending on whether you want to run an update workload that includes only insertions and updates, or if you prefer the database to undergo changes in a sliding window format, run the appropriate command:
```
\i /File_Path/CrypQ/update_workload/update.sql
```
or
```
\i /File_Path/CrypQ/update_workload/sliding_window_update.sql
```
If you wish to have updates simulated according to original timestamps, basic boilerplate is provided in example_update_usage.py

