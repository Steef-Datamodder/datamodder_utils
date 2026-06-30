{% macro _schema_filter(schemas, col) -%}
  {% if schemas is not none %}
    {% if schemas is string %}
      and lower({{ col }}) = lower('{{ schemas }}')
    {% else %}
      and lower({{ col }}) in ({{ schemas | map('lower') | list | tojson | replace('[', '') | replace(']', '') }})
    {% endif %}
  {% endif %}
{%- endmacro %}


{% macro generate_source_yaml(database, schemas=none, split=true) %}
{#
  Generates sources.yml content for all tables in a database.

  Parameters:
    database : Snowflake database (required)
    schemas  : string, list of strings, or none (= all schemas)
    split    : true  → one block per schema with file path as comment (default)
               false → single combined sources.yml

  Usage:
    dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data"}'
    dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": "tpch_sf1"}'
    dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1", "tpch_sf10"]}'
    dbt run-operation generate_source_yaml --args '{"database": "snowflake_sample_data", "split": false}'
#}

{% set sql %}
select lower(c.table_schema) as table_schema
     , lower(c.table_name)   as table_name
     , lower(c.column_name)  as column_name
     , lower(c.data_type)    as data_type
  from {{ database }}.information_schema.columns c
  join {{ database }}.information_schema.tables t
    on  t.table_catalog = c.table_catalog
   and  t.table_schema  = c.table_schema
   and  t.table_name    = c.table_name
 where c.table_schema not ilike 'information_schema'
   and t.table_type = 'BASE TABLE'
   {{ _schema_filter(schemas, 'c.table_schema') }}
 order by c.table_schema, c.table_name, c.ordinal_position
{% endset %}

{% if execute %}
  {% set results = run_query(sql) %}
  {% set lines   = [] %}
  {% set ns      = namespace(schema='', table='') %}

  {% if not split %}
    {% set _ = lines.append('version: 2') %}
    {% set _ = lines.append('') %}
    {% set _ = lines.append('sources:') %}
  {% endif %}

  {% for row in results %}
    {% if row['table_schema'] != ns.schema %}
      {% set ns.schema = row['table_schema'] %}
      {% set ns.table  = '' %}

      {% if split %}
        {% if not loop.first %}{% set _ = lines.append('') %}{% endif %}
        {% set _ = lines.append('-- === models/staging/sources/' ~ ns.schema ~ '.yml ===') %}
        {% set _ = lines.append('version: 2') %}
        {% set _ = lines.append('') %}
        {% set _ = lines.append('sources:') %}
      {% endif %}

      {% set _ = lines.append('  - name: '     ~ ns.schema) %}
      {% set _ = lines.append('    database: ' ~ database | lower) %}
      {% set _ = lines.append('    schema: '   ~ ns.schema) %}
      {% set _ = lines.append('    tables:') %}
    {% endif %}

    {% if row['table_name'] != ns.table %}
      {% set ns.table = row['table_name'] %}
      {% set _ = lines.append('      - name: '    ~ ns.table) %}
      {% set _ = lines.append('        columns:') %}
    {% endif %}

    {% set _ = lines.append('          - name: '      ~ row['column_name']) %}
    {% set _ = lines.append('            data_type: ' ~ row['data_type']) %}
  {% endfor %}

  {{ print(lines | join('\n')) }}
{% endif %}

{% endmacro %}


{% macro generate_staging_models(database, schemas=none) %}
{#
  Outputs the content of each staging model (one per table).
  Separated by -- === {schema}/{table}.sql === comments.

  Usage:
    dbt run-operation generate_staging_models --args '{"database": "snowflake_sample_data"}'
    dbt run-operation generate_staging_models --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1", "tpch_sf10"]}'
#}

{% set sql %}
select lower(table_schema) as table_schema
     , lower(table_name)   as table_name
  from {{ database }}.information_schema.tables
 where table_schema not ilike 'information_schema'
   and table_type = 'BASE TABLE'
   {{ _schema_filter(schemas, 'table_schema') }}
 order by table_schema, table_name
{% endset %}

{% if execute %}
  {% set results = run_query(sql) %}
  {% set lines   = [] %}

  {% for row in results %}
    {% if not loop.first %}{% set _ = lines.append('') %}{% endif %}
    {% set _ = lines.append('-- === models/staging/' ~ row['table_schema'] ~ '/' ~ row['table_name'] ~ '.sql ===') %}
    {% set _ = lines.append("select * from {{ source('" ~ row['table_schema'] ~ "', '" ~ row['table_name'] ~ "') }}") %}
  {% endfor %}

  {{ print(lines | join('\n')) }}
{% endif %}

{% endmacro %}


{% macro generate_dbt_project_snippet(database, schemas=none) %}
{#
  Outputs the block to paste under 'models:' in dbt_project.yml.

  Usage:
    dbt run-operation generate_dbt_project_snippet --args '{"database": "snowflake_sample_data"}'
    dbt run-operation generate_dbt_project_snippet --args '{"database": "snowflake_sample_data", "schemas": ["tpch_sf1"]}'
#}

{% set sql %}
select distinct lower(table_schema) as table_schema
  from {{ database }}.information_schema.tables
 where table_schema not ilike 'information_schema'
   and table_type = 'BASE TABLE'
   {{ _schema_filter(schemas, 'table_schema') }}
 order by 1
{% endset %}

{% if execute %}
  {% set results = run_query(sql) %}
  {% set lines   = ['    staging:'] %}

  {% for row in results %}
    {% set _ = lines.append('      ' ~ row['table_schema'] ~ ':') %}
    {% set _ = lines.append('        +enabled: false') %}
  {% endfor %}

  {{ print(lines | join('\n')) }}
{% endif %}

{% endmacro %}
