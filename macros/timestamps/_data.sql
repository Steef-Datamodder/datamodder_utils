{%- macro _data() -%}
{#-
  Central data store for the timestamp macro set.
  Referenced by fix_months, fix_weekdays, and create_test_to_timestamp_tz_safe.

  To add a language: add entries to months[] and weekdays[] here;
  the logic macros (fix_months, fix_weekdays) need no changes.

  months[]
    out  — 3-letter English abbreviation Snowflake accepts (jan … dec)
    rx[] — patterns ordered longest/most-specific first
      p  — regex pattern (applied after lower/trim)
      l  — languages this pattern belongs to; [] = universal abbreviation

  weekdays[]
    rx[] — patterns ordered longest/most-specific first
      p  — regex pattern (applied after lower/trim)
      l  — languages this pattern belongs to
    (No 'out' — weekday names are stripped, not normalised.)

  test_values[]
    Flat list of date strings covering all active format groups and
    languages across five reference dates:
      • 2026-06-14 16:00:00  (een week geleden, 16:00 — zondag)
      • 2024-02-29 11:00:00  (laatste schrikkeldag, 11:00 — donderdag)
      • 2024-02-29 23:00:00  (laatste schrikkeldag, 23:00 — donderdag)
      • 1936-01-01 23:00:00  (1 jan 1936, 23:00 — woensdag)
      • 1905-01-01            (1 jan 1905 — zondag)

  Notes:
    • Longer/more-specific patterns come before shorter ones so the
      regex alternation tries them first (e.g. segunda-feira before segunda).
    • Weekday abbreviations are intentionally omitted to avoid false matches
      with month abbreviations (e.g. French mar. = Mardi AND March).
-#}

{#- ── Months ────────────────────────────────────────────────────────────── -#}

{%- set months = [

  { 'out': 'Jan', 'rx': [
      { 'p': 'january',       'l': ['english'] },
      { 'p': 'januari',       'l': ['dutch', 'swedish'] },
      { 'p': 'janvier',       'l': ['french'] },
      { 'p': 'januar',        'l': ['german', 'danish', 'norwegian'] },
      { 'p': 'enero',         'l': ['spanish'] },
      { 'p': 'janeiro',       'l': ['portuguese'] },
      { 'p': 'stycze[nń]',    'l': ['polish'] },
      { 'p': 'tammikuu',      'l': ['finnish'] },
      { 'p': 'ichigatsu',     'l': ['japanese'] },
      { 'p': 'janvari',       'l': ['hindi'] },
      { 'p': 'janv',      'l': ['french'] },
      { 'p': 'sty',       'l': ['polish'] },
      { 'p': 'jan',       'l': [] }
  ] },

  { 'out': 'Feb', 'rx': [
      { 'p': 'february',      'l': ['english'] },
      { 'p': 'februari',      'l': ['dutch', 'swedish'] },
      { 'p': 'f[eé]vrier',    'l': ['french'] },
      { 'p': 'februar',       'l': ['german', 'danish', 'norwegian'] },
      { 'p': 'febrero',       'l': ['spanish'] },
      { 'p': 'fevereiro',     'l': ['portuguese'] },
      { 'p': 'luty',          'l': ['polish'] },
      { 'p': 'helmikuu',      'l': ['finnish'] },
      { 'p': 'nigatsu',       'l': ['japanese'] },
      { 'p': 'pharvari',      'l': ['hindi'] },
      { 'p': 'farvari',       'l': ['hindi'] },
      { 'p': 'f[eé]vr',   'l': ['french'] },
      { 'p': 'f[eé]v',    'l': ['french'] },
      { 'p': 'lut',       'l': ['polish'] },
      { 'p': 'feb',       'l': [] }
  ] },

  { 'out': 'Mar', 'rx': [
      { 'p': 'march',         'l': ['english', 'hindi'] },
      { 'p': 'maart',         'l': ['dutch'] },
      { 'p': 'mars',          'l': ['french', 'swedish', 'danish', 'norwegian'] },
      { 'p': 'm[aä]rz',       'l': ['german'] },
      { 'p': 'marzo',         'l': ['spanish'] },
      { 'p': 'mar[cç]o',      'l': ['portuguese'] },
      { 'p': 'marzec',        'l': ['polish'] },
      { 'p': 'maaliskuu',     'l': ['finnish'] },
      { 'p': 'sangatsu',      'l': ['japanese'] },
      { 'p': 'mrz',       'l': ['german'] },
      { 'p': 'mrt',       'l': ['dutch'] },
      { 'p': 'mar',       'l': [] }
  ] },

  { 'out': 'Apr', 'rx': [
      { 'p': 'april',         'l': ['english', 'dutch', 'german', 'danish', 'swedish', 'norwegian'] },
      { 'p': 'avril',         'l': ['french'] },
      { 'p': 'abril',         'l': ['spanish', 'portuguese'] },
      { 'p': 'kwiecie[nń]',   'l': ['polish'] },
      { 'p': 'huhtikuu',      'l': ['finnish'] },
      { 'p': 'shigatsu',      'l': ['japanese'] },
      { 'p': 'aprayl',        'l': ['hindi'] },
      { 'p': 'abr',       'l': ['spanish', 'portuguese'] },
      { 'p': 'kwi',       'l': ['polish'] },
      { 'p': 'avr',       'l': ['french'] },
      { 'p': 'apr',       'l': [] }
  ] },

  { 'out': 'May', 'rx': [
      { 'p': 'may',           'l': ['english'] },
      { 'p': 'mei',           'l': ['dutch'] },
      { 'p': 'mai',           'l': ['french', 'german', 'hindi'] },
      { 'p': 'maj',           'l': ['swedish', 'polish'] },
      { 'p': 'mayo',          'l': ['spanish'] },
      { 'p': 'maio',          'l': ['portuguese'] },
      { 'p': 'toukokuu',      'l': ['finnish'] },
      { 'p': 'gogatsu',       'l': ['japanese'] }
  ] },

  { 'out': 'Jun', 'rx': [
      { 'p': 'june',          'l': ['english'] },
      { 'p': 'juni',          'l': ['dutch', 'german', 'danish', 'swedish', 'norwegian'] },
      { 'p': 'juin',          'l': ['french'] },
      { 'p': 'junio',         'l': ['spanish'] },
      { 'p': 'junho',         'l': ['portuguese'] },
      { 'p': 'czerwiec',      'l': ['polish'] },
      { 'p': 'kes[aä]kuu',    'l': ['finnish'] },
      { 'p': 'rokugatsu',     'l': ['japanese'] },
      { 'p': 'cze',       'l': ['polish'] },
      { 'p': 'jun',       'l': [] }
  ] },

  { 'out': 'Jul', 'rx': [
      { 'p': 'july',          'l': ['english'] },
      { 'p': 'juli',          'l': ['dutch', 'german', 'danish', 'swedish', 'norwegian'] },
      { 'p': 'juillet',       'l': ['french'] },
      { 'p': 'julio',         'l': ['spanish'] },
      { 'p': 'julho',         'l': ['portuguese'] },
      { 'p': 'lipiec',        'l': ['polish'] },
      { 'p': 'hein[aä]kuu',   'l': ['finnish'] },
      { 'p': 'shichigatsu',   'l': ['japanese'] },
      { 'p': 'julai',         'l': ['hindi'] },
      { 'p': 'juil',      'l': ['french'] },
      { 'p': 'lip',       'l': ['polish'] },
      { 'p': 'jul',       'l': [] }
  ] },

  { 'out': 'Aug', 'rx': [
      { 'p': 'augustus',      'l': ['dutch'] },
      { 'p': 'augusti',       'l': ['swedish'] },
      { 'p': 'august',        'l': ['english', 'german', 'danish', 'norwegian'] },
      { 'p': 'ao[uû]t',       'l': ['french'] },
      { 'p': 'agosto',        'l': ['spanish', 'portuguese'] },
      { 'p': 'sierpie[nń]',   'l': ['polish'] },
      { 'p': 'elokuu',        'l': ['finnish'] },
      { 'p': 'hachigatsu',    'l': ['japanese'] },
      { 'p': 'agast',         'l': ['hindi'] },
      { 'p': 'ago',       'l': ['spanish', 'portuguese'] },
      { 'p': 'sie',       'l': ['polish'] },
      { 'p': 'aug',       'l': [] }
  ] },

  { 'out': 'Sep', 'rx': [
      { 'p': 'september',     'l': ['english', 'dutch', 'german', 'danish', 'swedish', 'norwegian'] },
      { 'p': 'septembre',     'l': ['french'] },
      { 'p': 'septiembre',    'l': ['spanish'] },
      { 'p': 'setiembre',     'l': ['spanish'] },
      { 'p': 'setembro',      'l': ['portuguese'] },
      { 'p': 'wrzesie[nń]',   'l': ['polish'] },
      { 'p': 'syyskuu',       'l': ['finnish'] },
      { 'p': 'kugatsu',       'l': ['japanese'] },
      { 'p': 'sitambar',      'l': ['hindi'] },
      { 'p': 'set',       'l': ['portuguese'] },
      { 'p': 'wrz',       'l': ['polish'] },
      { 'p': 'sept',      'l': [] },
      { 'p': 'sep',       'l': [] }
  ] },

  { 'out': 'Oct', 'rx': [
      { 'p': 'october',           'l': ['english'] },
      { 'p': 'oktober',           'l': ['dutch', 'german', 'danish', 'swedish', 'norwegian'] },
      { 'p': 'octobre',           'l': ['french'] },
      { 'p': 'octubre',           'l': ['spanish'] },
      { 'p': 'outubro',           'l': ['portuguese'] },
      { 'p': 'pa[zź]dziernik',    'l': ['polish'] },
      { 'p': 'lokakuu',           'l': ['finnish'] },
      { 'p': 'j[uū]u?gatsu',      'l': ['japanese'] },
      { 'p': 'aktubar',           'l': ['hindi'] },
      { 'p': 'out',           'l': ['portuguese'] },
      { 'p': 'pa[zź]',        'l': ['polish'] },
      { 'p': 'o[ck]t',        'l': [] }
  ] },

  { 'out': 'Nov', 'rx': [
      { 'p': 'november',          'l': ['english', 'dutch', 'german', 'danish', 'swedish', 'norwegian'] },
      { 'p': 'novembre',          'l': ['french'] },
      { 'p': 'noviembre',         'l': ['spanish'] },
      { 'p': 'novembro',          'l': ['portuguese'] },
      { 'p': 'listopad',          'l': ['polish'] },
      { 'p': 'marraskuu',         'l': ['finnish'] },
      { 'p': 'j[uū]u?ichigatsu',  'l': ['japanese'] },
      { 'p': 'navambar',          'l': ['hindi'] },
      { 'p': 'lis',           'l': ['polish'] },
      { 'p': 'nov',           'l': [] }
  ] },

  { 'out': 'Dec', 'rx': [
      { 'p': 'december',          'l': ['english', 'dutch', 'danish', 'swedish'] },
      { 'p': 'd[eé]cembre',       'l': ['french'] },
      { 'p': 'dezember',          'l': ['german'] },
      { 'p': 'diciembre',         'l': ['spanish'] },
      { 'p': 'dezembro',          'l': ['portuguese'] },
      { 'p': 'desember',          'l': ['norwegian'] },
      { 'p': 'grudzie[nń]',       'l': ['polish'] },
      { 'p': 'joulukuu',          'l': ['finnish'] },
      { 'p': 'j[uū]u?nigatsu',    'l': ['japanese'] },
      { 'p': 'disambar',          'l': ['hindi'] },
      { 'p': 'dic',           'l': ['spanish'] },
      { 'p': 'gru',           'l': ['polish'] },
      { 'p': 'd[eé]c',        'l': ['french'] },
      { 'p': 'dez',           'l': ['german', 'portuguese'] },
      { 'p': 'dec',           'l': [] }
  ] }

] -%}

{#- ── Weekdays ──────────────────────────────────────────────────────────── -#}

{%- set weekdays = [

  { 'rx': [
      { 'p': 'monday',              'l': ['english'] },
      { 'p': 'maandag',             'l': ['dutch'] },
      { 'p': 'lundi',               'l': ['french'] },
      { 'p': 'montag',              'l': ['german'] },
      { 'p': 'lunes',               'l': ['spanish'] },
      { 'p': 'segunda-feira',       'l': ['portuguese'] },
      { 'p': 'segunda',             'l': ['portuguese'] },
      { 'p': 'poniedzia[lł]ek',     'l': ['polish'] },
      { 'p': 'mandag',              'l': ['danish', 'norwegian'] },
      { 'p': 'm[aå]ndag',           'l': ['swedish'] },
      { 'p': 'maanantai',           'l': ['finnish'] },
      { 'p': 'somav?aar?',          'l': ['hindi'] },
      { 'p': 'getsuy[oō][ou]?bi',  'l': ['japanese'] }
  ] },

  { 'rx': [
      { 'p': 'tuesday',             'l': ['english'] },
      { 'p': 'dinsdag',             'l': ['dutch'] },
      { 'p': 'mardi',               'l': ['french'] },
      { 'p': 'dienstag',            'l': ['german'] },
      { 'p': 'martes',              'l': ['spanish'] },
      { 'p': 'ter[cç]a-feira',      'l': ['portuguese'] },
      { 'p': 'ter[cç]a',            'l': ['portuguese'] },
      { 'p': 'wtorek',              'l': ['polish'] },
      { 'p': 'tirsdag',             'l': ['danish', 'norwegian'] },
      { 'p': 'tisdag',              'l': ['swedish'] },
      { 'p': 'tiistai',             'l': ['finnish'] },
      { 'p': 'mangalav?aar?',       'l': ['hindi'] },
      { 'p': 'kay[oō][ou]?bi',     'l': ['japanese'] }
  ] },

  { 'rx': [
      { 'p': 'wednesday',           'l': ['english'] },
      { 'p': 'woensdag',            'l': ['dutch'] },
      { 'p': 'mercredi',            'l': ['french'] },
      { 'p': 'mittwoch',            'l': ['german'] },
      { 'p': 'mi[eé]rcoles',        'l': ['spanish'] },
      { 'p': 'quarta-feira',        'l': ['portuguese'] },
      { 'p': 'quarta',              'l': ['portuguese'] },
      { 'p': '[sś]roda',            'l': ['polish'] },
      { 'p': 'onsdag',              'l': ['danish', 'swedish', 'norwegian'] },
      { 'p': 'keskiviikko',         'l': ['finnish'] },
      { 'p': 'budhav?aar?',         'l': ['hindi'] },
      { 'p': 'suiy[oō][ou]?bi',    'l': ['japanese'] }
  ] },

  { 'rx': [
      { 'p': 'thursday',            'l': ['english'] },
      { 'p': 'donderdag',           'l': ['dutch'] },
      { 'p': 'jeudi',               'l': ['french'] },
      { 'p': 'donnerstag',          'l': ['german'] },
      { 'p': 'jueves',              'l': ['spanish'] },
      { 'p': 'quinta-feira',        'l': ['portuguese'] },
      { 'p': 'quinta',              'l': ['portuguese'] },
      { 'p': 'czwartek',            'l': ['polish'] },
      { 'p': 'torsdag',             'l': ['danish', 'swedish', 'norwegian'] },
      { 'p': 'torstai',             'l': ['finnish'] },
      { 'p': 'guruv?aar?',          'l': ['hindi'] },
      { 'p': 'brihaspativar',       'l': ['hindi'] },
      { 'p': 'mokuy[oō][ou]?bi',   'l': ['japanese'] }
  ] },

  { 'rx': [
      { 'p': 'friday',              'l': ['english'] },
      { 'p': 'vrijdag',             'l': ['dutch'] },
      { 'p': 'vendredi',            'l': ['french'] },
      { 'p': 'freitag',             'l': ['german'] },
      { 'p': 'viernes',             'l': ['spanish'] },
      { 'p': 'sexta-feira',         'l': ['portuguese'] },
      { 'p': 'sexta',               'l': ['portuguese'] },
      { 'p': 'pi[aą]tek',           'l': ['polish'] },
      { 'p': 'fredag',              'l': ['danish', 'swedish', 'norwegian'] },
      { 'p': 'perjantai',           'l': ['finnish'] },
      { 'p': 'shukrav?aar?',        'l': ['hindi'] },
      { 'p': 'kin.?y[oō][ou]?bi',  'l': ['japanese'] }
  ] },

  { 'rx': [
      { 'p': 'saturday',            'l': ['english'] },
      { 'p': 'zaterdag',            'l': ['dutch'] },
      { 'p': 'samedi',              'l': ['french'] },
      { 'p': 'samstag',             'l': ['german'] },
      { 'p': 'sonnabend',           'l': ['german'] },
      { 'p': 's[aá]bado',           'l': ['spanish', 'portuguese'] },
      { 'p': 'sobota',              'l': ['polish'] },
      { 'p': 'l[øo]rdag',           'l': ['danish', 'norwegian'] },
      { 'p': 'l[öo]rdag',           'l': ['swedish'] },
      { 'p': 'lauantai',            'l': ['finnish'] },
      { 'p': 'shaniv?aar?',         'l': ['hindi'] },
      { 'p': 'doy[oō][ou]?bi',     'l': ['japanese'] }
  ] },

  { 'rx': [
      { 'p': 'sunday',              'l': ['english'] },
      { 'p': 'zondag',              'l': ['dutch'] },
      { 'p': 'dimanche',            'l': ['french'] },
      { 'p': 'sonntag',             'l': ['german'] },
      { 'p': 'domingo',             'l': ['spanish', 'portuguese'] },
      { 'p': 'niedziela',           'l': ['polish'] },
      { 'p': 's[øo]ndag',           'l': ['danish', 'norwegian'] },
      { 'p': 's[öo]ndag',           'l': ['swedish'] },
      { 'p': 'sunnuntai',           'l': ['finnish'] },
      { 'p': 'raviv?aar?',          'l': ['hindi'] },
      { 'p': 'nichiy[oō][ou]?bi',  'l': ['japanese'] }
  ] }

] -%}

{#- ── Test values ───────────────────────────────────────────────────────── -#}

{#- 2026-06-14 16:00:00  (een week geleden, 16:00 — zondag / Sunday / dimanche / Sonntag) -#}
{%- set _tv_wk = [
    '2026-06-14 16:00:00',
    '2026-06-14T16:00:00',
    '2026-06-14T16:00:00Z',
    '2026-06-14',
    '2026/06/14 16:00:00',
    '2026.06.14 16:00:00',
    '14-06-2026 16:00:00',
    '14/06/2026 16:00:00',
    '14.06.2026 16:00:00',
    '14-06-2026',
    '06/14/2026 16:00:00',
    '06-14-2026',
    '20260614',
    '14 Jun 2026 16:00:00',
    '14 June 2026 16:00:00',
    'June 14, 2026',
    '14 juni 2026 16:00:00',
    '14 juin 2026 16:00:00',
    '14 Juni 2026 16:00:00',
    '14 junio 2026 16:00:00',
    '14 junho 2026 16:00:00',
    '14 czerwiec 2026 16:00:00',
    'zondag 14-06-2026 16:00:00',
    'zondag 14 juni 2026 16:00:00',
    'Sunday, 14 June 2026 16:00:00',
    'Sunday 14-06-2026 16:00:00',
    'dimanche 14 juin 2026 16:00:00',
    'Sonntag, 14 Juni 2026 16:00:00',
    'domingo 14 junio 2026 16:00:00'
] -%}

{#- 2024-02-29 11:00:00  (laatste schrikkeldag, 11:00 — donderdag / Thursday / jeudi / Donnerstag) -#}
{%- set _tv_ld1 = [
    '2024-02-29 11:00:00',
    '2024-02-29T11:00:00',
    '2024-02-29',
    '29-02-2024 11:00:00',
    '29/02/2024 11:00:00',
    '29.02.2024 11:00:00',
    '02/29/2024 11:00:00',
    '20240229',
    '29 Feb 2024 11:00:00',
    '29 February 2024 11:00:00',
    'February 29, 2024',
    '29 februari 2024 11:00:00',
    '29 février 2024 11:00:00',
    '29 Februar 2024 11:00:00',
    '29 febrero 2024 11:00:00',
    '29 fevereiro 2024 11:00:00',
    'donderdag 29-02-2024 11:00:00',
    'Thursday, 29 February 2024 11:00:00',
    'jeudi 29 février 2024 11:00:00',
    'Donnerstag, 29 Februar 2024 11:00:00'
] -%}

{#- 2024-02-29 23:00:00  (laatste schrikkeldag, 23:00 — donderdag) -#}
{%- set _tv_ld2 = [
    '2024-02-29 23:00:00',
    '2024-02-29T23:00:00',
    '29-02-2024 23:00:00',
    '29/02/2024 23:00:00',
    '29.02.2024 23:00:00',
    '02/29/2024 23:00:00',
    '29 Feb 2024 23:00:00',
    '29 februari 2024 23:00:00',
    'donderdag 29 februari 2024 23:00:00',
    'Thursday, 29 February 2024 23:00:00'
] -%}

{#- 1936-01-01 23:00:00  (1 jan 1936, 23:00 — woensdag / Wednesday / mercredi / Mittwoch) -#}
{%- set _tv_1936 = [
    '1936-01-01 23:00:00',
    '1936-01-01T23:00:00',
    '01-01-1936 23:00:00',
    '01/01/1936 23:00:00',
    '01.01.1936 23:00:00',
    '19360101',
    '1 Jan 1936 23:00:00',
    '1 January 1936 23:00:00',
    'January 1, 1936',
    '1 januari 1936 23:00:00',
    '1 janvier 1936 23:00:00',
    '1 Januar 1936 23:00:00',
    '1 enero 1936 23:00:00',
    'woensdag 1 januari 1936 23:00:00',
    'Wednesday, 1 January 1936 23:00:00',
    'mercredi 1 janvier 1936 23:00:00',
    'Mittwoch, 1 Januar 1936 23:00:00'
] -%}

{#- 1905-01-01  (1 jan 1905 — zondag / Sunday / dimanche / Sonntag) -#}
{%- set _tv_1905 = [
    '1905-01-01',
    '01-01-1905',
    '01/01/1905',
    '01.01.1905',
    '19050101',
    '1 Jan 1905',
    '1 January 1905',
    'January 1, 1905',
    '1 januari 1905',
    '1 janvier 1905',
    '1 Januar 1905',
    '1 enero 1905',
    'zondag 1 januari 1905',
    'Sunday, 1 January 1905',
    'dimanche 1 janvier 1905',
    'Sonntag, 1 Januar 1905'
] -%}

{#- ── Extra test values — fills every remaining COALESCE branch ──────────── -#}

{#- 2026-06-14 16:00:00: numeric gaps, all named-format patterns, extra languages -#}
{%- set _tv_extra_wk = [

    '2026/06/14',
    '2026.06.14',
    '14/06/2026',
    '14.06.2026',
    '06/14/2026',
    '06.14.2026 16:00:00',
    '06.14.2026',
    '14-06-26 16:00:00',
    '14-06-26',
    '14/06/26',
    '14.06.26',
    '06-14-26',
    '06/14/26',
    '20260614160000',
    '2026-06-14 16:00:00.123456',
    '14-06-2026 16:00:00.123456',
    '2026-06-14T16:00:00.123456',
    '2026-06-14T16:00:00.123456Z',

    '14-Jun-2026 16:00:00',
    '14-Jun-2026',
    '14/Jun/2026 16:00:00',
    '14/Jun/2026',
    '14.Jun.2026 16:00:00',
    '14.Jun.2026',
    '14-Jun-26 16:00:00',
    '14-Jun-26',
    '14 Jun 26 16:00:00',
    '14 Jun 26',

    'Jun 14 2026 16:00:00',
    'Jun 14 2026',
    'Jun 14, 2026 16:00:00',
    'Jun-14-2026 16:00:00',
    'Jun-14-2026',
    'Jun/14/2026 16:00:00',
    'Jun/14/2026',
    'Jun 14, 26',
    'Jun 14 26',
    '2026-Jun-14 16:00:00',
    '2026-Jun-14',

    '14 kesäkuu 2026 16:00:00',
    '14 rokugatsu 2026 16:00:00',
    '14 juni 2026',
    '14 juin 2026',

    'zondag 2026-06-14T16:00:00',
    'zondag 14-Jun-2026 16:00:00',
    'Sunday, 2026-Jun-14',
    'dimanche 14-juin-2026 16:00:00',
    'Sonntag, Jun 14 2026'

] -%}

{#- 2024-02-29 11:00:00: numeric gaps, all named-format patterns, extra languages -#}
{%- set _tv_extra_ld1 = [

    '2024/02/29',
    '2024.02.29',
    '29/02/2024',
    '29.02.2024',
    '02/29/2024',
    '20240229110000',
    '2024-02-29 11:00:00.123456',

    '29-Feb-2024 11:00:00',
    '29-Feb-2024',
    '29/Feb/2024 11:00:00',
    '29/Feb/2024',
    '29.Feb.2024 11:00:00',
    '29.Feb.2024',

    'Feb 29 2024 11:00:00',
    'Feb 29 2024',
    'Feb 29, 2024 11:00:00',
    'Feb-29-2024 11:00:00',
    'Feb-29-2024',
    'Feb/29/2024 11:00:00',
    'Feb/29/2024',
    '2024-Feb-29 11:00:00',
    '2024-Feb-29',

    '29 helmikuu 2024 11:00:00',
    '29 nigatsu 2024 11:00:00',
    'donderdag 29-Feb-2024 11:00:00',
    'Thursday, Feb 29 2024 11:00:00'

] -%}

{#- 2024-02-29 23:00:00: named formats at 23:00 not yet covered -#}
{%- set _tv_extra_ld2 = [
    '29-Feb-2024 23:00:00',
    'Feb 29, 2024 23:00:00',
    '2024-Feb-29 23:00:00',
    'donderdag 29/Feb/2024 23:00:00'
] -%}

{#- 1936-01-01 23:00:00: numeric gaps, all named-format patterns, extra languages -#}
{%- set _tv_extra_1936 = [

    '1936/01/01 23:00:00',
    '1936/01/01',
    '1936.01.01 23:00:00',
    '01/01/1936',

    '1-Jan-1936 23:00:00',
    '1-Jan-1936',
    '1/Jan/1936',
    '1.Jan.1936 23:00:00',
    '1.Jan.1936',

    'Jan 1 1936 23:00:00',
    'Jan 1 1936',
    'Jan 1, 1936 23:00:00',
    'Jan-1-1936 23:00:00',
    'Jan-1-1936',
    'Jan/1/1936 23:00:00',
    'Jan/1/1936',
    '1936-Jan-01 23:00:00',
    '1936-Jan-01',

    '1 tammikuu 1936 23:00:00',
    '1 ichigatsu 1936 23:00:00',
    'woensdag 1-Jan-1936 23:00:00'

] -%}

{#- 1905-01-01: numeric gaps, all named-format patterns, extra languages -#}
{%- set _tv_extra_1905 = [

    '1905/01/01',
    '1905.01.01',

    '1-Jan-1905',
    '1/Jan/1905',
    '1.Jan.1905',

    'Jan 1 1905',
    'Jan-1-1905',
    'Jan/1/1905',
    '1905-Jan-01',

    '1 tammikuu 1905',
    '1 ichigatsu 1905',
    'zondag 1-Jan-1905'

] -%}

{#- ── Return ─────────────────────────────────────────────────────────────── -#}

{{ return({
    'months':      months,
    'weekdays':    weekdays,
    'test_values': _tv_wk      + _tv_extra_wk
                 + _tv_ld1     + _tv_extra_ld1
                 + _tv_ld2     + _tv_extra_ld2
                 + _tv_1936    + _tv_extra_1936
                 + _tv_1905    + _tv_extra_1905
}) }}

{%- endmacro -%}
