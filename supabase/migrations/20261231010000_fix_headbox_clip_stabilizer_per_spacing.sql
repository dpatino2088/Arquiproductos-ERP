-- ============================================================================
-- Fix headbox clip / stabilizer quantity rule (data consistency).
--
-- The mounting clip (RC3024-W) and stabilizer accessory (RC3048-W) are
-- spacing-based components: 1 unit every 500 mm of width. Engineering had
-- already defined them as qty_type = 'per_spacing', qty_spacing_mm = 500 in
-- most templates and in the sibling headbox variant (RC3131-W), but a few
-- headbox alternatives left them as qty_type = 'fixed' (qty 1). Selecting one
-- of those alternatives (e.g. RC3051-W in ROLLER_MOTOR_WHITE_COU_M_HB) showed
-- a single clip / stabilizer instead of scaling with width, under-pricing the
-- product.
--
-- Bracket (RC3025) and end caps (RC3052-W / RC3132-W) stay 'fixed' on purpose.
--
-- NOTE: applied on the remote project via SQL/MCP (migration histories have
-- diverged, so `supabase db push` is not used here). Kept for traceability.
-- ============================================================================

SET search_path = public;

-- 1) Normalize the spacing SKUs to per_spacing = 500 mm in ACTIVE templates.
UPDATE "BOMComponents" child
SET qty_type = 'per_spacing',
    qty_spacing_mm = 500,
    updated_at = now()
FROM "BOMComponents" parent
JOIN "BOMTemplates" t ON t.id = parent.bom_template_id
JOIN "CatalogItems" cci ON cci.id = child.component_item_id
WHERE child.parent_component_id = parent.id
  AND cci.organization_id = child.organization_id
  AND lower(parent.component_role) = 'headbox'
  AND parent.parent_component_id IS NULL
  AND parent.deleted = false AND parent.archived = false
  AND child.deleted = false AND child.archived = false
  AND COALESCE(t.deleted, false) = false
  AND COALESCE(t.archived, false) = false
  AND cci.sku IN ('RC3024-W', 'RC3048-W')
  AND child.qty_type = 'fixed';

-- 2) Purge already soft-deleted, unused duplicate "...Copy" templates.
DELETE FROM "BOMComponents"
WHERE bom_template_id IN (
  SELECT id FROM "BOMTemplates"
  WHERE name ILIKE 'Roller Shade Cassette Side Channel Motor White M Copy%'
    AND deleted = true AND archived = true
    AND NOT EXISTS (
      SELECT 1 FROM "ConfiguredProducts" cp WHERE cp.bom_template_id = "BOMTemplates".id
    )
);

DELETE FROM "BOMTemplates"
WHERE name ILIKE 'Roller Shade Cassette Side Channel Motor White M Copy%'
  AND deleted = true AND archived = true
  AND NOT EXISTS (
    SELECT 1 FROM "ConfiguredProducts" cp WHERE cp.bom_template_id = "BOMTemplates".id
  );
