-- ============================================================
-- Migration: Update upsert_organization_user RPC to use new roles
-- ============================================================
-- OBJECTIVE:
-- Update the upsert_organization_user RPC function to:
-- 1. Accept superadmin/admin roles (instead of owner/admin)
-- 2. Allow superadmin/admin to manage users
-- 3. Prevent admin from creating superadmin users
-- ============================================================

BEGIN;

-- ============================================================
-- Update upsert_organization_user RPC
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

  -- Validar que caller es superadmin o admin en la organización
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

  -- Solo permitir superadmin y admin (los valores que pueden gestionar usuarios)
  -- También aceptar 'owner' como legacy (mapeado a superadmin)
  IF v_caller_role::text NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins and admins can manage organization users';
  END IF;

  -- Validar que admins no pueden crear superadmins
  IF v_caller_role::text IN ('admin') AND p_role::text = 'superadmin' THEN
    RAISE EXCEPTION 'Admins cannot create superadmins';
  END IF;

  -- También prevenir que admin cree 'owner' (legacy)
  IF v_caller_role::text IN ('admin') AND p_role::text = 'owner' THEN
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

COMMENT ON FUNCTION public.upsert_organization_user IS 'Upsert organization user. Only superadmins/admins can call. Returns the created/updated OrganizationUsers row.';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Updated upsert_organization_user to accept superadmin/admin roles
-- 2. Updated validation to allow superadmin/admin to manage users
-- 3. Prevented admin from creating superadmin users
-- 4. Maintained backward compatibility with 'owner' role (legacy)
-- ============================================================
