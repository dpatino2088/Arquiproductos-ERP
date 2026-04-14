CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_mo RECORD; v_mo_line RECORD; v_sales_order_line RECORD; v_bom_instance_id uuid; v_bom_template_id uuid; v_bom_component RECORD; v_catalog_item RECORD; v_fabric_count integer := 0; v_calculated_qty numeric; v_normalized_uom text; v_category_code text; v_unit_cost_exw numeric(12,4) := 0; v_total_cost_exw numeric(12,4) := 0; v_unit_msrp_sale_out numeric(12,4) := 0; v_total_msrp_sale_out numeric(12,4) := 0; v_bom_total_cost numeric(12,4) := 0; v_bom_labor_cost numeric(12,4) := 0; v_bom_total_cost_with_labor numeric(12,4) := 0; v_bom_msrp_sale_out numeric(12,4) := 0; v_cost_settings RECORD; v_shipping_percentage numeric(8,4) := 0; v_import_tax_percentage numeric(8,4) := 0; v_min_margin_pct numeric(8,4) := 35.0; v_max_discount_pct numeric(8,4) := 65.0; v_labor_percentage numeric(8,4) := 0; v_created_lines integer := 0; v_errors text[] := ARRAY[]::text[]; v_warnings text[] := ARRAY[]::text[]; v_formula_params jsonb; v_total_bom_instances integer := 0; v_total_bom_lines integer := 0; v_mo_lines_processed integer := 0; v_mo_lines_before integer := 0; v_mo_lines_after integer := 0; v_created_mo_lines integer := 0; v_bom_instances_before integer := 0; v_bom_instances_after integer := 0; v_bom_lines_before integer := 0; v_bom_lines_after integer := 0; v_cost_from_msrp boolean := false;
BEGIN
    SELECT * INTO v_mo FROM public."ManufacturingOrders" WHERE id = p_manufacturing_order_id;
    IF v_mo.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO not found'], 'warnings', ARRAY[]::text[]); END IF;
    IF v_mo.deleted = true THEN RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO is deleted'], 'warnings', ARRAY[]::text[]); END IF;
    IF v_mo.sales_order_id IS NULL THEN v_warnings := v_warnings || 'MO has no sales_order_id'; END IF;
    SELECT COUNT(*) INTO v_mo_lines_before FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bom_instances_before FROM public."BOMInstances" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bom_lines_before FROM public."BOMInstanceLines" bil JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;
    IF v_mo_lines_before = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'planned'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND NOT EXISTS (SELECT 1 FROM public."ManufacturingOrderLines" mol2 WHERE mol2.manufacturing_order_id = p_manufacturing_order_id AND mol2.sales_order_line_id = sol.id);
        GET DIAGNOSTICS v_created_mo_lines = ROW_COUNT;
    END IF;
    SELECT COUNT(*) INTO v_mo_lines_after FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    IF v_mo_lines_after = 0 THEN
        RETURN jsonb_build_object('ok', true, 'mo_lines_before', v_mo_lines_before, 'mo_lines_after', v_mo_lines_after, 'mo_lines_created', v_created_mo_lines, 'bom_instances_before', v_bom_instances_before, 'bom_instances_after', v_bom_instances_before, 'bom_instances_created', 0, 'bom_instance_lines_before', v_bom_lines_before, 'bom_instance_lines_after', v_bom_lines_before, 'bom_instance_lines_created', 0, 'warnings', v_warnings, 'errors', v_errors);
    END IF;
    SELECT shipping_pct, import_tax_pct, minimum_margin_pct, default_msrp_pct, labor_pct INTO v_cost_settings FROM "CostSettings" WHERE organization_id = v_mo.organization_id AND is_active = true LIMIT 1;
    IF FOUND THEN
        v_shipping_percentage := COALESCE(v_cost_settings.shipping_pct, 0); v_import_tax_percentage := COALESCE(v_cost_settings.import_tax_pct, 0); v_min_margin_pct := COALESCE(v_cost_settings.minimum_margin_pct, 35.0); v_labor_percentage := COALESCE(v_cost_settings.labor_pct, 0); v_max_discount_pct := COALESCE(v_cost_settings.default_msrp_pct, 65.0);
    END IF;
    FOR v_mo_line IN SELECT mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false ORDER BY mol.created_at ASC
    LOOP
        v_mo_lines_processed := v_mo_lines_processed + 1; v_bom_instance_id := NULL; v_bom_template_id := NULL; v_fabric_count := 0; v_bom_total_cost := 0; v_created_lines := 0;
        SELECT sol.id, sol.product_type, sol.collection_name, sol.variant_name, sol.width_m, sol.height_m, sol.area, ql.drive_type, ql.cassette, NULL::text AS cassette_type, ql.side_channel, NULL::text AS side_channel_type, sol.hardware_color, NULL::text AS bottom_rail_type, sol.quote_line_id INTO v_sales_order_line FROM "SaleOrderLines" sol LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id WHERE sol.id = v_mo_line.sales_order_line_id AND sol.deleted = false;
        IF NOT FOUND THEN v_warnings := v_warnings || format('SaleOrderLine %s not found', v_mo_line.sales_order_line_id); CONTINUE; END IF;
        IF v_sales_order_line.product_type IS NULL OR TRIM(v_sales_order_line.product_type) = '' THEN v_warnings := v_warnings || format('SaleOrderLine %s has NULL product_type', v_sales_order_line.id); CONTINUE; END IF;
        SELECT bt.id INTO v_bom_template_id FROM "BOMTemplates" bt INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id WHERE pt.code = v_sales_order_line.product_type AND bt.is_active = true AND bt.deleted = false ORDER BY bt.created_at DESC LIMIT 1;
        IF NOT FOUND THEN v_warnings := v_warnings || format('No active BOMTemplate for product_type: %s', v_sales_order_line.product_type); CONTINUE; END IF;
        UPDATE "BOMInstanceLines" bil SET deleted = true, updated_at = now() WHERE bil.bom_instance_id IN (SELECT bi.id FROM "BOMInstances" bi WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sales_order_line.id AND bi.deleted = false);
        UPDATE "BOMInstances" bi SET deleted = true, updated_at = now() WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sales_order_line.id AND bi.deleted = false;
        INSERT INTO "BOMInstances" (organization_id, manufacturing_order_id, sales_order_line_id, quote_line_id, bom_template_id, status, deleted, created_at, updated_at, generated_at) VALUES (v_mo.organization_id, p_manufacturing_order_id, v_sales_order_line.id, v_sales_order_line.quote_line_id, v_bom_template_id, 'draft', false, now(), now(), now()) RETURNING id INTO v_bom_instance_id;
        IF v_bom_instance_id IS NULL THEN CONTINUE; END IF;
        v_total_bom_instances := v_total_bom_instances + 1;
        FOR v_bom_component IN SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_formula_code, bc.qty_formula_params, bc.uom FROM "BOMComponents" bc WHERE bc.bom_template_id = v_bom_template_id AND bc.deleted = false AND bc.component_item_id IS NOT NULL ORDER BY bc.created_at
        LOOP
            IF v_bom_component.component_role = 'fabric' THEN
                v_fabric_count := v_fabric_count + 1; IF v_fabric_count > 1 THEN CONTINUE; END IF;
                SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw INTO v_catalog_item FROM "CatalogItems" ci INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id WHERE ci.id = v_bom_component.component_item_id AND ci.organization_id = v_mo.organization_id AND ci.is_active = true AND ic.code = 'FABRIC' AND ci.collection_name = v_sales_order_line.collection_name AND ((v_sales_order_line.variant_name IS NULL AND ci.variant_name IS NULL) OR ci.variant_name = v_sales_order_line.variant_name);
                IF NOT FOUND THEN v_warnings := v_warnings || format('Fabric mismatch for CatalogItem %s', v_bom_component.component_item_id); CONTINUE; END IF;
            ELSE
                SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw INTO v_catalog_item FROM "CatalogItems" ci WHERE ci.id = v_bom_component.component_item_id AND ci.organization_id = v_mo.organization_id AND ci.is_active = true;
                IF NOT FOUND THEN v_warnings := v_warnings || format('CatalogItem %s not found', v_bom_component.component_item_id); CONTINUE; END IF;
            END IF;
            IF v_bom_component.qty_formula_code = 'CHAIN_HEIGHT_FACTOR' THEN
                v_formula_params := v_bom_component.qty_formula_params;
                IF v_formula_params IS NULL OR (v_formula_params->>'height_factor') IS NULL OR (v_formula_params->>'mult') IS NULL OR v_sales_order_line.height_m IS NULL THEN CONTINUE; END IF;
                v_calculated_qty := v_sales_order_line.height_m * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75) * COALESCE((v_formula_params->>'mult')::numeric, 2);
            ELSIF v_bom_component.qty_type = 'per_width' THEN
                IF v_sales_order_line.width_m IS NULL THEN CONTINUE; END IF;
                v_calculated_qty := v_sales_order_line.width_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'per_area' THEN
                IF v_sales_order_line.width_m IS NULL OR v_sales_order_line.height_m IS NULL THEN CONTINUE; END IF;
                v_calculated_qty := v_sales_order_line.width_m * v_sales_order_line.height_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'fixed' THEN v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
            ELSE CONTINUE;
            END IF;
            IF v_calculated_qty IS NULL OR v_calculated_qty <= 0 THEN CONTINUE; END IF;
            v_normalized_uom := CASE WHEN UPPER(TRIM(v_bom_component.uom)) IN ('PCS','PIECE','PIECES','SET','SETS','EA','EACH') THEN 'ea' WHEN v_bom_component.component_role = 'fabric' THEN 'm2' WHEN v_bom_component.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile','chain') OR UPPER(TRIM(v_bom_component.uom)) IN ('FT','FEET','FOOT','MTS','M','METER','METERS') THEN 'm' WHEN UPPER(TRIM(v_bom_component.uom)) IN ('M2','SQM','SQ_M') THEN 'm2' ELSE NULL END;
            IF v_normalized_uom IS NULL THEN CONTINUE; END IF;
            v_category_code := CASE WHEN v_bom_component.component_role = 'fabric' THEN 'fabric' WHEN v_bom_component.component_role = 'tube' THEN 'tube' WHEN v_bom_component.component_role = 'motor' THEN 'motor' WHEN v_bom_component.component_role = 'bracket' THEN 'bracket' WHEN v_bom_component.component_role LIKE '%cassette%' THEN 'cassette' WHEN v_bom_component.component_role LIKE '%side_channel%' THEN 'side_channel' WHEN v_bom_component.component_role LIKE '%bottom_rail%' OR v_bom_component.component_role LIKE '%bottom_channel%' OR v_bom_component.component_role LIKE '%bottom_bar%' THEN 'bottom_channel' ELSE 'accessory' END;
            v_cost_from_msrp := false;
            SELECT cim.total_cost INTO v_unit_cost_exw FROM "CatalogItemsMSRP" cim WHERE cim.catalog_item_id = v_catalog_item.id AND cim.organization_id = v_mo.organization_id AND cim.total_cost IS NOT NULL LIMIT 1;
            IF FOUND AND v_unit_cost_exw IS NOT NULL THEN v_cost_from_msrp := true; ELSE v_unit_cost_exw := COALESCE(CAST(v_catalog_item.cost_exw AS numeric(12,4)), 0); END IF;
            v_total_cost_exw := v_unit_cost_exw * v_calculated_qty;
            IF v_unit_cost_exw > 0 THEN
                DECLARE v_uct numeric(12,4); v_msi numeric(12,4);
                BEGIN
                    IF v_cost_from_msrp THEN v_uct := v_unit_cost_exw; ELSE v_uct := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0)); END IF;
                    v_msi := v_uct / (1 - (v_min_margin_pct / 100.0));
                    v_unit_msrp_sale_out := v_msi / (1 - (v_max_discount_pct / 100.0));
                    v_total_msrp_sale_out := v_unit_msrp_sale_out * v_calculated_qty;
                END;
            ELSE v_unit_msrp_sale_out := 0; v_total_msrp_sale_out := 0;
            END IF;
            v_bom_total_cost := v_bom_total_cost + v_total_cost_exw;
            INSERT INTO "BOMInstanceLines" (organization_id, bom_instance_id, resolved_part_id, resolved_sku, part_role, qty, uom, description, category_code, unit_cost_exw, total_cost_exw, unit_msrp_sale_out, total_msrp_sale_out, cut_l_mm, deleted, created_at, updated_at) VALUES (v_mo.organization_id, v_bom_instance_id, v_catalog_item.id, v_catalog_item.sku, v_bom_component.component_role, v_calculated_qty, v_normalized_uom, COALESCE(v_catalog_item.description, v_catalog_item.item_name), v_category_code, COALESCE(v_unit_cost_exw, 0)::numeric(12,4), COALESCE(v_total_cost_exw, 0)::numeric(12,4), COALESCE(v_unit_msrp_sale_out, 0)::numeric(12,4), COALESCE(v_total_msrp_sale_out, 0)::numeric(12,4), CASE WHEN v_bom_component.qty_type = 'per_width' OR v_bom_component.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile') THEN COALESCE(v_sales_order_line.width_m, 0) * 1000.0 ELSE NULL END, false, now(), now());
            v_created_lines := v_created_lines + 1; v_total_bom_lines := v_total_bom_lines + 1;
        END LOOP;
        v_bom_labor_cost := v_bom_total_cost * (v_labor_percentage / 100.0);
        v_bom_total_cost_with_labor := v_bom_total_cost + v_bom_labor_cost;
        DECLARE v_bmsi numeric(12,4);
        BEGIN v_bmsi := v_bom_total_cost_with_labor / (1 - (v_min_margin_pct / 100.0)); v_bom_msrp_sale_out := v_bmsi / (1 - (v_max_discount_pct / 100.0)); END;
        UPDATE "BOMInstances" SET labor_cost = v_bom_labor_cost, total_cost_with_labor = v_bom_total_cost_with_labor, total_msrp_sale_out_with_labor = v_bom_msrp_sale_out, updated_at = now() WHERE id = v_bom_instance_id;
    END LOOP;
    SELECT COUNT(*) INTO v_bom_instances_after FROM public."BOMInstances" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bom_lines_after FROM public."BOMInstanceLines" bil JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;
    RETURN jsonb_build_object('ok', array_length(v_errors, 1) IS NULL OR array_length(v_errors, 1) = 0, 'manufacturing_order_id', p_manufacturing_order_id, 'mo_lines_before', v_mo_lines_before, 'mo_lines_after', v_mo_lines_after, 'mo_lines_created', v_created_mo_lines, 'mo_lines_processed', v_mo_lines_processed, 'bom_instances_before', v_bom_instances_before, 'bom_instances_after', v_bom_instances_after, 'bom_instances_created', v_bom_instances_after - v_bom_instances_before, 'bom_instance_lines_before', v_bom_lines_before, 'bom_instance_lines_after', v_bom_lines_after, 'bom_instance_lines_created', v_bom_lines_after - v_bom_lines_before, 'warnings', COALESCE(v_warnings, ARRAY[]::text[]), 'errors', COALESCE(v_errors, ARRAY[]::text[]));
END;
$function$;;
