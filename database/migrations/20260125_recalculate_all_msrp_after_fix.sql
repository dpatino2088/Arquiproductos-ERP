-- ====================================================
-- MIGRATION: Recalcular todos los MSRP después de corregir función
-- Date: 2026-01-25
-- Description: Recalcula MSRP para todos los CatalogItems después de corregir msrp_compute_for_item
-- IMPORTANTE: Ejecutar DESPUÉS de 20260125_fix_msrp_compute_for_item.sql
-- ====================================================

BEGIN;

-- ====================================================
-- Recalcular MSRP para todos los items activos
-- ====================================================
DO $$
DECLARE
  v_item RECORD;
  v_count integer := 0;
  v_total integer;
BEGIN
  -- Contar total de items
  SELECT COUNT(*) INTO v_total
  FROM public."CatalogItems"
  WHERE cost_exw > 0
    AND organization_id IS NOT NULL;
  
  RAISE NOTICE '=== Recalculando MSRP para % items ===', v_total;
  
  -- Recalcular cada item
  FOR v_item IN
    SELECT id, sku, cost_exw
    FROM public."CatalogItems"
    WHERE cost_exw > 0
      AND organization_id IS NOT NULL
    ORDER BY created_at DESC
  LOOP
    BEGIN
      PERFORM public.msrp_compute_for_item(v_item.id);
      v_count := v_count + 1;
      
      -- Log cada 100 items
      IF v_count % 100 = 0 THEN
        RAISE NOTICE 'Procesados % / % items...', v_count, v_total;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error recalculando item % (SKU: %): %', v_item.id, v_item.sku, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE '=== Recalculación completada: % items procesados ===', v_count;
END $$;

COMMIT;
