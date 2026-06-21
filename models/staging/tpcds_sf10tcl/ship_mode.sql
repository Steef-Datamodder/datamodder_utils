select * from {{ source('tpcds_sf10tcl', 'ship_mode') }}
