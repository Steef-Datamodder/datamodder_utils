select * from {{ source('tpcds_sf10tcl', 'web_returns') }}
