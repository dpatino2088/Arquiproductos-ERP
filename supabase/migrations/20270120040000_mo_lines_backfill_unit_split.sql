-- Backfill: split manufacture MOL with quantity > 1 into unit rows + clone BOM.

DO $bf$
DECLARE
  r record;
  v_target int;
  v_u int;
  v_new_mol_id uuid;
  v_src_bi record;
  v_new_bi_id uuid;
BEGIN
  FOR r IN
    SELECT
      mol.id AS mol_id,
      mol.manufacturing_order_id,
      mol.sales_order_line_id,
      mol.organization_id,
      mol.configured_product_id,
      mol.status,
      mol.delivery_status,
      mol.quantity,
      mo.status AS mo_status,
      COALESCE(pt.fulfillment_type, 'manufacture') AS fulfillment
    FROM public."ManufacturingOrderLines" mol
    JOIN public."ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
    JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
    LEFT JOIN public."ProductTypes" pt
      ON pt.code = sol.product_type
     AND pt.organization_id = COALESCE(mol.organization_id, sol.organization_id)
    WHERE mol.deleted = false
      AND mo.deleted = false
      AND COALESCE(mol.quantity, 1) > 1
      AND COALESCE(pt.fulfillment_type, 'manufacture') <> 'supply_only'
      AND mo.status NOT IN ('cancelled', 'delivered', 'completed')
  LOOP
    v_target := GREATEST(1, CEIL(r.quantity)::int);

    -- Keep original as unit 1
    UPDATE public."ManufacturingOrderLines"
    SET quantity = 1,
        unit_index = 1,
        updated_at = now()
    WHERE id = r.mol_id;

    SELECT * INTO v_src_bi
    FROM public."BOMInstances"
    WHERE manufacturing_order_line_id = r.mol_id
      AND deleted = false
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_src_bi.id IS NULL THEN
      SELECT * INTO v_src_bi
      FROM public."BOMInstances"
      WHERE manufacturing_order_id = r.manufacturing_order_id
        AND sales_order_line_id = r.sales_order_line_id
        AND deleted = false
      ORDER BY created_at ASC
      LIMIT 1;

      IF v_src_bi.id IS NOT NULL THEN
        UPDATE public."BOMInstances"
        SET manufacturing_order_line_id = r.mol_id,
            updated_at = now()
        WHERE id = v_src_bi.id;
      END IF;
    END IF;

    -- Ensure existing WO on this SOL attach to unit 1 MOL
    UPDATE public."WorkOrderTasks"
    SET manufacturing_order_line_id = r.mol_id
    WHERE manufacturing_order_id = r.manufacturing_order_id
      AND sales_order_line_id = r.sales_order_line_id
      AND manufacturing_order_line_id IS NULL
      AND COALESCE(deleted, false) = false;

    FOR v_u IN 2..v_target LOOP
      INSERT INTO public."ManufacturingOrderLines" (
        manufacturing_order_id,
        sales_order_line_id,
        organization_id,
        configured_product_id,
        quantity,
        unit_index,
        status,
        delivery_status,
        deleted
      ) VALUES (
        r.manufacturing_order_id,
        r.sales_order_line_id,
        r.organization_id,
        r.configured_product_id,
        1,
        v_u,
        r.status,
        COALESCE(r.delivery_status, 'pending'),
        false
      )
      RETURNING id INTO v_new_mol_id;

      IF v_src_bi.id IS NOT NULL THEN
        INSERT INTO public."BOMInstances" (
          organization_id,
          manufacturing_order_id,
          sales_order_line_id,
          manufacturing_order_line_id,
          quote_line_id,
          bom_template_id,
          deleted
        ) VALUES (
          v_src_bi.organization_id,
          v_src_bi.manufacturing_order_id,
          v_src_bi.sales_order_line_id,
          v_new_mol_id,
          v_src_bi.quote_line_id,
          v_src_bi.bom_template_id,
          false
        )
        RETURNING id INTO v_new_bi_id;

        INSERT INTO public."BOMInstanceLines" (
          organization_id,
          bom_instance_id,
          resolved_part_id,
          part_role,
          qty,
          uom,
          unit_cost_exw,
          total_cost_exw,
          unit_msrp,
          total_msrp,
          cut_length_mm,
          cut_height_mm,
          cut_width_mm,
          panel_index,
          excluded,
          deleted
        )
        SELECT
          bil.organization_id,
          v_new_bi_id,
          bil.resolved_part_id,
          bil.part_role,
          bil.qty,
          bil.uom,
          bil.unit_cost_exw,
          bil.total_cost_exw,
          bil.unit_msrp,
          bil.total_msrp,
          bil.cut_length_mm,
          bil.cut_height_mm,
          bil.cut_width_mm,
          bil.panel_index,
          bil.excluded,
          false
        FROM public."BOMInstanceLines" bil
        WHERE bil.bom_instance_id = v_src_bi.id
          AND bil.deleted = false;
      END IF;
    END LOOP;
  END LOOP;
END;
$bf$;

-- Scale down WO task line qtys that were multiplied by sol.quantity (unit-split now)
UPDATE public."WorkOrderTaskLines" wotl
SET qty = bil.qty
FROM public."BOMInstanceLines" bil,
     public."BOMInstances" bi,
     public."WorkOrderTasks" wot,
     public."ManufacturingOrderLines" mol
WHERE wotl.bom_instance_line_id = bil.id
  AND bil.bom_instance_id = bi.id
  AND wotl.task_id = wot.id
  AND wot.manufacturing_order_line_id = mol.id
  AND mol.quantity = 1
  AND COALESCE(wotl.completed, false) = false
  AND ABS(COALESCE(wotl.qty, 0) - COALESCE(bil.qty, 0)) > 0.0001
  AND COALESCE(wotl.qty, 0) > COALESCE(bil.qty, 0);
