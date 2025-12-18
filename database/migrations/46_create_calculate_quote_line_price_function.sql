-- ====================================================
-- Migration: Create calculate_quote_line_price Function
-- ====================================================
-- Calculates unit price for QuoteLine using Category Margins
-- Priority: Category Margin > Item Default Margin > 35% fallback
-- ====================================================

CREATE OR REPLACE FUNCTION public.calculate_quote_line_price(
    p_quote_line_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_catalog_item_record RECORD;
    v_category_margin_record RECORD;
    v_base_cost_per_unit numeric(12,4) := 0;
    v_margin_percentage numeric(8,4) := 35.0000; -- Default 35%
    v_margin_source text := 'default';
    v_unit_price numeric(12,4) := 0;
    v_quote_line_cost_record RECORD;
BEGIN
    -- Step 1: Load QuoteLine with organization_id
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        ql.unit_price_snapshot,
        ql.margin_percentage_used,
        ql.margin_source
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Step 2: Load CatalogItem to get cost_exw and category_id
    SELECT 
        id,
        cost_exw,
        item_category_id,
        default_margin_pct
    INTO v_catalog_item_record
    FROM "CatalogItems"
    WHERE id = v_quote_line_record.catalog_item_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'CatalogItem % not found for QuoteLine %', v_quote_line_record.catalog_item_id, p_quote_line_id;
        RETURN p_quote_line_id; -- Return without updating
    END IF;
    
    -- Step 3: Get base cost per unit from QuoteLineCosts (if exists) or CatalogItem
    -- Try to get from QuoteLineCosts first (more accurate, includes all costs)
    SELECT 
        base_material_cost,
        total_cost
    INTO v_quote_line_cost_record
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND AND v_quote_line_cost_record.total_cost > 0 THEN
        -- Use total_cost from QuoteLineCosts (includes all costs: material, labor, shipping, etc.)
        -- Divide by computed_qty to get cost per unit
        v_base_cost_per_unit := v_quote_line_cost_record.total_cost / GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
    ELSIF v_catalog_item_record.cost_exw IS NOT NULL AND v_catalog_item_record.cost_exw > 0 THEN
        -- Fallback to CatalogItem.cost_exw
        v_base_cost_per_unit := v_catalog_item_record.cost_exw;
    ELSE
        -- No cost available, cannot calculate price
        RAISE WARNING 'No cost available for QuoteLine %. Cannot calculate price.', p_quote_line_id;
        RETURN p_quote_line_id;
    END IF;
    
    -- Step 4: Determine margin percentage (Priority: Category Margin > Item Default > 35%)
    IF v_catalog_item_record.item_category_id IS NOT NULL THEN
        -- Try to get Category Margin
        SELECT 
            margin_percentage,
            active
        INTO v_category_margin_record
        FROM "CategoryMargins"
        WHERE organization_id = v_quote_line_record.organization_id
        AND category_id = v_catalog_item_record.item_category_id
        AND active = true
        AND deleted = false
        LIMIT 1;
        
        IF FOUND THEN
            v_margin_percentage := v_category_margin_record.margin_percentage;
            v_margin_source := 'category';
        ELSIF v_catalog_item_record.default_margin_pct IS NOT NULL AND v_catalog_item_record.default_margin_pct > 0 THEN
            -- Use item's default margin
            v_margin_percentage := v_catalog_item_record.default_margin_pct;
            v_margin_source := 'item';
        ELSE
            -- Use default 35%
            v_margin_percentage := 35.0000;
            v_margin_source := 'default';
        END IF;
    ELSIF v_catalog_item_record.default_margin_pct IS NOT NULL AND v_catalog_item_record.default_margin_pct > 0 THEN
        -- No category, but item has default margin
        v_margin_percentage := v_catalog_item_record.default_margin_pct;
        v_margin_source := 'item';
    ELSE
        -- No category, no item margin, use default
        v_margin_percentage := 35.0000;
        v_margin_source := 'default';
    END IF;
    
    -- Step 5: Calculate unit price
    -- Formula: unit_price = base_cost_per_unit * (1 + margin_percentage / 100)
    v_unit_price := v_base_cost_per_unit * (1 + v_margin_percentage / 100);
    
    -- Step 6: Update QuoteLine with calculated price and margin info
    UPDATE "QuoteLines"
    SET 
        unit_price_snapshot = v_unit_price,
        margin_percentage_used = v_margin_percentage,
        margin_source = v_margin_source,
        updated_at = NOW()
    WHERE id = p_quote_line_id;
    
    RETURN p_quote_line_id;
END;
$$;

-- Add comment
COMMENT ON FUNCTION public.calculate_quote_line_price(uuid) IS 
'Calculates unit price for a QuoteLine using Category Margins.
Priority: Category Margin > Item Default Margin > 35% fallback.
Uses total_cost from QuoteLineCosts if available, otherwise uses CatalogItem.cost_exw.';

-- Create trigger function to auto-calculate price
CREATE OR REPLACE FUNCTION public.trigger_calculate_quote_line_price()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only calculate if catalog_item_id is set and not deleted
    IF NEW.catalog_item_id IS NOT NULL AND (NEW.deleted = false OR NEW.deleted IS NULL) THEN
        PERFORM public.calculate_quote_line_price(NEW.id);
    END IF;
    RETURN NEW;
END;
$$;

-- Create trigger on QuoteLines
DROP TRIGGER IF EXISTS trg_calculate_quote_line_price ON public."QuoteLines";
CREATE TRIGGER trg_calculate_quote_line_price
    AFTER INSERT OR UPDATE OF catalog_item_id, qty, computed_qty ON public."QuoteLines"
    FOR EACH ROW
    WHEN (NEW.deleted = false OR NEW.deleted IS NULL)
    EXECUTE FUNCTION public.trigger_calculate_quote_line_price();

-- Also trigger when QuoteLineCosts are updated (costs changed, recalculate price)
-- Note: This uses a separate function because QuoteLineCosts.quote_line_id is needed

-- Note: We need to create a wrapper function for QuoteLineCosts trigger
-- because the trigger function expects NEW.id to be a QuoteLine id
CREATE OR REPLACE FUNCTION public.trigger_recalculate_price_from_costs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Recalculate price for the associated QuoteLine
    IF NEW.quote_line_id IS NOT NULL THEN
        PERFORM public.calculate_quote_line_price(NEW.quote_line_id);
    END IF;
    RETURN NEW;
END;
$$;

-- Update the trigger to use the correct function
DROP TRIGGER IF EXISTS trg_recalculate_price_on_cost_update ON public."QuoteLineCosts";
CREATE TRIGGER trg_recalculate_price_on_cost_update
    AFTER INSERT OR UPDATE OF total_cost, base_material_cost ON public."QuoteLineCosts"
    FOR EACH ROW
    WHEN (NEW.deleted = false OR NEW.deleted IS NULL)
    EXECUTE FUNCTION public.trigger_recalculate_price_from_costs();

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Function and triggers created';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Function: calculate_quote_line_price(uuid)';
    RAISE NOTICE 'Trigger: trg_calculate_quote_line_price (on QuoteLines)';
    RAISE NOTICE 'Trigger: trg_recalculate_price_on_cost_update (on QuoteLineCosts)';
    RAISE NOTICE '';
END $$;

