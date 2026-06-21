@echo off

if not exist "..\models\staging\sources" mkdir "..\models\staging\sources"

for %%F in (
  tpcds_sf100tcl
  tpcds_sf10tcl
  tpch_sf1
  tpch_sf10
  tpch_sf100
  tpch_sf1000
) do (
  echo version: 1 > "..\models\staging\sources\%%F.yml"
  echo. >> "..\models\staging\sources\%%F.yml"
  echo sources: >> "..\models\staging\sources\%%F.yml"
  echo. >> "..\models\staging\sources\%%F.yml"
)
for %%F in (
tpch_sf100
tpch_sf1
tpch_sf10
tpcds_sf100tcl
tpch_sf1000
tpcds_sf10tcl
) do (
  mkdir "..\models\staging\%%F"
)

