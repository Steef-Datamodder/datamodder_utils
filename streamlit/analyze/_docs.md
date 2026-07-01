# Analyze

Frontend for the Snowflake stored procedures in `datamodder.analyze`. Creates and manages point-in-time (PIT) snapshots of source tables and computes column-level statistics.

## Starting the app

```
streamlit\analyze\start.cmd
```

Or manually (from the repo root with the venv active):

```
streamlit run streamlit\analyze\app.py
```

## Connection

Enter your Snowflake account identifier, username and password in the sidebar and click **Connect**. Credentials are saved between sessions: account and username in `~/.streamlit_sources.json`, password in Windows Credential Manager (via the `keyring` package).

After connecting, select a warehouse and role from the dropdowns. Changing either immediately executes `USE WAREHOUSE` / `USE ROLE` on the active connection.

## Target

Configure where PIT snapshots and statistics are stored. Defaults match the standard `datamodder_utils` setup:

| Field | Default | Description |
|---|---|---|
| Database | `datamodder` | Snowflake database that holds the analyze schemas |
| PIT schema | `analyze` | Schema where PIT snapshot tables are created |
| Agg schema | `analyzer_agg` | Schema where the `statistics` aggregation table lives |

## Source

Select the source database, schema, and table for which to create a PIT snapshot. Schemas and tables are loaded from Snowflake on demand and cached for the session.

## Actions

| Button | Stored procedure | Description |
|---|---|---|
| **Create PIT** | `create_pit(db, schema, table)` | Creates a snapshot table named `{TABLE}_{YYYYMMDD}_{HH24MISS}` in the PIT schema |
| **Register PITs** | `register_pits()` | Scans the PIT schema and registers all snapshot tables in the metadata |
| **Update statistics** | `update_statistics()` | Computes column-level statistics for all registered PITs |

The stored procedures require three Snowflake session variables (`$target_db_name`, `$pit_schema_name`, `$agg_schema_name`). The app sets these automatically before each call.

## PIT list and statistics

After connecting, the app queries the PIT schema for all tables matching the `{NAME}_{YYYYMMDD}_{HH24MISS}` pattern and lists them newest first. Select a PIT to view its column statistics.

Statistics are read from `{target_db}.{agg_schema}.statistics`. Column highlights:

- **null_count** — yellow background if > 0
- **under_min_count** / **above_max_count** — red background if > 0

Use **Refresh PIT list** and **Refresh statistics** to clear the cache and reload from Snowflake.

## Dependencies

```
pip install streamlit snowflake-connector-python keyring pandas
```

See `requirements.txt` for pinned versions. The stored procedures must be deployed first — see `stored procedure/analyze/setup.sql`.
