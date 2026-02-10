-- =====================================================
-- Fix is_org_user_member WITHOUT DROP (policies depend on it)
-- =====================================================
-- - No DROP FUNCTION. Use CREATE OR REPLACE with same param name as PROD.
-- - Detect current param name via pg_proc.proargnames[1] and use dynamic SQL.
-- - Return true if auth.uid() in OrganizationUsers OR DealerUsers for org,
--   with coalesce(deleted,false)=false and status in ('active','invited') or null.
-- - Optional: SELECT policy for ConfiguredProductOptions if table exists.
-- =====================================================

SET search_path = public;

DO $$
DECLARE
  v_arg_name text;
  v_sql text;
BEGIN
  -- Get current parameter name (PROD uses p_org_id)
  SELECT proargnames[1] INTO v_arg_name
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'is_org_user_member';

  -- If function does not exist yet, use p_org_id
  IF v_arg_name IS NULL THEN
    v_arg_name := 'p_org_id';
  END IF;

  v_sql := format(
    'CREATE OR REPLACE FUNCTION public.is_org_user_member(%I uuid) '
    'RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $body$ '
    'SELECT '
    '  EXISTS (SELECT 1 FROM public."OrganizationUsers" ou WHERE ou.organization_id = %I AND ou.user_id = auth.uid() AND coalesce(ou.deleted, false) = false AND (ou.status IS NULL OR ou.status IN (''active'', ''invited''))) '
    '  OR EXISTS (SELECT 1 FROM public."DealerUsers" du WHERE du.organization_id = %I AND du.user_id = auth.uid() AND coalesce(du.deleted, false) = false AND (du.status IS NULL OR du.status IN (''active'', ''invited''))); '
    '$body$',
    v_arg_name,
    v_arg_name,
    v_arg_name
  );

  EXECUTE v_sql;
END;
$$;

COMMENT ON FUNCTION public.is_org_user_member(uuid) IS
  'Returns true if current user is an active/invited member of the organization via OrganizationUsers OR DealerUsers (portal). No DROP used; policies depend on this function.';

-- =====================================================
-- ConfiguredProductOptions: SELECT policy if table exists
-- =====================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProductOptions'
  ) THEN
    DROP POLICY IF EXISTS configured_product_options_select_org ON "public"."ConfiguredProductOptions";
    CREATE POLICY configured_product_options_select_org
      ON "public"."ConfiguredProductOptions"
      FOR SELECT TO authenticated
      USING (public.is_org_user_member(organization_id));
  END IF;
END;
$$;
