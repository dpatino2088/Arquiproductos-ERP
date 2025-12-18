-- ====================================================
-- Migration 86: Limpiar tabla de staging
-- ====================================================
-- Esta tabla temporal ya no se necesita después de
-- actualizar las categorías desde el CSV
-- ====================================================

DO $$
DECLARE
  staging_count integer := 0;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'LIMPIEZA DE TABLA DE STAGING';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Verificar cuántos registros hay
  BEGIN
    SELECT COUNT(*) INTO staging_count
    FROM public."_stg_catalog_items";
    RAISE NOTICE 'Registros en _stg_catalog_items: %', staging_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Tabla _stg_catalog_items no existe o está vacía';
  END;

  RAISE NOTICE '';

  -- OPCIÓN 1: Limpiar la tabla (TRUNCATE) - mantiene la estructura
  RAISE NOTICE 'OPCIÓN 1: Limpiando tabla (TRUNCATE)...';
  BEGIN
    TRUNCATE TABLE public."_stg_catalog_items";
    RAISE NOTICE '   ✅ Tabla limpiada (estructura mantenida)';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '   ⚠️  No se pudo limpiar: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- OPCIÓN 2: Eliminar la tabla completamente (descomenta si lo prefieres)
  /*
  RAISE NOTICE 'OPCIÓN 2: Eliminando tabla completamente...';
  BEGIN
    DROP TABLE IF EXISTS public."_stg_catalog_items";
    RAISE NOTICE '   ✅ Tabla eliminada completamente';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '   ⚠️  No se pudo eliminar: %', SQLERRM;
  END;
  */

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ LIMPIEZA COMPLETADA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '💡 Nota:';
  RAISE NOTICE '   - La tabla está vacía pero la estructura se mantiene';
  RAISE NOTICE '   - Si quieres eliminarla completamente, descomenta la OPCIÓN 2';
  RAISE NOTICE '   - Puedes volver a importar el CSV en el futuro si lo necesitas';
  RAISE NOTICE '';

END $$;

