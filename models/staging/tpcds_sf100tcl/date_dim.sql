select * from {{ source('tpcds_sf100tcl', 'date_dim') }}
