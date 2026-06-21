select * from {{ source('tpcds_sf10tcl', 'date_dim') }}
