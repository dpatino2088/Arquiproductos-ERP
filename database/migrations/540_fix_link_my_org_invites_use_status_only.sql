-- Migration: Fix link_my_org_invites to use ONLY 'status' column (not portal_user_status)
-- Date: 2026-01-12
-- Description: Updates link_my_org_invites() function, triggers, and policies to use 'status' column instead of 'portal_user_status'
-- Also drops the legacy portal_user_status column

BEGIN;

-- ============================================================
-- 0) Encontrar TODO lo que depende de portal_user_status (para que no te vuelva a pasar)
-- ============================================================
-- (Informativo) Te muestra policies y funciones donde aparece el texto.
-- Si quieres ver resultados, ejecuta esto aparte.
-- select schemaname, tablename, policyname, qual, with_check
-- from pg_policies
-- where (qual ilike '%portal_user_status%' or with_check ilike '%portal_user_status%');
--
-- select n.nspname as schema, p.proname as function_name
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where pg_get_functiondef(p.oid) ilike '%portal_user_status%';

-- ============================================================
-- 1) FIX: Reemplazar policy que depende de portal_user_status
--    (La dropeamos y la recreamos usando CompanyPortalUsers.status)
-- ============================================================
DROP POLICY IF EXISTS portal_select_contacts ON public."DirectoryContacts";

-- ⚠️ IMPORTANTE:
-- Esta policy asume que DirectoryContacts tiene column company_id
-- y que CompanyPortalUsers relaciona por company_id.
-- Ajusta el join si tu RLS usa otra lógica.
CREATE POLICY portal_select_contacts
ON public."DirectoryContacts"
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.company_id = public."DirectoryContacts".company_id
      AND cpu.user_id = auth.uid()
      AND cpu.deleted = false
      AND cpu.status = 'active'  -- ✅ USAR ENUM status
  )
);

-- ============================================================
-- 2) Alinear link_my_org_invites / triggers a usar SOLO status
-- ============================================================
CREATE OR REPLACE FUNCTION public.link_my_org_invites()
RETURNS TABLE (
  linked_count integer,
  updated_ids uuid[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_linked_count integer := 0;
  v_updated_ids uuid[] := ARRAY[]::uuid[];
  v_portal_linked_count integer := 0;
  v_portal_updated_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  v_user_id := auth.uid();
  v_user_email := (SELECT email FROM auth.users WHERE id = v_user_id);

  IF v_user_id IS NULL OR v_user_email IS NULL THEN
    RAISE WARNING '[link_my_org_invites] No authenticated user or email found. Skipping link.';
    RETURN QUERY SELECT 0::integer, ARRAY[]::uuid[];
    RETURN;
  END IF;

  -- Link OrganizationUsers
  WITH updated AS (
    UPDATE public."OrganizationUsers"
    SET
      user_id = v_user_id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
    WHERE lower(user_email) = lower(v_user_email)
      AND user_id IS NULL
      AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[]
  INTO v_linked_count, v_updated_ids
  FROM updated;

  -- Link CompanyPortalUsers (✅ SOLO status)
  WITH updated_portal AS (
    UPDATE public."CompanyPortalUsers"
    SET
      user_id = v_user_id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
    WHERE lower(portal_user_email) = lower(v_user_email)
      AND user_id IS NULL
      AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[]
  INTO v_portal_linked_count, v_portal_updated_ids
  FROM updated_portal;

  RETURN QUERY
    SELECT (v_linked_count + v_portal_linked_count)::integer,
           (COALESCE(v_updated_ids, ARRAY[]::uuid[]) || COALESCE(v_portal_updated_ids, ARRAY[]::uuid[]))::uuid[];
END;
$$;

COMMENT ON FUNCTION public.link_my_org_invites() IS 
  'Links both OrganizationUsers and CompanyPortalUsers invites for the current authenticated user. Matches by email. Uses ONLY "status" column (not portal_user_status). Returns combined count and array of all updated IDs.';

-- Trigger function (si la estás usando)
CREATE OR REPLACE FUNCTION public.handle_auth_user_created_for_portal_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public."CompanyPortalUsers"
  SET
    user_id = NEW.id,
    status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
    accepted_at = COALESCE(accepted_at, now()),
    updated_at = now()
  WHERE lower(portal_user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_auth_user_created_for_portal_users() IS 
  'Automatically links CompanyPortalUsers invites when a new auth.users is created. Uses ONLY "status" column (not portal_user_status).';

-- ============================================================
-- 3) AHORA SÍ: dropear la columna legacy portal_user_status (text)
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='CompanyPortalUsers'
      AND column_name='portal_user_status'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" DROP COLUMN portal_user_status;
    RAISE NOTICE 'Dropped legacy column portal_user_status';
  END IF;
END $$;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Updated portal_select_contacts policy to use 'status' column
-- 2. Updated link_my_org_invites() to use 'status' column for CompanyPortalUsers
-- 3. Updated handle_auth_user_created_for_portal_users() trigger to use 'status' column
-- 4. Dropped legacy 'portal_user_status' column from CompanyPortalUsers
-- ============================================================
