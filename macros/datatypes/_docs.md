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

---

## Testing

```bash
dbt run-operation do_test_uniform_datatypes
```

Creates a test table with one column of each supported type, applies the macro, and logs pass/fail per assertion:

| Assertion | What is checked |
|---|---|
| excluded column unchanged | `id` (integer) passed through as-is |
| varchar → text | value preserved after `::text` |
| number → decimal | `42.5` → `42.5000` via `try_to_decimal` |
| timestamp_ntz → timestamp_tz | date part preserved after cast |
| time → timestamp_tz, anchor date | date part of result equals `2000-01-01` |
| time → timestamp_tz, time value | time part of result equals `14:30:00` |
| boolean unchanged | boolean passed through as-is |
