select * from {{ source('tpcds_sf100tcl', 'customer_demographics') }}
