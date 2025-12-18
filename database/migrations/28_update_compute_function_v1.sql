-- ====================================================
-- Migration: Update compute_quote_line_cost to v1 (Percentage-based)
-- ====================================================
-- Cost Engine v1: Simple percentage-based calculation
-- Labor = base_material_cost * (labor_percentage / 100)
-- Shipping = base_material_cost * (shipping_percentage / 100)
-- Respects manual overrides (labor_source, shipping_source)
-- ====================================================

-- ====================================================
-- STEP 1: Create updated compute_quote_line_cost function
-- ====================================================

CREATE OR REPLACE FUNCTION public.compute_quote_line_cost(
    p_quote_line_id uuid,
    p_options jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_cost_settings_record RECORD;
    v_catalog_item_record RECORD;
    v_existing_cost_record RECORD;
    v_base_material_cost numeric(12,4) := 0;
    v_labor_cost numeric(12,4) := 0;
    v_shipping_cost numeric(12,4) := 0;
    v_total_cost numeric(12,4) := 0;
    v_quote_line_cost_id uuid;
    v_reset_labor boolean := COALESCE((p_options->>'reset_labor')::boolean, false);
    v_reset_shipping boolean := COALESCE((p_options->>'reset_shipping')::boolean, false);
    v_labor_percentage numeric(8,4) := 10.0000; -- Default 10%
    v_shipping_percentage numeric(8,4) := 15.0000; -- Default 15%
    v_labor_source text := 'auto';
    v_shipping_source text := 'auto';
BEGIN
    -- Step 1: Load QuoteLine + organization_id
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        q.currency
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Step 2: Determine base_material_cost from CatalogItems.cost_exw
    SELECT 
        id,
        cost_exw
    INTO v_catalog_item_record
    FROM "CatalogItems"
    WHERE id = v_quote_line_record.catalog_item_id
    AND deleted = false;
    
    IF FOUND AND v_catalog_item_record.cost_exw IS NOT NULL THEN
        v_base_material_cost := COALESCE(
            v_catalog_item_record.cost_exw * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1),
            0
        );
    ELSE
        v_base_material_cost := 0;
    END IF;
    
    -- Step 3: Load CostSettings for organization
    SELECT 
        id,
        currency_code,
        labor_percentage,
        shipping_percentage
    INTO v_cost_settings_record
    FROM "CostSettings"
    WHERE organization_id = v_quote_line_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        v_labor_percentage := COALESCE(v_cost_settings_record.labor_percentage, 10.0000);
        v_shipping_percentage := COALESCE(v_cost_settings_record.shipping_percentage, 15.0000);
    END IF;
    
    -- Step 4: Check if QuoteLineCosts already exists
    SELECT 
        id,
        labor_cost,
        shipping_cost,
        labor_source,
        shipping_source
    INTO v_existing_cost_record
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    -- Step 5: Calculate labor_cost
    IF FOUND AND v_existing_cost_record.labor_source = 'manual' AND NOT v_reset_labor THEN
        -- Keep existing manual labor_cost
        v_labor_cost := v_existing_cost_record.labor_cost;
    ELSE
        -- Calculate: base_material_cost * (labor_percentage / 100)
        v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
    END IF;
    
    -- Step 6: Calculate shipping_cost
    IF FOUND AND v_existing_cost_record.shipping_source = 'manual' AND NOT v_reset_shipping THEN
        -- Keep existing manual shipping_cost
        v_shipping_cost := v_existing_cost_record.shipping_cost;
    ELSE
        -- Calculate: base_material_cost * (shipping_percentage / 100)
        v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
    END IF;
    
    -- Step 7: Determine labor_source and shipping_source
    IF FOUND AND v_existing_cost_record.labor_source = 'manual' AND NOT v_reset_labor THEN
        v_labor_source := 'manual';
    END IF;
    
    IF FOUND AND v_existing_cost_record.shipping_source = 'manual' AND NOT v_reset_shipping THEN
        v_shipping_source := 'manual';
    END IF;
    
    -- Step 8: Calculate total_cost
    v_total_cost := v_base_material_cost + v_labor_cost + v_shipping_cost;
    
    -- Step 9: Upsert QuoteLineCosts
    INSERT INTO "QuoteLineCosts" (
        organization_id,
        quote_id,
        quote_line_id,
        currency_code,
        base_material_cost,
        labor_cost,
        labor_source,
        shipping_cost,
        shipping_source,
        total_cost,
        calculated_at,
        updated_at
    )
    VALUES (
        v_quote_line_record.organization_id,
        v_quote_line_record.quote_id,
        p_quote_line_id,
        COALESCE(v_cost_settings_record.currency_code, v_quote_line_record.currency, 'USD'),
        v_base_material_cost,
        v_labor_cost,
        v_labor_source,
        v_shipping_cost,
        v_shipping_source,
        v_total_cost,
        now(),
        now()
    )
    ON CONFLICT (quote_line_id) 
    DO UPDATE SET
        base_material_cost = EXCLUDED.base_material_cost,
        labor_cost = CASE 
            WHEN v_reset_labor THEN EXCLUDED.labor_cost
            WHEN "QuoteLineCosts".labor_source = 'manual' THEN "QuoteLineCosts".labor_cost
            ELSE EXCLUDED.labor_cost
        END,
        labor_source = CASE 
            WHEN v_reset_labor THEN 'auto'
            WHEN "QuoteLineCosts".labor_source = 'manual' THEN 'manual'
            ELSE EXCLUDED.labor_source
        END,
        shipping_cost = CASE 
            WHEN v_reset_shipping THEN EXCLUDED.shipping_cost
            WHEN "QuoteLineCosts".shipping_source = 'manual' THEN "QuoteLineCosts".shipping_cost
            ELSE EXCLUDED.shipping_cost
        END,
        shipping_source = CASE 
            WHEN v_reset_shipping THEN 'auto'
            WHEN "QuoteLineCosts".shipping_source = 'manual' THEN 'manual'
            ELSE EXCLUDED.shipping_source
        END,
        total_cost = EXCLUDED.base_material_cost + 
                    CASE 
                        WHEN v_reset_labor THEN EXCLUDED.labor_cost
                        WHEN "QuoteLineCosts".labor_source = 'manual' THEN "QuoteLineCosts".labor_cost
                        ELSE EXCLUDED.labor_cost
                    END +
                    CASE 
                        WHEN v_reset_shipping THEN EXCLUDED.shipping_cost
                        WHEN "QuoteLineCosts".shipping_source = 'manual' THEN "QuoteLineCosts".shipping_cost
                        ELSE EXCLUDED.shipping_cost
                    END,
        calculated_at = now(),
        updated_at = now()
    RETURNING id INTO v_quote_line_cost_id;
    
    RETURN v_quote_line_cost_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error computing quote line cost: %', SQLERRM;
END;
$$;

-- ====================================================
-- STEP 2: Update comment
-- ====================================================

COMMENT ON FUNCTION public.compute_quote_line_cost(uuid, jsonb) IS 
    'Cost Engine v1: Calculates quote line costs using percentage-based labor and shipping. 
     Options: { "reset_labor": boolean, "reset_shipping": boolean }
     Respects manual overrides unless reset is explicitly requested.';

-- ====================================================
-- STEP 3: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Updated compute_quote_line_cost to v1 (percentage-based)';
    RAISE NOTICE '📋 Features:';
    RAISE NOTICE '   - Labor = base_material_cost * (labor_percentage / 100)';
    RAISE NOTICE '   - Shipping = base_material_cost * (shipping_percentage / 100)';
    RAISE NOTICE '   - Respects manual overrides (labor_source, shipping_source)';
    RAISE NOTICE '   - Supports reset via options parameter';
END $$;

