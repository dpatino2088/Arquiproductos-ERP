-- ============================================================================
-- Drapery rail-split rule: connectors driven by rail LENGTH, not panel count.
--
-- The headrail (CC1001 family) is split into pieces of max 4 m. Every split
-- needs a rail connector (CC1016-W) and the drive belt needs a split-rail belt
-- (CC1021-W). The templates modeled both as qty_type = 'per_joint'
-- (= panel_count - 1), so a single-panel curtain (even at 4.2 m) got 0 and a
-- multi-panel <4 m curtain got a spurious connector. Neither respects the 4 m
-- rail rule.
--
-- Fix (data only, no engine change; verified against the SQL BOM engine):
--   * rail_connector CC1016-W -> per_spacing, spacing 4000, delta -4000
--       => CEIL(max(0, width - 4000) / 4000) = number of splits (0,1,2,...).
--   * belt_connector CC1021-W -> per_spacing, spacing 1000000, delta -4000
--       => 0 when width <= 4000, else 1 (capped at 1 for any realistic width,
--          since there is no qty_max column). Engineering rule: max 1 belt.
--
-- Business rule confirmed: center-draw drapery uses ONE continuous rail, so the
-- old panel-based connector was incorrect; length-only is the source of truth.
--
-- NOTE: applied on the remote project via SQL/MCP (migration histories have
-- diverged, so `supabase db push` is not used here). Kept for traceability.
-- Affected quote snapshots NOT already in a Sales Order were regenerated via
-- calculate_configured_product_totals + sync_quote_line_pricing_from_configured_product.
-- ============================================================================

SET search_path = public;

-- Rail connector: scales with 4 m splits.
UPDATE "BOMComponents" child
SET qty_type = 'per_spacing',
    qty_spacing_mm = 4000,
    qty_delta_mm = -4000,
    updated_at = now()
FROM "CatalogItems" cci, "BOMTemplates" t
WHERE cci.id = child.component_item_id
  AND cci.organization_id = child.organization_id
  AND t.id = child.bom_template_id
  AND cci.sku = 'CC1016-W'
  AND child.component_role = 'rail_connector'
  AND child.qty_type = 'per_joint'
  AND child.deleted = false AND child.archived = false
  AND COALESCE(t.deleted, false) = false
  AND COALESCE(t.archived, false) = false;

-- Split-rail belt: 0/1 only (needed once when the rail is split at all).
UPDATE "BOMComponents" child
SET qty_type = 'per_spacing',
    qty_spacing_mm = 1000000,
    qty_delta_mm = -4000,
    updated_at = now()
FROM "CatalogItems" cci, "BOMTemplates" t
WHERE cci.id = child.component_item_id
  AND cci.organization_id = child.organization_id
  AND t.id = child.bom_template_id
  AND cci.sku = 'CC1021-W'
  AND child.component_role = 'belt_connector'
  AND child.qty_type = 'per_joint'
  AND child.deleted = false AND child.archived = false
  AND COALESCE(t.deleted, false) = false
  AND COALESCE(t.archived, false) = false;
