{%- macro fix_months(value_expr) -%}
{#-
  normalize_month_names(value_expr)
  ════════════════════════════════════════════════════════════════════════
  Normalizes written-out month names to 3-letter English abbreviations:
    jan · feb · mar · apr · may · jun · jul · aug · sep · oct · nov · dec

  Active languages and their priority order are read from _timestamp_config().
  Locale data (month name patterns) is loaded from _data().
  Configure via dbt_project.yml — see _config.sql for full documentation.

  Supported languages:
    english · dutch · french · german · spanish · portuguese
    polish · danish · swedish · norwegian · finnish
    hindi (transliterated) · japanese (romaji)

  Behaviour:
    • Input is lowercased and trimmed before matching.
    • Word boundaries (\b) prevent partial-word collisions.
    • Accented forms and ASCII transliterations are both matched
      (e.g. Polish ń ↔ n, ź ↔ z; Finnish ä ↔ a; French é ↔ e).
    • Japanese: numbered-month romaji (ichigatsu … jūnigatsu).
      Both macron (ū) and double-u (uu) spellings are accepted.
    • Hindi: common Devanagari-to-Latin transliterations.
    • Language-specific abbreviations (janv., mrz., …) are only included
      when that language is active.
    • Universal abbreviations (jan., feb., …) are controlled separately
      by the abbreviations config flag.
    • Pattern order within each month follows the language priority order
      from the config: patterns belonging to higher-priority languages
      appear first.

  Usage:
    {{ normalize_month_names('raw_month_column') }}
    {{ normalize_month_names("'15-March-2024'") }}
-#}

{%- set cfg    = _timestamp_config() -%}
{%- set months = _data().months -%}

{%- set ns = namespace(expr = 'lower(trim(' ~ value_expr ~ '))') -%}

{%- for month in months -%}

  {#- Build active pattern list, ordered by language priority.
      Iterate over configured languages in order; for each language collect
      patterns that belong to it and haven't been added yet.
      Universal patterns (l = []) are appended last, controlled by cfg.abbreviations. -#}

  {%- set ms = namespace(active = []) -%}

  {%- for lang in cfg.languages -%}
    {%- for rx in month.rx -%}
      {%- if lang in rx.l and rx.p not in ms.active -%}
        {%- set ms.active = ms.active + [rx.p] -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endfor -%}

  {%- if cfg.abbreviations -%}
    {%- for rx in month.rx -%}
      {%- if rx.l | length == 0 and rx.p not in ms.active -%}
        {%- set ms.active = ms.active + [rx.p] -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}

  {%- if ms.active | length > 0 -%}
    {%- set pattern = '\\\\b(' ~ ms.active | join('|') ~ ')\\\\b' -%}
    {%- set ns.expr = 'regexp_replace(\n' ~ ns.expr ~ ",\n    '" ~ pattern ~ "',\n    '" ~ month.out ~ "')" -%}
  {%- endif -%}

{%- endfor -%}

{{ ns.expr }}

{%- endmacro -%}
