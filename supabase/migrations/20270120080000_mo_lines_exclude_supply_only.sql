-- ManufacturingOrderLines must only list manufacture items.
-- Catalog / custom / supply_only lines stay on the Sales Order (Procurement), not on the MO.

SET search_path = public;

-- 1) Soft-delete existing supply_only MOLs (and their empty BOMInstances, if any)
UPDATE public."BOMInstanceLines" bil
SET deleted = true, updated_at = now()
WHERE bil.deleted = false
  AND bil.bom_instance_id IN (
    SELECT bi.id
    FROM public."BOMInstances" bi
    JOIN public."ManufacturingOrderLines" mol ON mol.id = bi.manufacturing_order_line_id
    JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
    JOIN public."ProductTypes" pt
      ON pt.code = sol.product_type AND pt.organization_id = sol.organization_id
    WHERE mol.deleted = false
      AND pt.fulfillment_type = 'supply_only'
  );

UPDATE public."BOMInstances" bi
SET deleted = true, updated_at = now()
WHERE bi.deleted = false
  AND bi.manufacturing_order_line_id IN (
    SELECT mol.id
    FROM public."ManufacturingOrderLines" mol
    JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
    JOIN public."ProductTypes" pt
      ON pt.code = sol.product_type AND pt.organization_id = sol.organization_id
    WHERE mol.deleted = false
      AND pt.fulfillment_type = 'supply_only'
  );

UPDATE public."ManufacturingOrderLines" mol
SET deleted = true, updated_at = now()
FROM public."SaleOrderLines" sol
JOIN public."ProductTypes" pt
  ON pt.code = sol.product_type AND pt.organization_id = sol.organization_id
WHERE mol.sales_order_line_id = sol.id
  AND mol.deleted = false
  AND pt.fulfillment_type = 'supply_only';

-- 2) Patch generate_bom: never seed supply_only MOLs; retire any that appear
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

  -- Replace seed INSERT: manufacture only, 1 row per sold unit
  v_old := $old$IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
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
          1,
          gs.unit_index
        FROM public."SaleOrderLines" sol
        LEFT JOIN public."ProductTypes" pt
          ON pt.code = sol.product_type
         AND pt.organization_id = COALESCE(v_mo.organization_id, sol.organization_id)
        CROSS JOIN LATERAL generate_series(
          1,
          GREATEST(1, CEIL(COALESCE(sol.quantity, 1))::int)
        ) AS gs(unit_index)
        WHERE sol.sales_order_id = v_mo.sales_order_id
          AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND COALESCE(pt.fulfillment_type, 'manufacture') <> 'supply_only'
          AND NOT EXISTS (
            SELECT 1 FROM public."ManufacturingOrderLines" m2
            WHERE m2.manufacturing_order_id = p_manufacturing_order_id
              AND m2.sales_order_line_id = sol.id
              AND m2.unit_index = gs.unit_index
              AND m2.deleted = false
          );
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;

    -- Always retire supply_only MOLs (catalog / custom) — Procurement owns them
    UPDATE public."BOMInstanceLines" bil
    SET deleted = true, updated_at = now()
    WHERE bil.deleted = false
      AND bil.bom_instance_id IN (
        SELECT bi.id
        FROM public."BOMInstances" bi
        JOIN public."ManufacturingOrderLines" mol ON mol.id = bi.manufacturing_order_line_id
        JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
        JOIN public."ProductTypes" pt
          ON pt.code = sol.product_type
         AND pt.organization_id = COALESCE(v_mo.organization_id, sol.organization_id)
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
          AND mol.deleted = false
          AND pt.fulfillment_type = 'supply_only'
      );

    UPDATE public."BOMInstances" bi
    SET deleted = true, updated_at = now()
    WHERE bi.deleted = false
      AND bi.manufacturing_order_line_id IN (
        SELECT mol.id
        FROM public."ManufacturingOrderLines" mol
        JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
        JOIN public."ProductTypes" pt
          ON pt.code = sol.product_type
         AND pt.organization_id = COALESCE(v_mo.organization_id, sol.organization_id)
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
          AND mol.deleted = false
          AND pt.fulfillment_type = 'supply_only'
      );

    UPDATE public."ManufacturingOrderLines" mol
    SET deleted = true, updated_at = now()
    FROM public."SaleOrderLines" sol
    JOIN public."ProductTypes" pt
      ON pt.code = sol.product_type
     AND pt.organization_id = COALESCE(v_mo.organization_id, sol.organization_id)
    WHERE mol.manufacturing_order_id = p_manufacturing_order_id
      AND mol.sales_order_line_id = sol.id
      AND mol.deleted = false
      AND pt.fulfillment_type = 'supply_only';$new$;

  IF position(v_old IN v_def) = 0 THEN
    RAISE EXCEPTION 'Could not locate MOL seed block to exclude supply_only';
  END IF;
  v_def := replace(v_def, v_old, v_new);

  EXECUTE v_def;
END;
$patch$;
