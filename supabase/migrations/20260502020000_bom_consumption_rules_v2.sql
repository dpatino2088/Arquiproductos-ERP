-- BOM Consumption Rules v2
-- Adds: per_spacing qty_type, children processing, cut_delta_mm application
-- Backward compatible: existing per_width, per_height, per_area, fixed still work

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_mo RECORD;
    v_mo_line RECORD;
    v_sol RECORD;
    v_bi_id uuid;
    v_bt_id uuid;
    v_bc RECORD;
    v_child RECORD;
    v_ci RECORD;
    v_fc integer := 0;
    v_qty numeric;
    v_uom text;
    v_ucx numeric(12,4) := 0;
    v_tcx numeric(12,4) := 0;
    v_um numeric(12,4) := 0;
    v_tm numeric(12,4) := 0;
    v_btc numeric(12,4) := 0;
    v_cs RECORD;
    v_sp numeric(8,4) := 0;
    v_ip numeric(8,4) := 0;
    v_mm numeric(8,4) := 35.0;
    v_md numeric(8,4) := 65.0;
    v_lp numeric(8,4) := 0;
    v_cl integer := 0;
    v_err text[] := ARRAY[]::text[];
    v_warn text[] := ARRAY[]::text[];
    v_tbi integer := 0;
    v_tbl integer := 0;
    v_mlp integer := 0;
    v_mlb integer := 0;
    v_mla integer := 0;
    v_cml integer := 0;
    v_bib integer := 0;
    v_bia integer := 0;
    v_blb integer := 0;
    v_bla integer := 0;
    v_cfm boolean := false;
    v_cut_length numeric;
    v_cut_height numeric;
    v_dim_mm numeric;
    v_parent_cut_length numeric;
    v_parent_cut_height numeric;
BEGIN
    SELECT * INTO v_mo FROM public."ManufacturingOrders" WHERE id = p_manufacturing_order_id;
    IF v_mo.id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO not found'], 'warnings', ARRAY[]::text[]);
    END IF;
    IF v_mo.deleted = true THEN
        RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO is deleted'], 'warnings', ARRAY[]::text[]);
    END IF;
    IF v_mo.sales_order_id IS NULL THEN
        v_warn := v_warn || 'MO has no sales_order_id';
    END IF;

    SELECT COUNT(*) INTO v_mlb FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_bib FROM public."BOMInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_blb FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'planned'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND NOT EXISTS (
            SELECT 1 FROM public."ManufacturingOrderLines" m2
            WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id
          );
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;

    SELECT COUNT(*) INTO v_mla FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    IF v_mla = 0 THEN
        RETURN jsonb_build_object(
            'ok', true, 'mo_lines_before', v_mlb, 'mo_lines_after', v_mla,
            'mo_lines_created', v_cml, 'bom_instances_before', v_bib,
            'bom_instances_after', v_bib, 'bom_instances_created', 0,
            'bom_instance_lines_before', v_blb, 'bom_instance_lines_after', v_blb,
            'bom_instance_lines_created', 0, 'warnings', v_warn, 'errors', v_err
        );
    END IF;

    SELECT shipping_pct, import_tax_pct, minimum_margin_pct, default_msrp_pct, labor_pct
    INTO v_cs FROM "CostSettings"
    WHERE organization_id = v_mo.organization_id AND is_active = true LIMIT 1;

    IF FOUND THEN
        v_sp := COALESCE(v_cs.shipping_pct, 0);
        v_ip := COALESCE(v_cs.import_tax_pct, 0);
        v_mm := COALESCE(v_cs.minimum_margin_pct, 35.0);
        v_lp := COALESCE(v_cs.labor_pct, 0);
        v_md := COALESCE(v_cs.default_msrp_pct, 65.0);
    END IF;

    FOR v_mo_line IN
        SELECT mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false
        ORDER BY mol.created_at ASC
    LOOP
        v_mlp := v_mlp + 1;
        v_bi_id := NULL;
        v_bt_id := NULL;
        v_fc := 0;
        v_btc := 0;
        v_cl := 0;

        SELECT sol.id, sol.product_type, sol.collection_name, sol.variant_name,
               sol.width_m, sol.height_m, sol.area, sol.hardware_color, sol.quote_line_id
        INTO v_sol
        FROM "SaleOrderLines" sol
        WHERE sol.id = v_mo_line.sales_order_line_id AND sol.deleted = false;

        IF NOT FOUND THEN
            v_warn := v_warn || format('SaleOrderLine %s not found', v_mo_line.sales_order_line_id);
            CONTINUE;
        END IF;

        IF v_sol.product_type IS NULL OR TRIM(v_sol.product_type) = '' THEN
            v_warn := v_warn || format('SaleOrderLine %s has NULL product_type', v_sol.id);
            CONTINUE;
        END IF;

        SELECT bt.id INTO v_bt_id FROM "BOMTemplates" bt
        INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
        WHERE pt.code = v_sol.product_type AND bt.is_active = true AND bt.deleted = false
        ORDER BY bt.created_at DESC LIMIT 1;

        IF NOT FOUND THEN
            v_warn := v_warn || format('No BOMTemplate for: %s', v_sol.product_type);
            CONTINUE;
        END IF;

        UPDATE "BOMInstanceLines" bil SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id IN (
            SELECT bi.id FROM "BOMInstances" bi
            WHERE bi.manufacturing_order_id = p_manufacturing_order_id
              AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false
        );

        UPDATE "BOMInstances" bi SET deleted = true, updated_at = now()
        WHERE bi.manufacturing_order_id = p_manufacturing_order_id
          AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false;

        INSERT INTO "BOMInstances" (
            organization_id, manufacturing_order_id, sales_order_line_id,
            quote_line_id, bom_template_id, deleted, created_at, updated_at
        ) VALUES (
            v_mo.organization_id, p_manufacturing_order_id, v_sol.id,
            v_sol.quote_line_id, v_bt_id, false, now(), now()
        ) RETURNING id INTO v_bi_id;

        IF v_bi_id IS NULL THEN CONTINUE; END IF;
        v_tbi := v_tbi + 1;

        -- Process PARENT components only (parent_component_id IS NULL)
        FOR v_bc IN
            SELECT bc.id, bc.component_role, bc.component_item_id,
                   bc.qty_type, bc.qty_value, bc.uom,
                   bc.qty_spacing_mm, bc.qty_min, bc.cut_delta_mm,
                   bc.depends_on_role
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bt_id
              AND bc.deleted = false
              AND bc.component_item_id IS NOT NULL
              AND bc.parent_component_id IS NULL
            ORDER BY bc.sort_order, bc.created_at
        LOOP
            -- Resolve catalog item
            IF v_bc.component_role = 'fabric' THEN
                v_fc := v_fc + 1;
                IF v_fc > 1 THEN CONTINUE; END IF;
                SELECT ci.id, ci.sku, ci.name, ci.description, ci.cost_exw
                INTO v_ci FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ci.id = v_bc.component_item_id
                  AND ci.organization_id = v_mo.organization_id
                  AND ci.is_active = true AND ic.code = 'FABRIC'
                  AND ci.collection_name = v_sol.collection_name
                  AND ((v_sol.variant_name IS NULL AND ci.variant_name IS NULL) OR ci.variant_name = v_sol.variant_name);
                IF NOT FOUND THEN
                    v_warn := v_warn || format('Fabric mismatch %s', v_bc.component_item_id);
                    CONTINUE;
                END IF;
            ELSE
                SELECT ci.id, ci.sku, ci.name, ci.description, ci.cost_exw
                INTO v_ci FROM "CatalogItems" ci
                WHERE ci.id = v_bc.component_item_id
                  AND ci.organization_id = v_mo.organization_id
                  AND ci.is_active = true;
                IF NOT FOUND THEN
                    v_warn := v_warn || format('CatalogItem %s not found', v_bc.component_item_id);
                    CONTINUE;
                END IF;
            END IF;

            -- Calculate quantity based on qty_type
            IF v_bc.qty_type = 'per_width' THEN
                IF v_sol.width_m IS NULL THEN CONTINUE; END IF;
                v_qty := v_sol.width_m * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_height' THEN
                IF v_sol.height_m IS NULL THEN CONTINUE; END IF;
                v_qty := v_sol.height_m * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_area' THEN
                IF v_sol.width_m IS NULL OR v_sol.height_m IS NULL THEN CONTINUE; END IF;
                v_qty := v_sol.width_m * v_sol.height_m * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_spacing' THEN
                v_dim_mm := COALESCE(v_sol.width_m, 0) * 1000.0;
                IF v_bc.depends_on_role IS NOT NULL AND v_bc.depends_on_role = 'height' THEN
                    v_dim_mm := COALESCE(v_sol.height_m, 0) * 1000.0;
                END IF;
                IF v_dim_mm <= 0 THEN CONTINUE; END IF;
                v_qty := CEIL(v_dim_mm / COALESCE(v_bc.qty_spacing_mm, 500));
                IF v_bc.qty_min IS NOT NULL AND v_qty < v_bc.qty_min THEN
                    v_qty := v_bc.qty_min;
                END IF;
            ELSIF v_bc.qty_type = 'fixed' THEN
                v_qty := COALESCE(v_bc.qty_value, 1);
            ELSE
                CONTINUE;
            END IF;

            IF v_qty IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

            -- Normalize UOM
            v_uom := CASE
                WHEN UPPER(TRIM(v_bc.uom)) IN ('PCS','PIECE','PIECES','SET','SETS','EA','EACH') THEN 'ea'
                WHEN v_bc.component_role = 'fabric' THEN 'm2'
                WHEN v_bc.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile','chain')
                     OR UPPER(TRIM(v_bc.uom)) IN ('FT','FEET','FOOT','MTS','M','METER','METERS') THEN 'm'
                WHEN UPPER(TRIM(v_bc.uom)) IN ('M2','SQM','SQ_M') THEN 'm2'
                ELSE NULL
            END;
            IF v_uom IS NULL THEN CONTINUE; END IF;

            -- Cost calculation
            v_cfm := false;
            SELECT cim.total_cost INTO v_ucx FROM "CatalogItemsMSRP" cim
            WHERE cim.catalog_item_id = v_ci.id AND cim.organization_id = v_mo.organization_id
              AND cim.total_cost IS NOT NULL LIMIT 1;
            IF FOUND AND v_ucx IS NOT NULL THEN
                v_cfm := true;
            ELSE
                v_ucx := COALESCE(CAST(v_ci.cost_exw AS numeric(12,4)), 0);
            END IF;
            v_tcx := v_ucx * v_qty;
            IF v_ucx > 0 THEN
                DECLARE vc numeric(12,4); vm numeric(12,4);
                BEGIN
                    IF v_cfm THEN vc := v_ucx; ELSE vc := v_ucx * (1 + (v_sp / 100.0) + (v_ip / 100.0)); END IF;
                    vm := vc / (1 - (v_mm / 100.0));
                    v_um := vm / (1 - (v_md / 100.0));
                    v_tm := v_um * v_qty;
                END;
            ELSE
                v_um := 0;
                v_tm := 0;
            END IF;

            v_btc := v_btc + v_tcx;

            -- Calculate cut dimensions with cut_delta_mm
            v_cut_length := CASE
                WHEN v_bc.qty_type = 'per_width'
                     OR v_bc.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile')
                THEN COALESCE(v_sol.width_m, 0) * 1000.0 + COALESCE(v_bc.cut_delta_mm, 0)
                ELSE NULL
            END;
            v_cut_height := CASE
                WHEN v_bc.qty_type = 'per_height'
                     OR v_bc.component_role IN ('side_channel','side_channel_left','side_channel_right')
                THEN COALESCE(v_sol.height_m, 0) * 1000.0 + COALESCE(v_bc.cut_delta_mm, 0)
                ELSE NULL
            END;

            -- Remember parent cut dimensions for children
            v_parent_cut_length := v_cut_length;
            v_parent_cut_height := v_cut_height;

            -- Insert parent BOMInstanceLine
            INSERT INTO "BOMInstanceLines" (
                organization_id, bom_instance_id, resolved_part_id,
                part_role, qty, uom,
                unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                cut_length_mm, cut_height_mm,
                deleted, created_at, updated_at
            ) VALUES (
                v_mo.organization_id, v_bi_id, v_ci.id,
                v_bc.component_role, v_qty, v_uom,
                COALESCE(v_ucx, 0)::numeric(12,4), COALESCE(v_tcx, 0)::numeric(12,4),
                COALESCE(v_um, 0)::numeric(12,4), COALESCE(v_tm, 0)::numeric(12,4),
                v_cut_length, v_cut_height,
                false, now(), now()
            );
            v_cl := v_cl + 1;
            v_tbl := v_tbl + 1;

            -- Process CHILDREN of this parent component
            FOR v_child IN
                SELECT cc.id, cc.component_role, cc.component_item_id,
                       cc.qty_type, cc.qty_value, cc.uom,
                       cc.qty_spacing_mm, cc.qty_min, cc.cut_delta_mm,
                       cc.depends_on_role
                FROM "BOMComponents" cc
                WHERE cc.parent_component_id = v_bc.id
                  AND cc.deleted = false
                  AND cc.component_item_id IS NOT NULL
                ORDER BY cc.sort_order, cc.created_at
            LOOP
                -- Resolve child catalog item
                SELECT ci.id, ci.sku, ci.name, ci.description, ci.cost_exw
                INTO v_ci FROM "CatalogItems" ci
                WHERE ci.id = v_child.component_item_id
                  AND ci.organization_id = v_mo.organization_id
                  AND ci.is_active = true;
                IF NOT FOUND THEN
                    v_warn := v_warn || format('Child CatalogItem %s not found (parent comp %s)', v_child.component_item_id, v_bc.id);
                    CONTINUE;
                END IF;

                -- Calculate child quantity
                -- Children can use parent dimensions as reference
                IF v_child.qty_type = 'per_width' THEN
                    IF v_sol.width_m IS NULL THEN CONTINUE; END IF;
                    v_qty := v_sol.width_m * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_height' THEN
                    IF v_sol.height_m IS NULL THEN CONTINUE; END IF;
                    v_qty := v_sol.height_m * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_area' THEN
                    IF v_sol.width_m IS NULL OR v_sol.height_m IS NULL THEN CONTINUE; END IF;
                    v_qty := v_sol.width_m * v_sol.height_m * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_spacing' THEN
                    -- Use parent cut dimension as reference, fallback to SOL width
                    v_dim_mm := COALESCE(v_parent_cut_length, COALESCE(v_sol.width_m, 0) * 1000.0);
                    IF v_child.depends_on_role IS NOT NULL AND v_child.depends_on_role = 'height' THEN
                        v_dim_mm := COALESCE(v_parent_cut_height, COALESCE(v_sol.height_m, 0) * 1000.0);
                    END IF;
                    IF v_dim_mm IS NULL OR v_dim_mm <= 0 THEN CONTINUE; END IF;
                    v_qty := CEIL(v_dim_mm / COALESCE(v_child.qty_spacing_mm, 500));
                    IF v_child.qty_min IS NOT NULL AND v_qty < v_child.qty_min THEN
                        v_qty := v_child.qty_min;
                    END IF;
                ELSIF v_child.qty_type = 'fixed' THEN
                    v_qty := COALESCE(v_child.qty_value, 1);
                ELSE
                    CONTINUE;
                END IF;

                IF v_qty IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

                -- Normalize child UOM
                v_uom := CASE
                    WHEN UPPER(TRIM(v_child.uom)) IN ('PCS','PIECE','PIECES','SET','SETS','EA','EACH') THEN 'ea'
                    WHEN v_child.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile','chain')
                         OR UPPER(TRIM(v_child.uom)) IN ('FT','FEET','FOOT','MTS','M','METER','METERS') THEN 'm'
                    WHEN UPPER(TRIM(v_child.uom)) IN ('M2','SQM','SQ_M') THEN 'm2'
                    ELSE NULL
                END;
                IF v_uom IS NULL THEN CONTINUE; END IF;

                -- Child cost calculation
                v_cfm := false;
                SELECT cim.total_cost INTO v_ucx FROM "CatalogItemsMSRP" cim
                WHERE cim.catalog_item_id = v_ci.id AND cim.organization_id = v_mo.organization_id
                  AND cim.total_cost IS NOT NULL LIMIT 1;
                IF FOUND AND v_ucx IS NOT NULL THEN
                    v_cfm := true;
                ELSE
                    v_ucx := COALESCE(CAST(v_ci.cost_exw AS numeric(12,4)), 0);
                END IF;
                v_tcx := v_ucx * v_qty;
                IF v_ucx > 0 THEN
                    DECLARE vc numeric(12,4); vm numeric(12,4);
                    BEGIN
                        IF v_cfm THEN vc := v_ucx; ELSE vc := v_ucx * (1 + (v_sp / 100.0) + (v_ip / 100.0)); END IF;
                        vm := vc / (1 - (v_mm / 100.0));
                        v_um := vm / (1 - (v_md / 100.0));
                        v_tm := v_um * v_qty;
                    END;
                ELSE
                    v_um := 0;
                    v_tm := 0;
                END IF;

                v_btc := v_btc + v_tcx;

                -- Child cut dimensions
                v_cut_length := CASE
                    WHEN v_child.qty_type = 'per_width'
                         OR v_child.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile')
                    THEN COALESCE(v_sol.width_m, 0) * 1000.0 + COALESCE(v_child.cut_delta_mm, 0)
                    ELSE NULL
                END;
                v_cut_height := CASE
                    WHEN v_child.qty_type = 'per_height'
                         OR v_child.component_role IN ('side_channel','side_channel_left','side_channel_right','brush')
                    THEN COALESCE(v_sol.height_m, 0) * 1000.0 + COALESCE(v_child.cut_delta_mm, 0)
                    ELSE NULL
                END;

                -- Insert child BOMInstanceLine
                INSERT INTO "BOMInstanceLines" (
                    organization_id, bom_instance_id, resolved_part_id,
                    part_role, qty, uom,
                    unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                    cut_length_mm, cut_height_mm,
                    deleted, created_at, updated_at
                ) VALUES (
                    v_mo.organization_id, v_bi_id, v_ci.id,
                    v_child.component_role, v_qty, v_uom,
                    COALESCE(v_ucx, 0)::numeric(12,4), COALESCE(v_tcx, 0)::numeric(12,4),
                    COALESCE(v_um, 0)::numeric(12,4), COALESCE(v_tm, 0)::numeric(12,4),
                    v_cut_length, v_cut_height,
                    false, now(), now()
                );
                v_cl := v_cl + 1;
                v_tbl := v_tbl + 1;
            END LOOP; -- children

        END LOOP; -- parent components
    END LOOP; -- MO lines

    SELECT COUNT(*) INTO v_bia FROM public."BOMInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_bla FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    RETURN jsonb_build_object(
        'ok', array_length(v_err, 1) IS NULL OR array_length(v_err, 1) = 0,
        'manufacturing_order_id', p_manufacturing_order_id,
        'mo_lines_before', v_mlb,
        'mo_lines_after', v_mla,
        'mo_lines_created', v_cml,
        'mo_lines_processed', v_mlp,
        'bom_instances_before', v_bib,
        'bom_instances_after', v_bia,
        'bom_instances_created', v_bia - v_bib,
        'bom_instance_lines_before', v_blb,
        'bom_instance_lines_after', v_bla,
        'bom_instance_lines_created', v_bla - v_blb,
        'warnings', COALESCE(v_warn, ARRAY[]::text[]),
        'errors', COALESCE(v_err, ARRAY[]::text[])
    );
END;
$function$;
