# uniform_datatypes

Generates a SELECT that casts all columns to uniform data types. Use as a model macro.

```sql
-- models/staging/stg_orders.sql
{{ uniform_datatypes(ref('raw_orders')) }}
```

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `relation` | relation | — | ref() or source() pointing to the source table (required) |
| `integer_digits` | int | `18` (via `_config.sql`) | Max digits before the decimal point |
| `decimal_digits` | int | `4` (via `_config.sql`) | Max digits after the decimal point |
| `exclude_columns` | list | `[]` | Column names to pass through unchanged |

---

## Conversions

| Source type | Target type | Function |
|---|---|---|
| TEXT, VARCHAR, CHAR, … | `TEXT` | `::text` |
| NUMBER, INT, FLOAT, … | `DECIMAL(precision, scale)` | `try_to_decimal()` |
| DATE, TIMESTAMP_NTZ, TIMESTAMP_LTZ, TIMESTAMP_TZ | `TIMESTAMP_TZ` | `try_to_timestamp_tz()` |
| TIME | `TIMESTAMP_TZ` | `try_to_timestamp_tz('2000-01-01 ' \|\| col, …)` |
| BOOLEAN, VARIANT, other | unchanged | — |

Invalid values return `NULL` (no error).

> **TIME anchor date:** `2000-01-01` is used as anchor for TIME columns. This avoids both the Excel leap year bug (1900) and the Dutch timezone shift of 17 May 1937 (Amsterdam Mean Time → CET).

---

## Examples

```sql
-- Default
{{ uniform_datatypes(ref('raw_orders')) }}

-- Custom precision
{{ uniform_datatypes(source('raw', 'orders'), integer_digits=15, decimal_digits=2) }}

-- Exclude columns
{{ uniform_datatypes(ref('raw_orders'), exclude_columns=['id', 'record_hash']) }}
```

Override defaults via `dbt_project.yml`:

```yaml
vars:
  uniform_datatypes_integer_digits: 15
  uniform_datatypes_decimal_digits: 2
```
