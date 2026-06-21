select * from {{ source('tpcds_sf10tcl', 'income_band') }}
