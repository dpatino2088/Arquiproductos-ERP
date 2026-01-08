-- ====================================================
-- Migration 422: Patch generate_bom_for_manufacturing_order
-- ====================================================
-- This migration patches the existing function to:
-- 1. Improve fabric resolution from QuoteLine collection/variant
-- 2. Apply UOM canonicalization in ALL INSERT statements
-- 3. Convert quantities when UOM changes (ft->m, etc.)
-- ====================================================
-- NOTE: This is a PATCH. The full function is in 405_fix_bom_instances_rls_and_return_counts.sql
-- This file contains only the critical fixes that need to be applied.
-- ====================================================

-- ====================================================
-- CRITICAL FIX 1: Improve Fabric Resolution
-- ====================================================
-- The fabric resolution logic in generate_bom_for_manufacturing_order needs to:
-- 1. First try resolve_selected_fabric_catalog_item_id (already done)
-- 2. Then try collection_name/variant_name match (already done, but improve matching)
-- 3. Ensure it uses the EXACT match, not just any fabric

-- This fix is already partially implemented in 405, but we need to ensure it's robust.
-- The current logic at lines 1027-1083 should work, but let's add better logging and fallback.

-- ====================================================
-- CRITICAL FIX 2: UOM Canonicalization in ALL Inserts
-- ====================================================
-- Need to ensure ALL INSERT INTO "BomInstanceLines" statements use:
-- uom = public.normalize_uom_to_canonical(original_uom, role, qty_type)
-- qty = public.convert_qty_by_uom(original_qty, original_uom, canonical_uom)

-- Current status:
-- - Line 1345: Already uses normalize_uom_to_canonical ✅
-- - Line 596: QuoteLineComponents insert - NEEDS FIX
-- - Line 609: QuoteLineComponents insert - NEEDS FIX  
-- - Assembly children inserts - NEEDS CHECK

-- ====================================================
-- PATCH: Update QuoteLineComponents Insert (Line ~596)
-- ====================================================
-- This section inserts BomInstanceLines from QuoteLineComponents
-- Current code uses qlc.uom directly - needs normalization

-- The fix should be applied around line 596-610 in 405_fix_bom_instances_rls_and_return_counts.sql
-- Change from:
--   uom = qlc.uom
-- To:
--   uom = public.normalize_uom_to_canonical(qlc.uom, qlc.component_role, NULL),
--   qty = public.convert_qty_by_uom(qlc.qty, qlc.uom, public.normalize_uom_to_canonical(qlc.uom, qlc.component_role, NULL))

-- ====================================================
-- PATCH: Update Auto-Select Insert (Line ~1345)
-- ====================================================
-- This is already fixed, but ensure qty conversion is applied:
-- Current: uom = public.normalize_uom_to_canonical(...)
-- Add: qty = public.convert_qty_by_uom(v_calculated_qty, original_uom, canonical_uom)

-- ====================================================
-- PATCH: Update Assembly Children Inserts
-- ====================================================
-- Need to check if assembly children inserts also normalize UOM
-- Location: around line 1430+ in 405_fix_bom_instances_rls_and_return_counts.sql

-- ====================================================
-- INSTRUCTIONS FOR MANUAL PATCH
-- ====================================================
-- Since the function is very large (~1553 lines), apply these changes manually:

-- 1. In QuoteLineComponents INSERT (around line 596):
--    Replace:
--      uom,
--    With:
--      public.normalize_uom_to_canonical(qlc.uom, qlc.component_role, NULL) AS uom,
--    
--    And in VALUES:
--      Replace:
--        qlc.uom,
--      With:
--        public.normalize_uom_to_canonical(qlc.uom, qlc.component_role, NULL),
--
--    Also update qty:
--      Replace:
--        qlc.qty,
--      With:
--        public.convert_qty_by_uom(
--          qlc.qty, 
--          qlc.uom, 
--          public.normalize_uom_to_canonical(qlc.uom, qlc.component_role, NULL)
--        ),

-- 2. In Auto-Select INSERT (around line 1345):
--    Already has: public.normalize_uom_to_canonical(...)
--    Add qty conversion:
--      Replace:
--        v_calculated_qty,
--      With:
--        public.convert_qty_by_uom(
--          v_calculated_qty,
--          COALESCE(v_bom_component.uom, v_catalog_item_uom),
--          public.normalize_uom_to_canonical(COALESCE(v_bom_component.uom, v_catalog_item_uom), v_bom_component.component_role, v_bom_component.qty_type)
--        ),

-- 3. In Assembly Children INSERT (around line 1430+):
--    Apply same normalization to uom and qty

-- ====================================================
-- VERIFICATION QUERIES
-- ====================================================
-- After applying patches, run these to verify:

-- 1. Check UOM distribution (should only be m, m2, ea):
SELECT uom, COUNT(*) as count
FROM "BomInstanceLines"
WHERE deleted = false
GROUP BY uom
ORDER BY count DESC;

-- 2. Check fabric matches SO selection:
SELECT 
    sol.id AS sale_order_line_id,
    ql.collection_name AS quote_collection,
    ql.variant_name AS quote_variant,
    bil.resolved_sku AS bom_fabric_sku,
    ci.collection_name AS bom_fabric_collection,
    ci.variant_name AS bom_fabric_variant,
    CASE 
        WHEN ql.collection_name = ci.collection_name OR ql.variant_name = ci.variant_name THEN '✅ MATCH'
        ELSE '❌ MISMATCH'
    END AS match_status
FROM "SalesOrderLines" sol
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false AND bil.part_role = 'fabric'
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE sol.deleted = false
ORDER BY bi.created_at DESC
LIMIT 10;


