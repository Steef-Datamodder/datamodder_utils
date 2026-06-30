{%- macro _datamodder_schema() -%}
{{ return(var('datamodder_schema', 'datamodder')) }}
{%- endmacro -%}

-- uniform_datatypes: standaardprecisie voor decimale velden
-- overschrijf in dbt_project.yml: vars: { uniform_datatypes_voor_komma: 15, uniform_datatypes_na_komma: 2 }
{%- macro _uniform_datatypes_voor_komma() -%}
{{ return(var('uniform_datatypes_voor_komma', 18)) }}
{%- endmacro -%}

{%- macro _uniform_datatypes_na_komma() -%}
{{ return(var('uniform_datatypes_na_komma', 4)) }}
{%- endmacro -%}

{%- macro _dim_datum_taal() -%}
{{ return(var('dim_datum_taal', 'nl')) }}
{%- endmacro -%}

-- Schoolvakanties: zet 'dim_datum_schoolvakanties_tabel' op de naam van je ref/source
-- bijv. in dbt_project.yml:
--   vars:
--     dim_datum_schoolvakanties_tabel: ref('schoolvakanties')   -- of: source('raw', 'schoolvakanties')
--     dim_datum_schoolvakantie_land:   'NL'
--     dim_datum_schoolvakantie_regio:  'Noord'                  -- optioneel
{%- macro _dim_datum_schoolvakanties() -%}
{{ return(var('dim_datum_schoolvakanties_tabel', none)) }}
{%- endmacro -%}

{%- macro _dim_datum_schoolvakantie_land() -%}
{{ return(var('dim_datum_schoolvakantie_land', none)) }}
{%- endmacro -%}

{%- macro _dim_datum_schoolvakantie_regio() -%}
{{ return(var('dim_datum_schoolvakantie_regio', none)) }}
{%- endmacro -%}
