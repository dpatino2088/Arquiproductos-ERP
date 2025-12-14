-- ====================================================
-- SCRIPT TEMPORAL: Deshabilitar RLS de OrganizationUsers
-- Esto permite que funcione sin restricciones
-- SOLO PARA DESARROLLO - NO USAR EN PRODUCCIÓN
-- ====================================================

-- Paso 1: Eliminar TODAS las políticas RLS
DROP POLICY IF EXISTS "organizationusers_select_own" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_select_org_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_own" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_delete_owners" ON "OrganizationUsers";

-- Eliminar cualquier otra política que exista
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'OrganizationUsers'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "OrganizationUsers"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Todas las políticas eliminadas';
END $$;

-- Paso 2: DESHABILITAR RLS completamente
ALTER TABLE "OrganizationUsers" DISABLE ROW LEVEL SECURITY;

-- Paso 3: Verificar que RLS está deshabilitado
SELECT 
    tablename,
    rowsecurity as "RLS Habilitado (debe ser false)"
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'OrganizationUsers';

-- Paso 4: Verificar que no hay políticas
SELECT 
    COUNT(*) as "Total Políticas (debe ser 0)"
FROM pg_policies 
WHERE tablename = 'OrganizationUsers';

DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ RLS DESHABILITADO EN OrganizationUsers';
    RAISE NOTICE '⚠️  ESTO ES TEMPORAL - SOLO PARA DESARROLLO';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Ahora prueba crear usuarios en la aplicación.';
    RAISE NOTICE 'Si funciona, ejecuta ENABLE_RLS_ORGANIZATION_USERS.sql';
    RAISE NOTICE 'para re-habilitar RLS con políticas correctas.';
    RAISE NOTICE '==============================================';
END $$;

