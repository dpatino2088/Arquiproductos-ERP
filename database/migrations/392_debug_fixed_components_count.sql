-- ====================================================
-- Migration 392: Debug Fixed Components Count
-- ====================================================
-- This creates a debug version of bom_readiness_report that logs
-- exactly what components are being counted and why
-- ====================================================

CREATE OR REPLACE FUNCTION public.bom_readiness_report_debug_fixed(
    p_organization_id uuid
)
RETURNS TABLE (
    product_type_name text,
    product_type_id uuid,
    component_id uuid,
    component_role text,
    component_item_id uuid,
    is_fixed boolean,
    is_valid boolean,
    validation_reason text
)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_product_type RECORD;
    v_component RECORD;
    v_is_valid boolean;
    v_reason text;
BEGIN
    -- Iterate through all ProductTypes for this organization
    FOR v_product_type IN
        SELECT pt.id, pt.name, pt.code
        FROM "ProductTypes" pt
        WHERE pt.organization_id = p_organization_id
        AND pt.deleted = false
        ORDER BY pt.sort_order NULLS LAST, pt.name
    LOOP
        -- Get all components for this product type
        FOR v_component IN
            SELECT 
                bc.id,
                bc.component_role,
                bc.component_item_id,
                bt.id as template_id
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false
            ORDER BY bc.sequence_order
        LOOP
            -- Determine if it's a fixed component
            v_is_valid := false;
            v_reason := '';
            
            IF v_component.component_item_id IS NOT NULL THEN
                -- It's a fixed component, check if it's valid
                IF EXISTS (
                    SELECT 1 
                    FROM "CatalogItems" ci 
                    WHERE ci.id = v_component.component_item_id 
                    AND ci.deleted = false 
                    AND ci.active = true
                    AND ci.uom IS NOT NULL 
                    AND TRIM(ci.uom) <> ''
                    AND ci.item_category_id IS NOT NULL
                ) THEN
                    v_is_valid := true;
                    v_reason := 'Valid fixed component';
                ELSE
                    v_is_valid := false;
                    -- Determine why it's invalid
                    IF NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = v_component.component_item_id) THEN
                        v_reason := 'CatalogItem does not exist';
                    ELSIF EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = v_component.component_item_id AND ci.deleted = true) THEN
                        v_reason := 'CatalogItem is deleted';
                    ELSIF EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = v_component.component_item_id AND ci.deleted = false AND ci.active = false) THEN
                        v_reason := 'CatalogItem is inactive';
                    ELSIF EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = v_component.component_item_id AND ci.deleted = false AND ci.active = true AND (ci.uom IS NULL OR TRIM(ci.uom) = '')) THEN
                        v_reason := 'CatalogItem has NULL or empty UOM';
                    ELSIF EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = v_component.component_item_id AND ci.deleted = false AND ci.active = true AND ci.item_category_id IS NULL) THEN
                        v_reason := 'CatalogItem has NULL item_category_id';
                    ELSE
                        v_reason := 'Unknown validation failure';
                    END IF;
                END IF;
            ELSE
                -- It's an auto-select component, not counted as fixed
                v_reason := 'Auto-select component (not counted as fixed)';
            END IF;
            
            -- Return this component's details
            RETURN QUERY SELECT 
                v_product_type.name,
                v_product_type.id,
                v_component.id,
                v_component.component_role,
                v_component.component_item_id,
                (v_component.component_item_id IS NOT NULL)::boolean,
                v_is_valid,
                v_reason;
        END LOOP;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION public.bom_readiness_report_debug_fixed(uuid) IS 'Debug function to see exactly which components are counted as fixed and why they are valid/invalid';

