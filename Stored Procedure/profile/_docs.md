# profile

Snowflake stored procedure that automatically scans a schema for personal data (PII) based on configurable regex rules.

---

## Required objects

The following tables must exist in `UTILS_DATABASE.UTILS_SCHEMA` (default: the database/schema where the procedure resides) before running the procedure:

### PII_REGEX_RULES

Configuration table with detection rules. Add rows here to support new PII types — no code changes required.

```sql
CREATE TABLE PII_REGEX_RULES (
    pii_type               TEXT,     -- e.g. 'BSN', 'EMAIL', 'NAME'
    rule_name              TEXT,     -- unique name within pii_type
    column_name_regex      TEXT,     -- regex on column name (null = skip)
    value_regex            TEXT,     -- regex on column content (null = skip)
    data_type_regex        TEXT,     -- filter on Snowflake data type, e.g. 'TEXT|VARCHAR' (null = all types)
    confidence_name_match  FLOAT,    -- score (0.0–1.0) on column name match
    confidence_value_match FLOAT,    -- score (0.0–1.0) on value match
    suggested_action       TEXT,     -- e.g. 'mask', 'delete'
    is_active              BOOLEAN   -- false = rule skipped
);
```

**Detection logic per rule:**
- If `column_name_regex` matches → name hit
- If `value_regex` matches on ≥ `MATCH_THRESHOLD` of samples → value hit
- If `data_type_regex` does not match → column skipped for this rule
- A column is recorded as a finding as soon as a name hit **or** value hit applies

**Confidence calculation:**
`min(confidence_name_match + confidence_value_match, 1.0)` — both signals are summed. Name match only: `confidence_name_match`. Value match only: `confidence_value_match`. Both: sum, clipped to 1.0.

**Example rows:**

| pii_type | rule_name | column_name_regex | value_regex | data_type_regex | confidence_name_match | confidence_value_match | suggested_action | is_active |
|---|---|---|---|---|---|---|---|---|
| BSN | bsn_name | `(^|_)(bsn|sofi)(\_|$)` | null | `TEXT\|VARCHAR` | 0.8 | null | mask | true |
| BSN | bsn_value | null | `^\d{9}$` | `TEXT\|VARCHAR\|NUMBER` | null | 0.7 | mask | true |
| EMAIL | email_name | `email` | null | null | 0.9 | null | mask | true |
| EMAIL | email_value | null | `^[^@]+@[^@]+\.[^@]+$` | `TEXT\|VARCHAR` | null | 0.85 | mask | true |
| NAME | name_column | `(^|_)(naam\|name\|first_name\|last_name)(\_\|$)` | null | null | 0.6 | null | pseudonymise | true |

### PII_SCAN_RESULTS

Result table — must exist before the first call.

```sql
CREATE TABLE PII_SCAN_RESULTS (
    scan_id              TEXT,
    scanned_at           TIMESTAMP_TZ,
    database_name        TEXT,
    schema_name          TEXT,
    table_name           TEXT,
    column_name          TEXT,
    data_type            TEXT,
    pii_type             TEXT,
    rule_name            TEXT,
    confidence           FLOAT,
    detection_reason     TEXT,
    matched_sample_count NUMBER,
    sample_size          NUMBER,
    suggested_action     TEXT
);
```

---

## Calling the procedure

```sql
-- Minimal
CALL DATAMODDER_UTILS.PROFILE_PII('MY_DATABASE', 'MY_SCHEMA', 1000);

-- With threshold and custom utils schema
CALL DATAMODDER_UTILS.PROFILE_PII(
    'MY_DATABASE',
    'MY_SCHEMA',
    500,
    0.05,                  -- match_threshold: 5% of samples must match
    'UTILS_DB',
    'DATAMODDER'
);
```

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `DATABASE_NAME` | string | — | Database to scan (required) |
| `SCHEMA_NAME` | string | — | Schema to scan (required) |
| `SAMPLE_ROWS` | number | — | Number of rows per column for value scan (0 → 1000) |
| `MATCH_THRESHOLD` | float | `0.1` | Minimum fraction of samples that must match the regex (0.0–1.0) |
| `UTILS_DATABASE` | string | current database | Database containing `PII_REGEX_RULES` and `PII_SCAN_RESULTS` |
| `UTILS_SCHEMA` | string | current schema | Schema containing `PII_REGEX_RULES` and `PII_SCAN_RESULTS` |

---

## Return value

The procedure returns a `VARIANT` with a scan summary:

```json
{
    "scan_id":         "a1b2c3d4-...",
    "database_name":   "MY_DATABASE",
    "schema_name":     "MY_SCHEMA",
    "sample_rows":     1000,
    "match_threshold": 0.1,
    "scanned_columns": 142,
    "findings":        7
}
```

Full details are available in `PII_SCAN_RESULTS` filtered on `scan_id`.

---

## How it works

### Step 1 — candidate list

A single query cross-joins `information_schema.columns` with `PII_REGEX_RULES`. Snowflake evaluates directly:
- **type filter** (`data_type_regex`): columns whose data type does not match are filtered out
- **name check** (`column_name_regex`): result is returned as `name_matched` column

Python receives only the (column, rule) combinations that passed the type filter. This replaces N×M separate round trips with a single query.

Only base tables are scanned — views are skipped.

### Step 2 — value scans

For each candidate with a `value_regex`, a sample is drawn:

```sql
SELECT count(*) AS sample_size
     , count_if(regexp_like(to_varchar(<column>), <regex>, 'i')) AS matched_count
  FROM (
      SELECT <column> FROM <table> WHERE <column> IS NOT NULL LIMIT <sample_rows>
  )
```

`match_ratio = matched_count / sample_size`. If `match_ratio >= MATCH_THRESHOLD` → value hit.

> **Note:** `LIMIT` pulls the first N rows in storage order, not a statistical sample. Sorted or clustered tables may give a skewed result. Use a higher `SAMPLE_ROWS` for better reliability.

### Step 3 — save results

Findings are inserted one by one into `PII_SCAN_RESULTS`. Columns with no hit are not stored.

---

## Querying results

```sql
-- Most recent scan
SELECT *
  FROM DATAMODDER_UTILS.PII_SCAN_RESULTS
 WHERE scan_id = (SELECT max(scan_id) FROM DATAMODDER_UTILS.PII_SCAN_RESULTS)
 ORDER BY confidence DESC, table_name, column_name;

-- All high-confidence findings
SELECT table_name, column_name, pii_type, confidence, suggested_action
  FROM DATAMODDER_UTILS.PII_SCAN_RESULTS
 WHERE confidence >= 0.8
 ORDER BY confidence DESC;

-- Summary per PII type
SELECT pii_type, count(*) AS column_count
  FROM DATAMODDER_UTILS.PII_SCAN_RESULTS
 WHERE scan_id = '<scan_id>'
 GROUP BY pii_type
 ORDER BY column_count DESC;
```

---

## Tips

- Set `MATCH_THRESHOLD` lower (e.g. `0.02`) for sensitive scans where over-reporting is preferred.
- Set `MATCH_THRESHOLD` higher (e.g. `0.5`) to only flag columns where the majority of values are PII.
- Temporarily disable rules via `is_active = false` in `PII_REGEX_RULES` without deleting them.
- Run the same schema multiple times with different thresholds and compare via `scan_id`.
