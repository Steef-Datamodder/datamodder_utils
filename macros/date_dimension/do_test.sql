{% macro do_test_date_dimension() %}

{% set schema  = _datamodder_schema() %}
{% set tbl     = target.database ~ '.' ~ schema ~ '.test_date_dimension' %}
{% set tbl_fy  = target.database ~ '.' ~ schema ~ '.test_date_dimension_fy' %}

{% do run_query("create schema if not exists " ~ target.database ~ "." ~ schema) %}

{% set create_sql %}
create or replace table {{ tbl }} as
{{ generate_date_dimension(start_date='2024-01-01', end_date='2026-12-31') }}
{% endset %}
{% do run_query(create_sql) %}

{% set create_fy_sql %}
create or replace table {{ tbl_fy }} as
{{ generate_date_dimension(start_date='2024-01-01', end_date='2024-12-31', fiscal_year_start_month=4) }}
{% endset %}
{% do run_query(create_fy_sql) %}

{% set checks = run_query("
    select (select date_key       from " ~ tbl ~ " where date = '2024-01-15'::date) = 20240115        as chk_date_key
         , (select day_of_week_nr from " ~ tbl ~ " where date = '2024-01-01'::date) = 1               as chk_weekday_nr
         , (select is_weekend     from " ~ tbl ~ " where date = '2024-01-06'::date) = true             as chk_weekend
         , (select iso_week_label from " ~ tbl ~ " where date = '2024-01-08'::date) = '2024-W02'      as chk_iso_week
         , (select is_holiday     from " ~ tbl ~ " where date = '2024-03-31'::date) = true             as chk_easter_2024
         , (select holiday_name   from " ~ tbl ~ " where date = '2024-03-31'::date) = 'Easter Sunday'  as chk_easter_name
         , (select is_holiday     from " ~ tbl ~ " where date = '2024-04-01'::date) = true             as chk_easter_monday
         , (select is_holiday     from " ~ tbl ~ " where date = '2025-04-26'::date) = true             as chk_kingsday_moved
         , (select is_holiday     from " ~ tbl ~ " where date = '2025-04-27'::date) = false            as chk_kingsday_not_27
         , (select holiday_name   from " ~ tbl ~ " where date = '2024-12-25'::date) = 'Christmas Day'  as chk_christmas
         , (select is_workday     from " ~ tbl ~ " where date = '2024-01-01'::date) = false            as chk_workday_holiday
         , (select is_workday     from " ~ tbl ~ " where date = '2024-01-02'::date) = true             as chk_workday_regular
         , (select fiscal_year     from " ~ tbl_fy ~ " where date = '2024-03-31'::date) = 2023        as chk_fiscal_year_pre
         , (select fiscal_year     from " ~ tbl_fy ~ " where date = '2024-04-01'::date) = 2024        as chk_fiscal_year_start
         , (select fiscal_month_nr from " ~ tbl_fy ~ " where date = '2024-04-01'::date) = 1           as chk_fiscal_month_nr
         , (select fiscal_quarter  from " ~ tbl_fy ~ " where date = '2024-06-30'::date) = 1           as chk_fiscal_quarter
") %}

{% set row   = checks.rows[0] %}
{% set tests = [
    ("date_key: 2024-01-15 → 20240115",                        row[0]),
    ("day_of_week_nr: 2024-01-01 (Monday) = 1",                row[1]),
    ("is_weekend: 2024-01-06 (Saturday) = true",               row[2]),
    ("iso_week_label: 2024-01-08 = '2024-W02'",                row[3]),
    ("is_holiday: 2024-03-31 (Easter Sunday) = true",          row[4]),
    ("holiday_name: 2024-03-31 = 'Easter Sunday'",             row[5]),
    ("is_holiday: 2024-04-01 (Easter Monday) = true",          row[6]),
    ("is_holiday: 2025-04-26 (King's Day, moved from 27) = true", row[7]),
    ("is_holiday: 2025-04-27 (Sunday, moved) = false",         row[8]),
    ("holiday_name: 2024-12-25 = 'Christmas Day'",             row[9]),
    ("is_workday: 2024-01-01 (New Year's Day) = false",        row[10]),
    ("is_workday: 2024-01-02 (Tuesday) = true",                row[11]),
    ("fiscal_year: 2024-03-31 (before April start) = 2023",    row[12]),
    ("fiscal_year: 2024-04-01 (fiscal year start) = 2024",     row[13]),
    ("fiscal_month_nr: 2024-04-01 (first fiscal month) = 1",   row[14]),
    ("fiscal_quarter: 2024-06-30 (fiscal month 3) = 1",        row[15]),
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
