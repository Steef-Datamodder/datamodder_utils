select * from {{ source('tpcds_sf100tcl', 'inventory') }}
