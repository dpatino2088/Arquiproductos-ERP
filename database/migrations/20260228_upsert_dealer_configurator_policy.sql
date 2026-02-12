-- RPC to upsert DealerConfiguratorPolicies (used by Settings → Dealer Profile → Configurator Permissions tab).
-- Idempotent: safe to run even if function already exists (e.g. from full dump).
CREATE OR REPLACE FUNCTION public.upsert_dealer_configurator_policy(
  p_org_id uuid,
  p_dealer_id uuid,
  p_allowed_product_type_codes text[],
  p_allow_variants_catalog boolean,
  p_allow_variants_oneoff boolean,
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
    allow_variants_oneoff,
    allow_accessories_only,
    allow_hardware,
    allow_operating_system
  )
  VALUES (
    p_org_id,
    p_dealer_id,
    p_allowed_product_type_codes,
    p_allow_variants_catalog,
    p_allow_variants_oneoff,
    p_allow_accessories_only,
    p_allow_hardware,
    p_allow_operating_system
  )
  ON CONFLICT (organization_id, dealer_id)
  DO UPDATE SET
    allowed_product_type_codes = EXCLUDED.allowed_product_type_codes,
    allow_variants_catalog = EXCLUDED.allow_variants_catalog,
    allow_variants_oneoff = EXCLUDED.allow_variants_oneoff,
    allow_accessories_only = EXCLUDED.allow_accessories_only,
    allow_hardware = EXCLUDED.allow_hardware,
    allow_operating_system = EXCLUDED.allow_operating_system,
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION public.upsert_dealer_configurator_policy(uuid, uuid, text[], boolean, boolean, boolean, boolean, boolean)
  IS 'Upserts one row in DealerConfiguratorPolicies per (org, dealer). Used by Settings → Dealer Profile → Configurator Permissions.';
