-- ====================================================
-- Migration: Create compute_quote_line_cost Function
-- ====================================================
-- Cost Engine v1: Server-side function to calculate and store quote line costs
-- ====================================================

-- ====================================================
-- STEP 1: Create compute_quote_line_cost function
-- ====================================================

CREATE OR REPLACE FUNCTION public.compute_quote_line_cost(
    p_quote_line_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_quote_record RECORD;
    v_cost_settings_record RECORD;
    v_catalog_item_record RECORD;
    v_base_material_cost numeric(12,4) := 0;
    v_labor_cost numeric(12,4) := 0;
    v_shipping_cost numeric(12,4) := 0;
    v_import_tax_cost numeric(12,4) := 0;
    v_handling_cost numeric(12,4) := 0;
    v_additional_cost numeric(12,4) := 0;
    v_total_cost numeric(12,4) := 0;
    v_quote_line_cost_id uuid;
    v_labor_hours_per_unit numeric(12,4);
    v_weight_kg numeric(12,4) := NULL; -- Can be extended later if weight is tracked
BEGIN
    -- Step 1: Load QuoteLine, Quote, organization_id
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        q.id as quote_id_check,
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
        cost_exw,
        item_type
    INTO v_catalog_item_record
    FROM "CatalogItems"
    WHERE id = v_quote_line_record.catalog_item_id
    AND deleted = false;
    
    IF FOUND AND v_catalog_item_record.cost_exw IS NOT NULL THEN
        -- v1: Use cost_exw * computed_qty (or qty if computed_qty is 0)
        v_base_material_cost := COALESCE(
            v_catalog_item_record.cost_exw * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1),
            0
        );
    ELSE
        -- Default to 0 (allow overrides)
        v_base_material_cost := 0;
    END IF;
    
    -- Step 3: Load CostSettings for organization
    SELECT 
        id,
        currency_code,
        labor_rate_per_hour,
        default_labor_minutes_per_unit,
        shipping_base_cost,
        shipping_cost_per_kg,
        import_tax_percent,
        handling_fee
    INTO v_cost_settings_record
    FROM "CostSettings"
    WHERE organization_id = v_quote_line_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Use default values (all zeros) if no CostSettings exist
        v_cost_settings_record := ROW(
            NULL::uuid,
            'USD'::text,
            0::numeric(12,4),
            0::numeric(12,4),
            0::numeric(12,4),
            0::numeric(12,4),
            0::numeric(8,4),
            0::numeric(12,4)
        );
    END IF;
    
    -- Step 4: Compute cost components
    
    -- Labor cost = (default_labor_minutes_per_unit / 60) * labor_rate_per_hour * qty
    v_labor_hours_per_unit := v_cost_settings_record.default_labor_minutes_per_unit / 60.0;
    v_labor_cost := v_labor_hours_per_unit * v_cost_settings_record.labor_rate_per_hour * 
                    GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
    
    -- Shipping cost = shipping_base_cost + (weight_kg * shipping_cost_per_kg if available)
    -- v1: Use base cost only (weight can be added later)
    v_shipping_cost := v_cost_settings_record.shipping_base_cost;
    -- TODO: Add weight calculation when weight tracking is implemented
    -- IF v_weight_kg IS NOT NULL THEN
    --     v_shipping_cost := v_shipping_cost + (v_weight_kg * v_cost_settings_record.shipping_cost_per_kg);
    -- END IF;
    
    -- Import tax = (base_material_cost + shipping_cost) * (import_tax_percent / 100)
    v_import_tax_cost := (v_base_material_cost + v_shipping_cost) * (v_cost_settings_record.import_tax_percent / 100.0);
    
    -- Handling = handling_fee * qty
    v_handling_cost := v_cost_settings_record.handling_fee * 
                      GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
    
    -- Additional cost = 0 (for future extensions)
    v_additional_cost := 0;
    
    -- Step 5: Calculate total_cost (before overrides)
    v_total_cost := v_base_material_cost + 
                    v_labor_cost + 
                    v_shipping_cost + 
                    v_import_tax_cost + 
                    v_handling_cost + 
                    v_additional_cost;
    
    -- Step 6: Upsert into QuoteLineCosts
    INSERT INTO "QuoteLineCosts" (
        organization_id,
        quote_id,
        quote_line_id,
        currency_code,
        base_material_cost,
        labor_cost,
        shipping_cost,
        import_tax_cost,
        handling_cost,
        additional_cost,
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
        v_shipping_cost,
        v_import_tax_cost,
        v_handling_cost,
        v_additional_cost,
        v_total_cost,
        now(),
        now()
    )
    ON CONFLICT (quote_line_id) 
    DO UPDATE SET
        base_material_cost = EXCLUDED.base_material_cost,
        labor_cost = EXCLUDED.labor_cost,
        shipping_cost = EXCLUDED.shipping_cost,
        import_tax_cost = EXCLUDED.import_tax_cost,
        handling_cost = EXCLUDED.handling_cost,
        additional_cost = EXCLUDED.additional_cost,
        total_cost = CASE 
            WHEN "QuoteLineCosts".is_overridden = true THEN
                -- If overridden, keep existing total_cost (it's calculated from overrides)
                "QuoteLineCosts".total_cost
            ELSE
                -- Otherwise, use calculated total
                EXCLUDED.total_cost
        END,
        calculated_at = now(),
        updated_at = now()
    RETURNING id INTO v_quote_line_cost_id;
    
    -- If overrides exist, recalculate total_cost from overrides
    IF v_quote_line_cost_id IS NOT NULL THEN
        UPDATE "QuoteLineCosts"
        SET total_cost = COALESCE(override_base_material_cost, base_material_cost) +
                         COALESCE(override_labor_cost, labor_cost) +
                         COALESCE(override_shipping_cost, shipping_cost) +
                         COALESCE(override_import_tax_cost, import_tax_cost) +
                         COALESCE(override_handling_cost, handling_cost) +
                         COALESCE(override_additional_cost, additional_cost),
            updated_at = now()
        WHERE id = v_quote_line_cost_id
        AND is_overridden = true;
    END IF;
    
    RETURN v_quote_line_cost_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error computing quote line cost: %', SQLERRM;
END;
$$;

-- ====================================================
-- STEP 2: Add comment
-- ====================================================

COMMENT ON FUNCTION public.compute_quote_line_cost(uuid) IS 
    'Calculates and stores cost breakdown for a quote line. Returns the QuoteLineCosts id.';

-- ====================================================
-- STEP 3: Create trigger function to auto-calculate on quote line changes
-- ====================================================

CREATE OR REPLACE FUNCTION public.trigger_compute_quote_line_cost()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Recalculate cost when quote line is created or updated
    -- Only if the quote line is not deleted
    IF NEW.deleted = false THEN
        PERFORM public.compute_quote_line_cost(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$;

-- ====================================================
-- STEP 4: Create trigger on QuoteLines
-- ====================================================

DROP TRIGGER IF EXISTS trigger_quote_lines_compute_cost ON "QuoteLines";
CREATE TRIGGER trigger_quote_lines_compute_cost
    AFTER INSERT OR UPDATE OF catalog_item_id, qty, computed_qty
    ON "QuoteLines"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.trigger_compute_quote_line_cost();

-- ====================================================
-- STEP 5: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Function: compute_quote_line_cost(uuid)';
    RAISE NOTICE '   - Trigger function: trigger_compute_quote_line_cost()';
    RAISE NOTICE '   - Trigger: trigger_quote_lines_compute_cost on QuoteLines';
END $$;













