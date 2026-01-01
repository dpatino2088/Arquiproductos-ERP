-- ====================================================
-- Verify BOM Mappings
-- ====================================================
-- Check what mappings were created
-- ====================================================

-- 1) HardwareColorMapping summary
SELECT 
  'HardwareColorMapping' as table_name,
  COUNT(*) as total_mappings,
  COUNT(DISTINCT base_part_id) as unique_base_parts,
  COUNT(DISTINCT hardware_color) as colors_mapped
FROM "HardwareColorMapping"
WHERE deleted = false;

-- 2) HardwareColorMapping details (first 20)
SELECT 
  ci_base.sku as base_sku,
  ci_base.item_name as base_name,
  hcm.hardware_color,
  ci_mapped.sku as mapped_sku,
  ci_mapped.item_name as mapped_name
FROM "HardwareColorMapping" hcm
JOIN "CatalogItems" ci_base ON hcm.base_part_id = ci_base.id
JOIN "CatalogItems" ci_mapped ON hcm.mapped_part_id = ci_mapped.id
WHERE hcm.deleted = false
ORDER BY ci_base.sku, hcm.hardware_color
LIMIT 20;

-- 3) CassettePartsMapping summary
SELECT 
  'CassettePartsMapping' as table_name,
  COUNT(*) as total_mappings,
  COUNT(DISTINCT cassette_shape) as shapes_mapped,
  COUNT(DISTINCT part_role) as roles_mapped
FROM "CassettePartsMapping"
WHERE deleted = false;

-- 4) CassettePartsMapping details
SELECT 
  cpm.cassette_shape,
  cpm.part_role,
  ci.sku,
  ci.item_name,
  cpm.qty_per_unit
FROM "CassettePartsMapping" cpm
JOIN "CatalogItems" ci ON cpm.catalog_item_id = ci.id
WHERE cpm.deleted = false
ORDER BY cpm.cassette_shape, cpm.part_role;

-- 5) MotorTubeCompatibility (should be empty for now)
SELECT 
  'MotorTubeCompatibility' as table_name,
  COUNT(*) as total_entries
FROM "MotorTubeCompatibility"
WHERE deleted = false;









