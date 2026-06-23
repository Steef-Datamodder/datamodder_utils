# Management macros

**Files:** `log_dbt_start.sql`, `log_dbt_end.sql`

Log the start and end of a dbt run to a Snowflake table. Typically called from
`on-run-start` and `on-run-end` hooks in `dbt_project.yml`:

```yaml
on-run-start:
  - "{{ log_dbt_start() }}"
on-run-end:
  - "{{ log_dbt_end() }}"
```

The target table is `target.database.<schema>.<table>`, configurable via `management_config`
in `dbt_project.yml`:

```yaml
vars:
  management_config:
    schema: datamodder     # default
    table:  runtimes       # default
```

The table must already exist with at least the following columns:

```sql
CREATE TABLE <database>.<schema>.<table> (
    invocation_id  TEXT,
    project_name   TEXT,
    target_name    TEXT,
    run_started_at TIMESTAMP_TZ,
    run_ended_at   TIMESTAMP_TZ,
    stat           TEXT
);
```
