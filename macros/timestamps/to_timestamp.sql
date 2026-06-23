{% macro to_timestamp(value_expr, timezone="'UTC'") %}
{#- See docs.md for full documentation. -#}

{%- set cfg = _timestamp_config() -%}
{%- set grps = cfg.format_groups -%}
{%- set yy   = cfg.two_digit_years -%}

{#- Output-type wrappers: swap these to switch between timestamp_tz and timestamp_ntz output -#}
{%- if cfg.output_type == 'ntz' -%}
  {%- set _pre        = '' -%}
  {%- set _suf        = '' -%}
  {%- set _try_tz_suf = '::timestamp_ntz' -%}
{%- else -%}
  {%- set _pre        = "convert_timezone('UTC', " ~ timezone ~ ", " -%}
  {%- set _suf        = ')::timestamp_tz' -%}
  {%- set _try_tz_suf = '' -%}
{%- endif -%}

{#- ── Format definitions per group ─────────────────────────────────────── -#}

{%- set fmt_iso = [
    'YYYY-MM-DD HH24:MI:SS.FF',
    'YYYY-MM-DD HH24:MI:SS',
    'YYYY-MM-DD',
    'YYYY/MM/DD HH24:MI:SS.FF',
    'YYYY/MM/DD HH24:MI:SS',
    'YYYY/MM/DD',
    'YYYY.MM.DD HH24:MI:SS',
    'YYYY.MM.DD',
] -%}

{%- set fmt_european = [
    'DD-MM-YYYY HH24:MI:SS.FF',
    'DD-MM-YYYY HH24:MI:SS',
    'DD-MM-YYYY',
    'DD/MM/YYYY HH24:MI:SS.FF',
    'DD/MM/YYYY HH24:MI:SS',
    'DD/MM/YYYY',
    'DD.MM.YYYY HH24:MI:SS.FF',
    'DD.MM.YYYY HH24:MI:SS',
    'DD.MM.YYYY',
] + ([
    'DD-MM-YY HH24:MI:SS',
    'DD-MM-YY',
    'DD/MM/YY',
    'DD.MM.YY',
] if yy else []) -%}

{%- set fmt_us = [
    'MM-DD-YYYY HH24:MI:SS.FF',
    'MM-DD-YYYY HH24:MI:SS',
    'MM-DD-YYYY',
    'MM/DD/YYYY HH24:MI:SS.FF',
    'MM/DD/YYYY HH24:MI:SS',
    'MM/DD/YYYY',
    'MM.DD.YYYY HH24:MI:SS',
    'MM.DD.YYYY',
] + ([
    'MM-DD-YY',
    'MM/DD/YY',
] if yy else []) -%}

{%- set fmt_compact = [
    'YYYYMMDD',
    'YYYYMMDDHH24MISS',
] -%}

{#- Oracle: default export format is DD-MON-RR; also produces long-precision timestamps -#}
{%- set fmt_oracle = [
    'YYYY-MM-DD HH24:MI:SS.FF6',
    'YYYY-MM-DD HH24:MI:SS',
    'YYYY-MM-DD',
    'DD/MM/YYYY HH24:MI:SS.FF6',
    'DD/MM/YYYY HH24:MI:SS',
    'DD/MM/YYYY',
    'DD-MM-YYYY HH24:MI:SS.FF6',
    'DD-MM-YYYY HH24:MI:SS',
    'DD-MM-YYYY',
] -%}

{#- MSSQL: CONVERT styles 1/101 (US), 3/103 (EU), 100 and 109 (named month + 12h) -#}
{%- set fmt_mssql = [
    'MM/DD/YYYY HH24:MI:SS.FF',
    'MM/DD/YYYY HH24:MI:SS',
    'MM/DD/YYYY',
    'DD/MM/YYYY HH24:MI:SS.FF',
    'DD/MM/YYYY HH24:MI:SS',
    'DD/MM/YYYY',
    'YYYY-MM-DD HH24:MI:SS.FF',
    'YYYY-MM-DD HH24:MI:SS',
    'YYYY-MM-DD',
    'MON DD YYYY HH12:MIAM',
    'MON DD YYYY HH12:MI:SSAM',
    'MON DD YYYY HH12:MI:SS:FF3AM',
] + ([
    'MM/DD/YY',
    'DD/MM/YY',
] if yy else []) -%}

{#- PostgreSQL: ISO 8601 is the default output -#}
{%- set fmt_postgresql = [
    'YYYY-MM-DD HH24:MI:SS.FF',
    'YYYY-MM-DD HH24:MI:SS',
    'YYYY-MM-DD',
] -%}

{#- MySQL: canonical datetime format -#}
{%- set fmt_mysql = [
    'YYYY-MM-DD HH24:MI:SS',
    'YYYY-MM-DD',
] -%}

{#- SAP/ABAP: compact numeric date -#}
{%- set fmt_sap = [
    'YYYYMMDD',
    'YYYYMMDDHH24MISS',
] -%}

{%- set group_map = {
    'iso':        fmt_iso,
    'european':   fmt_european,
    'us':         fmt_us,
    'compact':    fmt_compact,
    'oracle':     fmt_oracle,
    'mssql':      fmt_mssql,
    'postgresql': fmt_postgresql,
    'mysql':      fmt_mysql,
    'sap':        fmt_sap,
} -%}

{#- ── Collect raw formats, preserving group order, deduplicating ─────── -#}

{%- set ns = namespace(seen=[], raw=[]) -%}
{%- for grp in grps -%}
  {%- if grp in group_map -%}
    {%- for fmt in group_map[grp] -%}
      {%- if fmt not in ns.seen -%}
        {%- set ns.seen = ns.seen + [fmt] -%}
        {%- set ns.raw  = ns.raw  + [fmt] -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}
{%- endfor -%}

{#- Include ISO T/Z preprocessing when iso or any ISO-producing provider is active -#}
{%- set iso_providers = ['iso', 'oracle', 'postgresql', 'mysql'] -%}
{%- set ns2 = namespace(do_iso_preprocess = false) -%}
{%- for grp in grps -%}
  {%- if grp in iso_providers -%}
    {%- set ns2.do_iso_preprocess = true -%}
  {%- endif -%}
{%- endfor -%}

{#- Named month formats — always tried when at least one language is active -#}
{%- set named_formats = [

    'DD-MON-YY HH24:MI:SS',
    'DD-MON-YY',
    'DD MON YY HH24:MI:SS',
    'DD MON YY',
    'DD-MON-YYYY HH24:MI:SS.FF',
    'DD-MON-YYYY HH24:MI:SS',
    'DD-MON-YYYY',
    'DD MON YYYY HH24:MI:SS.FF',
    'DD MON YYYY HH24:MI:SS',
    'DD MON YYYY',
    'DD/MON/YYYY HH24:MI:SS.FF',
    'DD/MON/YYYY HH24:MI:SS',
    'DD/MON/YYYY',
    'DD.MON.YYYY HH24:MI:SS',
    'DD.MON.YYYY',

    'MON DD, YY',
    'MON DD YY',
    'MON DD, YYYY HH24:MI:SS.FF',
    'MON DD, YYYY HH24:MI:SS',
    'MON DD, YYYY',
    'MON DD YYYY HH24:MI:SS.FF',
    'MON DD YYYY HH24:MI:SS',
    'MON DD YYYY',
    'MON-DD-YYYY HH24:MI:SS.FF',
    'MON-DD-YYYY HH24:MI:SS',
    'MON-DD-YYYY',
    'MON/DD/YYYY HH24:MI:SS',
    'MON/DD/YYYY',

    'YYYY-MON-DD HH24:MI:SS',
    'YYYY-MON-DD',

] -%}

{#- ── Generate SQL ───────────────────────────────────────────────────── -#}

{%- set stripped_expr = fix_weekdays(value_expr) -%}

coalesce(
{%- if 'compact' in grps or 'sap' in grps %}
{#- Compact formats first: prevent try_to_timestamp_tz from misreading YYYYMMDD as Unix epoch -#}
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'YYYYMMDDHH24MISS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'YYYYMMDD'){{ _suf }},
{%- endif %}
{%- if yy %}
{#- Two-digit year formats: before YYYY-formats and try_to_timestamp_tz to prevent e.g. YYYY-MM-DD or
    auto-detection reading "14-06-26" as year 14, or "14-Jun-26" as year 0026 -#}
{%- if 'european' in grps %}
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'DD-MM-YY HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'DD-MM-YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'DD/MM/YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'DD.MM.YY'){{ _suf }},
{%- endif %}
{%- if 'us' in grps %}
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'MM-DD-YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, 'MM/DD/YY'){{ _suf }},
{%- endif %}
{%- if cfg.languages | length > 0 %}
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(value_expr) }}, 'DD-MON-YY HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(value_expr) }}, 'DD-MON-YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(value_expr) }}, 'DD MON YY HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(value_expr) }}, 'DD MON YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(value_expr) }}, 'MON DD, YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(value_expr) }}, 'MON DD YY'){{ _suf }},
{%- endif %}
{%- endif %}
    try_to_timestamp_tz({{ value_expr }}){{ _try_tz_suf }},
{%- if cfg.languages | length > 0 %}
    try_to_timestamp_tz(replace({{ stripped_expr }}, 't', ' ')){{ _try_tz_suf }},
{%- endif %}
{%- for fmt in ns.raw %}
    {{ _pre }}try_to_timestamp_ntz({{ value_expr }}, '{{ fmt }}'){{ _suf }},
{%- endfor %}
{%- if ns2.do_iso_preprocess %}
    {{ _pre }}try_to_timestamp_ntz(replace({{ value_expr }}, 'T', ' '), 'YYYY-MM-DD HH24:MI:SS.FF'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz(replace({{ value_expr }}, 'T', ' '), 'YYYY-MM-DD HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz(replace(replace({{ value_expr }}, 'T', ' '), 'Z', ''), 'YYYY-MM-DD HH24:MI:SS.FF'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz(replace(replace({{ value_expr }}, 'T', ' '), 'Z', ''), 'YYYY-MM-DD HH24:MI:SS'){{ _suf }},
{%- endif %}
{%- if cfg.languages | length > 0 %}
{#- ── ISO T/Z preprocessing: replace T first, then strip weekday ─────────── -#}
{%- if ns2.do_iso_preprocess %}
    {{ _pre }}try_to_timestamp_ntz({{ fix_weekdays("replace(" ~ value_expr ~ ", 'T', ' ')") }}, 'YYYY-MM-DD HH24:MI:SS.FF'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_weekdays("replace(" ~ value_expr ~ ", 'T', ' ')") }}, 'YYYY-MM-DD HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_weekdays("replace(replace(" ~ value_expr ~ ", 'T', ' '), 'Z', '')") }}, 'YYYY-MM-DD HH24:MI:SS.FF'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ fix_weekdays("replace(replace(" ~ value_expr ~ ", 'T', ' '), 'Z', '')") }}, 'YYYY-MM-DD HH24:MI:SS'){{ _suf }},
{%- endif %}
{#- ── Formats after weekday stripping ───────────────────────────────────── -#}
{%- if yy %}
{%- if 'european' in grps %}
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, 'DD-MM-YY HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, 'DD-MM-YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, 'DD/MM/YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, 'DD.MM.YY'){{ _suf }},
{%- endif %}
{%- if 'us' in grps %}
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, 'MM-DD-YY'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, 'MM/DD/YY'){{ _suf }},
{%- endif %}
{%- endif %}
{%- for fmt in ns.raw %}
    {{ _pre }}try_to_timestamp_ntz({{ stripped_expr }}, '{{ fmt }}'){{ _suf }},
{%- endfor %}
{%- if ns2.do_iso_preprocess %}
    {{ _pre }}try_to_timestamp_ntz(replace({{ stripped_expr }}, 't', ' '), 'YYYY-MM-DD HH24:MI:SS.FF'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz(replace({{ stripped_expr }}, 't', ' '), 'YYYY-MM-DD HH24:MI:SS'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz(replace(replace({{ stripped_expr }}, 't', ' '), 'z', ''), 'YYYY-MM-DD HH24:MI:SS.FF'){{ _suf }},
    {{ _pre }}try_to_timestamp_ntz(replace(replace({{ stripped_expr }}, 't', ' '), 'z', ''), 'YYYY-MM-DD HH24:MI:SS'){{ _suf }},
{%- endif %}
{#- ── Named month formats (weekday stripped + month normalised) ──────────── -#}
{%- for fmt in named_formats %}
    {{ _pre }}try_to_timestamp_ntz({{ fix_months(stripped_expr) }}, '{{ fmt }}'){{ _suf }}{% if not loop.last %},{% endif %}

{%- endfor %}
{%- endif %}
)

{% endmacro %}
