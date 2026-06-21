{% macro create_test_to_timestamp_tz_safe() %}
{#-
  Maakt datamodder.test_to_timestamp_tz_safe aan met de testwaarden.
  De kolom 'converted' blijft leeg (NULL) totdat do_test_to_timestamp_tz_safe
  wordt uitgevoerd.

  Gebruik:
    dbt run-operation create_test_to_timestamp_tz_safe --project-dir compare_wh
    dbt run-operation do_test_to_timestamp_tz_safe     --project-dir compare_wh
-#}

{%- set vals = _data().test_values -%}

{% do run_query("create schema if not exists " ~ target.database ~ ".datamodder") %}

{% set create_sql %}
create or replace table {{ target.database }}.datamodder.test_to_timestamp_tz_safe (
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
{{ log("Aangemaakt: " ~ target.database ~ ".datamodder.test_to_timestamp_tz_safe (" ~ vals | length ~ " rijen, converted nog leeg)", info=True) }}

{% endmacro %}
