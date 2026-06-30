# generate_date_dimension

Generates a full date dimension. Use as a model macro — the macro returns SQL that serves directly as the model definition.

```sql
-- models/core/dim_date.sql
{{ generate_date_dimension() }}
```

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `start_date` | string | `'2000-01-01'` | First date in the dimension |
| `end_date` | string | `'2030-12-31'` | Last date in the dimension |
| `fiscal_year_start_month` | int | `1` | First month of the fiscal year (1–12) |
| `school_holidays` | relation | `none` | ref() or source() to a school holidays table |
| `school_holiday_country` | string | `none` | Filter on country (e.g. `'NL'`) |
| `school_holiday_region` | string | `none` | Filter on region (e.g. `'Noord'`) |

---

## Generated columns

| Column | Description |
|---|---|
| `date` | Date |
| `date_key` | Surrogate key (YYYYMMDD) |
| `day_nr` | Day of the month (1–31) |
| `day_of_year` | Day of the year (1–366) |
| `day_of_week_nr` | ISO weekday number (1 = Mon, 7 = Sun) |
| `weekday` | Day name (language-dependent) |
| `weekday_abbr` | Day name abbreviation |
| `is_weekend` | true if Saturday or Sunday |
| `is_workday` | true if not a weekend day and not a holiday |
| `week_nr` | Calendar week (1–53) |
| `iso_week_nr` | ISO 8601 week number |
| `iso_week_year` | Year of the ISO week |
| `iso_week_label` | E.g. `2024-W03` |
| `month_nr` | Month number (1–12) |
| `month_name` | Month name (language-dependent) |
| `month_abbr` | Month name abbreviation |
| `month_label` | E.g. `2024-03` |
| `quarter` | Quarter (1–4) |
| `quarter_label` | E.g. `2024-Q1` |
| `year` | Year |
| `fiscal_year` | Fiscal year based on `fiscal_year_start_month` |
| `fiscal_month_nr` | Fiscal month (1–12) |
| `fiscal_quarter` | Fiscal quarter (1–4) |
| `fiscal_quarter_label` | E.g. `FY2024-Q2` |
| `is_holiday` | true if Dutch public holiday |
| `holiday_name` | Name of the holiday |
| `is_school_holiday` | true if school holiday (only when relation provided) |
| `school_holiday_name` | Name of the school holiday |

---

## Language

Set via dbt variable `dim_date_language` (default `nl`, `en` also supported):

```yaml
# dbt_project.yml
vars:
  dim_date_language: en
```

---

## School holidays

The macro expects a table with the following schema:

| Column | Type | Description |
|---|---|---|
| `start_date` | date | First day of holiday |
| `end_date` | date | Last day of holiday |
| `holiday_name` | text | E.g. `'Summer Holiday'` |
| `country` | text | `'NL'`, `'BE'`, `'DE'`, `'GB'`, `'FR'`, `'US'` |
| `region` | text | E.g. `'Noord'`, `'Zone A'`, `'Bayern'` (null = all regions) |

Data sources per country:

| Country | Source | Structure |
|---|---|---|
| NL | rijksoverheid.nl/onderwerpen/schoolvakanties | 3 regions: Noord / Midden / Zuid |
| BE | onderwijs.vlaanderen.be / enseignement.be | 3 communities: NL / FR / DE |
| DE | kmk.org/service/schulferien | 16 Bundesländer |
| GB | gov.uk/school-term-and-holiday-dates | Per local authority — no central source |
| FR | education.gouv.fr/calendrier-scolaire | 3 zones: A / B / C |
| US | No central source | Per school district |

Configure defaults via `dbt_project.yml`:

```yaml
vars:
  dim_date_school_holidays_table: "ref('school_holidays')"
  dim_date_school_holiday_country: 'NL'
  dim_date_school_holiday_region: 'Noord'
```

---

## Extended example

```sql
{{ generate_date_dimension(
       start_date='2015-01-01',
       end_date='2040-12-31',
       fiscal_year_start_month=4,
       school_holidays=ref('school_holidays'),
       school_holiday_country='NL',
       school_holiday_region='Noord') }}
```

---

## Testing

```bash
dbt run-operation do_test_date_dimension
```

Creates two date dimension tables (2024–2026 with default settings, 2024 with `fiscal_year_start_month=4`) and logs pass/fail per assertion:

| Assertion | What is checked |
|---|---|
| date_key | 2024-01-15 → `20240115` |
| day_of_week_nr | 2024-01-01 (Monday) = `1` |
| is_weekend | 2024-01-06 (Saturday) = `true` |
| iso_week_label | 2024-01-08 = `'2024-W02'` |
| is_holiday — Easter Sunday | 2024-03-31 = `true` |
| holiday_name — Easter Sunday | 2024-03-31 = `'Easter Sunday'` |
| is_holiday — Easter Monday | 2024-04-01 = `true` |
| King's Day moved to April 26 | 2025-04-26 = `true` (April 27 is Sunday in 2025) |
| April 27 no longer a holiday | 2025-04-27 = `false` |
| holiday_name — Christmas | 2024-12-25 = `'Christmas Day'` |
| is_workday — public holiday | 2024-01-01 (New Year's Day) = `false` |
| is_workday — regular weekday | 2024-01-02 (Tuesday) = `true` |
| fiscal_year before start month | 2024-03-31 with `start_month=4` → `2023` |
| fiscal_year after start month | 2024-04-01 with `start_month=4` → `2024` |
| fiscal_month_nr at year start | 2024-04-01 with `start_month=4` → `1` |
| fiscal_quarter (months 1–3) | 2024-06-30 with `start_month=4` → `1` |
