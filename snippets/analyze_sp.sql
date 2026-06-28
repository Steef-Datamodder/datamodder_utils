-- ── Setup ────────────────────────────────────────────────────────────────────
-- Voer create_analyze_sp.sql eenmalig uit om de objecten aan te maken.
-- Pas bovenin dat bestand de variabelen aan naar jouw situatie.

-- ── Uitvoeren ────────────────────────────────────────────────────────────────
-- 1. Maak een point-in-time snapshot van de brontabel
call create_pit();

-- 2. Registreer alle nieuwe PIT-tabellen in de statistiekentabel
call register_pits();

-- 3. Bereken en sla statistieken op per kolom
call update_statistics();

-- ── Optioneel: andere bron meegeven ──────────────────────────────────────────
call create_pit('snowflake_sample_data', 'tpch_sf1', 'orders');
