set db_name = 'datamodder';
set schema_name = 'analyze';
set role_name = 'analyzer_role';

use role accountadmin;
create database identifier($db_name);
use database identifier($db_name);
create schema identifier($schema_name);
create role identifier($role_name);
grant usage on database identifier($db_name) to role identifier($role_name);
grant usage on schema identifier($schema_name) to role identifier($role_name);
grant all privileges on all tables in schema identifier($schema_name) to role identifier($role_name);
grant all privileges on future tables in schema identifier($schema_name) to role identifier($role_name);
grant role identifier($role_name) to user identifier(current_user());
