-- ====================================================
-- Migration: Update compute_quote_line_cost to save Import Tax Breakdown
-- ====================================================
-- Groups components by category and saves breakdown to QuoteLineImportTaxBreakdown
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
    v_category_breakdown RECORD;
    v_base_material_cost numeric(12,4) := 0;
    v_labor_cost numeric(12,4) := 0;
    v_shipping_cost numeric(12,4) := 0;
    v_import_tax_cost numeric(12,4) := 0;
    v_total_cost numeric(12,4) := 0;
    v_quote_line_cost_id uuid;
    v_reset_labor boolean := COALESCE((p_options->>'reset_labor')::boolean, false);
    v_reset_shipping boolean := COALESCE((p_options->>'reset_shipping')::boolean, false);
    v_reset_import_tax boolean := COALESCE((p_options->>'reset_import_tax')::boolean, false);
    v_labor_percentage numeric(8,4) := 10.0000; -- Default 10%
    v_shipping_percentage numeric(8,4) := 15.0000; -- Default 15%
    v_global_import_tax_percentage numeric(8,4) := 0; -- Default 0%
    v_labor_source text := 'auto';
    v_shipping_source text := 'auto';
    v_import_tax_source text := 'auto';
    v_category_tax_percentage numeric(8,4);
    v_category_name text;
    v_category_tax_amount numeric(12,4);
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
        shipping_percentage,
        import_tax_percent
    INTO v_cost_settings_record
    FROM "CostSettings"
    WHERE organization_id = v_quote_line_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        v_labor_percentage := COALESCE(v_cost_settings_record.labor_percentage, 10.0000);
        v_shipping_percentage := COALESCE(v_cost_settings_record.shipping_percentage, 15.0000);
        v_global_import_tax_percentage := COALESCE(v_cost_settings_record.import_tax_percent, 0);
    END IF;
    
    -- Step 4: Check if QuoteLineCosts already exists
    SELECT 
        id,
        labor_cost,
        shipping_cost,
        import_tax_cost,
        labor_source,
        shipping_source,
        import_tax_source
    INTO v_existing_cost_record
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    -- Step 5: Calculate labor_cost
    IF FOUND AND v_existing_cost_record.labor_source = 'manual' AND NOT v_reset_labor THEN
        v_labor_cost := v_existing_cost_record.labor_cost;
        v_labor_source := 'manual';
    ELSE
        v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
        v_labor_source := 'auto';
    END IF;
    
    -- Step 6: Calculate shipping_cost
    IF FOUND AND v_existing_cost_record.shipping_source = 'manual' AND NOT v_reset_shipping THEN
        v_shipping_cost := v_existing_cost_record.shipping_cost;
        v_shipping_source := 'manual';
    ELSE
        v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
        v_shipping_source := 'auto';
    END IF;
    
    -- Step 7: Calculate import_tax_cost from REAL components (GROUPED BY CATEGORY)
    IF FOUND AND v_existing_cost_record.import_tax_source = 'manual' AND NOT v_reset_import_tax THEN
        -- Keep existing manual import_tax_cost
        v_import_tax_cost := v_existing_cost_record.import_tax_cost;
        v_import_tax_source := 'manual';
    ELSE
        -- Delete existing breakdown (will recreate)
        DELETE FROM "QuoteLineImportTaxBreakdown"
        WHERE quote_line_id = p_quote_line_id;
        
        -- Calculate from QuoteLineComponents grouped by category
        v_import_tax_cost := 0;
        
        -- Group components by category and calculate tax for each
        FOR v_category_breakdown IN
            SELECT 
                COALESCE(ci.item_category_id, '00000000-0000-0000-0000-000000000000'::uuid) as category_id,
                ic.name as category_name,
                SUM(qlc.qty * COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0)) as extended_cost
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE qlc.quote_line_id = p_quote_line_id
            AND qlc.deleted = false
            AND ci.deleted = false
            GROUP BY ci.item_category_id, ic.name
            HAVING SUM(qlc.qty * COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0)) > 0
        LOOP
            -- Get tax percentage for this category
            IF v_category_breakdown.category_id != '00000000-0000-0000-0000-000000000000'::uuid THEN
                -- Try to find category-specific rule
                SELECT import_tax_percentage
                INTO v_category_tax_percentage
                FROM "ImportTaxRules"
                WHERE organization_id = v_quote_line_record.organization_id
                AND category_id = v_category_breakdown.category_id
                AND active = true
                AND deleted = false
                LIMIT 1;
                
                -- If not found, use global default
                IF NOT FOUND THEN
                    v_category_tax_percentage := v_global_import_tax_percentage;
                END IF;
            ELSE
                -- No category, use global default
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
            -- Calculate tax amount for this category
            v_category_tax_amount := v_category_breakdown.extended_cost * (v_category_tax_percentage / 100.0);
            
            -- Add to total import_tax_cost
            v_import_tax_cost := v_import_tax_cost + v_category_tax_amount;
            
            -- Save breakdown
            INSERT INTO "QuoteLineImportTaxBreakdown" (
                organization_id,
                quote_line_id,
                category_id,
                category_name,
                extended_cost,
                import_tax_percentage,
                import_tax_amount
            )
            VALUES (
                v_quote_line_record.organization_id,
                p_quote_line_id,
                CASE WHEN v_category_breakdown.category_id != '00000000-0000-0000-0000-000000000000'::uuid 
                     THEN v_category_breakdown.category_id 
                     ELSE NULL END,
                COALESCE(v_category_breakdown.category_name, 'No Category'),
                v_category_breakdown.extended_cost,
                v_category_tax_percentage,
                v_category_tax_amount
            );
        END LOOP;
        
        -- If no components found, use legacy calculation (base_material_cost * global percentage)
        -- This maintains backward compatibility
        IF v_import_tax_cost = 0 AND v_base_material_cost > 0 THEN
            v_import_tax_cost := v_base_material_cost * (v_global_import_tax_percentage / 100.0);
            
            -- Save breakdown for legacy calculation
            INSERT INTO "QuoteLineImportTaxBreakdown" (
                organization_id,
                quote_line_id,
                category_id,
                category_name,
                extended_cost,
                import_tax_percentage,
                import_tax_amount
            )
            VALUES (
                v_quote_line_record.organization_id,
                p_quote_line_id,
                NULL,
                'Legacy (Base Material)',
                v_base_material_cost,
                v_global_import_tax_percentage,
                v_import_tax_cost
            );
        END IF;
        
        v_import_tax_source := 'auto';
    END IF;
    
    -- Step 8: Calculate total_cost
    v_total_cost := v_base_material_cost + v_labor_cost + v_shipping_cost + v_import_tax_cost;
    
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
        import_tax_cost,
        import_tax_source,
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
        v_import_tax_cost,
        v_import_tax_source,
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
        import_tax_cost = CASE 
            WHEN v_reset_import_tax THEN EXCLUDED.import_tax_cost
            WHEN "QuoteLineCosts".import_tax_source = 'manual' THEN "QuoteLineCosts".import_tax_cost
            ELSE EXCLUDED.import_tax_cost
        END,
        import_tax_source = CASE 
            WHEN v_reset_import_tax THEN 'auto'
            WHEN "QuoteLineCosts".import_tax_source = 'manual' THEN 'manual'
            ELSE EXCLUDED.import_tax_source
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
                    END +
                    CASE 
                        WHEN v_reset_import_tax THEN EXCLUDED.import_tax_cost
                        WHEN "QuoteLineCosts".import_tax_source = 'manual' THEN "QuoteLineCosts".import_tax_cost
                        ELSE EXCLUDED.import_tax_cost
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
-- Update comment
-- ====================================================

COMMENT ON FUNCTION public.compute_quote_line_cost(uuid, jsonb) IS 
    'Cost Engine v1: Calculates quote line costs using percentage-based labor and shipping, 
     and REAL import tax from QuoteLineComponents grouped by category.
     Saves breakdown to QuoteLineImportTaxBreakdown for detailed view.
     Options: { "reset_labor": boolean, "reset_shipping": boolean, "reset_import_tax": boolean }
     Respects manual overrides unless reset is explicitly requested.';

-- ====================================================
-- Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Updated compute_quote_line_cost to save Import Tax Breakdown';
    RAISE NOTICE '📋 Features:';
    RAISE NOTICE '   - Groups components by category';
    RAISE NOTICE '   - Saves breakdown to QuoteLineImportTaxBreakdown';
    RAISE NOTICE '   - Shows category name, extended cost, percentage, and tax amount';
END $$;

