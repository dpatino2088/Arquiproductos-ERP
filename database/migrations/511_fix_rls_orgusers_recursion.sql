-- ============================================================
-- Migration: Fix RLS recursion in OrganizationUsers
-- ============================================================
-- OBJETIVO: Eliminar recursión infinita en RLS de OrganizationUsers
-- - Políticas simples NO recursivas (solo user_id = auth.uid())
-- - RPCs SECURITY DEFINER para administración (sin recursion)
-- - Mantener seguridad: usuarios solo leen su membership
-- ============================================================
-- NOTA: Esta migración usa solo valores que existen en el enum org_role:
-- 'owner', 'admin', 'manager', 'user'
-- Si necesitas agregar 'superadmin', 'super_admin', 'member', 'viewer',
-- ejecuta una migración separada ANTES de esta para agregar esos valores al enum.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) DROP todas las políticas existentes en OrganizationUsers
-- ============================================================
DROP POLICY IF EXISTS "Users can read own organization users" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "Users can read own organization users v2" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_select_own" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_select_all" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_insert_own" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_update_own" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_delete_own" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_select" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_insert" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_update" ON public."OrganizationUsers";
DROP POLICY IF EXISTS "orgusers_delete" ON public."OrganizationUsers";

-- Drop any other potentially recursive policies
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'OrganizationUsers'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public."OrganizationUsers"', pol.policyname);
  END LOOP;
END $$;

-- ============================================================
-- 2) Crear políticas NO recursivas (solo user_id = auth.uid())
-- ============================================================

-- A.1) SELECT own membership only (NO recursion)
CREATE POLICY orgusers_select_own
  ON public."OrganizationUsers"
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND deleted = false
  );

-- A.2) UPDATE own row only (opcional, para que users puedan editar su perfil)
CREATE POLICY orgusers_update_own
  ON public."OrganizationUsers"
  FOR UPDATE
  USING (
    user_id = auth.uid()
    AND deleted = false
  )
  WITH CHECK (
    user_id = auth.uid()
    AND deleted = false
  );

-- NOTA: NO creamos INSERT/DELETE policies porque eso se hace vía RPCs SECURITY DEFINER

-- ============================================================
-- 3) Asegurar unique index correcto
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS orgusers_org_email_uniq
  ON public."OrganizationUsers" (organization_id, lower(user_email))
  WHERE deleted = false;

-- ============================================================
-- 4) RPC SECURITY DEFINER: upsert_organization_user
-- ============================================================
CREATE OR REPLACE FUNCTION public.upsert_organization_user(
  p_organization_id uuid,
  p_user_email text,
  p_role public.org_role,
  p_status public.org_user_status DEFAULT 'invited'::public.org_user_status
)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  user_id uuid,
  user_email text,
  user_name text,
  role public.org_role,
  status public.org_user_status,
  invited_by_user_id uuid,
  invited_at timestamptz,
  accepted_at timestamptz,
  deleted boolean,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
  v_existing_id uuid;
  v_result_record public."OrganizationUsers"%ROWTYPE;
BEGIN
  -- Obtener caller user_id (SECURITY DEFINER preserva auth.uid())
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es owner o admin en la organización
  -- Esto se hace SIN RLS (porque estamos en SECURITY DEFINER y la función puede leer OrganizationUsers directamente)
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Solo permitir owner y admin (los valores que definitivamente existen en el enum)
  IF v_caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owners and admins can manage organization users';
  END IF;

  -- Validar que admins no pueden crear owners
  IF v_caller_role = 'admin' AND p_role = 'owner' THEN
    RAISE EXCEPTION 'Admins cannot create owners';
  END IF;

  -- Normalizar email
  p_user_email := lower(trim(p_user_email));

  -- Buscar si ya existe (incluyendo deleted=true para "revivir")
  SELECT id INTO v_existing_id
  FROM public."OrganizationUsers"
  WHERE organization_id = p_organization_id
    AND lower(user_email) = p_user_email;

  IF v_existing_id IS NOT NULL THEN
    -- UPDATE: reactivar si estaba deleted, actualizar role/status
    UPDATE public."OrganizationUsers"
    SET
      role = p_role,
      status = p_status,
      deleted = false,
      updated_at = now()
    WHERE id = v_existing_id
    RETURNING * INTO v_result_record;
    
    -- Return as TABLE
    RETURN QUERY SELECT
      v_result_record.id,
      v_result_record.organization_id,
      v_result_record.user_id,
      v_result_record.user_email,
      v_result_record.user_name,
      v_result_record.role,
      v_result_record.status,
      v_result_record.invited_by_user_id,
      v_result_record.invited_at,
      v_result_record.accepted_at,
      v_result_record.deleted,
      v_result_record.created_at,
      v_result_record.updated_at;
  ELSE
    -- INSERT: nuevo usuario
    INSERT INTO public."OrganizationUsers" (
      organization_id,
      user_email,
      role,
      status,
      user_id, -- NULL hasta que acepte invite
      invited_by_user_id,
      invited_at,
      deleted,
      created_at,
      updated_at
    ) VALUES (
      p_organization_id,
      p_user_email,
      p_role,
      p_status,
      NULL, -- user_id será NULL hasta que acepte invite
      v_caller_user_id,
      now(),
      false,
      now(),
      now()
    )
    RETURNING * INTO v_result_record;
    
    -- Return as TABLE
    RETURN QUERY SELECT
      v_result_record.id,
      v_result_record.organization_id,
      v_result_record.user_id,
      v_result_record.user_email,
      v_result_record.user_name,
      v_result_record.role,
      v_result_record.status,
      v_result_record.invited_by_user_id,
      v_result_record.invited_at,
      v_result_record.accepted_at,
      v_result_record.deleted,
      v_result_record.created_at,
      v_result_record.updated_at;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.upsert_organization_user IS 'Upsert organization user. Only owners/admins can call. Returns the created/updated OrganizationUsers row.';

-- ============================================================
-- 5) RPC SECURITY DEFINER: list_organization_users
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_organization_users(
  p_organization_id uuid
)
RETURNS SETOF public."OrganizationUsers"
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
BEGIN
  -- Obtener caller user_id
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es owner o admin en la organización
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Allow superadmin, admin, and owner (legacy) roles to list users
  IF v_caller_role NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins, admins, and owners can list organization users';
  END IF;

  -- Retornar usuarios de la organización (deleted=false)
  RETURN QUERY
  SELECT ou.*
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.deleted = false
  ORDER BY ou.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.list_organization_users IS 'List all users in an organization. Only owners/admins can call.';

-- ============================================================
-- 6) Asegurar policies de OrganizationUserPermissions (NO recursivas)
-- ============================================================
-- Drop existing policies
DROP POLICY IF EXISTS "Users can read own permissions" ON public."OrganizationUserPermissions";
DROP POLICY IF EXISTS "orguserperms_select_own" ON public."OrganizationUserPermissions";

-- Crear policy NO recursiva: usa join directo con auth.uid() sin subquery a OrganizationUsers
CREATE POLICY orguserperms_select_own
  ON public."OrganizationUserPermissions"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.id = organization_user_id
        AND ou.user_id = auth.uid()
        AND ou.deleted = false
        AND ou.status = 'active'
    )
  );

COMMENT ON POLICY orguserperms_select_own ON public."OrganizationUserPermissions" IS 'Users can read their own permissions via organization_user_id. This is safe because OrganizationUsers has non-recursive select policy.';

-- ============================================================
-- 7) Re-seed permissions + assign to owners
-- ============================================================
-- Asegurar que todos los permisos base existen
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('directory.read', 'directory', 'View directory (customers, contacts)'),
  ('directory.write', 'directory', 'Create/edit directory entries'),
  ('catalog.read', 'catalog', 'View catalog'),
  ('catalog.write', 'catalog', 'Create/edit catalog items'),
  ('sales.read', 'sales', 'View quotes and sales orders'),
  ('sales.write', 'sales', 'Create/edit quotes and sales orders'),
  ('manufacturing.read', 'manufacturing', 'View manufacturing orders'),
  ('manufacturing.write', 'manufacturing', 'Create/edit manufacturing orders'),
  ('finance.read', 'finance', 'View financial data'),
  ('finance.write', 'finance', 'Create/edit financial data'),
  ('settings.read', 'settings', 'View settings'),
  ('settings.write', 'settings', 'Edit settings'),
  ('dashboard.read', 'dashboard', 'View dashboard')
ON CONFLICT (code) DO NOTHING;

-- Asignar todos los permisos a owners (y otros roles administrativos si existen en el enum)
INSERT INTO public."OrganizationUserPermissions" (organization_user_id, permission_code)
SELECT ou.id, p.code
FROM public."OrganizationUsers" ou
CROSS JOIN public."Permissions" p
WHERE ou.role IN ('owner', 'admin')  -- Solo roles que definitivamente existen en el enum
  AND ou.deleted = false
ON CONFLICT (organization_user_id, permission_code) DO NOTHING;

COMMIT;
