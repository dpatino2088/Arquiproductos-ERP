
CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo record;
  v_sol record;
  v_mol_id uuid;
  v_bom_template_id uuid;
  v_bomi_id uuid;
  v_bc record;
  v_qty numeric;
  v_width_mm numeric;
  v_height_mm numeric;
  v_cut_len numeric;
  v_cut_wid numeric;
  v_cut_hei numeric;
  v_unit_cost numeric;
  v_total_cost numeric;
  v_mo_lines_created int := 0;
  v_bom_instances_created int := 0;
  v_bom_lines_created int := 0;
  v_warnings text[] := '{}';
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_manufacturing_order_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Manufacturing Order not found'; END IF;

  -- Step 1: Auto-create ManufacturingOrderLines from SaleOrderLines if none exist
  IF NOT EXISTS (SELECT 1 FROM "ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false) THEN
    FOR v_sol IN
      SELECT id, organization_id, quantity, configured_product_id
      FROM "SaleOrderLines"
      WHERE sales_order_id = v_mo.sales_order_id AND deleted = false
    LOOP
      INSERT INTO "ManufacturingOrderLines" (manufacturing_order_id, sales_order_line_id, organization_id, quantity, configured_product_id)
      VALUES (p_manufacturing_order_id, v_sol.id, v_sol.organization_id, COALESCE(v_sol.quantity, 1), v_sol.configured_product_id)
      ON CONFLICT DO NOTHING;
      v_mo_lines_created := v_mo_lines_created + 1;
    END LOOP;
  END IF;

  -- Step 2: For each MO Line, create BOMInstance + BOMInstanceLines
  FOR v_sol IN
    SELECT mol.id as mol_id, mol.sales_order_line_id, mol.organization_id, mol.configured_product_id, mol.quantity as mol_qty,
           sol.product_type, sol.product_type_id, sol.width_m, sol.height_m, sol.quote_line_id, sol.quantity as sol_qty
    FROM "ManufacturingOrderLines" mol
    JOIN "SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
    WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false
    AND NOT EXISTS (
      SELECT 1 FROM "BOMInstances" bi
      WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.sales_order_line_id = mol.sales_order_line_id
      AND bi.deleted = false
    )
  LOOP
    v_bom_template_id := NULL;

    IF v_sol.product_type_id IS NOT NULL THEN
      SELECT bt.id INTO v_bom_template_id
      FROM "BOMTemplates" bt
      WHERE bt.product_type_id = v_sol.product_type_id
      AND bt.is_active = true AND COALESCE(bt.deleted, false) = false
      ORDER BY bt.created_at DESC LIMIT 1;
    END IF;

    IF v_bom_template_id IS NULL AND v_sol.product_type IS NOT NULL THEN
      SELECT bt.id INTO v_bom_template_id
      FROM "BOMTemplates" bt
      JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
      WHERE pt.code = v_sol.product_type
      AND bt.is_active = true AND COALESCE(bt.deleted, false) = false
      ORDER BY bt.created_at DESC LIMIT 1;
    END IF;

    IF v_bom_template_id IS NULL THEN
      v_warnings := array_append(v_warnings, 'No BOM Template for product_type: ' || COALESCE(v_sol.product_type, 'NULL'));
      CONTINUE;
    END IF;

    INSERT INTO "BOMInstances" (organization_id, manufacturing_order_id, sales_order_line_id, quote_line_id, bom_template_id)
    VALUES (v_sol.organization_id, p_manufacturing_order_id, v_sol.sales_order_line_id, v_sol.quote_line_id, v_bom_template_id)
    RETURNING id INTO v_bomi_id;
    v_bom_instances_created := v_bom_instances_created + 1;

    v_width_mm := COALESCE(v_sol.width_m, 0) * 1000;
    v_height_mm := COALESCE(v_sol.height_m, 0) * 1000;

    FOR v_bc IN
      SELECT bc.id, bc.component_item_id, bc.component_role, bc.qty_type, bc.qty_value,
             bc.qty_delta_mm, bc.uom, bc.waste_pct, bc.cut_axis, bc.cut_delta_mm,
             bc.qty_min
      FROM "BOMComponents" bc
      WHERE bc.bom_template_id = v_bom_template_id
      AND COALESCE(bc.deleted, false) = false AND bc.component_item_id IS NOT NULL
      ORDER BY bc.sort_order NULLS LAST, bc.created_at
    LOOP
      v_qty := COALESCE(v_bc.qty_value, 1);

      IF v_bc.qty_type = 'per_width' AND v_width_mm > 0 THEN
        v_qty := (v_width_mm + COALESCE(v_bc.qty_delta_mm, 0)) * COALESCE(v_bc.qty_value, 1);
        IF v_bc.uom = 'm' THEN v_qty := v_qty / 1000; END IF;
      ELSIF v_bc.qty_type = 'per_height' AND v_height_mm > 0 THEN
        v_qty := (v_height_mm + COALESCE(v_bc.qty_delta_mm, 0)) * COALESCE(v_bc.qty_value, 1);
        IF v_bc.uom = 'm' THEN v_qty := v_qty / 1000; END IF;
      ELSIF v_bc.qty_type = 'fixed' THEN
        v_qty := COALESCE(v_bc.qty_value, 1);
      END IF;

      IF COALESCE(v_bc.waste_pct, 0) > 0 THEN
        v_qty := v_qty * (1 + v_bc.waste_pct / 100);
      END IF;

      IF COALESCE(v_bc.qty_min, 0) > 0 AND v_qty < v_bc.qty_min THEN
        v_qty := v_bc.qty_min;
      END IF;

      v_qty := v_qty * COALESCE(v_sol.sol_qty, 1);

      v_cut_len := NULL; v_cut_wid := NULL; v_cut_hei := NULL;
      IF v_bc.cut_axis = 'width' THEN
        v_cut_len := v_width_mm + COALESCE(v_bc.cut_delta_mm, 0);
      ELSIF v_bc.cut_axis = 'height' THEN
        v_cut_len := v_height_mm + COALESCE(v_bc.cut_delta_mm, 0);
      END IF;

      v_unit_cost := 0;
      SELECT cost_exw INTO v_unit_cost FROM "CatalogItems" WHERE id = v_bc.component_item_id;
      v_unit_cost := COALESCE(v_unit_cost, 0);
      v_total_cost := ROUND(v_qty * v_unit_cost, 4);

      INSERT INTO "BOMInstanceLines" (
        bom_instance_id, organization_id, catalog_item_id, resolved_part_id,
        part_role, qty, uom, cut_length_mm, cut_width_mm, cut_height_mm,
        unit_cost_exw, total_cost_exw
      ) VALUES (
        v_bomi_id, v_sol.organization_id, v_bc.component_item_id, v_bc.component_item_id,
        v_bc.component_role, ROUND(v_qty, 4), COALESCE(v_bc.uom, 'ea'),
        v_cut_len, v_cut_wid, v_cut_hei,
        v_unit_cost, v_total_cost
      );
      v_bom_lines_created := v_bom_lines_created + 1;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'mo_lines_created', v_mo_lines_created,
    'bom_instances_created', v_bom_instances_created,
    'bom_instance_lines_created', v_bom_lines_created,
    'warnings', to_jsonb(v_warnings)
  );
END;
$function$;
;
