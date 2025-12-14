-- ====================================================
-- SOLUCIÓN SIMPLE: Deshabilitar RLS temporalmente
-- y verificar que todo funcione
-- ====================================================

-- ============================================================================
-- PASO 1: Deshabilitar RLS en OrganizationUsers
-- ============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Eliminar todas las políticas
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'OrganizationUsers'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "OrganizationUsers"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Políticas de OrganizationUsers eliminadas';
END $$;

-- Deshabilitar RLS
ALTER TABLE "OrganizationUsers" DISABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    RAISE NOTICE '✅ RLS deshabilitado en OrganizationUsers';
END $$;

-- ============================================================================
-- PASO 2: Verificar que DirectoryCustomers y DirectoryContacts tienen RLS habilitado
-- ============================================================================
DO $$
BEGIN
    -- Verificar DirectoryCustomers
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = 'DirectoryCustomers' 
        AND rowsecurity = true
    ) THEN
        ALTER TABLE "DirectoryCustomers" ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS habilitado en DirectoryCustomers';
    ELSE
        RAISE NOTICE '✅ DirectoryCustomers ya tiene RLS habilitado';
    END IF;

    -- Verificar DirectoryContacts
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = 'DirectoryContacts' 
        AND rowsecurity = true
    ) THEN
        ALTER TABLE "DirectoryContacts" ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS habilitado en DirectoryContacts';
    ELSE
        RAISE NOTICE '✅ DirectoryContacts ya tiene RLS habilitado';
    END IF;
END $$;

-- ============================================================================
-- PASO 3: Asegurar que hay políticas básicas para Directory tables
-- ============================================================================

-- Política simple para DirectoryCustomers: todos los miembros de la org pueden ver
DROP POLICY IF EXISTS "directory_customers_select_org_members" ON "DirectoryCustomers";
CREATE POLICY "directory_customers_select_org_members"
ON "DirectoryCustomers"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM "OrganizationUsers" ou
    WHERE ou.organization_id = "DirectoryCustomers".organization_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
  )
);

-- Política simple para DirectoryContacts: todos los miembros de la org pueden ver
DROP POLICY IF EXISTS "directory_contacts_select_org_members" ON "DirectoryContacts";
CREATE POLICY "directory_contacts_select_org_members"
ON "DirectoryContacts"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM "OrganizationUsers" ou
    WHERE ou.organization_id = "DirectoryContacts".organization_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
  )
);

DO $$ BEGIN
    RAISE NOTICE '✅ Políticas básicas de Directory creadas';
END $$;

-- ============================================================================
-- PASO 4: Verificar configuración final
-- ============================================================================
SELECT 
    'OrganizationUsers' as tabla,
    rowsecurity as "RLS Habilitado",
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'OrganizationUsers') as "Total Políticas"
FROM pg_tables
WHERE tablename = 'OrganizationUsers'

UNION ALL

SELECT 
    'DirectoryCustomers' as tabla,
    rowsecurity as "RLS Habilitado",
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'DirectoryCustomers') as "Total Políticas"
FROM pg_tables
WHERE tablename = 'DirectoryCustomers'

UNION ALL

SELECT 
    'DirectoryContacts' as tabla,
    rowsecurity as "RLS Habilitado",
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'DirectoryContacts') as "Total Políticas"
FROM pg_tables
WHERE tablename = 'DirectoryContacts';

DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ CONFIGURACIÓN COMPLETADA';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'OrganizationUsers: RLS DESHABILITADO (temporal)';
    RAISE NOTICE 'DirectoryCustomers: RLS HABILITADO con política básica';
    RAISE NOTICE 'DirectoryContacts: RLS HABILITADO con política básica';
    RAISE NOTICE '';
    RAISE NOTICE 'Ahora recarga la aplicación y prueba crear usuarios.';
    RAISE NOTICE '==============================================';
END $$;

