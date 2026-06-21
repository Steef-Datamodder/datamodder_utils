select * from {{ source('tpcds_sf100tcl', 'ship_mode') }}
