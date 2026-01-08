-- ====================================================
-- Migration 421: Fix BOM Fabric Resolution, UOM Normalization, and Reset
-- ====================================================
-- Objective: 
-- 1. Create reset_bom_for_manufacturing_order function
-- 2. Fix fabric resolution to use SalesOrderLine/QuoteLine selection
-- 3. Implement UOM canonicalization (m, m2, ea)
-- 4. Ensure BOM uses correct fabric from SO selection
-- ====================================================

-- ====================================================
-- STEP 1: Helper Function - Normalize UOM to Canonical
-- ====================================================
-- This function normalizes UOM strings to canonical values (m, m2, ea)
-- and converts quantities when needed (ft -> m)

-- Drop existing function with all possible signatures
-- We need to drop views first, then functions, then recreate
DO $$
BEGIN
    -- Drop dependent views first
    DROP VIEW IF EXISTS public.vw_bom_validation_missing_parent CASCADE;
    DROP VIEW IF EXISTS public.vw_bom_validation_missing_qty_uom CASCADE;
    DROP VIEW IF EXISTS public.vw_bom_validation_duplicate_items CASCADE;
    DROP VIEW IF EXISTS public.vw_bom_validation_orphan_assembly_children CASCADE;
    DROP VIEW IF EXISTS public.vw_bom_instance_summary CASCADE;
    DROP VIEW IF EXISTS public.vw_bom_instance_flat CASCADE;
    
    -- Drop all versions of the function
    DROP FUNCTION IF EXISTS public.normalize_uom_to_canonical(text);
    DROP FUNCTION IF EXISTS public.normalize_uom_to_canonical(text, text);
    DROP FUNCTION IF EXISTS public.normalize_uom_to_canonical(text, text, text);
END $$;

-- Now create the new function with extended signature
CREATE OR REPLACE FUNCTION public.normalize_uom_to_canonical(
    p_uom text,
    p_role text DEFAULT NULL,
    p_qty_type text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
    v_uom_normalized text;
    v_uom_lower text;
BEGIN
    -- Handle NULL
    IF p_uom IS NULL OR trim(p_uom) = '' THEN
        -- Default based on role or qty_type
        IF p_role = 'fabric' OR p_qty_type = 'per_area' THEN
            RETURN 'm2';
        ELSIF p_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'cassette', 'side_channel', 'chain') 
           OR p_qty_type IN ('per_width', 'per_length', 'per_height', 'perimeter') THEN
            RETURN 'm';
        ELSE
            RETURN 'ea';
        END IF;
    END IF;
    
    v_uom_lower := lower(trim(p_uom));
    
    -- Normalize to canonical
    CASE v_uom_lower
        -- Area units -> m2
        WHEN 'm2', 'sqm', 'sq_m', 'square_meter', 'square_meters' THEN
            RETURN 'm2';
        
        -- Linear units -> m
        WHEN 'm', 'meter', 'meters', 'metre', 'metres' THEN
            RETURN 'm';
        WHEN 'ft', 'foot', 'feet' THEN
            RETURN 'm';  -- Will need conversion factor
        WHEN 'mm', 'millimeter', 'millimeters', 'millimetre', 'millimetres' THEN
            RETURN 'm';  -- Will need conversion factor (divide by 1000)
        
        -- Count units -> ea
        WHEN 'ea', 'each', 'pcs', 'pc', 'piece', 'pieces', 'set', 'sets', 'unit', 'units' THEN
            RETURN 'ea';
        
        -- Unknown -> try to infer from role/qty_type
        ELSE
            IF p_role = 'fabric' OR p_qty_type = 'per_area' THEN
                RETURN 'm2';
            ELSIF p_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'cassette', 'side_channel', 'chain')
               OR p_qty_type IN ('per_width', 'per_length', 'per_height', 'perimeter') THEN
                RETURN 'm';
            ELSE
                RETURN 'ea';
            END IF;
    END CASE;
END;
$$;

COMMENT ON FUNCTION public.normalize_uom_to_canonical IS 
    'Normalizes UOM strings to canonical values (m, m2, ea). Converts ft->m, pcs/set->ea. Uses role/qty_type for inference if UOM is unknown.';

-- ====================================================
-- STEP 2: Helper Function - Convert Quantity by UOM
-- ====================================================
-- Converts quantity based on UOM normalization
-- ft -> m: multiply by 0.3048
-- mm -> m: divide by 1000
-- pcs/set -> ea: no conversion (1:1)

CREATE OR REPLACE FUNCTION public.convert_qty_by_uom(
    p_qty numeric,
    p_uom_original text,
    p_uom_canonical text
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
    v_uom_orig_lower text;
BEGIN
    -- If same, no conversion
    IF p_uom_original = p_uom_canonical THEN
        RETURN p_qty;
    END IF;
    
    v_uom_orig_lower := lower(trim(COALESCE(p_uom_original, '')));
    
    -- Conversions
    CASE 
        -- ft -> m
        WHEN v_uom_orig_lower IN ('ft', 'foot', 'feet') AND p_uom_canonical = 'm' THEN
            RETURN p_qty * 0.3048;
        
        -- mm -> m
        WHEN v_uom_orig_lower IN ('mm', 'millimeter', 'millimeters', 'millimetre', 'millimetres') AND p_uom_canonical = 'm' THEN
            RETURN p_qty / 1000.0;
        
        -- pcs/set -> ea (1:1, no conversion)
        WHEN v_uom_orig_lower IN ('pcs', 'pc', 'piece', 'pieces', 'set', 'sets') AND p_uom_canonical = 'ea' THEN
            RETURN p_qty;
        
        -- No conversion needed or unknown
        ELSE
            RETURN p_qty;
    END CASE;
END;
$$;

COMMENT ON FUNCTION public.convert_qty_by_uom IS 
    'Converts quantity based on UOM normalization. ft->m (×0.3048), mm->m (÷1000), pcs/set->ea (1:1).';

-- ====================================================
-- STEP 3: Function - Reset BOM for Manufacturing Order
-- ====================================================
-- Soft-deletes all BomInstances and BomInstanceLines for a Manufacturing Order

CREATE OR REPLACE FUNCTION public.reset_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_manufacturing_order RECORD;
    v_sale_order RECORD;
    v_bom_instance_ids uuid[];
    v_deleted_lines_count integer := 0;
    v_deleted_instances_count integer := 0;
BEGIN
    -- Get ManufacturingOrder and SaleOrder
    SELECT mo.id, mo.organization_id, mo.sale_order_id
    INTO v_manufacturing_order
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    -- Get SaleOrder
    SELECT so.id, so.organization_id
    INTO v_sale_order
    FROM "SalesOrders" so
    WHERE so.id = v_manufacturing_order.sale_order_id
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_manufacturing_order.sale_order_id, p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '🔄 [Reset BOM] Starting reset for ManufacturingOrder % (SaleOrder: %)', 
        p_manufacturing_order_id, v_sale_order.id;
    
    -- Step A: Find all BomInstances associated with SaleOrderLines of this MO's SaleOrder
    SELECT ARRAY_AGG(bi.id)
    INTO v_bom_instance_ids
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order.id
    AND bi.deleted = false;
    
    -- Step B: Soft-delete BomInstanceLines
    IF v_bom_instance_ids IS NOT NULL AND array_length(v_bom_instance_ids, 1) > 0 THEN
        UPDATE "BomInstanceLines" bil
        SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id = ANY(v_bom_instance_ids)
        AND bil.deleted = false;
        
        GET DIAGNOSTICS v_deleted_lines_count = ROW_COUNT;
        RAISE NOTICE '   🗑️  Soft-deleted % BomInstanceLines', v_deleted_lines_count;
    END IF;
    
    -- Step C: Soft-delete BomInstances
    IF v_bom_instance_ids IS NOT NULL AND array_length(v_bom_instance_ids, 1) > 0 THEN
        UPDATE "BomInstances" bi
        SET deleted = true, updated_at = now()
        WHERE bi.id = ANY(v_bom_instance_ids)
        AND bi.deleted = false;
        
        GET DIAGNOSTICS v_deleted_instances_count = ROW_COUNT;
        RAISE NOTICE '   🗑️  Soft-deleted % BomInstances', v_deleted_instances_count;
    END IF;
    
    -- Return summary
    RETURN jsonb_build_object(
        'ok', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'sale_order_id', v_sale_order.id,
        'deleted_instances', v_deleted_instances_count,
        'deleted_lines', v_deleted_lines_count
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in reset_bom_for_manufacturing_order: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.reset_bom_for_manufacturing_order IS 
    'Soft-deletes all BomInstances and BomInstanceLines for a Manufacturing Order. Returns JSON with deleted counts.';

GRANT EXECUTE ON FUNCTION public.reset_bom_for_manufacturing_order TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_uom_to_canonical TO authenticated;
GRANT EXECUTE ON FUNCTION public.convert_qty_by_uom TO authenticated;

-- ====================================================
-- STEP 4: Recreate Views that depend on normalize_uom_to_canonical
-- ====================================================
-- The views were dropped above, now recreate them with the new function signature
-- (The new function is compatible - can be called with just (text))

-- Recreate vw_bom_instance_flat (from migration 413)
CREATE OR REPLACE VIEW public.vw_bom_instance_flat AS
SELECT 
    -- BomInstance fields
    bi.id AS bom_instance_id,
    bi.organization_id,
    sol.sale_order_id,
    bi.sale_order_line_id,
    bi.quote_line_id,
    bi.bom_template_id,
    bi.labor_cost,
    bi.total_cost_with_labor,
    bi.total_msrp_sale_out_with_labor,
    bi.created_at AS bom_created_at,
    bi.updated_at AS bom_updated_at,
    bi.generated_at AS bom_generated_at,
    
    -- BomInstanceLines fields
    bil.id AS bom_line_id,
    bil.resolved_part_id AS catalog_item_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    -- ✅ FIX: Add canonical UOM (normalized: ft->m, pcs->ea, set->ea)
    public.normalize_uom_to_canonical(bil.uom) AS uom_canonical,
    bil.description AS line_description,
    bil.category_code,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.unit_msrp_sale_out,
    bil.total_msrp_sale_out,
    bil.source,
    bil.parent_part_id,
    bil.created_at AS line_created_at,
    bil.updated_at AS line_updated_at,
    
    -- Additional useful fields for debugging/auditing
    bi.deleted AS bom_deleted,
    bil.deleted AS line_deleted
    
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
WHERE bi.deleted = false
  AND bil.deleted = false;

COMMENT ON VIEW public.vw_bom_instance_flat IS 
    'Read-only flattened view of BOM instances and their lines. Use for auditing, UI consumption, and validation queries. Filters out deleted records.';

GRANT SELECT ON public.vw_bom_instance_flat TO authenticated;

-- Recreate validation views
CREATE OR REPLACE VIEW public.vw_bom_validation_orphan_assembly_children AS
SELECT *
FROM public.vw_bom_instance_flat
WHERE source = 'assembly_child'
  AND parent_part_id IS NULL;

COMMENT ON VIEW public.vw_bom_validation_orphan_assembly_children IS 
    'Detects assembly_child lines without a parent_part_id. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_orphan_assembly_children TO authenticated;

CREATE OR REPLACE VIEW public.vw_bom_validation_duplicate_items AS
SELECT
    bom_instance_id,
    parent_part_id,
    catalog_item_id,
    resolved_sku,
    part_role,
    uom,
    COUNT(*) AS duplicate_count
FROM public.vw_bom_instance_flat
GROUP BY bom_instance_id, parent_part_id, catalog_item_id, resolved_sku, part_role, uom
HAVING COUNT(*) > 1;

COMMENT ON VIEW public.vw_bom_validation_duplicate_items IS 
    'Detects duplicate items in the same BOM instance. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_duplicate_items TO authenticated;

CREATE OR REPLACE VIEW public.vw_bom_validation_missing_qty_uom AS
SELECT *
FROM public.vw_bom_instance_flat
WHERE qty IS NULL
   OR uom IS NULL
   OR TRIM(uom) = '';

COMMENT ON VIEW public.vw_bom_validation_missing_qty_uom IS 
    'Detects BOM lines missing qty or uom. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_missing_qty_uom TO authenticated;

CREATE OR REPLACE VIEW public.vw_bom_validation_missing_parent AS
SELECT 
    vf.bom_instance_id,
    vf.catalog_item_id AS child_item_id,
    vf.parent_part_id,
    vf.resolved_sku AS child_sku,
    vf.source
FROM public.vw_bom_instance_flat vf
WHERE vf.source = 'assembly_child'
  AND vf.parent_part_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.vw_bom_instance_flat vf_parent
    WHERE vf_parent.bom_instance_id = vf.bom_instance_id
      AND vf_parent.catalog_item_id = vf.parent_part_id
      AND vf_parent.source IN ('bom_component', 'quote_line_component')
  );

COMMENT ON VIEW public.vw_bom_validation_missing_parent IS 
    'Detects assembly_child lines where the parent item is not present in the same BOM instance. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_missing_parent TO authenticated;

CREATE OR REPLACE VIEW public.vw_bom_instance_summary AS
SELECT 
    bom_instance_id,
    organization_id,
    bom_template_id,
    bom_created_at,
    COUNT(*) AS total_lines,
    COUNT(DISTINCT catalog_item_id) AS unique_items,
    COUNT(*) FILTER (WHERE source = 'bom_component') AS bom_component_lines,
    COUNT(*) FILTER (WHERE source = 'quote_line_component') AS quote_line_component_lines,
    COUNT(*) FILTER (WHERE source = 'assembly_child') AS assembly_child_lines,
    SUM(qty) AS total_qty,
    SUM(total_cost_exw) AS total_cost_exw,
    SUM(total_msrp_sale_out) AS total_msrp_sale_out
FROM public.vw_bom_instance_flat
GROUP BY 
    bom_instance_id,
    organization_id,
    bom_template_id,
    bom_created_at;

COMMENT ON VIEW public.vw_bom_instance_summary IS 
    'Summary statistics per BOM instance: line counts, unique items, totals by source, and cost/MSRP totals.';

GRANT SELECT ON public.vw_bom_instance_summary TO authenticated;

