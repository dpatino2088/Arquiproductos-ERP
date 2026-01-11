-- ============================================================
-- Migration: Fix ambiguous 'id' column reference in upsert_organization_user
-- ============================================================
-- OBJECTIVE:
-- Fix the "column reference 'id' is ambiguous" error in the
-- upsert_organization_user RPC function by using explicit table aliases
-- ============================================================

-- ============================================================
-- Step 1: Drop ALL existing versions of the function
-- ============================================================

BEGIN;

-- Drop ALL existing versions of the function to avoid conflicts
-- Use dynamic SQL to drop all versions regardless of signature
DO $$
DECLARE
  func_record record;
  drop_sql text;
BEGIN
  FOR func_record IN 
    SELECT 
      oid,
      proname,
      pg_get_function_identity_arguments(oid) as args,
      oid::regprocedure::text as func_signature
    FROM pg_proc
    WHERE proname = 'upsert_organization_user'
      AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  LOOP
    BEGIN
      -- Build DROP statement using regprocedure which includes full signature
      drop_sql := 'DROP FUNCTION IF EXISTS ' || func_record.func_signature || ' CASCADE';
      EXECUTE drop_sql;
      RAISE NOTICE 'Dropped function: %', func_record.func_signature;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop function: % - Error: %', func_record.func_signature, SQLERRM;
    END;
  END LOOP;
END $$;

COMMIT;

-- ============================================================
-- Step 2: Create the new function with fixed ambiguous id issue
-- ============================================================
-- Note: After dropping all versions in Step 1, we can safely CREATE the function

BEGIN;

CREATE FUNCTION public.upsert_organization_user(
  p_organization_id uuid,
  p_user_email text,
  p_role public.org_role,
  p_status public.org_user_status DEFAULT 'invited'::public.org_user_status,
  p_user_name text DEFAULT NULL
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
  v_current_user_name text;
  v_result_record public."OrganizationUsers"%ROWTYPE;
BEGIN
  -- Obtener caller user_id (SECURITY DEFINER preserva auth.uid())
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es superadmin o admin en la organización
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
  -- Use explicit table alias to avoid ambiguity with RETURNS TABLE
  SELECT ou.id INTO v_existing_id
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND lower(ou.user_email) = p_user_email;

  IF v_existing_id IS NOT NULL THEN
    -- UPDATE: reactivar si estaba deleted, actualizar role/status/user_name
    -- Get current user_name first to preserve it if p_user_name is null
    SELECT ou2.user_name INTO v_current_user_name
    FROM public."OrganizationUsers" ou2
    WHERE ou2.id = v_existing_id;
    
    -- Use fully qualified column reference to avoid ambiguity with RETURNS TABLE id column
    UPDATE public."OrganizationUsers"
    SET
      role = p_role,
      status = p_status,
      user_name = COALESCE(p_user_name, v_current_user_name), -- Update name if provided, else keep existing
      deleted = false,
      updated_at = now()
    WHERE public."OrganizationUsers".id = v_existing_id
    RETURNING public."OrganizationUsers".* INTO v_result_record;
    
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
      user_name,
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
      p_user_name, -- Include user_name in insert
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

COMMENT ON FUNCTION public.upsert_organization_user IS 'Upsert organization user. Only superadmins/admins can call. Returns the created/updated OrganizationUsers row. Fixed ambiguous id column reference.';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Dropped all existing versions of upsert_organization_user to avoid conflicts
-- 2. Fixed ambiguous 'id' column reference by using fully qualified table names
-- 3. Added p_user_name parameter to support user name updates
-- 4. Updated UPDATE to use fully qualified column reference (public."OrganizationUsers".id)
-- 5. Updated INSERT to include user_name field
-- ============================================================
