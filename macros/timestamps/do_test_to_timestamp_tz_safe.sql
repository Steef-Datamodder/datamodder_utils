{% macro do_test_to_timestamp_tz_safe() %}
{#-
  Vult de kolom 'converted' in datamodder.test_to_timestamp_tz_safe
  en logt een samenvatting van geslaagde en mislukte conversies.

  Gebruik eerst create_test_to_timestamp_tz_safe om de tabel aan te maken.

  Gebruik:
    dbt run-operation do_test_to_timestamp_tz_safe --project-dir compare_wh
-#}

{%- set tbl = target.database ~ ".datamodder.test_to_timestamp_tz_safe" -%}

{% set update_sql %}
update {{ tbl }}
set converted = {{ to_timestamp_tz_safe('testval') }}::text
{% endset %}

{% do run_query(update_sql) %}

{%- set summary = run_query("
    select
        count(*)                     as total,
        count(*) - count(converted)  as failed,
        count(converted)             as passed
    from " ~ tbl) -%}

{%- set total  = summary.columns[0].values()[0] -%}
{%- set failed = summary.columns[1].values()[0] -%}
{%- set passed = summary.columns[2].values()[0] -%}

{{ log("─────────────────────────────────────────", info=True) }}
{{ log("Testresultaat: " ~ passed ~ "/" ~ total ~ " geslaagd", info=True) }}

{%- if failed > 0 %}
{{ log("MISLUKT (" ~ failed ~ " rijen — converted is null):", info=True) }}
{%- set failures = run_query("
    select id, testval
    from " ~ tbl ~ "
    where converted is null
    order by id") -%}
{%- for row in failures.rows %}
{{ log("  [" ~ row[0] ~ "]  " ~ row[1], info=True) }}
{%- endfor %}
{%- else %}
{{ log("Alle formaten herkend.", info=True) }}
{%- endif %}
{{ log("─────────────────────────────────────────", info=True) }}

{% endmacro %}
