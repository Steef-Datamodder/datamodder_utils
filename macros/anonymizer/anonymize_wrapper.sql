{% macro anonymize(table, pk, columns) %}
{% if execute %}
{%- set schema_ref = target.database ~ '.' ~ _datamodder_schema() -%}
{%- set col_json = columns | tojson -%}
{%- set sql %}
    call {{ schema_ref }}.anonymize(
        '{{ table }}',
        '{{ pk }}',
        parse_json($$ {{ col_json }} $$)
    )
{%- endset -%}
{%- do run_query(sql) -%}
{% endif %}
{% endmacro %}
