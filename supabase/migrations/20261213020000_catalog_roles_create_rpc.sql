-- Allow controlled creation of global catalog roles under RLS.
-- CatalogItemRoles has SELECT-only policies, so writes must go through SECURITY DEFINER RPC.

CREATE OR REPLACE FUNCTION public.create_catalog_item_role(
  p_org_id uuid,
  p_role_code text,
  p_label text,
  p_role_type text DEFAULT 'both'
)
RETURNS TABLE (
  role_code text,
  label text,
  description text,
  role_type text,
  active boolean,
  sort_order integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_label text;
  v_role_type text;
BEGIN
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'Organization is required';
  END IF;

  IF NOT (public.is_org_user_superadmin(p_org_id) OR public.is_org_owner_or_admin(p_org_id)) THEN
    RAISE EXCEPTION 'Not authorized to create roles for this organization';
  END IF;

  v_code := lower(trim(coalesce(p_role_code, '')));
  v_label := trim(coalesce(p_label, ''));
  v_role_type := lower(trim(coalesce(p_role_type, 'both')));

  IF v_code = '' THEN
    RAISE EXCEPTION 'Role code cannot be empty';
  END IF;
  IF v_label = '' THEN
    RAISE EXCEPTION 'Role label cannot be empty';
  END IF;
  IF v_code !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Role code must be lowercase letters, numbers, and underscores';
  END IF;
  IF v_role_type NOT IN ('parent_only', 'child_only', 'both') THEN
    RAISE EXCEPTION 'Invalid role_type: %', v_role_type;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public."CatalogItemRoles"
    WHERE role_code = v_code
  ) THEN
    RAISE EXCEPTION 'Role code % already exists', v_code;
  END IF;

  INSERT INTO public."CatalogItemRoles" (
    role_code,
    label,
    role_name,
    role_type,
    active,
    sort_order
  ) VALUES (
    v_code,
    v_label,
    v_label,
    v_role_type,
    true,
    0
  );

  RETURN QUERY
  SELECT
    r.role_code,
    r.label,
    r.description,
    r.role_type::text,
    r.active,
    r.sort_order
  FROM public."CatalogItemRoles" r
  WHERE r.role_code = v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_catalog_item_role(uuid, text, text, text) TO authenticated;

COMMENT ON FUNCTION public.create_catalog_item_role(uuid, text, text, text)
IS 'Creates a global CatalogItemRole through controlled admin/superadmin RPC under RLS.';
