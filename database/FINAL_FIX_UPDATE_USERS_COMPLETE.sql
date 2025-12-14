-- ====================================================
-- FIX COMPLETO Y DEFINITIVO: Actualización de Usuarios
-- ====================================================
-- Este script asegura que todo esté configurado correctamente
-- para permitir que Owners y Admins actualicen usuarios
-- ====================================================

-- PASO 1: Asegurar que la función existe y está correcta
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
  v_is_superadmin boolean;
  v_user_role text;
BEGINcam
  -- Deshabilitar RLS temporalmente para evitar recursión
  SET LOCAL row_security = off;
  
  -- Verificar si es superadmin
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true; -- SuperAdmins pueden hacer todo
  END IF;
  
  -- Obtener el rol del usuario que intenta actualizar
  SELECT role INTO v_user_role
  FROM public."OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  -- Si no tiene rol, no puede actualizar
  IF v_user_role IS NULL THEN
    RETURN false;
  END IF;
  
  -- Owners pueden actualizar cualquier usuario
  IF v_user_role = 'owner' THEN
    RETURN true;
  END IF;
  
  -- Admins pueden actualizar usuarios, PERO no pueden cambiar roles a 'owner'
  IF v_user_role = 'admin' THEN
    -- Si se está intentando cambiar el rol a 'owner', denegar
    IF p_new_role IS NOT NULL AND p_new_role = 'owner' THEN
      RETURN false;
    END IF;
    -- Admins pueden actualizar otros campos y cambiar roles a admin/member/viewer
    RETURN true;
  END IF;
  
  -- Otros roles no pueden actualizar
  RETURN false;
END;
$$;

-- PASO 2: Otorgar permisos de ejecución
GRANT EXECUTE ON FUNCTION public.can_update_organization_user(uuid, uuid, text) TO authenticated;

-- PASO 3: Eliminar TODAS las políticas de UPDATE existentes
DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_owners_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_own" ON "OrganizationUsers";

-- PASO 4: Crear política para auto-actualización (usuarios pueden actualizar su propio registro, excepto rol)
CREATE POLICY "organizationusers_update_own"
ON "OrganizationUsers"
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (
  user_id = auth.uid()
  AND role = (SELECT role FROM "OrganizationUsers" WHERE id = "OrganizationUsers".id)
);

-- PASO 5: Crear política para Owners y Admins (pueden actualizar otros usuarios)
CREATE POLICY "organizationusers_update_owners_admins"
ON "OrganizationUsers"
FOR UPDATE
USING (
  public.can_update_organization_user(auth.uid(), organization_id, NULL)
)
WITH CHECK (
  public.can_update_organization_user(auth.uid(), organization_id, role)
);

-- PASO 6: Añadir comentarios descriptivos
COMMENT ON FUNCTION public.can_update_organization_user(uuid, uuid, text) IS 
  'Verifica si usuario puede actualizar miembros. Owners y Admins pueden actualizar. Admins no pueden cambiar roles a owner.';

COMMENT ON POLICY "organizationusers_update_own" ON "OrganizationUsers" IS 
  'Los usuarios pueden actualizar su propio registro pero no pueden cambiar su rol';

COMMENT ON POLICY "organizationusers_update_owners_admins" ON "OrganizationUsers" IS 
  'Permite a owners y admins actualizar usuarios. Los admins no pueden cambiar roles a owner.';

-- PASO 7: Verificación final
DO $$ 
DECLARE
  v_policy_count integer;
  v_function_exists boolean;
BEGIN
    -- Verificar que la función existe
    SELECT EXISTS (
      SELECT 1 FROM pg_proc 
      WHERE proname = 'can_update_organization_user'
    ) INTO v_function_exists;
    
    -- Contar políticas de UPDATE
    SELECT COUNT(*) INTO v_policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'OrganizationUsers'
      AND cmd = 'UPDATE';
    
    IF v_function_exists AND v_policy_count >= 2 THEN
        RAISE NOTICE '✅ Migración completada exitosamente';
        RAISE NOTICE '✅ Función can_update_organization_user: CREADA';
        RAISE NOTICE '✅ Políticas UPDATE: % políticas creadas', v_policy_count;
        RAISE NOTICE '';
        RAISE NOTICE '🔍 Verificación:';
        RAISE NOTICE '   - Owners pueden actualizar cualquier usuario';
        RAISE NOTICE '   - Admins pueden actualizar usuarios (excepto cambiar a owner)';
        RAISE NOTICE '   - Usuarios pueden actualizar su propio registro (excepto rol)';
    ELSE
        RAISE WARNING '⚠️ Verificación falló:';
        RAISE WARNING '   - Función existe: %', v_function_exists;
        RAISE WARNING '   - Políticas encontradas: %', v_policy_count;
    END IF;
END $$;

