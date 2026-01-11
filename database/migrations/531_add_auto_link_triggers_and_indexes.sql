-- ============================================================
-- Migration: Add auto-linking triggers and ensure unique indexes
-- ============================================================
-- OBJECTIVE:
-- 1. Ensure user_id is nullable in both OrganizationUsers and CompanyPortalUsers (for invites)
-- 2. Create/update unique indexes to prevent duplicates
-- 3. Create triggers to automatically link invites when auth.users is created
-- 4. Clean up any duplicate constraints/FKs
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Ensure user_id is nullable in OrganizationUsers (should already be, but confirm)
-- ============================================================
DO $$
BEGIN
  -- Check if user_id has a NOT NULL constraint and remove it if it exists
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'OrganizationUsers'
      AND column_name = 'user_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public."OrganizationUsers" ALTER COLUMN user_id DROP NOT NULL;
    RAISE NOTICE 'Removed NOT NULL constraint from OrganizationUsers.user_id';
  ELSE
    RAISE NOTICE 'OrganizationUsers.user_id is already nullable';
  END IF;
END $$;

-- ============================================================
-- 2) Ensure user_id is nullable in CompanyPortalUsers (should already be, but confirm)
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CompanyPortalUsers'
      AND column_name = 'user_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" ALTER COLUMN user_id DROP NOT NULL;
    RAISE NOTICE 'Removed NOT NULL constraint from CompanyPortalUsers.user_id';
  ELSE
    RAISE NOTICE 'CompanyPortalUsers.user_id is already nullable';
  END IF;
END $$;

-- ============================================================
-- 3) Ensure unique indexes exist (create if missing, update if needed)
-- ============================================================

-- OrganizationUsers: unique by (organization_id, lower(user_email)) WHERE deleted=false
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'OrganizationUsers'
      AND indexname = 'organizationusers_org_email_unique'
  ) THEN
    CREATE UNIQUE INDEX organizationusers_org_email_unique
      ON public."OrganizationUsers" (organization_id, lower(user_email))
      WHERE deleted = false;
    RAISE NOTICE 'Created unique index organizationusers_org_email_unique';
  ELSE
    RAISE NOTICE 'Index organizationusers_org_email_unique already exists';
  END IF;
END $$;

-- CompanyPortalUsers: unique by (organization_id, lower(portal_user_email)) WHERE deleted=false
-- Note: If company_id is part of the model, we should use that instead. Checking schema...
DO $$
BEGIN
  -- Check if organization_id exists in CompanyPortalUsers
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CompanyPortalUsers'
      AND column_name = 'organization_id'
  ) THEN
    -- Use organization_id for uniqueness (if it exists)
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename = 'CompanyPortalUsers'
        AND indexname = 'companyportalusers_org_email_unique'
    ) THEN
      CREATE UNIQUE INDEX companyportalusers_org_email_unique
        ON public."CompanyPortalUsers" (organization_id, lower(portal_user_email))
        WHERE deleted = false;
      RAISE NOTICE 'Created unique index companyportalusers_org_email_unique (by organization_id)';
    ELSE
      RAISE NOTICE 'Index companyportalusers_org_email_unique already exists';
    END IF;
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CompanyPortalUsers'
      AND column_name = 'company_id'
  ) THEN
    -- Fallback to company_id for uniqueness
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename = 'CompanyPortalUsers'
        AND indexname = 'companyportalusers_company_email_unique'
    ) THEN
      CREATE UNIQUE INDEX companyportalusers_company_email_unique
        ON public."CompanyPortalUsers" (company_id, lower(portal_user_email))
        WHERE deleted = false;
      RAISE NOTICE 'Created unique index companyportalusers_company_email_unique (by company_id)';
    ELSE
      RAISE NOTICE 'Index companyportalusers_company_email_unique already exists';
    END IF;
  END IF;
END $$;

-- ============================================================
-- 4) Create trigger function to auto-link OrganizationUsers on auth.users creation
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_auth_user_created_for_org_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Link OrganizationUsers where email matches and user_id is null
  UPDATE public."OrganizationUsers"
  SET
    user_id = NEW.id,
    status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
    accepted_at = COALESCE(accepted_at, now()),
    updated_at = now()
  WHERE
    lower(user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_auth_user_created_for_org_users IS 
  'Automatically links OrganizationUsers invites when a new auth.users is created. Matches by lower(email).';

-- Create trigger on auth.users (if it doesn't exist)
DROP TRIGGER IF EXISTS on_auth_user_created_link_org_users ON auth.users;
CREATE TRIGGER on_auth_user_created_link_org_users
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user_created_for_org_users();

-- ============================================================
-- 5) Create trigger function to auto-link CompanyPortalUsers on auth.users creation
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_auth_user_created_for_portal_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Link CompanyPortalUsers where email matches and user_id is null
  UPDATE public."CompanyPortalUsers"
  SET
    user_id = NEW.id,
    portal_user_status = CASE 
      WHEN portal_user_status IN ('invited', 'draft') THEN 'active'
      ELSE portal_user_status
    END,
    accepted_at = COALESCE(accepted_at, now()),
    updated_at = now()
  WHERE
    lower(portal_user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_auth_user_created_for_portal_users IS 
  'Automatically links CompanyPortalUsers invites when a new auth.users is created. Matches by lower(portal_user_email).';

-- Create trigger on auth.users (if it doesn't exist)
DROP TRIGGER IF EXISTS on_auth_user_created_link_portal_users ON auth.users;
CREATE TRIGGER on_auth_user_created_link_portal_users
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user_created_for_portal_users();

-- ============================================================
-- 6) Ensure no duplicate FKs pointing to auth.users
-- ============================================================
-- Note: PostgreSQL automatically handles FK constraints. We just need to ensure
-- they point to auth.users(id) and not to any non-existent "public.users" table.

-- Check for any FKs pointing to non-existent tables
DO $$
DECLARE
  fk_record record;
BEGIN
  FOR fk_record IN
    SELECT
      tc.table_schema,
      tc.table_name,
      tc.constraint_name,
      kcu.column_name,
      ccu.table_schema AS foreign_table_schema,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
      AND tc.table_name IN ('OrganizationUsers', 'CompanyPortalUsers')
      AND kcu.column_name = 'user_id'
      AND (ccu.table_schema, ccu.table_name) != ('auth', 'users')
  LOOP
    RAISE NOTICE 'Found FK constraint % on %.% pointing to %.%, expected auth.users. Review manually.', 
      fk_record.constraint_name, 
      fk_record.table_schema, 
      fk_record.table_name,
      fk_record.foreign_table_schema,
      fk_record.foreign_table_name;
  END LOOP;
END $$;

-- ============================================================
-- 7) Update link_my_org_invites to also link CompanyPortalUsers
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
    -- Get current authenticated user
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
        WHERE 
            lower(user_email) = lower(v_user_email)
            AND user_id IS NULL
            AND deleted = false
        RETURNING id
    )
    SELECT 
        COUNT(*)::integer,
        ARRAY_AGG(id)::uuid[]
    INTO v_linked_count, v_updated_ids
    FROM updated;

    -- Link CompanyPortalUsers
    WITH updated_portal AS (
        UPDATE public."CompanyPortalUsers"
        SET
            user_id = v_user_id,
            portal_user_status = CASE 
                WHEN portal_user_status IN ('invited', 'draft') THEN 'active'
                ELSE portal_user_status
            END,
            accepted_at = COALESCE(accepted_at, now()),
            updated_at = now()
        WHERE
            lower(portal_user_email) = lower(v_user_email)
            AND user_id IS NULL
            AND deleted = false
        RETURNING id
    )
    SELECT
        COUNT(*)::integer,
        ARRAY_AGG(id)::uuid[]
    INTO v_portal_linked_count, v_portal_updated_ids
    FROM updated_portal;

    -- Return combined count
    RETURN QUERY SELECT 
        (v_linked_count + v_portal_linked_count)::integer,
        (v_updated_ids || v_portal_updated_ids)::uuid[];
END;
$$;

COMMENT ON FUNCTION public.link_my_org_invites() IS 
    'Links both OrganizationUsers and CompanyPortalUsers invites for the current authenticated user. Matches by email. Returns combined count and array of all updated IDs.';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Ensured user_id is nullable in both OrganizationUsers and CompanyPortalUsers
-- 2. Created/verified unique indexes for preventing duplicates
-- 3. Created triggers to auto-link invites when auth.users is created
-- 4. Updated link_my_org_invites RPC to also link CompanyPortalUsers
-- ============================================================
