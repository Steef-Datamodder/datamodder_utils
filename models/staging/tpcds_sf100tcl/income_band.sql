select * from {{ source('tpcds_sf100tcl', 'income_band') }}
