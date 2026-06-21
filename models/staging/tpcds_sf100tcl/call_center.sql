select * from {{ source('tpcds_sf100tcl', 'call_center') }}
