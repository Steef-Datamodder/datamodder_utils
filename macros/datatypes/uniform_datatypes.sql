{% macro uniform_datatypes(relation, integer_digits=none, decimal_digits=none, exclude_columns=[]) %}
{#
  Generates a SELECT that casts all columns to uniform data types:
    - String types  (text, varchar, char, ...)                    → TEXT
    - Numeric types (number, int, float, ...)                     → DECIMAL(integer_digits + decimal_digits, decimal_digits)
    - Date/time types (date, timestamp_ntz/ltz, ...)              → TIMESTAMP_TZ  (via try_to_timestamp_tz)
    - TIME                                                        → TIMESTAMP_TZ  (anchor date 2000-01-01)
    - Other types (boolean, variant, ...)                         → unchanged

  Invalid values return NULL (try_to_* functions), not an error.

  Parameters:
    relation         : ref() or source() pointing to the source table (required)
    integer_digits   : max digits before the decimal point (default via _config.sql: 18)
    decimal_digits   : max digits after the decimal point  (default via _config.sql: 4)
    exclude_columns  : list of column names to pass through unchanged
                       e.g. ['id', 'record_hash', 'is_active']

  Usage in a model:
    {{ uniform_datatypes(ref('my_table')) }}
    {{ uniform_datatypes(source('raw', 'orders'), integer_digits=15, decimal_digits=2) }}
    {{ uniform_datatypes(ref('my_table'), exclude_columns=['id', 'source_system']) }}

  Or via config defaults in dbt_project.yml (see _config.sql):
    vars:
      uniform_datatypes_integer_digits: 15
      uniform_datatypes_decimal_digits: 2
#}

{% set integer_digits = integer_digits or _uniform_datatypes_integer_digits() %}
{% set decimal_digits = decimal_digits or _uniform_datatypes_decimal_digits() %}
{% set precision      = integer_digits + decimal_digits %}
{% set scale          = decimal_digits %}
{% set columns        = adapter.get_columns_in_relation(relation) %}
{% set date_types     = ['date', 'datetime', 'timestamp', 'timestamp_ntz', 'timestamp_ltz', 'timestamp_tz'] %}
{% set excluded       = exclude_columns | map('upper') | list %}

select {% for col in columns -%}

  {%- set is_excluded = col.column | upper in excluded -%}
  {%- set is_str      = col.is_string() -%}
  {%- set is_num      = col.is_numeric() or col.is_integer() or col.is_float() -%}
  {%- set is_time     = col.dtype | lower == 'time' -%}
  {%- set is_date     = col.dtype | lower in date_types -%}

  {%- if not loop.first %}
     , {% endif -%}

  {%- if is_excluded %}{{ col.column }}
  {%- elif is_str    %}{{ col.column }}::text
  {%- elif is_num    %}try_to_decimal({{ col.column }}, {{ precision }}, {{ scale }})
  {%- elif is_time   %}try_to_timestamp_tz('2000-01-01 ' || {{ col.column }}::string, 'YYYY-MM-DD HH24:MI:SS')
  {%- elif is_date   %}try_to_timestamp_tz({{ col.column }})
  {%- else           %}{{ col.column }}
  {%- endif %} as {{ col.column | lower }}

{%- endfor %}
  from {{ relation }}

{% endmacro %}
