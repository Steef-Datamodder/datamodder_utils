# generate_sources

Macros voor het genereren van bronbestanden en dbt-configuratie op basis van Snowflake-metadata.

---

## generate_source_yaml

Genereert `sources.yml`-inhoud. Kopieer de console-output naar `models/staging/sources/`.

```bash
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data"}'
```

### Parameters

| Parameter | Type | Default | Omschrijving |
|---|---|---|---|
| `database` | string | — | Snowflake-database (verplicht) |
| `schemas` | string of lijst | `none` (= alle) | Filter op één of meerdere schema's |
| `split` | boolean | `true` | `true` → per schema een apart blok met bestandspad als commentaar; `false` → één gecombineerde YAML |

### Voorbeelden

```bash
# Alle schema's, gesplitst per bestand
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data"}'

# Eén schema
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": "tpch_sf1"}'

# Meerdere schema's
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1", "tpch_sf10"]}'

# Alles in één bestand
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "split": false}'
```

---

## generate_staging_models

Toont de inhoud van elk staging-model (`select * from {{ source(...) }}`), per tabel gescheiden door een commentaarregel met het bestandspad.

```bash
dbt run-operation generate_staging_models --args '{"database": "snowflake_sample_data"}'
```

### Parameters

| Parameter | Type | Default | Omschrijving |
|---|---|---|---|
| `database` | string | — | Snowflake-database (verplicht) |
| `schemas` | string of lijst | `none` (= alle) | Filter op één of meerdere schema's |

---

## generate_dbt_project_snippet

Toont het blok om onder `models:` in `dbt_project.yml` te plakken.

```bash
dbt run-operation generate_dbt_project_snippet --args '{"database": "snowflake_sample_data"}'
```

### Parameters

| Parameter | Type | Default | Omschrijving |
|---|---|---|---|
| `database` | string | — | Snowflake-database (verplicht) |
| `schemas` | string of lijst | `none` (= alle) | Filter op één of meerdere schema's |

### Voorbeeldoutput

```yaml
    staging:
      tpch_sf1:
        +enabled: false
      tpch_sf10:
        +enabled: false
```
