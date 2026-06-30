{% macro generate_date_dimension(
    start_date              = '2000-01-01',
    end_date                = '2030-12-31',
    fiscal_year_start_month = 1,
    schoolvakanties         = none,
    schoolvakantie_regio    = none,
    schoolvakantie_land     = none
) %}
{#
  Genereert een datum-dimensie voor Snowflake.

  Parameters:
    start_date              : begindatum (default '2000-01-01')
    end_date                : einddatum  (default '2030-12-31')
    fiscal_year_start_month : startmaand van het fiscale jaar (1-12, default 1 = kalenderjaar)
    schoolvakanties         : ref() of source() naar een tabel met schoolvakantiedata (optioneel)
                              Verwacht schema:
                                van_datum      DATE   -- eerste vakantiedag
                                tot_datum      DATE   -- laatste vakantiedag
                                vakantie_naam  TEXT   -- bijv. 'Zomervakantie'
                                land           TEXT   -- 'NL', 'BE', 'DE', 'GB', 'FR', 'US'
                                regio          TEXT   -- bijv. 'Noord', 'Zone A', 'Bayern' (null = alle regio's)
    schoolvakantie_regio    : filter op regio (optioneel, bijv. 'Noord')
    schoolvakantie_land     : filter op land  (optioneel, bijv. 'NL')

  Databronnen per land:
    NL : rijksoverheid.nl/onderwerpen/schoolvakanties          (3 regio's: Noord, Midden, Zuid)
    BE : onderwijs.vlaanderen.be / enseignement.be             (3 gemeenschappen: NL, FR, DE)
    DE : kmk.org/service/schulferien                           (16 Bundesländer)
    GB : gov.uk/school-term-and-holiday-dates                  (per local authority, geen centrale bron)
    FR : education.gouv.fr/calendrier-scolaire                 (3 zones: A, B, C)
    US : geen centrale bron; per school district               (aggregators: niche.com/places-to-live/search/best-school-districts)

  Taal: stel in via dbt variable 'dim_datum_taal' (default 'nl', ook 'en' ondersteund):
    dbt run --vars '{"dim_datum_taal": "en"}'
    of in dbt_project.yml:  vars: { dim_datum_taal: en }

  Gebruik in een model (models/core/dim_datum.sql):
    {{ generate_date_dimension() }}
    {{ generate_date_dimension(
           start_date='2015-01-01',
           end_date='2040-12-31',
           fiscal_year_start_month=4,
           schoolvakanties=ref('schoolvakanties'),
           schoolvakantie_land='NL',
           schoolvakantie_regio='Noord') }}
#}

{% set taal                  = _dim_datum_taal() %}
{% set schoolvakanties       = schoolvakanties    or _dim_datum_schoolvakanties() %}
{% set schoolvakantie_land   = schoolvakantie_land  or _dim_datum_schoolvakantie_land() %}
{% set schoolvakantie_regio  = schoolvakantie_regio or _dim_datum_schoolvakantie_regio() %}

with date_spine as (
    select dateadd('day', seq4(), '{{ start_date }}'::date) as datum
      from table(generator(rowcount => 50000))
     where datum <= '{{ end_date }}'::date

), jaar_lijst as (
    select distinct year(datum) as jr
      from date_spine

), pasen as (
    -- Anonieme Gregoriaanse algoritme voor Eerste Paasdag
    with stap1 as (
        select jr
             , mod(jr, 19)                                                        as a
             , mod(jr, 4)                                                         as b
             , mod(jr, 7)                                                         as c
          from jaar_lijst
    ), stap2 as (
        select jr, a, b, c
             , mod(19 * a + 24, 30)                                               as d
             , mod(2 * b + 4 * c + 6 * mod(19 * a + 24, 30) + 5, 7)             as e
          from stap1
    )
    select jr
         , dateadd('day',
               21 + d + e
               - iff(d = 29 and e = 6,           7, 0)
               - iff(d = 28 and e = 6 and a > 10, 7, 0),
               to_date(jr::string || '-03-01', 'YYYY-MM-DD'))                     as eerste_paasdag
      from stap2

{% if schoolvakanties is not none %}
), schoolvakanties_gefilterd as (
    select van_datum
         , tot_datum
         , vakantie_naam
      from {{ schoolvakanties }}
     where 1 = 1
    {% if schoolvakantie_land is not none %}
       and land = '{{ schoolvakantie_land }}'
    {% endif %}
    {% if schoolvakantie_regio is not none %}
       and (regio = '{{ schoolvakantie_regio }}' or regio is null)
    {% endif %}

{% endif %}
), feestdagen as (
    -- Vaste feestdagen
    select to_date(jr::string || '-01-01', 'YYYY-MM-DD') as datum, 'Nieuwjaarsdag'   as feestdag_naam from jaar_lijst union all
    select to_date(jr::string || '-05-05', 'YYYY-MM-DD')         , 'Bevrijdingsdag'                    from jaar_lijst union all
    select to_date(jr::string || '-12-25', 'YYYY-MM-DD')         , 'Eerste Kerstdag'                   from jaar_lijst union all
    select to_date(jr::string || '-12-26', 'YYYY-MM-DD')         , 'Tweede Kerstdag'                   from jaar_lijst union all
    -- Koningsdag: 27 april, uitgesteld naar 26 april als het een zondag is
    select iff(dayofweek(to_date(jr::string || '-04-27', 'YYYY-MM-DD')) = 0,
               to_date(jr::string || '-04-26', 'YYYY-MM-DD'),
               to_date(jr::string || '-04-27', 'YYYY-MM-DD'))    , 'Koningsdag'                        from jaar_lijst union all
    -- Beweeglijke feestdagen (relatief aan Eerste Paasdag)
    select dateadd('day',  -2, eerste_paasdag), 'Goede Vrijdag'      from pasen union all
    select dateadd('day',   0, eerste_paasdag), 'Eerste Paasdag'     from pasen union all
    select dateadd('day',   1, eerste_paasdag), 'Tweede Paasdag'     from pasen union all
    select dateadd('day',  39, eerste_paasdag), 'Hemelvaartsdag'     from pasen union all
    select dateadd('day',  49, eerste_paasdag), 'Eerste Pinksterdag' from pasen union all
    select dateadd('day',  50, eerste_paasdag), 'Tweede Pinksterdag' from pasen

)

select ds.datum                                                                                as datum
     , to_char(ds.datum, 'YYYYMMDD')::number                                                  as datum_sleutel

     -- ── Dag ─────────────────────────────────────────────────────────────────────
     , day(ds.datum)                                                                            as dag_nr
     , dayofyear(ds.datum)                                                                      as dag_van_jaar
     , dayofweekiso(ds.datum)                                                                   as dag_van_week_nr   -- 1 = ma, 7 = zo
     {% if taal == 'nl' %}
     , case dayofweekiso(ds.datum)
           when 1 then 'maandag'   when 2 then 'dinsdag'   when 3 then 'woensdag'
           when 4 then 'donderdag' when 5 then 'vrijdag'   when 6 then 'zaterdag'
           when 7 then 'zondag'    end                                                          as weekdag
     , case dayofweekiso(ds.datum)
           when 1 then 'ma' when 2 then 'di' when 3 then 'wo'
           when 4 then 'do' when 5 then 'vr' when 6 then 'za'
           when 7 then 'zo' end                                                                 as weekdag_afk
     {% elif taal == 'en' %}
     , dayname(ds.datum)                                                                        as weekdag          -- Mon, Tue, ...
     , left(dayname(ds.datum), 2)                                                               as weekdag_afk
     {% endif %}
     , dayofweekiso(ds.datum) >= 6                                                              as is_weekend
     , dayofweekiso(ds.datum) <  6 and fd.feestdag_naam is null                                as is_werkdag

     -- ── Week ─────────────────────────────────────────────────────────────────────
     , week(ds.datum)                                                                           as weeknummer        -- kalenderweek (1-53)
     , weekiso(ds.datum)                                                                        as iso_weeknummer    -- ISO 8601 weeknummer
     , yearofweekiso(ds.datum)                                                                  as iso_week_jaar
     , yearofweekiso(ds.datum)::string
       || '-W' || lpad(weekiso(ds.datum)::string, 2, '0')                                      as iso_week_label

     -- ── Maand ────────────────────────────────────────────────────────────────────
     , month(ds.datum)                                                                          as maand_nr
     {% if taal == 'nl' %}
     , case month(ds.datum)
           when 1  then 'januari'   when 2  then 'februari' when 3  then 'maart'
           when 4  then 'april'     when 5  then 'mei'      when 6  then 'juni'
           when 7  then 'juli'      when 8  then 'augustus' when 9  then 'september'
           when 10 then 'oktober'   when 11 then 'november' when 12 then 'december' end        as maand_naam
     , case month(ds.datum)
           when 1  then 'jan' when 2  then 'feb' when 3  then 'mrt'
           when 4  then 'apr' when 5  then 'mei' when 6  then 'jun'
           when 7  then 'jul' when 8  then 'aug' when 9  then 'sep'
           when 10 then 'okt' when 11 then 'nov' when 12 then 'dec' end                        as maand_afk
     {% elif taal == 'en' %}
     , monthname(ds.datum)                                                                      as maand_naam        -- January, ...
     , left(monthname(ds.datum), 3)                                                             as maand_afk         -- Jan, ...
     {% endif %}
     , year(ds.datum)::string
       || '-' || lpad(month(ds.datum)::string, 2, '0')                                         as maand_label

     -- ── Kwartaal ─────────────────────────────────────────────────────────────────
     , quarter(ds.datum)                                                                        as kwartaal
     , year(ds.datum)::string || '-Q' || quarter(ds.datum)::string                             as kwartaal_label

     -- ── Jaar ─────────────────────────────────────────────────────────────────────
     , year(ds.datum)                                                                           as jaar

     -- ── Fiscale kalender (startmaand: {{ fiscal_year_start_month }}) ─────────────
     , iff(month(ds.datum) >= {{ fiscal_year_start_month }},
           year(ds.datum),
           year(ds.datum) - 1)                                                                  as fiscaal_jaar
     , mod(month(ds.datum) - {{ fiscal_year_start_month }} + 12, 12) + 1                       as fiscaal_maand_nr
     , ceil((mod(month(ds.datum) - {{ fiscal_year_start_month }} + 12, 12) + 1) / 3.0)         as fiscaal_kwartaal
     , 'FY' || iff(month(ds.datum) >= {{ fiscal_year_start_month }},
                   year(ds.datum), year(ds.datum) - 1)::string
       || '-Q' || ceil((mod(month(ds.datum) - {{ fiscal_year_start_month }} + 12, 12) + 1) / 3.0)::string as fiscaal_kwartaal_label

     -- ── Feestdagen ───────────────────────────────────────────────────────────────
     , fd.feestdag_naam is not null                                                             as is_feestdag
     , fd.feestdag_naam

     -- ── Schoolvakanties ──────────────────────────────────────────────────────────
     {% if schoolvakanties is not none %}
     , sv.vakantie_naam is not null                                                             as is_schoolvakantie
     , sv.vakantie_naam                                                                         as schoolvakantie_naam
     {% endif %}

  from date_spine ds
  left join feestdagen fd on fd.datum = ds.datum
  {% if schoolvakanties is not none %}
  left join schoolvakanties_gefilterd sv
    on  ds.datum between sv.van_datum and sv.tot_datum
  {% endif %}
 order by ds.datum

{% endmacro %}
