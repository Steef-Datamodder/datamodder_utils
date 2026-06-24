set role_name          = 'analyzer_role';
set target_db_name     = 'analyzer';
set pit_schema_name    = 'analyzer';
set agg_schema_name    = 'analyzer_agg';
set source_db_name     = 'snowflake_sample_data';
set source_schema_name = 'tpch_sf1';
set source_table_name  = 'customer';
set current_user_name  = current_user();
set chars_min          = 2;
set chars_max          = 100;
set numeric_min        = 0;
set numeric_max        = 999;
set datetime_min       = '01-01-1925';

use role accountadmin;
create database if not exists identifier($target_db_name);
use database identifier($target_db_name);
create schema if not exists identifier($pit_schema_name);
create schema if not exists identifier($agg_schema_name);
create role if not exists identifier($role_name);
grant usage on database identifier($target_db_name) to role identifier($role_name);
grant usage           on schema identifier($pit_schema_name) to role identifier($role_name);
grant all privileges on all tables    in schema identifier($pit_schema_name) to role identifier($role_name);
grant all privileges on future tables in schema identifier($pit_schema_name) to role identifier($role_name);
grant create table     on schema identifier($pit_schema_name) to role identifier($role_name);
grant create procedure on schema identifier($pit_schema_name) to role identifier($role_name);
grant usage           on schema identifier($agg_schema_name) to role identifier($role_name);
grant all privileges on all tables    in schema identifier($agg_schema_name) to role identifier($role_name);
grant all privileges on future tables in schema identifier($agg_schema_name) to role identifier($role_name);
grant create view      on schema identifier($agg_schema_name) to role identifier($role_name);
grant role identifier($role_name) to user identifier($current_user_name);

use role analyzer_role;
use database identifier($target_db_name);
use schema identifier($pit_schema_name);

create or replace procedure create_pit(source_db  string default null
                                     , source_sch string default null
                                     , source_tbl string default null)
returns string
language sql
execute as caller
as
$$
declare
    db string default $target_db_name;
    sch string default $pit_schema_name;
    src_db string default coalesce(source_db, $source_db_name);
    src_sch string default coalesce(source_sch, $source_schema_name);
    src_tbl string default coalesce(source_tbl, $source_table_name);
    detected_tz string;
    ts_str string;
begin
    execute immediate 'show parameters like ''TIMEZONE'' in session';
    detected_tz := (select "value" from table(result_scan(last_query_id())) limit 1);
    ts_str := to_char(convert_timezone(detected_tz, current_timestamp()), 'YYYYMMDD_HH24MISS');
    execute immediate 'create table ' || db || '.' || sch || '.' || src_tbl || '_' || ts_str ||
                      ' as select * from ' || src_db || '.' || src_sch || '.' || src_tbl;
    return 'done';
end;
$$;

begin
execute immediate replace(replace(replace(replace(replace(replace(replace(
$$
create or replace view {TARGET_DB}.{AGG_SCHEMA}.stats_statements as
with ranges as (
select {CHARS_MIN} as chars_min
     , {CHARS_MAX} as chars_max
     , {NUMERIC_MIN} as numeric_min
     , {NUMERIC_MAX} as numeric_max
     , '{DATETIME_MIN}'::date as datetime_min
     , current_date() as datetime_max)
select lower(regexp_replace(c.table_name, '_[0-9]{8}_[0-9]{6}$', '')) as tbl_name
     , dense_rank() over (partition by regexp_replace(c.table_name, '_[0-9]{8}_[0-9]{6}$', '')
                              order by to_timestamp_ntz(regexp_substr(c.table_name
                                                                    , '[0-9]{8}_[0-9]{6}$')
                                                                    , 'YYYYMMDD_HH24MISS')) as tbl_nr
     , c.ordinal_position as col_nr
     , lower(c.column_name) as col_name
     , c.data_type
     , case when c.data_type = 'TEXT' then 'chars'
            when c.data_type = 'NUMBER' then 'numeric'
            when c.data_type in ('DATE', 'TIME', 'TIMESTAMP_NTZ', 'TIMESTAMP_LTZ', 'TIMESTAMP_TZ') then 'datetime' end as data_type_group
     , to_timestamp_ntz(regexp_substr(c.table_name, '[0-9]{8}_[0-9]{6}$'), 'YYYYMMDD_HH24MISS') as table_ts
     , 'select count(*) - count(' || c.column_name || ') from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name as null_count_sql
     , 'select count(distinct ' || c.column_name || ') from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name as distinct_count_sql
     , case when data_type_group = 'chars' then 'select min(length(' || c.column_name || ')) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name
            when data_type_group in ('numeric', 'datetime') then 'select min(' || c.column_name || ') from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name end as min_sql
     , case when data_type_group = 'chars' then 'select max(length(' || c.column_name || ')) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name
            when data_type_group in ('numeric', 'datetime') then 'select max(' || c.column_name || ') from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name end as max_sql
     , case when data_type_group = 'chars' then 'select sum(iff(length(' || c.column_name || ') < ' || r.chars_min || ', 1, 0)) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name
            when data_type_group = 'numeric' then 'select sum(iff(' || c.column_name || ' < ' || r.numeric_min || ', 1, 0)) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name
            when data_type_group = 'datetime' then 'select sum(iff(' || c.column_name || ' < ''' || r.datetime_min || '''::date, 1, 0)) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name end as under_min_count_sql
     , case when data_type_group = 'chars' then 'select sum(iff(length(' || c.column_name || ') > ' || r.chars_max || ', 1, 0)) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name
            when data_type_group = 'numeric' then 'select sum(iff(' || c.column_name || ' > ' || r.numeric_max || ', 1, 0)) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name
            when data_type_group = 'datetime' then 'select sum(iff(' || c.column_name || ' > ''' || r.datetime_max || '''::date, 1, 0)) from {TARGET_DB}.{PIT_SCHEMA}.' || c.table_name end as above_max_count_sql
  from information_schema.tables tv
  join information_schema.columns c
    on tv.table_catalog = c.table_catalog
   and tv.table_schema = c.table_schema
   and tv.table_name = c.table_name
 cross join ranges r
 where tv.table_schema ilike '{PIT_SCHEMA}'
   and regexp_like(tv.table_name, '.*_[0-9]{8}_[0-9]{6}$')
 order by 1,2,3
$$,
'{CHARS_MIN}', $chars_min::string),
'{CHARS_MAX}', $chars_max::string),
'{NUMERIC_MIN}', $numeric_min::string),
'{NUMERIC_MAX}', $numeric_max::string),
'{DATETIME_MIN}', $datetime_min::string),
'{TARGET_DB}', $target_db_name),
'{PIT_SCHEMA}', $pit_schema_name),
'{AGG_SCHEMA}', $agg_schema_name)
;
end;


