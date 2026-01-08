-- ====================================================
-- Query: Limpiar BOM por SaleOrder
-- ====================================================
-- Limpia BomInstanceLines + BomInstances para un SaleOrder específico
-- Útil para regenerar BOM limpio después de normalizar el template
-- ====================================================

-- Opción 1: Por sale_order_no
DO $$
DECLARE
  v_sale_order_id uuid;
  v_deleted_lines int := 0;
  v_deleted_instances int := 0;
BEGIN
  -- ⚠️ REEMPLAZAR con el sale_order_no real (ej: 'SO-090166')
  SELECT id INTO v_sale_order_id
  FROM "SalesOrders"
  WHERE sale_order_no = 'SO-090166' -- ⚠️ REEMPLAZAR
    AND deleted = false
  LIMIT 1;

  IF v_sale_order_id IS NULL THEN
    RAISE EXCEPTION 'SaleOrder not found';
  END IF;

  RAISE NOTICE '🗑️  Limpiando BOMs para SaleOrder: % (id: %)', 'SO-090166', v_sale_order_id;

  -- Eliminar BomInstanceLines
  DELETE FROM "BomInstanceLines"
  WHERE bom_instance_id IN (
    SELECT bi.id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
      AND bi.deleted = false
  );
  
  GET DIAGNOSTICS v_deleted_lines = ROW_COUNT;
  RAISE NOTICE '✅ Eliminadas % líneas de BomInstanceLines', v_deleted_lines;

  -- Eliminar BomInstances
  DELETE FROM "BomInstances"
  WHERE id IN (
    SELECT bi.id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
      AND bi.deleted = false
  );
  
  GET DIAGNOSTICS v_deleted_instances = ROW_COUNT;
  RAISE NOTICE '✅ Eliminadas % instancias de BomInstances', v_deleted_instances;
  
  RAISE NOTICE '✅ Limpieza completada para SaleOrder: %', 'SO-090166';
  
END $$;

-- ====================================================
-- Opción 2: Por manufacturing_order_id (alternativa)
-- ====================================================
/*
DO $$
DECLARE
  v_mo_id uuid := '39aa56bd-4750-4b86-ab6c-fc0c3b010543'::uuid; -- ⚠️ REEMPLAZAR
  v_sale_order_id uuid;
  v_deleted_lines int := 0;
  v_deleted_instances int := 0;
BEGIN
  -- Obtener sale_order_id del ManufacturingOrder
  SELECT sale_order_id INTO v_sale_order_id
  FROM "ManufacturingOrders"
  WHERE id = v_mo_id
    AND deleted = false
  LIMIT 1;

  IF v_sale_order_id IS NULL THEN
    RAISE EXCEPTION 'ManufacturingOrder % not found', v_mo_id;
  END IF;

  RAISE NOTICE '🗑️  Limpiando BOMs para ManufacturingOrder: % (SaleOrder: %)', v_mo_id, v_sale_order_id;

  -- Eliminar BomInstanceLines
  DELETE FROM "BomInstanceLines"
  WHERE bom_instance_id IN (
    SELECT bi.id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
      AND bi.deleted = false
  );
  
  GET DIAGNOSTICS v_deleted_lines = ROW_COUNT;
  RAISE NOTICE '✅ Eliminadas % líneas de BomInstanceLines', v_deleted_lines;

  -- Eliminar BomInstances
  DELETE FROM "BomInstances"
  WHERE id IN (
    SELECT bi.id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
      AND bi.deleted = false
  );
  
  GET DIAGNOSTICS v_deleted_instances = ROW_COUNT;
  RAISE NOTICE '✅ Eliminadas % instancias de BomInstances', v_deleted_instances;
  
  RAISE NOTICE '✅ Limpieza completada para ManufacturingOrder: %', v_mo_id;
  
END $$;
*/


