select * from {{ source('tpcds_sf100tcl', 'time_dim') }}
