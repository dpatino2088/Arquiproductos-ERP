/*
  Rewrite generate_bom_for_manufacturing_order to read materials
  from ConfiguredProduct.bom_preview_snapshot instead of recalculating
  from BOMComponents.

  The snapshot is the single source of truth — it stores the exact
  items, quantities, prices, and fabric consumption that the user
  confirmed in the Quote configurator.
*/
CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_mo              RECORD;
    v_mo_line         RECORD;
    v_sol             RECORD;
    v_cp              RECORD;
    v_bi_id           uuid;
    v_item            jsonb;
    v_child           jsonb;
    v_catalog_item_id uuid;
    v_role            text;
    v_qty             numeric;
    v_uom             text;
    v_ucx             numeric(12,4);
    v_tcx             numeric(12,4);
    v_um              numeric(12,4);
    v_tm              numeric(12,4);
    v_snapshot         jsonb;
    v_items           jsonb;
    v_totals          jsonb;
    v_fabric_calc     jsonb;

    v_mlb  integer := 0;   -- MO lines before
    v_mla  integer := 0;   -- MO lines after
    v_cml  integer := 0;   -- MO lines created
    v_mlp  integer := 0;   -- MO lines processed
    v_bib  integer := 0;   -- BOM instances before
    v_bia  integer := 0;   -- BOM instances after
    v_blb  integer := 0;   -- BOM instance lines before
    v_bla  integer := 0;   -- BOM instance lines after
    v_tbi  integer := 0;   -- total BOM instances created
    v_tbl  integer := 0;   -- total BOM instance lines created
    v_warn text[] := ARRAY[]::text[];
    v_err  text[] := ARRAY[]::text[];
BEGIN
    -- ── 1. Validate MO ──
    SELECT * INTO v_mo
    FROM public."ManufacturingOrders"
    WHERE id = p_manufacturing_order_id;

    IF v_mo.id IS NULL THEN
        RETURN jsonb_build_object('ok', false,
            'errors', ARRAY['MO not found'], 'warnings', ARRAY[]::text[]);
    END IF;
    IF v_mo.deleted = true THEN
        RETURN jsonb_build_object('ok', false,
            'errors', ARRAY['MO is deleted'], 'warnings', ARRAY[]::text[]);
    END IF;
    IF v_mo.sales_order_id IS NULL THEN
        v_warn := v_warn || 'MO has no sales_order_id';
    END IF;

    -- ── 2. Counts before ──
    SELECT COUNT(*) INTO v_mlb
    FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_bib
    FROM public."BOMInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_blb
    FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.deleted = false AND bil.deleted = false;

    -- ── 3. Auto-create MO lines from SO lines if none exist ──
    IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(
            manufacturing_order_id, sales_order_line_id,
            organization_id, status
        )
        SELECT p_manufacturing_order_id, sol.id,
               COALESCE(v_mo.organization_id, sol.organization_id), 'planned'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id
          AND COALESCE(sol.deleted, false) = false
          AND NOT EXISTS (
              SELECT 1 FROM public."ManufacturingOrderLines" m2
              WHERE m2.manufacturing_order_id = p_manufacturing_order_id
                AND m2.sales_order_line_id = sol.id
          );
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;

    SELECT COUNT(*) INTO v_mla
    FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    IF v_mla = 0 THEN
        RETURN jsonb_build_object(
            'ok', true,
            'mo_lines_before', v_mlb, 'mo_lines_after', v_mla,
            'mo_lines_created', v_cml,
            'bom_instances_before', v_bib, 'bom_instances_after', v_bib,
            'bom_instances_created', 0,
            'bom_instance_lines_before', v_blb,
            'bom_instance_lines_after', v_blb,
            'bom_instance_lines_created', 0,
            'warnings', v_warn, 'errors', v_err
        );
    END IF;

    -- ── 4. Process each MO line ──
    FOR v_mo_line IN
        SELECT mol.sales_order_line_id
        FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
          AND mol.deleted = false
        ORDER BY mol.created_at ASC
    LOOP
        v_mlp := v_mlp + 1;

        -- 4a. Get SaleOrderLine
        SELECT sol.id, sol.configured_product_id, sol.quote_line_id,
               sol.product_type, sol.width_m, sol.height_m
        INTO v_sol
        FROM "SaleOrderLines" sol
        WHERE sol.id = v_mo_line.sales_order_line_id
          AND sol.deleted = false;

        IF NOT FOUND THEN
            v_warn := v_warn || format('SaleOrderLine %s not found',
                v_mo_line.sales_order_line_id);
            CONTINUE;
        END IF;

        -- 4b. Get ConfiguredProduct with snapshot
        v_snapshot := NULL;
        IF v_sol.configured_product_id IS NOT NULL THEN
            SELECT cp.bom_preview_snapshot, cp.bom_template_id
            INTO v_cp
            FROM "ConfiguredProducts" cp
            WHERE cp.id = v_sol.configured_product_id
              AND cp.deleted = false;

            IF FOUND THEN
                v_snapshot := v_cp.bom_preview_snapshot;
            END IF;
        END IF;

        -- Fallback via QuoteLine if no direct configured_product_id
        IF v_snapshot IS NULL AND v_sol.quote_line_id IS NOT NULL THEN
            SELECT cp.bom_preview_snapshot, cp.bom_template_id
            INTO v_cp
            FROM "QuoteLines" ql
            JOIN "ConfiguredProducts" cp ON cp.id = ql.configured_product_id
            WHERE ql.id = v_sol.quote_line_id AND cp.deleted = false
            LIMIT 1;

            IF FOUND THEN
                v_snapshot := v_cp.bom_preview_snapshot;
            END IF;
        END IF;

        IF v_snapshot IS NULL OR v_snapshot = '{}'::jsonb THEN
            v_warn := v_warn || format(
                'No bom_preview_snapshot for SOL %s (configured_product_id=%s)',
                v_sol.id, v_sol.configured_product_id);
            CONTINUE;
        END IF;

        v_items       := v_snapshot->'items';
        v_totals      := v_snapshot->'totals';
        v_fabric_calc := v_totals->'fabric_calc';

        IF v_items IS NULL OR jsonb_typeof(v_items) != 'array'
           OR jsonb_array_length(v_items) = 0 THEN
            v_warn := v_warn || format('Empty snapshot items for SOL %s', v_sol.id);
            CONTINUE;
        END IF;

        -- 4c. Delete existing BOM instance lines and instances for this SOL
        UPDATE "BOMInstanceLines" bil SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id IN (
            SELECT bi.id FROM "BOMInstances" bi
            WHERE bi.manufacturing_order_id = p_manufacturing_order_id
              AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false
        );

        UPDATE "BOMInstances" bi SET deleted = true, updated_at = now()
        WHERE bi.manufacturing_order_id = p_manufacturing_order_id
          AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false;

        -- 4d. Create new BOM instance
        INSERT INTO "BOMInstances" (
            organization_id, manufacturing_order_id, sales_order_line_id,
            quote_line_id, bom_template_id, deleted, created_at, updated_at
        ) VALUES (
            v_mo.organization_id, p_manufacturing_order_id, v_sol.id,
            v_sol.quote_line_id,
            (v_snapshot->>'bom_template_id')::uuid,
            false, now(), now()
        ) RETURNING id INTO v_bi_id;

        IF v_bi_id IS NULL THEN CONTINUE; END IF;
        v_tbi := v_tbi + 1;

        -- 4e. Iterate snapshot items (parents)
        FOR v_item IN SELECT value FROM jsonb_array_elements(v_items)
        LOOP
            v_catalog_item_id := (v_item->>'catalog_item_id')::uuid;
            v_role            := v_item->>'role';
            v_qty             := COALESCE((v_item->>'qty')::numeric, 0);
            v_uom             := COALESCE(v_item->>'uom', 'ea');

            IF v_catalog_item_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

            -- Resolve costs: try CatalogItemsMSRP.total_cost first, fallback to cost_exw
            SELECT COALESCE(cim.total_cost, ci.cost_exw::numeric(12,4), 0)
            INTO v_ucx
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemsMSRP" cim
              ON cim.catalog_item_id = ci.id
              AND cim.organization_id = v_mo.organization_id
            WHERE ci.id = v_catalog_item_id
            LIMIT 1;

            IF NOT FOUND THEN v_ucx := 0; END IF;

            v_tcx := v_ucx * v_qty;
            v_um  := COALESCE((v_item->>'unit_price')::numeric(12,4), 0);
            v_tm  := COALESCE((v_item->>'line_total')::numeric(12,4), 0);

            INSERT INTO "BOMInstanceLines" (
                organization_id, bom_instance_id, resolved_part_id,
                part_role, qty, uom,
                unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                cut_length_mm, cut_height_mm,
                deleted, created_at, updated_at
            ) VALUES (
                v_mo.organization_id, v_bi_id, v_catalog_item_id,
                v_role, v_qty, v_uom,
                COALESCE(v_ucx, 0), COALESCE(v_tcx, 0),
                COALESCE(v_um, 0), COALESCE(v_tm, 0),
                CASE
                    WHEN v_role = 'fabric' AND v_fabric_calc IS NOT NULL
                        THEN (v_fabric_calc->>'fabric_cut_width_mm')::numeric
                    WHEN v_uom = 'm' THEN v_qty * 1000.0
                    ELSE NULL
                END,
                CASE
                    WHEN v_role = 'fabric' AND v_fabric_calc IS NOT NULL
                        THEN (v_fabric_calc->>'fabric_cut_height_mm')::numeric
                    ELSE NULL
                END,
                false, now(), now()
            );
            v_tbl := v_tbl + 1;

            -- 4f. Iterate children of this item
            IF v_item->'children' IS NOT NULL
               AND jsonb_typeof(v_item->'children') = 'array'
               AND jsonb_array_length(v_item->'children') > 0 THEN

                FOR v_child IN SELECT value FROM jsonb_array_elements(v_item->'children')
                LOOP
                    v_catalog_item_id := (v_child->>'catalog_item_id')::uuid;
                    v_role            := v_child->>'role';
                    v_qty             := COALESCE((v_child->>'qty')::numeric, 0);
                    v_uom             := COALESCE(v_child->>'uom', 'ea');

                    IF v_catalog_item_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

                    SELECT COALESCE(cim.total_cost, ci.cost_exw::numeric(12,4), 0)
                    INTO v_ucx
                    FROM "CatalogItems" ci
                    LEFT JOIN "CatalogItemsMSRP" cim
                      ON cim.catalog_item_id = ci.id
                      AND cim.organization_id = v_mo.organization_id
                    WHERE ci.id = v_catalog_item_id
                    LIMIT 1;

                    IF NOT FOUND THEN v_ucx := 0; END IF;

                    v_tcx := v_ucx * v_qty;
                    v_um  := COALESCE((v_child->>'unit_price')::numeric(12,4), 0);
                    v_tm  := COALESCE((v_child->>'line_total')::numeric(12,4), 0);

                    INSERT INTO "BOMInstanceLines" (
                        organization_id, bom_instance_id, resolved_part_id,
                        part_role, qty, uom,
                        unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                        cut_length_mm, cut_height_mm,
                        deleted, created_at, updated_at
                    ) VALUES (
                        v_mo.organization_id, v_bi_id, v_catalog_item_id,
                        v_role, v_qty, v_uom,
                        COALESCE(v_ucx, 0), COALESCE(v_tcx, 0),
                        COALESCE(v_um, 0), COALESCE(v_tm, 0),
                        CASE WHEN v_uom = 'm' THEN v_qty * 1000.0 ELSE NULL END,
                        NULL,
                        false, now(), now()
                    );
                    v_tbl := v_tbl + 1;
                END LOOP;
            END IF;
        END LOOP;
    END LOOP;

    -- ── 5. Counts after ──
    SELECT COUNT(*) INTO v_bia
    FROM public."BOMInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_bla
    FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.deleted = false AND bil.deleted = false;

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
$$;
