{%- macro fix_weekdays(value_expr) -%}
{#-
  strip_weekday_names(value_expr)
  ════════════════════════════════════════════════════════════════════════
  Removes a leading weekday name (plus any trailing comma, period, or
  whitespace separator) from a date string so the remainder can be parsed.

  Examples:
    'woensdag 15 maart 2024'     →  '15 maart 2024'
    'Wednesday, 15 March 2024'   →  '15 march 2024'
    'lundi 03/06/2024'           →  '03/06/2024'
    'Donnerstag, 15.03.2024'     →  '15.03.2024'
    '15-03-2024'                 →  '15-03-2024'   (no weekday — no change)

  Active languages are read from _timestamp_config().
  Locale data (weekday name patterns) is loaded from _data().
  Configure via dbt_project.yml — see _config.sql for full documentation.

  Supported languages:
    english · dutch · french · german · spanish · portuguese
    polish · danish · swedish · norwegian · finnish
    hindi (transliterated) · japanese (romaji)

  Behaviour:
    • Input is lowercased and trimmed before matching.
    • Only leading weekday names are stripped (anchored to start of string).
    • Full weekday names only — abbreviations are intentionally excluded to
      avoid false matches with month abbreviations (e.g. French mar. = Mardi
      but also March).
    • Pattern priority follows the language order from _timestamp_config().
    • Returns lower(trim(value_expr)) unchanged when no weekday is found.

  Usage:
    {{ strip_weekday_names('raw_date_column') }}
    {{ strip_weekday_names("'woensdag 15-03-2024'") }}
-#}

{%- set cfg      = _timestamp_config() -%}
{%- set weekdays = _data().weekdays -%}

{#- Collect active patterns in language-priority order, deduplicating across weekdays -#}

{%- set ns = namespace(active=[]) -%}

{%- for day in weekdays -%}
  {%- for lang in cfg.languages -%}
    {%- for rx in day.rx -%}
      {%- if lang in rx.l and rx.p not in ns.active -%}
        {%- set ns.active = ns.active + [rx.p] -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endfor -%}
{%- endfor -%}

{%- if ns.active | length > 0 -%}
{%- set pattern = '^\\s*(' ~ ns.active | join('|') ~ ')[,\\.\\s]*' -%}
regexp_replace(lower(trim({{ value_expr }})), '{{ pattern }}', '')
{%- else -%}
lower(trim({{ value_expr }}))
{%- endif -%}

{%- endmacro -%}
