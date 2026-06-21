select * from {{ source('tpch_sf100', 'partsupp') }}
