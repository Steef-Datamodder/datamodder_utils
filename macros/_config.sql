{%- macro _datamodder_schema() -%}
{{ return(var('datamodder_schema', 'datamodder')) }}
{%- endmacro -%}

{%- macro _dim_datum_taal() -%}
{{ return(var('dim_datum_taal', 'nl')) }}
{%- endmacro -%}
