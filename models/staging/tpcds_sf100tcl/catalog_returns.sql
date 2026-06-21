select * from {{ source('tpcds_sf100tcl', 'catalog_returns') }}
