{% macro create_masking_setup() %}
{% if execute %}
{%- set schema_ref = _datamodder_database() ~ '.' ~ _datamodder_schema() -%}
{%- set unmasked_roles = var('masking_unmasked_roles', ['SYSADMIN']) -%}
{%- do run_query('create database if not exists ' ~ _datamodder_database()) -%}
{%- do run_query('create schema if not exists ' ~ schema_ref) -%}
{%- set roles_sql = "'" ~ unmasked_roles | join("', '") ~ "'" -%}

{%- do run_query('create tag if not exists ' ~ schema_ref ~ '.pii_name    comment = \'Personal name field\'') -%}
{%- do run_query('create tag if not exists ' ~ schema_ref ~ '.pii_email   comment = \'Email address field\'') -%}
{%- do run_query('create tag if not exists ' ~ schema_ref ~ '.pii_phone   comment = \'Phone number field\'') -%}
{%- do run_query('create tag if not exists ' ~ schema_ref ~ '.pii_address comment = \'Address field\'') -%}
{%- do run_query('create tag if not exists ' ~ schema_ref ~ '.pii_date    comment = \'Sensitive date field\'') -%}
{%- do run_query('create tag if not exists ' ~ schema_ref ~ '.pii         comment = \'Generic PII field\'') -%}

{%- set policies = [
    { 'name': 'mask_name',         'type': 'varchar', 'masked': "'***** *****'" },
    { 'name': 'mask_email',        'type': 'varchar', 'masked': "'*****@*****.***'" },
    { 'name': 'mask_phone',        'type': 'varchar', 'masked': "'**-********'" },
    { 'name': 'mask_address',      'type': 'varchar', 'masked': "'***** ****'" },
    { 'name': 'mask_pii_varchar',  'type': 'varchar', 'masked': "'*****'" },
    { 'name': 'mask_pii_date',     'type': 'date',    'masked': "'1900-01-01'::date" },
    { 'name': 'mask_pii_number',   'type': 'number',  'masked': '0' }
] -%}

{%- for p in policies -%}
    {%- set policy_sql %}
        create or replace masking policy {{ schema_ref }}.{{ p.name }}
            as (val {{ p.type }}) returns {{ p.type }} ->
            case when current_role() in ({{ roles_sql }}) then val else {{ p.masked }} end
    {%- endset -%}
    {%- do run_query(policy_sql) -%}
{%- endfor -%}

{%- set tag_policies = [
    { 'tag': 'pii_name',    'policy': 'mask_name' },
    { 'tag': 'pii_email',   'policy': 'mask_email' },
    { 'tag': 'pii_phone',   'policy': 'mask_phone' },
    { 'tag': 'pii_address', 'policy': 'mask_address' },
    { 'tag': 'pii_date',    'policy': 'mask_pii_date' },
    { 'tag': 'pii',         'policy': 'mask_pii_varchar' },
    { 'tag': 'pii',         'policy': 'mask_pii_date' },
    { 'tag': 'pii',         'policy': 'mask_pii_number' }
] -%}

{%- for tp in tag_policies -%}
    {%- do run_query(
        'alter tag ' ~ schema_ref ~ '.' ~ tp.tag ~
        ' set masking policy ' ~ schema_ref ~ '.' ~ tp.policy
    ) -%}
{%- endfor -%}

{% endif %}
{% endmacro %}
