# Timestamp macro set

All macros read their configuration via `_timestamp_config()` in `_config.sql`
and their pattern data via `_data()` in `_data.sql`.

---

## to_timestamp

**File:** `to_timestamp.sql`  
**Signature:** `{{ to_timestamp(value_expr, timezone="'UTC'") }}`

Tries a comprehensive set of date and time formats and returns the first
successful parse as `timestamp_tz` or `timestamp_ntz`, depending on `output_type`
in `_config.sql`.

**Evaluation order:**

1. Compact numeric formats (`YYYYMMDD`, `YYYYMMDDHH24MISS`) — if `compact` or `sap` is active.
   First, so Snowflake's auto-detect does not read them as Unix epoch.
2. Two-digit year formats (`DD-MM-YY`, `MM/DD/YY`, `DD-MON-YY`, …) — if `two_digit_years` is active.
   Before the YYYY formats, otherwise e.g. `14-06-26` would be parsed as year 14.
3. Snowflake native auto-detection (`try_to_timestamp_tz`).
4. Explicit formats per active format_group, in config order, deduplicated.
5. ISO 8601 T-separator and Z-suffix preprocessing — if `iso` or an ISO-producing
   provider group is active.
6. Steps 2–5 repeated after weekday stripping via `fix_weekdays`
   (e.g. `"Wednesday 15-03-2024"` → `"15-03-2024"`).
7. Named-month formats (after `fix_weekdays` + `fix_months`),
   always tried when at least one language is configured.

---

## _config

**File:** `_config.sql`

Central configuration for the entire macro set. Edit the `defaults` dict directly
in this file, or override per environment via `dbt_project.yml`:

```yaml
vars:
  timestamp_config:
    languages:
      - dutch
      - english
    format_groups:
      - iso
      - european
      - oracle
    two_digit_years: true
    abbreviations:   true
    output_type:     ntz
    test_schema:     datamodder
```

### languages

Controls which month-name and weekday-name patterns are recognised and in what
priority order. The first language in the list wins when patterns overlap.

Available: `english` · `dutch` · `french` · `german` · `spanish` · `portuguese`
· `polish` · `danish` · `swedish` · `norwegian` · `finnish` · `hindi` · `japanese`

### format_groups

Controls which date/time format families `to_timestamp` attempts.
Human-language names and database-provider names may be mixed freely.
Duplicate format strings across groups are deduplicated automatically.

**Generic groups:**

| Name       | Description |
|------------|-------------|
| `iso`      | `YYYY-MM-DD …` (also `/` and `.`, T-variant, Z-suffix) |
| `european` | `DD-MM-YYYY …` (also `/` and `.`) |
| `us`       | `MM-DD-YYYY …` (also `/` and `.`) |
| `compact`  | `YYYYMMDD`, `YYYYMMDDHH24MISS` |

**Database provider groups** (activates typical export formats for that vendor):

| Name         | Description |
|--------------|-------------|
| `oracle`     | `DD-MON-RR`, `YYYY-MM-DD HH24:MI:SS.FF6`, and related |
| `mssql`      | `MM/DD/YYYY`, `MON DD YYYY HH12:MIAM`, style-109 variant |
| `postgresql` | ISO 8601 (equivalent to `iso`) |
| `mysql`      | `YYYY-MM-DD HH:MI:SS` (subset of `iso`) |
| `sap`        | `YYYYMMDD` (equivalent to `compact`) |

### two_digit_years

When `true`: adds YY variants for the active generic groups
(e.g. `DD-MM-YY`, `MM/DD/YY`). Has no effect on provider groups.

### abbreviations

When `true`: adds language-agnostic month abbreviations (`jan.`, `feb.`, …)
at the end of the match list in `fix_months`.

### output_type

Controls the return type of `to_timestamp`.

| Value  | Type            | Behaviour |
|--------|-----------------|-----------|
| `'tz'` | `timestamp_tz`  | Timezone offset preserved |
| `'ntz'`| `timestamp_ntz` | Offset stripped; local time kept as-is |

### test_schema

Schema in which `create_test` creates the test table. Default: `datamodder`.
Useful to use a different schema per environment (e.g. `dev_datamodder`).

---

## fix_weekdays

**File:** `fix_weekdays.sql`  
**Signature:** `{{ fix_weekdays(value_expr) }}`

Removes a leading weekday name (plus any trailing comma, period, or whitespace
separator) so the remainder can be parsed as a date.
Always returns `lower(trim(value_expr))`.

**Examples:**

```
'woensdag 15 maart 2024'    →  '15 maart 2024'
'Wednesday, 15 March 2024'  →  '15 march 2024'
'lundi 03/06/2024'          →  '03/06/2024'
'Donnerstag, 15.03.2024'    →  '15.03.2024'
'15-03-2024'                →  '15-03-2024'   (no weekday — unchanged)
```

**Behaviour:**

- Input is lowercased and trimmed before matching.
- Only leading weekday names are stripped (anchored to start of string).
- Full weekday names only — abbreviations are intentionally excluded to avoid
  false matches with month abbreviations (e.g. French `mar.` = Mardi and March).
- Pattern priority follows the language order from `_config`.
- Active languages and pattern data are loaded from `_data`.

---

## fix_months

**File:** `fix_months.sql`  
**Signature:** `{{ fix_months(value_expr) }}`

Normalises written-out month names to 3-letter English abbreviations that
Snowflake accepts: `jan` · `feb` · `mar` · `apr` · `may` · `jun` · `jul`
· `aug` · `sep` · `oct` · `nov` · `dec`.

**Behaviour:**

- Input is lowercased and trimmed before matching.
- Word boundaries (`\b`) prevent partial-word collisions.
- Accented forms and ASCII transliterations are both matched
  (e.g. Polish `ń ↔ n`, `ź ↔ z`; Finnish `ä ↔ a`; French `é ↔ e`).
- Japanese: numbered-month romaji (`ichigatsu … jūnigatsu`).
  Both macron (`ū`) and double-u (`uu`) spellings are accepted.
- Hindi: common Devanagari-to-Latin transliterations.
- Language-specific abbreviations (`janv.`, `mrz.`, …) are only included
  when that language is active.
- Universal abbreviations (`jan.`, `feb.`, …) are controlled separately
  by the `abbreviations` config flag.
- Pattern order within each month follows the language priority from `_config`.

---

## _data

**File:** `_data.sql`

Central data store for the entire macro set. Used by `fix_months`,
`fix_weekdays`, and `create_test`.

To add a language: add entries to `months[]` and `weekdays[]` in this file.
The logic macros (`fix_months`, `fix_weekdays`) need no changes.

**Data structure:**

```
months[]
  out  — 3-letter English abbreviation Snowflake accepts (jan … dec)
  rx[] — patterns, longest/most-specific first
    p  — regex pattern (applied after lower/trim)
    l  — languages this pattern belongs to; [] = universal abbreviation

weekdays[]
  rx[] — patterns, longest/most-specific first
    p  — regex pattern (applied after lower/trim)
    l  — languages this pattern belongs to
  (No 'out' — weekday names are stripped, not normalised.)

test_values[]
  Flat list of date strings covering all active format_groups and languages
  across five reference dates:
    • 2026-06-14 16:00:00  (last week, 16:00 — Sunday)
    • 2024-02-29 11:00:00  (last leap day, 11:00 — Thursday)
    • 2024-02-29 23:00:00  (last leap day, 23:00 — Thursday)
    • 1936-01-01 23:00:00  (1 Jan 1936, 23:00 — Wednesday)
    • 1905-01-01            (1 Jan 1905 — Sunday)
```

**Notes:**

- Longer/more-specific patterns come before shorter ones so the regex alternation
  tries them first (e.g. `segunda-feira` before `segunda`).
- Weekday abbreviations are intentionally omitted to avoid false matches with
  month abbreviations (e.g. French `mar.` = Mardi and March).

---

## Testing

**Files:** `create_test.sql`, `do_test.sql`

```
dbt run-operation create_test --project-dir XXXXX
dbt run-operation do_test     --project-dir XXXXX
```

`create_test` — creates `<test_schema>.test_to_timestamp` with all test values
from `_data().test_values`. The `converted` column remains empty until `do_test` is run.

`do_test` — populates `converted` via `to_timestamp('testval')::text` and logs a
summary: number passed/total, and for failures the row IDs and input values of the NULLs.

### Required Snowflake privileges

`create_test` executes `CREATE SCHEMA IF NOT EXISTS` and `CREATE OR REPLACE TABLE`.
The dbt role needs the following privileges:

```sql
-- Grant the right to create a schema in the database
GRANT CREATE SCHEMA ON DATABASE <database> TO ROLE <dbt_role>;

-- Grant the right to create tables in the schema (after the schema exists)
GRANT CREATE TABLE ON SCHEMA <database>.<test_schema> TO ROLE <dbt_role>;
```

Or grant schema ownership (automatically covers all schema-level privileges):

```sql
GRANT OWNERSHIP ON SCHEMA <database>.<test_schema> TO ROLE <dbt_role>;
```

Replace `<database>` with the value of `target.database` from your dbt profile,
`<test_schema>` with the configured value (default `datamodder`),
and `<dbt_role>` with the role dbt uses.

---

> **Note:** wherever `XXXXX` appears, replace it with the name of your dbt project directory
> (the directory containing `dbt_project.yml`, passed as `--project-dir`).

