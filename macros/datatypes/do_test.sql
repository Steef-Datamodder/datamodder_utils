{% macro do_test_uniform_datatypes() %}
{#
  Creates a test table with one column of each supported type, applies uniform_datatypes,
  and checks the output against known expected values.

  Usage:
    dbt run-operation do_test_uniform_datatypes
#}

{% set schema  = _datamodder_schema() %}
{% set tbl_src = target.database ~ '.' ~ schema ~ '.test_uniform_datatypes_src' %}
{% set tbl_out = target.database ~ '.' ~ schema ~ '.test_uniform_datatypes_out' %}

{% do run_query("create schema if not exists " ~ target.database ~ "." ~ schema) %}

{% do run_query("
    create or replace table " ~ tbl_src ~ " (
        id      integer,
        label   varchar,
        amount  number(10, 2),
        ts      timestamp_ntz,
        t       time,
        flag    boolean
    )
") %}

{% do run_query("
    insert into " ~ tbl_src ~ " values (
        1,
        'hello',
        42.5,
        '2024-01-15 10:30:00'::timestamp_ntz,
        '14:30:00'::time,
        true
    )
") %}

{% set src_rel = adapter.get_relation(
    database = target.database,
    schema   = schema,
    identifier = 'test_uniform_datatypes_src'
) %}

{% set create_out %}
create or replace table {{ tbl_out }} as
{{ uniform_datatypes(src_rel, exclude_columns=['id']) }}
{% endset %}
{% do run_query(create_out) %}

{% set checks = run_query("
    select
        id        = 1                           as chk_excluded
      , label     = 'hello'                     as chk_text
      , amount    = 42.5                        as chk_decimal
      , ts::date  = '2024-01-15'::date          as chk_timestamp
      , t::date   = '2000-01-01'::date          as chk_time_anchor
      , to_time(t) = '14:30:00'::time           as chk_time_value
      , flag      = true                        as chk_boolean
    from " ~ tbl_out) %}

{% set row   = checks.rows[0] %}
{% set tests = [
    ('excluded column unchanged (id)',    row[0]),
    ('varchar → text',                    row[1]),
    ('number → decimal',                  row[2]),
    ('timestamp_ntz → timestamp_tz',      row[3]),
    ('time → timestamp_tz, anchor date',  row[4]),
    ('time → timestamp_tz, time value',   row[5]),
    ('boolean unchanged',                 row[6]),
] %}

{% set ns = namespace(passed=0, failed=0) %}
{{ log("─────────────────────────────────────────", info=True) }}
{% for name, ok in tests %}
    {% if ok %}
        {% set ns.passed = ns.passed + 1 %}
        {{ log("  PASS  " ~ name, info=True) }}
    {% else %}
        {% set ns.failed = ns.failed + 1 %}
        {{ log("  FAIL  " ~ name, info=True) }}
    {% endif %}
{% endfor %}
{{ log("─────────────────────────────────────────", info=True) }}
{{ log("Result: " ~ ns.passed ~ "/" ~ (ns.passed + ns.failed) ~ " passed", info=True) }}
{{ log("─────────────────────────────────────────", info=True) }}

{% endmacro %}
