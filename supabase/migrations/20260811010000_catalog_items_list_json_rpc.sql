-- Catalog list fast path: one request instead of ~18.
--
-- The catalog Items list used to page CatalogItems sequentially (1000/req),
-- then fire 15+ CatalogItemsMSRP .in() batches, taking 6s+ to load. This RPC
-- returns the whole org catalog (items + manufacturer name + MSRP) as a single
-- jsonb payload (~1.7 MB), bypassing PostgREST row caps in one round-trip.
--
-- SECURITY INVOKER: RLS on CatalogItems / Manufacturers / CatalogItemsMSRP
-- applies to the caller exactly as with the direct table queries it replaces.

CREATE OR REPLACE FUNCTION public.catalog_items_list_json(
  p_org_id uuid,
  p_status text DEFAULT 'all'
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(t.row_data ORDER BY t.sku_sort), '[]'::jsonb)
  FROM (
    SELECT
      ci.sku AS sku_sort,
      to_jsonb(ci.*)
        || jsonb_build_object(
             'manufacturer_name', m.name,
             'msrp_value', mp.msrp,
             'dealer_price_value', mp.dealer_price
           ) AS row_data
    FROM public."CatalogItems" ci
    LEFT JOIN public."Manufacturers" m
      ON m.id = ci.manufacturer_id
    LEFT JOIN public."CatalogItemsMSRP" mp
      ON mp.catalog_item_id = ci.id
     AND mp.organization_id = ci.organization_id
    WHERE ci.organization_id = p_org_id
      AND (
        p_status = 'all'
        OR (p_status = 'active' AND ci.is_active = true)
        OR (p_status = 'inactive' AND ci.is_active = false)
      )
  ) t;
$$;

COMMENT ON FUNCTION public.catalog_items_list_json(uuid, text) IS
  'Full catalog list (items + manufacturer name + msrp/dealer_price) as one jsonb array ordered by sku. Read-only fast path for the catalog Items list.';
