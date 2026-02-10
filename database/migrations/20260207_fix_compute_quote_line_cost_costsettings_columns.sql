-- Fix compute_quote_line_cost: use actual CostSettings and ImportTaxRules columns (dump V9)
-- CostSettings: no id, no currency_code, no deleted; use labor_pct, shipping_pct, global_import_tax_pct (0-1), is_active
-- ImportTaxRules: use import_tax_pct (0-1), no deleted column

CREATE OR REPLACE FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
    v_quote_line_record RECORD;
    v_cost_settings_record RECORD;
    v_catalog_item_record RECORD;
    v_conversions_record RECORD;
    v_existing_cost_record RECORD;
    v_component_record RECORD;
    v_bom_component_record RECORD;
    v_category_tax_record RECORD;
    v_base_material_cost numeric(12,4) := 0;
    v_labor_cost numeric(12,4) := 0;
    v_shipping_cost numeric(12,4) := 0;
    v_import_tax_cost numeric(12,4) := 0;
    v_total_cost numeric(12,4) := 0;
    v_quote_line_cost_id uuid;
    v_reset_labor boolean := COALESCE((p_options->>'reset_labor')::boolean, false);
    v_reset_shipping boolean := COALESCE((p_options->>'reset_shipping')::boolean, false);
    v_reset_import_tax boolean := COALESCE((p_options->>'reset_import_tax')::boolean, false);
    v_labor_percentage numeric(8,4) := 10.0000;
    v_shipping_percentage numeric(8,4) := 15.0000;
    v_global_import_tax_percentage numeric(8,4) := 0;
    v_labor_source text := 'auto';
    v_shipping_source text := 'auto';
    v_import_tax_source text := 'auto';
    v_unit_cost numeric(12,4);
    v_extended_cost numeric(12,4);
    v_category_tax_percentage numeric(8,4);
    v_category_tax_amount numeric(12,4);
    v_has_bom boolean := false;
    v_category_cost_map jsonb := '{}'::jsonb;
    v_category_id uuid;
    v_category_extended_cost numeric(12,4);
    v_area_sqm numeric;
    v_category_key text;
    v_category_value text;
    v_breakdown_key text;
    v_breakdown_value text;
    v_import_tax_pct_raw numeric(8,4);
BEGIN
    -- Step 1: Load QuoteLine + organization_id + dimensions
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        ql.width_m,
        ql.height_m,
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
    
    -- Step 2: Check if catalog_item_id has a BOM
    SELECT EXISTS (
        SELECT 1
        FROM "BOMComponents" bom
        WHERE bom.parent_item_id = v_quote_line_record.catalog_item_id
        AND bom.organization_id = v_quote_line_record.organization_id
        AND bom.deleted = false
    ) INTO v_has_bom;
    
    -- Step 3: Calculate base_material_cost (unchanged - keep existing logic from dump)
    IF v_has_bom THEN
        v_area_sqm := CASE 
            WHEN v_quote_line_record.width_m IS NOT NULL 
                 AND v_quote_line_record.height_m IS NOT NULL 
            THEN v_quote_line_record.width_m * v_quote_line_record.height_m
            ELSE NULL
        END;
        
        FOR v_bom_component_record IN
            SELECT * FROM calculate_bom_price(
                v_quote_line_record.catalog_item_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_area_sqm
            )
        LOOP
            v_base_material_cost := v_base_material_cost + v_bom_component_record.extended_cost;
            IF v_bom_component_record.category_id IS NOT NULL THEN
                v_category_id := v_bom_component_record.category_id;
                v_category_extended_cost := COALESCE((v_category_cost_map->>v_category_id::text)::numeric, 0);
                v_category_extended_cost := v_category_extended_cost + v_bom_component_record.extended_cost;
                v_category_cost_map := jsonb_set(
                    v_category_cost_map,
                    ARRAY[v_category_id::text],
                    to_jsonb(v_category_extended_cost)
                );
            END IF;
        END LOOP;
        
        v_base_material_cost := v_base_material_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
        v_category_cost_map := (
            SELECT jsonb_object_agg(key, value::numeric * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1))
            FROM jsonb_each_text(v_category_cost_map)
        );
        
    ELSE
        SELECT SUM(COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0) * qlc.qty)
        INTO v_base_material_cost
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
        WHERE qlc.quote_line_id = p_quote_line_id
        AND qlc.deleted = false;
        
        IF v_base_material_cost IS NULL OR v_base_material_cost = 0 THEN
            SELECT 
                ci.id,
                ci.cost_exw,
                ci.is_roll,
                ci.roll_pricing_mode,
                ci.measure_basis,
                ci.unit_of_measure,
                ci.category_id,
                conv.cost_exw_per_m,
                conv.cost_exw_per_m2,
                conv.cost_exw_per_ea
            INTO v_catalog_item_record
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemConversions" conv 
                ON conv.catalog_item_id = ci.id 
                AND conv.organization_id = ci.organization_id
            WHERE ci.id = v_quote_line_record.catalog_item_id
            AND ci.is_active = true;
            
            IF FOUND THEN
                IF v_catalog_item_record.is_roll = true AND v_catalog_item_record.roll_pricing_mode IS NOT NULL THEN
                    IF v_catalog_item_record.roll_pricing_mode = 'per_linear_meter' THEN
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    ELSIF v_catalog_item_record.roll_pricing_mode = 'per_square_meter' THEN
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m2, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    ELSIF v_catalog_item_record.roll_pricing_mode = 'per_unit' THEN
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_ea, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.qty, 1);
                    ELSE
                        v_base_material_cost := COALESCE(v_catalog_item_record.cost_exw, 0) * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    END IF;
                ELSIF v_catalog_item_record.measure_basis = 'linear' THEN
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                ELSIF v_catalog_item_record.measure_basis = 'area' THEN
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m2, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                ELSIF v_catalog_item_record.measure_basis = 'unit' THEN
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_ea, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.qty, 1);
                ELSE
                    v_base_material_cost := COALESCE(v_catalog_item_record.cost_exw, 0) * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                END IF;
            ELSE
                v_base_material_cost := 0;
            END IF;
        END IF;
        
        FOR v_component_record IN
            SELECT 
                qlc.catalog_item_id,
                COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0) as unit_cost,
                qlc.qty,
                ci.item_category_id,
                ic.name as category_name
            FROM "QuoteLineComponents" qlc
            LEFT JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
            LEFT JOIN "ItemCategories" ic ON ci.item_category_id = ic.id
            WHERE qlc.quote_line_id = p_quote_line_id
            AND qlc.deleted = false
        LOOP
            IF v_component_record.item_category_id IS NOT NULL THEN
                v_category_id := v_component_record.item_category_id;
                v_category_extended_cost := COALESCE((v_category_cost_map->>v_category_id::text)::numeric, 0);
                v_category_extended_cost := v_category_extended_cost + (v_component_record.unit_cost * v_component_record.qty);
                v_category_cost_map := jsonb_set(
                    v_category_cost_map,
                    ARRAY[v_category_id::text],
                    to_jsonb(v_category_extended_cost)
                );
            END IF;
        END LOOP;
    END IF;
    
    -- Step 4: Load CostSettings (actual columns: labor_pct, shipping_pct, global_import_tax_pct; no id, no currency_code, no deleted)
    SELECT 
        labor_pct,
        shipping_pct,
        global_import_tax_pct
    INTO v_cost_settings_record
    FROM "CostSettings"
    WHERE organization_id = v_quote_line_record.organization_id
    AND is_active = true
    LIMIT 1;
    
    IF FOUND THEN
        -- DB stores 0-1 (e.g. 0.10); formula expects 0-100
        v_labor_percentage := COALESCE(v_cost_settings_record.labor_pct, 0.10) * 100.0;
        v_shipping_percentage := COALESCE(v_cost_settings_record.shipping_pct, 0.15) * 100.0;
        v_global_import_tax_percentage := COALESCE(v_cost_settings_record.global_import_tax_pct, 0) * 100.0;
    END IF;
    
    -- Step 5: Check for existing QuoteLineCosts to preserve manual overrides
    SELECT * INTO v_existing_cost_record
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    -- Step 6: Calculate labor and shipping costs
    IF v_existing_cost_record.id IS NOT NULL THEN
        IF v_existing_cost_record.labor_source = 'manual' AND NOT v_reset_labor THEN
            v_labor_cost := v_existing_cost_record.labor_cost;
            v_labor_source := 'manual';
        ELSE
            v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
            v_labor_source := 'auto';
        END IF;
        
        IF v_existing_cost_record.shipping_source = 'manual' AND NOT v_reset_shipping THEN
            v_shipping_cost := v_existing_cost_record.shipping_cost;
            v_shipping_source := 'manual';
        ELSE
            v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
            v_shipping_source := 'auto';
        END IF;
    ELSE
        v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
        v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
    END IF;
    
    -- Step 7: Calculate Import Tax by category (ImportTaxRules uses import_tax_pct 0-1, no deleted)
    IF v_existing_cost_record.id IS NOT NULL 
       AND v_existing_cost_record.import_tax_source = 'manual' 
       AND NOT v_reset_import_tax THEN
        v_import_tax_cost := v_existing_cost_record.import_tax_cost;
        v_import_tax_source := 'manual';
    ELSE
        v_import_tax_cost := 0;
        
        FOR v_category_key, v_category_value IN
            SELECT key, value
            FROM jsonb_each_text(v_category_cost_map)
        LOOP
            v_category_id := v_category_key::uuid;
            v_category_extended_cost := v_category_value::numeric;
            
            v_category_tax_percentage := NULL;
            SELECT import_tax_pct INTO v_import_tax_pct_raw
            FROM "ImportTaxRules"
            WHERE organization_id = v_quote_line_record.organization_id
            AND category_id = v_category_id
            AND is_active = true
            LIMIT 1;
            
            IF v_import_tax_pct_raw IS NOT NULL THEN
                v_category_tax_percentage := v_import_tax_pct_raw * 100.0;
            ELSE
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
            v_category_tax_amount := v_category_extended_cost * (v_category_tax_percentage / 100.0);
            v_import_tax_cost := v_import_tax_cost + v_category_tax_amount;
        END LOOP;
        
        v_import_tax_source := 'auto';
    END IF;
    
    -- Step 8: Calculate total_cost
    v_total_cost := v_base_material_cost + v_labor_cost + v_shipping_cost + v_import_tax_cost;
    
    -- Step 9: Upsert into QuoteLineCosts (currency from Quotes)
    INSERT INTO "QuoteLineCosts" (
        organization_id,
        quote_id,
        quote_line_id,
        currency_code,
        base_material_cost,
        labor_cost,
        shipping_cost,
        import_tax_cost,
        labor_source,
        shipping_source,
        import_tax_source,
        total_cost
    )
    VALUES (
        v_quote_line_record.organization_id,
        v_quote_line_record.quote_id,
        p_quote_line_id,
        v_quote_line_record.currency,
        v_base_material_cost,
        v_labor_cost,
        v_shipping_cost,
        v_import_tax_cost,
        v_labor_source,
        v_shipping_source,
        v_import_tax_source,
        v_total_cost
    )
    ON CONFLICT (quote_line_id) 
    DO UPDATE SET
        base_material_cost = EXCLUDED.base_material_cost,
        labor_cost = EXCLUDED.labor_cost,
        shipping_cost = EXCLUDED.shipping_cost,
        import_tax_cost = EXCLUDED.import_tax_cost,
        labor_source = EXCLUDED.labor_source,
        shipping_source = EXCLUDED.shipping_source,
        import_tax_source = EXCLUDED.import_tax_source,
        total_cost = EXCLUDED.total_cost,
        updated_at = now()
    RETURNING id INTO v_quote_line_cost_id;
    
    -- Step 10: Update QuoteLineImportTaxBreakdown (if using BOM) - use import_tax_pct * 100 for percentage
    IF v_has_bom THEN
        DELETE FROM "QuoteLineImportTaxBreakdown"
        WHERE quote_line_id = p_quote_line_id
        AND deleted = false;
        
        FOR v_breakdown_key, v_breakdown_value IN
            SELECT key, value
            FROM jsonb_each_text(v_category_cost_map)
        LOOP
            v_category_id := v_breakdown_key::uuid;
            v_category_extended_cost := v_breakdown_value::numeric;
            
            SELECT name INTO v_category_tax_record.category_name
            FROM "ItemCategories"
            WHERE id = v_category_id
            AND deleted = false
            LIMIT 1;
            
            v_category_tax_percentage := NULL;
            SELECT import_tax_pct INTO v_import_tax_pct_raw
            FROM "ImportTaxRules"
            WHERE organization_id = v_quote_line_record.organization_id
            AND category_id = v_category_id
            AND is_active = true
            LIMIT 1;
            
            IF v_import_tax_pct_raw IS NOT NULL THEN
                v_category_tax_percentage := v_import_tax_pct_raw * 100.0;
            ELSE
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
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
                v_category_id,
                COALESCE(v_category_tax_record.category_name, 'Unknown'),
                v_category_extended_cost,
                v_category_tax_percentage,
                v_category_extended_cost * (v_category_tax_percentage / 100.0)
            );
        END LOOP;
    END IF;
    
    RETURN v_quote_line_cost_id;
END;
$_$;

ALTER FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") OWNER TO "postgres";
COMMENT ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") IS 'Calculates quote line costs. Uses CostSettings.labor_pct, shipping_pct, global_import_tax_pct (0-1) and ImportTaxRules.import_tax_pct (0-1).';
