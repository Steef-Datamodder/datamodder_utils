select * from {{ source('tpcds_sf100tcl', 'web_sales') }}
