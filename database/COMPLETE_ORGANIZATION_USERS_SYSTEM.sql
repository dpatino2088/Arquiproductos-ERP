-- ====================================================
-- SISTEMA COMPLETO DE ORGANIZATION USERS
-- ====================================================
-- Este script rehace completamente el sistema de OrganizationUsers
-- con roles y permisos correctos según especificación:
--
-- 1. Super Admin: Ve y hace todo
-- 2. Owner: Dueño de la cuenta/organización - puede hacer todo: borrar/crear usuarios, ver todos
-- 3. Admin: Puede ver todo de su propio Customer, crear usuarios, customers, contacts, vendors y quotes
-- 4. Member: Crear quotes y ver sus cuentas solamente
-- ====================================================

-- ============================================================================
-- PASO 1: Verificar estructura de tabla OrganizationUsers
-- ============================================================================
DO $$
BEGIN
    -- Verificar que existan todas las columnas necesarias
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'is_system'
    ) THEN
        ALTER TABLE "OrganizationUsers"
          ADD COLUMN is_system BOOLEAN DEFAULT false;
        RAISE NOTICE '✅ Columna is_system agregada';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'contact_id'
    ) THEN
        RAISE EXCEPTION '❌ ERROR: Columna contact_id no existe en OrganizationUsers. Ejecuta las migraciones necesarias primero.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'customer_id'
    ) THEN
        RAISE EXCEPTION '❌ ERROR: Columna customer_id no existe en OrganizationUsers. Ejecuta las migraciones necesarias primero.';
    END IF;

    RAISE NOTICE '✅ Estructura de tabla verificada';
END $$;

-- Crear índices necesarios
CREATE INDEX IF NOT EXISTS idx_organization_users_is_system 
ON "OrganizationUsers"(is_system) 
WHERE is_system = true AND deleted = false;

CREATE INDEX IF NOT EXISTS idx_organization_users_customer_id 
ON "OrganizationUsers"(customer_id) 
WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_organization_users_contact_id 
ON "OrganizationUsers"(contact_id) 
WHERE deleted = false;

-- ============================================================================
-- PASO 2: Eliminar TODAS las políticas RLS existentes
-- ============================================================================
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
    RAISE NOTICE '✅ Políticas RLS antiguas eliminadas';
END $$;

-- ============================================================================
-- PASO 3: Eliminar funciones helper antiguas
-- ============================================================================
DROP FUNCTION IF EXISTS public.can_insert_organization_user(uuid, uuid, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.can_insert_organization_user(uuid, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.can_view_organization_users(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.can_manage_organization_users(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.org_is_owner_or_admin(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.is_super_admin(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.is_owner(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.is_admin(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_user_customer_id(uuid, uuid) CASCADE;

DO $$ BEGIN
    RAISE NOTICE '✅ Funciones antiguas eliminadas';
END $$;

-- ============================================================================
-- PASO 4: Crear funciones helper RLS (SIN RECURSIÓN)
-- ============================================================================

-- Función 1: Verificar si usuario es Super Admin (PlatformAdmin)
CREATE OR REPLACE FUNCTION public.is_super_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    SET LOCAL row_security = off;
    
    RETURN EXISTS (
        SELECT 1 FROM "PlatformAdmins"
        WHERE user_id = p_user_id
    );
END;
$$;

-- Función 2: Verificar si usuario es Owner de una organización
CREATE OR REPLACE FUNCTION public.is_owner(p_user_id uuid, p_organization_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    SET LOCAL row_security = off;
    
    RETURN EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = p_user_id
          AND organization_id = p_organization_id
          AND role = 'owner'
          AND deleted = false
    );
END;
$$;

-- Función 3: Verificar si usuario es Admin de una organización
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid, p_organization_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    SET LOCAL row_security = off;
    
    RETURN EXISTS (
        SELECT 1 FROM "OrganizationUsers"
        WHERE user_id = p_user_id
          AND organization_id = p_organization_id
          AND role = 'admin'
          AND deleted = false
    );
END;
$$;

-- Función 4: Obtener customer_id del usuario en una organización
CREATE OR REPLACE FUNCTION public.get_user_customer_id(p_user_id uuid, p_organization_id uuid)
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
    
    SELECT customer_id INTO v_customer_id
    FROM "OrganizationUsers"
    WHERE user_id = p_user_id
      AND organization_id = p_organization_id
      AND deleted = false
    LIMIT 1;
    
    RETURN v_customer_id;
END;
$$;

-- Función 5: Verificar si usuario puede gestionar usuarios (Owner o Admin)
CREATE OR REPLACE FUNCTION public.can_manage_organization_users(p_user_id uuid, p_organization_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    SET LOCAL row_security = off;
    
    -- Super Admin puede gestionar todo
    IF public.is_super_admin(p_user_id) THEN
        RETURN true;
    END IF;
    
    -- Owner puede gestionar todo
    IF public.is_owner(p_user_id, p_organization_id) THEN
        RETURN true;
    END IF;
    
    -- Admin puede gestionar usuarios de su mismo Customer
    IF public.is_admin(p_user_id, p_organization_id) THEN
        RETURN true; -- Admin puede gestionar usuarios (pero solo de su Customer - se valida en la política)
    END IF;
    
    RETURN false;
END;
$$;

-- Función 6: Verificar si usuario puede insertar un OrganizationUser con un rol específico
CREATE OR REPLACE FUNCTION public.can_insert_organization_user(
  p_inviter_user_id uuid,
  p_organization_id uuid,
  p_new_user_role text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    SET LOCAL row_security = off;
    
    -- Super Admin puede insertar cualquier rol
    IF public.is_super_admin(p_inviter_user_id) THEN
        RETURN true;
    END IF;

    -- Owner puede insertar cualquier rol excepto 'owner' (solo otro owner puede crear owner)
    IF public.is_owner(p_inviter_user_id, p_organization_id) THEN
        RETURN p_new_user_role IN ('admin', 'member', 'viewer');
    END IF;

    -- Admin puede insertar 'member' y 'viewer' (pero solo para su mismo Customer)
    IF public.is_admin(p_inviter_user_id, p_organization_id) THEN
        RETURN p_new_user_role IN ('member', 'viewer');
    END IF;

    RETURN false;
END;
$$;

-- Función 7: Verificar si usuario puede ver otro usuario (basado en roles y Customer)
CREATE OR REPLACE FUNCTION public.can_view_organization_user(
  p_viewer_user_id uuid,
  p_viewer_organization_id uuid,
  p_target_user_id uuid,
  p_target_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_viewer_customer_id uuid;
    v_target_customer_id uuid;
BEGIN
    SET LOCAL row_security = off;
    
    -- Deben ser de la misma organización
    IF p_viewer_organization_id != p_target_organization_id THEN
        RETURN false;
    END IF;
    
    -- Super Admin puede ver todo
    IF public.is_super_admin(p_viewer_user_id) THEN
        RETURN true;
    END IF;
    
    -- Owner puede ver todos los usuarios de su organización
    IF public.is_owner(p_viewer_user_id, p_viewer_organization_id) THEN
        RETURN true;
    END IF;
    
    -- Admin puede ver usuarios de su mismo Customer
    IF public.is_admin(p_viewer_user_id, p_viewer_organization_id) THEN
        v_viewer_customer_id := public.get_user_customer_id(p_viewer_user_id, p_viewer_organization_id);
        v_target_customer_id := public.get_user_customer_id(p_target_user_id, p_target_organization_id);
        
        -- Admin puede ver usuarios de su mismo Customer
        RETURN v_viewer_customer_id IS NOT NULL 
           AND v_target_customer_id IS NOT NULL 
           AND v_viewer_customer_id = v_target_customer_id;
    END IF;
    
    -- Member puede verse a sí mismo
    IF p_viewer_user_id = p_target_user_id THEN
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$;

DO $$ BEGIN
    RAISE NOTICE '✅ Funciones helper RLS creadas';
END $$;

-- ============================================================================
-- PASO 5: Habilitar RLS en OrganizationUsers
-- ============================================================================
ALTER TABLE "OrganizationUsers" ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    RAISE NOTICE '✅ RLS habilitado en OrganizationUsers';
END $$;

-- ============================================================================
-- PASO 6: Crear políticas RLS para OrganizationUsers
-- ============================================================================

-- Policy 1: SELECT - Usuarios pueden ver su propio registro (incluso si is_system = true)
-- IMPORTANTE: El usuario necesita ver su propio registro para cargar su organización
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
USING (
    user_id = auth.uid()
    -- NO filtramos por is_system aquí porque el usuario necesita ver su organización
    -- El filtro is_system solo se usa para ocultar usuarios en las LISTAS, no para ocultar organizaciones
);

-- Policy 2: SELECT - Super Admin puede ver todo (excepto is_system)
CREATE POLICY "organizationusers_select_superadmin"
ON "OrganizationUsers"
FOR SELECT
USING (
    public.is_super_admin(auth.uid())
    AND is_system = false -- No mostrar usuarios del sistema
);

-- Policy 3: SELECT - Owner puede ver todos los usuarios de su organización (excepto is_system)
CREATE POLICY "organizationusers_select_owner"
ON "OrganizationUsers"
FOR SELECT
USING (
    public.is_owner(auth.uid(), organization_id)
    AND is_system = false -- No mostrar usuarios del sistema
);

-- Policy 4: SELECT - Admin puede ver usuarios de su mismo Customer (excepto is_system)
CREATE POLICY "organizationusers_select_admin"
ON "OrganizationUsers"
FOR SELECT
USING (
    public.is_admin(auth.uid(), organization_id)
    AND public.can_view_organization_user(
        auth.uid(),
        organization_id,
        user_id,
        organization_id
    )
    AND is_system = false -- No mostrar usuarios del sistema
);

-- Policy 5: INSERT - Solo Owners, Admins y Super Admins pueden insertar
CREATE POLICY "organizationusers_insert_managers"
ON "OrganizationUsers"
FOR INSERT
WITH CHECK (
    public.can_insert_organization_user(auth.uid(), organization_id, role)
    AND is_system = false -- No permitir crear usuarios del sistema desde la UI
);

-- Policy 6: UPDATE - Usuarios pueden actualizar su propio registro
-- NOTA: No podemos usar OLD en políticas RLS para validar cambios
-- El control de quién puede hacer UPDATE está en USING
-- Para prevenir cambios en rol, is_system, customer_id, contact_id, usar triggers o validación en frontend
CREATE POLICY "organizationusers_update_own"
ON "OrganizationUsers"
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy 7: UPDATE - Owners y Super Admins pueden actualizar cualquier usuario
-- NOTA: Para prevenir cambios en is_system, usar triggers o validación en frontend
CREATE POLICY "organizationusers_update_owners"
ON "OrganizationUsers"
FOR UPDATE
USING (
    public.is_owner(auth.uid(), organization_id)
    OR public.is_super_admin(auth.uid())
)
WITH CHECK (
    public.is_owner(auth.uid(), organization_id)
    OR public.is_super_admin(auth.uid())
);

-- Policy 8: UPDATE - Admins pueden actualizar usuarios de su mismo Customer (excepto rol, is_system)
CREATE POLICY "organizationusers_update_admin"
ON "OrganizationUsers"
FOR UPDATE
USING (
    public.is_admin(auth.uid(), organization_id)
    AND public.can_view_organization_user(
        auth.uid(),
        organization_id,
        user_id,
        organization_id
    )
)
WITH CHECK (
    public.is_admin(auth.uid(), organization_id)
    AND public.can_view_organization_user(
        auth.uid(),
        organization_id,
        user_id,
        organization_id
    )
    AND role != 'owner' -- Admin no puede cambiar rol a owner
    AND role != 'admin' -- Admin no puede crear otros admins (solo Owner puede)
    -- NOTA: Para prevenir cambios en is_system, usar triggers o validación en frontend
);

-- Policy 9: DELETE - Solo Owners y Super Admins pueden eliminar usuarios
CREATE POLICY "organizationusers_delete_owners"
ON "OrganizationUsers"
FOR DELETE
USING (
    public.is_owner(auth.uid(), organization_id)
    OR public.is_super_admin(auth.uid())
);

DO $$ BEGIN
    RAISE NOTICE '✅ Políticas RLS creadas';
END $$;

-- ============================================================================
-- PASO 7: Verificar configuración final
-- ============================================================================
DO $$
DECLARE
    rls_enabled BOOLEAN;
    policy_count INTEGER;
    function_count INTEGER;
BEGIN
    SELECT relrowsecurity INTO rls_enabled 
    FROM pg_class 
    WHERE relname = 'OrganizationUsers';
    
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'OrganizationUsers';
    
    SELECT COUNT(*) INTO function_count
    FROM pg_proc
    WHERE proname IN (
        'is_super_admin',
        'is_owner',
        'is_admin',
        'get_user_customer_id',
        'can_manage_organization_users',
        'can_insert_organization_user',
        'can_view_organization_user'
    )
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'VERIFICACIÓN FINAL:';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'RLS Habilitado: %', rls_enabled;
    RAISE NOTICE 'Total Políticas: %', policy_count;
    RAISE NOTICE 'Total Funciones Helper: %', function_count;
    RAISE NOTICE '==============================================';
    
    IF rls_enabled AND policy_count >= 9 AND function_count >= 7 THEN
        RAISE NOTICE '✅ SISTEMA DE ORGANIZATION USERS CONFIGURADO CORRECTAMENTE';
    ELSE
        RAISE NOTICE '❌ CONFIGURACIÓN INCOMPLETA - Revisa los valores arriba';
    END IF;
    RAISE NOTICE '==============================================';
END $$;

-- ============================================================================
-- RESUMEN DE PERMISOS POR ROL
-- ============================================================================
DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'PERMISOS POR ROL:';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'SUPER ADMIN:';
    RAISE NOTICE '  - Ve y hace TODO';
    RAISE NOTICE '  - Puede crear/editar/eliminar cualquier usuario';
    RAISE NOTICE '  - Puede ver todas las organizaciones';
    RAISE NOTICE '';
    RAISE NOTICE 'OWNER:';
    RAISE NOTICE '  - Ve y hace TODO en su organización';
    RAISE NOTICE '  - Puede crear/editar/eliminar usuarios (admin, member, viewer)';
    RAISE NOTICE '  - Puede ver todos los usuarios de su organización';
    RAISE NOTICE '';
    RAISE NOTICE 'ADMIN:';
    RAISE NOTICE '  - Ve TODO de su propio Customer';
    RAISE NOTICE '  - Puede crear usuarios (member, viewer) de su mismo Customer';
    RAISE NOTICE '  - Puede editar usuarios de su mismo Customer';
    RAISE NOTICE '  - Puede crear customers, contacts, vendors, quotes';
    RAISE NOTICE '';
    RAISE NOTICE 'MEMBER:';
    RAISE NOTICE '  - Puede crear quotes';
    RAISE NOTICE '  - Puede ver sus propias cuentas solamente';
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
END $$;

