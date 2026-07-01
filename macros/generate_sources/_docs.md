# generate_sources

Macros for generating source files and dbt configuration from Snowflake metadata.

---

## generate_source_yaml

Generates `sources.yml` content. Copy the console output to `models/staging/sources/`.

```bash
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data"}'
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `database` | string | — | Snowflake database (required) |
| `schemas` | string or list | `none` (= all) | Filter on one or more schemas |
| `split` | boolean | `true` | `true` → one block per schema with file path as comment; `false` → single combined YAML |

### Examples

```bash
# All schemas, split per file
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data"}'

# Single schema
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": "tpch_sf1"}'

# Multiple schemas
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1", "tpch_sf10"]}'

# Everything in one file
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "split": false}'
```

---

## generate_staging_models

Generates a boilerplate staging model for each table in the database: a `select * from {{ source(...) }}` query, preceded by a comment line with the suggested file path. Copy each block to the corresponding `.sql` file under `models/staging/`.

```bash
dbt run-operation generate_staging_models --args '{"database": "snowflake_sample_data", "schemas": "tpch_sf1"}'
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `database` | string | — | Snowflake database (required) |
| `schemas` | string or list | `none` (= all) | Filter on one or more schemas |

### Example output

```sql
-- === models/staging/tpch_sf1/customer.sql ===
select * from {{ source('tpch_sf1', 'customer') }}

-- === models/staging/tpch_sf1/orders.sql ===
select * from {{ source('tpch_sf1', 'orders') }}
```

---

## generate_dbt_project_snippet

Outputs the block to paste under `models:` in `dbt_project.yml`.

```bash
dbt run-operation generate_dbt_project_snippet --args '{"database": "snowflake_sample_data"}'
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `database` | string | — | Snowflake database (required) |
| `schemas` | string or list | `none` (= all) | Filter on one or more schemas |

### Example output

```yaml
    staging:
      tpch_sf1:
        +enabled: false
      tpch_sf10:
        +enabled: false
```
