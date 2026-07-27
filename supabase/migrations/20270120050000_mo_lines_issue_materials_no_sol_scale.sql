-- issue_materials: N BOMInstances already encode unit qty — do not × sol.quantity.
DO $patch$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'issue_materials_for_manufacturing_order';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'issue_materials_for_manufacturing_order not found';
  END IF;

  IF position('SUM(bil.qty * COALESCE(sol.quantity, 1))' IN v_def) = 0 THEN
    RAISE NOTICE 'issue_materials already without sol.quantity scale';
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    'SUM(bil.qty * COALESCE(sol.quantity, 1)) AS total_qty,
           bil.uom
    FROM "BOMInstanceLines" bil
    JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
    LEFT JOIN "SaleOrderLines" sol ON sol.id = bi.sales_order_line_id',
    'SUM(bil.qty) AS total_qty,
           bil.uom
    FROM "BOMInstanceLines" bil
    JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id'
  );

  EXECUTE v_def;
END;
$patch$;
