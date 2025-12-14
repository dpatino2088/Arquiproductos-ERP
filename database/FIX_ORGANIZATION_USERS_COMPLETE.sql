-- ====================================================
-- SCRIPT COMPLETO: Reparar OrganizationUsers y RLS
-- Ejecuta este script completo en Supabase SQL Editor
-- ====================================================

-- ============================================================================
-- PASO 1: Verificar y agregar columna is_system
-- ============================================================================
DO $$ 
BEGIN
    -- Agregar columna is_system si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'is_system'
    ) THEN
        ALTER TABLE "OrganizationUsers"
          ADD COLUMN is_system BOOLEAN DEFAULT false;
        
        RAISE NOTICE '✅ Columna is_system agregada';
    ELSE
        RAISE NOTICE '✅ Columna is_system ya existe';
    END IF;

    -- Crear índice si no existe
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_organization_users_is_system'
    ) THEN
        CREATE INDEX idx_organization_users_is_system 
        ON "OrganizationUsers"(is_system) 
        WHERE is_system = true AND deleted = false;
        
        RAISE NOTICE '✅ Índice creado';
    ELSE
        RAISE NOTICE '✅ Índice ya existe';
    END IF;
END $$;

-- Marcar usuarios del sistema
DO $$
BEGIN
    UPDATE "OrganizationUsers"
    SET is_system = true
    WHERE email IN ('dpatino@arquiluz.studio', 'dpatino@grupo927.com')
      AND deleted = false;
    
    RAISE NOTICE '✅ Usuarios del sistema marcados';
END $$;

-- ============================================================================
-- PASO 2: Eliminar políticas RLS antiguas PRIMERO
-- ============================================================================
DO $$ BEGIN
    DROP POLICY IF EXISTS "organizationusers_select_own" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_select_org_admins" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_update_own" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_delete_owners" ON "OrganizationUsers";

    RAISE NOTICE '✅ Políticas antiguas eliminadas';
END $$;

-- ============================================================================
-- PASO 3: Eliminar funciones antiguas
-- ============================================================================
DROP FUNCTION IF EXISTS public.can_insert_organization_user(uuid, uuid, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.can_insert_organization_user(uuid, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.can_view_organization_users(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.can_manage_organization_users(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.org_is_owner_or_admin(uuid, uuid) CASCADE;

DO $$ BEGIN
    RAISE NOTICE '✅ Funciones antiguas eliminadas';
END $$;

-- ============================================================================
-- PASO 4: Crear funciones helper para RLS (SIN RECURSIÓN)
-- ============================================================================

-- Función 1: Verificar si usuario puede insertar en OrganizationUsers
CREATE OR REPLACE FUNCTION public.can_insert_organization_user(
  p_user_id uuid,
  p_organization_id uuid,
  p_new_role text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_user_role text;
  v_is_platform_admin boolean;
BEGIN
  -- CRÍTICO: Deshabilitar RLS para esta función
  SET LOCAL row_security = off;
  
  -- Verificar si es Platform Admin
  SELECT EXISTS (
    SELECT 1 FROM "PlatformAdmins"
    WHERE user_id = p_user_id
  ) INTO v_is_platform_admin;
  
  -- Platform Admins pueden crear cualquier usuario
  IF v_is_platform_admin THEN
    RETURN true;
  END IF;
  
  -- Obtener el rol del usuario en la organización
  SELECT role INTO v_user_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  -- Si no tiene rol, no puede crear usuarios
  IF v_user_role IS NULL THEN
    RETURN false;
  END IF;
  
  -- Owners pueden crear cualquier rol
  IF v_user_role = 'owner' THEN
    RETURN true;
  END IF;
  
  -- Admins pueden crear admin, member, viewer (pero no owner)
  IF v_user_role = 'admin' AND p_new_role != 'owner' THEN
    RETURN true;
  END IF;
  
  -- Otros roles no pueden crear usuarios
  RETURN false;
END;
$$;

-- Función 2: Verificar si usuario puede ver miembros de la organización
CREATE OR REPLACE FUNCTION public.can_view_organization_users(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_has_role boolean;
  v_is_platform_admin boolean;
BEGIN
  -- CRÍTICO: Deshabilitar RLS para esta función
  SET LOCAL row_security = off;
  
  -- Verificar si es Platform Admin
  SELECT EXISTS (
    SELECT 1 FROM "PlatformAdmins"
    WHERE user_id = p_user_id
  ) INTO v_is_platform_admin;
  
  IF v_is_platform_admin THEN
    RETURN true;
  END IF;
  
  -- Verificar si el usuario pertenece a la organización
  SELECT EXISTS (
    SELECT 1 FROM "OrganizationUsers"
    WHERE user_id = p_user_id
      AND organization_id = p_organization_id
      AND deleted = false
      AND role IN ('owner', 'admin', 'member', 'viewer')
  ) INTO v_has_role;
  
  RETURN v_has_role;
END;
$$;

-- Función 3: Verificar si usuario puede gestionar usuarios
CREATE OR REPLACE FUNCTION public.can_manage_organization_users(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_user_role text;
  v_is_platform_admin boolean;
BEGIN
  -- CRÍTICO: Deshabilitar RLS para esta función
  SET LOCAL row_security = off;
  
  -- Verificar si es Platform Admin
  SELECT EXISTS (
    SELECT 1 FROM "PlatformAdmins"
    WHERE user_id = p_user_id
  ) INTO v_is_platform_admin;
  
  IF v_is_platform_admin THEN
    RETURN true;
  END IF;
  
  -- Obtener el rol del usuario
  SELECT role INTO v_user_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  -- Solo owners pueden gestionar usuarios
  RETURN v_user_role = 'owner';
END;
$$;

-- Función auxiliar: Verificar si usuario es owner o admin
CREATE OR REPLACE FUNCTION public.org_is_owner_or_admin(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_user_role text;
BEGIN
  -- CRÍTICO: Deshabilitar RLS para esta función
  SET LOCAL row_security = off;
  
  SELECT role INTO v_user_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  RETURN v_user_role IN ('owner', 'admin');
END;
$$;

DO $$ BEGIN
    RAISE NOTICE '✅ Funciones helper creadas';
END $$;

-- ============================================================================
-- PASO 5: Crear políticas RLS nuevas (AHORA SIN DEPENDENCIAS)
-- ============================================================================

-- Política 1: SELECT - Usuarios pueden ver su propio registro
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
USING (user_id = auth.uid());

-- Política 2: SELECT - Miembros de la organización pueden ver otros miembros
CREATE POLICY "organizationusers_select_org_admins"
ON "OrganizationUsers"
FOR SELECT
USING (
  public.can_view_organization_users(auth.uid(), organization_id)
);

-- Política 3: INSERT - Solo Owners/Admins pueden invitar usuarios
CREATE POLICY "organizationusers_insert_owners_admins"
ON "OrganizationUsers"
FOR INSERT
WITH CHECK (
  public.can_insert_organization_user(
    auth.uid(),
    organization_id,
    role
  )
);

-- Política 4: UPDATE - Usuarios pueden actualizar su propio registro (excepto rol)
CREATE POLICY "organizationusers_update_own"
ON "OrganizationUsers"
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (
  user_id = auth.uid()
  AND role = (SELECT role FROM "OrganizationUsers" WHERE id = "OrganizationUsers".id)
);

-- Política 5: UPDATE - Owners pueden actualizar cualquier usuario
CREATE POLICY "organizationusers_update_owners"
ON "OrganizationUsers"
FOR UPDATE
USING (
  public.can_manage_organization_users(auth.uid(), organization_id)
)
WITH CHECK (
  public.can_manage_organization_users(auth.uid(), organization_id)
);

-- Política 6: DELETE - Solo Owners pueden eliminar usuarios
CREATE POLICY "organizationusers_delete_owners"
ON "OrganizationUsers"
FOR DELETE
USING (
  public.can_manage_organization_users(auth.uid(), organization_id)
);

DO $$ BEGIN
    RAISE NOTICE '✅ Políticas RLS creadas';
END $$;

-- ============================================================================
-- PASO 6: Habilitar RLS si no está habilitado
-- ============================================================================

-- Verificar que RLS está habilitado
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'OrganizationUsers' 
        AND rowsecurity = true
    ) THEN
        ALTER TABLE "OrganizationUsers" ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS habilitado';
    ELSE
        RAISE NOTICE '✅ RLS ya estaba habilitado';
    END IF;
END $$;

-- ============================================================================
-- PASO 7: Verificar y mostrar resumen final
-- ============================================================================
DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ CONFIGURACIÓN COMPLETADA';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
END $$;

-- Mostrar resumen de políticas
SELECT 
    'Políticas RLS activas' as categoria,
    COUNT(*) as total
FROM pg_policies 
WHERE tablename = 'OrganizationUsers';

-- Mostrar resumen de funciones
SELECT 
    'Funciones helper activas' as categoria,
    COUNT(*) as total
FROM pg_proc 
WHERE proname IN (
    'can_insert_organization_user',
    'can_view_organization_users',
    'can_manage_organization_users',
    'org_is_owner_or_admin'
);

-- Mostrar columnas de la tabla
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'OrganizationUsers'
  AND column_name IN ('id', 'organization_id', 'user_id', 'role', 'contact_id', 'customer_id', 'is_system', 'deleted')
ORDER BY ordinal_position;

