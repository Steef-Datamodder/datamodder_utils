# uniform_datatypes

Genereert een SELECT die alle kolommen naar uniforme datatypes cast. Gebruik als model-macro.

```sql
-- models/staging/stg_orders.sql
{{ uniform_datatypes(ref('raw_orders')) }}
```

---

## Parameters

| Parameter | Type | Default | Omschrijving |
|---|---|---|---|
| `relatie` | relatie | — | ref() of source() naar de brontabel (verplicht) |
| `voor_komma` | int | `18` (via `_config.sql`) | Maximaal aantal cijfers vóór de komma |
| `na_komma` | int | `4` (via `_config.sql`) | Maximaal aantal cijfers ná de komma |
| `kolommen_uitsluiten` | lijst | `[]` | Kolomnamen die ongewijzigd worden doorgelaten |

---

## Conversies

| Brontype | Doeltype | Functie |
|---|---|---|
| TEXT, VARCHAR, CHAR, … | `TEXT` | `::text` |
| NUMBER, INT, FLOAT, … | `DECIMAL(precision, scale)` | `try_to_decimal()` |
| DATE, TIMESTAMP_NTZ, TIMESTAMP_LTZ, TIMESTAMP_TZ | `TIMESTAMP_TZ` | `try_to_timestamp_tz()` |
| TIME | `TIMESTAMP_TZ` | `try_to_timestamp_tz('2000-01-01 ' \|\| col, …)` |
| BOOLEAN, VARIANT, overig | ongewijzigd | — |

Ongeldige waarden leveren `NULL` op (geen fout).

> **TIME-ankerdatum:** Voor TIME-kolommen wordt `2000-01-01` als ankerdatum gebruikt. Dit vermijdt zowel de Excel-schrikkeljaarfout (1900) als de Nederlandse tijdzoneverschuiving van 17 mei 1937 (Amsterdam Mean Time → CET).

---

## Voorbeelden

```sql
-- Standaard
{{ uniform_datatypes(ref('raw_orders')) }}

-- Aangepaste precisie
{{ uniform_datatypes(source('raw', 'orders'), voor_komma=15, na_komma=2) }}

-- Kolommen uitsluiten
{{ uniform_datatypes(ref('raw_orders'), kolommen_uitsluiten=['id', 'record_hash']) }}
```

Standaardwaarden aanpassen via `dbt_project.yml`:

```yaml
vars:
  uniform_datatypes_voor_komma: 15
  uniform_datatypes_na_komma: 2
```
