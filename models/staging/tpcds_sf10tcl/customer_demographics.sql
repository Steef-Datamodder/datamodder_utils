select * from {{ source('tpcds_sf10tcl', 'customer_demographics') }}
