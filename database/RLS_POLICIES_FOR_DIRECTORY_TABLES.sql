-- ====================================================
-- POLÍTICAS RLS PARA TABLAS DE DIRECTORY
-- ====================================================
-- Este script crea políticas RLS para DirectoryCustomers, DirectoryContacts,
-- DirectoryVendors basadas en los roles de OrganizationUsers:
--
-- - Super Admin: Ve y hace todo
-- - Owner: Ve y hace todo en su organización
-- - Admin: Ve y hace todo de su propio Customer
-- - Member: Ve solo sus propias cuentas
-- ====================================================

-- ============================================================================
-- PASO 0: Verificar y agregar columnas necesarias
-- ============================================================================
DO $$
BEGIN
    -- Verificar/agregar primary_contact_id a DirectoryVendors
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'DirectoryVendors' 
        AND column_name = 'primary_contact_id'
    ) THEN
        ALTER TABLE "DirectoryVendors"
          ADD COLUMN primary_contact_id uuid;
        
        -- Agregar foreign key constraint si no existe
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'directoryvendors_primary_contact_id_fkey'
        ) THEN
            ALTER TABLE "DirectoryVendors"
            ADD CONSTRAINT directoryvendors_primary_contact_id_fkey
            FOREIGN KEY (primary_contact_id) 
            REFERENCES "DirectoryContacts"(id) 
            ON UPDATE CASCADE 
            ON DELETE RESTRICT;
        END IF;
        
        -- Crear índice
        CREATE INDEX IF NOT EXISTS idx_directory_vendors_primary_contact_id 
        ON "DirectoryVendors"(primary_contact_id);
        
        RAISE NOTICE '✅ Columna primary_contact_id agregada a DirectoryVendors';
    ELSE
        RAISE NOTICE '✅ Columna primary_contact_id ya existe en DirectoryVendors';
    END IF;
END $$;

-- ============================================================================
-- FUNCIONES HELPER PARA DIRECTORY TABLES
-- ============================================================================

-- Función: Obtener customer_id del usuario actual en una organización
CREATE OR REPLACE FUNCTION public.get_current_user_customer_id(p_organization_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_customer_id uuid;
BEGIN
    SET LOCAL row_security = off;
    
    -- Super Admin no tiene customer_id (ve todo)
    IF public.is_super_admin(auth.uid()) THEN
        RETURN NULL; -- NULL significa "ver todo"
    END IF;
    
    SELECT customer_id INTO v_customer_id
    FROM "OrganizationUsers"
    WHERE user_id = auth.uid()
      AND organization_id = p_organization_id
      AND deleted = false
    LIMIT 1;
    
    RETURN v_customer_id;
END;
$$;

-- Función: Verificar si usuario puede ver/editar un Customer
CREATE OR REPLACE FUNCTION public.can_access_customer(
    p_customer_id uuid,
    p_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_customer_id uuid;
    v_user_role text;
BEGIN
    SET LOCAL row_security = off;
    
    -- Super Admin puede acceder a todo
    IF public.is_super_admin(auth.uid()) THEN
        RETURN true;
    END IF;
    
    -- Obtener rol y customer_id del usuario
    SELECT role, customer_id INTO v_user_role, v_user_customer_id
    FROM "OrganizationUsers"
    WHERE user_id = auth.uid()
      AND organization_id = p_organization_id
      AND deleted = false
    LIMIT 1;
    
    -- Owner puede acceder a todos los Customers de su organización
    IF v_user_role = 'owner' THEN
        RETURN true;
    END IF;
    
    -- Admin puede acceder solo a su propio Customer
    IF v_user_role = 'admin' THEN
        RETURN v_user_customer_id IS NOT NULL 
           AND v_user_customer_id = p_customer_id;
    END IF;
    
    -- Member puede acceder solo a su propio Customer
    IF v_user_role = 'member' THEN
        RETURN v_user_customer_id IS NOT NULL 
           AND v_user_customer_id = p_customer_id;
    END IF;
    
    -- Viewer no puede editar, solo ver (se maneja en políticas específicas)
    IF v_user_role = 'viewer' THEN
        RETURN v_user_customer_id IS NOT NULL 
           AND v_user_customer_id = p_customer_id;
    END IF;
    
    RETURN false;
END;
$$;

-- ============================================================================
-- DIRECTORYCUSTOMERS - POLÍTICAS RLS
-- ============================================================================

-- Eliminar políticas existentes
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'DirectoryCustomers'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "DirectoryCustomers"', pol.policyname);
    END LOOP;
END $$;

-- Habilitar RLS
ALTER TABLE "DirectoryCustomers" ENABLE ROW LEVEL SECURITY;

-- SELECT: Super Admin ve todo
CREATE POLICY "directorycustomers_select_superadmin"
ON "DirectoryCustomers"
FOR SELECT
USING (
    public.is_super_admin(auth.uid())
);

-- SELECT: Owner ve todos los Customers de su organización
CREATE POLICY "directorycustomers_select_owner"
ON "DirectoryCustomers"
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryCustomers".organization_id
          AND role = 'owner'
          AND deleted = false
    )
);

-- SELECT: Admin y Member ven solo su propio Customer
CREATE POLICY "directorycustomers_select_admin_member"
ON "DirectoryCustomers"
FOR SELECT
USING (
    public.can_access_customer(id, organization_id)
);

-- INSERT: Super Admin, Owner y Admin pueden crear Customers
CREATE POLICY "directorycustomers_insert_managers"
ON "DirectoryCustomers"
FOR INSERT
WITH CHECK (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryCustomers".organization_id
          AND role IN ('owner', 'admin')
          AND deleted = false
    )
);

-- UPDATE: Super Admin, Owner y Admin pueden actualizar Customers
CREATE POLICY "directorycustomers_update_managers"
ON "DirectoryCustomers"
FOR UPDATE
USING (
    public.is_super_admin(auth.uid())
    OR public.can_access_customer(id, organization_id)
)
WITH CHECK (
    public.is_super_admin(auth.uid())
    OR public.can_access_customer(id, organization_id)
);

-- DELETE: Solo Super Admin y Owner pueden eliminar Customers
CREATE POLICY "directorycustomers_delete_owners"
ON "DirectoryCustomers"
FOR DELETE
USING (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryCustomers".organization_id
          AND role = 'owner'
          AND deleted = false
    )
);

-- ============================================================================
-- DIRECTORYCONTACTS - POLÍTICAS RLS
-- ============================================================================

-- Eliminar políticas existentes
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'DirectoryContacts'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "DirectoryContacts"', pol.policyname);
    END LOOP;
END $$;

-- Habilitar RLS
ALTER TABLE "DirectoryContacts" ENABLE ROW LEVEL SECURITY;

-- SELECT: Super Admin ve todo
CREATE POLICY "directorycontacts_select_superadmin"
ON "DirectoryContacts"
FOR SELECT
USING (
    public.is_super_admin(auth.uid())
);

-- SELECT: Owner ve todos los Contacts de su organización
CREATE POLICY "directorycontacts_select_owner"
ON "DirectoryContacts"
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryContacts".organization_id
          AND role = 'owner'
          AND deleted = false
    )
);

-- SELECT: Admin y Member ven Contacts de su propio Customer
CREATE POLICY "directorycontacts_select_admin_member"
ON "DirectoryContacts"
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM "DirectoryCustomers" dc
        WHERE dc.id = "DirectoryContacts".customer_id
          AND public.can_access_customer(dc.id, dc.organization_id)
    )
    OR customer_id IS NULL -- Contacts sin customer (standalone) - solo Owner y Super Admin
);

-- INSERT: Super Admin, Owner y Admin pueden crear Contacts
CREATE POLICY "directorycontacts_insert_managers"
ON "DirectoryContacts"
FOR INSERT
WITH CHECK (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryContacts".organization_id
          AND role IN ('owner', 'admin')
          AND deleted = false
    )
);

-- UPDATE: Super Admin, Owner y Admin pueden actualizar Contacts
CREATE POLICY "directorycontacts_update_managers"
ON "DirectoryContacts"
FOR UPDATE
USING (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "DirectoryCustomers" dc
        WHERE dc.id = "DirectoryContacts".customer_id
          AND public.can_access_customer(dc.id, dc.organization_id)
    )
    OR (customer_id IS NULL AND EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryContacts".organization_id
          AND role = 'owner'
          AND deleted = false
    ))
)
WITH CHECK (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "DirectoryCustomers" dc
        WHERE dc.id = "DirectoryContacts".customer_id
          AND public.can_access_customer(dc.id, dc.organization_id)
    )
    OR (customer_id IS NULL AND EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryContacts".organization_id
          AND role = 'owner'
          AND deleted = false
    ))
);

-- DELETE: Solo Super Admin y Owner pueden eliminar Contacts
CREATE POLICY "directorycontacts_delete_owners"
ON "DirectoryContacts"
FOR DELETE
USING (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryContacts".organization_id
          AND role = 'owner'
          AND deleted = false
    )
);

-- ============================================================================
-- DIRECTORYVENDORS - POLÍTICAS RLS
-- ============================================================================

-- Eliminar políticas existentes
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'DirectoryVendors'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "DirectoryVendors"', pol.policyname);
    END LOOP;
END $$;

-- Habilitar RLS
ALTER TABLE "DirectoryVendors" ENABLE ROW LEVEL SECURITY;

-- SELECT: Super Admin ve todo
CREATE POLICY "directoryvendors_select_superadmin"
ON "DirectoryVendors"
FOR SELECT
USING (
    public.is_super_admin(auth.uid())
);

-- SELECT: Owner ve todos los Vendors de su organización
CREATE POLICY "directoryvendors_select_owner"
ON "DirectoryVendors"
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryVendors".organization_id
          AND role = 'owner'
          AND deleted = false
    )
);

-- SELECT: Admin y Member ven Vendors de su propio Customer
CREATE POLICY "directoryvendors_select_admin_member"
ON "DirectoryVendors"
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM "DirectoryContacts" dcon
        JOIN "DirectoryCustomers" dc ON dc.id = dcon.customer_id
        WHERE dcon.id = "DirectoryVendors".primary_contact_id
          AND public.can_access_customer(dc.id, dc.organization_id)
    )
);

-- INSERT: Super Admin, Owner y Admin pueden crear Vendors
CREATE POLICY "directoryvendors_insert_managers"
ON "DirectoryVendors"
FOR INSERT
WITH CHECK (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryVendors".organization_id
          AND role IN ('owner', 'admin')
          AND deleted = false
    )
);

-- UPDATE: Super Admin, Owner y Admin pueden actualizar Vendors
CREATE POLICY "directoryvendors_update_managers"
ON "DirectoryVendors"
FOR UPDATE
USING (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "DirectoryContacts" dcon
        JOIN "DirectoryCustomers" dc ON dc.id = dcon.customer_id
        WHERE dcon.id = "DirectoryVendors".primary_contact_id
          AND public.can_access_customer(dc.id, dc.organization_id)
    )
)
WITH CHECK (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "DirectoryContacts" dcon
        JOIN "DirectoryCustomers" dc ON dc.id = dcon.customer_id
        WHERE dcon.id = "DirectoryVendors".primary_contact_id
          AND public.can_access_customer(dc.id, dc.organization_id)
    )
);

-- DELETE: Solo Super Admin y Owner pueden eliminar Vendors
CREATE POLICY "directoryvendors_delete_owners"
ON "DirectoryVendors"
FOR DELETE
USING (
    public.is_super_admin(auth.uid())
    OR EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = auth.uid()
          AND organization_id = "DirectoryVendors".organization_id
          AND role = 'owner'
          AND deleted = false
    )
);

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================
DO $$
DECLARE
    customers_policies INTEGER;
    contacts_policies INTEGER;
    vendors_policies INTEGER;
BEGIN
    SELECT COUNT(*) INTO customers_policies 
    FROM pg_policies 
    WHERE tablename = 'DirectoryCustomers';
    
    SELECT COUNT(*) INTO contacts_policies 
    FROM pg_policies 
    WHERE tablename = 'DirectoryContacts';
    
    SELECT COUNT(*) INTO vendors_policies 
    FROM pg_policies 
    WHERE tablename = 'DirectoryVendors';
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'POLÍTICAS RLS PARA DIRECTORY TABLES:';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DirectoryCustomers: % políticas', customers_policies;
    RAISE NOTICE 'DirectoryContacts: % políticas', contacts_policies;
    RAISE NOTICE 'DirectoryVendors: % políticas', vendors_policies;
    RAISE NOTICE '==============================================';
    
    IF customers_policies >= 6 AND contacts_policies >= 6 AND vendors_policies >= 6 THEN
        RAISE NOTICE '✅ POLÍTICAS RLS CONFIGURADAS CORRECTAMENTE';
    ELSE
        RAISE NOTICE '❌ CONFIGURACIÓN INCOMPLETA';
    END IF;
    RAISE NOTICE '==============================================';
END $$;

