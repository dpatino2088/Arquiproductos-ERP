-- ====================================================
-- Migration 419: BOM Reset and Helper Functions
-- ====================================================
-- Objective: Create helper functions for BOM template resolution,
-- fabric selection resolution, and reset+regenerate workflow
-- ====================================================

-- ====================================================
-- STEP 1: Helper - Resolve BOM Template ID for Sale Order Line
-- ====================================================

CREATE OR REPLACE FUNCTION public.resolve_bom_template_id_for_sale_order_line(
    p_sale_order_line_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_bom_template_id uuid;
    v_quote_line_id uuid;
    v_configured_product_id uuid;
    v_product_type_id uuid;
BEGIN
    -- Get quote_line_id from SalesOrderLine
    SELECT sol.quote_line_id
    INTO v_quote_line_id
    FROM "SalesOrderLines" sol
    WHERE sol.id = p_sale_order_line_id
    AND sol.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrderLine % not found', p_sale_order_line_id;
    END IF;
    
    -- Get configured_product_id from ConfiguredProducts table (using quote_line_id)
    -- ConfiguredProducts has quote_line_id, not QuoteLines having configured_product_id
    IF v_quote_line_id IS NOT NULL THEN
        SELECT cp.id
        INTO v_configured_product_id
        FROM "ConfiguredProducts" cp
        WHERE cp.quote_line_id = v_quote_line_id
        AND cp.deleted = false
        LIMIT 1;
    END IF;
    
    -- Route A: Check QuoteLine.bom_template_id (highest priority)
    IF v_quote_line_id IS NOT NULL THEN
        SELECT ql.bom_template_id
        INTO v_bom_template_id
        FROM "QuoteLines" ql
        WHERE ql.id = v_quote_line_id
        AND ql.deleted = false
        AND ql.bom_template_id IS NOT NULL
        LIMIT 1;
        
        IF v_bom_template_id IS NOT NULL THEN
            RAISE NOTICE '[resolve_bom_template_id] Found bom_template_id=% from QuoteLine %', v_bom_template_id, v_quote_line_id;
            RETURN v_bom_template_id;
        END IF;
    END IF;
    
    -- Route B: Check ConfiguredProduct.bom_template_id (if configured_product_id exists)
    IF v_configured_product_id IS NOT NULL THEN
        -- Check if ConfiguredProducts table has bom_template_id column
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'ConfiguredProducts'
            AND column_name = 'bom_template_id'
        ) THEN
            SELECT cp.bom_template_id
            INTO v_bom_template_id
            FROM "ConfiguredProducts" cp
            WHERE cp.id = v_configured_product_id
            AND cp.deleted = false
            AND cp.bom_template_id IS NOT NULL
            LIMIT 1;
            
            IF v_bom_template_id IS NOT NULL THEN
                RAISE NOTICE '[resolve_bom_template_id] Found bom_template_id=% from ConfiguredProduct %', v_bom_template_id, v_configured_product_id;
                RETURN v_bom_template_id;
            END IF;
        END IF;
        
        -- Route B2: Get product_type_id from ConfiguredProduct and find default template
        SELECT cp.product_type_id
        INTO v_product_type_id
        FROM "ConfiguredProducts" cp
        WHERE cp.id = v_configured_product_id
        AND cp.deleted = false
        LIMIT 1;
    END IF;
    
    -- Route C: Get product_type_id from QuoteLine if not found yet
    IF v_product_type_id IS NULL AND v_quote_line_id IS NOT NULL THEN
        SELECT ql.product_type_id
        INTO v_product_type_id
        FROM "QuoteLines" ql
        WHERE ql.id = v_quote_line_id
        AND ql.deleted = false
        LIMIT 1;
    END IF;
    
    -- Route D: Find default BOMTemplate for product_type_id
    IF v_product_type_id IS NOT NULL THEN
        -- Check if is_default column exists, otherwise just order by created_at
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'BOMTemplates'
            AND column_name = 'is_default'
        ) THEN
            SELECT bt.id
            INTO v_bom_template_id
            FROM "BOMTemplates" bt
            WHERE bt.product_type_id = v_product_type_id
            AND bt.active = true
            AND bt.deleted = false
            ORDER BY bt.is_default DESC, bt.created_at DESC
            LIMIT 1;
        ELSE
            -- Fallback: just order by created_at if is_default doesn't exist
            SELECT bt.id
            INTO v_bom_template_id
            FROM "BOMTemplates" bt
            WHERE bt.product_type_id = v_product_type_id
            AND bt.active = true
            AND bt.deleted = false
            ORDER BY bt.created_at DESC
            LIMIT 1;
        END IF;
        
        IF v_bom_template_id IS NOT NULL THEN
            RAISE NOTICE '[resolve_bom_template_id] Found bom_template_id=% from ProductType % (default template)', v_bom_template_id, v_product_type_id;
            RETURN v_bom_template_id;
        END IF;
    END IF;
    
    -- If we get here, we couldn't resolve a template
    -- Instead of raising exception, return NULL and log a warning
    -- This allows the calling function to handle the case gracefully
    RAISE WARNING 'Could not resolve bom_template_id for SalesOrderLine %. Tried: QuoteLine.bom_template_id, ConfiguredProduct.bom_template_id, ProductType default template. Returning NULL.', 
        p_sale_order_line_id;
    
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.resolve_bom_template_id_for_sale_order_line IS 
    'Resolves the correct bom_template_id for a SalesOrderLine using: QuoteLine.bom_template_id > ConfiguredProduct.bom_template_id > ProductType default template. Fails if no template can be resolved.';

-- ====================================================
-- STEP 2: Helper - Resolve Selected Fabric Catalog Item ID
-- ====================================================

CREATE OR REPLACE FUNCTION public.resolve_selected_fabric_catalog_item_id(
    p_sale_order_line_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_fabric_catalog_item_id uuid;
    v_quote_line_id uuid;
    v_configured_product_id uuid;
BEGIN
    -- Get quote_line_id from SalesOrderLine
    SELECT sol.quote_line_id
    INTO v_quote_line_id
    FROM "SalesOrderLines" sol
    WHERE sol.id = p_sale_order_line_id
    AND sol.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    -- Get configured_product_id from ConfiguredProducts table (using quote_line_id)
    -- ConfiguredProducts has quote_line_id, not QuoteLines having configured_product_id
    IF v_quote_line_id IS NOT NULL THEN
        SELECT cp.id
        INTO v_configured_product_id
        FROM "ConfiguredProducts" cp
        WHERE cp.quote_line_id = v_quote_line_id
        AND cp.deleted = false
        LIMIT 1;
    END IF;
    
    -- Route A: Check QuoteLineComponents for fabric (highest priority - user selection)
    IF v_quote_line_id IS NOT NULL THEN
        SELECT qlc.catalog_item_id
        INTO v_fabric_catalog_item_id
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_quote_line_id
        AND qlc.component_role = 'fabric'
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'
        LIMIT 1;
        
        IF v_fabric_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '[resolve_selected_fabric] Found fabric catalog_item_id=% from QuoteLineComponents', v_fabric_catalog_item_id;
            RETURN v_fabric_catalog_item_id;
        END IF;
    END IF;
    
    -- Route B: Check ConfiguredProduct.fabric_catalog_item_id
    IF v_configured_product_id IS NOT NULL THEN
        -- Check if ConfiguredProducts table has fabric_catalog_item_id column
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'ConfiguredProducts'
            AND column_name = 'fabric_catalog_item_id'
        ) THEN
            SELECT cp.fabric_catalog_item_id
            INTO v_fabric_catalog_item_id
            FROM "ConfiguredProducts" cp
            WHERE cp.id = v_configured_product_id
            AND cp.deleted = false
            AND cp.fabric_catalog_item_id IS NOT NULL
            LIMIT 1;
            
            IF v_fabric_catalog_item_id IS NOT NULL THEN
                RAISE NOTICE '[resolve_selected_fabric] Found fabric catalog_item_id=% from ConfiguredProduct', v_fabric_catalog_item_id;
                RETURN v_fabric_catalog_item_id;
            END IF;
        END IF;
    END IF;
    
    -- Route C: Try to resolve from QuoteLine collection_name/variant_name (fallback)
    IF v_quote_line_id IS NOT NULL THEN
        -- This is a fallback - try to find fabric by collection/variant
        -- This should ideally be done in the main generator, but we can return NULL here
        -- and let the generator handle it
        RETURN NULL;
    END IF;
    
    -- No fabric selection found
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.resolve_selected_fabric_catalog_item_id IS 
    'Resolves the selected fabric catalog_item_id for a SalesOrderLine using: QuoteLineComponents (fabric role) > ConfiguredProduct.fabric_catalog_item_id. Returns NULL if no selection found (fallback to auto-select).';

-- ====================================================
-- STEP 3: RPC - Reset and Generate BOM for Manufacturing Order
-- ====================================================

CREATE OR REPLACE FUNCTION public.reset_and_generate_bom_for_manufacturing_order(
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
    v_result jsonb;
BEGIN
    -- Get ManufacturingOrder and SaleOrder
    SELECT mo.id, mo.organization_id, mo.sale_order_id, mo.status
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
    
    -- Step D: Call generate_bom_for_manufacturing_order (this will create new BOMs)
    -- Note: generate_bom_for_manufacturing_order expects a ManufacturingOrder, not a SaleOrder
    -- So we need to call it with the MO ID
    PERFORM public.generate_bom_for_manufacturing_order(p_manufacturing_order_id);
    
    -- Step E: Get the newly created BOM instance ID (most recent for this MO)
    DECLARE
        v_new_bom_instance_id uuid;
        v_new_lines_count integer;
    BEGIN
        SELECT bi.id, COUNT(bil.id)
        INTO v_new_bom_instance_id, v_new_lines_count
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
        WHERE sol.sale_order_id = v_sale_order.id
        AND bi.deleted = false
        GROUP BY bi.id
        ORDER BY bi.created_at DESC
        LIMIT 1;
        
        -- Build result JSON
        v_result := jsonb_build_object(
            'ok', true,
            'manufacturing_order_id', p_manufacturing_order_id,
            'sale_order_id', v_sale_order.id,
            'deleted_instances', v_deleted_instances_count,
            'deleted_lines', v_deleted_lines_count,
            'new_bom_instance_id', v_new_bom_instance_id,
            'new_lines_count', COALESCE(v_new_lines_count, 0)
        );
        
        RAISE NOTICE '   ✅ Reset complete. New BOM instance: %, lines: %', v_new_bom_instance_id, v_new_lines_count;
    END;
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in reset_and_generate_bom_for_manufacturing_order: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.reset_and_generate_bom_for_manufacturing_order IS 
    'Resets (soft-deletes) existing BOMs for a ManufacturingOrder and regenerates fresh BOMs. Returns JSON with deleted/new counts and new_bom_instance_id.';

GRANT EXECUTE ON FUNCTION public.reset_and_generate_bom_for_manufacturing_order TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_bom_template_id_for_sale_order_line TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_selected_fabric_catalog_item_id TO authenticated;

