-- One-time setup: creates and populates the public_holidays table for years 2000-2100.
-- Countries included: NL, BE, DE, FR, GB, ES, IT, PT
-- State/regional holidays are not included; see _docs.md for per-country details.
--
-- 1. Adjust the table name below to match your Snowflake environment.
-- 2. Run this script once (re-runnable: uses CREATE OR REPLACE).
-- 3. Reference in dbt_project.yml:
--      vars:
--        dim_date_public_holidays_table: source('raw', 'public_holidays')
--        dim_date_country: 'NL'

create or replace table your_database.your_schema.public_holidays as

with years as (
    select row_number() over (order by seq4()) + 1999 as yr
      from table(generator(rowcount => 101))

), easter_step1 as (
    select yr
         , mod(yr, 19)                                                        as a
         , mod(yr, 4)                                                         as b
         , mod(yr, 7)                                                         as c
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
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',  'NL' from years union all
    select dateadd('day', -2, easter_sunday),             'Good Friday',      'NL' from easter union all
    select easter_sunday,                                  'Easter Sunday',    'NL' from easter union all
    select dateadd('day',  1, easter_sunday),             'Easter Monday',    'NL' from easter union all
    select iff(dayofweek(to_date(yr::string || '-04-27', 'YYYY-MM-DD')) = 0,
               to_date(yr::string || '-04-26', 'YYYY-MM-DD'),
               to_date(yr::string || '-04-27', 'YYYY-MM-DD')),
           'King''s Day',                                                      'NL' from years union all
    select to_date(yr::string || '-05-05', 'YYYY-MM-DD'), 'Liberation Day',   'NL' from years union all
    select dateadd('day', 39, easter_sunday),             'Ascension Day',    'NL' from easter union all
    select dateadd('day', 49, easter_sunday),             'Whit Sunday',      'NL' from easter union all
    select dateadd('day', 50, easter_sunday),             'Whit Monday',      'NL' from easter union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',    'NL' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'Boxing Day',       'NL' from years

), be as (
    -- Sources: https://www.belgium.be/nl/werk/feestdagen
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',      'BE' from years union all
    select easter_sunday,                                  'Easter Sunday',         'BE' from easter union all
    select dateadd('day',  1, easter_sunday),             'Easter Monday',         'BE' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day',            'BE' from years union all
    select dateadd('day', 39, easter_sunday),             'Ascension Day',         'BE' from easter union all
    select dateadd('day', 49, easter_sunday),             'Whit Sunday',           'BE' from easter union all
    select dateadd('day', 50, easter_sunday),             'Whit Monday',           'BE' from easter union all
    select to_date(yr::string || '-07-21', 'YYYY-MM-DD'), 'Belgian National Day',  'BE' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption',            'BE' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints'' Day',      'BE' from years union all
    select to_date(yr::string || '-11-11', 'YYYY-MM-DD'), 'Armistice Day',         'BE' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',         'BE' from years

), de as (
    -- Sources: https://www.bmi.bund.de/DE/themen/verfassung/staatliche-symbole/nationale-feiertage
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',   'DE' from years union all
    select dateadd('day', -2, easter_sunday),             'Good Friday',        'DE' from easter union all
    select easter_sunday,                                  'Easter Sunday',      'DE' from easter union all
    select dateadd('day',  1, easter_sunday),             'Easter Monday',      'DE' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day',         'DE' from years union all
    select dateadd('day', 39, easter_sunday),             'Ascension Day',      'DE' from easter union all
    select dateadd('day', 49, easter_sunday),             'Whit Sunday',        'DE' from easter union all
    select dateadd('day', 50, easter_sunday),             'Whit Monday',        'DE' from easter union all
    select to_date(yr::string || '-10-03', 'YYYY-MM-DD'), 'German Unity Day',   'DE' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',      'DE' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'Boxing Day',         'DE' from years

), fr as (
    -- Sources: https://www.service-public.fr/particuliers/vosdroits/F2405
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',       'FR' from years union all
    select dateadd('day',  1, easter_sunday),             'Easter Monday',          'FR' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day',             'FR' from years union all
    select to_date(yr::string || '-05-08', 'YYYY-MM-DD'), 'Victory in Europe Day',  'FR' from years union all
    select dateadd('day', 39, easter_sunday),             'Ascension Day',          'FR' from easter union all
    select dateadd('day', 50, easter_sunday),             'Whit Monday',            'FR' from easter union all
    select to_date(yr::string || '-07-14', 'YYYY-MM-DD'), 'Bastille Day',           'FR' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption',             'FR' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints'' Day',       'FR' from years union all
    select to_date(yr::string || '-11-11', 'YYYY-MM-DD'), 'Armistice Day',          'FR' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',          'FR' from years

), gb as (
    -- Sources: https://www.gov.uk/bank-holidays
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',       'GB' from years union all
    select dateadd('day', -2, easter_sunday),             'Good Friday',            'GB' from easter union all
    select dateadd('day',  1, easter_sunday),             'Easter Monday',          'GB' from easter union all
    -- Early May Bank Holiday: first Monday of May
    select dateadd('day',
               mod(8 - dayofweekiso(to_date(yr::string || '-05-01', 'YYYY-MM-DD')), 7),
               to_date(yr::string || '-05-01', 'YYYY-MM-DD')),
           'Early May Bank Holiday',                                                 'GB' from years union all
    -- Spring Bank Holiday: last Monday of May
    select dateadd('day',
               -(dayofweekiso(to_date(yr::string || '-05-31', 'YYYY-MM-DD')) - 1),
               to_date(yr::string || '-05-31', 'YYYY-MM-DD')),
           'Spring Bank Holiday',                                                    'GB' from years union all
    -- Summer Bank Holiday: last Monday of August
    select dateadd('day',
               -(dayofweekiso(to_date(yr::string || '-08-31', 'YYYY-MM-DD')) - 1),
               to_date(yr::string || '-08-31', 'YYYY-MM-DD')),
           'Summer Bank Holiday',                                                    'GB' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',          'GB' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'Boxing Day',             'GB' from years

), es as (
    -- Sources: https://administracion.gob.es/pag_Home/atencionCiudadana/calendarios/fiestas-laborales-nacionales.html
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',        'ES' from years union all
    select to_date(yr::string || '-01-06', 'YYYY-MM-DD'), 'Epiphany',               'ES' from years union all
    select dateadd('day', -2, easter_sunday),             'Good Friday',             'ES' from easter union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day',              'ES' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption',              'ES' from years union all
    select to_date(yr::string || '-10-12', 'YYYY-MM-DD'), 'National Day',            'ES' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints'' Day',        'ES' from years union all
    select to_date(yr::string || '-12-06', 'YYYY-MM-DD'), 'Constitution Day',        'ES' from years union all
    select to_date(yr::string || '-12-08', 'YYYY-MM-DD'), 'Immaculate Conception',   'ES' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',           'ES' from years

), it as (
    -- Sources: https://www.governo.it/it/approfondimento/giorni-festivi
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',        'IT' from years union all
    select to_date(yr::string || '-01-06', 'YYYY-MM-DD'), 'Epiphany',               'IT' from years union all
    select easter_sunday,                                  'Easter Sunday',           'IT' from easter union all
    select dateadd('day',  1, easter_sunday),             'Easter Monday',           'IT' from easter union all
    select to_date(yr::string || '-04-25', 'YYYY-MM-DD'), 'Liberation Day',          'IT' from years union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day',              'IT' from years union all
    select to_date(yr::string || '-06-02', 'YYYY-MM-DD'), 'Republic Day',            'IT' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption',              'IT' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints'' Day',        'IT' from years union all
    select to_date(yr::string || '-12-08', 'YYYY-MM-DD'), 'Immaculate Conception',   'IT' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',           'IT' from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD'), 'St. Stephen''s Day',      'IT' from years

), pt as (
    -- Sources: https://eportugal.gov.pt/servicos/consultar-calendario-de-feriados-obrigatorios-em-portugal
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD'), 'New Year''s Day',              'PT' from years union all
    select dateadd('day', -2, easter_sunday),             'Good Friday',                   'PT' from easter union all
    select easter_sunday,                                  'Easter Sunday',                 'PT' from easter union all
    select to_date(yr::string || '-04-25', 'YYYY-MM-DD'), 'Freedom Day',                   'PT' from years union all
    select to_date(yr::string || '-05-01', 'YYYY-MM-DD'), 'Labour Day',                    'PT' from years union all
    select dateadd('day', 60, easter_sunday),             'Corpus Christi',                'PT' from easter union all
    select to_date(yr::string || '-06-10', 'YYYY-MM-DD'), 'Portugal Day',                  'PT' from years union all
    select to_date(yr::string || '-08-15', 'YYYY-MM-DD'), 'Assumption',                    'PT' from years union all
    select to_date(yr::string || '-10-05', 'YYYY-MM-DD'), 'Republic Day',                  'PT' from years union all
    select to_date(yr::string || '-11-01', 'YYYY-MM-DD'), 'All Saints'' Day',              'PT' from years union all
    select to_date(yr::string || '-12-01', 'YYYY-MM-DD'), 'Restoration of Independence',   'PT' from years union all
    select to_date(yr::string || '-12-08', 'YYYY-MM-DD'), 'Immaculate Conception',         'PT' from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD'), 'Christmas Day',                 'PT' from years

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
