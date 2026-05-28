-- Normalize the last lingering window_film SKU that was still priced per
-- square meter (m2). All window_film should be priced per linear meter (m),
-- because rolls are sold linearly even though they cover a 2D area.
--
-- Idempotent: only updates rows that match (sku + pricing_uom='m2'). Generated
-- columns total_cost / dealer_price / msrp recompute automatically via
-- existing triggers when pricing_cost_exw changes.
--
-- Conversion: pricing_cost_exw_new ($/m linear) = pricing_cost_exw_old ($/m2)
--                                                  × roll_width_m
-- For OPTIVISION 45 DA SR-72 (1.8288m wide):
--   6.7274 × 1.8288 ≈ 12.30502  -> rounded to 12.3050

UPDATE public."CatalogItemsMSRP" cim
SET pricing_cost_exw = ROUND((cim.pricing_cost_exw * ci.roll_width_m)::numeric, 4),
    pricing_uom      = 'm',
    updated_at       = now()
FROM public."CatalogItems" ci
WHERE cim.catalog_item_id = ci.id
  AND cim.organization_id = ci.organization_id
  AND ci.sku = 'OPTIVISION 45 DA SR-72'
  AND ci.is_active = true
  AND cim.pricing_uom = 'm2'
  AND ci.roll_width_m IS NOT NULL
  AND ci.roll_width_m > 0;
