{% macro generate(
    start_date = '2000-01-01'
  , end_date = '2030-12-31'
  , fiscal_year_start_month = 1
  , public_holidays = none
  , country = none
  , datenames = none
  , school_holidays = none
  , school_holiday_region = none
  , school_holiday_country = none
) %}
{% set language = _dim_date_language() %}
{% set public_holidays = public_holidays or _dim_date_public_holidays() %}
{% set country = country or _dim_date_country() %}
{% set datenames = datenames or _dim_date_datenames() %}
{% set school_holidays = school_holidays or _dim_date_school_holidays() %}
{% set school_holiday_country = school_holiday_country or _dim_date_school_holiday_country() %}
{% set school_holiday_region = school_holiday_region or _dim_date_school_holiday_region() %}

with date_spine as (
    select dateadd('day', seq4(), '{{ start_date }}'::date) as date
      from table(generator(rowcount => 50000))
     where date <= '{{ end_date }}'::date

{% if datenames is not none %}
), datenames_lang as (
    select type, nr, name, abbr
      from {{ datenames }}
     where language = '{{ language }}'

{% endif %}
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
)

select ds.date as date
     , to_char(ds.date, 'YYYYMMDD')::number as date_key
     , day(ds.date) as day_nr
     , dayofyear(ds.date) as day_of_year
     , dayofweekiso(ds.date) as day_of_week_nr   -- 1 = Mon, 7 = Sun
     {% if datenames is not none %}
     , wd.name as weekday
     , wd.abbr as weekday_abbr
     {% endif %}
     , dayofweekiso(ds.date) >= 6 as is_weekend
     {% if public_holidays is not none %}
     , dayofweekiso(ds.date) <  6 and ph.holiday_name is null as is_workday
     {% else %}
     , dayofweekiso(ds.date) <  6 as is_workday
     {% endif %}
     , week(ds.date) as week_nr
     , weekiso(ds.date) as iso_week_nr
     , yearofweekiso(ds.date) as iso_week_year
     , yearofweekiso(ds.date)::string
       || '-W' || lpad(weekiso(ds.date)::string, 2, '0') as iso_week_label
     , month(ds.date) as month_nr
     {% if datenames is not none %}
     , mn.name as month_name
     , mn.abbr as month_abbr
     {% endif %}
     , year(ds.date)::string
       || '-' || lpad(month(ds.date)::string, 2, '0') as month_label
     , quarter(ds.date) as quarter
     , year(ds.date)::string || '-Q' || quarter(ds.date)::string as quarter_label
     , year(ds.date) as year
     , iff(month(ds.date) >= {{ fiscal_year_start_month }},
           year(ds.date),
           year(ds.date) - 1) as fiscal_year
     , mod(month(ds.date) - {{ fiscal_year_start_month }} + 12, 12) + 1 as fiscal_month_nr
     , ceil((mod(month(ds.date) - {{ fiscal_year_start_month }} + 12, 12) + 1) / 3.0) as fiscal_quarter
     , 'FY' || iff(month(ds.date) >= {{ fiscal_year_start_month }},
                   year(ds.date), year(ds.date) - 1)::string
       || '-Q' || ceil((mod(month(ds.date) - {{ fiscal_year_start_month }} + 12, 12) + 1) / 3.0)::string as fiscal_quarter_label
     {% if public_holidays is not none %}
     , ph.holiday_name is not null as is_holiday
     , ph.holiday_name
     {% else %}
     , false::boolean as is_holiday
     , null::varchar as holiday_name
     {% endif %}
     {% if school_holidays is not none %}
     , sh.holiday_name is not null as is_school_holiday
     , sh.holiday_name as school_holiday_name
     {% endif %}
  from date_spine ds
  {% if datenames is not none %}
  left join datenames_lang wd on wd.type = 'weekday' and wd.nr = dayofweekiso(ds.date)
  left join datenames_lang mn on mn.type = 'month' and mn.nr = month(ds.date)
  {% endif %}
  {% if public_holidays is not none %}
  left join {{ public_holidays }} ph
    on  ph.date    = ds.date
    and ph.country = '{{ country }}'
  {% endif %}
  {% if school_holidays is not none %}
  left join school_holidays_filtered sh
    on  ds.date between sh.start_date and sh.end_date
  {% endif %}
 order by ds.date

{% endmacro %}
