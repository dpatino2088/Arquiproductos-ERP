-- ============================================================================
-- Catalog Profiles Cleanup
-- Move non-aluminum accessories out of Profiles category hierarchy
-- so that Profile Cut workstation only routes linear aluminium items.
-- ============================================================================

SET search_path = public;

-- Create 'Connectors' subcategory under Hardware
INSERT INTO "CatalogCategories" (name, parent_id, organization_id, deleted)
SELECT 'Connectors', hw.id, hw.organization_id, false
FROM "CatalogCategories" hw
WHERE hw.name = 'Hardware' AND hw.parent_id IS NULL AND hw.deleted = false
ON CONFLICT DO NOTHING;

-- 1. Move carriers → Hardware > Carrier
UPDATE "CatalogItems"
SET category_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Carrier' AND parent_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Hardware' AND parent_id IS NULL LIMIT 1) LIMIT 1)
WHERE sku IN ('CC1025-W', 'CC1026-W', 'CC1011-W', 'CC1011-BK', 'CC1012-W', 'CC1012-BK', 'CC1020-W', 'CC1020-BK');

-- 2. Move connectors → Hardware > Connectors
UPDATE "CatalogItems"
SET category_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Connectors' AND parent_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Hardware' AND parent_id IS NULL LIMIT 1) LIMIT 1)
WHERE sku IN ('CC1009', 'CC1010', 'CC1016-W', 'CC1016-BK', 'CC1021-W', 'CC1021-BK', 'VC12-RTC-R', 'VC12-RTC-L', 'RC4040-W', 'RC4040-GR');

-- 3. Move drive belts/runners → Accesories > Belt
UPDATE "CatalogItems"
SET category_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Belt' AND parent_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Accesories' AND parent_id IS NULL LIMIT 1) LIMIT 1)
WHERE sku IN ('VC31', 'VC32-W', 'VC33-W');

-- 4. Move bottom bar endcaps (unit items) → Hardware > End Plugs
UPDATE "CatalogItems"
SET category_id = (SELECT id FROM "CatalogCategories" WHERE name = 'End Plugs' AND parent_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Hardware' AND parent_id IS NULL LIMIT 1) LIMIT 1)
WHERE sku LIKE 'RC2056-%';

-- 5. Move headbox unit accessories → Hardware > Parts
UPDATE "CatalogItems"
SET category_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Parts' AND parent_id = (SELECT id FROM "CatalogCategories" WHERE name = 'Hardware' AND parent_id IS NULL LIMIT 1) LIMIT 1)
WHERE sku IN ('RC3119-W', 'RC4048', 'RC2015') OR sku LIKE 'RC4042-%' OR sku LIKE 'RC3118-%';

-- 6. Update CUT-PROFILE routing rule to enforce measure_basis = linear
UPDATE "WorkCenters"
SET routing_rule = '{"measure_basis": "linear", "category_parent_names": ["Profiles"]}'::jsonb
WHERE code = 'CUT-PROFILE';

DO $$ BEGIN RAISE NOTICE 'Catalog profiles cleanup: non-aluminum items moved out of Profiles, CUT-PROFILE rule updated'; END $$;
