-- ============================================================================
-- LIMPIEZA: Eliminar tablas de tipos/categorías no usadas
-- ============================================================================
-- Este script elimina tablas de tipos que no se usan en el frontend
-- 
-- SEGURO: Ninguna de estas tablas tiene queries en el código actual
-- 
-- IMPORTANTE: Ejecuta este script en Supabase SQL Editor
-- ============================================================================

DO $$ 
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧹 Iniciando limpieza de tablas de tipos no usadas...';
    RAISE NOTICE '';
END $$;

-- ============================================================================
-- PASO 1: Eliminar tablas de módulos ya eliminados (Sites y Contractors)
-- ============================================================================
DO $$
BEGIN
    -- ContractorRoles
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContractorRoles') THEN
        DROP TABLE "ContractorRoles" CASCADE;
        RAISE NOTICE '✅ Eliminada: ContractorRoles';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: ContractorRoles';
    END IF;

    -- ContractorTypes (si existe)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContractorTypes') THEN
        DROP TABLE "ContractorTypes" CASCADE;
        RAISE NOTICE '✅ Eliminada: ContractorTypes';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: ContractorTypes';
    END IF;

    -- SiteTypes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'SiteTypes') THEN
        DROP TABLE "SiteTypes" CASCADE;
        RAISE NOTICE '✅ Eliminada: SiteTypes';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: SiteTypes';
    END IF;

    RAISE NOTICE '';
END $$;

-- ============================================================================
-- PASO 2: Eliminar tablas de tipos que NO se usan en el frontend
-- ============================================================================
DO $$
BEGIN
    -- VendorTypes (tabla existe pero no se lee en VendorNew.tsx)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'VendorTypes') THEN
        DROP TABLE "VendorTypes" CASCADE;
        RAISE NOTICE '✅ Eliminada: VendorTypes (no usada en frontend)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: VendorTypes';
    END IF;

    -- ContactTitles (valores hardcoded en ContactNew.tsx, tabla no se lee)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContactTitles') THEN
        DROP TABLE "ContactTitles" CASCADE;
        RAISE NOTICE '✅ Eliminada: ContactTitles (valores hardcoded en código)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: ContactTitles';
    END IF;

    RAISE NOTICE '';
END $$;

-- ============================================================================
-- PASO 3: Eliminar índices huérfanos (si quedaron después de eliminar tablas)
-- ============================================================================
DROP INDEX IF EXISTS idx_contractor_roles_organization_id;
DROP INDEX IF EXISTS idx_contractor_roles_organization_deleted;
DROP INDEX IF EXISTS idx_contractor_types_organization_id;
DROP INDEX IF EXISTS idx_contractor_types_organization_deleted;
DROP INDEX IF EXISTS idx_site_types_organization_id;
DROP INDEX IF EXISTS idx_site_types_organization_deleted;
DROP INDEX IF EXISTS idx_vendor_types_organization_id;
DROP INDEX IF EXISTS idx_vendor_types_organization_deleted;
DROP INDEX IF EXISTS idx_contact_titles_organization_id;
DROP INDEX IF EXISTS idx_contact_titles_organization_deleted;

-- ============================================================================
-- PASO 4: Verificación Final
-- ============================================================================
DO $$ 
DECLARE
  customer_types_exists boolean;
  vendor_types_exists boolean;
  contact_titles_exists boolean;
  contractor_roles_exists boolean;
  site_types_exists boolean;
BEGIN
  -- Verificar que CustomerTypes aún existe (es la ÚNICA que debe quedar)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CustomerTypes'
  ) INTO customer_types_exists;
  
  -- Verificar que las otras fueron eliminadas
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'VendorTypes'
  ) INTO vendor_types_exists;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'ContactTitles'
  ) INTO contact_titles_exists;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'ContractorRoles'
  ) INTO contractor_roles_exists;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'SiteTypes'
  ) INTO site_types_exists;
  
  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ LIMPIEZA DE TABLAS DE TIPOS COMPLETADA';
  RAISE NOTICE '════════════════════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Estado de las tablas:';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Tablas MANTENIDAS (en uso activo):';
  RAISE NOTICE '   CustomerTypes: %', CASE WHEN customer_types_exists THEN '✅ EXISTE (OK)' ELSE '❌ NO EXISTE (ERROR!)' END;
  RAISE NOTICE '';
  RAISE NOTICE '❌ Tablas ELIMINADAS (no usadas):';
  RAISE NOTICE '   VendorTypes: %', CASE WHEN NOT vendor_types_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   ContactTitles: %', CASE WHEN NOT contact_titles_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   ContractorRoles: %', CASE WHEN NOT contractor_roles_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   SiteTypes: %', CASE WHEN NOT site_types_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '';
  
  IF customer_types_exists AND 
     NOT vendor_types_exists AND 
     NOT contact_titles_exists AND
     NOT contractor_roles_exists AND
     NOT site_types_exists THEN
    RAISE NOTICE '🎉 LIMPIEZA EXITOSA';
    RAISE NOTICE '   ✅ Solo CustomerTypes permanece (correcto)';
    RAISE NOTICE '   ✅ Todas las tablas no usadas fueron eliminadas';
  ELSE
    IF NOT customer_types_exists THEN
      RAISE WARNING '❌ ERROR CRÍTICO: CustomerTypes fue eliminada!';
      RAISE WARNING '   Esta tabla SÍ se usa en el frontend';
    END IF;
    IF vendor_types_exists OR contact_titles_exists OR contractor_roles_exists OR site_types_exists THEN
      RAISE WARNING '⚠️  Algunas tablas no pudieron eliminarse';
      RAISE WARNING '   Verifica los mensajes de error arriba';
    END IF;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════════════════════════';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- CONSULTAS DE VERIFICACIÓN OPCIONALES (Descomenta para ejecutar)
-- ============================================================================
/*
-- Ver todas las tablas que quedan con "Types" en el nombre
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%Type%'
ORDER BY table_name;

-- Ver tamaño de CustomerTypes (debería ser pequeña)
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT organization_id) as organizations_with_types
FROM "CustomerTypes"
WHERE deleted = false;
*/

-- ============================================================================
-- NOTAS FINALES
-- ============================================================================
-- ✅ Este script es seguro de ejecutar múltiples veces (idempotente)
-- ✅ Usa IF EXISTS para evitar errores si las tablas ya no existen
-- ✅ CustomerTypes se MANTIENE (es la única tabla de tipos que se usa)
-- ✅ Las foreign keys CASCADE se eliminan automáticamente
-- 
-- 🔍 TABLAS DE TIPOS QUE SE MANTIENEN:
--    - CustomerTypes ✅ (usado en CustomerNew.tsx)
--
-- ❌ TABLAS ELIMINADAS:
--    - VendorTypes (no se lee en VendorNew.tsx)
--    - ContactTitles (valores hardcoded en ContactNew.tsx)
--    - ContractorRoles (módulo eliminado)
--    - ContractorTypes (módulo eliminado)
--    - SiteTypes (módulo eliminado)
--
-- 💡 IMPACTO:
--    - Base de datos más limpia
--    - Reduce confusión sobre qué se usa
--    - Mejora mantenibilidad
--    - CERO impacto en funcionalidad (tablas no usadas)
-- ============================================================================

