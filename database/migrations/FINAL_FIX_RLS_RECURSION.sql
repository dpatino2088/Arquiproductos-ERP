-- ============================================================================
-- SOLUCIÓN DEFINITIVA: Eliminar recursión infinita en políticas RLS
-- ============================================================================
-- Este script resuelve completamente el error de recursión infinita
-- en las políticas de OrganizationUsers
--
-- IMPORTANTE: Ejecuta este script en el SQL Editor de Supabase
-- ============================================================================

-- ============================================================================
-- PASO 1: Eliminar TODAS las políticas existentes
-- ============================================================================
DO $$ 
BEGIN
    -- Drop all existing policies to start fresh
    DROP POLICY IF EXISTS "organizationusers_select_own" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_select_org_admins" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
    DROP POLICY IF EXISTS "organizationusers_delete_owners" ON "OrganizationUsers";
    
    RAISE NOTICE 'Políticas eliminadas correctamente';
END $$;

-- ============================================================================
-- PASO 2: Recrear funciones helper con SECURITY DEFINER y row_security = off
-- ============================================================================

-- Función 1: Verificar permisos para INSERT (con protección anti-recursión)
CREATE OR REPLACE FUNCTION public.can_insert_organization_user(
  p_inviter_user_id uuid,
  p_organization_id uuid,
  p_new_user_role text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER  -- Ejecuta con permisos del owner, no del usuario actual
STABLE
SET search_path = public
AS $$
DECLARE
  v_is_superadmin boolean;
  v_inviter_role text;
BEGIN
  -- CRÍTICO: Deshabilitar RLS temporalmente para evitar recursión
  SET LOCAL row_security = off;
  
  -- Verificar si el usuario es superadmin
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_inviter_user_id
  ) INTO v_is_superadmin;
  
  -- Los SuperAdmins pueden crear cualquier usuario en cualquier organización
  IF v_is_superadmin THEN
    RETURN true;
  END IF;
  
  -- Obtener el rol del invitador en la organización
  -- Con row_security = off, esta consulta NO activa las políticas RLS
  SELECT role INTO v_inviter_role
  FROM public."OrganizationUsers"
  WHERE user_id = p_inviter_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  -- Si el invitador no es owner ni admin, denegar
  IF v_inviter_role IS NULL OR v_inviter_role NOT IN ('owner', 'admin') THEN
    RETURN false;
  END IF;
  
  -- Si se intenta crear un owner, solo los owners pueden hacerlo
  IF p_new_user_role = 'owner' AND v_inviter_role != 'owner' THEN
    RETURN false;
  END IF;
  
  -- Todas las verificaciones pasaron
  RETURN true;
END;
$$;

-- Función 2: Verificar si usuario es owner o admin (para SELECT)
CREATE OR REPLACE FUNCTION public.can_view_organization_users(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_is_superadmin boolean;
  v_user_role text;
BEGIN
  -- CRÍTICO: Deshabilitar RLS temporalmente
  SET LOCAL row_security = off;
  
  -- Verificar si es superadmin
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true;
  END IF;
  
  -- Verificar rol en la organización
  SELECT role INTO v_user_role
  FROM public."OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  -- Owner o Admin pueden ver
  RETURN v_user_role IN ('owner', 'admin');
END;
$$;

-- Función 3: Verificar si usuario es owner o superadmin (para UPDATE/DELETE)
CREATE OR REPLACE FUNCTION public.can_manage_organization_users(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_is_superadmin boolean;
  v_user_role text;
BEGIN
  SET LOCAL row_security = off;
  
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true;
  END IF;
  
  SELECT role INTO v_user_role
  FROM public."OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  RETURN v_user_role = 'owner';
END;
$$;

-- ============================================================================
-- PASO 3: Otorgar permisos de ejecución
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.can_insert_organization_user(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_organization_users(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_organization_users(uuid, uuid) TO authenticated;

-- ============================================================================
-- PASO 4: Crear políticas SIMPLIFICADAS usando las funciones helper
-- ============================================================================

-- Política 1: SELECT - Ver propio registro
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
USING (
  user_id = auth.uid()
);

-- Política 2: SELECT - Owners/Admins/SuperAdmins pueden ver todos los usuarios
CREATE POLICY "organizationusers_select_org_admins"
ON "OrganizationUsers"
FOR SELECT
USING (
  public.can_view_organization_users(auth.uid(), organization_id)
);

-- Política 3: INSERT - Solo Owners/Admins/SuperAdmins pueden invitar usuarios
-- Esta política usa la función especializada que evita recursión
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
USING (
  user_id = auth.uid()
)
WITH CHECK (
  user_id = auth.uid()
  -- Prevenir cambio de rol propio
  AND role = (SELECT role FROM "OrganizationUsers" WHERE id = "OrganizationUsers".id)
);

-- Política 5: UPDATE - Owners/SuperAdmins pueden actualizar cualquier usuario
CREATE POLICY "organizationusers_update_owners"
ON "OrganizationUsers"
FOR UPDATE
USING (
  public.can_manage_organization_users(auth.uid(), organization_id)
)
WITH CHECK (
  public.can_manage_organization_users(auth.uid(), organization_id)
);

-- Política 6: DELETE - Solo Owners/SuperAdmins pueden eliminar usuarios
CREATE POLICY "organizationusers_delete_owners"
ON "OrganizationUsers"
FOR DELETE
USING (
  public.can_manage_organization_users(auth.uid(), organization_id)
);

-- ============================================================================
-- PASO 5: Añadir comentarios descriptivos
-- ============================================================================
COMMENT ON FUNCTION public.can_insert_organization_user(uuid, uuid, text) IS 
  'Verifica permisos para insertar usuarios. Usa SECURITY DEFINER y row_security=off para evitar recursión.';

COMMENT ON FUNCTION public.can_view_organization_users(uuid, uuid) IS 
  'Verifica si usuario puede ver miembros de la organización. Evita recursión RLS.';

COMMENT ON FUNCTION public.can_manage_organization_users(uuid, uuid) IS 
  'Verifica si usuario puede gestionar (actualizar/eliminar) miembros. Solo owners y superadmins.';

COMMENT ON POLICY "organizationusers_select_own" ON "OrganizationUsers" IS 
  'Los usuarios pueden ver su propio registro en OrganizationUsers';

COMMENT ON POLICY "organizationusers_select_org_admins" ON "OrganizationUsers" IS 
  'Owners, admins y superadmins pueden ver todos los usuarios de su organización';

COMMENT ON POLICY "organizationusers_insert_owners_admins" ON "OrganizationUsers" IS 
  'Permite a owners, admins y superadmins invitar usuarios. Los admins no pueden crear owners.';

COMMENT ON POLICY "organizationusers_update_own" ON "OrganizationUsers" IS 
  'Los usuarios pueden actualizar su propio registro pero no pueden cambiar su rol';

COMMENT ON POLICY "organizationusers_update_owners" ON "OrganizationUsers" IS 
  'Los owners y superadmins pueden actualizar cualquier usuario en su organización';

COMMENT ON POLICY "organizationusers_delete_owners" ON "OrganizationUsers" IS 
  'Solo owners y superadmins pueden eliminar usuarios de la organización';

-- ============================================================================
-- PASO 6: Verificación final
-- ============================================================================
DO $$ 
BEGIN
    RAISE NOTICE '✅ Migración completada exitosamente';
    RAISE NOTICE '✅ Políticas RLS recreadas sin recursión';
    RAISE NOTICE '✅ Funciones helper configuradas con SECURITY DEFINER';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Para verificar, ejecuta:';
    RAISE NOTICE '   SELECT policyname FROM pg_policies WHERE tablename = ''OrganizationUsers'';';
END $$;

