{%- macro fix_months(value_expr) -%}
{#- See docs.md for full documentation. -#}

{%- set cfg    = _timestamp_config() -%}
{%- set months = _data().months -%}
{%- set ns = namespace(expr = 'lower(trim(' ~ value_expr ~ '))') -%}
{%- for month in months -%}
  {#- Build active pattern list, ordered by language priority.
      Iterate over configured languages in order; for each language collect
      patterns that belong to it and have not been added yet.
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
