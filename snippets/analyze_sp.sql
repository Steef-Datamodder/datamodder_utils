-- ── Setup ────────────────────────────────────────────────────────────────────
-- Run create_analyze_sp.sql once to create all objects.
-- Adjust the variables at the top of that file to match your environment.

-- ── Run ──────────────────────────────────────────────────────────────────────
-- 1. Create a point-in-time snapshot of the source table
call create_pit();

-- 2. Register all new PIT tables in the statistics table
call register_pits();

-- 3. Calculate and store statistics per column
call update_statistics();

-- ── Optional: specify a different source ─────────────────────────────────────
call create_pit('snowflake_sample_data', 'tpch_sf1', 'orders');
