-- ====================================================
-- FIX: Permitir que Admins también puedan actualizar usuarios
-- ====================================================
-- Este script corrige la política RLS para que los admins
-- puedan actualizar usuarios (pero no crear owners)
-- ====================================================

-- Paso 1: Crear función mejorada que permite a admins actualizar usuarios
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
BEGIN
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

-- Paso 2: Otorgar permisos
GRANT EXECUTE ON FUNCTION public.can_update_organization_user(uuid, uuid, text) TO authenticated;

-- Paso 3: Eliminar políticas de UPDATE existentes (tanto la antigua como la nueva, para hacer el script idempotente)
DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_owners_admins" ON "OrganizationUsers";

-- Paso 4: Crear nueva política que permite a owners y admins actualizar
CREATE POLICY "organizationusers_update_owners_admins"
ON "OrganizationUsers"
FOR UPDATE
USING (
  public.can_update_organization_user(auth.uid(), organization_id, NULL)
)
WITH CHECK (
  public.can_update_organization_user(auth.uid(), organization_id, role)
);

-- Paso 5: Añadir comentarios
COMMENT ON FUNCTION public.can_update_organization_user(uuid, uuid, text) IS 
  'Verifica si usuario puede actualizar miembros. Owners y Admins pueden actualizar. Admins no pueden cambiar roles a owner.';

COMMENT ON POLICY "organizationusers_update_owners_admins" ON "OrganizationUsers" IS 
  'Permite a owners y admins actualizar usuarios. Los admins no pueden cambiar roles a owner.';

-- ====================================================
-- Verificación
-- ====================================================
DO $$ 
BEGIN
    RAISE NOTICE '✅ Migración completada exitosamente';
    RAISE NOTICE '✅ Función can_update_organization_user creada';
    RAISE NOTICE '✅ Política organizationusers_update_owners_admins creada';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Para verificar, ejecuta:';
    RAISE NOTICE '   SELECT policyname FROM pg_policies WHERE tablename = ''OrganizationUsers'' AND cmd = ''UPDATE'';';
END $$;

