{% macro apply_masking_tag(table, column, tag) %}
{% if execute %}
{%- set schema_ref = target.database ~ '.' ~ _datamodder_schema() -%}
{%- set sql %}
    alter table {{ table }} alter column {{ column }}
    set tag {{ schema_ref }}.{{ tag }} = '{{ tag }}'
{%- endset -%}
{%- do run_query(sql) -%}
{% endif %}
{% endmacro %}
