{%- macro _datamodder_schema() -%}
{{ return(var('datamodder_schema', 'datamodder')) }}
{%- endmacro -%}

-- uniform_datatypes: default decimal precision
-- override in dbt_project.yml: vars: { uniform_datatypes_integer_digits: 15, uniform_datatypes_decimal_digits: 2 }
{%- macro _uniform_datatypes_integer_digits() -%}
{{ return(var('uniform_datatypes_integer_digits', 18)) }}
{%- endmacro -%}

{%- macro _uniform_datatypes_decimal_digits() -%}
{{ return(var('uniform_datatypes_decimal_digits', 4)) }}
{%- endmacro -%}

{%- macro _dim_date_language() -%}
{{ return(var('dim_date_language', 'nl')) }}
{%- endmacro -%}

-- School holidays: set 'dim_date_school_holidays_table' to your ref/source name
-- e.g. in dbt_project.yml:
--   vars:
--     dim_date_school_holidays_table: ref('school_holidays')   -- or: source('raw', 'school_holidays')
--     dim_date_school_holiday_country: 'NL'
--     dim_date_school_holiday_region:  'Noord'                 -- optional
{%- macro _dim_date_school_holidays() -%}
{{ return(var('dim_date_school_holidays_table', none)) }}
{%- endmacro -%}

{%- macro _dim_date_school_holiday_country() -%}
{{ return(var('dim_date_school_holiday_country', none)) }}
{%- endmacro -%}

{%- macro _dim_date_school_holiday_region() -%}
{{ return(var('dim_date_school_holiday_region', none)) }}
{%- endmacro -%}
