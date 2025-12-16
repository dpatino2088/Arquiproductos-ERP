-- ====================================================
-- Seed Data: Catalog Dummy Data (Easy to Delete)
-- ====================================================
-- This file contains minimal dummy data for testing Catalog functionality
-- To delete all dummy data, run the DELETE statements at the bottom of this file
-- ====================================================

-- NOTE: This script automatically uses the first organization_id from "Organizations"
-- If you have multiple organizations, modify the CTE to select a specific one

-- ====================================================
-- DUMMY DATA: CatalogItems
-- ====================================================

-- Fabric Items (Telas)
-- Using CTE to get organization_id automatically
WITH org AS (
    SELECT id FROM "Organizations" LIMIT 1
)
INSERT INTO "CatalogItems" (
    organization_id,
    sku,
    name,
    description,
    item_type,
    measure_basis,
    uom,
    is_fabric,
    roll_width_m,
    fabric_pricing_mode,
    unit_price,
    cost_price,
    active,
    discontinued
)
SELECT 
    org.id,
    'FAB-ESS3000-01',
    'Essential 3000 - Chalk 5%',
    'Roller shade fabric Essential 3000 in Chalk 5% color',
    'fabric'::catalog_item_type,
    'fabric'::measure_basis,
    'roll',
    true,
    1.5,
    'per_linear_m'::fabric_pricing_mode,
    28.50,
    15.00,
    true,
    false
FROM org
UNION ALL
SELECT 
    org.id,
    'FAB-SUNSET-01',
    'Sunset Blackout - Black',
    'Blackout fabric Sunset in Black color',
    'fabric'::catalog_item_type,
    'fabric'::measure_basis,
    'roll',
    true,
    3.0,
    'per_linear_m'::fabric_pricing_mode,
    35.00,
    20.00,
    true,
    false
FROM org;

-- Component Items (Componentes)
WITH org AS (
    SELECT id FROM "Organizations" LIMIT 1
)
INSERT INTO "CatalogItems" (
    organization_id,
    sku,
    name,
    description,
    item_type,
    measure_basis,
    uom,
    is_fabric,
    unit_price,
    cost_price,
    active,
    discontinued
)
SELECT 
    org.id,
    'CASS-001',
    'Standard Cassette 42mm',
    'Standard cassette for roller shades',
    'component'::catalog_item_type,
    'unit'::measure_basis,
    'unit',
    false,
    45.00,
    25.00,
    true,
    false
FROM org
UNION ALL
SELECT 
    org.id,
    'MOT-EDU-001',
    'Lutron EDU Motor',
    'Smart motor for roller shades',
    'component'::catalog_item_type,
    'unit'::measure_basis,
    'unit',
    false,
    250.00,
    150.00,
    true,
    false
FROM org
UNION ALL
SELECT 
    org.id,
    'TUBE-42-001',
    'Tube 42mm Standard',
    'Standard tube for roller shades',
    'linear'::catalog_item_type,
    'linear_m'::measure_basis,
    'm',
    false,
    12.00,
    6.00,
    true,
    false
FROM org;

-- Accessory Items (Accesorios)
WITH org AS (
    SELECT id FROM "Organizations" LIMIT 1
)
INSERT INTO "CatalogItems" (
    organization_id,
    sku,
    name,
    description,
    item_type,
    measure_basis,
    uom,
    is_fabric,
    unit_price,
    cost_price,
    active,
    discontinued
)
SELECT 
    org.id,
    'CTRL-WALL-001',
    'Wall Control',
    'Wall-mounted control for motorized shades',
    'accessory'::catalog_item_type,
    'unit'::measure_basis,
    'unit',
    false,
    45.00,
    25.00,
    true,
    false
FROM org;

-- ====================================================
-- DELETE DUMMY DATA (Run this to clean up)
-- ====================================================
-- Uncomment and run the following to delete all dummy data:

/*
DELETE FROM "CatalogItems"
WHERE sku IN (
    'FAB-ESS3000-01',
    'FAB-SUNSET-01',
    'CASS-001',
    'MOT-EDU-001',
    'TUBE-42-001',
    'CTRL-WALL-001'
);
*/

-- ====================================================
-- VERIFY DATA (Optional - to check what was inserted)
-- ====================================================
-- Uncomment and run this to see all inserted dummy data:

/*
SELECT 
    sku,
    name,
    measure_basis,
    is_fabric,
    unit_price,
    active
FROM "CatalogItems"
WHERE sku IN (
    'FAB-ESS3000-01',
    'FAB-SUNSET-01',
    'CASS-001',
    'MOT-EDU-001',
    'TUBE-42-001',
    'CTRL-WALL-001'
)
ORDER BY sku;
*/

