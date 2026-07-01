-- Adjust these two values before running.
set db  = 'datamodder';
set sch = 'utils';

-- Derived names (no need to change these)
set holidays  = $db || '.' || $sch || '.holidays';
set datenames = $db || '.' || $sch || '.datenames';

create database if not exists identifier($db);
create schema  if not exists identifier($db || '.' || $sch);

-- ── Public holidays (NL, BE, DE, FR, GB, ES, IT, PT) 2000-2100 ───────────────────────────────────────

create or replace table identifier($holidays) as

with years as (
    select row_number() over (order by seq4()) + 1999 as yr
      from table(generator(rowcount => 101))

), easter_step1 as (
    select yr
         , mod(yr, 19) as a
         , mod(yr, 4) as b
         , mod(yr, 7) as c
      from years

), easter_step2 as (
    select yr, a, b, c
         , mod(19 * a + 24, 30)                                               as d
         , mod(2 * b + 4 * c + 6 * mod(19 * a + 24, 30) + 5, 7)             as e
      from easter_step1

), easter as (
    select yr
         , dateadd('day',
               21 + d + e
               - iff(d = 29 and e = 6,            7, 0)
               - iff(d = 28 and e = 6 and a > 10, 7, 0),
               to_date(yr::string || '-03-01', 'YYYY-MM-DD'))                 as easter_sunday
      from easter_step2

), nl as (
    -- Sources: https://www.rijksoverheid.nl/onderwerpen/feestdagen
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'NL' from years union all
    select dateadd('day', -2, easter_sunday), 'Good Friday', 'NL' from easter union all
    select easter_sunday, 'Easter Sunday', 'NL' from easter union all
    select dateadd('day', 1, easter_sunday), 'Easter Monday', 'NL' from easter union all
    select iff(dayofweek(to_date(yr::string || '-04-27', 'YYYY-MM-DD')) = 0,
               to_date(yr::string || '-04-26', 'YYYY-MM-DD'),
               to_date(yr::string || '-04-27', 'YYYY-MM-DD')),
           'King\'s Day', 'NL' from years union all
    select to_date(yr::string || '-05-05', 'YYYY-MM-DD'), 'Liberation Day', 'NL' from years union all
    select dateadd('day', 39, easter_sunday), 'Ascension Day', 'NL' from easter union all
    select dateadd('day', 49, easter_sunday), 'Whit Sunday', 'NL' from easter union all
    select dateadd('day', 50, easter_sunday), 'Whit Monday', 'NL' from easter union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'NL' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'Boxing Day', 'NL' from years

), be as (
    -- Sources: https://www.belgium.be/nl/werk/feestdagen
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'BE' from years union all
    select easter_sunday, 'Easter Sunday', 'BE' from easter union all
    select dateadd('day', 1, easter_sunday), 'Easter Monday', 'BE' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day', 'BE' from years union all
    select dateadd('day', 39, easter_sunday), 'Ascension Day', 'BE' from easter union all
    select dateadd('day', 49, easter_sunday), 'Whit Sunday', 'BE' from easter union all
    select dateadd('day', 50, easter_sunday), 'Whit Monday', 'BE' from easter union all
    select to_date(yr::string || '-07-21', 'YYYY-MM-DD'), 'Belgian National Day', 'BE' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption', 'BE' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints\' Day', 'BE' from years union all
    select to_date(yr::string || '-11-11', 'YYYY-MM-DD'), 'Armistice Day', 'BE' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'BE' from years

), de as (
    -- Sources: https://www.bmi.bund.de/DE/themen/verfassung/staatliche-symbole/nationale-feiertage
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'DE' from years union all
    select dateadd('day', -2, easter_sunday), 'Good Friday', 'DE' from easter union all
    select easter_sunday, 'Easter Sunday', 'DE' from easter union all
    select dateadd('day', 1, easter_sunday), 'Easter Monday', 'DE' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day', 'DE' from years union all
    select dateadd('day', 39, easter_sunday), 'Ascension Day', 'DE' from easter union all
    select dateadd('day', 49, easter_sunday), 'Whit Sunday', 'DE' from easter union all
    select dateadd('day', 50, easter_sunday), 'Whit Monday', 'DE' from easter union all
    select to_date(yr::string || '-10-03', 'YYYY-MM-DD'), 'German Unity Day', 'DE' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'DE' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'Boxing Day', 'DE' from years

), fr as (
    -- Sources: https://www.service-public.fr/particuliers/vosdroits/F2405
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'FR' from years union all
    select dateadd('day', 1, easter_sunday), 'Easter Monday', 'FR' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day', 'FR' from years union all
    select to_date(yr::string || '-05-08', 'YYYY-MM-DD'), 'Victory in Europe Day', 'FR' from years union all
    select dateadd('day', 39, easter_sunday), 'Ascension Day', 'FR' from easter union all
    select dateadd('day', 50, easter_sunday), 'Whit Monday', 'FR' from easter union all
    select to_date(yr::string || '-07-14', 'YYYY-MM-DD'), 'Bastille Day', 'FR' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption', 'FR' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints\' Day', 'FR' from years union all
    select to_date(yr::string || '-11-11', 'YYYY-MM-DD'), 'Armistice Day', 'FR' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'FR' from years

), gb as (
    -- Sources: https://www.gov.uk/bank-holidays
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'GB' from years union all
    select dateadd('day', -2, easter_sunday), 'Good Friday', 'GB' from easter union all
    select dateadd('day', 1, easter_sunday), 'Easter Monday', 'GB' from easter union all
    -- Early May Bank Holiday: first Monday of May
    select dateadd('day',
               mod(8 - dayofweekiso(to_date(yr::string || '-05-01', 'YYYY-MM-DD')), 7),
               to_date(yr::string || '-05-01', 'YYYY-MM-DD')),
           'Early May Bank Holiday', 'GB' from years union all
    -- Spring Bank Holiday: last Monday of May
    select dateadd('day',
               -(dayofweekiso(to_date(yr::string || '-05-31', 'YYYY-MM-DD')) - 1),
               to_date(yr::string || '-05-31', 'YYYY-MM-DD')),
           'Spring Bank Holiday', 'GB' from years union all
    -- Summer Bank Holiday: last Monday of August
    select dateadd('day',
               -(dayofweekiso(to_date(yr::string || '-08-31', 'YYYY-MM-DD')) - 1),
               to_date(yr::string || '-08-31', 'YYYY-MM-DD')),
           'Summer Bank Holiday', 'GB' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'GB' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'Boxing Day', 'GB' from years

), es as (
    -- Sources: https://administracion.gob.es/pag_Home/atencionCiudadana/calendarios/fiestas-laborales-nacionales.html
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'ES' from years union all
    select to_date(yr::string || '-01-06', 'YYYY-MM-DD'), 'Epiphany', 'ES' from years union all
    select dateadd('day', -2, easter_sunday), 'Good Friday', 'ES' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day', 'ES' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption', 'ES' from years union all
    select to_date(yr::string || '-10-12', 'YYYY-MM-DD'), 'National Day', 'ES' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints\' Day', 'ES' from years union all
    select to_date(yr::string || '-12-06', 'YYYY-MM-DD'), 'Constitution Day', 'ES' from years union all
    select to_date(yr::string || '-12-08', 'YYYY-MM-DD'), 'Immaculate Conception', 'ES' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'ES' from years

), it as (
    -- Sources: https://www.governo.it/it/approfondimento/giorni-festivi
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'IT' from years union all
    select to_date(yr::string || '-01-06', 'YYYY-MM-DD'), 'Epiphany', 'IT' from years union all
    select easter_sunday, 'Easter Sunday', 'IT' from easter union all
    select dateadd('day', 1, easter_sunday), 'Easter Monday', 'IT' from easter union all
    select to_date(yr::string || '-04-25', 'YYYY-MM-DD'), 'Liberation Day', 'IT' from years union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day', 'IT' from years union all
    select to_date(yr::string || '-06-02', 'YYYY-MM-DD'), 'Republic Day', 'IT' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption', 'IT' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints\' Day', 'IT' from years union all
    select to_date(yr::string || '-12-08', 'YYYY-MM-DD'), 'Immaculate Conception', 'IT' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'IT' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'St. Stephen\'s Day', 'IT' from years

), pt as (
    -- Sources: https://eportugal.gov.pt/servicos/consultar-calendario-de-feriados-obrigatorios-em-portugal
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year\'s Day', 'PT' from years union all
    select dateadd('day', -2, easter_sunday), 'Good Friday', 'PT' from easter union all
    select easter_sunday, 'Easter Sunday', 'PT' from easter union all
    select to_date(yr::string || '-04-25', 'YYYY-MM-DD'), 'Freedom Day', 'PT' from years union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day', 'PT' from years union all
    select dateadd('day', 60, easter_sunday), 'Corpus Christi', 'PT' from easter union all
    select to_date(yr::string || '-06-10', 'YYYY-MM-DD'), 'Portugal Day', 'PT' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption', 'PT' from years union all
    select to_date(yr::string || '-10-05', 'YYYY-MM-DD'), 'Republic Day', 'PT' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints\' Day', 'PT' from years union all
    select to_date(yr::string || '-12-01', 'YYYY-MM-DD'), 'Restoration of Independence', 'PT' from years union all
    select to_date(yr::string || '-12-08', 'YYYY-MM-DD'), 'Immaculate Conception', 'PT' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'PT' from years

)

select * from nl
union all select * from be
union all select * from de
union all select * from fr
union all select * from gb
union all select * from es
union all select * from it
union all select * from pt
;

-- ── Date names (weekday and month names per language) ──────────────────────────────────────────────

create or replace table identifier($datenames) as

-- NL (Dutch)
select 'nl' as language, 'weekday' as type, 1 as nr, 'maandag' as name, 'ma' as abbr
union all select 'nl', 'weekday',  2, 'dinsdag',         'di'
union all select 'nl', 'weekday',  3, 'woensdag',        'wo'
union all select 'nl', 'weekday',  4, 'donderdag',       'do'
union all select 'nl', 'weekday',  5, 'vrijdag',         'vr'
union all select 'nl', 'weekday',  6, 'zaterdag',        'za'
union all select 'nl', 'weekday',  7, 'zondag',          'zo'
union all select 'nl', 'month',    1, 'januari',         'jan'
union all select 'nl', 'month',    2, 'februari',        'feb'
union all select 'nl', 'month',    3, 'maart',           'mrt'
union all select 'nl', 'month',    4, 'april',           'apr'
union all select 'nl', 'month',    5, 'mei',             'mei'
union all select 'nl', 'month',    6, 'juni',            'jun'
union all select 'nl', 'month',    7, 'juli',            'jul'
union all select 'nl', 'month',    8, 'augustus',        'aug'
union all select 'nl', 'month',    9, 'september',       'sep'
union all select 'nl', 'month',   10, 'oktober',         'okt'
union all select 'nl', 'month',   11, 'november',        'nov'
union all select 'nl', 'month',   12, 'december',        'dec'
-- EN (English)
union all select 'en', 'weekday',  1, 'Monday',          'Mo'
union all select 'en', 'weekday',  2, 'Tuesday',         'Tu'
union all select 'en', 'weekday',  3, 'Wednesday',       'We'
union all select 'en', 'weekday',  4, 'Thursday',        'Th'
union all select 'en', 'weekday',  5, 'Friday',          'Fr'
union all select 'en', 'weekday',  6, 'Saturday',        'Sa'
union all select 'en', 'weekday',  7, 'Sunday',          'Su'
union all select 'en', 'month',    1, 'January',         'Jan'
union all select 'en', 'month',    2, 'February',        'Feb'
union all select 'en', 'month',    3, 'March',           'Mar'
union all select 'en', 'month',    4, 'April',           'Apr'
union all select 'en', 'month',    5, 'May',             'May'
union all select 'en', 'month',    6, 'June',            'Jun'
union all select 'en', 'month',    7, 'July',            'Jul'
union all select 'en', 'month',    8, 'August',          'Aug'
union all select 'en', 'month',    9, 'September',       'Sep'
union all select 'en', 'month',   10, 'October',         'Oct'
union all select 'en', 'month',   11, 'November',        'Nov'
union all select 'en', 'month',   12, 'December',        'Dec'
-- DE (German)
union all select 'de', 'weekday',  1, 'Montag',          'Mo'
union all select 'de', 'weekday',  2, 'Dienstag',        'Di'
union all select 'de', 'weekday',  3, 'Mittwoch',        'Mi'
union all select 'de', 'weekday',  4, 'Donnerstag',      'Do'
union all select 'de', 'weekday',  5, 'Freitag',         'Fr'
union all select 'de', 'weekday',  6, 'Samstag',         'Sa'
union all select 'de', 'weekday',  7, 'Sonntag',         'So'
union all select 'de', 'month',    1, 'Januar',          'Jan'
union all select 'de', 'month',    2, 'Februar',         'Feb'
union all select 'de', 'month',    3, 'März',       'Mär'
union all select 'de', 'month',    4, 'April',           'Apr'
union all select 'de', 'month',    5, 'Mai',             'Mai'
union all select 'de', 'month',    6, 'Juni',            'Jun'
union all select 'de', 'month',    7, 'Juli',            'Jul'
union all select 'de', 'month',    8, 'August',          'Aug'
union all select 'de', 'month',    9, 'September',       'Sep'
union all select 'de', 'month',   10, 'Oktober',         'Okt'
union all select 'de', 'month',   11, 'November',        'Nov'
union all select 'de', 'month',   12, 'Dezember',        'Dez'
-- FR (French)
union all select 'fr', 'weekday',  1, 'lundi',           'lun'
union all select 'fr', 'weekday',  2, 'mardi',           'mar'
union all select 'fr', 'weekday',  3, 'mercredi',        'mer'
union all select 'fr', 'weekday',  4, 'jeudi',           'jeu'
union all select 'fr', 'weekday',  5, 'vendredi',        'ven'
union all select 'fr', 'weekday',  6, 'samedi',          'sam'
union all select 'fr', 'weekday',  7, 'dimanche',        'dim'
union all select 'fr', 'month',    1, 'janvier',         'jan'
union all select 'fr', 'month',    2, 'février',    'fév'
union all select 'fr', 'month',    3, 'mars',            'mar'
union all select 'fr', 'month',    4, 'avril',           'avr'
union all select 'fr', 'month',    5, 'mai',             'mai'
union all select 'fr', 'month',    6, 'juin',            'jun'
union all select 'fr', 'month',    7, 'juillet',         'jul'
union all select 'fr', 'month',    8, 'août',       'aoû'
union all select 'fr', 'month',    9, 'septembre',       'sep'
union all select 'fr', 'month',   10, 'octobre',         'oct'
union all select 'fr', 'month',   11, 'novembre',        'nov'
union all select 'fr', 'month',   12, 'décembre',   'déc'
-- ES (Spanish)
union all select 'es', 'weekday',  1, 'lunes',           'lun'
union all select 'es', 'weekday',  2, 'martes',          'mar'
union all select 'es', 'weekday',  3, 'miércoles',  'mié'
union all select 'es', 'weekday',  4, 'jueves',          'jue'
union all select 'es', 'weekday',  5, 'viernes',         'vie'
union all select 'es', 'weekday',  6, 'sábado',     'sáb'
union all select 'es', 'weekday',  7, 'domingo',         'dom'
union all select 'es', 'month',    1, 'enero',           'ene'
union all select 'es', 'month',    2, 'febrero',         'feb'
union all select 'es', 'month',    3, 'marzo',           'mar'
union all select 'es', 'month',    4, 'abril',           'abr'
union all select 'es', 'month',    5, 'mayo',            'may'
union all select 'es', 'month',    6, 'junio',           'jun'
union all select 'es', 'month',    7, 'julio',           'jul'
union all select 'es', 'month',    8, 'agosto',          'ago'
union all select 'es', 'month',    9, 'septiembre',      'sep'
union all select 'es', 'month',   10, 'octubre',         'oct'
union all select 'es', 'month',   11, 'noviembre',       'nov'
union all select 'es', 'month',   12, 'diciembre',       'dic'
-- PT (Portuguese)
union all select 'pt', 'weekday',  1, 'segunda-feira',   'seg'
union all select 'pt', 'weekday',  2, 'terça-feira','ter'
union all select 'pt', 'weekday',  3, 'quarta-feira',    'qua'
union all select 'pt', 'weekday',  4, 'quinta-feira',    'qui'
union all select 'pt', 'weekday',  5, 'sexta-feira',     'sex'
union all select 'pt', 'weekday',  6, 'sábado',     'sáb'
union all select 'pt', 'weekday',  7, 'domingo',         'dom'
union all select 'pt', 'month',    1, 'janeiro',         'jan'
union all select 'pt', 'month',    2, 'fevereiro',       'fev'
union all select 'pt', 'month',    3, 'março',      'mar'
union all select 'pt', 'month',    4, 'abril',           'abr'
union all select 'pt', 'month',    5, 'maio',            'mai'
union all select 'pt', 'month',    6, 'junho',           'jun'
union all select 'pt', 'month',    7, 'julho',           'jul'
union all select 'pt', 'month',    8, 'agosto',          'ago'
union all select 'pt', 'month',    9, 'setembro',        'set'
union all select 'pt', 'month',   10, 'outubro',         'out'
union all select 'pt', 'month',   11, 'novembro',        'nov'
union all select 'pt', 'month',   12, 'dezembro',        'dez'
-- IT (Italian)
union all select 'it', 'weekday',  1, 'lunedì',     'lun'
union all select 'it', 'weekday',  2, 'martedì',    'mar'
union all select 'it', 'weekday',  3, 'mercoledì',  'mer'
union all select 'it', 'weekday',  4, 'giovedì',    'gio'
union all select 'it', 'weekday',  5, 'venerdì',    'ven'
union all select 'it', 'weekday',  6, 'sabato',          'sab'
union all select 'it', 'weekday',  7, 'domenica',        'dom'
union all select 'it', 'month',    1, 'gennaio',         'gen'
union all select 'it', 'month',    2, 'febbraio',        'feb'
union all select 'it', 'month',    3, 'marzo',           'mar'
union all select 'it', 'month',    4, 'aprile',          'apr'
union all select 'it', 'month',    5, 'maggio',          'mag'
union all select 'it', 'month',    6, 'giugno',          'giu'
union all select 'it', 'month',    7, 'luglio',          'lug'
union all select 'it', 'month',    8, 'agosto',          'ago'
union all select 'it', 'month',    9, 'settembre',       'set'
union all select 'it', 'month',   10, 'ottobre',         'ott'
union all select 'it', 'month',   11, 'novembre',        'nov'
union all select 'it', 'month',   12, 'dicembre',        'dic'
-- PL (Polish)
union all select 'pl', 'weekday',  1, 'poniedziałek','pon'
union all select 'pl', 'weekday',  2, 'wtorek',          'wt'
union all select 'pl', 'weekday',  3, 'środa',      'śr'
union all select 'pl', 'weekday',  4, 'czwartek',        'czw'
union all select 'pl', 'weekday',  5, 'piątek',     'pt'
union all select 'pl', 'weekday',  6, 'sobota',          'sob'
union all select 'pl', 'weekday',  7, 'niedziela',       'ndz'
union all select 'pl', 'month',    1, 'styczeń',    'sty'
union all select 'pl', 'month',    2, 'luty',            'lut'
union all select 'pl', 'month',    3, 'marzec',          'mar'
union all select 'pl', 'month',    4, 'kwiecień',   'kwi'
union all select 'pl', 'month',    5, 'maj',             'maj'
union all select 'pl', 'month',    6, 'czerwiec',        'cze'
union all select 'pl', 'month',    7, 'lipiec',          'lip'
union all select 'pl', 'month',    8, 'sierpień',   'sie'
union all select 'pl', 'month',    9, 'wrzesień',   'wrz'
union all select 'pl', 'month',   10, 'październik','paź'
union all select 'pl', 'month',   11, 'listopad',        'lis'
union all select 'pl', 'month',   12, 'grudzień',   'gru'
;
