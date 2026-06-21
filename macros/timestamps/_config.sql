{%- macro _timestamp_config() -%}
{#-
  Central configuration for normalize_month_names and to_timestamp_tz_safe.

  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Override in dbt_project.yml:                                           │
  │                                                                         │
  │  vars:                                                                  │
  │    timestamp_config:                                                    │
  │      languages:                                                         │
  │        - dutch                                                          │
  │        - english                                                        │
  │        - french                                                         │
  │      format_groups:                                                     │
  │        - iso                                                            │
  │        - european                                                       │
  │        - oracle                                                         │
  │      two_digit_years: true                                              │
  │      abbreviations:   true                                              │
  └─────────────────────────────────────────────────────────────────────────┘

  languages
    Controls which month-name patterns normalize_month_names recognises and
    in what priority order patterns are tried.  The first language in the
    list wins when the same pattern belongs to multiple languages.

    Available:
      english · dutch · french · german · spanish · portuguese
      polish · danish · swedish · norwegian · finnish
      hindi · japanese

  format_groups
    Controls which date/time format families to_timestamp_tz_safe attempts.
    Human-language names and database-provider names may be mixed freely.
    Duplicate format strings across groups are deduplicated automatically.

    Generic groups:
      iso        — YYYY-MM-DD …  (also /  and  . separators, T-variant, Z-suffix)
      european   — DD-MM-YYYY …  (also /  and  .)
      us         — MM-DD-YYYY …  (also /  and  .)
      compact    — YYYYMMDD, YYYYMMDDHH24MISS

    Database provider groups (activates that vendor's typical export formats):
      oracle     — DD-MON-RR, YYYY-MM-DD HH24:MI:SS.FF6, and related
      mssql      — MM/DD/YYYY, MON DD YYYY HH12:MIAM, style-109 variant
      postgresql — ISO 8601  (equivalent to iso)
      mysql      — YYYY-MM-DD HH:MI:SS  (subset of iso)
      sap        — YYYYMMDD  (equivalent to compact)

  two_digit_years
    When true, includes YY variants for the active generic groups
    (e.g. DD-MM-YY, MM/DD/YY).  Has no effect on provider groups
    (those handle their own year formats internally).

  abbreviations
    When true, includes language-agnostic month abbreviations
    (jan., feb., …) at the end of the match list in normalize_month_names.
-#}

{%- set defaults = {
    'languages': [
        'english', 'dutch', 'french', 'german', 'spanish', 'portuguese',
        'polish', 'danish', 'swedish', 'norwegian', 'finnish',
        'hindi', 'japanese'
    ],
    'format_groups':    ['iso', 'european', 'us', 'compact'],
    'two_digit_years':  true,
    'abbreviations':    true
} -%}

{%- set user = var('timestamp_config', {}) -%}

{{ return({
    'languages':       user.get('languages',       defaults.languages),
    'format_groups':   user.get('format_groups',   defaults.format_groups),
    'two_digit_years': user.get('two_digit_years', defaults.two_digit_years),
    'abbreviations':   user.get('abbreviations',   defaults.abbreviations)
}) }}

{%- endmacro -%}
