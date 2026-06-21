// maak scripts\create_source_files.cmd

with schema_names as (
select distinct table_schema as sch 
  from information_schema.tables
 where table_catalog = 'SNOWFLAKE_SAMPLE_DATA' 
   and table_schema not ilike 'information_schema')
select 1 as id
     , '@echo off\n\nif not exist "..\\models\\staging\\sources" mkdir "..\\models\\staging\\sources"\n\nfor %%F in (' as cmd
 union 
select (row_number() over (order by sch)) + 1
     , '  ' || lower(sch)
  from schema_names     
 union  
select 996
     , ') do (\n  echo version: 1 > "..\\models\\staging\\sources\\%%F.yml"\n  ' || 
       'echo. >> "..\\models\\staging\\sources\\%%F.yml"\n  ' || 
       'echo sources: >> "..\\models\\staging\\sources\\%%F.yml"\n  ' ||
       'echo. >> "..\\models\\staging\\sources\\%%F.yml"\n)'
 union 
select 997
     , 'for %%F in (' 
 union 
select 998
     , lower(sch)
  from schema_names    
 union 
select 999
     , ') do (\n  mkdir "..\\models\\staging\\%%F"\n)' 
 order by 1
 
// vulling 
      
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

// maak scripts\create_staging_files.cmd

with table_names as (
select lower(table_schema) as sch
     , lower(table_name) as tbl 
  from information_schema.tables
 where table_catalog = 'SNOWFLAKE_SAMPLE_DATA' 
   and table_schema not ilike 'information_schema')
select 'echo select * from {{ source(''' || sch || ''', ''' || tbl || ''') }}' ||
       '>"..\\models\\staging\\' || sch || '\\' || tbl || '.sql"' as line
  from table_names
 order by sch, tbl

// dbt_project,yml content
 
select distinct '      ' || lower(table_schema) || ':\n        +enabled: false' as sch
  from information_schema.tables
 where table_catalog = 'SNOWFLAKE_SAMPLE_DATA' 
   and table_schema not ilike 'information_schema'