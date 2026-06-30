{% macro uniform_datatypes(relatie, voor_komma=none, na_komma=none, kolommen_uitsluiten=[]) %}
{#
  Genereert een SELECT die datatypes uniformeert:
    - Alle string-typen  (text, varchar, char, ...)          → TEXT
    - Alle numerieke typen (number, int, float, ...)         → DECIMAL(voor_komma + na_komma, na_komma)
    - Alle datum/tijd-typen (date, timestamp_ntz/ltz, ...)   → TIMESTAMP_TZ  (via try_to_timestamp_tz)
    - TIME                                                   → TIMESTAMP_TZ  (ankerdatum 2000-01-01)
    - Overige typen (boolean, variant, ...)                  → ongewijzigd

  Ongeldige waarden leveren NULL op (try_to_* functies), geen fout.

  Parameters:
    relatie              : ref() of source() naar de brontabel (verplicht)
    voor_komma           : maximaal aantal cijfers vóór de komma (default via _config.sql: 18)
    na_komma             : maximaal aantal cijfers ná  de komma (default via _config.sql: 4)
    kolommen_uitsluiten  : lijst van kolomnamen die ongewijzigd worden doorgelaten
                           bijv. ['id', 'record_hash', 'is_actief']

  Gebruik in een model:
    {{ uniform_datatypes(ref('mijn_tabel')) }}
    {{ uniform_datatypes(source('raw', 'orders'), voor_komma=15, na_komma=2) }}
    {{ uniform_datatypes(ref('mijn_tabel'), kolommen_uitsluiten=['id', 'bron_systeem']) }}

  Of via de config-defaults in dbt_project.yml (zie _config.sql):
    vars:
      uniform_datatypes_voor_komma: 15
      uniform_datatypes_na_komma:   2
#}

{% set voor_komma          = voor_komma or _uniform_datatypes_voor_komma() %}
{% set na_komma            = na_komma   or _uniform_datatypes_na_komma() %}
{% set precision           = voor_komma + na_komma %}
{% set scale               = na_komma %}
{% set columns             = adapter.get_columns_in_relation(relatie) %}
{% set datum_typen         = ['date', 'datetime', 'timestamp', 'timestamp_ntz', 'timestamp_ltz', 'timestamp_tz'] %}
{% set uitgesloten         = kolommen_uitsluiten | map('upper') | list %}

select {% for col in columns -%}

  {%- set is_uitgesloten = col.column | upper in uitgesloten -%}
  {%- set is_str         = col.is_string() -%}
  {%- set is_num         = col.is_numeric() or col.is_integer() or col.is_float() -%}
  {%- set is_time        = col.dtype | lower == 'time' -%}
  {%- set is_dttm        = col.dtype | lower in datum_typen -%}

  {%- if not loop.first %}
     , {% endif -%}

  {%- if is_uitgesloten %}{{ col.column }}
  {%- elif is_str        %}{{ col.column }}::text
  {%- elif is_num        %}try_to_decimal({{ col.column }}, {{ precision }}, {{ scale }})
  {%- elif is_time       %}try_to_timestamp_tz('2000-01-01 ' || {{ col.column }}::string, 'YYYY-MM-DD HH24:MI:SS')
  {%- elif is_dttm       %}try_to_timestamp_tz({{ col.column }})
  {%- else               %}{{ col.column }}
  {%- endif %} as {{ col.column | lower }}

{%- endfor %}
  from {{ relatie }}

{% endmacro %}
