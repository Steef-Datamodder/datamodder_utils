{% macro do_test() %}
{#-
  Populates the 'converted' column in test_to_timestamp
  and logs a summary of successful and failed conversions.

  Run create_test first to create the table.

  Usage:
    dbt run-operation do_test --project-dir XXXXX
-#}

{%- set cfg = _timestamp_config() -%}
{%- set tbl = cfg.test_database ~ "." ~ cfg.test_schema ~ ".test_to_timestamp" -%}

{% set update_sql %}
update {{ tbl }}
set converted = {{ to_timestamp('testval') }}::text
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
{{ log("Result: " ~ passed ~ "/" ~ total ~ " passed", info=True) }}

{%- if failed > 0 %}
{{ log("FAILED (" ~ failed ~ " rows — converted is null):", info=True) }}
{%- set failures = run_query("
    select id, testval
    from " ~ tbl ~ "
    where converted is null
    order by id") -%}
{%- for row in failures.rows %}
{{ log("  [" ~ row[0] ~ "]  " ~ row[1], info=True) }}
{%- endfor %}
{%- else %}
{{ log("All formats recognised.", info=True) }}
{%- endif %}
{{ log("─────────────────────────────────────────", info=True) }}

{% endmacro %}
