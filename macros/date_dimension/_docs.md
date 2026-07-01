# generate

Generates a full date dimension. Use as a model macro — the macro returns SQL that serves directly as the model definition.

```sql
-- models/core/dim_date.sql
{{ generate() }}
```

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `start_date` | string | `'2000-01-01'` | First date in the dimension |
| `end_date` | string | `'2030-12-31'` | Last date in the dimension |
| `fiscal_year_start_month` | int | `1` | First month of the fiscal year (1–12) |
| `public_holidays` | relation | `none` | ref() or source() to the public holidays table (see setup below) |
| `country` | string | `'NL'` | Country code to filter from `public_holidays` |
| `datenames` | relation | `none` | ref() or source() to the date names table (see setup below) |
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
| `weekday` | Day name — only present when `datenames` is configured |
| `weekday_abbr` | Day name abbreviation — only present when `datenames` is configured |
| `is_weekend` | true if Saturday or Sunday |
| `is_workday` | true if not a weekend day and not a holiday |
| `week_nr` | Calendar week (1–53) |
| `iso_week_nr` | ISO 8601 week number |
| `iso_week_year` | Year of the ISO week |
| `iso_week_label` | E.g. `2024-W03` |
| `month_nr` | Month number (1–12) |
| `month_name` | Month name — only present when `datenames` is configured |
| `month_abbr` | Month name abbreviation — only present when `datenames` is configured |
| `month_label` | E.g. `2024-03` |
| `quarter` | Quarter (1–4) |
| `quarter_label` | E.g. `2024-Q1` |
| `year` | Year |
| `fiscal_year` | Fiscal year based on `fiscal_year_start_month` |
| `fiscal_month_nr` | Fiscal month (1–12) |
| `fiscal_quarter` | Fiscal quarter (1–4) |
| `fiscal_quarter_label` | E.g. `FY2024-Q2` |
| `is_holiday` | true if a public holiday for the configured country |
| `holiday_name` | Name of the holiday |
| `is_school_holiday` | true if school holiday (only when relation provided) |
| `school_holiday_name` | Name of the school holiday |

---

## Language

Set via dbt variable `dim_date_language` (default `nl`):

```yaml
# dbt_project.yml
vars:
  dim_date_language: en
```

The language code is used to filter the `datenames` table. Supported values:

| Code | Language | Example weekday | Example month |
|---|---|---|---|
| `nl` | Dutch | maandag / ma | januari / jan |
| `en` | English | Monday / Mo | January / Jan |
| `de` | German | Montag / Mo | Januar / Jan |
| `fr` | French | lundi / lun | janvier / jan |
| `es` | Spanish | lunes / lun | enero / ene |
| `pt` | Portuguese | segunda-feira / seg | janeiro / jan |
| `it` | Italian | lunedì / lun | gennaio / gen |
| `pl` | Polish | poniedziałek / pon | styczeń / sty |

---

## Setup

Run `setup.sql` once to create both lookup tables. Adjust `db` and `sch` at the top of the file to match your Snowflake environment. The script creates the database and schema if they don't exist and uses `CREATE OR REPLACE` throughout, so it is safe to re-run.

The script creates two tables:

- `datamodder.utils.holidays` — public holidays for NL, BE, DE, FR, GB, ES, IT, PT (years 2000–2100)
- `datamodder.utils.datenames` — weekday and month names and abbreviations for 8 languages

Configure defaults via `dbt_project.yml`:

```yaml
vars:
  dim_date_public_holidays_table: "datamodder.utils.holidays"
  dim_date_country: 'NL'
  dim_date_datenames_table: "datamodder.utils.datenames"
  dim_date_language: nl
```

Or pass tables directly per model:

```sql
{{ generate(
       public_holidays=source('utils', 'holidays'),
       country='DE',
       datenames=source('utils', 'datenames')) }}
```

When `public_holidays` is not configured, `is_holiday` is always `false` and `holiday_name` is `null`.
When `datenames` is not configured, the `weekday`, `weekday_abbr`, `month_name` and `month_abbr` columns are not included in the output.

## Date names

The `datenames` table has the following schema:

| Column | Type | Description |
|---|---|---|
| `language` | varchar(2) | Language code (`nl`, `en`, `de`, `fr`, `es`, `pt`, `it`, `pl`) |
| `type` | varchar(7) | `weekday` (1–7, Mon–Sun) or `month` (1–12) |
| `nr` | integer | ISO weekday number or month number |
| `name` | varchar | Full name |
| `abbr` | varchar | Abbreviated name |

## Public holidays

### Holidays per country

**NL** — [rijksoverheid.nl/onderwerpen/feestdagen](https://www.rijksoverheid.nl/onderwerpen/feestdagen)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| Easter −2 | Good Friday |
| Easter | Easter Sunday |
| Easter +1 | Easter Monday |
| 27 Apr (→ 26 if Sunday) | King's Day |
| 5 May | Liberation Day |
| Easter +39 | Ascension Day |
| Easter +49 | Whit Sunday |
| Easter +50 | Whit Monday |
| 25 Dec | Christmas Day |
| 26 Dec | Boxing Day |

**BE** — [belgium.be/nl/werk/feestdagen](https://www.belgium.be/nl/werk/feestdagen)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| Easter | Easter Sunday |
| Easter +1 | Easter Monday |
| 1 May | Labour Day |
| Easter +39 | Ascension Day |
| Easter +49 | Whit Sunday |
| Easter +50 | Whit Monday |
| 21 Jul | Belgian National Day |
| 15 Aug | Assumption |
| 1 Nov | All Saints' Day |
| 11 Nov | Armistice Day |
| 25 Dec | Christmas Day |

**DE** — [bmi.bund.de — Nationale Feiertage](https://www.bmi.bund.de/DE/themen/verfassung/staatliche-symbole/nationale-feiertage/nationale-feiertage-node.html)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| Easter −2 | Good Friday |
| Easter | Easter Sunday |
| Easter +1 | Easter Monday |
| 1 May | Labour Day |
| Easter +39 | Ascension Day |
| Easter +49 | Whit Sunday |
| Easter +50 | Whit Monday |
| 3 Oct | German Unity Day |
| 25 Dec | Christmas Day |
| 26 Dec | Boxing Day |

> State-specific holidays (e.g. Epiphany in Bavaria, Reformation Day in Protestant states) are not included.

**FR** — [service-public.fr — Jours fériés](https://www.service-public.fr/particuliers/vosdroits/F2405)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| Easter +1 | Easter Monday |
| 1 May | Labour Day |
| 8 May | Victory in Europe Day |
| Easter +39 | Ascension Day |
| Easter +50 | Whit Monday |
| 14 Jul | Bastille Day |
| 15 Aug | Assumption |
| 1 Nov | All Saints' Day |
| 11 Nov | Armistice Day |
| 25 Dec | Christmas Day |

**GB** — [gov.uk/bank-holidays](https://www.gov.uk/bank-holidays)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| Easter −2 | Good Friday |
| Easter +1 | Easter Monday |
| First Mon of May | Early May Bank Holiday |
| Last Mon of May | Spring Bank Holiday |
| Last Mon of Aug | Summer Bank Holiday |
| 25 Dec | Christmas Day |
| 26 Dec | Boxing Day |

> Scotland and Northern Ireland have different bank holidays; this table covers England and Wales.

**ES** — [administracion.gob.es — Fiestas laborales nacionales](https://administracion.gob.es/pag_Home/atencionCiudadana/calendarios/fiestas-laborales-nacionales.html)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| 6 Jan | Epiphany |
| Easter −2 | Good Friday |
| 1 May | Labour Day |
| 15 Aug | Assumption |
| 12 Oct | National Day |
| 1 Nov | All Saints' Day |
| 6 Dec | Constitution Day |
| 8 Dec | Immaculate Conception |
| 25 Dec | Christmas Day |

**IT** — [governo.it — Giorni festivi](https://www.governo.it/it/approfondimento/giorni-festivi)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| 6 Jan | Epiphany |
| Easter | Easter Sunday |
| Easter +1 | Easter Monday |
| 25 Apr | Liberation Day |
| 1 May | Labour Day |
| 2 Jun | Republic Day |
| 15 Aug | Assumption |
| 1 Nov | All Saints' Day |
| 8 Dec | Immaculate Conception |
| 25 Dec | Christmas Day |
| 26 Dec | St. Stephen's Day |

**PT** — [eportugal.gov.pt — Feriados obrigatórios](https://eportugal.gov.pt/servicos/consultar-calendario-de-feriados-obrigatorios-em-portugal)

| Date | Holiday |
|---|---|
| 1 Jan | New Year's Day |
| Easter −2 | Good Friday |
| Easter | Easter Sunday |
| 25 Apr | Freedom Day |
| 1 May | Labour Day |
| Easter +60 | Corpus Christi |
| 10 Jun | Portugal Day |
| 15 Aug | Assumption |
| 5 Oct | Republic Day |
| 1 Nov | All Saints' Day |
| 1 Dec | Restoration of Independence |
| 8 Dec | Immaculate Conception |
| 25 Dec | Christmas Day |

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
{{ generate(
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
dbt run-operation do_test
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
