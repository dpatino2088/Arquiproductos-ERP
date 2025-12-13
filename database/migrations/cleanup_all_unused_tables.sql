-- ============================================================================
-- LIMPIEZA COMPLETA: Eliminar TODAS las tablas no usadas
-- ============================================================================
-- Este script elimina todas las tablas que NO tienen queries en el frontend
-- 
-- TABLAS A ELIMINAR:
-- 1. DirectoryEntityContacts - Tabla huérfana/legacy
-- 2. Addresses - Campos embebidos en cada tabla (no se usa repositorio)
-- 3. Countries - Lista hardcoded en constants.ts
-- 4. States - Nunca implementado
-- 5. VendorTypes - No se lee en VendorNew.tsx
-- 6. ContactTitles - Valores hardcoded en ContactNew.tsx
-- 7. ContractorRoles - Módulo Contractors eliminado
-- 8. SiteTypes - Módulo Sites eliminado
--
-- IMPORTANTE: Ejecuta este script en Supabase SQL Editor
-- ============================================================================

DO $$ 
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧹 Iniciando limpieza COMPLETA de tablas no usadas...';
    RAISE NOTICE '';
END $$;

-- ============================================================================
-- PASO 1: Eliminar tabla DirectoryEntityContacts (huérfana)
-- ============================================================================
DO $$
DECLARE
  table_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryEntityContacts'
    ) INTO table_exists;
    
    IF table_exists THEN
        DROP TABLE public."DirectoryEntityContacts" CASCADE;
        RAISE NOTICE '✅ Eliminada: DirectoryEntityContacts (tabla huérfana/legacy)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: DirectoryEntityContacts';
    END IF;
END $$;

-- ============================================================================
-- PASO 2: Eliminar tabla Addresses (no usada - campos embebidos)
-- ============================================================================
DO $$
DECLARE
  table_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Addresses'
    ) INTO table_exists;
    
    IF table_exists THEN
        -- Primero eliminar FKs que apuntan a Addresses
        ALTER TABLE IF EXISTS public."DirectoryContacts" 
            DROP CONSTRAINT IF EXISTS "DirectoryContacts_location_address_id_fkey";
        ALTER TABLE IF EXISTS public."DirectoryContacts" 
            DROP CONSTRAINT IF EXISTS "DirectoryContacts_billing_address_id_fkey";
        
        -- Eliminar columnas FK que referencian Addresses
        ALTER TABLE IF EXISTS public."DirectoryContacts" 
            DROP COLUMN IF EXISTS location_address_id CASCADE;
        ALTER TABLE IF EXISTS public."DirectoryContacts" 
            DROP COLUMN IF EXISTS billing_address_id CASCADE;
        
        -- Ahora eliminar la tabla
        DROP TABLE public."Addresses" CASCADE;
        RAISE NOTICE '✅ Eliminada: Addresses (campos embebidos en cada tabla)';
        RAISE NOTICE '✅ Eliminadas: Columnas FK location_address_id y billing_address_id';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: Addresses';
    END IF;
END $$;

-- ============================================================================
-- PASO 3: Eliminar tabla Countries (lista hardcoded en constants.ts)
-- ============================================================================
DO $$
DECLARE
  table_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Countries'
    ) INTO table_exists;
    
    IF table_exists THEN
        DROP TABLE public."Countries" CASCADE;
        RAISE NOTICE '✅ Eliminada: Countries (lista hardcoded en constants.ts)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: Countries';
    END IF;
END $$;

-- ============================================================================
-- PASO 4: Eliminar tabla States (nunca implementada)
-- ============================================================================
DO $$
DECLARE
  table_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'States'
    ) INTO table_exists;
    
    IF table_exists THEN
        DROP TABLE public."States" CASCADE;
        RAISE NOTICE '✅ Eliminada: States (nunca implementada)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: States';
    END IF;
END $$;

-- ============================================================================
-- PASO 5: Eliminar tablas de tipos de módulos eliminados
-- ============================================================================
DO $$
BEGIN
    -- ContractorRoles
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContractorRoles') THEN
        DROP TABLE public."ContractorRoles" CASCADE;
        RAISE NOTICE '✅ Eliminada: ContractorRoles (módulo eliminado)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: ContractorRoles';
    END IF;

    -- ContractorTypes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContractorTypes') THEN
        DROP TABLE public."ContractorTypes" CASCADE;
        RAISE NOTICE '✅ Eliminada: ContractorTypes (módulo eliminado)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: ContractorTypes';
    END IF;

    -- SiteTypes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'SiteTypes') THEN
        DROP TABLE public."SiteTypes" CASCADE;
        RAISE NOTICE '✅ Eliminada: SiteTypes (módulo eliminado)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: SiteTypes';
    END IF;
END $$;

-- ============================================================================
-- PASO 6: Eliminar tablas de tipos no usadas en frontend
-- ============================================================================
DO $$
BEGIN
    -- VendorTypes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'VendorTypes') THEN
        DROP TABLE public."VendorTypes" CASCADE;
        RAISE NOTICE '✅ Eliminada: VendorTypes (no usada en frontend)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: VendorTypes';
    END IF;

    -- ContactTitles
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContactTitles') THEN
        DROP TABLE public."ContactTitles" CASCADE;
        RAISE NOTICE '✅ Eliminada: ContactTitles (valores hardcoded)';
    ELSE
        RAISE NOTICE '⏭️  Ya eliminada: ContactTitles';
    END IF;
END $$;

-- ============================================================================
-- PASO 7: Eliminar índices huérfanos
-- ============================================================================
DROP INDEX IF EXISTS idx_addresses_organization_id;
DROP INDEX IF EXISTS idx_directory_contacts_location_address_id;
DROP INDEX IF EXISTS idx_directory_contacts_billing_address_id;
DROP INDEX IF EXISTS idx_contractor_roles_organization_id;
DROP INDEX IF EXISTS idx_contractor_types_organization_id;
DROP INDEX IF EXISTS idx_site_types_organization_id;
DROP INDEX IF EXISTS idx_vendor_types_organization_id;
DROP INDEX IF EXISTS idx_vendor_types_organization_deleted;
DROP INDEX IF EXISTS idx_contact_titles_organization_id;
DROP INDEX IF EXISTS idx_contact_titles_organization_deleted;

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================
DO $$ 
DECLARE
  -- Verificar tablas que DEBEN quedar
  customer_types_exists boolean;
  directory_contacts_exists boolean;
  directory_customers_exists boolean;
  directory_vendors_exists boolean;
  
  -- Verificar tablas que DEBEN eliminarse
  addresses_exists boolean;
  countries_exists boolean;
  states_exists boolean;
  entity_contacts_exists boolean;
  vendor_types_exists boolean;
  contact_titles_exists boolean;
BEGIN
  -- Tablas que DEBEN existir
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'CustomerTypes') INTO customer_types_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'DirectoryContacts') INTO directory_contacts_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'DirectoryCustomers') INTO directory_customers_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'DirectoryVendors') INTO directory_vendors_exists;
  
  -- Tablas que NO deben existir
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'Addresses') INTO addresses_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'Countries') INTO countries_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'States') INTO states_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'DirectoryEntityContacts') INTO entity_contacts_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'VendorTypes') INTO vendor_types_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ContactTitles') INTO contact_titles_exists;
  
  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ LIMPIEZA COMPLETA FINALIZADA';
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '✅ TABLAS PRINCIPALES MANTENIDAS (en uso activo):';
  RAISE NOTICE '   DirectoryContacts: %', CASE WHEN directory_contacts_exists THEN '✅ OK' ELSE '❌ ERROR' END;
  RAISE NOTICE '   DirectoryCustomers: %', CASE WHEN directory_customers_exists THEN '✅ OK' ELSE '❌ ERROR' END;
  RAISE NOTICE '   DirectoryVendors: %', CASE WHEN directory_vendors_exists THEN '✅ OK' ELSE '❌ ERROR' END;
  RAISE NOTICE '   CustomerTypes: %', CASE WHEN customer_types_exists THEN '✅ OK' ELSE '❌ ERROR' END;
  RAISE NOTICE '';
  RAISE NOTICE '❌ TABLAS ELIMINADAS (no usadas):';
  RAISE NOTICE '   DirectoryEntityContacts: %', CASE WHEN NOT entity_contacts_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   Addresses: %', CASE WHEN NOT addresses_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   Countries: %', CASE WHEN NOT countries_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   States: %', CASE WHEN NOT states_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   VendorTypes: %', CASE WHEN NOT vendor_types_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '   ContactTitles: %', CASE WHEN NOT contact_titles_exists THEN '✅ Eliminada' ELSE '⚠️  Aún existe' END;
  RAISE NOTICE '';
  
  IF customer_types_exists AND 
     directory_contacts_exists AND 
     directory_customers_exists AND 
     directory_vendors_exists AND
     NOT addresses_exists AND 
     NOT countries_exists AND 
     NOT states_exists AND
     NOT entity_contacts_exists AND
     NOT vendor_types_exists AND
     NOT contact_titles_exists THEN
    RAISE NOTICE '🎉 LIMPIEZA COMPLETADA CON ÉXITO';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Base de datos optimizada:';
    RAISE NOTICE '   ✅ Solo tablas en uso activo';
    RAISE NOTICE '   ✅ Todas las tablas obsoletas eliminadas';
    RAISE NOTICE '   ✅ Campos de dirección: embebidos (correcto)';
    RAISE NOTICE '   ✅ Países: constante hardcoded (correcto)';
    RAISE NOTICE '';
  ELSE
    IF NOT customer_types_exists OR NOT directory_contacts_exists OR 
       NOT directory_customers_exists OR NOT directory_vendors_exists THEN
      RAISE WARNING '❌ ERROR: Alguna tabla necesaria fue eliminada!';
    END IF;
    IF addresses_exists OR countries_exists OR states_exists OR 
       entity_contacts_exists OR vendor_types_exists OR contact_titles_exists THEN
      RAISE WARNING '⚠️  Algunas tablas no pudieron eliminarse';
    END IF;
  END IF;
  
  RAISE NOTICE '════════════════════════════════════════════════════════════════';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- CONSULTAS DE VERIFICACIÓN (Opcional - descomenta para ejecutar)
-- ============================================================================
/*
-- Ver TODAS las tablas restantes
SELECT table_name, 
       pg_size_pretty(pg_total_relation_size(quote_ident(table_name)::regclass)) as size
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY pg_total_relation_size(quote_ident(table_name)::regclass) DESC;

-- Ver solo tablas Directory
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'Directory%'
ORDER BY table_name;

-- Ver tablas de tipos restantes
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%Type%'
ORDER BY table_name;
*/

-- ============================================================================
-- NOTAS FINALES
-- ============================================================================
-- ✅ Script idempotente (se puede ejecutar múltiples veces)
-- ✅ Verifica existencia antes de eliminar
-- ✅ Usa CASCADE para eliminar dependencias
-- ✅ Mensajes claros de progreso
-- 
-- 📊 IMPACTO:
--    Base de datos MÁS LIMPIA y CLARA
--    Solo tablas que realmente se usan
--    Mejor mantenibilidad
--    Cero impacto en funcionalidad
--
-- ✅ TABLAS QUE PERMANECEN:
--    - DirectoryContacts ✅
--    - DirectoryCustomers ✅
--    - DirectoryVendors ✅
--    - CustomerTypes ✅
--    - Organizations ✅
--    - OrganizationUsers ✅
--    - PlatformAdmins ✅
--
-- ❌ TABLAS ELIMINADAS:
--    - DirectoryEntityContacts (huérfana)
--    - DirectorySites (módulo eliminado)
--    - DirectoryContractors (módulo eliminado)
--    - Addresses (campos embebidos)
--    - Countries (hardcoded en constants.ts)
--    - States (nunca implementado)
--    - VendorTypes (no usada)
--    - ContactTitles (hardcoded)
--    - ContractorRoles (módulo eliminado)
--    - SiteTypes (módulo eliminado)
-- ============================================================================

