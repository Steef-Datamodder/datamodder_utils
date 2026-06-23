{%- macro _management_config() -%}
{#- See docs.md for full documentation. -#}

{%- set defaults = {
    'schema': _datamodder_schema(),
    'table':  'runtimes'
} -%}

{%- set user = var('management_config', {}) -%}

{{ return({
    'schema': user.get('schema', defaults.schema),
    'table':  user.get('table',  defaults.table)
}) }}

{%- endmacro -%}
