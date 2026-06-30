{% macro generate_date_dimension(
    start_date              = '2000-01-01',
    end_date                = '2030-12-31',
    fiscal_year_start_month = 1,
    school_holidays         = none,
    school_holiday_region   = none,
    school_holiday_country  = none
) %}
{#
  Generates a date dimension for Snowflake.

  Parameters:
    start_date              : start date (default '2000-01-01')
    end_date                : end date   (default '2030-12-31')
    fiscal_year_start_month : first month of the fiscal year (1-12, default 1 = calendar year)
    school_holidays         : ref() or source() to a table with school holiday data (optional)
                              Expected schema:
                                start_date     DATE   -- first day of holiday
                                end_date       DATE   -- last day of holiday
                                holiday_name   TEXT   -- e.g. 'Summer Holiday'
                                country        TEXT   -- 'NL', 'BE', 'DE', 'GB', 'FR', 'US'
                                region         TEXT   -- e.g. 'Noord', 'Zone A', 'Bayern' (null = all regions)
    school_holiday_region   : filter on region (optional, e.g. 'Noord')
    school_holiday_country  : filter on country (optional, e.g. 'NL')

  Data sources per country:
    NL : rijksoverheid.nl/onderwerpen/schoolvakanties  (3 regions: Noord, Midden, Zuid)
    BE : onderwijs.vlaanderen.be / enseignement.be     (3 communities: NL, FR, DE)
    DE : kmk.org/service/schulferien                   (16 Bundesländer)
    GB : gov.uk/school-term-and-holiday-dates          (per local authority, no central source)
    FR : education.gouv.fr/calendrier-scolaire         (3 zones: A, B, C)
    US : no central source; per school district

  Language: set via dbt variable 'dim_date_language' (default 'nl', 'en' also supported):
    dbt run --vars '{"dim_date_language": "en"}'
    or in dbt_project.yml:  vars: { dim_date_language: en }

  Usage in a model (models/core/dim_date.sql):
    {{ generate_date_dimension() }}
    {{ generate_date_dimension(
           start_date='2015-01-01',
           end_date='2040-12-31',
           fiscal_year_start_month=4,
           school_holidays=ref('school_holidays'),
           school_holiday_country='NL',
           school_holiday_region='Noord') }}
#}

{% set language               = _dim_date_language() %}
{% set school_holidays        = school_holidays         or _dim_date_school_holidays() %}
{% set school_holiday_country = school_holiday_country  or _dim_date_school_holiday_country() %}
{% set school_holiday_region  = school_holiday_region   or _dim_date_school_holiday_region() %}

with date_spine as (
    select dateadd('day', seq4(), '{{ start_date }}'::date) as date
      from table(generator(rowcount => 50000))
     where date <= '{{ end_date }}'::date

), years as (
    select distinct year(date) as yr
      from date_spine

), easter as (
    -- Anonymous Gregorian algorithm for Easter Sunday
    with step1 as (
        select yr
             , mod(yr, 19)                                                        as a
             , mod(yr, 4)                                                         as b
             , mod(yr, 7)                                                         as c
          from years
    ), step2 as (
        select yr, a, b, c
             , mod(19 * a + 24, 30)                                               as d
             , mod(2 * b + 4 * c + 6 * mod(19 * a + 24, 30) + 5, 7)             as e
          from step1
    )
    select yr
         , dateadd('day',
               21 + d + e
               - iff(d = 29 and e = 6,           7, 0)
               - iff(d = 28 and e = 6 and a > 10, 7, 0),
               to_date(yr::string || '-03-01', 'YYYY-MM-DD'))                     as easter_sunday
      from step2

{% if school_holidays is not none %}
), school_holidays_filtered as (
    select start_date
         , end_date
         , holiday_name
      from {{ school_holidays }}
     where 1 = 1
    {% if school_holiday_country is not none %}
       and country = '{{ school_holiday_country }}'
    {% endif %}
    {% if school_holiday_region is not none %}
       and (region = '{{ school_holiday_region }}' or region is null)
    {% endif %}

{% endif %}
), holidays as (
    -- Fixed holidays
    select to_date(yr::string || '-01-01', 'YYYY-MM-DD') as date, 'New Year''s Day'  as holiday_name from years union all
    select to_date(yr::string || '-05-05', 'YYYY-MM-DD')         , 'Liberation Day'                   from years union all
    select to_date(yr::string || '-12-25', 'YYYY-MM-DD')         , 'Christmas Day'                    from years union all
    select to_date(yr::string || '-12-26', 'YYYY-MM-DD')         , 'Boxing Day'                       from years union all
    -- King's Day: 27 April, moved to 26 April if it falls on a Sunday
    select iff(dayofweek(to_date(yr::string || '-04-27', 'YYYY-MM-DD')) = 0,
               to_date(yr::string || '-04-26', 'YYYY-MM-DD'),
               to_date(yr::string || '-04-27', 'YYYY-MM-DD'))    , 'King''s Day'                      from years union all
    -- Moveable holidays (relative to Easter Sunday)
    select dateadd('day',  -2, easter_sunday), 'Good Friday'    from easter union all
    select dateadd('day',   0, easter_sunday), 'Easter Sunday'  from easter union all
    select dateadd('day',   1, easter_sunday), 'Easter Monday'  from easter union all
    select dateadd('day',  39, easter_sunday), 'Ascension Day'  from easter union all
    select dateadd('day',  49, easter_sunday), 'Whit Sunday'    from easter union all
    select dateadd('day',  50, easter_sunday), 'Whit Monday'    from easter

)

select ds.date                                                                                 as date
     , to_char(ds.date, 'YYYYMMDD')::number                                                   as date_key

     -- ── Day ──────────────────────────────────────────────────────────────────
     , day(ds.date)                                                                             as day_nr
     , dayofyear(ds.date)                                                                       as day_of_year
     , dayofweekiso(ds.date)                                                                    as day_of_week_nr   -- 1 = Mon, 7 = Sun
     {% if language == 'nl' %}
     , case dayofweekiso(ds.date)
           when 1 then 'maandag'   when 2 then 'dinsdag'   when 3 then 'woensdag'
           when 4 then 'donderdag' when 5 then 'vrijdag'   when 6 then 'zaterdag'
           when 7 then 'zondag'    end                                                          as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'ma' when 2 then 'di' when 3 then 'wo'
           when 4 then 'do' when 5 then 'vr' when 6 then 'za'
           when 7 then 'zo' end                                                                 as weekday_abbr
     {% elif language == 'en' %}
     , dayname(ds.date)                                                                         as weekday          -- Mon, Tue, ...
     , left(dayname(ds.date), 2)                                                                as weekday_abbr
     {% endif %}
     , dayofweekiso(ds.date) >= 6                                                               as is_weekend
     , dayofweekiso(ds.date) <  6 and h.holiday_name is null                                   as is_workday

     -- ── Week ─────────────────────────────────────────────────────────────────
     , week(ds.date)                                                                            as week_nr           -- calendar week (1-53)
     , weekiso(ds.date)                                                                         as iso_week_nr       -- ISO 8601 week number
     , yearofweekiso(ds.date)                                                                   as iso_week_year
     , yearofweekiso(ds.date)::string
       || '-W' || lpad(weekiso(ds.date)::string, 2, '0')                                       as iso_week_label

     -- ── Month ────────────────────────────────────────────────────────────────
     , month(ds.date)                                                                           as month_nr
     {% if language == 'nl' %}
     , case month(ds.date)
           when 1  then 'januari'   when 2  then 'februari' when 3  then 'maart'
           when 4  then 'april'     when 5  then 'mei'      when 6  then 'juni'
           when 7  then 'juli'      when 8  then 'augustus' when 9  then 'september'
           when 10 then 'oktober'   when 11 then 'november' when 12 then 'december' end        as month_name
     , case month(ds.date)
           when 1  then 'jan' when 2  then 'feb' when 3  then 'mrt'
           when 4  then 'apr' when 5  then 'mei' when 6  then 'jun'
           when 7  then 'jul' when 8  then 'aug' when 9  then 'sep'
           when 10 then 'okt' when 11 then 'nov' when 12 then 'dec' end                        as month_abbr
     {% elif language == 'en' %}
     , monthname(ds.date)                                                                       as month_name        -- January, ...
     , left(monthname(ds.date), 3)                                                              as month_abbr        -- Jan, ...
     {% endif %}
     , year(ds.date)::string
       || '-' || lpad(month(ds.date)::string, 2, '0')                                          as month_label

     -- ── Quarter ──────────────────────────────────────────────────────────────
     , quarter(ds.date)                                                                         as quarter
     , year(ds.date)::string || '-Q' || quarter(ds.date)::string                               as quarter_label

     -- ── Year ─────────────────────────────────────────────────────────────────
     , year(ds.date)                                                                            as year

     -- ── Fiscal calendar (start month: {{ fiscal_year_start_month }}) ─────────
     , iff(month(ds.date) >= {{ fiscal_year_start_month }},
           year(ds.date),
           year(ds.date) - 1)                                                                   as fiscal_year
     , mod(month(ds.date) - {{ fiscal_year_start_month }} + 12, 12) + 1                        as fiscal_month_nr
     , ceil((mod(month(ds.date) - {{ fiscal_year_start_month }} + 12, 12) + 1) / 3.0)          as fiscal_quarter
     , 'FY' || iff(month(ds.date) >= {{ fiscal_year_start_month }},
                   year(ds.date), year(ds.date) - 1)::string
       || '-Q' || ceil((mod(month(ds.date) - {{ fiscal_year_start_month }} + 12, 12) + 1) / 3.0)::string as fiscal_quarter_label

     -- ── Holidays ─────────────────────────────────────────────────────────────
     , h.holiday_name is not null                                                               as is_holiday
     , h.holiday_name

     -- ── School holidays ──────────────────────────────────────────────────────
     {% if school_holidays is not none %}
     , sh.holiday_name is not null                                                              as is_school_holiday
     , sh.holiday_name                                                                          as school_holiday_name
     {% endif %}

  from date_spine ds
  left join holidays h on h.date = ds.date
  {% if school_holidays is not none %}
  left join school_holidays_filtered sh
    on  ds.date between sh.start_date and sh.end_date
  {% endif %}
 order by ds.date

{% endmacro %}
