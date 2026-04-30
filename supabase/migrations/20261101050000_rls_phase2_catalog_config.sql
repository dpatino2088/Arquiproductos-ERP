-- RLS Phase 2: catalog and configuration tables (org-scoped)
-- All have `organization_id`. Read for org members; write for admins.
-- Manufacturers stays writable by org members because it is referenced by
-- regular catalog flows.

DO $$
DECLARE
  t TEXT;
  p_select TEXT;
  p_insert TEXT;
  p_update TEXT;
  p_delete TEXT;
  member_writes BOOLEAN;
  tables TEXT[] := ARRAY[
    'Manufacturers',
    'ProductTypes',
    'CostSettings',
    'ImportTaxRules',
    'CategoryMargins',
    'CatalogItemProductTypes',
    'CatalogRoleCategoryMap',
    'ProductTypeRoleRules',
    'CatalogItemConversions',
    'FabricRules'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);

    p_select := format('rls_%s_select', lower(t));
    p_insert := format('rls_%s_insert', lower(t));
    p_update := format('rls_%s_update', lower(t));
    p_delete := format('rls_%s_delete', lower(t));

    -- Manufacturers must be writable by any org member (it is created from
    -- the catalog form). Other tables are admin-only writes.
    member_writes := (t = 'Manufacturers');

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', p_select, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT USING (is_org_user_member(organization_id));',
      p_select, t
    );

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', p_insert, t);
    IF member_writes THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR INSERT WITH CHECK (is_org_user_member(organization_id));',
        p_insert, t
      );
    ELSE
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR INSERT WITH CHECK (is_org_owner_or_admin(organization_id));',
        p_insert, t
      );
    END IF;

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', p_update, t);
    IF member_writes THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR UPDATE USING (is_org_user_member(organization_id)) WITH CHECK (is_org_user_member(organization_id));',
        p_update, t
      );
    ELSE
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR UPDATE USING (is_org_owner_or_admin(organization_id)) WITH CHECK (is_org_owner_or_admin(organization_id));',
        p_update, t
      );
    END IF;

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', p_delete, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE USING (is_org_owner_or_admin(organization_id));',
      p_delete, t
    );
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
