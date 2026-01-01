-- ========================================
-- FIX: BOM Completo - UOM + Componentes + Accessories
-- ========================================
-- Este script corrige UOM, regenera BOM y verifica accessories
-- INSTRUCTIONS: Replace 'SO-000007' with your Sale Order number
-- ========================================

DO $$
DECLARE
  v_quote_line_id uuid;
  v_product_type_id uuid;
  v_organization_id uuid;
  v_drive_type text;
  v_bottom_rail_type text;
  v_cassette boolean;
  v_cassette_type text;
  v_side_channel boolean;
  v_side_channel_type text;
  v_hardware_color text;
  v_width_m numeric;
  v_height_m numeric;
  v_qty numeric;
  v_updated_count integer;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING BOM COMPLETO';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Get QuoteLine configuration
  SELECT 
    ql.id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.cassette_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty
  INTO 
    v_quote_line_id,
    v_product_type_id,
    v_organization_id,
    v_drive_type,
    v_bottom_rail_type,
    v_cassette,
    v_cassette_type,
    v_side_channel,
    v_side_channel_type,
    v_hardware_color,
    v_width_m,
    v_height_m,
    v_qty
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1;

  IF v_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found for Sale Order SO-000007';
  END IF;

  RAISE NOTICE '✅ QuoteLine ID: %', v_quote_line_id;
  RAISE NOTICE '✅ Product Type ID: %', v_product_type_id;
  RAISE NOTICE '✅ Organization ID: %', v_organization_id;
  RAISE NOTICE '';

  -- Step 1: Fix UOM in QuoteLineComponents (fabrics)
  RAISE NOTICE 'Step 1: Fixing UOM in QuoteLineComponents...';
  
  UPDATE "QuoteLineComponents" qlc
  SET 
    uom = CASE 
      WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
      WHEN ci.fabric_pricing_mode = 'per_sqm' OR ci.fabric_pricing_mode IS NULL THEN 'm2'
      ELSE 'm2'
    END,
    updated_at = NOW()
  FROM "CatalogItems" ci
  WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.catalog_item_id = ci.id
    AND qlc.deleted = false
    AND ci.is_fabric = true
    AND (qlc.uom IS NULL OR qlc.uom = 'ea' OR qlc.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed UOM for % fabric components', v_updated_count;
  ELSE
    RAISE NOTICE 'ℹ️  No fabric UOM issues found';
  END IF;

  -- Step 2: Delete old configured components (to regenerate)
  RAISE NOTICE '';
  RAISE NOTICE 'Step 2: Deleting old configured components...';
  
  DELETE FROM "QuoteLineComponents"
  WHERE quote_line_id = v_quote_line_id
    AND source = 'configured_component'
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Deleted % old configured components', v_updated_count;
  ELSE
    RAISE NOTICE 'ℹ️  No old configured components to delete';
  END IF;

  -- Step 3: Regenerate BOM
  RAISE NOTICE '';
  RAISE NOTICE 'Step 3: Regenerating BOM...';
  
  PERFORM public.generate_configured_bom_for_quote_line(
    p_quote_line_id := v_quote_line_id,
    p_product_type_id := v_product_type_id,
    p_organization_id := v_organization_id,
    p_drive_type := COALESCE(v_drive_type, 'motor'),
    p_bottom_rail_type := COALESCE(v_bottom_rail_type, 'standard'),
    p_cassette := COALESCE(v_cassette, false),
    p_cassette_type := v_cassette_type,
    p_side_channel := COALESCE(v_side_channel, false),
    p_side_channel_type := v_side_channel_type,
    p_hardware_color := COALESCE(v_hardware_color, 'white'),
    p_width_m := COALESCE(v_width_m, 0),
    p_height_m := COALESCE(v_height_m, 0),
    p_qty := COALESCE(v_qty, 1)
  );

  RAISE NOTICE '✅ BOM regeneration completed';
  RAISE NOTICE '';

  -- Step 4: Fix UOM again (in case new components have wrong UOM)
  RAISE NOTICE 'Step 4: Fixing UOM in newly generated components...';
  
  UPDATE "QuoteLineComponents" qlc
  SET 
    uom = CASE 
      WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
      WHEN ci.fabric_pricing_mode = 'per_sqm' OR ci.fabric_pricing_mode IS NULL THEN 'm2'
      ELSE 'm2'
    END,
    updated_at = NOW()
  FROM "CatalogItems" ci
  WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.catalog_item_id = ci.id
    AND qlc.deleted = false
    AND ci.is_fabric = true
    AND (qlc.uom IS NULL OR qlc.uom = 'ea' OR qlc.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed UOM for % newly generated fabric components', v_updated_count;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✨ FIX COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '1. Verify QuoteLineComponents with DIAGNOSTICO_COMPLETO_BOM.sql';
  RAISE NOTICE '2. Re-approve Quote to copy components to BomInstanceLines';
  RAISE NOTICE '3. Verify BomInstanceLines has all components';
  RAISE NOTICE '';

END $$;

-- Verification: Show QuoteLineComponents after fix
SELECT 
  'Verification: QuoteLineComponents After Fix' as check_name,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  CASE 
    WHEN ci.is_fabric = true AND qlc.uom = 'ea' THEN '❌ STILL WRONG'
    WHEN ci.is_fabric = true AND qlc.uom IN ('m', 'm2') THEN '✅ FIXED'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE qlc.source
    WHEN 'configured_component' THEN 1
    WHEN 'accessory' THEN 2
    ELSE 99
  END,
  qlc.component_role;








