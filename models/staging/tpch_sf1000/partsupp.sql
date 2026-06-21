select * from {{ source('tpch_sf1000', 'partsupp') }}
