with tables_and_columns as (
select table_catalog
     , table_schema
     , table_name
     , '      - name: ' || lower(table_name) || '\n' ||
       '        columns:' || '\n' ||
       listagg('          - name: ' || lower(column_name) || '\n' ||
               '            data_type: ' || lower(data_type)
               , '\n') within group (order by ordinal_position) as table_yaml
  from information_schema.columns
 where table_catalog = 'SNOWFLAKE_SAMPLE_DATA' 
   and table_schema not ilike 'information_schema'
 group by 1, 2, 3)
select '  - name: ' || lower(table_schema) || '\n' ||
       '    database: ' || lower(table_catalog) || '\n' ||
       '    schema: ' || lower(table_schema) || '\n' ||
       '    tables:' || '\n' ||
       listagg(table_yaml, '\n') within group (order by table_name) as yaml
  from tables_and_columns
 group by table_catalog, table_schema
 order by table_catalog, table_schema;