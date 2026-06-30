use role dbt_role;
use warehouse MY_WAREHOUSE;   -- change to your warehouse
use database MY_DATABASE;     -- change to your database

-- ----------------------------------------------------------------
-- setup: lookup table with fruit (apple 5x for weighted test)
-- ----------------------------------------------------------------
create or replace table datamodder.abc as
select value::varchar as xyz
from table(flatten(input => parse_json('["apple","apple","apple","apple","apple","pear","banana","strawberry","mango","kiwi","grape","orange","cherry","pineapple"]')));

-- ----------------------------------------------------------------
-- setup: combined test table covering all anonymization methods
-- ----------------------------------------------------------------
create or replace table datamodder.test_anonymize (
    id integer,
    naam varchar, -- shuffle_name
    adres varchar, -- shuffle (group with postcode + huisnummer)
    postcode varchar, -- shuffle (group with adres + huisnummer)
    huisnummer varchar, -- shuffle (group with adres + postcode), then shift_housenumber
    telefoon varchar, -- shuffle_phone
    categorie varchar, -- random_lookup uniform=true
    segment varchar -- random_lookup uniform=false
);

insert into datamodder.test_anonymize values
    -- 06- numbers (2-digit prefix, 8-digit suffix)
    (1, 'Jan de Vries', 'Kerkstraat', '1234 AB', '12', '06-12345678', null, null),          -- infix: de
    (2, 'Maria Bakker', 'Hoofdstraat', '2345 BC', '34B', '06-23456789', null, null),          -- no infix
    (3, 'Piet Janssen', 'Molenweg', '3456 CD', '5', '06-34567890', null, null),               -- no infix
    (4, 'Anna Smit', 'Dorpsstraat', '4567 DE', '78C', '06-45678901', null, null),             -- no infix
    (5, 'P.J. van den Berg', 'Lindelaan', '5678 EF', '3 bis', '06-56789012', null, null),    -- initials + multi-word infix
    -- 085- numbers (3-digit prefix, 7-digit suffix)
    (6, 'Truus van Dijk', 'Parallelweg', '6789 FG', '100', '085-1234567', null, null),        -- infix: van
    (7, 'Henk de Boer', 'Stationsstraat', '7890 GH', '2A', '085-2345678', null, null),        -- infix: de
    (8, 'Pieter Jan van Boven', 'Nieuwstraat', '8901 HI', '55', '088-3456789', null, null),   -- two voornamen + infix
    -- 0800- numbers (4-digit prefix, 5-digit suffix)
    (9, 'Youssef el Amrani', 'Schoolstraat', '9012 IJ', '7', '0800-12345', null, null),       -- infix: el
    (10, 'Griet Postma', 'Beatrixlaan', '0123 JK', '19D', '0900-54321', null, null);          -- no infix

-- save original values for comparison
create or replace temporary table datamodder.temp_voor as
select * from datamodder.test_anonymize;

-- ----------------------------------------------------------------
-- anonymize all columns at once
-- ----------------------------------------------------------------
call datamodder.anonymize(
    'datamodder.test_anonymize',
    'id',
    parse_json('[
        {"column": "naam", "method": "shuffle_name"},
        {"column": ["adres", "postcode", "huisnummer"], "method": "shuffle"},
        {"column": "huisnummer", "method": "shift_housenumber"},
        {"column": "telefoon", "method": "shuffle_phone"},
        {"column": "categorie", "method": "random_lookup", "source": "datamodder.abc", "source_column": "xyz", "uniform": true},
        {"column": "segment", "method": "random_lookup", "source": "datamodder.abc", "source_column": "xyz", "uniform": false}
    ]')
);

-- ----------------------------------------------------------------
-- comparison: before and after side by side
-- ----------------------------------------------------------------
select n.id
     , o.naam as naam_before
     , n.naam as naam_after
     , o.adres as adres_before
     , n.adres as adres_after
     , o.postcode as postcode_before
     , n.postcode as postcode_after
     , o.huisnummer as huisnummer_before
     , n.huisnummer as huisnummer_after
     , o.telefoon as telefoon_before
     , n.telefoon as telefoon_after
     , o.categorie as categorie_before
     , n.categorie as categorie_after
     , o.segment as segment_before
     , n.segment as segment_after
from datamodder.test_anonymize n
join datamodder.temp_voor o on n.id = o.id
order by n.id;
