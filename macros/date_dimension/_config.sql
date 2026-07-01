{%- macro _dim_date_language() -%}
{{ return(var('dim_date_language', 'nl')) }}
{%- endmacro -%}

{%- macro _dim_date_public_holidays() -%}
{{ return(var('dim_date_public_holidays_table', none)) }}
{%- endmacro -%}

{%- macro _dim_date_country() -%}
{{ return(var('dim_date_country', 'NL')) }}
{%- endmacro -%}

{%- macro _dim_date_datenames() -%}
{{ return(var('dim_date_datenames_table', none)) }}
{%- endmacro -%}

{%- macro _dim_date_school_holidays() -%}
{{ return(var('dim_date_school_holidays_table', none)) }}
{%- endmacro -%}

{%- macro _dim_date_school_holiday_country() -%}
{{ return(var('dim_date_school_holiday_country', none)) }}
{%- endmacro -%}

{%- macro _dim_date_school_holiday_region() -%}
{{ return(var('dim_date_school_holiday_region', none)) }}
{%- endmacro -%}
