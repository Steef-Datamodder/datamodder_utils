{%- macro _timestamp_config() -%}
{#- See docs.md for full documentation. -#}

{%- set defaults = {
    'languages': [
        'english', 'dutch', 'french', 'german', 'spanish', 'portuguese',
        'polish', 'danish', 'swedish', 'norwegian', 'finnish',
        'hindi', 'japanese'
    ],
    'format_groups':    ['iso', 'european', 'us', 'compact'],
    'two_digit_years':  true,
    'abbreviations':    true,
    'output_type':      'tz',
    'test_database':    _datamodder_database(),
    'test_schema':      'test_timestamps'
} -%}
{%- set user = var('timestamp_config', {}) -%}
{{ return({
    'languages':       user.get('languages',       defaults.languages),
    'format_groups':   user.get('format_groups',   defaults.format_groups),
    'two_digit_years': user.get('two_digit_years', defaults.two_digit_years),
    'abbreviations':   user.get('abbreviations',   defaults.abbreviations),
    'output_type':     user.get('output_type',     defaults.output_type),
    'test_database':   user.get('test_database',   defaults.test_database),
    'test_schema':     user.get('test_schema',     defaults.test_schema)
}) }}
{%- endmacro -%}
