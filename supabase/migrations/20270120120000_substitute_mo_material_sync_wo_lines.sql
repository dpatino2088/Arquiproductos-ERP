-- Keep WorkOrderTaskLines in sync when BOM SKU is substituted at allocate time.
-- New WOs already read live BOMInstanceLines.resolved_part_id; this covers WOs already generated.

CREATE OR REPLACE FUNCTION public.substitute_mo_material(
  p_mo_id uuid,
  p_warehouse_id uuid,
  p_original_catalog_item_id uuid,
  p_substitute_catalog_item_id uuid,
  p_bom_instance_line_ids uuid[] DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_mo record;
  v_orig record;
  v_sub record;
  v_roles text[];
  v_required_qty numeric := 0;
  v_linear_qty numeric := 0;
  v_fabric_buy numeric;
  v_on_hand numeric := 0;
  v_already_allocated numeric := 0;
  v_available numeric := 0;
  v_alloc_qty numeric := 0;
  v_unit_cost numeric := 0;
  v_unit_msrp numeric := 0;
  v_lines_updated int := 0;
  v_audit_count int := 0;
  v_released int := 0;
  v_wo_synced int := 0;
  v_line record;
  v_has_fabric boolean := false;
BEGIN
  IF p_original_catalog_item_id = p_substitute_catalog_item_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Substitute must differ from original SKU');
  END IF;

  SELECT mo.id, mo.organization_id, mo.status::text AS status, mo.sales_order_id, mo.deleted
    INTO v_mo
  FROM public."ManufacturingOrders" mo
  WHERE mo.id = p_mo_id;

  IF NOT FOUND OR v_mo.deleted THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  IF v_mo.status NOT IN ('draft', 'confirmed', 'procurement', 'material_available', 'materials_ready') THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Cannot substitute materials when MO is in %s. Only allowed up to Materials Ready.', v_mo.status)
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public."InventoryAllocations" ia
    WHERE ia.manufacturing_order_id = p_mo_id
      AND ia.catalog_item_id = p_original_catalog_item_id
      AND ia.status = 'issued'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Cannot substitute: original material already issued');
  END IF;

  SELECT ci.id, ci.organization_id, ci.measure_basis::text AS measure_basis, ci.is_active, ci.cost_exw
    INTO v_orig
  FROM public."CatalogItems" ci
  WHERE ci.id = p_original_catalog_item_id;

  SELECT
    ci.id,
    ci.organization_id,
    ci.measure_basis::text AS measure_basis,
    ci.is_active,
    ci.cost_exw,
    ci.sku,
    ci.name,
    COALESCE(msrp.total_cost, ci.cost_exw, 0) AS unit_cost,
    COALESCE(msrp.msrp, 0) AS unit_msrp
  INTO v_sub
  FROM public."CatalogItems" ci
  LEFT JOIN public."CatalogItemsMSRP" msrp ON msrp.catalog_item_id = ci.id
  WHERE ci.id = p_substitute_catalog_item_id;

  IF v_orig.id IS NULL OR v_sub.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Catalog item not found');
  END IF;

  IF v_orig.organization_id <> v_mo.organization_id OR v_sub.organization_id <> v_mo.organization_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Catalog items must belong to the MO organization');
  END IF;

  IF COALESCE(v_sub.is_active, true) = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Substitute catalog item is inactive');
  END IF;

  IF v_orig.measure_basis IS DISTINCT FROM v_sub.measure_basis THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('measure_basis mismatch: original=%s substitute=%s', v_orig.measure_basis, v_sub.measure_basis)
    );
  END IF;

  CREATE TEMP TABLE _sub_bil (
    id uuid PRIMARY KEY,
    part_role text,
    qty numeric,
    unit_cost_exw numeric
  ) ON COMMIT DROP;

  INSERT INTO _sub_bil (id, part_role, qty, unit_cost_exw)
  SELECT bil.id, bil.part_role, bil.qty, bil.unit_cost_exw
  FROM public."BOMInstanceLines" bil
  JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
  WHERE bi.manufacturing_order_id = p_mo_id
    AND bi.deleted = false
    AND COALESCE(bil.deleted, false) = false
    AND bil.resolved_part_id = p_original_catalog_item_id
    AND (
      p_bom_instance_line_ids IS NULL
      OR bil.id = ANY (p_bom_instance_line_ids)
    );

  GET DIAGNOSTICS v_lines_updated = ROW_COUNT;
  IF v_lines_updated = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No matching BOM instance lines for original SKU on this MO');
  END IF;

  SELECT ARRAY_AGG(DISTINCT part_role), COALESCE(SUM(qty), 0)
    INTO v_roles, v_linear_qty
  FROM _sub_bil
  WHERE part_role IS NOT NULL;

  IF v_roles IS NULL OR cardinality(v_roles) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BOM lines missing part_role');
  END IF;

  IF NOT public._mo_substitute_role_ok(
    v_mo.organization_id,
    p_substitute_catalog_item_id,
    v_roles,
    v_sub.measure_basis
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Substitute is not eligible for role(s) %s with measure_basis %s', v_roles::text, v_sub.measure_basis)
    );
  END IF;

  v_has_fabric := EXISTS (SELECT 1 FROM unnest(v_roles) r WHERE lower(r) = 'fabric');

  IF v_has_fabric AND p_bom_instance_line_ids IS NULL THEN
    SELECT fp.purchase_qty
      INTO v_fabric_buy
    FROM public."ManufacturingOrderFabricPurchase" fp
    WHERE fp.manufacturing_order_id = p_mo_id
      AND fp.catalog_item_id = p_original_catalog_item_id
    LIMIT 1;
  END IF;

  v_required_qty := CASE
    WHEN v_fabric_buy IS NOT NULL AND v_fabric_buy > 0 THEN v_fabric_buy
    ELSE v_linear_qty
  END;

  IF v_required_qty < 0.0001 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Required qty is zero');
  END IF;

  SELECT COALESCE(SUM(ib.quantity), 0)
    INTO v_on_hand
  FROM public."InventoryBalances" ib
  WHERE ib.organization_id = v_mo.organization_id
    AND ib.warehouse_id = p_warehouse_id
    AND ib.catalog_item_id = p_substitute_catalog_item_id;

  SELECT COALESCE(SUM(ia.allocated_qty), 0)
    INTO v_already_allocated
  FROM public."InventoryAllocations" ia
  WHERE ia.organization_id = v_mo.organization_id
    AND ia.warehouse_id = p_warehouse_id
    AND ia.catalog_item_id = p_substitute_catalog_item_id
    AND ia.status = 'reserved';

  v_available := v_on_hand - v_already_allocated;

  IF v_available + 0.0001 < v_required_qty THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Insufficient substitute stock: need %s, available %s', v_required_qty, GREATEST(v_available, 0)),
      'required_qty', v_required_qty,
      'available_qty', GREATEST(v_available, 0)
    );
  END IF;

  v_unit_cost := COALESCE(v_sub.unit_cost, 0);
  v_unit_msrp := COALESCE(v_sub.unit_msrp, 0);

  UPDATE public."InventoryAllocations" ia
  SET status = 'released',
      released_at = now(),
      updated_at = now()
  WHERE ia.manufacturing_order_id = p_mo_id
    AND ia.catalog_item_id = p_original_catalog_item_id
    AND ia.status = 'reserved';
  GET DIAGNOSTICS v_released = ROW_COUNT;

  FOR v_line IN SELECT * FROM _sub_bil LOOP
    UPDATE public."BOMInstanceLines" bil
    SET resolved_part_id = p_substitute_catalog_item_id,
        catalog_item_id = p_substitute_catalog_item_id,
        unit_cost_exw = ROUND(v_unit_cost, 4),
        total_cost_exw = ROUND(v_unit_cost * COALESCE(bil.qty, 0), 4),
        unit_msrp = ROUND(v_unit_msrp, 4),
        total_msrp = ROUND(v_unit_msrp * COALESCE(bil.qty, 0), 4),
        updated_at = now()
    WHERE bil.id = v_line.id;

    INSERT INTO public."MOMaterialSubstitutions" (
      organization_id,
      mo_id,
      bom_instance_line_id,
      original_catalog_item_id,
      substitute_catalog_item_id,
      qty,
      original_unit_cost,
      substitute_unit_cost,
      reason,
      created_by
    ) VALUES (
      v_mo.organization_id,
      p_mo_id,
      v_line.id,
      p_original_catalog_item_id,
      p_substitute_catalog_item_id,
      COALESCE(v_line.qty, 0),
      v_line.unit_cost_exw,
      v_unit_cost,
      p_reason,
      auth.uid()
    );
    v_audit_count := v_audit_count + 1;
  END LOOP;

  UPDATE public."WorkOrderTaskLines" wotl
  SET catalog_item_id = p_substitute_catalog_item_id,
      sku = v_sub.sku,
      item_name = v_sub.name
  WHERE wotl.bom_instance_line_id IN (SELECT id FROM _sub_bil);
  GET DIAGNOSTICS v_wo_synced = ROW_COUNT;

  IF v_has_fabric THEN
    UPDATE public."ManufacturingOrderFabricPurchase" fp
    SET catalog_item_id = p_substitute_catalog_item_id,
        updated_at = now()
    WHERE fp.manufacturing_order_id = p_mo_id
      AND fp.catalog_item_id = p_original_catalog_item_id;
  END IF;

  v_alloc_qty := ROUND(LEAST(v_required_qty, GREATEST(0, v_available)), 4);
  IF v_alloc_qty >= 0.0001 THEN
    INSERT INTO public."InventoryAllocations" (
      organization_id,
      warehouse_id,
      catalog_item_id,
      manufacturing_order_id,
      sales_order_id,
      allocated_qty,
      status,
      source
    ) VALUES (
      v_mo.organization_id,
      p_warehouse_id,
      p_substitute_catalog_item_id,
      p_mo_id,
      v_mo.sales_order_id,
      v_alloc_qty,
      'reserved',
      'auto'
    );
  END IF;

  IF v_mo.status = 'materials_ready' AND v_alloc_qty + 0.0001 < v_required_qty THEN
    UPDATE public."ManufacturingOrders"
    SET status = 'procurement'::manufacturing_order_status,
        updated_at = now()
    WHERE id = p_mo_id AND deleted = false;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'lines_updated', v_audit_count,
    'released_count', v_released,
    'wo_lines_synced', v_wo_synced,
    'allocated_qty', v_alloc_qty,
    'required_qty', v_required_qty,
    'substitute_unit_cost', v_unit_cost,
    'original_catalog_item_id', p_original_catalog_item_id,
    'substitute_catalog_item_id', p_substitute_catalog_item_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.substitute_mo_material(uuid, uuid, uuid, uuid, uuid[], text) TO authenticated;
