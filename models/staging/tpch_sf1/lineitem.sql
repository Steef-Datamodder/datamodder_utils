select * from {{ source('tpch_sf1', 'lineitem') }}
