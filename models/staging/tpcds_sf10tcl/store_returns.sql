select * from {{ source('tpcds_sf10tcl', 'store_returns') }}
