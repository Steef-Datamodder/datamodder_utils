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
