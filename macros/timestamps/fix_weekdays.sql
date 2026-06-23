{%- macro fix_weekdays(value_expr) -%}
{#- See docs.md for full documentation. -#}

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
