-- Patch generate_bom_for_manufacturing_order for 1 MOL + 1 BOMInstance per sold unit.

DO $patch$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'generate_bom_for_manufacturing_order';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'generate_bom_for_manufacturing_order not found';
  END IF;

  -- 1) MOL seed: unit-split for manufacture; single row for supply_only
  v_old := $old$IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status, quantity)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'draft', COALESCE(sol.quantity, 1)
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND NOT EXISTS (SELECT 1 FROM public."ManufacturingOrderLines" m2 WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id);
        GET DIAGNOSTICS v_cml = ROW_COUNT;

        -- Keep MOL.quantity aligned with SOL units (BOM is still 1 instance per SOL).
        UPDATE public."ManufacturingOrderLines" mol
        SET quantity = COALESCE(sol.quantity, 1),
            updated_at = now()
        FROM public."SaleOrderLines" sol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
          AND mol.sales_order_line_id = sol.id
          AND mol.deleted = false
          AND COALESCE(mol.quantity, 1) IS DISTINCT FROM COALESCE(sol.quantity, 1);
    END IF;$old$;

  v_new := $new$IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(
          manufacturing_order_id, sales_order_line_id, organization_id, status, quantity, unit_index
        )
        SELECT
          p_manufacturing_order_id,
          sol.id,
          COALESCE(v_mo.organization_id, sol.organization_id),
          'draft',
          CASE
            WHEN COALESCE(pt.fulfillment_type, 'manufacture') = 'supply_only'
              THEN COALESCE(sol.quantity, 1)
            ELSE 1
          END,
          gs.unit_index
        FROM public."SaleOrderLines" sol
        LEFT JOIN public."ProductTypes" pt
          ON pt.code = sol.product_type
         AND pt.organization_id = COALESCE(v_mo.organization_id, sol.organization_id)
        CROSS JOIN LATERAL generate_series(
          1,
          CASE
            WHEN COALESCE(pt.fulfillment_type, 'manufacture') = 'supply_only'
              THEN 1
            ELSE GREATEST(1, CEIL(COALESCE(sol.quantity, 1))::int)
          END
        ) AS gs(unit_index)
        WHERE sol.sales_order_id = v_mo.sales_order_id
          AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND NOT EXISTS (
            SELECT 1 FROM public."ManufacturingOrderLines" m2
            WHERE m2.manufacturing_order_id = p_manufacturing_order_id
              AND m2.sales_order_line_id = sol.id
              AND m2.unit_index = gs.unit_index
              AND m2.deleted = false
          );
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;$new$;

  IF position(v_old IN v_def) = 0 THEN
    RAISE EXCEPTION 'Could not locate MOL seed block in generate_bom_for_manufacturing_order';
  END IF;
  v_def := replace(v_def, v_old, v_new);

  -- 2) Loop over MOL id + SOL
  v_old := $old$FOR v_mo_line IN SELECT mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false ORDER BY mol.created_at ASC$old$;
  v_new := $new$FOR v_mo_line IN SELECT mol.id, mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false ORDER BY mol.created_at ASC, mol.unit_index ASC$new$;
  IF position(v_old IN v_def) = 0 THEN
    RAISE EXCEPTION 'Could not locate MOL loop in generate_bom_for_manufacturing_order';
  END IF;
  v_def := replace(v_def, v_old, v_new);

  -- 3) Soft-delete BI/BIL scoped to this MOL (not entire SOL)
  v_old := $old$UPDATE public."BOMInstanceLines" bil SET deleted = true, updated_at = now() WHERE bil.bom_instance_id IN (SELECT bi.id FROM public."BOMInstances" bi WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false);
        UPDATE public."BOMInstances" bi SET deleted = true, updated_at = now() WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false;
        INSERT INTO public."BOMInstances" (organization_id, manufacturing_order_id, sales_order_line_id, quote_line_id, bom_template_id, deleted, created_at, updated_at) VALUES (v_mo.organization_id, p_manufacturing_order_id, v_sol.id, v_sol.quote_line_id, (v_snapshot->>'bom_template_id')::uuid, false, now(), now()) RETURNING id INTO v_bi_id;$old$;

  v_new := $new$UPDATE public."BOMInstanceLines" bil SET deleted = true, updated_at = now() WHERE bil.bom_instance_id IN (SELECT bi.id FROM public."BOMInstances" bi WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.manufacturing_order_line_id = v_mo_line.id AND bi.deleted = false);
        UPDATE public."BOMInstances" bi SET deleted = true, updated_at = now() WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.manufacturing_order_line_id = v_mo_line.id AND bi.deleted = false;
        -- Legacy rows linked only by SOL (pre unit-split): retire when regenerating unit 1
        IF COALESCE((SELECT unit_index FROM public."ManufacturingOrderLines" WHERE id = v_mo_line.id), 1) = 1 THEN
          UPDATE public."BOMInstanceLines" bil SET deleted = true, updated_at = now()
          WHERE bil.bom_instance_id IN (
            SELECT bi.id FROM public."BOMInstances" bi
            WHERE bi.manufacturing_order_id = p_manufacturing_order_id
              AND bi.sales_order_line_id = v_sol.id
              AND bi.manufacturing_order_line_id IS NULL
              AND bi.deleted = false
          );
          UPDATE public."BOMInstances" bi SET deleted = true, updated_at = now()
          WHERE bi.manufacturing_order_id = p_manufacturing_order_id
            AND bi.sales_order_line_id = v_sol.id
            AND bi.manufacturing_order_line_id IS NULL
            AND bi.deleted = false;
        END IF;
        INSERT INTO public."BOMInstances" (organization_id, manufacturing_order_id, sales_order_line_id, manufacturing_order_line_id, quote_line_id, bom_template_id, deleted, created_at, updated_at) VALUES (v_mo.organization_id, p_manufacturing_order_id, v_sol.id, v_mo_line.id, v_sol.quote_line_id, (v_snapshot->>'bom_template_id')::uuid, false, now(), now()) RETURNING id INTO v_bi_id;$new$;

  IF position(v_old IN v_def) = 0 THEN
    RAISE EXCEPTION 'Could not locate BOMInstance insert block in generate_bom_for_manufacturing_order';
  END IF;
  v_def := replace(v_def, v_old, v_new);

  EXECUTE v_def;
END;
$patch$;
