-- ====================================================
-- ACTUALIZACIÓN RLS: Políticas para 3 roles
-- ====================================================
-- Este script actualiza las políticas RLS para reflejar:
-- - Superadmin: Puede hacer TODO (crear, actualizar, borrar usuarios)
-- - Admin: Puede ver todas las cotizaciones y hacer todo, EXCEPTO crear/borrar usuarios
-- - Member: Solo puede ver/editar/borrar sus propias cotizaciones
-- ====================================================

-- PASO 1: Función helper para verificar si es Superadmin
CREATE OR REPLACE FUNCTION public.is_super_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  SET LOCAL row_security = off;
  
  RETURN EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_super_admin(uuid) TO authenticated;

-- PASO 2: Función helper para obtener el rol del usuario en una organización
CREATE OR REPLACE FUNCTION public.get_user_org_role(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  SET LOCAL row_security = off;
  
  -- Si es superadmin, retornar 'superadmin'
  IF public.is_super_admin(p_user_id) THEN
    RETURN 'superadmin';
  END IF;
  
  -- Obtener rol de OrganizationUsers
  SELECT role INTO v_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  RETURN COALESCE(v_role, NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_org_role(uuid, uuid) TO authenticated;

-- PASO 3: Función para verificar si puede actualizar (Superadmin y Admin, pero Admin no puede cambiar a superadmin)
CREATE OR REPLACE FUNCTION public.can_update_organization_user(
  p_user_id uuid,
  p_organization_id uuid,
  p_new_role text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_user_role text;
BEGIN
  SET LOCAL row_security = off;
  
  -- Superadmin puede hacer todo
  IF public.is_super_admin(p_user_id) THEN
    RETURN true;
  END IF;
  
  -- Obtener el rol del usuario
  v_user_role := public.get_user_org_role(p_user_id, p_organization_id);
  
  -- Si no tiene rol, no puede actualizar
  IF v_user_role IS NULL THEN
    RETURN false;
  END IF;
  
  -- Superadmin puede actualizar cualquier usuario
  IF v_user_role = 'superadmin' THEN
    RETURN true;
  END IF;
  
  -- Admin puede actualizar usuarios, PERO no puede cambiar roles a 'superadmin'
  IF v_user_role = 'admin' THEN
    -- Si se está intentando cambiar el rol a 'superadmin', denegar
    IF p_new_role IS NOT NULL AND p_new_role = 'superadmin' THEN
      RETURN false;
    END IF;
    -- Admin puede actualizar otros campos y cambiar roles a admin/member
    RETURN true;
  END IF;
  
  -- Member no puede actualizar otros usuarios
  RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_update_organization_user(uuid, uuid, text) TO authenticated;

-- PASO 4: Eliminar TODAS las políticas existentes de OrganizationUsers
DROP POLICY IF EXISTS "organizationusers_select_own" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_select_org_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_select_org_managers" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_select_managers" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_insert_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_insert_managers" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_insert_superadmin" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_own" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_owners_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_managers" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_delete_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_delete_superadmin" ON "OrganizationUsers";

-- PASO 5: Crear nuevas políticas SELECT
-- 5.1: Los usuarios pueden ver su propio registro
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
USING (user_id = auth.uid());

-- 5.2: Superadmin puede ver todos, Admin solo ve usuarios de su mismo Customer
CREATE POLICY "organizationusers_select_managers"
ON "OrganizationUsers"
FOR SELECT
USING (
  -- Superadmin puede ver todos
  public.is_super_admin(auth.uid())
  OR
  -- Superadmin (desde OrganizationUsers) puede ver todos
  public.get_user_org_role(auth.uid(), organization_id) = 'superadmin'
  OR
  -- Admin solo ve usuarios de su mismo Customer
  (
    public.get_user_org_role(auth.uid(), organization_id) = 'admin'
    AND customer_id IN (
      SELECT customer_id
      FROM "OrganizationUsers"
      WHERE user_id = auth.uid()
        AND organization_id = "OrganizationUsers".organization_id
        AND deleted = false
        AND customer_id IS NOT NULL
    )
  )
);

-- PASO 6: Crear política INSERT (SOLO Superadmin puede crear usuarios)
CREATE POLICY "organizationusers_insert_superadmin"
ON "OrganizationUsers"
FOR INSERT
WITH CHECK (
  public.is_super_admin(auth.uid())
);

-- PASO 7: Crear políticas UPDATE
-- 7.1: Los usuarios pueden actualizar su propio registro (excepto rol)
CREATE POLICY "organizationusers_update_own"
ON "OrganizationUsers"
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (
  user_id = auth.uid()
  AND role = (SELECT role FROM "OrganizationUsers" WHERE id = "OrganizationUsers".id)
);

-- 7.2: Superadmin y Admin pueden actualizar otros usuarios
CREATE POLICY "organizationusers_update_managers"
ON "OrganizationUsers"
FOR UPDATE
USING (
  public.can_update_organization_user(auth.uid(), organization_id, NULL)
)
WITH CHECK (
  public.can_update_organization_user(auth.uid(), organization_id, role)
);

-- PASO 8: Crear política DELETE (SOLO Superadmin puede borrar usuarios)
CREATE POLICY "organizationusers_delete_superadmin"
ON "OrganizationUsers"
FOR DELETE
USING (
  public.is_super_admin(auth.uid())
);

-- PASO 9: Añadir comentarios descriptivos
COMMENT ON FUNCTION public.is_super_admin(uuid) IS 
  'Verifica si un usuario es Superadmin (está en PlatformAdmins)';

COMMENT ON FUNCTION public.get_user_org_role(uuid, uuid) IS 
  'Obtiene el rol de un usuario en una organización. Retorna superadmin si es superadmin, o el rol de OrganizationUsers';

COMMENT ON FUNCTION public.can_update_organization_user(uuid, uuid, text) IS 
  'Verifica si usuario puede actualizar miembros. Superadmin y Admin pueden actualizar. Admin no puede cambiar roles a superadmin.';

COMMENT ON POLICY "organizationusers_select_own" ON "OrganizationUsers" IS 
  'Los usuarios pueden ver su propio registro';

COMMENT ON POLICY "organizationusers_select_managers" ON "OrganizationUsers" IS 
  'Superadmin puede ver todos los usuarios. Admin solo ve usuarios de su mismo Customer.';

COMMENT ON POLICY "organizationusers_insert_superadmin" ON "OrganizationUsers" IS 
  'Solo Superadmin puede crear usuarios';

COMMENT ON POLICY "organizationusers_update_own" ON "OrganizationUsers" IS 
  'Los usuarios pueden actualizar su propio registro pero no pueden cambiar su rol';

COMMENT ON POLICY "organizationusers_update_managers" ON "OrganizationUsers" IS 
  'Superadmin y Admin pueden actualizar usuarios. Admin no puede cambiar roles a superadmin.';

COMMENT ON POLICY "organizationusers_delete_superadmin" ON "OrganizationUsers" IS 
  'Solo Superadmin puede borrar usuarios';

-- PASO 10: Verificación final
DO $$ 
DECLARE
  v_select_count integer;
  v_insert_count integer;
  v_update_count integer;
  v_delete_count integer;
BEGIN
  -- Contar políticas por tipo
  SELECT COUNT(*) INTO v_select_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'OrganizationUsers'
    AND cmd = 'SELECT';
  
  SELECT COUNT(*) INTO v_insert_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'OrganizationUsers'
    AND cmd = 'INSERT';
  
  SELECT COUNT(*) INTO v_update_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'OrganizationUsers'
    AND cmd = 'UPDATE';
  
  SELECT COUNT(*) INTO v_delete_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'OrganizationUsers'
    AND cmd = 'DELETE';
  
  RAISE NOTICE '✅ Migración RLS completada exitosamente';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Políticas creadas:';
  RAISE NOTICE '   - SELECT: % políticas', v_select_count;
  RAISE NOTICE '   - INSERT: % políticas (solo Superadmin)', v_insert_count;
  RAISE NOTICE '   - UPDATE: % políticas (Superadmin y Admin)', v_update_count;
  RAISE NOTICE '   - DELETE: % políticas (solo Superadmin)', v_delete_count;
  RAISE NOTICE '';
  RAISE NOTICE '🔒 Permisos configurados:';
  RAISE NOTICE '   - Superadmin: Puede crear, actualizar y borrar usuarios';
  RAISE NOTICE '   - Admin: Puede actualizar usuarios (excepto cambiar a superadmin)';
  RAISE NOTICE '   - Member: Solo puede ver/actualizar su propio registro';
END $$;

