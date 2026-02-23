-- Migration: Remove _landed cost columns from ConfiguredProducts
-- Replaces legacy naming with: roll_total_cost, bom_total_cost, accessories_total_cost,
-- unit_product_cost, total_cost. Source of truth: CatalogItemsMSRP.

-- STEP 1: Backfill unit_product_cost_landed from total_cost_landed_without_labor if needed
-- (Skip if columns already renamed by a prior run)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_product_cost_landed'
  ) THEN
    UPDATE public."ConfiguredProducts"
    SET unit_product_cost_landed = COALESCE(NULLIF(unit_product_cost_landed, 0), total_cost_landed_without_labor)
    WHERE (unit_product_cost_landed IS NULL OR unit_product_cost_landed = 0)
      AND total_cost_landed_without_labor IS NOT NULL
      AND total_cost_landed_without_labor > 0;
  END IF;
END $$;

-- STEP 2: Rename ConfiguredProducts columns (skip if already renamed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'roll_total_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" RENAME COLUMN roll_total_cost_landed TO roll_total_cost;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'bom_total_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" RENAME COLUMN bom_total_cost_landed TO bom_total_cost;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'accessories_total_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" RENAME COLUMN accessories_total_cost_landed TO accessories_total_cost;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_product_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" RENAME COLUMN unit_product_cost_landed TO unit_product_cost;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'total_cost_with_labor') THEN
    ALTER TABLE public."ConfiguredProducts" RENAME COLUMN total_cost_with_labor TO total_cost;
  END IF;
END $$;

-- STEP 3: Drop redundant column (unit_product_cost = roll + bom + accessories)
ALTER TABLE public."ConfiguredProducts" DROP COLUMN IF EXISTS total_cost_landed_without_labor;

-- STEP 4: Update column comments
COMMENT ON COLUMN public."ConfiguredProducts".roll_total_cost IS 'Roll cost from CatalogItemsMSRP.total_cost.';
COMMENT ON COLUMN public."ConfiguredProducts".bom_total_cost IS 'BOM components cost from CatalogItemsMSRP.';
COMMENT ON COLUMN public."ConfiguredProducts".accessories_total_cost IS 'Accessories cost from CatalogItemsMSRP.';
COMMENT ON COLUMN public."ConfiguredProducts".unit_product_cost IS 'Per-unit product cost (roll + BOM + accessories), without labor.';
COMMENT ON COLUMN public."ConfiguredProducts".total_cost IS 'Per-unit total cost including labor.';

-- STEP 5: Temporary compatibility view (exposes *_landed aliases for legacy consumers)
CREATE OR REPLACE VIEW public.v_configured_products_legacy_costs AS
SELECT
  id,
  organization_id,
  roll_total_cost AS roll_total_cost_landed,
  bom_total_cost AS bom_total_cost_landed,
  accessories_total_cost AS accessories_total_cost_landed,
  unit_product_cost AS unit_product_cost_landed,
  unit_product_cost AS total_cost_landed_without_labor,
  total_cost AS total_cost_with_labor
FROM public."ConfiguredProducts";

COMMENT ON VIEW public.v_configured_products_legacy_costs IS 'Temporary view exposing cost columns as *_landed aliases. Use ConfiguredProducts directly with new column names.';
