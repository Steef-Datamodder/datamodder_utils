{% macro uniform_datatypes(relation, integer_digits=none, decimal_digits=none, exclude_columns=[]) %}

{% set integer_digits = integer_digits or _uniform_datatypes_integer_digits() %}
{% set decimal_digits = decimal_digits or _uniform_datatypes_decimal_digits() %}
{% set precision = integer_digits + decimal_digits %}
{% set scale = decimal_digits %}
{% set columns = adapter.get_columns_in_relation(relation) %}
{% set date_types = ['date', 'datetime', 'timestamp', 'timestamp_ntz', 'timestamp_ltz', 'timestamp_tz'] %}
{% set excluded = exclude_columns | map('upper') | list %}

select {% for col in columns -%}

  {%- set is_excluded = col.column | upper in excluded -%}
  {%- set is_str = col.is_string() -%}
  {%- set is_num = col.is_numeric() or col.is_integer() or col.is_float() -%}
  {%- set is_time = col.dtype | lower == 'time' -%}
  {%- set is_date = col.dtype | lower in date_types -%}

  {%- if not loop.first %}
     , {% endif -%}

  {%- if is_excluded %}{{ col.column }}
  {%- elif is_str %}{{ col.column }}::text
  {%- elif is_num %}try_to_decimal({{ col.column }}, {{ precision }}, {{ scale }})
  {%- elif is_time %}try_to_timestamp_tz('2000-01-01 ' || {{ col.column }}::string, 'YYYY-MM-DD HH24:MI:SS')
  {%- elif is_date %}try_to_timestamp_tz({{ col.column }})
  {%- else %}{{ col.column }}
  {%- endif %} as {{ col.column | lower }}

{%- endfor %}
  from {{ relation }}

{% endmacro %}
