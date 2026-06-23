-- ----------------------------------------------------------------
-- datamodder_utils — one-time setup
-- run as accountadmin before using any datamodder macros
-- ----------------------------------------------------------------

-- ----------------------------------------------------------------
-- step 1: accountadmin — database, role, grants
-- ----------------------------------------------------------------
use role accountadmin;

create database if not exists MY_DATABASE;  -- change to your database name

create role if not exists dbt_role;

grant usage            on database MY_DATABASE to role dbt_role;
grant create schema    on database MY_DATABASE to role dbt_role;
grant usage            on warehouse MY_WAREHOUSE to role dbt_role;  -- change to your warehouse

-- assign role to your user (optional but recommended)
-- grant role dbt_role to user MY_USER;

-- ----------------------------------------------------------------
-- step 2: dbt_role — create datamodder schema
-- ----------------------------------------------------------------
use role dbt_role;
use database MY_DATABASE;

create schema if not exists datamodder;
