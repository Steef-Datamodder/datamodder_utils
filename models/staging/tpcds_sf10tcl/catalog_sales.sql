select * from {{ source('tpcds_sf10tcl', 'catalog_sales') }}
