-- =====================================================================
-- generate_bom_for_manufacturing_order: unify production cut geometry
-- onto the canonical engine + add safety guardrails.
--
-- Changes vs previous version:
--   1) STATUS GUARDRAIL (Option B): if the MO is already past pre-production
--      (in_production / completed / cancelled / quality_check /
--       ready_for_pickup / delivered) AND it already has a BOM, do NOT touch
--      it. Pre-production MOs (draft / confirmed / procurement /
--      material_available / materials_ready / planned) regenerate freely.
--
--   2) GENERIC PER-PANEL SPLIT: instead of only tube + bottom_bar, split every
--      width-axis profile role that compute_system_dimensions (now backed by
--      compute_cut_breakdown_core) resolved per panel.
--
--   3) COST RECONCILIATION: a role is only split into per-panel lines when the
--      panel geometry (Σ panel cuts) reconciles with the length already priced
--      in the snapshot (the audited v_resolved_cuts cascade). If they diverge
--      beyond tolerance the single line is kept (cost stays frozen and equal to
--      the quote) and a warning is emitted. This guarantees production cost
--      always closes with the dealer quote, while geometry follows the core.
--
-- Fabric handling and the snapshot-driven cost flow are unchanged.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_mo RECORD; v_mo_line RECORD; v_sol RECORD; v_cp RECORD;
    v_bi_id uuid; v_item jsonb; v_child jsonb;
    v_catalog_item_id uuid; v_role text; v_qty numeric; v_uom text;
    v_ucx numeric(12,4); v_tcx numeric(12,4); v_um numeric(12,4); v_tm numeric(12,4);
    v_snapshot jsonb; v_items jsonb; v_totals jsonb; v_fabric_calc jsonb;
    v_dim_outputs jsonb; v_panel_cuts_key text; v_panel_cuts jsonb; v_pc jsonb;
    v_panel_cut_mm numeric; v_panel_idx integer; v_src_line RECORD;
    v_unit_cost_per_m numeric(12,6); v_unit_msrp_per_m numeric(12,6);
    v_fulfillment text;
    v_sum_m numeric; v_recon_tol numeric;
    v_mlb integer := 0; v_mla integer := 0; v_cml integer := 0; v_mlp integer := 0;
    v_bib integer := 0; v_bia integer := 0; v_blb integer := 0; v_bla integer := 0;
    v_tbi integer := 0; v_tbl integer := 0;
    v_supply_skipped integer := 0; v_recon_skips integer := 0;
    v_warn text[] := ARRAY[]::text[]; v_err text[] := ARRAY[]::text[];
BEGIN
    SELECT * INTO v_mo FROM public."ManufacturingOrders" WHERE id = p_manufacturing_order_id;
    IF v_mo.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO not found'], 'warnings', ARRAY[]::text[]); END IF;
    IF v_mo.deleted = true THEN RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO is deleted'], 'warnings', ARRAY[]::text[]); END IF;
    IF v_mo.sales_order_id IS NULL THEN v_warn := v_warn || 'MO has no sales_order_id'; END IF;

    SELECT COUNT(*) INTO v_mlb FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bib FROM public."BOMInstances" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_blb FROM public."BOMInstanceLines" bil JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    -- GUARDRAIL: never re-cut a MO that already left pre-production.
    IF v_mo.status IN ('in_production','completed','cancelled','quality_check','ready_for_pickup','delivered')
       AND v_bib > 0 THEN
        RETURN jsonb_build_object(
            'ok', true,
            'skipped', 'mo_frozen',
            'manufacturing_order_id', p_manufacturing_order_id,
            'status', v_mo.status::text,
            'bom_instances_after', v_bib,
            'bom_instance_lines_after', v_blb,
            'warnings', v_warn || format('MO status %s is frozen; BOM not regenerated', v_mo.status),
            'errors', ARRAY[]::text[]
        );
    END IF;

    IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'draft'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id
          AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND NOT EXISTS (SELECT 1 FROM public."ManufacturingOrderLines" m2 WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id);
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;

    SELECT COUNT(*) INTO v_mla FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    IF v_mla = 0 THEN
        RETURN jsonb_build_object('ok', true, 'mo_lines_before', v_mlb, 'mo_lines_after', v_mla, 'mo_lines_created', v_cml, 'bom_instances_before', v_bib, 'bom_instances_after', v_bib, 'bom_instances_created', 0, 'bom_instance_lines_before', v_blb, 'bom_instance_lines_after', v_blb, 'bom_instance_lines_created', 0, 'warnings', v_warn, 'errors', v_err);
    END IF;

    FOR v_mo_line IN
        SELECT mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false ORDER BY mol.created_at ASC
    LOOP
        v_mlp := v_mlp + 1;
        v_dim_outputs := '{}'::jsonb;

        SELECT sol.id, sol.configured_product_id, sol.quote_line_id, sol.product_type, sol.width_m, sol.height_m
        INTO v_sol FROM public."SaleOrderLines" sol WHERE sol.id = v_mo_line.sales_order_line_id AND sol.deleted = false;
        IF NOT FOUND THEN v_warn := v_warn || format('SaleOrderLine %s not found', v_mo_line.sales_order_line_id); CONTINUE; END IF;

        SELECT COALESCE(pt.fulfillment_type, 'manufacture') INTO v_fulfillment
        FROM public."ProductTypes" pt
        WHERE pt.code = v_sol.product_type
          AND pt.organization_id = v_mo.organization_id
        LIMIT 1;

        IF v_fulfillment = 'supply_only' THEN
            v_supply_skipped := v_supply_skipped + 1;
            CONTINUE;
        END IF;

        v_snapshot := NULL;
        IF v_sol.configured_product_id IS NOT NULL THEN
            SELECT cp.bom_preview_snapshot, cp.bom_template_id INTO v_cp
            FROM public."ConfiguredProducts" cp WHERE cp.id = v_sol.configured_product_id AND cp.deleted = false;
            IF FOUND THEN v_snapshot := v_cp.bom_preview_snapshot; END IF;
        END IF;

        IF v_snapshot IS NULL AND v_sol.quote_line_id IS NOT NULL THEN
            SELECT cp.bom_preview_snapshot, cp.bom_template_id INTO v_cp
            FROM public."QuoteLines" ql JOIN public."ConfiguredProducts" cp ON cp.id = ql.configured_product_id
            WHERE ql.id = v_sol.quote_line_id AND cp.deleted = false LIMIT 1;
            IF FOUND THEN v_snapshot := v_cp.bom_preview_snapshot; END IF;
        END IF;

        IF v_snapshot IS NULL OR v_snapshot = '{}'::jsonb THEN
            v_warn := v_warn || format('No bom_preview_snapshot for SOL %s (configured_product_id=%s)', v_sol.id, v_sol.configured_product_id);
            CONTINUE;
        END IF;

        IF v_sol.configured_product_id IS NOT NULL THEN
            BEGIN v_dim_outputs := COALESCE(public.compute_system_dimensions(v_sol.configured_product_id), '{}'::jsonb);
            EXCEPTION WHEN OTHERS THEN v_dim_outputs := '{}'::jsonb; END;
        END IF;

        v_items       := v_snapshot->'items';
        v_totals      := v_snapshot->'totals';
        v_fabric_calc := v_totals->'fabric_calc';

        IF v_items IS NULL OR jsonb_typeof(v_items) != 'array' OR jsonb_array_length(v_items) = 0 THEN
            v_warn := v_warn || format('Empty snapshot items for SOL %s', v_sol.id);
            CONTINUE;
        END IF;

        UPDATE public."BOMInstanceLines" bil SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id IN (
            SELECT bi.id FROM public."BOMInstances" bi
            WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false
        );
        UPDATE public."BOMInstances" bi SET deleted = true, updated_at = now()
        WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false;

        INSERT INTO public."BOMInstances" (
            organization_id, manufacturing_order_id, sales_order_line_id,
            quote_line_id, bom_template_id, deleted, created_at, updated_at
        ) VALUES (
            v_mo.organization_id, p_manufacturing_order_id, v_sol.id,
            v_sol.quote_line_id, (v_snapshot->>'bom_template_id')::uuid,
            false, now(), now()
        ) RETURNING id INTO v_bi_id;
        IF v_bi_id IS NULL THEN CONTINUE; END IF;
        v_tbi := v_tbi + 1;

        FOR v_item IN SELECT value FROM jsonb_array_elements(v_items)
        LOOP
            v_catalog_item_id := (v_item->>'catalog_item_id')::uuid;
            v_role            := v_item->>'role';
            v_qty             := COALESCE((v_item->>'qty')::numeric, 0);
            v_uom             := COALESCE(v_item->>'uom', 'ea');
            IF v_catalog_item_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

            SELECT COALESCE(cim.total_cost, ci.cost_exw::numeric(12,4), 0) INTO v_ucx
            FROM public."CatalogItems" ci LEFT JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id AND cim.organization_id = v_mo.organization_id
            WHERE ci.id = v_catalog_item_id LIMIT 1;
            IF NOT FOUND THEN v_ucx := 0; END IF;

            v_tcx := v_ucx * v_qty;
            v_um  := COALESCE((v_item->>'unit_price')::numeric(12,4), 0);
            v_tm  := COALESCE((v_item->>'line_total')::numeric(12,4), 0);

            INSERT INTO public."BOMInstanceLines" (
                organization_id, bom_instance_id, resolved_part_id,
                part_role, qty, uom,
                unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                cut_length_mm, cut_height_mm,
                deleted, created_at, updated_at
            ) VALUES (
                v_mo.organization_id, v_bi_id, v_catalog_item_id,
                v_role, v_qty, v_uom,
                COALESCE(v_ucx, 0), COALESCE(v_tcx, 0), COALESCE(v_um, 0), COALESCE(v_tm, 0),
                CASE WHEN v_role = 'fabric' AND v_fabric_calc IS NOT NULL THEN (v_fabric_calc->>'fabric_cut_width_mm')::numeric
                     WHEN v_uom = 'm' THEN v_qty * 1000.0 ELSE NULL END,
                CASE WHEN v_role = 'fabric' AND v_fabric_calc IS NOT NULL THEN (v_fabric_calc->>'fabric_cut_height_mm')::numeric
                     ELSE NULL END,
                false, now(), now()
            );
            v_tbl := v_tbl + 1;

            IF v_item->'children' IS NOT NULL AND jsonb_typeof(v_item->'children') = 'array' AND jsonb_array_length(v_item->'children') > 0 THEN
                FOR v_child IN SELECT value FROM jsonb_array_elements(v_item->'children')
                LOOP
                    v_catalog_item_id := (v_child->>'catalog_item_id')::uuid;
                    v_role            := v_child->>'role';
                    v_qty             := COALESCE((v_child->>'qty')::numeric, 0);
                    v_uom             := COALESCE(v_child->>'uom', 'ea');
                    IF v_catalog_item_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

                    SELECT COALESCE(cim.total_cost, ci.cost_exw::numeric(12,4), 0) INTO v_ucx
                    FROM public."CatalogItems" ci LEFT JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id AND cim.organization_id = v_mo.organization_id
                    WHERE ci.id = v_catalog_item_id LIMIT 1;
                    IF NOT FOUND THEN v_ucx := 0; END IF;

                    v_tcx := v_ucx * v_qty;
                    v_um  := COALESCE((v_child->>'unit_price')::numeric(12,4), 0);
                    v_tm  := COALESCE((v_child->>'line_total')::numeric(12,4), 0);

                    INSERT INTO public."BOMInstanceLines" (
                        organization_id, bom_instance_id, resolved_part_id,
                        part_role, qty, uom,
                        unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                        cut_length_mm, cut_height_mm,
                        deleted, created_at, updated_at
                    ) VALUES (
                        v_mo.organization_id, v_bi_id, v_catalog_item_id,
                        v_role, v_qty, v_uom,
                        COALESCE(v_ucx, 0), COALESCE(v_tcx, 0), COALESCE(v_um, 0), COALESCE(v_tm, 0),
                        CASE WHEN v_uom = 'm' THEN v_qty * 1000.0 ELSE NULL END, NULL,
                        false, now(), now()
                    );
                    v_tbl := v_tbl + 1;
                END LOOP;
            END IF;
        END LOOP;

        -- ---- Per-panel split for every width-axis profile resolved by the core ----
        -- (tube, bottom_bar, and any other role the canonical engine cut per panel).
        -- Only applied when the panel geometry reconciles with the priced length so
        -- the production cost stays equal to the quote sent to the dealer.
        FOR v_role IN
            SELECT replace(k, '_panel_cuts', '')
            FROM jsonb_object_keys(v_dim_outputs) AS k
            WHERE k LIKE '%\_panel\_cuts'
        LOOP
            v_panel_cuts_key := v_role || '_panel_cuts';
            v_panel_cuts := v_dim_outputs->v_panel_cuts_key;
            IF v_panel_cuts IS NULL OR jsonb_typeof(v_panel_cuts) <> 'array' OR jsonb_array_length(v_panel_cuts) <= 1 THEN
                CONTINUE;
            END IF;

            SELECT COALESCE(SUM((pc->>(v_role || '_width_mm'))::numeric), 0) / 1000.0
              INTO v_sum_m
            FROM jsonb_array_elements(v_panel_cuts) AS pc;

            FOR v_src_line IN
                SELECT * FROM public."BOMInstanceLines"
                WHERE bom_instance_id = v_bi_id AND part_role = v_role AND deleted = false AND COALESCE(uom,'') = 'm'
            LOOP
                v_recon_tol := GREATEST(0.01, ABS(COALESCE(v_src_line.qty, 0)) * 0.01);
                IF ABS(v_sum_m - COALESCE(v_src_line.qty, 0)) > v_recon_tol THEN
                    v_recon_skips := v_recon_skips + 1;
                    v_warn := v_warn || format(
                        'Role %s: panel geometry %sm <> quoted %sm (SOL %s); kept single line, cost frozen',
                        v_role, round(v_sum_m, 3), round(COALESCE(v_src_line.qty, 0), 3), v_sol.id);
                    CONTINUE;
                END IF;

                v_unit_cost_per_m := CASE WHEN COALESCE(v_src_line.qty, 0) > 0 THEN COALESCE(v_src_line.total_cost_exw, 0) / v_src_line.qty ELSE COALESCE(v_src_line.unit_cost_exw, 0) END;
                v_unit_msrp_per_m := CASE WHEN COALESCE(v_src_line.qty, 0) > 0 THEN COALESCE(v_src_line.total_msrp, 0) / v_src_line.qty ELSE COALESCE(v_src_line.unit_msrp, 0) END;
                UPDATE public."BOMInstanceLines" SET deleted = true, updated_at = now() WHERE id = v_src_line.id;
                FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
                    v_panel_idx := (v_pc->>'index')::integer;
                    v_panel_cut_mm := COALESCE((v_pc->>(v_role || '_width_mm'))::numeric, 0);
                    IF v_panel_cut_mm <= 0 THEN CONTINUE; END IF;
                    v_qty := ROUND(v_panel_cut_mm / 1000.0, 4);
                    v_tcx := ROUND(v_unit_cost_per_m * v_qty, 4);
                    v_tm  := ROUND(v_unit_msrp_per_m * v_qty, 4);
                    INSERT INTO public."BOMInstanceLines" (
                        organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom,
                        unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                        cut_length_mm, cut_height_mm, panel_index, deleted, created_at, updated_at
                    ) VALUES (
                        v_src_line.organization_id, v_src_line.bom_instance_id, v_src_line.resolved_part_id,
                        v_src_line.part_role, v_qty, v_src_line.uom,
                        ROUND(v_unit_cost_per_m, 4), v_tcx, ROUND(v_unit_msrp_per_m, 4), v_tm,
                        ROUND(v_panel_cut_mm, 1), NULL, v_panel_idx, false, now(), now()
                    );
                    v_tbl := v_tbl + 1;
                END LOOP;
            END LOOP;
        END LOOP;

        -- ---- Fabric per-panel split (proportional to tube panel cuts) ----
        v_panel_cuts := v_dim_outputs->'tube_panel_cuts';
        IF v_panel_cuts IS NOT NULL AND jsonb_typeof(v_panel_cuts) = 'array' AND jsonb_array_length(v_panel_cuts) > 1 THEN
            FOR v_src_line IN SELECT * FROM public."BOMInstanceLines" WHERE bom_instance_id = v_bi_id AND part_role = 'fabric' AND deleted = false
            LOOP
                IF COALESCE(v_src_line.uom, '') <> 'm' THEN CONTINUE; END IF;
                v_unit_cost_per_m := CASE WHEN COALESCE(v_src_line.qty, 0) > 0 THEN COALESCE(v_src_line.total_cost_exw, 0) / v_src_line.qty ELSE COALESCE(v_src_line.unit_cost_exw, 0) END;
                v_unit_msrp_per_m := CASE WHEN COALESCE(v_src_line.qty, 0) > 0 THEN COALESCE(v_src_line.total_msrp, 0) / v_src_line.qty ELSE COALESCE(v_src_line.unit_msrp, 0) END;
                UPDATE public."BOMInstanceLines" SET deleted = true, updated_at = now() WHERE id = v_src_line.id;
                FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
                    v_panel_idx := (v_pc->>'index')::integer;
                    v_panel_cut_mm := COALESCE((v_pc->>'tube_width_mm')::numeric, 0);
                    IF v_panel_cut_mm <= 0 THEN CONTINUE; END IF;
                    v_qty := ROUND(v_panel_cut_mm / 1000.0, 4);
                    v_tcx := ROUND(v_unit_cost_per_m * v_qty, 4);
                    v_tm  := ROUND(v_unit_msrp_per_m * v_qty, 4);
                    INSERT INTO public."BOMInstanceLines" (
                        organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom,
                        unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                        cut_length_mm, cut_height_mm, panel_index, deleted, created_at, updated_at
                    ) VALUES (
                        v_src_line.organization_id, v_src_line.bom_instance_id, v_src_line.resolved_part_id,
                        v_src_line.part_role, v_qty, v_src_line.uom,
                        ROUND(v_unit_cost_per_m, 4), v_tcx, ROUND(v_unit_msrp_per_m, 4), v_tm,
                        ROUND(v_panel_cut_mm, 1), v_src_line.cut_height_mm, v_panel_idx, false, now(), now()
                    );
                    v_tbl := v_tbl + 1;
                END LOOP;
            END LOOP;
        END IF;

    END LOOP;

    SELECT COUNT(*) INTO v_bia FROM public."BOMInstances" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bla FROM public."BOMInstanceLines" bil JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    RETURN jsonb_build_object(
        'ok', array_length(v_err, 1) IS NULL OR array_length(v_err, 1) = 0,
        'manufacturing_order_id', p_manufacturing_order_id,
        'status', v_mo.status::text,
        'mo_lines_before', v_mlb, 'mo_lines_after', v_mla,
        'mo_lines_created', v_cml, 'mo_lines_processed', v_mlp,
        'supply_only_skipped', v_supply_skipped,
        'reconciliation_skips', v_recon_skips,
        'bom_instances_before', v_bib, 'bom_instances_after', v_bia,
        'bom_instances_created', v_bia - v_bib,
        'bom_instance_lines_before', v_blb, 'bom_instance_lines_after', v_bla,
        'bom_instance_lines_created', v_bla - v_blb,
        'warnings', COALESCE(v_warn, ARRAY[]::text[]),
        'errors', COALESCE(v_err, ARRAY[]::text[])
    );
END;
$function$;
