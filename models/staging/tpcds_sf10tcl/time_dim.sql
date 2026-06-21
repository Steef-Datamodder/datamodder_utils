select * from {{ source('tpcds_sf10tcl', 'time_dim') }}
