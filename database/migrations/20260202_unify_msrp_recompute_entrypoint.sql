-- ====================================================
-- MIGRATION: Unify MSRP recompute entrypoint
-- Date: 2026-02-02
--
-- Problem:
-- Several triggers call public.msrp_compute_for_item(item_id), while others
-- call public.recompute_catalog_item_msrp(org_id, item_id). If these functions
-- differ, UI shows inconsistent MSRP.
--
-- Fix:
-- Make msrp_compute_for_item() delegate to recompute_catalog_item_msrp()
-- so there is a single source of truth.
-- ====================================================

BEGIN;

CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
BEGIN
  SELECT organization_id INTO v_org_id
  FROM public."CatalogItems"
  WHERE id = p_item_id;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  -- Single source of truth:
  PERFORM public.recompute_catalog_item_msrp(v_org_id, p_item_id);
END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") IS
'Entry point for MSRP recomputation (legacy name). Delegates to recompute_catalog_item_msrp(org_id, item_id).';

COMMIT;

