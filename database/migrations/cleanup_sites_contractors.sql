-- ============================================================================
-- LIMPIEZA DE BASE DE DATOS: Eliminar módulos Sites y Contractors
-- ============================================================================
-- Este script elimina de forma segura las tablas, políticas RLS, índices y 
-- referencias relacionadas con Sites y Contractors que ya no se usan.
--
-- IMPORTANTE: Ejecuta este script en Supabase SQL Editor
-- NOTA: Este script NO afecta datos existentes hasta que elimines las tablas.
--       Puedes hacer backup primero si lo deseas.
-- ============================================================================

-- ============================================================================
-- PASO 1: Eliminar políticas RLS de Sites y Contractors
-- ============================================================================
DO $$ 
DECLARE
  sites_exists boolean;
  contractors_exists boolean;
BEGIN
    -- Verificar si las tablas existen
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectorySites'
    ) INTO sites_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContractors'
    ) INTO contractors_exists;
    
    -- Eliminar políticas solo si las tablas existen
    IF sites_exists THEN
        DROP POLICY IF EXISTS "Allow org members to read sites" ON public."DirectorySites";
        DROP POLICY IF EXISTS "Allow org admins to insert sites" ON public."DirectorySites";
        DROP POLICY IF EXISTS "Allow org admins to update sites" ON public."DirectorySites";
        DROP POLICY IF EXISTS "Allow org admins to delete sites" ON public."DirectorySites";
        RAISE NOTICE '✅ Políticas de DirectorySites eliminadas';
    ELSE
        RAISE NOTICE '⏭️  DirectorySites ya no existe (omitiendo políticas)';
    END IF;
    
    IF contractors_exists THEN
        DROP POLICY IF EXISTS "Allow org members to read contractors" ON public."DirectoryContractors";
        DROP POLICY IF EXISTS "Allow org admins to insert contractors" ON public."DirectoryContractors";
        DROP POLICY IF EXISTS "Allow org admins to update contractors" ON public."DirectoryContractors";
        DROP POLICY IF EXISTS "Allow org admins to delete contractors" ON public."DirectoryContractors";
        RAISE NOTICE '✅ Políticas de DirectoryContractors eliminadas';
    ELSE
        RAISE NOTICE '⏭️  DirectoryContractors ya no existe (omitiendo políticas)';
    END IF;
    
    RAISE NOTICE '✅ Paso de políticas RLS completado';
END $$;

-- ============================================================================
-- PASO 2: Eliminar foreign keys que referencian a Sites y Contractors
-- ============================================================================
DO $$ 
DECLARE
  sites_exists boolean;
  contractors_exists boolean;
BEGIN
    -- Verificar si las tablas existen
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectorySites'
    ) INTO sites_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContractors'
    ) INTO contractors_exists;
    
    -- Eliminar FK solo si las tablas existen
    IF sites_exists THEN
        ALTER TABLE public."DirectorySites" 
            DROP CONSTRAINT IF EXISTS "DirectorySites_customer_id_fkey";
        
        ALTER TABLE public."DirectorySites" 
            DROP CONSTRAINT IF EXISTS "DirectorySites_contact_id_fkey";
        
        ALTER TABLE public."DirectorySites" 
            DROP CONSTRAINT IF EXISTS "DirectorySites_contractor_id_fkey";
        
        RAISE NOTICE '✅ Foreign keys de DirectorySites eliminadas';
    ELSE
        RAISE NOTICE '⏭️  DirectorySites no existe (omitiendo FK)';
    END IF;
    
    IF contractors_exists THEN
        ALTER TABLE public."DirectoryContractors" 
            DROP CONSTRAINT IF EXISTS "DirectoryContractors_contractor_role_id_fkey";
        
        RAISE NOTICE '✅ Foreign keys de DirectoryContractors eliminadas';
    ELSE
        RAISE NOTICE '⏭️  DirectoryContractors no existe (omitiendo FK)';
    END IF;
    
    RAISE NOTICE '✅ Paso de foreign keys completado';
END $$;

-- ============================================================================
-- PASO 3: Eliminar índices
-- ============================================================================
DROP INDEX IF EXISTS public.idx_directory_sites_organization_id;
DROP INDEX IF EXISTS public.idx_directory_sites_site_name;
DROP INDEX IF EXISTS public.idx_directory_sites_customer_id;
DROP INDEX IF EXISTS public.idx_directory_sites_contact_id;
DROP INDEX IF EXISTS public.idx_directory_sites_contractor_id;
DROP INDEX IF EXISTS public.idx_directory_sites_deleted;
DROP INDEX IF EXISTS public.idx_directory_sites_organization_remote_id;

DROP INDEX IF EXISTS public.idx_directory_contractors_organization_id;
DROP INDEX IF EXISTS public.idx_directory_contractors_organization_remote_id;
DROP INDEX IF EXISTS public.idx_directory_contractors_contractor_role_id;
DROP INDEX IF EXISTS public.idx_directory_contractors_deleted;

-- ============================================================================
-- PASO 4: Eliminar tablas principales
-- ============================================================================
-- ADVERTENCIA: Este paso elimina permanentemente los datos de Sites y Contractors
-- Si tienes datos importantes, haz un backup antes de ejecutar.

DO $$
DECLARE
  sites_exists boolean;
  contractors_exists boolean;
BEGIN
    -- Verificar si las tablas existen antes de eliminar
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectorySites'
    ) INTO sites_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContractors'
    ) INTO contractors_exists;
    
    -- Eliminar tablas si existen
    IF sites_exists THEN
        DROP TABLE public."DirectorySites" CASCADE;
        RAISE NOTICE '✅ Tabla DirectorySites eliminada';
    ELSE
        RAISE NOTICE '⏭️  DirectorySites ya estaba eliminada';
    END IF;
    
    IF contractors_exists THEN
        DROP TABLE public."DirectoryContractors" CASCADE;
        RAISE NOTICE '✅ Tabla DirectoryContractors eliminada';
    ELSE
        RAISE NOTICE '⏭️  DirectoryContractors ya estaba eliminada';
    END IF;
    
    RAISE NOTICE '✅ Paso de eliminación de tablas completado';
END $$;

-- ============================================================================
-- PASO 5: Eliminar tablas de referencia (opcionales)
-- ============================================================================
-- Estas tablas pueden contener tipos/categorías usadas por Sites y Contractors
-- Solo elimínalas si estás seguro de que no las necesitas

-- DROP TABLE IF EXISTS public."ContractorRoles" CASCADE;
-- DROP TABLE IF EXISTS public."SiteTypes" CASCADE;

-- Si prefieres mantenerlas pero vaciarlas:
-- TRUNCATE TABLE public."ContractorRoles" CASCADE;
-- TRUNCATE TABLE public."SiteTypes" CASCADE;

-- ============================================================================
-- PASO 6: Limpieza de funciones RLS helpers (si existen)
-- ============================================================================
-- Eliminar funciones específicas de Sites y Contractors si las hay
-- DROP FUNCTION IF EXISTS public.can_manage_sites(uuid, uuid);
-- DROP FUNCTION IF EXISTS public.can_manage_contractors(uuid, uuid);

-- ============================================================================
-- PASO 7: Verificación
-- ============================================================================
DO $$ 
DECLARE
  sites_exists boolean;
  contractors_exists boolean;
BEGIN
  -- Verificar si las tablas ya no existen
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'DirectorySites'
  ) INTO sites_exists;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'DirectoryContractors'
  ) INTO contractors_exists;
  
  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════';
  RAISE NOTICE '✅ LIMPIEZA COMPLETADA';
  RAISE NOTICE '════════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Estado de las tablas:';
  RAISE NOTICE '   DirectorySites: %', CASE WHEN sites_exists THEN '⚠️  Todavía existe' ELSE '✅ Eliminada' END;
  RAISE NOTICE '   DirectoryContractors: %', CASE WHEN contractors_exists THEN '⚠️  Todavía existe' ELSE '✅ Eliminada' END;
  RAISE NOTICE '';
  
  IF NOT sites_exists AND NOT contractors_exists THEN
    RAISE NOTICE '🎉 Base de datos limpiada exitosamente';
    RAISE NOTICE '✅ Módulos Sites y Contractors eliminados completamente';
  ELSE
    RAISE WARNING '⚠️  Algunas tablas aún existen. Verifica los errores arriba.';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '📋 Para verificar manualmente:';
  RAISE NOTICE '   SELECT tablename FROM pg_tables WHERE schemaname = ''public'' AND tablename LIKE ''%%Site%%'' OR tablename LIKE ''%%Contractor%%'';';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- CONSULTAS DE VERIFICACIÓN OPCIONALES
-- ============================================================================
/*
-- Ver todas las tablas restantes del directorio
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE 'Directory%'
ORDER BY tablename;

-- Ver todas las políticas RLS restantes
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename LIKE 'Directory%'
ORDER BY tablename, policyname;

-- Ver índices restantes
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename LIKE 'Directory%'
ORDER BY tablename, indexname;
*/

-- ============================================================================
-- NOTAS FINALES
-- ============================================================================
-- ✅ Este script es seguro de ejecutar múltiples veces (idempotente)
-- ✅ Usa IF EXISTS para evitar errores si las tablas ya no existen
-- ✅ Las tablas DirectoryContacts, DirectoryCustomers y DirectoryVendors NO se tocan
-- ✅ Las políticas y estructura de las tablas restantes permanecen intactas
-- 
-- 🔍 TABLAS QUE SE MANTIENEN:
--    - DirectoryContacts
--    - DirectoryCustomers
--    - DirectoryVendors
--    - VendorTypes
--    - CustomerTypes
--    - Organizations
--    - OrganizationUsers
--
-- ❌ TABLAS ELIMINADAS:
--    - DirectorySites
--    - DirectoryContractors
--    - ContractorRoles (opcional)
--    - SiteTypes (opcional)
-- ============================================================================

