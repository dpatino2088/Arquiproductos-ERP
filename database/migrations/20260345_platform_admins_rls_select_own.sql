-- DEPRECATED: Role/SuperAdmin is now read from AppUsers (user_type='org', role_code).
-- This migration only runs if PlatformAdmins table exists; safe to keep for legacy DBs.
-- Frontend uses AppUsers as single source of truth (useCurrentOrgRole, OrganizationContext, useAccessContext).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'PlatformAdmins'
  ) THEN
    ALTER TABLE public."PlatformAdmins" ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "platformadmins_select_own" ON public."PlatformAdmins";
    CREATE POLICY "platformadmins_select_own"
      ON public."PlatformAdmins"
      FOR SELECT
      USING (user_id = auth.uid());
    RAISE NOTICE 'PlatformAdmins: RLS enabled and policy platformadmins_select_own created.';
  ELSE
    RAISE NOTICE 'PlatformAdmins table does not exist; skipping. Create it and add a row for SuperAdmin user_id, then re-run this migration.';
  END IF;
END $$;
