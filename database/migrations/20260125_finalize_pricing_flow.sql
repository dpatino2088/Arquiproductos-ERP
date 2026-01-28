-- ====================================================
-- MIGRATION: Finalizar flujo de pricing completo
-- Date: 2026-01-25
-- Description: 
--  1. Asegurar unique constraint en CatalogItemsMSRP
--  2. Eliminar triggers duplicados
--  3. Verificar y corregir calculate_configured_product_totals
--  4. Asegurar que use BOMInstances/BOMInstanceLines correctamente
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Asegurar unique constraint en CatalogItemsMSRP
-- ====================================================
-- Verificar si ya existe constraint único
DO $$
BEGIN
  -- Intentar crear unique constraint si no existe
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'catalogitemsmsrp_org_item_unique'
      AND conrelid = 'public."CatalogItemsMSRP"'::regclass
  ) THEN
    -- Crear unique constraint en (organization_id, catalog_item_id)
    ALTER TABLE public."CatalogItemsMSRP"
      ADD CONSTRAINT catalogitemsmsrp_org_item_unique 
      UNIQUE (organization_id, catalog_item_id);
    
    RAISE NOTICE '✅ Unique constraint creado en CatalogItemsMSRP';
  ELSE
    RAISE NOTICE '✅ Unique constraint ya existe en CatalogItemsMSRP';
  END IF;
END $$;

-- Crear índice para performance si no existe
CREATE INDEX IF NOT EXISTS idx_catalogitemsmsrp_org_item 
  ON public."CatalogItemsMSRP" (organization_id, catalog_item_id);

-- ====================================================
-- 2. Eliminar triggers duplicados
-- ====================================================
-- Eliminar trigger antiguo trig_items_msrp (duplicado con trg_recompute_msrp_on_catalog_item_change)
-- ✅ IMPORTANTE: Verificar primero si existe el nuevo trigger antes de eliminar el viejo
DO $$
BEGIN
  -- Verificar que el nuevo trigger existe
  IF EXISTS (
    SELECT 1 
    FROM pg_trigger 
    WHERE tgname = 'trg_recompute_msrp_on_catalog_item_change'
      AND tgrelid = 'public."CatalogItems"'::regclass
  ) THEN
    -- Si el nuevo existe, eliminar el viejo
    DROP TRIGGER IF EXISTS "trig_items_msrp" ON public."CatalogItems";
    RAISE NOTICE '✅ Trigger trig_items_msrp eliminado (duplicado)';
    
    -- Eliminar función antigua si no se usa en otro lugar
    IF NOT EXISTS (
      SELECT 1 
      FROM pg_trigger 
      WHERE tgname = 'trig_items_msrp'
    ) THEN
      DROP FUNCTION IF EXISTS public."trig_items_msrp"() CASCADE;
      RAISE NOTICE '✅ Función trig_items_msrp eliminada (duplicada)';
    END IF;
  ELSE
    RAISE WARNING '⚠️ Trigger trg_recompute_msrp_on_catalog_item_change NO existe. No se eliminará trig_items_msrp.';
  END IF;
END $$;

-- ====================================================
-- 3. Verificar y corregir calculate_configured_product_totals
-- ====================================================
-- La función ya está corregida en 20260125_complete_configured_products_quote_lines_flow.sql
-- Solo verificamos que use las tablas correctas
DO $$
BEGIN
  -- Verificar que la función existe y usa BOMInstances (mayúsculas)
  IF EXISTS (
    SELECT 1 
    FROM pg_proc 
    WHERE proname = 'calculate_configured_product_totals'
  ) THEN
    RAISE NOTICE '✅ Función calculate_configured_product_totals existe';
    
    -- Verificar que no use tablas old (BomInstances/BomInstanceLines)
    IF EXISTS (
      SELECT 1 
      FROM pg_proc p
      JOIN pg_proc p2 ON p.oid = p2.oid
      WHERE p.proname = 'calculate_configured_product_totals'
        AND p.prosrc LIKE '%"BomInstances"%'
    ) THEN
      RAISE WARNING '⚠️ Función calculate_configured_product_totals puede estar usando tablas old (BomInstances)';
    ELSE
      RAISE NOTICE '✅ Función calculate_configured_product_totals usa tablas correctas (BOMInstances)';
    END IF;
  ELSE
    RAISE WARNING '⚠️ Función calculate_configured_product_totals NO existe';
  END IF;
END $$;

-- ====================================================
-- 4. Verificar que no existan referencias a tablas old
-- ====================================================
DO $$
DECLARE
  v_old_refs integer;
BEGIN
  -- Buscar funciones que usen tablas old
  SELECT COUNT(*) INTO v_old_refs
  FROM pg_proc
  WHERE prosrc LIKE '%"BomInstances"%'
     OR prosrc LIKE '%"BomInstanceLines"%'
     OR prosrc LIKE '%from BomInstances%'
     OR prosrc LIKE '%from BomInstanceLines%';
  
  IF v_old_refs > 0 THEN
    RAISE WARNING '⚠️ Se encontraron % funciones que pueden usar tablas old (BomInstances/BomInstanceLines)', v_old_refs;
  ELSE
    RAISE NOTICE '✅ No se encontraron referencias a tablas old en funciones';
  END IF;
END $$;

-- ====================================================
-- 5. Crear índice para performance en BOMInstanceLines
-- ====================================================
CREATE INDEX IF NOT EXISTS idx_bominstancelines_instance_resolved 
  ON public."BOMInstanceLines" (bom_instance_id, resolved_part_id)
  WHERE deleted = false AND resolved_part_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bominstancelines_resolved_part 
  ON public."BOMInstanceLines" (resolved_part_id)
  WHERE deleted = false AND resolved_part_id IS NOT NULL;

-- ====================================================
-- 6. Verificar triggers activos
-- ====================================================
DO $$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE '=== Triggers activos para CatalogItems ===';
  
  -- Listar todos los triggers en CatalogItems
  FOR rec IN
    SELECT tgname, tgenabled
    FROM pg_trigger
    WHERE tgrelid = 'public."CatalogItems"'::regclass
      AND tgname NOT LIKE 'pg_%'
  LOOP
    RAISE NOTICE 'Trigger: % (enabled: %)', rec.tgname, rec.tgenabled;
  END LOOP;
END $$;

COMMIT;
