-- ====================================================
-- Migration: Fix btrim() error with ENUM in calculate_quote_line_price
-- ====================================================
-- The function was trying to use TRIM() on directory_customer_type_name ENUM
-- which causes: "function pg_catalog.btrim(directory_customer_type_name) does not exist"
-- Solution: Convert ENUM to text before using TRIM()
-- ====================================================

-- Recreate the function with the fix
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
    v_customer_record RECORD;
    v_cost_settings_record RECORD;
    v_base_cost_per_unit numeric(12,4) := 0;
    v_unit_price numeric(12,4) := 0;
    v_discount_percentage numeric(8,4) := 0;
    v_margin_percentage numeric(8,4) := 35.0000;
    v_margin_source text := 'default';
    v_discount_source text := NULL;
    v_quote_record RECORD;
BEGIN
    -- Step 1: Load QuoteLine + Quote
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        ql.unit_price_snapshot,
        ql.discount_percentage,
        ql.discount_source,
        q.customer_id
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'QuoteLine with id % not found or deleted', p_quote_line_id;
        RETURN p_quote_line_id;
    END IF;
    
    -- Load Quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_line_record.quote_id
    AND deleted = false;
    
    -- Step 2: Load CatalogItem
    SELECT 
        cost_exw,
        msrp,
        default_margin_pct,
        item_category_id
    INTO v_catalog_item_record
    FROM "CatalogItems"
    WHERE id = v_quote_line_record.catalog_item_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE WARNING 'CatalogItem with id % not found or deleted', v_quote_line_record.catalog_item_id;
        RETURN p_quote_line_id;
    END IF;
    
    -- Step 3: Get base cost (Priority: QuoteLineCosts.total_cost > CatalogItem.cost_exw)
    SELECT total_cost INTO v_base_cost_per_unit
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    IF v_base_cost_per_unit IS NULL OR v_base_cost_per_unit = 0 THEN
        v_base_cost_per_unit := COALESCE(v_catalog_item_record.cost_exw, 0);
    ELSE
        -- Divide by quantity to get per-unit cost
        v_base_cost_per_unit := v_base_cost_per_unit / GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
    END IF;
    
    IF v_base_cost_per_unit = 0 THEN
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
    
    -- Step 5: Calculate unit price (before discount)
    -- Formula: unit_price = base_cost_per_unit * (1 + margin_percentage / 100)
    v_unit_price := v_base_cost_per_unit * (1 + v_margin_percentage / 100);
    
    -- Step 6: Determine discount (only if not manually set)
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
                    -- FIX: Convert ENUM to text before using TRIM/UPPER
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
                    v_discount_percentage := 0;
                    v_discount_source := NULL;
                END IF;
            ELSE
                v_discount_percentage := 0;
                v_discount_source := NULL;
            END IF;
        ELSE
            v_discount_percentage := 0;
            v_discount_source := NULL;
        END IF;
    END IF;
    
    -- Step 7: Apply discount to unit price
    IF v_discount_percentage > 0 THEN
        v_unit_price := v_unit_price * (1 - v_discount_percentage / 100);
    END IF;
    
    -- Step 8: Update QuoteLine with calculated price
    UPDATE "QuoteLines"
    SET 
        unit_price_snapshot = v_unit_price,
        margin_percentage = v_margin_percentage,
        margin_source = v_margin_source,
        discount_percentage = CASE WHEN v_discount_percentage > 0 THEN v_discount_percentage ELSE NULL END,
        discount_source = v_discount_source,
        updated_at = now()
    WHERE id = p_quote_line_id;
    
    RETURN p_quote_line_id;
END;
$$;

-- Update comment
COMMENT ON FUNCTION public.calculate_quote_line_price(uuid) IS 
'Calculates unit price for a QuoteLine using Category Margins and applies customer tier discounts.
Priority: Category Margin > Item Default Margin > 35% fallback.
Uses total_cost from QuoteLineCosts if available, otherwise uses CatalogItem.cost_exw.
Applies discount from customer pricing tier unless manually overridden.
FIXED: Converts ENUM to text before using TRIM() to avoid btrim() error.';

