-- ====================================================
-- DESHABILITAR RLS TEMPORALMENTE EN TODAS LAS TABLAS
-- SOLO PARA DESARROLLO - NO USAR EN PRODUCCIÓN
-- ====================================================

-- ============================================================================
-- PASO 1: Deshabilitar RLS en OrganizationUsers
-- ============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Eliminar todas las políticas de OrganizationUsers
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'OrganizationUsers'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "OrganizationUsers"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Políticas de OrganizationUsers eliminadas';
END $$;

ALTER TABLE "OrganizationUsers" DISABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    RAISE NOTICE '✅ RLS deshabilitado en OrganizationUsers';
END $$;

-- ============================================================================
-- PASO 2: Deshabilitar RLS en DirectoryCustomers
-- ============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Eliminar todas las políticas de DirectoryCustomers
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'DirectoryCustomers'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "DirectoryCustomers"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Políticas de DirectoryCustomers eliminadas';
END $$;

ALTER TABLE "DirectoryCustomers" DISABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    RAISE NOTICE '✅ RLS deshabilitado en DirectoryCustomers';
END $$;

-- ============================================================================
-- PASO 3: Deshabilitar RLS en DirectoryContacts
-- ============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Eliminar todas las políticas de DirectoryContacts
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'DirectoryContacts'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "DirectoryContacts"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Políticas de DirectoryContacts eliminadas';
END $$;

ALTER TABLE "DirectoryContacts" DISABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    RAISE NOTICE '✅ RLS deshabilitado en DirectoryContacts';
END $$;

-- ============================================================================
-- PASO 4: Deshabilitar RLS en DirectoryVendors
-- ============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Eliminar todas las políticas de DirectoryVendors
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'DirectoryVendors'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "DirectoryVendors"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Políticas de DirectoryVendors eliminadas';
END $$;

ALTER TABLE "DirectoryVendors" DISABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    RAISE NOTICE '✅ RLS deshabilitado en DirectoryVendors';
END $$;

-- ============================================================================
-- PASO 5: Verificar configuración
-- ============================================================================
SELECT 
    tablename as "Tabla",
    rowsecurity as "RLS Habilitado (debe ser false)",
    (SELECT COUNT(*) FROM pg_policies p WHERE p.tablename = t.tablename) as "Total Políticas (debe ser 0)"
FROM pg_tables t
WHERE schemaname = 'public' 
  AND tablename IN (
    'OrganizationUsers',
    'DirectoryCustomers',
    'DirectoryContacts',
    'DirectoryVendors'
  )
ORDER BY tablename;

DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ RLS DESHABILITADO EN TODAS LAS TABLAS';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '⚠️  ESTO ES TEMPORAL - SOLO PARA DESARROLLO';
    RAISE NOTICE '';
    RAISE NOTICE 'Ahora recarga la aplicación y prueba:';
    RAISE NOTICE '1. Ver lista de Customers en Add Organization User';
    RAISE NOTICE '2. Crear un nuevo usuario';
    RAISE NOTICE '3. Ver la lista de Organization Users';
    RAISE NOTICE '';
    RAISE NOTICE 'Si todo funciona, crearemos políticas RLS';
    RAISE NOTICE 'simples y correctas.';
    RAISE NOTICE '==============================================';
END $$;

