-- ── generate_source_yaml ─────────────────────────────────────────────────────
-- Genereert sources.yml-inhoud. Kopieer de output naar models/staging/sources/.

-- Alle schema's, gesplitst per bestand (default)
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data"}'

-- Één schema
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": "tpch_sf1"}'

-- Meerdere schema's
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1", "tpch_sf10"]}'

-- Alle schema's in één gecombineerd bestand
dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "split": false}'


-- ── generate_staging_models ──────────────────────────────────────────────────
-- Toont inhoud per staging-model. Kopieer per blok naar models/staging/{schema}/.

dbt run-operation generate_staging_models --args '{"database": "snowflake_sample_data"}'

dbt run-operation generate_staging_models --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1"]}'


-- ── generate_dbt_project_snippet ─────────────────────────────────────────────
-- Toont het blok om onder 'models:' in dbt_project.yml te plakken.

dbt run-operation generate_dbt_project_snippet --args '{"database": "snowflake_sample_data"}'
