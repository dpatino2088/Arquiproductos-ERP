-- ============================================================================
-- Migration: Remove allow_variants_oneoff from policy (One-Off removed)
-- Date: 2026-02-13
-- Description: DealerConfiguratorPolicies table no longer has allow_variants_oneoff.
--              Update assert_dealer_configurator_policy and upsert_dealer_configurator_policy
--              to not reference that column.
-- ============================================================================

-- 1) assert_dealer_configurator_policy: remove SELECT of allow_variants_oneoff and OneOff check
CREATE OR REPLACE FUNCTION public.assert_dealer_configurator_policy(
  p_org_id uuid,
  p_dealer_id uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_pt_code text;
  v_allowed text[];
BEGIN
  IF p_dealer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT lower(pt.code)
    INTO v_pt_code
  FROM public."ProductTypes" pt
  WHERE pt.organization_id = p_org_id
    AND pt.id = p_product_type_id;

  IF v_pt_code IS NULL THEN
    RAISE EXCEPTION 'Invalid product_type_id % for org %', p_product_type_id, p_org_id
      USING errcode = '22023';
  END IF;

  SELECT coalesce(p.allowed_product_type_codes, '{}'::text[])
    INTO v_allowed
  FROM public."DealerConfiguratorPolicies" p
  WHERE p.organization_id = p_org_id
    AND p.dealer_id = p_dealer_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF array_length(v_allowed, 1) IS NULL THEN
    RAISE EXCEPTION 'No product types assigned for this dealer'
      USING errcode = '42501';
  END IF;

  IF NOT (v_pt_code = ANY (v_allowed)) THEN
    RAISE EXCEPTION 'Product type "%" is not allowed for this dealer', v_pt_code
      USING errcode = '42501';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.assert_dealer_configurator_policy(uuid, uuid, uuid, jsonb) IS
'Validates dealer configurator policy: product type must be in allowed_product_type_codes. One-Off removed.';


-- 2) upsert_dealer_configurator_policy: remove p_allow_variants_oneoff and column references
DROP FUNCTION IF EXISTS public.upsert_dealer_configurator_policy(uuid, uuid, text[], boolean, boolean, boolean, boolean, boolean);

CREATE OR REPLACE FUNCTION public.upsert_dealer_configurator_policy(
  p_org_id uuid,
  p_dealer_id uuid,
  p_allowed_product_type_codes text[],
  p_allow_variants_catalog boolean,
  p_allow_accessories_only boolean,
  p_allow_hardware boolean,
  p_allow_operating_system boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public."DealerConfiguratorPolicies" (
    organization_id,
    dealer_id,
    allowed_product_type_codes,
    allow_variants_catalog,
    allow_accessories_only,
    allow_hardware,
    allow_operating_system
  )
  VALUES (
    p_org_id,
    p_dealer_id,
    p_allowed_product_type_codes,
    p_allow_variants_catalog,
    p_allow_accessories_only,
    p_allow_hardware,
    p_allow_operating_system
  )
  ON CONFLICT (organization_id, dealer_id)
  DO UPDATE SET
    allowed_product_type_codes = EXCLUDED.allowed_product_type_codes,
    allow_variants_catalog = EXCLUDED.allow_variants_catalog,
    allow_accessories_only = EXCLUDED.allow_accessories_only,
    allow_hardware = EXCLUDED.allow_hardware,
    allow_operating_system = EXCLUDED.allow_operating_system,
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION public.upsert_dealer_configurator_policy(uuid, uuid, text[], boolean, boolean, boolean, boolean) IS
'Upserts one row in DealerConfiguratorPolicies per (org, dealer). One-Off (allow_variants_oneoff) removed.';
