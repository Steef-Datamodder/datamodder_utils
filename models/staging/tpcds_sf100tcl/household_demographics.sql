select * from {{ source('tpcds_sf100tcl', 'household_demographics') }}
