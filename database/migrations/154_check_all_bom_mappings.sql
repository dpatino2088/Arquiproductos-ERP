-- ====================================================
-- Check All BOM Mappings Created
-- ====================================================
-- Quick summary of all mappings created
-- ====================================================

-- 1) HardwareColorMapping Summary
SELECT 
  'HardwareColorMapping' as mapping_type,
  COUNT(*) as total_mappings,
  COUNT(DISTINCT base_part_id) as unique_base_parts,
  COUNT(DISTINCT hardware_color) as colors_mapped,
  COUNT(*) FILTER (WHERE hardware_color = 'white') as white_mappings,
  COUNT(*) FILTER (WHERE hardware_color = 'black') as black_mappings,
  COUNT(*) FILTER (WHERE hardware_color = 'bronze') as bronze_mappings,
  COUNT(*) FILTER (WHERE hardware_color = 'silver') as silver_mappings
FROM "HardwareColorMapping"
WHERE deleted = false;

-- 2) Sample HardwareColorMapping (first 10)
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
LIMIT 10;

-- 3) CassettePartsMapping Summary
SELECT 
  'CassettePartsMapping' as mapping_type,
  COUNT(*) as total_mappings,
  COUNT(DISTINCT cassette_shape) as shapes_mapped,
  COUNT(DISTINCT part_role) as roles_mapped
FROM "CassettePartsMapping"
WHERE deleted = false;

-- 4) CassettePartsMapping Details
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

-- 5) MotorTubeCompatibility Summary
SELECT 
  'MotorTubeCompatibility' as mapping_type,
  COUNT(*) as total_entries,
  COUNT(DISTINCT tube_type) as tube_types,
  COUNT(DISTINCT motor_family) as motor_families
FROM "MotorTubeCompatibility"
WHERE deleted = false;

-- 6) MotorTubeCompatibility Details
SELECT 
  mtc.tube_type,
  mtc.motor_family,
  ci_crown.sku as crown_sku,
  ci_crown.item_name as crown_name,
  ci_drive.sku as drive_sku,
  ci_drive.item_name as drive_name,
  mtc.notes
FROM "MotorTubeCompatibility" mtc
LEFT JOIN "CatalogItems" ci_crown ON mtc.required_crown_item_id = ci_crown.id
LEFT JOIN "CatalogItems" ci_drive ON mtc.required_drive_item_id = ci_drive.id
WHERE mtc.deleted = false
ORDER BY mtc.tube_type, mtc.motor_family;









