{%- macro _datamodder_database() -%}
{{ return(var('datamodder_database', 'datamodder')) }}
{%- endmacro -%}

{%- macro _datamodder_schema() -%}
{{ return(var('datamodder_schema', 'utils')) }}
{%- endmacro -%}


{%- macro _management_config() -%}
{#- See docs.md for full documentation. -#}

{%- set defaults = {
    'database': _datamodder_database(),
    'schema':   _datamodder_schema(),
    'table':    'runtimes'
} -%}

{%- set user = var('management_config', {}) -%}

{{ return({
    'database': user.get('database', defaults.database),
    'schema':   user.get('schema',   defaults.schema),
    'table':    user.get('table',    defaults.table)
}) }}

{%- endmacro -%}
