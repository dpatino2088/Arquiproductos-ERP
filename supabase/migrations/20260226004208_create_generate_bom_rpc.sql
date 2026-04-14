
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
  v_bomi_id uuid;
  v_line_count int := 0;
  v_bom_count int := 0;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_manufacturing_order_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Manufacturing Order not found'; END IF;

  -- Step 1: Create ManufacturingOrderLines from SaleOrderLines if none exist
  IF NOT EXISTS (SELECT 1 FROM "ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false) THEN
    FOR v_sol IN
      SELECT id, organization_id, quantity, configured_product_id
      FROM "SaleOrderLines"
      WHERE sales_order_id = v_mo.sales_order_id AND deleted = false
    LOOP
      INSERT INTO "ManufacturingOrderLines" (manufacturing_order_id, sales_order_line_id, organization_id, quantity, configured_product_id)
      VALUES (p_manufacturing_order_id, v_sol.id, v_sol.organization_id, COALESCE(v_sol.quantity, 1), v_sol.configured_product_id)
      RETURNING id INTO v_mol_id;
      v_line_count := v_line_count + 1;
    END LOOP;
  END IF;

  -- Step 2: Create BOMInstances for each ManufacturingOrderLine that doesn't have one
  FOR v_sol IN
    SELECT mol.id as mol_id, mol.sales_order_line_id, mol.organization_id, mol.configured_product_id,
           sol.quote_line_id
    FROM "ManufacturingOrderLines" mol
    LEFT JOIN "SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
    WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false
    AND NOT EXISTS (
      SELECT 1 FROM "BOMInstances" bi
      WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.sales_order_line_id = mol.sales_order_line_id
      AND bi.deleted = false
    )
  LOOP
    INSERT INTO "BOMInstances" (organization_id, manufacturing_order_id, sales_order_line_id, quote_line_id)
    VALUES (v_sol.organization_id, p_manufacturing_order_id, v_sol.sales_order_line_id, v_sol.quote_line_id)
    RETURNING id INTO v_bomi_id;
    v_bom_count := v_bom_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'mo_lines_created', v_line_count,
    'bom_instances_created', v_bom_count
  );
END;
$function$;
;
