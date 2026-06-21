select * from {{ source('tpcds_sf100tcl', 'store_returns') }}
