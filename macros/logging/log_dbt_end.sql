{% macro log_dbt_end() %}
{%- set cfg = _management_config() -%}
{%- set tbl = target.database ~ '.' ~ cfg.schema ~ '.' ~ cfg.table -%}
    insert into {{ tbl }} (invocation_id
                         , project_name
                         , target_name
                         , run_ended_at
                         , stat)
    values ('{{ invocation_id }}'
          , '{{ project_name }}'
          , '{{ target.name }}'
          , current_timestamp()
          , 'DBT Run ended');
{% endmacro %}