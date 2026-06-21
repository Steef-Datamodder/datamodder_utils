select * from {{ source('tpcds_sf10tcl', 'household_demographics') }}
