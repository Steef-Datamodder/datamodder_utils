{% macro generate_date_dimension(
    start_date = '2000-01-01'
  , end_date = '2030-12-31'
  , fiscal_year_start_month = 1
  , public_holidays = none
  , country = none
  , school_holidays = none
  , school_holiday_region = none
  , school_holiday_country = none
) %}
{% set language               = _dim_date_language() %}
{% set public_holidays        = public_holidays        or _dim_date_public_holidays() %}
{% set country                = country                or _dim_date_country() %}
{% set school_holidays        = school_holidays        or _dim_date_school_holidays() %}
{% set school_holiday_country = school_holiday_country or _dim_date_school_holiday_country() %}
{% set school_holiday_region  = school_holiday_region  or _dim_date_school_holiday_region() %}

with date_spine as (
    select dateadd('day', seq4(), '{{ start_date }}'::date) as date
      from table(generator(rowcount => 50000))
     where date <= '{{ end_date }}'::date

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

select ds.date                                                                                 as date
     , to_char(ds.date, 'YYYYMMDD')::number                                                   as date_key

     -- ── Day ──────────────────────────────────────────────────────────────────
     , day(ds.date)                                                                             as day_nr
     , dayofyear(ds.date)                                                                       as day_of_year
     , dayofweekiso(ds.date)                                                                    as day_of_week_nr   -- 1 = Mon, 7 = Sun
     {% if language == 'nl' %}
     , case dayofweekiso(ds.date)
           when 1 then 'maandag'    when 2 then 'dinsdag'   when 3 then 'woensdag'
           when 4 then 'donderdag'  when 5 then 'vrijdag'   when 6 then 'zaterdag'
           when 7 then 'zondag'     end                                                         as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'ma' when 2 then 'di' when 3 then 'wo'
           when 4 then 'do' when 5 then 'vr' when 6 then 'za'
           when 7 then 'zo' end                                                                 as weekday_abbr
     {% elif language == 'en' %}
     , dayname(ds.date)                                                                         as weekday
     , left(dayname(ds.date), 2)                                                                as weekday_abbr
     {% elif language == 'de' %}
     , case dayofweekiso(ds.date)
           when 1 then 'Montag'     when 2 then 'Dienstag'  when 3 then 'Mittwoch'
           when 4 then 'Donnerstag' when 5 then 'Freitag'   when 6 then 'Samstag'
           when 7 then 'Sonntag'    end                                                         as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'Mo' when 2 then 'Di' when 3 then 'Mi'
           when 4 then 'Do' when 5 then 'Fr' when 6 then 'Sa'
           when 7 then 'So' end                                                                 as weekday_abbr
     {% elif language == 'fr' %}
     , case dayofweekiso(ds.date)
           when 1 then 'lundi'      when 2 then 'mardi'     when 3 then 'mercredi'
           when 4 then 'jeudi'      when 5 then 'vendredi'  when 6 then 'samedi'
           when 7 then 'dimanche'   end                                                         as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'lun' when 2 then 'mar' when 3 then 'mer'
           when 4 then 'jeu' when 5 then 'ven' when 6 then 'sam'
           when 7 then 'dim' end                                                                as weekday_abbr
     {% elif language == 'es' %}
     , case dayofweekiso(ds.date)
           when 1 then 'lunes'      when 2 then 'martes'    when 3 then 'miércoles'
           when 4 then 'jueves'     when 5 then 'viernes'   when 6 then 'sábado'
           when 7 then 'domingo'    end                                                         as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'lun' when 2 then 'mar' when 3 then 'mié'
           when 4 then 'jue' when 5 then 'vie' when 6 then 'sáb'
           when 7 then 'dom' end                                                                as weekday_abbr
     {% elif language == 'pt' %}
     , case dayofweekiso(ds.date)
           when 1 then 'segunda-feira' when 2 then 'terça-feira'  when 3 then 'quarta-feira'
           when 4 then 'quinta-feira'  when 5 then 'sexta-feira'  when 6 then 'sábado'
           when 7 then 'domingo'       end                                                      as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'seg' when 2 then 'ter' when 3 then 'qua'
           when 4 then 'qui' when 5 then 'sex' when 6 then 'sáb'
           when 7 then 'dom' end                                                                as weekday_abbr
     {% elif language == 'it' %}
     , case dayofweekiso(ds.date)
           when 1 then 'lunedì'     when 2 then 'martedì'   when 3 then 'mercoledì'
           when 4 then 'giovedì'    when 5 then 'venerdì'   when 6 then 'sabato'
           when 7 then 'domenica'   end                                                         as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'lun' when 2 then 'mar' when 3 then 'mer'
           when 4 then 'gio' when 5 then 'ven' when 6 then 'sab'
           when 7 then 'dom' end                                                                as weekday_abbr
     {% elif language == 'pl' %}
     , case dayofweekiso(ds.date)
           when 1 then 'poniedziałek' when 2 then 'wtorek'    when 3 then 'środa'
           when 4 then 'czwartek'     when 5 then 'piątek'    when 6 then 'sobota'
           when 7 then 'niedziela'    end                                                       as weekday
     , case dayofweekiso(ds.date)
           when 1 then 'pon' when 2 then 'wt'  when 3 then 'śr'
           when 4 then 'czw' when 5 then 'pt'  when 6 then 'sob'
           when 7 then 'ndz' end                                                                as weekday_abbr
     {% endif %}
     , dayofweekiso(ds.date) >= 6                                                               as is_weekend
     {% if public_holidays is not none %}
     , dayofweekiso(ds.date) <  6 and ph.holiday_name is null                                  as is_workday
     {% else %}
     , dayofweekiso(ds.date) <  6                                                               as is_workday
     {% endif %}

     -- ── Week ─────────────────────────────────────────────────────────────────
     , week(ds.date)                                                                            as week_nr
     , weekiso(ds.date)                                                                         as iso_week_nr
     , yearofweekiso(ds.date)                                                                   as iso_week_year
     , yearofweekiso(ds.date)::string
       || '-W' || lpad(weekiso(ds.date)::string, 2, '0')                                       as iso_week_label

     -- ── Month ────────────────────────────────────────────────────────────────
     , month(ds.date)                                                                           as month_nr
     {% if language == 'nl' %}
     , case month(ds.date)
           when 1  then 'januari'    when 2  then 'februari'   when 3  then 'maart'
           when 4  then 'april'      when 5  then 'mei'        when 6  then 'juni'
           when 7  then 'juli'       when 8  then 'augustus'   when 9  then 'september'
           when 10 then 'oktober'    when 11 then 'november'   when 12 then 'december'   end   as month_name
     , case month(ds.date)
           when 1  then 'jan' when 2  then 'feb' when 3  then 'mrt'
           when 4  then 'apr' when 5  then 'mei' when 6  then 'jun'
           when 7  then 'jul' when 8  then 'aug' when 9  then 'sep'
           when 10 then 'okt' when 11 then 'nov' when 12 then 'dec' end                        as month_abbr
     {% elif language == 'en' %}
     , monthname(ds.date)                                                                       as month_name
     , left(monthname(ds.date), 3)                                                              as month_abbr
     {% elif language == 'de' %}
     , case month(ds.date)
           when 1  then 'Januar'     when 2  then 'Februar'    when 3  then 'März'
           when 4  then 'April'      when 5  then 'Mai'        when 6  then 'Juni'
           when 7  then 'Juli'       when 8  then 'August'     when 9  then 'September'
           when 10 then 'Oktober'    when 11 then 'November'   when 12 then 'Dezember'   end   as month_name
     , case month(ds.date)
           when 1  then 'Jan' when 2  then 'Feb' when 3  then 'Mär'
           when 4  then 'Apr' when 5  then 'Mai' when 6  then 'Jun'
           when 7  then 'Jul' when 8  then 'Aug' when 9  then 'Sep'
           when 10 then 'Okt' when 11 then 'Nov' when 12 then 'Dez' end                        as month_abbr
     {% elif language == 'fr' %}
     , case month(ds.date)
           when 1  then 'janvier'    when 2  then 'février'    when 3  then 'mars'
           when 4  then 'avril'      when 5  then 'mai'        when 6  then 'juin'
           when 7  then 'juillet'    when 8  then 'août'       when 9  then 'septembre'
           when 10 then 'octobre'    when 11 then 'novembre'   when 12 then 'décembre'   end   as month_name
     , case month(ds.date)
           when 1  then 'jan' when 2  then 'fév' when 3  then 'mar'
           when 4  then 'avr' when 5  then 'mai' when 6  then 'jun'
           when 7  then 'jul' when 8  then 'aoû' when 9  then 'sep'
           when 10 then 'oct' when 11 then 'nov' when 12 then 'déc' end                        as month_abbr
     {% elif language == 'es' %}
     , case month(ds.date)
           when 1  then 'enero'      when 2  then 'febrero'    when 3  then 'marzo'
           when 4  then 'abril'      when 5  then 'mayo'       when 6  then 'junio'
           when 7  then 'julio'      when 8  then 'agosto'     when 9  then 'septiembre'
           when 10 then 'octubre'    when 11 then 'noviembre'  when 12 then 'diciembre'  end   as month_name
     , case month(ds.date)
           when 1  then 'ene' when 2  then 'feb' when 3  then 'mar'
           when 4  then 'abr' when 5  then 'may' when 6  then 'jun'
           when 7  then 'jul' when 8  then 'ago' when 9  then 'sep'
           when 10 then 'oct' when 11 then 'nov' when 12 then 'dic' end                        as month_abbr
     {% elif language == 'pt' %}
     , case month(ds.date)
           when 1  then 'janeiro'    when 2  then 'fevereiro'  when 3  then 'março'
           when 4  then 'abril'      when 5  then 'maio'       when 6  then 'junho'
           when 7  then 'julho'      when 8  then 'agosto'     when 9  then 'setembro'
           when 10 then 'outubro'    when 11 then 'novembro'   when 12 then 'dezembro'   end   as month_name
     , case month(ds.date)
           when 1  then 'jan' when 2  then 'fev' when 3  then 'mar'
           when 4  then 'abr' when 5  then 'mai' when 6  then 'jun'
           when 7  then 'jul' when 8  then 'ago' when 9  then 'set'
           when 10 then 'out' when 11 then 'nov' when 12 then 'dez' end                        as month_abbr
     {% elif language == 'it' %}
     , case month(ds.date)
           when 1  then 'gennaio'    when 2  then 'febbraio'   when 3  then 'marzo'
           when 4  then 'aprile'     when 5  then 'maggio'     when 6  then 'giugno'
           when 7  then 'luglio'     when 8  then 'agosto'     when 9  then 'settembre'
           when 10 then 'ottobre'    when 11 then 'novembre'   when 12 then 'dicembre'   end   as month_name
     , case month(ds.date)
           when 1  then 'gen' when 2  then 'feb' when 3  then 'mar'
           when 4  then 'apr' when 5  then 'mag' when 6  then 'giu'
           when 7  then 'lug' when 8  then 'ago' when 9  then 'set'
           when 10 then 'ott' when 11 then 'nov' when 12 then 'dic' end                        as month_abbr
     {% elif language == 'pl' %}
     , case month(ds.date)
           when 1  then 'styczeń'    when 2  then 'luty'       when 3  then 'marzec'
           when 4  then 'kwiecień'   when 5  then 'maj'        when 6  then 'czerwiec'
           when 7  then 'lipiec'     when 8  then 'sierpień'   when 9  then 'wrzesień'
           when 10 then 'październik' when 11 then 'listopad'  when 12 then 'grudzień'  end   as month_name
     , case month(ds.date)
           when 1  then 'sty' when 2  then 'lut' when 3  then 'mar'
           when 4  then 'kwi' when 5  then 'maj' when 6  then 'cze'
           when 7  then 'lip' when 8  then 'sie' when 9  then 'wrz'
           when 10 then 'paź' when 11 then 'lis' when 12 then 'gru' end                        as month_abbr
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
     {% if public_holidays is not none %}
     , ph.holiday_name is not null                                                              as is_holiday
     , ph.holiday_name
     {% else %}
     , false::boolean                                                                           as is_holiday
     , null::varchar                                                                            as holiday_name
     {% endif %}

     -- ── School holidays ──────────────────────────────────────────────────────
     {% if school_holidays is not none %}
     , sh.holiday_name is not null                                                              as is_school_holiday
     , sh.holiday_name                                                                          as school_holiday_name
     {% endif %}

  from date_spine ds
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
