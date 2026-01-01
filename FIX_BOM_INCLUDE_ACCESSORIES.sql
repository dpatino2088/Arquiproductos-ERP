-- ========================================
-- FIX: Include Accessories in BomInstanceLines
-- ========================================
-- This script manually copies accessories to BomInstanceLines
-- INSTRUCTIONS: Replace 'SO-000007' with your Sale Order number
-- ========================================

DO $$
DECLARE
  v_bom_instance_id uuid;
  v_component_record RECORD;
  v_canonical_uom text;
  v_unit_cost_exw numeric(12,4);
  v_total_cost_exw numeric(12,4);
  v_category_code text;
  v_updated_count integer;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'COPYING ACCESSORIES TO BomInstanceLines';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Get BomInstance for this Sale Order
  SELECT bi.id INTO v_bom_instance_id
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1;

  IF v_bom_instance_id IS NULL THEN
    RAISE EXCEPTION 'BomInstance not found for Sale Order SO-000007. Please approve the Quote first.';
  END IF;

  RAISE NOTICE '✅ Found BomInstance ID: %', v_bom_instance_id;
  RAISE NOTICE '';

  -- Copy accessories from QuoteLineComponents to BomInstanceLines
  FOR v_component_record IN
    SELECT 
      qlc.*,
      ci.item_name,
      ci.sku,
      ci.cost_exw,
      ci.msrp
    FROM "SaleOrders" so
      INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
      INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
      INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
        AND (qlc.source = 'accessory' OR qlc.component_role = 'accessory')
        AND qlc.deleted = false
      INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        AND ci.deleted = false
    WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
      AND so.deleted = false
  LOOP
    -- Compute canonical UOM
    v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
    
    -- Use stored unit_cost_exw or calculate
    v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, v_component_record.cost_exw, 0);
    
    -- Calculate total_cost_exw
    v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
    
    -- Set category_code for accessories
    v_category_code := 'accessory';
    
    -- Insert BomInstanceLine with ON CONFLICT DO NOTHING
    INSERT INTO "BomInstanceLines" (
      bom_instance_id,
      source_template_line_id,
      resolved_part_id,
      resolved_sku,
      part_role,
      qty,
      uom,
      description,
      unit_cost_exw,
      total_cost_exw,
      category_code,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_bom_instance_id,
      NULL,
      v_component_record.catalog_item_id,
      v_component_record.sku,
      'accessory',
      v_component_record.qty,
      v_canonical_uom,
      v_component_record.item_name,
      v_unit_cost_exw,
      v_total_cost_exw,
      v_category_code,
      now(),
      now(),
      false
    )
    ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
    WHERE deleted = false
    DO NOTHING;

    RAISE NOTICE '✅ Copied accessory: % (SKU: %)', v_component_record.item_name, v_component_record.sku;
  END LOOP;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  IF v_updated_count = 0 THEN
    RAISE NOTICE 'ℹ️  No accessories found to copy';
  ELSE
    RAISE NOTICE '';
    RAISE NOTICE '✅ Copied % accessories to BomInstanceLines', v_updated_count;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✨ PROCESS COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

END $$;

-- Verification: Show accessories in BomInstanceLines
SELECT 
  'Verification: Accessories in BomInstanceLines' as check_name,
  bil.category_code,
  bil.part_role,
  bil.qty,
  bil.uom,
  ci.sku,
  ci.item_name
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.category_code = 'accessory'
    AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false
ORDER BY ci.sku;








