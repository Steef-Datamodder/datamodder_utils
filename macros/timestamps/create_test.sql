{% macro create_test() %}
{#-
  Creates <test_schema>.test_to_timestamp with the test values.
  The 'converted' column remains NULL until do_test is run.

  Usage:
    dbt run-operation create_test --project-dir XXXXX
    dbt run-operation do_test     --project-dir XXXXX
-#}

{%- set cfg  = _timestamp_config() -%}
{%- set vals = _data().test_values -%}
{%- set tbl  = cfg.test_database ~ "." ~ cfg.test_schema ~ ".test_to_timestamp" -%}

{% do run_query("create database if not exists " ~ cfg.test_database) %}
{% do run_query("create schema if not exists " ~ cfg.test_database ~ "." ~ cfg.test_schema) %}

{% set create_sql %}
create or replace table {{ tbl }} (
    id        integer,
    testval   text,
    converted text
) as
select
    id,
    testval,
    null::text as converted
from (
    values
    {%- for v in vals %}
        ({{ loop.index }}, '{{ v }}'){% if not loop.last %},{% endif %}
    {%- endfor %}
) as t(id, testval)
order by id
{% endset %}

{% do run_query(create_sql) %}
{{ log("Created: " ~ tbl ~ " (" ~ vals | length ~ " rows, converted still empty)", info=True) }}

{% endmacro %}
