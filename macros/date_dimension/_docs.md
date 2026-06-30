# generate_date_dimension

Genereert een volledige datum-dimensie. Gebruik als model-macro: de macro retourneert SQL dat direct als modeldefinitie dient.

```sql
-- models/core/dim_datum.sql
{{ generate_date_dimension() }}
```

---

## Parameters

| Parameter | Type | Default | Omschrijving |
|---|---|---|---|
| `start_date` | string | `'2000-01-01'` | Begindatum van de dimensie |
| `end_date` | string | `'2030-12-31'` | Einddatum van de dimensie |
| `fiscal_year_start_month` | int | `1` | Startmaand van het fiscale jaar (1–12) |
| `schoolvakanties` | relatie | `none` | ref() of source() naar een schoolvakanties-tabel |
| `schoolvakantie_land` | string | `none` | Filter op land (bijv. `'NL'`) |
| `schoolvakantie_regio` | string | `none` | Filter op regio (bijv. `'Noord'`) |

---

## Gegenereerde kolommen

| Kolom | Omschrijving |
|---|---|
| `datum` | Datum |
| `datum_sleutel` | Surrogaatsleutel (YYYYMMDD) |
| `dag_nr` | Dag van de maand (1–31) |
| `dag_van_jaar` | Dag van het jaar (1–366) |
| `dag_van_week_nr` | ISO weekdagnummer (1 = ma, 7 = zo) |
| `weekdag` | Naam van de dag (taalafhankelijk) |
| `weekdag_afk` | Afkorting van de dag |
| `is_weekend` | true als zaterdag of zondag |
| `is_werkdag` | true als geen weekend én geen feestdag |
| `weeknummer` | Kalenderweek (1–53) |
| `iso_weeknummer` | ISO 8601 weeknummer |
| `iso_week_jaar` | Jaar van de ISO-week |
| `iso_week_label` | Bijv. `2024-W03` |
| `maand_nr` | Maandnummer (1–12) |
| `maand_naam` | Naam van de maand (taalafhankelijk) |
| `maand_afk` | Afkorting van de maand |
| `maand_label` | Bijv. `2024-03` |
| `kwartaal` | Kwartaal (1–4) |
| `kwartaal_label` | Bijv. `2024-Q1` |
| `jaar` | Jaar |
| `fiscaal_jaar` | Fiscaal jaar op basis van `fiscal_year_start_month` |
| `fiscaal_maand_nr` | Fiscale maand (1–12) |
| `fiscaal_kwartaal` | Fiscaal kwartaal (1–4) |
| `fiscaal_kwartaal_label` | Bijv. `FY2024-Q2` |
| `is_feestdag` | true als Nederlandse feestdag |
| `feestdag_naam` | Naam van de feestdag |
| `is_schoolvakantie` | true als schoolvakantie (alleen bij opgegeven relatie) |
| `schoolvakantie_naam` | Naam van de schoolvakantie |

---

## Taal

Stel in via dbt-variabele `dim_datum_taal` (default `nl`, ook `en` ondersteund):

```yaml
# dbt_project.yml
vars:
  dim_datum_taal: en
```

---

## Schoolvakanties

De macro verwacht een tabel met het volgende schema:

| Kolom | Type | Omschrijving |
|---|---|---|
| `van_datum` | date | Eerste vakantiedag |
| `tot_datum` | date | Laatste vakantiedag |
| `vakantie_naam` | text | Bijv. `'Zomervakantie'` |
| `land` | text | `'NL'`, `'BE'`, `'DE'`, `'GB'`, `'FR'`, `'US'` |
| `regio` | text | Bijv. `'Noord'`, `'Zone A'`, `'Bayern'` (null = alle regio's) |

Databronnen per land:

| Land | Bron | Structuur |
|---|---|---|
| NL | rijksoverheid.nl/onderwerpen/schoolvakanties | 3 regio's: Noord / Midden / Zuid |
| BE | onderwijs.vlaanderen.be / enseignement.be | 3 gemeenschappen: NL / FR / DE |
| DE | kmk.org/service/schulferien | 16 Bundesländer |
| GB | gov.uk/school-term-and-holiday-dates | Per local authority — geen centrale bron |
| FR | education.gouv.fr/calendrier-scolaire | 3 zones: A / B / C |
| US | Geen centrale bron | Per school district |

Configureer als standaard via `dbt_project.yml`:

```yaml
vars:
  dim_datum_schoolvakanties_tabel: "ref('schoolvakanties')"
  dim_datum_schoolvakantie_land: 'NL'
  dim_datum_schoolvakantie_regio: 'Noord'
```

---

## Uitgebreid voorbeeld

```sql
{{ generate_date_dimension(
       start_date='2015-01-01',
       end_date='2040-12-31',
       fiscal_year_start_month=4,
       schoolvakanties=ref('schoolvakanties'),
       schoolvakantie_land='NL',
       schoolvakantie_regio='Noord') }}
```
