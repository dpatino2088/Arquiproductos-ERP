-- ====================================================
-- Migration: Create Staging Table for CSV Import
-- ====================================================
-- This creates a staging table to import CSV data
-- ====================================================

BEGIN;

-- Drop staging table if exists
DROP TABLE IF EXISTS public."_stg_catalog_items";

-- Create staging table matching CSV structure EXACTLY (case-sensitive)
-- Note: Column names must match CSV headers exactly
-- However, Supabase will convert to lowercase when importing
CREATE TABLE public."_stg_catalog_items" (
    "sku" text,
    "Collection" text,           -- Must match CSV header exactly
    "Variant" text,               -- Must match CSV header exactly
    "Item_name" text,             -- Must match CSV header exactly
    "Item_description" text,      -- Must match CSV header exactly
    "item_type" text,
    "measure_basis" text,
    "uom" text,
    "is_fabric" text,             -- CSV has TRUE/FALSE as text, we'll convert
    "roll_width_m" text,          -- CSV may have empty values
    "fabric_pricing_mode" text,   -- CSV may have empty values
    "active" text,                -- CSV has TRUE/FALSE as text
    "discontinued" text,          -- CSV has TRUE/FALSE as text
    "manufacturer" text,
    "category" text,
    "family" text
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_stg_catalog_items_sku 
    ON public."_stg_catalog_items"("sku");

CREATE INDEX IF NOT EXISTS idx_stg_catalog_items_collection 
    ON public."_stg_catalog_items"("Collection") 
    WHERE "Collection" IS NOT NULL;

COMMIT;

-- ====================================================
-- Instructions:
-- 1. Import CSV into this staging table using Supabase Table Editor
--    or use COPY command:
--    COPY public."_stg_catalog_items" FROM '/path/to/catalog_items_import_DP_COLLECTIONS_FINAL.csv' 
--    WITH (FORMAT csv, HEADER true, DELIMITER ',');
-- 
-- 2. After import, run 03_import_catalog_from_staging.sql
-- 
-- Note: Supabase may convert column names to lowercase when importing
-- ====================================================













