-- ====================================================
-- Query: Limpiar BOM existente para un Manufacturing Order
-- ====================================================
-- IMPORTANTE: Esta query elimina TODAS las líneas de BOM para el MO especificado
-- Úsala solo si necesitas regenerar el BOM desde cero
-- ====================================================

-- Reemplazar con el manufacturing_order_id real
-- Ejemplo: '79d6cc3c-b546-4c6f-97ca-42125f7454d5'::uuid

DO $$
DECLARE
  v_mo_id uuid := '79d6cc3c-b546-4c6f-97ca-42125f7454d5'::uuid; -- ⚠️ REEMPLAZAR CON EL ID REAL
  v_deleted_lines int := 0;
  v_deleted_instances int := 0;
BEGIN
  -- 1) Eliminar BomInstanceLines asociadas a BomInstances del MO
  DELETE FROM "BomInstanceLines" bil
  WHERE bil.bom_instance_id IN (
    SELECT bi.id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = v_mo_id
  );
  
  GET DIAGNOSTICS v_deleted_lines = ROW_COUNT;
  RAISE NOTICE '✅ Eliminadas % líneas de BomInstanceLines', v_deleted_lines;
  
  -- 2) Eliminar BomInstances asociadas al MO
  DELETE FROM "BomInstances" bi
  WHERE bi.id IN (
    SELECT bi2.id
    FROM "BomInstances" bi2
    JOIN "SalesOrderLines" sol ON sol.id = bi2.sale_order_line_id
    JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = v_mo_id
  );
  
  GET DIAGNOSTICS v_deleted_instances = ROW_COUNT;
  RAISE NOTICE '✅ Eliminadas % instancias de BomInstances', v_deleted_instances;
  
  RAISE NOTICE '✅ Limpieza completada para MO: %', v_mo_id;
  
END $$;

-- ====================================================
-- Query de verificación (ejecutar después de limpiar)
-- ====================================================
/*
SELECT 
  mo.id as mo_id,
  mo.status,
  COUNT(DISTINCT bi.id) as bom_instances_count,
  COUNT(bil.id) as bom_lines_count
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.id = '79d6cc3c-b546-4c6f-97ca-42125f7454d5'::uuid -- ⚠️ REEMPLAZAR CON EL ID REAL
GROUP BY mo.id, mo.status;
*/


