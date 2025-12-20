-- ====================================================
-- Migration: Update calculate_quote_line_price to Include Discounts
-- ====================================================
-- Updates the price calculation function to apply customer tier discounts
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
    v_quote_record RECORD;
    v_customer_record RECORD;
    v_cost_settings_record RECORD;
    v_base_cost_per_unit numeric(12,4) := 0;
    v_margin_percentage numeric(8,4) := 35.0000; -- Default 35%
    v_margin_source text := 'default';
    v_unit_price numeric(12,4) := 0;
    v_discount_percentage numeric(8,4) := 0;
    v_discount_source text := NULL;
    v_discount_amount numeric(12,4) := 0;
    v_final_unit_price numeric(12,4) := 0;
    v_quote_line_cost_record RECORD;
BEGIN
    -- Step 1: Load QuoteLine with organization_id and quote_id
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        ql.unit_price_snapshot,
        ql.margin_percentage_used,
        ql.margin_source,
        ql.discount_percentage,
        ql.discount_source
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Step 2: Load Quote to get customer_id
    SELECT 
        id,
        customer_id,
        currency
    INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_line_record.quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'Quote % not found for QuoteLine %', v_quote_line_record.quote_id, p_quote_line_id;
        RETURN p_quote_line_id;
    END IF;
    
    -- Step 3: Load CatalogItem to get cost_exw and category_id
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
    
    -- Step 4: Get base cost per unit from QuoteLineCosts (if exists) or CatalogItem
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
        v_base_cost_per_unit := v_quote_line_cost_record.total_cost / GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
    ELSIF v_catalog_item_record.cost_exw IS NOT NULL AND v_catalog_item_record.cost_exw > 0 THEN
        -- Fallback to CatalogItem.cost_exw
        v_base_cost_per_unit := v_catalog_item_record.cost_exw;
    ELSE
        -- No cost available, cannot calculate price
        RAISE WARNING 'No cost available for QuoteLine %. Cannot calculate price.', p_quote_line_id;
        RETURN p_quote_line_id;
    END IF;
    
    -- Step 5: Determine margin percentage (Priority: Category Margin > Item Default > 35%)
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
    
    -- Step 6: Calculate unit price (before discount)
    -- Formula: unit_price = base_cost_per_unit * (1 + margin_percentage / 100)
    v_unit_price := v_base_cost_per_unit * (1 + v_margin_percentage / 100);
    
    -- Step 7: Determine discount (only if not manually set)
    -- Priority: manual_line > manual_customer > customer_type > 0
    -- Handle both 'manual_line' and legacy 'manual' for backward compatibility
    IF (v_quote_line_record.discount_source = 'manual_line' OR v_quote_line_record.discount_source = 'manual') 
        AND v_quote_line_record.discount_percentage IS NOT NULL THEN
        -- Keep manual line discount
        v_discount_percentage := v_quote_line_record.discount_percentage;
        v_discount_source := 'manual_line';
    ELSE
        -- Get customer record with discount_pct and customer_type_name
        SELECT 
            discount_pct,
            customer_type_name
        INTO v_customer_record
        FROM "DirectoryCustomers" dc
        WHERE dc.id = v_quote_record.customer_id
        AND dc.deleted = false
        LIMIT 1;
        
        IF FOUND THEN
            -- Priority a): If customer has manual discount_pct > 0, use it
            IF v_customer_record.discount_pct IS NOT NULL AND v_customer_record.discount_pct > 0 THEN
                v_discount_percentage := v_customer_record.discount_pct;
                v_discount_source := 'manual_customer';
            -- Priority b): Map customer_type_name to CostSettings discount field
            ELSIF v_customer_record.customer_type_name IS NOT NULL THEN
                -- Load CostSettings for the organization
                SELECT 
                    discount_reseller_pct,
                    discount_distributor_pct,
                    discount_partner_pct,
                    discount_vip_pct
                INTO v_cost_settings_record
                FROM "CostSettings"
                WHERE organization_id = v_quote_line_record.organization_id
                AND deleted = false
                LIMIT 1;
                
                IF FOUND THEN
                    -- Map customer_type_name to discount field (case-insensitive)
                    -- Convert ENUM to text before using TRIM
                    CASE UPPER(TRIM(v_customer_record.customer_type_name::text))
                        WHEN 'RESELLER' THEN
                            v_discount_percentage := COALESCE(v_cost_settings_record.discount_reseller_pct, 0);
                        WHEN 'DISTRIBUTOR' THEN
                            v_discount_percentage := COALESCE(v_cost_settings_record.discount_distributor_pct, 0);
                        WHEN 'PARTNER' THEN
                            v_discount_percentage := COALESCE(v_cost_settings_record.discount_partner_pct, 0);
                        WHEN 'VIP' THEN
                            v_discount_percentage := COALESCE(v_cost_settings_record.discount_vip_pct, 0);
                        ELSE
                            v_discount_percentage := 0;
                    END CASE;
                    
                    IF v_discount_percentage > 0 THEN
                        v_discount_source := 'customer_type';
                    ELSE
                        v_discount_source := NULL;
                    END IF;
                ELSE
                    -- No CostSettings found, no discount
                    v_discount_percentage := 0;
                    v_discount_source := NULL;
                END IF;
            ELSE
                -- No customer type, no discount
                v_discount_percentage := 0;
                v_discount_source := NULL;
            END IF;
        ELSE
            -- Customer not found, no discount
            v_discount_percentage := 0;
            v_discount_source := NULL;
        END IF;
    END IF;
    
    -- Step 8: Calculate discount amount and final unit price
    v_discount_amount := v_unit_price * (v_discount_percentage / 100);
    v_final_unit_price := v_unit_price - v_discount_amount;
    
    -- Ensure final_unit_price is not negative
    IF v_final_unit_price < 0 THEN
        v_final_unit_price := 0;
    END IF;
    
    -- Step 9: Update QuoteLine with calculated prices and discount info
    UPDATE "QuoteLines"
    SET 
        unit_price_snapshot = v_unit_price,
        margin_percentage_used = v_margin_percentage,
        margin_source = v_margin_source,
        discount_percentage = v_discount_percentage,
        discount_amount = v_discount_amount,
        discount_source = v_discount_source,
        final_unit_price = v_final_unit_price,
        -- Recalculate line_total using final_unit_price
        line_total = v_final_unit_price * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1),
        updated_at = NOW()
    WHERE id = p_quote_line_id;
    
    RETURN p_quote_line_id;
END;
$$;

-- Update comment
COMMENT ON FUNCTION public.calculate_quote_line_price(uuid) IS 
'Calculates unit price for a QuoteLine using Category Margins and applies customer tier discounts.
Priority: Category Margin > Item Default Margin > 35% fallback.
Uses total_cost from QuoteLineCosts if available, otherwise uses CatalogItem.cost_exw.
Applies discount from customer pricing tier unless manually overridden.';

-- Also trigger when Quote customer changes (to recalculate discounts for all lines)
CREATE OR REPLACE FUNCTION public.trigger_recalculate_prices_on_customer_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Recalculate prices for all QuoteLines in this Quote
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id THEN
        PERFORM public.calculate_quote_line_price(ql.id)
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_recalculate_prices_on_customer_change ON public."Quotes";
CREATE TRIGGER trg_recalculate_prices_on_customer_change
    AFTER UPDATE OF customer_id ON public."Quotes"
    FOR EACH ROW
    WHEN (NEW.deleted = false OR NEW.deleted IS NULL)
    EXECUTE FUNCTION public.trigger_recalculate_prices_on_customer_change();

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Function updated with discount calculation';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Function now:';
    RAISE NOTICE '  - Calculates unit price with margin';
    RAISE NOTICE '  - Applies customer tier discount';
    RAISE NOTICE '  - Supports manual discount override';
    RAISE NOTICE '  - Calculates final_unit_price and line_total';
    RAISE NOTICE '';
    RAISE NOTICE 'Triggers:';
    RAISE NOTICE '  - Recalculates prices when Quote customer changes';
    RAISE NOTICE '';
END $$;

