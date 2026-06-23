{% macro log_dbt_start() %}
{%- set cfg = _management_config() -%}
{%- set schema_ref = target.database ~ '.' ~ cfg.schema -%}
{%- set tbl = schema_ref ~ '.' ~ cfg.table -%}
{% if execute %}
    {%- set create_table_sql %}
        create table if not exists {{ tbl }} (invocation_id varchar
                                            , project_name varchar
                                            , target_name varchar
                                            , run_started_at timestamp_tz
                                            , run_ended_at timestamp_tz
                                            , stat varchar
        )
    {%- endset -%}
    {%- do run_query(create_table_sql) -%}
{% endif %}
    insert into {{ tbl }} (invocation_id
                         , project_name
                         , target_name
                         , run_started_at
                         , stat)
    values ('{{ invocation_id }}'
          , '{{ project_name }}'
          , '{{ target.name }}'
          , '{{ run_started_at }}'::timestamp_tz
          , 'DBT Run started');
{% endmacro %}
