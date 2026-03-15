-- ============================================================
-- Catalog Product Line
-- 1. Add 'catalog' ProductType per organization
-- 2. Add 'catalog' BOMTemplate per organization (empty, pass-through)
-- 3. Migrate existing 'accessories' QuoteLines → 'catalog'
-- 4. Function create_catalog_configured_product
-- ============================================================

BEGIN;

-- ============================================================
-- 1. ProductType 'catalog' per org
-- ============================================================
INSERT INTO public."ProductTypes" (organization_id, code, name, sort_order, status)
SELECT
  pt.organization_id,
  'catalog',
  'Catalog',
  100,
  'active'
FROM public."ProductTypes" pt
WHERE pt.code = 'roller'
  AND NOT EXISTS (
    SELECT 1 FROM public."ProductTypes" WHERE organization_id = pt.organization_id AND code = 'catalog'
  );

-- ============================================================
-- 2. BOMTemplate 'catalog' per org (no components — pass-through)
-- ============================================================
INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, archived, is_active, sort_order, deleted, panel_count_min, panel_count_max)
SELECT
  pt.organization_id,
  pt.id,
  'catalog',
  'Catalog Item',
  false,
  true,
  100,
  false,
  1,
  1
FROM public."ProductTypes" pt
WHERE pt.code = 'catalog'
  AND NOT EXISTS (
    SELECT 1 FROM public."BOMTemplates" bt
    WHERE bt.organization_id = pt.organization_id AND bt.code = 'catalog'
  );

-- ============================================================
-- 3. Migrate existing 'accessories' QuoteLines → 'catalog'
-- ============================================================
UPDATE public."QuoteLines" ql
SET product_type = 'catalog'
WHERE product_type = 'accessories';

-- ============================================================
-- 3b. Add 'catalog' to DealerConfiguratorPolicies allowed codes
-- ============================================================
UPDATE public."DealerConfiguratorPolicies"
SET allowed_product_type_codes = array_append(allowed_product_type_codes, 'catalog')
WHERE NOT ('catalog' = ANY(COALESCE(allowed_product_type_codes, '{}'::text[])));

-- ============================================================
-- 4. Function: create_catalog_configured_product
--    Creates a ConfiguredProduct for a single catalog item (1 SKU × qty).
--    Uses the org's catalog BOMTemplate (no components).
--    Builds a minimal bom_preview_snapshot so MO can reference the item.
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_catalog_configured_product(
  p_org_id          uuid,
  p_product_type_id uuid,
  p_quote_id        uuid,
  p_catalog_item_id uuid,
  p_qty             numeric,
  p_unit_msrp       numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bom_template_id     uuid;
  v_configured_product_id uuid;
  v_total_msrp          numeric;
  v_total_cost          numeric;
  v_item_name           text;
  v_item_sku            text;
  v_cost_exw            numeric;
  v_bom_preview         jsonb;
  v_config_snapshot     jsonb;
BEGIN
  -- Resolve catalog BOM template for this org
  SELECT id INTO v_bom_template_id
  FROM "BOMTemplates"
  WHERE organization_id = p_org_id
    AND code = 'catalog'
    AND deleted = false
  LIMIT 1;

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No catalog BOM template found for organization %', p_org_id;
  END IF;

  -- Fetch item info
  SELECT name, sku, cost_exw
  INTO v_item_name, v_item_sku, v_cost_exw
  FROM "CatalogItems"
  WHERE id = p_catalog_item_id
  LIMIT 1;

  v_total_msrp := COALESCE(p_qty, 1) * COALESCE(p_unit_msrp, 0);
  v_total_cost := COALESCE(p_qty, 1) * COALESCE(v_cost_exw, 0);

  -- Build config_snapshot
  v_config_snapshot := jsonb_build_object(
    'productType',      'catalog',
    'catalog_item_id',  p_catalog_item_id,
    'name',             COALESCE(v_item_name, ''),
    'sku',              COALESCE(v_item_sku, ''),
    'qty',              COALESCE(p_qty, 1),
    'unit_msrp',        COALESCE(p_unit_msrp, 0),
    'bom_template_id',  v_bom_template_id
  );

  -- Build bom_preview_snapshot with a single catalog item (kind='accessory' for MO compatibility)
  v_bom_preview := jsonb_build_object(
    'version',          '1',
    'product_type_id',  p_product_type_id,
    'bom_template_id',  v_bom_template_id,
    'price_basis',      'msrp',
    'currency',         'USD',
    'items', jsonb_build_array(
      jsonb_build_object(
        'id',               gen_random_uuid(),
        'kind',             'accessory',
        'role',             'catalog_item',
        'level',            0,
        'selected',         true,
        'catalog_item_id',  p_catalog_item_id,
        'sku',              COALESCE(v_item_sku, ''),
        'name',             COALESCE(v_item_name, ''),
        'qty',              COALESCE(p_qty, 1),
        'uom',              'ea',
        'unit_price',       COALESCE(p_unit_msrp, 0),
        'line_total',       v_total_msrp
      )
    ),
    'totals', jsonb_build_object(
      'roll_msrp_total',      0,
      'bom_total',            0,
      'accessories_total',    v_total_msrp,
      'labor_pct',            0,
      'labor_amount',         0,
      'total_msrp',           v_total_msrp,
      'roll_total_cost',      0,
      'bom_total_cost',       0,
      'accessories_total_cost', v_total_cost,
      'unit_product_cost',    v_total_cost,
      'unit_labor_cost',      0,
      'total_cost',           v_total_cost
    )
  );

  -- Insert ConfiguredProduct
  INSERT INTO public."ConfiguredProducts" (
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    quantity,
    config_snapshot,
    bom_preview_snapshot,
    roll_msrp_total,
    bom_total,
    accessories_total,
    total_msrp,
    msrp_product_subtotal,
    unit_msrp_total,
    roll_total_cost,
    bom_total_cost,
    accessories_total_cost,
    unit_product_cost,
    unit_labor_cost,
    total_cost,
    labor_pct,
    labor_amount,
    labor_msrp,
    deleted
  )
  VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    COALESCE(p_qty, 1),
    v_config_snapshot,
    v_bom_preview,
    0,
    0,
    v_total_msrp,
    v_total_msrp,
    v_total_msrp,
    v_total_msrp,
    0,
    0,
    v_total_cost,
    v_total_cost,
    0,
    v_total_cost,
    0,
    0,
    0,
    false
  )
  RETURNING id INTO v_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_template_id',       v_bom_template_id,
    'total_msrp',            v_total_msrp,
    'total_cost',            v_total_cost
  );
END;
$$;

COMMIT;
