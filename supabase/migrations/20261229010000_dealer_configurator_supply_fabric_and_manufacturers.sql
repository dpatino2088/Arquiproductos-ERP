-- Per-dealer configurator permissions:
--   1) allow_dealer_supply_fabric: dealer may quote a configured product WITHOUT a catalog fabric
--      (dealer/client supplies the fabric; cut list is kept, fabric cost excluded).
--   2) allowed_manufacturer_names: restrict which manufacturers the dealer can use in the configurator.
--      Empty array = no restriction (all manufacturers allowed).

ALTER TABLE public."DealerConfiguratorPolicies"
  ADD COLUMN IF NOT EXISTS allow_dealer_supply_fabric boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS allowed_manufacturer_names text[] NOT NULL DEFAULT '{}'::text[];

COMMENT ON COLUMN public."DealerConfiguratorPolicies".allow_dealer_supply_fabric
  IS 'When true, the dealer may quote configured products without selecting a catalog fabric (dealer/client supplies the fabric; cut list kept, fabric cost excluded).';
COMMENT ON COLUMN public."DealerConfiguratorPolicies".allowed_manufacturer_names
  IS 'Allowed manufacturer names for this dealer in the configurator. Empty array = no restriction (all manufacturers allowed).';

-- Recreate the upsert RPC with the two new parameters.
-- Drop prior signatures to avoid named-argument ambiguity (8-arg current, 7-arg legacy).
DROP FUNCTION IF EXISTS public.upsert_dealer_configurator_policy(uuid, uuid, text[], boolean, boolean, boolean, boolean, boolean);
DROP FUNCTION IF EXISTS public.upsert_dealer_configurator_policy(uuid, uuid, text[], boolean, boolean, boolean, boolean);

CREATE OR REPLACE FUNCTION public.upsert_dealer_configurator_policy(
  p_org_id uuid,
  p_dealer_id uuid,
  p_allowed_product_type_codes text[],
  p_allow_variants_catalog boolean,
  p_allow_accessories_only boolean,
  p_allow_hardware boolean,
  p_allow_operating_system boolean,
  p_allow_custom_only_proposals boolean DEFAULT false,
  p_allow_dealer_supply_fabric boolean DEFAULT false,
  p_allowed_manufacturer_names text[] DEFAULT '{}'::text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public."DealerConfiguratorPolicies" (
    organization_id,
    dealer_id,
    allowed_product_type_codes,
    allow_variants_catalog,
    allow_accessories_only,
    allow_hardware,
    allow_operating_system,
    allow_custom_only_proposals,
    allow_dealer_supply_fabric,
    allowed_manufacturer_names
  )
  VALUES (
    p_org_id,
    p_dealer_id,
    p_allowed_product_type_codes,
    p_allow_variants_catalog,
    p_allow_accessories_only,
    p_allow_hardware,
    p_allow_operating_system,
    COALESCE(p_allow_custom_only_proposals, false),
    COALESCE(p_allow_dealer_supply_fabric, false),
    COALESCE(p_allowed_manufacturer_names, '{}'::text[])
  )
  ON CONFLICT (organization_id, dealer_id)
  DO UPDATE SET
    allowed_product_type_codes = EXCLUDED.allowed_product_type_codes,
    allow_variants_catalog = EXCLUDED.allow_variants_catalog,
    allow_accessories_only = EXCLUDED.allow_accessories_only,
    allow_hardware = EXCLUDED.allow_hardware,
    allow_operating_system = EXCLUDED.allow_operating_system,
    allow_custom_only_proposals = EXCLUDED.allow_custom_only_proposals,
    allow_dealer_supply_fabric = EXCLUDED.allow_dealer_supply_fabric,
    allowed_manufacturer_names = EXCLUDED.allowed_manufacturer_names,
    updated_at = now();
END;
$function$;

GRANT EXECUTE ON FUNCTION public.upsert_dealer_configurator_policy(uuid, uuid, text[], boolean, boolean, boolean, boolean, boolean, boolean, text[]) TO authenticated;
