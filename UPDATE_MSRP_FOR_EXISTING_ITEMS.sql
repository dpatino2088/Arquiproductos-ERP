-- Script: Update MSRP for existing CatalogItems using margin-on-sale formula
-- Description: Calculates and updates MSRP for all items that don't have msrp_manual = true
-- Formula: msrp = cost_exw / (1 - margin_pct / 100)
-- Margin priority: Category margin > Item default_margin_pct > 35% fallback
-- Date: 2024-12-24
-- 
-- NOTE: This simplified version uses only cost_exw for calculation.
-- If you want to include labor, shipping, freight, handling, and import_tax costs,
-- you can update items individually through the UI, or run the advanced version below
-- (uncomment it) if those columns exist in your database.

-- ============================================
-- Step 1: Create function to calculate MSRP from margin-on-sale
-- ============================================
CREATE OR REPLACE FUNCTION calculate_msrp_from_margin_on_sale(
  p_total_cost numeric,
  p_margin_pct numeric
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_safe_margin numeric;
  v_msrp numeric;
BEGIN
  -- Handle edge cases
  IF p_total_cost <= 0 THEN
    RETURN 0;
  END IF;
  
  -- Clamp margin to safe range [0, 95]
  v_safe_margin := GREATEST(0, LEAST(95, COALESCE(p_margin_pct, 35)));
  
  -- Prevent division by zero (margin >= 100%)
  IF v_safe_margin >= 100 THEN
    RETURN p_total_cost * 100; -- Fallback for extreme cases
  END IF;
  
  -- Margin-on-sale formula: msrp = cost / (1 - margin/100)
  v_msrp := p_total_cost / (1 - v_safe_margin / 100);
  
  -- Round to 2 decimal places
  RETURN ROUND(v_msrp, 2);
END;
$$;

-- ============================================
-- Step 2: Update MSRP for existing CatalogItems (SIMPLIFIED VERSION)
-- Uses only cost_exw (safe - this column definitely exists)
-- ============================================
UPDATE "CatalogItems" ci
SET 
  "msrp" = calculate_msrp_from_margin_on_sale(
    COALESCE(ci."cost_exw", 0),
    COALESCE(
      -- Category margin (if exists and active)
      (SELECT cm."margin_percentage" 
       FROM "CategoryMargins" cm 
       WHERE cm."category_id" = ci."item_category_id"
         AND cm."organization_id" = ci."organization_id"
         AND cm."active" = true
         AND (cm."deleted" IS NULL OR cm."deleted" = false)
       ORDER BY cm."created_at" DESC
       LIMIT 1),
      -- Item margin (default_margin_pct)
      ci."default_margin_pct",
      -- Fallback
      35.0
    )
  ),
  "updated_at" = NOW()
WHERE ci."deleted" = false
  AND COALESCE(ci."cost_exw", 0) > 0
  AND (
    -- Only update items where msrp_manual = false OR msrp is NULL/0
    COALESCE(ci."msrp_manual", false) = false
    OR ci."msrp" IS NULL
    OR ci."msrp" = 0
  );

-- ============================================
-- Step 3: ADVANCED VERSION (uncomment ONLY if columns exist)
-- This version includes all cost components (labor, shipping, freight, handling, import_tax)
-- ============================================
/*
-- WARNING: Only uncomment and run this if these columns exist in CatalogItems:
-- - labor_cost_per_unit
-- - shipping_cost_per_unit
-- - freight_cost
-- - handling_cost
-- - import_tax_pct

UPDATE "CatalogItems" ci
SET 
  "msrp" = calculate_msrp_from_margin_on_sale(
    -- Calculate total_unit_cost with all components
    COALESCE(ci."cost_exw", 0) 
      + COALESCE(ci."labor_cost_per_unit", 0)
      + COALESCE(ci."shipping_cost_per_unit", 0)
      + COALESCE(ci."freight_cost", 0)
      + COALESCE(ci."handling_cost", 0)
      + (COALESCE(ci."cost_exw", 0) * COALESCE(ci."import_tax_pct", 0) / 100),
    -- Resolve margin percentage (priority: Category > Item > 35%)
    COALESCE(
      (SELECT cm."margin_percentage" 
       FROM "CategoryMargins" cm 
       WHERE cm."category_id" = ci."item_category_id"
         AND cm."organization_id" = ci."organization_id"
         AND cm."active" = true
         AND (cm."deleted" IS NULL OR cm."deleted" = false)
       ORDER BY cm."created_at" DESC
       LIMIT 1),
      ci."default_margin_pct",
      35.0
    )
  ),
  "updated_at" = NOW()
WHERE ci."deleted" = false
  AND (
    COALESCE(ci."cost_exw", 0) > 0
    OR COALESCE(ci."labor_cost_per_unit", 0) > 0
    OR COALESCE(ci."shipping_cost_per_unit", 0) > 0
    OR COALESCE(ci."freight_cost", 0) > 0
    OR COALESCE(ci."handling_cost", 0) > 0
  )
  AND (
    COALESCE(ci."msrp_manual", false) = false
    OR ci."msrp" IS NULL
    OR ci."msrp" = 0
  );
*/

-- ============================================
-- Verification query (run separately to check results)
-- ============================================
-- SELECT 
--   ci."sku",
--   ci."item_name",
--   ci."cost_exw",
--   ci."msrp" AS current_msrp,
--   ci."msrp_manual",
--   ci."default_margin_pct",
--   (SELECT cm."margin_percentage" 
--    FROM "CategoryMargins" cm 
--    WHERE cm."category_id" = ci."item_category_id"
--      AND cm."organization_id" = ci."organization_id"
--      AND cm."active" = true
--      AND (cm."deleted" IS NULL OR cm."deleted" = false)
--    LIMIT 1) AS category_margin,
--   calculate_msrp_from_margin_on_sale(
--     COALESCE(ci."cost_exw", 0),
--     COALESCE(
--       (SELECT cm."margin_percentage" 
--        FROM "CategoryMargins" cm 
--        WHERE cm."category_id" = ci."item_category_id"
--          AND cm."organization_id" = ci."organization_id"
--          AND cm."active" = true
--          AND (cm."deleted" IS NULL OR cm."deleted" = false)
--        LIMIT 1),
--       ci."default_margin_pct",
--       35.0
--     )
--   ) AS calculated_msrp
-- FROM "CatalogItems" ci
-- WHERE ci."deleted" = false
-- ORDER BY ci."updated_at" DESC
-- LIMIT 20;

-- ============================================
-- Summary (run separately)
-- ============================================
-- SELECT 
--   COUNT(*) FILTER (WHERE "msrp" IS NOT NULL AND "msrp" > 0) AS items_with_msrp,
--   COUNT(*) FILTER (WHERE "msrp" IS NULL OR "msrp" = 0) AS items_without_msrp,
--   COUNT(*) FILTER (WHERE "msrp_manual" = true) AS items_with_manual_msrp,
--   COUNT(*) AS total_items
-- FROM "CatalogItems"
-- WHERE "deleted" = false;
