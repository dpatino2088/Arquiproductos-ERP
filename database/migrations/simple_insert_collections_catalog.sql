-- ====================================================
-- SIMPLE Direct Insert: Populate CollectionsCatalog from CSV
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Total fabrics: 565
-- Uses SKU to find catalog_item_id (FK to CatalogItems)
-- Collection and Variant come directly from CSV
-- ====================================================
-- 
-- INSTRUCCIONES:
-- 1. Ejecuta este script completo en Supabase SQL Editor
-- 2. Si hay errores, verás exactamente qué INSERT falló
-- 3. El ON CONFLICT evitará duplicados automáticamente
-- ====================================================

-- Insert 1: DRF-BLOCK-0100 | Block | cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Block',
    'cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-BLOCK-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 2: DRF-BLOCK-0200 | Block | grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Block',
    'grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-BLOCK-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 3: DRF-BLOCK-0300 | Block | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Block',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-BLOCK-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 4: DRF-BLOCK-0400 | Block | white/white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Block',
    'white/white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-BLOCK-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 5: DRF-FIJI-0100 | Fiji | white/grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Fiji',
    'white/grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-FIJI-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 6: DRF-FIJI-0200 | Fiji | white/sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Fiji',
    'white/sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-FIJI-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 7: DRF-FIJI-0300 | Fiji | white/black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Fiji',
    'white/black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-FIJI-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 8: DRF-FIJI-0400 | Fiji | beige/brown
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Fiji',
    'beige/brown',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-FIJI-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 9: DRF-FIJI-0600 | Fiji | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Fiji',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-FIJI-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 10: DRF-HONEY-0100 | Honey | cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Honey',
    'cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HONEY-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 11: DRF-HONEY-0200 | Honey | grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Honey',
    'grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HONEY-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 12: DRF-HONEY-0300 | Honey | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Honey',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HONEY-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 13: DRF-HONEY-0400 | Honey | pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Honey',
    'pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HONEY-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 14: DRF-HYDRA-0100 | Hydra | silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hydra',
    'silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HYDRA-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 15: DRF-HYDRA-0200 | Hydra | bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hydra',
    'bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HYDRA-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 16: DRF-HYDRA-0300 | Hydra | steel
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hydra',
    'steel',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HYDRA-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 17: DRF-HYDRA-0400 | Hydra | copper
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hydra',
    'copper',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HYDRA-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 18: DRF-HYDRA-0500 | Hydra | brown sugar
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hydra',
    'brown sugar',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HYDRA-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 19: DRF-HYDRA-0600 | Hydra | fossil
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hydra',
    'fossil',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-HYDRA-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 20: DRF-IKARIA-0100 | Ikaria | saffron
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ikaria',
    'saffron',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-IKARIA-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 21: DRF-IKARIA-0400 | Ikaria | grain
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ikaria',
    'grain',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-IKARIA-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 22: DRF-IKARIA-0500 | Ikaria | concrete
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ikaria',
    'concrete',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-IKARIA-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 23: DRF-IKARIA-0600 | Ikaria | charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ikaria',
    'charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-IKARIA-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 24: DRF-IKARIA-0700 | Ikaria | sky
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ikaria',
    'sky',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-IKARIA-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 25: DRF-IKARIA-0900 | Ikaria | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ikaria',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-IKARIA-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 26: DRF-MADAGASCAR-0100 | Madagascar | grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Madagascar',
    'grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-MADAGASCAR-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 27: DRF-MADAGASCAR-0200 | Madagascar | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Madagascar',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-MADAGASCAR-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 28: DRF-MADAGASCAR-0300 | Madagascar | ice
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Madagascar',
    'ice',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-MADAGASCAR-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 29: DRF-MADAGASCAR-0600 | Madagascar | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Madagascar',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-MADAGASCAR-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 30: DRF-NAXOS-0100 | Naxos | sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Naxos',
    'sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-NAXOS-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 31: DRF-NAXOS-0200 | Naxos | stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Naxos',
    'stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-NAXOS-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 32: DRF-NAXOS-0300 | Naxos | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Naxos',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-NAXOS-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 33: DRF-NAXOS-0500 | Naxos | chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Naxos',
    'chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-NAXOS-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 34: DRF-PARGA-0100 | Parga | cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Parga',
    'cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-PARGA-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 35: DRF-PARGA-0200 | Parga | slate
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Parga',
    'slate',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-PARGA-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 36: DRF-PARGA-0300 | Parga | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Parga',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-PARGA-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 37: DRF-POROS-5100 | Poros | off white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Poros',
    'off white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-POROS-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 38: DRF-POROS-5200 | Poros | silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Poros',
    'silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-POROS-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 39: DRF-POROS-5300 | Poros | anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Poros',
    'anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-POROS-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 40: DRF-POROS-5400 | Poros | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Poros',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-POROS-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 41: DRF-SAMOS-0100 | Samos | natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Samos',
    'natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SAMOS-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 42: DRF-SAMOS-0300 | Samos | anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Samos',
    'anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SAMOS-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 43: DRF-SAMOS-0600 | Samos | light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Samos',
    'light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SAMOS-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 44: DRF-SAMOS-0900 | Samos | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Samos',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SAMOS-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 45: DRF-SKYROS-S-0100 | Skyros | cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Skyros',
    'cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SKYROS-S-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 46: DRF-SKYROS-S-0200 | Skyros | silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Skyros',
    'silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SKYROS-S-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 47: DRF-SKYROS-S-1400 | Skyros | iron
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Skyros',
    'iron',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SKYROS-S-1400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 48: DRF-SKYROS-S-1600 | Skyros | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Skyros',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SKYROS-S-1600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 49: DRF-SKYROS-S-1700 | Skyros | sesame
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Skyros',
    'sesame',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SKYROS-S-1700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 50: DRF-SKYROS-S-2300 | Skyros | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Skyros',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SKYROS-S-2300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 51: DRF-SPETSES-0100 | Spetses | crystal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Spetses',
    'crystal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SPETSES-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 52: DRF-SPETSES-0200 | Spetses | titan
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Spetses',
    'titan',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SPETSES-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 53: DRF-SPETSES-0300 | Spetses | silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Spetses',
    'silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SPETSES-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 54: DRF-SPETSES-0400 | Spetses | platinum
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Spetses',
    'platinum',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SPETSES-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 55: DRF-SPETSES-0500 | Spetses | mushroom
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Spetses',
    'mushroom',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-SPETSES-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 56: DRF-THASOS-0100 | Thasos | sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Thasos',
    'sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-THASOS-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 57: DRF-THASOS-0200 | Thasos | charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Thasos',
    'charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-THASOS-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 58: DRF-THASOS-0300 | Thasos | stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Thasos',
    'stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-THASOS-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 59: DRF-THASOS-0400 | Thasos | bright white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Thasos',
    'bright white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-THASOS-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 60: DRF-ZAKYNTHOS-01-280 | Zakynthos | gardenia
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'gardenia',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-01-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 61: DRF-ZAKYNTHOS-02-280 | Zakynthos | peach
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'peach',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-02-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 62: DRF-ZAKYNTHOS-04-280 | Zakynthos | croissant
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'croissant',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-04-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 63: DRF-ZAKYNTHOS-05-280 | Zakynthos | cappuccino
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'cappuccino',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-05-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 64: DRF-ZAKYNTHOS-07-280 | Zakynthos | metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-07-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 65: DRF-ZAKYNTHOS-08-280 | Zakynthos | steel grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'steel grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-08-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 66: DRF-ZAKYNTHOS-09-280 | Zakynthos | pirate black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'pirate black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-09-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 67: DRF-ZAKYNTHOS-10-280 | Zakynthos | dark shadow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'dark shadow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-10-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 68: DRF-ZAKYNTHOS-11-280 | Zakynthos | cinder
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'cinder',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-11-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 69: DRF-ZAKYNTHOS-12-280 | Zakynthos | blue night
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'blue night',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-12-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 70: DRF-ZAKYNTHOS-20-280 | Zakynthos | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Zakynthos',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'DRF-ZAKYNTHOS-20-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 71: PF-HC45-BLTMR-563-01 | Baltimore | brown
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Baltimore',
    'brown',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-BLTMR-563-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 72: PF-HC45-BLTMR-563-02 | Baltimore | grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Baltimore',
    'grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-BLTMR-563-02' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 73: PF-HC45-BLTMR-563-03 | Baltimore | dark grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Baltimore',
    'dark grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-BLTMR-563-03' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 74: PF-HC45-BLTMR-563-04 | Baltimore | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Baltimore',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-BLTMR-563-04' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 75: PF-HC45-BLTMR-563-05 | Baltimore | ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Baltimore',
    'ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-BLTMR-563-05' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 76: PF-HC45-BLTMR-563-06 | Baltimore | beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Baltimore',
    'beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-BLTMR-563-06' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 77: PF-HC45-DEVON-0300 | Devon | light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Devon',
    'light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DEVON-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 78: PF-HC45-DEVON-0400 | Devon | cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Devon',
    'cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DEVON-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 79: PF-HC45-DEVON-0500 | Devon | oyster
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Devon',
    'oyster',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DEVON-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 80: PF-HC45-DEVON-0600 | Devon | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Devon',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DEVON-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 81: PF-HC45-DEVON-0700 | Devon | brown
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Devon',
    'brown',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DEVON-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 82: PF-HC45-DEVON-0800 | Devon | grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Devon',
    'grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DEVON-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 83: PF-HC45-DMNTN-5600 | Edmonton | dark grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'dark grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 84: PF-HC45-DMNTN-5603 | Edmonton | black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5603' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 85: PF-HC45-DMNTN-5609 | Edmonton | ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5609' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 86: PF-HC45-DMNTN-5610 | Edmonton | beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5610' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 87: PF-HC45-DMNTN-5611 | Edmonton | light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5611' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 88: PF-HC45-DMNTN-5612 | Edmonton | cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5612' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 89: PF-HC45-DMNTN-5613 | Edmonton | oyster
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'oyster',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5613' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 90: PF-HC45-DMNTN-5615 | Edmonton | sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5615' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 91: PF-HC45-DMNTN-5623 | Edmonton | charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5623' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 92: PF-HC45-DMNTN-5629 | Edmonton | mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5629' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 93: PF-HC45-DMNTN-5650 | Edmonton | sky
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'sky',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5650' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 94: PF-HC45-DMNTN-5653 | Edmonton | sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5653' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 95: PF-HC45-DMNTN-5659 | Edmonton | cinder
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'cinder',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5659' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 96: PF-HC45-DMNTN-5660 | Edmonton | storm
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'storm',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5660' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 97: PF-HC45-DMNTN-5661 | Edmonton | cinder
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'cinder',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5661' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 98: PF-HC45-DMNTN-5662 | Edmonton | storm
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'storm',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5662' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 99: PF-HC45-DMNTN-5663 | Edmonton | charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5663' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 100: PF-HC45-DMNTN-5665 | Edmonton | mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5665' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 101: PF-HC45-DMNTN-5673 | Edmonton | sky
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'sky',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5673' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 102: PF-HC45-DMNTN-5679 | Edmonton | lily
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Edmonton',
    'lily',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-DMNTN-5679' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 103: PF-HC45-HALIFAX-0100 | Halifax | ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 104: PF-HC45-HALIFAX-0300 | Halifax | dawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'dawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 105: PF-HC45-HALIFAX-0400 | Halifax | charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 106: PF-HC45-HALIFAX-0500 | Halifax | FR white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 107: PF-HC45-HALIFAX-5100 | Halifax | FR dawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR dawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 108: PF-HC45-HALIFAX-5247 | Halifax | FR mouse
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR mouse',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5247' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 109: PF-HC45-HALIFAX-5249 | Halifax | FR smoke
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR smoke',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5249' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 110: PF-HC45-HALIFAX-5267 | Halifax | FR white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5267' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 111: PF-HC45-HALIFAX-5269 | Halifax | FR dawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR dawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5269' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 112: PF-HC45-HALIFAX-5300 | Halifax | FR mouse
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR mouse',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 113: PF-HC45-HALIFAX-5400 | Halifax | FR smoke
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'FR smoke',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 114: PF-HC45-HALIFAX-5500 | Halifax | snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Halifax',
    'snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HALIFAX-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 115: PF-HC45-HDSN-562-01 | Hudson | beach beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hudson',
    'beach beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HDSN-562-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 116: PF-HC45-HDSN-562-02 | Hudson | moon rock
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hudson',
    'moon rock',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HDSN-562-02' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 117: PF-HC45-HDSN-562-04 | Hudson | stone blue
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hudson',
    'stone blue',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HDSN-562-04' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 118: PF-HC45-HDSN-562-05 | Hudson | pebble
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hudson',
    'pebble',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-HDSN-562-05' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 119: PF-HC45-LBRT-773-01 | Liberty | light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-773-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 120: PF-HC45-LBRT-773-02 | Liberty | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-773-02' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 121: PF-HC45-LBRT-773-03 | Liberty | pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-773-03' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 122: PF-HC45-LBRT-773-04 | Liberty | dawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'dawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-773-04' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 123: PF-HC45-LBRT-776-01 | Liberty | espresso
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'espresso',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-776-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 124: PF-HC45-LBRT-776-02 | Liberty | mouse
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'mouse',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-776-02' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 125: PF-HC45-LBRT-776-03 | Liberty | white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-776-03' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 126: PF-HC45-LBRT-776-04 | Liberty | pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Liberty',
    'pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-LBRT-776-04' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 127: PF-HC45-OXFORD-0100 | Oxford | dawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Oxford',
    'dawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-OXFORD-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 128: PF-HC45-OXFORD-0300 | Oxford | espresso
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Oxford',
    'espresso',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-OXFORD-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 129: PF-HC45-OXFORD-0600 | Oxford | mouse
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Oxford',
    'mouse',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-OXFORD-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 130: PF-HC45-OXFORD-0700 | Oxford | lime
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Oxford',
    'lime',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-OXFORD-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 131: PF-HC45-OXFORD-0900 | Oxford | off-white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Oxford',
    'off-white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-OXFORD-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 132: PF-HC45-OXFORD-1000 | Oxford | shell
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Oxford',
    'shell',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-OXFORD-1000' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 133: PF-HC45-RIOJA0100-36 | Rijoa | dust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'dust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA0100-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 134: PF-HC45-RIOJA0110-36 | Rijoa | bark
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'bark',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA0110-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 135: PF-HC45-RIOJA0150-36 | Rijoa | cement
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'cement',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA0150-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 136: PF-HC45-RIOJA0170-36 | Rijoa | cloud
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'cloud',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA0170-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 137: PF-HC45-RIOJA0180-36 | Rijoa | mint
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'mint',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA0180-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 138: PF-HC45-RIOJA5100-36 | Rijoa | sour lime
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'sour lime',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA5100-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 139: PF-HC45-RIOJA5110-36 | Rijoa | jeans
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'jeans',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA5110-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 140: PF-HC45-RIOJA5150-36 | Rijoa | dark coral
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'dark coral',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA5150-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 141: PF-HC45-RIOJA5170-36 | Rijoa | bark
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'bark',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA5170-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 142: PF-HC45-RIOJA5180-36 | Rijoa | dust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'dust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA5180-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 143: PF-HC45-RIOJA5240-36 | Rijoa | off white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'off white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA5240-36' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 144: PF-HC45-RIOJA-772-01 | Rijoa | cement
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'cement',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 145: PF-HC45-RIOJA-772-02 | Rijoa | cloud
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'cloud',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-02' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 146: PF-HC45-RIOJA-772-04 | Rijoa | mint
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'mint',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-04' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 147: PF-HC45-RIOJA-772-05 | Rijoa | shell
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'shell',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-05' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 148: PF-HC45-RIOJA-772-06 | Rijoa | jeans
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'jeans',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-06' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 149: PF-HC45-RIOJA-772-07 | Rijoa | dark coral
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'dark coral',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-07' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 150: PF-HC45-RIOJA-772-08 | Rijoa | bright white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'bright white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-08' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 151: PF-HC45-RIOJA-772-09 | Rijoa | biscotti
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'biscotti',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-09' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 152: PF-HC45-RIOJA-772-10 | Rijoa | dune
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'dune',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-10' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 153: PF-HC45-RIOJA-772-11 | Rijoa | chestnut
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'chestnut',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-772-11' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 154: PF-HC45-RIOJA-775-01 | Rijoa | White
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'White',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 155: PF-HC45-RIOJA-775-02 | Rijoa | White
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'White',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-02' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 156: PF-HC45-RIOJA-775-05 | Rijoa | White
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'White',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-05' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 157: PF-HC45-RIOJA-775-06 | Rijoa | Champ. Beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'Champ. Beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-06' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 158: PF-HC45-RIOJA-775-07 | Rijoa | Champ. Beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'Champ. Beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-07' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 159: PF-HC45-RIOJA-775-08 | Rijoa | Champ. Beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'Champ. Beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-08' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 160: PF-HC45-RIOJA-775-09 | Rijoa | Fawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'Fawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-09' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 161: PF-HC45-RIOJA-775-10 | Rijoa | Fawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'Fawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-10' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 162: PF-HC45-RIOJA-775-11 | Rijoa | Fawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Rijoa',
    'Fawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'PF-HC45-RIOJA-775-11' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 163: RF-BALI-0100 | Bali | Roller blind fabric Nature SH PAP PES 200cm bright white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bali',
    'Roller blind fabric Nature SH PAP PES 200cm bright white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BALI-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 164: RF-BALI-0300 | Bali | Roller blind fabric Nature SH PAP PES 200cm biscotti
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bali',
    'Roller blind fabric Nature SH PAP PES 200cm biscotti',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BALI-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 165: RF-BALI-0700 | Bali | Roller blind fabric Nature SH PAP PES 200cm dune
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bali',
    'Roller blind fabric Nature SH PAP PES 200cm dune',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BALI-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 166: RF-BALI-0800 | Bali | Roller blind fabric Nature SH PAP PES 200cm chestnut
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bali',
    'Roller blind fabric Nature SH PAP PES 200cm chestnut',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BALI-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 167: RF-BASIC-BO-01-183-N | Basic | Roller blind fabric Plain BO PVC BO 183cm x 3000cm White
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 183cm x 3000cm White',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-01-183-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 168: RF-BASIC-BO-01-244-N | Basic | Roller blind fabric Plain BO PVC BO 244cm x 3000cm White
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 244cm x 3000cm White',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-01-244-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 169: RF-BASIC-BO-01-300 | Basic | Roller blind fabric Plain BO PVC BO 300cm x 2800cm White
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 300cm x 2800cm White',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 170: RF-BASIC-BO-02-183-N | Basic | Roller blind fabric Plain BO PVC BO 183cm x 3000cm Champ. Beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 183cm x 3000cm Champ. Beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-02-183-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 171: RF-BASIC-BO-02-244-N | Basic | Roller blind fabric Plain BO PVC BO 244cm x 3000cm Champ. Beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 244cm x 3000cm Champ. Beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-02-244-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 172: RF-BASIC-BO-02-300 | Basic | Roller blind fabric Plain BO PVC BO 300cm x 2800cm Champ. Beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 300cm x 2800cm Champ. Beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 173: RF-BASIC-BO-03-183-N | Basic | Roller blind fabric Plain BO PVC BO 183cm x 3000cm Fawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 183cm x 3000cm Fawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-03-183-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 174: RF-BASIC-BO-03-244-N | Basic | Roller blind fabric Plain BO PVC BO 244cm x 3000cm Fawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 244cm x 3000cm Fawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-03-244-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 175: RF-BASIC-BO-03-300 | Basic | Roller blind fabric Plain BO PVC BO 300cm x 2800cm Fawn
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 300cm x 2800cm Fawn',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 176: RF-BASIC-BO-04-183-N | Basic | Roller blind fabric Plain BO PVC BO 183cm x 3000cm Grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 183cm x 3000cm Grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-04-183-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 177: RF-BASIC-BO-04-244-N | Basic | Roller blind fabric Plain BO PVC BO 244cm x 3000cm Grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 244cm x 3000cm Grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-04-244-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 178: RF-BASIC-BO-04-300 | Basic | Roller blind fabric Plain BO PVC BO 300cm x 2800cm Grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 300cm x 2800cm Grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-04-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 179: RF-BASIC-BO-05-183-N | Basic | PVC BO 183cm x 3000cm stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'PVC BO 183cm x 3000cm stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-05-183-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 180: RF-BASIC-BO-05-244-N | Basic | Roller blind fabric Plain BO PVC BO 244cm x 3000cm stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 244cm x 3000cm stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-05-244-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 181: RF-BASIC-BO-05-300 | Basic | Roller blind fabric Plain BO PVC BO 300cm x 2800cm Stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 300cm x 2800cm Stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-05-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 182: RF-BASIC-BO-06-183-N | Basic | PVC BO 183cm x 3000cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'PVC BO 183cm x 3000cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-06-183-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 183: RF-BASIC-BO-06-244-N | Basic | PVC BO 244cm x 3000cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'PVC BO 244cm x 3000cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-06-244-N' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 184: RF-BASIC-BO-06-300 | Basic | Roller blind fabric Plain BO PVC BO 300cm x 2800cm Black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Basic',
    'Roller blind fabric Plain BO PVC BO 300cm x 2800cm Black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BASIC-BO-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 185: RF-BEIJING-01-240 | Beijing | Roller blind fabric Nature SH PAP PES 240cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Beijing',
    'Roller blind fabric Nature SH PAP PES 240cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BEIJING-01-240' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 186: RF-BERLIN-0100-250 | Berlin | Roller blind fabric Plain LF PES 250cm blanc
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm blanc',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0100-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 187: RF-BERLIN-0120-250 | Berlin | Roller blind fabric Plain LF PES 250cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0120-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 188: RF-BERLIN-0220-250 | Berlin | Roller blind fabric Plain LF PES 250cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0220-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 189: RF-BERLIN-0300-250 | Berlin | Roller blind fabric Plain LF PES 250cm vanilla
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm vanilla',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0300-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 190: RF-BERLIN-0500-250 | Berlin | Roller blind fabric Plain LF PES 250cm peach
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm peach',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0500-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 191: RF-BERLIN-0540-250 | Berlin | Roller blind fabric Plain LF PES 250cm twill
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm twill',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0540-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 192: RF-BERLIN-0600-250 | Berlin | Roller blind fabric Plain LF PES 250cm metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0600-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 193: RF-BERLIN-0610-250 | Berlin | Roller blind fabric Plain LF PES 250cm limestone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm limestone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0610-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 194: RF-BERLIN-0800-250 | Berlin | Roller blind fabric plain TR PES 250cm mimosa
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain TR PES 250cm mimosa',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-0800-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 195: RF-BERLIN-1000-250 | Berlin | Roller blind fabric Plain LF PES 250cm blue night
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm blue night',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-1000-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 196: RF-BERLIN-1200-250 | Berlin | Roller blind fabric Plain LF PES 250cm rust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm rust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-1200-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 197: RF-BERLIN-1300-250 | Berlin | Roller blind fabric Plain LF PES 250cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-1300-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 198: RF-BERLIN-1320-250 | Berlin | Roller blind fabric Plain LF PES 250cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric Plain LF PES 250cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-1320-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 199: RF-BERLIN-5100-250 | Berlin | Roller blind fabric plain BO PES 250cm blanc
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm blanc',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5100-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 200: RF-BERLIN-5120-250 | Berlin | Roller blind fabric plain BO PES 250cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5120-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 201: RF-BERLIN-5220-250 | Berlin | Roller blind fabric plain BO PES 250cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5220-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 202: RF-BERLIN-5300-250 | Berlin | Roller blind fabric plain BO PES 250cm vanilla
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm vanilla',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5300-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 203: RF-BERLIN-5500-250 | Berlin | Roller blind fabric plain BO PES 250cm peach
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm peach',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5500-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 204: RF-BERLIN-5540-250 | Berlin | Roller blind fabric plain BO PES 250cm twill
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm twill',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5540-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 205: RF-BERLIN-5600-250 | Berlin | Roller blind fabric plain BO PES 250cm metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5600-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 206: RF-BERLIN-5610-250 | Berlin | Roller blind fabric plain BO PES 250cm limestone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm limestone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5610-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 207: RF-BERLIN-5800-250 | Berlin | Roller blind fabric plain BO PES 250cm mimosa
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm mimosa',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5800-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 208: RF-BERLIN-5900-250 | Berlin | Roller blind fabric plain BO PES 250cm riviera
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm riviera',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-5900-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 209: RF-BERLIN-6000-250 | Berlin | Roller blind fabric plain BO PES 250cm blue night
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm blue night',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-6000-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 210: RF-BERLIN-6300-250 | Berlin | Roller blind fabric plain BO PES 250cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-6300-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 211: RF-BERLIN-6320-250 | Berlin | Roller blind fabric plain BO PES 250cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Berlin',
    'Roller blind fabric plain BO PES 250cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BERLIN-6320-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 212: RF-BOMBAY-0100 | Bombay | Roller blind fabric Nature SH 240cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bombay',
    'Roller blind fabric Nature SH 240cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BOMBAY-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 213: RF-BOMBAY-0300 | Bombay | Roller blind fabric Nature SH 240cm natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bombay',
    'Roller blind fabric Nature SH 240cm natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BOMBAY-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 214: RF-BOMBAY-0400 | Bombay | Roller blind fabric Nature SH 240cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bombay',
    'Roller blind fabric Nature SH 240cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BOMBAY-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 215: RF-BOMBAY-0600 | Bombay | Roller blind fabric Nature SH 240cm bean
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bombay',
    'Roller blind fabric Nature SH 240cm bean',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BOMBAY-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 216: RF-BOMBAY-0700 | Bombay | Roller blind fabric Nature SH 240cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bombay',
    'Roller blind fabric Nature SH 240cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BOMBAY-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 217: RF-BOMBAY-0800 | Bombay | Roller blind fabric Nature SH 240cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Bombay',
    'Roller blind fabric Nature SH 240cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BOMBAY-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 218: RF-BRASILIA-0200 | Brasilia | Roller blind fabric Texture LF PES TREVIRA CS 300cm twill
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Brasilia',
    'Roller blind fabric Texture LF PES TREVIRA CS 300cm twill',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BRASILIA-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 219: RF-BRASILIA-0500 | Brasilia | Roller blind fabric Texture LF PES TREVIRA CS 300cm steel
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Brasilia',
    'Roller blind fabric Texture LF PES TREVIRA CS 300cm steel',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BRASILIA-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 220: RF-BRASILIA-0600 | Brasilia | Roller blind fabric Texture LF PES TREV CS 300cm steeple grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Brasilia',
    'Roller blind fabric Texture LF PES TREV CS 300cm steeple grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BRASILIA-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 221: RF-BRASILIA-0800 | Brasilia | Roller blind fabric Texture LF PES TREVIRA CS 300cm raven
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Brasilia',
    'Roller blind fabric Texture LF PES TREVIRA CS 300cm raven',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BRASILIA-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 222: RF-COMO-5100 | Como | Roller blind fabric Texture BO PES FR 280cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Como',
    'Roller blind fabric Texture BO PES FR 280cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-COMO-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 223: RF-COMO-5300 | Como | Roller blind fabric Texture BO PES FR 280cm shell
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Como',
    'Roller blind fabric Texture BO PES FR 280cm shell',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-COMO-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 224: RF-COMO-5500 | Como | Roller blind fabric Texture BO PES FR 280cm sesame
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Como',
    'Roller blind fabric Texture BO PES FR 280cm sesame',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-COMO-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 225: RF-COMO-5600 | Como | Roller blind fabric Texture BO PES FR 280cm chanterelle
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Como',
    'Roller blind fabric Texture BO PES FR 280cm chanterelle',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-COMO-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 226: RF-COMO-5700 | Como | Roller blind fabric Texture BO PES FR 280cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Como',
    'Roller blind fabric Texture BO PES FR 280cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-COMO-5700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 227: RF-COMO-5800 | Como | Roller blind fabric Texture BO PES FR 280cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Como',
    'Roller blind fabric Texture BO PES FR 280cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-COMO-5800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 228: RF-DARWIN-5100 | Darwin | Roller blind fabric Texture BO PES  280cm cloud
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Darwin',
    'Roller blind fabric Texture BO PES  280cm cloud',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DARWIN-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 229: RF-DARWIN-5200 | Darwin | Roller blind fabric Texture BO PES  280cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Darwin',
    'Roller blind fabric Texture BO PES  280cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DARWIN-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 230: RF-DARWIN-5300 | Darwin | Roller blind fabric Texture BO PES  280cm taupe
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Darwin',
    'Roller blind fabric Texture BO PES  280cm taupe',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DARWIN-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 231: RF-DARWIN-5400 | Darwin | Roller blind fabric Texture BO PES  280cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Darwin',
    'Roller blind fabric Texture BO PES  280cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DARWIN-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 232: RF-DARWIN-5500 | Darwin | Roller blind fabric Texture BO PES  280cm indigo
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Darwin',
    'Roller blind fabric Texture BO PES  280cm indigo',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DARWIN-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 233: RF-DARWIN-5600 | Darwin | Roller blind fabric Texture BO PES  280cm aubergine
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Darwin',
    'Roller blind fabric Texture BO PES  280cm aubergine',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DARWIN-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 234: RF-DURBAN-0100 | Durban | Roller blind fabric Texture LF  PES 280 cm grain
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Durban',
    'Roller blind fabric Texture LF  PES 280 cm grain',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DURBAN-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 235: RF-DURBAN-0200 | Durban | Roller blind fabric Texture LF  PES 280 cm  bark
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Durban',
    'Roller blind fabric Texture LF  PES 280 cm  bark',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DURBAN-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 236: RF-DURBAN-0300 | Durban | Roller blind fabric Texture LF  PES 280 cm charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Durban',
    'Roller blind fabric Texture LF  PES 280 cm charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DURBAN-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 237: RF-DURBAN-0400 | Durban | Roller blind fabric Texture LF  PES 280 cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Durban',
    'Roller blind fabric Texture LF  PES 280 cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-DURBAN-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 238: RF-EKO50-0100 | Eko | Roller blind fabric Texture LF PES 210cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 239: RF-EKO50-0400 | Eko | Roller blind fabric Texture LF PES 210cm pearled ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm pearled ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 240: RF-EKO50-0700 | Eko | Roller blind fabric Texture LF PES 210cm pale khaki
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm pale khaki',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 241: RF-EKO50-1900 | Eko | Roller blind fabric Texture LF PES 210cm inda ink
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm inda ink',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-1900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 242: RF-EKO50-2000 | Eko | Roller blind fabric Texture LF PES 210cm silver cloud
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm silver cloud',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-2000' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 243: RF-EKO50-2100 | Eko | Roller blind fabric Texture LF PES 210cm atmosphere
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm atmosphere',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-2100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 244: RF-EKO50-2200 | Eko | Roller blind fabric Texture LF PES 210cm cinder
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm cinder',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-2200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 245: RF-EKO50-2300 | Eko | Roller blind fabric Texture LF PES 210cm caviar
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm caviar',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-2300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 246: RF-EKO50-2400 | Eko | Roller blind fabric Texture LF PES 210cm limestone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Eko',
    'Roller blind fabric Texture LF PES 210cm limestone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-EKO50-2400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 247: RF-ESVEDRA-0100-280 | Esvedra | Roller blind fabric Plain SH PES 280cm blanc
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm blanc',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-0100-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 248: RF-ESVEDRA-0200-280 | Esvedra | Roller blind fabric Plain SH PES 280cm vanilla
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm vanilla',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-0200-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 249: RF-ESVEDRA-3000-280 | Esvedra | Roller blind fabric Plain SH PES 280cm metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-3000-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 250: RF-ESVEDRA-3200-280 | Esvedra | Roller blind fabric Plain SH PES 280cm cinder
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm cinder',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-3200-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 251: RF-ESVEDRA-3300-280 | Esvedra | Roller blind fabric Plain SH PES 280cm dark shadow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm dark shadow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-3300-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 252: RF-ESVEDRA-3400-280 | Esvedra | Roller blind fabric Plain SH PES 280cm castle rock
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm castle rock',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-3400-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 253: RF-ESVEDRA-3500-280 | Esvedra | Roller blind fabric Plain SH PES 280cm feather
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm feather',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-3500-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 254: RF-ESVEDRA-3600-280 | Esvedra | Roller blind fabric Plain SH PES 280cm mushroom
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Esvedra',
    'Roller blind fabric Plain SH PES 280cm mushroom',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-ESVEDRA-3600-280' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 255: RF-GUNSANG-0100 | Gunsang | Roller blind fabric Nature SH PAP PES 200cm pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Gunsang',
    'Roller blind fabric Nature SH PAP PES 200cm pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-GUNSANG-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 256: RF-GUNSANGSPNGL-0100 | Gunsang | Roller blind fabric Nature SH PAP PES 200cm pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Gunsang',
    'Roller blind fabric Nature SH PAP PES 200cm pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-GUNSANGSPNGL-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 257: RF-HAMPTON-0100 | Hampton | Roller blind fabric Texture SH PES 280 cm light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture SH PES 280 cm light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 258: RF-HAMPTON-0150 | Hampton | Roller blind fabric Texture SH PES 280 cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture SH PES 280 cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-0150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 259: RF-HAMPTON-0200 | Hampton | Roller blind fabric Texture SH PES 280 cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture SH PES 280 cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 260: RF-HAMPTON-0300 | Hampton | Roller blind fabric Texture SH PES 280 cm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture SH PES 280 cm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 261: RF-HAMPTON-0400 | Hampton | Roller blind fabric Texture SH PES 280 cm antra
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture SH PES 280 cm antra',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 262: RF-HAMPTON-0500 | Hampton | Roller blind fabric Texture SH PES 280 cm off white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture SH PES 280 cm off white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 263: RF-HAMPTON-5100 | Hampton | Roller blind fabric Texture BO  PES 280 cm light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture BO  PES 280 cm light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 264: RF-HAMPTON-5150 | Hampton | Roller blind fabric Texture BO  PES 280 cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture BO  PES 280 cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-5150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 265: RF-HAMPTON-5200 | Hampton | Roller blind fabric Texture BO  PES 280 cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture BO  PES 280 cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 266: RF-HAMPTON-5300 | Hampton | Roller blind fabric Texture BO  PES 280 cm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture BO  PES 280 cm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 267: RF-HAMPTON-5400 | Hampton | Roller blind fabric Texture BO  PES 280 cm antra
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture BO  PES 280 cm antra',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 268: RF-HAMPTON-5500 | Hampton | Roller blind fabric Texture BO  PES 280 cm off white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hampton',
    'Roller blind fabric Texture BO  PES 280 cm off white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HAMPTON-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 269: RF-HONGKONG-01 | Hong Kong | Roller blind fabric Nature LF PAP PES 180cm natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hong Kong',
    'Roller blind fabric Nature LF PAP PES 180cm natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HONGKONG-01' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 270: RF-HUEVA-0100 | Hueva | Roller blind fabric Nature SH 240cm vanilla
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hueva',
    'Roller blind fabric Nature SH 240cm vanilla',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HUEVA-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 271: RF-HUEVA-0200 | Hueva | Roller blind fabric Nature SH 240cm straw
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hueva',
    'Roller blind fabric Nature SH 240cm straw',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HUEVA-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 272: RF-HUEVA-0300 | Hueva | Roller blind fabric Nature SH 240cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hueva',
    'Roller blind fabric Nature SH 240cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HUEVA-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 273: RF-HUEVA-0400 | Hueva | Roller blind fabric Nature SH 240cm metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hueva',
    'Roller blind fabric Nature SH 240cm metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HUEVA-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 274: RF-HUEVA-0500 | Hueva | Roller blind fabric Nature SH 240cm ink
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Hueva',
    'Roller blind fabric Nature SH 240cm ink',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-HUEVA-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 275: RF-JA21001-001 | Jacquard� | Roller blind fabric jacquard SH PES 280cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jacquard�',
    'Roller blind fabric jacquard SH PES 280cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA21001-001' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 276: RF-JA21001-002 | Jacquard� | Roller blind fabric jacquard SH PES 280cm ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jacquard�',
    'Roller blind fabric jacquard SH PES 280cm ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA21001-002' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 277: RF-JA21001-003 | Jacquard� | Roller blind fabric jacquard SH PES 280cm light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jacquard�',
    'Roller blind fabric jacquard SH PES 280cm light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA21001-003' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 278: RF-JA21001-004 | Jacquard� | Roller blind fabric jacquard SH PES 280cm dark grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jacquard�',
    'Roller blind fabric jacquard SH PES 280cm dark grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA21001-004' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 279: RF-JA-ARETHA-0100 | Aretha | Roller blind fabric Jacquard LF PES 240cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Aretha',
    'Roller blind fabric Jacquard LF PES 240cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA-ARETHA-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 280: RF-JA-ARETHA-0200 | Aretha | Roller blind fabric Jacquard LF PES 240cm off-white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Aretha',
    'Roller blind fabric Jacquard LF PES 240cm off-white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA-ARETHA-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 281: RF-JA-ARETHA-0300 | Aretha | Roller blind fabric Jacquard LF PES 240cm cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Aretha',
    'Roller blind fabric Jacquard LF PES 240cm cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA-ARETHA-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 282: RF-JA-ARETHA-0500 | Aretha | Roller blind fabric Jacquard LF PES 240cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Aretha',
    'Roller blind fabric Jacquard LF PES 240cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA-ARETHA-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 283: RF-JA-ARETHA-0800 | Aretha | Roller blind fabric Jacquard LF PES 240cm dark grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Aretha',
    'Roller blind fabric Jacquard LF PES 240cm dark grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JA-ARETHA-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 284: RF-JINJU-0100 | Jinju | Roller blind fabric Nature LF PAP JUT 200cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jinju',
    'Roller blind fabric Nature LF PAP JUT 200cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JINJU-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 285: RF-JINJU-0200 | Jinju | Roller blind fabric Nature LF PAP JUT 200cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jinju',
    'Roller blind fabric Nature LF PAP JUT 200cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JINJU-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 286: RF-JINJU-0300 | Jinju | Roller blind fabric Nature LF PAP JUT 200cm sun
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Jinju',
    'Roller blind fabric Nature LF PAP JUT 200cm sun',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-JINJU-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 287: RF-LIN2 | Lf Jtu Pes | Roller blind fabric Nature LF JUT PES 180cm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lf Jtu Pes',
    'Roller blind fabric Nature LF JUT PES 180cm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LIN2' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 288: RF-LIN3 | Lf Jtu Pes | Roller blind fabric Nature LF JUT PES 180cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lf Jtu Pes',
    'Roller blind fabric Nature LF JUT PES 180cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LIN3' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 289: RF-LISBOA-5100 | Lisboa | Roller blind fabric Texture BO PES 280cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lisboa',
    'Roller blind fabric Texture BO PES 280cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LISBOA-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 290: RF-LISBOA-5400 | Lisboa | Roller blind fabric Texture BO PES 280cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lisboa',
    'Roller blind fabric Texture BO PES 280cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LISBOA-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 291: RF-LISBOA-5500 | Lisboa | Roller blind fabric Texture BO PES 280cm dust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lisboa',
    'Roller blind fabric Texture BO PES 280cm dust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LISBOA-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 292: RF-LISBOA-5600 | Lisboa | Roller blind fabric Texture BO PES 280cm buffalo
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lisboa',
    'Roller blind fabric Texture BO PES 280cm buffalo',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LISBOA-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 293: RF-LISBOA-5700 | Lisboa | Roller blind fabric Texture BO PES 280cm cacoa
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lisboa',
    'Roller blind fabric Texture BO PES 280cm cacoa',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-LISBOA-5700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 294: RF-MELBOURNE-0100 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 295: RF-MELBOURNE-0300 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 296: RF-MELBOURNE-0400 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm mocca
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm mocca',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 297: RF-MELBOURNE-0500 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 298: RF-MELBOURNE-0600 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm ash
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm ash',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 299: RF-MELBOURNE-0700 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 300: RF-MELBOURNE-0800 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm grain
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm grain',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 301: RF-MELBOURNE-0900 | Melbourne | Roller blind fabric Texture SH Trevira CS 300 cm jeans
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Melbourne',
    'Roller blind fabric Texture SH Trevira CS 300 cm jeans',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MELBOURNE-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 302: RF-MEXICO-5102 | Mexico | Roller blind fabric Texture BO PES FR 280cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mexico',
    'Roller blind fabric Texture BO PES FR 280cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MEXICO-5102' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 303: RF-MEXICO-5105 | Mexico | Roller blind fabric Texture BO PES FR 280cm coffee
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mexico',
    'Roller blind fabric Texture BO PES FR 280cm coffee',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MEXICO-5105' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 304: RF-MEXICO-5106 | Mexico | Roller blind fabric Texture BO PES FR 280cm ash
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mexico',
    'Roller blind fabric Texture BO PES FR 280cm ash',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MEXICO-5106' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 305: RF-MEXICO-5107 | Mexico | Roller blind fabric Texture BO PES FR 280cm slate
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mexico',
    'Roller blind fabric Texture BO PES FR 280cm slate',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MEXICO-5107' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 306: RF-MIAMI-5100 | Miami | Roller blind fabric Texture BO PES FR 280cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 307: RF-MIAMI-5200 | Miami | Roller blind fabric Texture BO PES FR 280cm pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 308: RF-MIAMI-5300 | Miami | Roller blind fabric Texture BO PES FR 280cm cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 309: RF-MIAMI-5500 | Miami | Roller blind fabric Texture BO PES FR 280cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 310: RF-MIAMI-6000 | Miami | Roller blind fabric Texture BO PES FR 280cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-6000' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 311: RF-MIAMI-6100 | Miami | Roller blind fabric Texture BO PES FR 280cm steel grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm steel grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-6100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 312: RF-MIAMI-6200 | Miami | Roller blind fabric Texture BO PES FR 280cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Miami',
    'Roller blind fabric Texture BO PES FR 280cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MIAMI-6200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 313: RF-MOMBASSA-0100 | Mombassa | Roller blind fabric Texture LF PES 300cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 314: RF-MOMBASSA-0150 | Mombassa | Roller blind fabric Texture LF PES 300cm snow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm snow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 315: RF-MOMBASSA-0200 | Mombassa | Roller blind fabric Texture LF PES 300cm oyster
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm oyster',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 316: RF-MOMBASSA-0300 | Mombassa | Roller blind fabric Texture LF PES 300cm dust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm dust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 317: RF-MOMBASSA-0400 | Mombassa | Roller blind fabric Texture LF PES 300cm ink
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm ink',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 318: RF-MOMBASSA-0500 | Mombassa | Roller blind fabric Texture LF PES 300cm ash
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm ash',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 319: RF-MOMBASSA-0600 | Mombassa | Roller blind fabric Texture LF PES 300cm grain
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture LF PES 300cm grain',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 320: RF-MOMBASSA-5100 | Mombassa | Roller blind fabric Texture BO PES 300cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 321: RF-MOMBASSA-5150 | Mombassa | Roller blind fabric Texture BO PES 300cm snow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm snow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 322: RF-MOMBASSA-5200 | Mombassa | Roller blind fabric Texture BO PES 300cm oyster
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm oyster',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 323: RF-MOMBASSA-5300 | Mombassa | Roller blind fabric Texture BO PES 300cm dust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm dust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 324: RF-MOMBASSA-5400 | Mombassa | Roller blind fabric Texture BO PES 300cm ink
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm ink',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 325: RF-MOMBASSA-5500 | Mombassa | Roller blind fabric Texture BO PES 300cm ash
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm ash',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 326: RF-MOMBASSA-5600 | Mombassa | Roller blind fabric Texture BO PES 300cm grain
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Mombassa',
    'Roller blind fabric Texture BO PES 300cm grain',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MOMBASSA-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 327: RF-MUENCHEN-0150 | Muenchen | Roller blind fabric Plain LF PES 200cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-0150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 328: RF-MUENCHEN-0150-300 | Muenchen | Roller blind fabric Plain LF PES 300cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-0150-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 329: RF-MUENCHEN-0301 | Muenchen | Roller blind fabric Plain LF PES 200cm grey anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm grey anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-0301' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 330: RF-MUENCHEN-0301-300 | Muenchen | Roller blind fabric Plain LF PES 300cm grey anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm grey anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-0301-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 331: RF-MUENCHEN-0401 | Muenchen | Roller blind fabric Plain LF PES 200cm bleached sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm bleached sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-0401' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 332: RF-MUENCHEN-0401-300 | Muenchen | Roller blind fabric Plain LF PES 300cm bleached sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm bleached sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-0401-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 333: RF-MUENCHEN-1002 | Muenchen | Roller blind fabric Plain LF PES 200cm lime stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm lime stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-1002' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 334: RF-MUENCHEN-1002-300 | Muenchen | Roller blind fabric Plain LF PES 300cm lime stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm lime stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-1002-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 335: RF-MUENCHEN-2700 | Muenchen | Roller blind fabric Plain LF PES 200cm oyster grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm oyster grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-2700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 336: RF-MUENCHEN-2700-300 | Muenchen | Roller blind fabric Plain LF PES 300cm oyster grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm oyster grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-2700-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 337: RF-MUENCHEN-4301 | Muenchen | Roller blind fabric Plain LF PES 200cm dark shadow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm dark shadow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-4301' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 338: RF-MUENCHEN-4301-300 | Muenchen | Roller blind fabric Plain LF PES 300cm dark shadow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm dark shadow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-4301-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 339: RF-MUENCHEN-4400 | Muenchen | Roller blind fabric Plain LF PES 200cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-4400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 340: RF-MUENCHEN-4400-300 | Muenchen | Roller blind fabric Plain LF PES 300cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-4400-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 341: RF-MUENCHEN-4601 | Muenchen | Roller blind fabric Plain LF PES 200cm clay
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 200cm clay',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-4601' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 342: RF-MUENCHEN-4601-300 | Muenchen | Roller blind fabric Plain LF PES 300cm clay
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric Plain LF PES 300cm clay',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-4601-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 343: RF-MUENCHEN-5001 | Muenchen | Roller blind fabric plain BO PES 200cm lime stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm lime stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-5001' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 344: RF-MUENCHEN-5001-300 | Muenchen | Roller blind fabric plain BO PES 300cm lime stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm lime stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-5001-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 345: RF-MUENCHEN-5300 | Muenchen | Roller blind fabric plain BO PES 200cm grey anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm grey anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 346: RF-MUENCHEN-5300-300 | Muenchen | Roller blind fabric plain BO PES 300cm grey anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm grey anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-5300-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 347: RF-MUENCHEN-5401 | Muenchen | Roller blind fabric plain BO PES 200cm bleached sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm bleached sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-5401' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 348: RF-MUENCHEN-5401-300 | Muenchen | Roller blind fabric plain BO PES 300cm bleached sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm bleached sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-5401-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 349: RF-MUENCHEN-6250 | Muenchen | Roller blind fabric plain BO PES 200cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-6250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 350: RF-MUENCHEN-6250-300 | Muenchen | Roller blind fabric plain BO PES 300cm snow white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm snow white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-6250-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 351: RF-MUENCHEN-6301 | Muenchen | Roller blind fabric plain BO PES 200cm dark shadow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm dark shadow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-6301' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 352: RF-MUENCHEN-6301-300 | Muenchen | Roller blind fabric plain BO PES 300cm dark shadow
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm dark shadow',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-6301-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 353: RF-MUENCHEN-6400 | Muenchen | Roller blind fabric plain BO PES 200cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-6400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 354: RF-MUENCHEN-6400-300 | Muenchen | Roller blind fabric plain BO PES 300cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-6400-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 355: RF-MUENCHEN-7600 | Muenchen | Roller blind fabric plain BO PES 200cm clay
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm clay',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-7600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 356: RF-MUENCHEN-7600-300 | Muenchen | Roller blind fabric plain BO PES 300cm clay
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm clay',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-7600-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 357: RF-MUENCHEN-7700 | Muenchen | Roller blind fabric plain BO PES 200cm oyster grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 200cm oyster grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-7700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 358: RF-MUENCHEN-7700-300 | Muenchen | Roller blind fabric plain BO PES 300cm oyster grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Muenchen',
    'Roller blind fabric plain BO PES 300cm oyster grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-MUENCHEN-7700-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 359: RF-NATAL-0150 | Natal | Roller blind fabric Plain LF PES 250cm bright white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm bright white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 360: RF-NATAL-0200 | Natal | Roller blind fabric Plain LF PES 250cm star white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm star white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 361: RF-NATAL-0400 | Natal | Roller blind fabric Plain LF PES 250cm moonbeam
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm moonbeam',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 362: RF-NATAL-0500 | Natal | Roller blind fabric Plain LF PES 250cm oyster grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm oyster grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 363: RF-NATAL-0600 | Natal | Roller blind fabric Plain LF PES 250cm moon mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm moon mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 364: RF-NATAL-0700 | Natal | Roller blind fabric Plain LF PES 250cm jet set
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm jet set',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 365: RF-NATAL-0900 | Natal | Roller blind fabric Plain LF PES 250cm black coffee
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric Plain LF PES 250cm black coffee',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 366: RF-NATAL-5150 | Natal | Roller blind fabric plain BO PES 250cm bright white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm bright white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5150' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 367: RF-NATAL-5200 | Natal | Roller blind fabric plain BO PES 250cm star white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm star white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 368: RF-NATAL-5400 | Natal | Roller blind fabric plain BO PES 250cm moonbeam
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm moonbeam',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 369: RF-NATAL-5500 | Natal | Roller blind fabric plain BO PES 250cm oyster grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm oyster grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 370: RF-NATAL-5600 | Natal | Roller blind fabric plain BO PES 250cm moon mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm moon mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 371: RF-NATAL-5700 | Natal | Roller blind fabric plain BO PES 250cm jet set
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm jet set',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 372: RF-NATAL-5900 | Natal | Roller blind fabric plain BO PES 250cm black coffee
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Natal',
    'Roller blind fabric plain BO PES 250cm black coffee',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-NATAL-5900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 373: RF-OSAKA-0100-185 | Osaka | Roller blind fabric Nature LF PAP PES 185cm stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Osaka',
    'Roller blind fabric Nature LF PAP PES 185cm stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-OSAKA-0100-185' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 374: RF-OSAKA-0300-185 | Osaka | Roller blind fabric Nature LF PAP PES 185cm latte
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Osaka',
    'Roller blind fabric Nature LF PAP PES 185cm latte',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-OSAKA-0300-185' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 375: RF-OSAKA-0400-185 | Osaka | Roller blind fabric Nature LF PAP PES 185cm mocha
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Osaka',
    'Roller blind fabric Nature LF PAP PES 185cm mocha',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-OSAKA-0400-185' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 376: RF-PAP2-240 | Sh Pap Pes | Roller blind fabric Nature SH PAP PES 240cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Sh Pap Pes',
    'Roller blind fabric Nature SH PAP PES 240cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PAP2-240' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 377: RF-PAP3-240 | Sh Pap Pes | Roller blind fabric Nature SH PAP PES 240cm natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Sh Pap Pes',
    'Roller blind fabric Nature SH PAP PES 240cm natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PAP3-240' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 378: RF-PAP7-240 | Sh Pap Pes | Roller blind fabric Nature SH PAP PES 240cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Sh Pap Pes',
    'Roller blind fabric Nature SH PAP PES 240cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PAP7-240' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 379: RF-PARIS-0100-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm blanc
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm blanc',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-0100-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 380: RF-PARIS-0150-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm gardenia
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm gardenia',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-0150-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 381: RF-PARIS-0400-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm buff
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm buff',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-0400-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 382: RF-PARIS-3300-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm dove
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm dove',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-3300-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 383: RF-PARIS-3400-300 | Paris | Roller blind fabric Plain SH PES TREV. CS 300cm steel grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREV. CS 300cm steel grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-3400-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 384: RF-PARIS-3500-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm caviar
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm caviar',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-3500-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 385: RF-PARIS-3800-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm twill
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm twill',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-3800-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 386: RF-PARIS-4200-300 | Paris | Roller blind fabric Plain SH PES TREVIRA CS 300cm raven
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Paris',
    'Roller blind fabric Plain SH PES TREVIRA CS 300cm raven',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PARIS-4200-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 387: RF-PR180660-0100 | Lf Pes | Roller blind fabric Print LF PES 240 cm  sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lf Pes',
    'Roller blind fabric Print LF PES 240 cm  sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PR180660-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 388: RF-PR180660-0200 | Lf Pes | Roller blind fabric Print LF PES 240 cm  taupe
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lf Pes',
    'Roller blind fabric Print LF PES 240 cm  taupe',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PR180660-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 389: RF-PR180660-0300 | Lf Pes | Roller blind fabric Print LF PES 240 cm moth
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Lf Pes',
    'Roller blind fabric Print LF PES 240 cm moth',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-PR180660-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 390: RF-RICHMOND-0100 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 391: RF-RICHMOND-0200 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 392: RF-RICHMOND-0300 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 393: RF-RICHMOND-0500 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 394: RF-RICHMOND-0700 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm bison
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm bison',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 395: RF-RICHMOND-0900 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm castle rock
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm castle rock',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 396: RF-RICHMOND-1000 | Richmond | Roller blind fabric Texture SH PES TREV CS 300cm frost
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Richmond',
    'Roller blind fabric Texture SH PES TREV CS 300cm frost',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-RICHMOND-1000' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 397: RF-SAIGON-0100 | Saigon | Roller blind fabric Nature SH PAP PES 240cm natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Saigon',
    'Roller blind fabric Nature SH PAP PES 240cm natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SAIGON-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 398: RF-SAIGON-0200 | Saigon | Roller blind fabric Nature SH PAP PES 240cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Saigon',
    'Roller blind fabric Nature SH PAP PES 240cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SAIGON-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 399: RF-SAIGON-0300 | Saigon | Roller blind fabric Nature SH PAP PES 240cm dark brown
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Saigon',
    'Roller blind fabric Nature SH PAP PES 240cm dark brown',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SAIGON-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 400: RF-SAIGON-0500 | Saigon | Roller blind fabric Nature SH PAP PES 240cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Saigon',
    'Roller blind fabric Nature SH PAP PES 240cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SAIGON-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 401: RF-SALVADOR-0100 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm optical white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm optical white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 402: RF-SALVADOR-0200 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 403: RF-SALVADOR-0300 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 404: RF-SALVADOR-0500 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 405: RF-SALVADOR-0700 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm stone
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm stone',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 406: RF-SALVADOR-0800 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm slate
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm slate',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-0800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 407: RF-SALVADOR-1100 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-1100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 408: RF-SALVADOR-1300 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm dark grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm dark grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-1300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 409: RF-SALVADOR-1400 | Salvador | Roller blind fabric Plain SH TREVIRA CS 240cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Salvador',
    'Roller blind fabric Plain SH TREVIRA CS 240cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SALVADOR-1400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 410: RF-SANTIAGO-5100 | Santiago | Roller blind fabric plain BO PES FR 280cm bright white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm bright white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 411: RF-SANTIAGO-5200 | Santiago | Roller blind fabric plain BO PES FR 280cm blanc
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm blanc',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 412: RF-SANTIAGO-5300 | Santiago | Roller blind fabric plain BO PES FR 280cm gardenia
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm gardenia',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 413: RF-SANTIAGO-5400 | Santiago | Roller blind fabric plain BO PES FR 280cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 414: RF-SANTIAGO-5600 | Santiago | Roller blind fabric plain BO PES FR 280cm chocolate
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm chocolate',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 415: RF-SANTIAGO-5700 | Santiago | Roller blind fabric plain BO PES FR 280cm raven
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm raven',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 416: RF-SANTIAGO-5800 | Santiago | Roller blind fabric plain BO PES FR 280cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-5800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 417: RF-SANTIAGO-6000 | Santiago | Roller blind fabric plain BO PES FR 280cm metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Santiago',
    'Roller blind fabric plain BO PES FR 280cm metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-SANTIAGO-6000' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 418: RF-TOKIO-0100 | Tokio | Roller blind fabric Nature LF PAP PES 200cm natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Tokio',
    'Roller blind fabric Nature LF PAP PES 200cm natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-TOKIO-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 419: RF-TOKIO-0200 | Tokio | Roller blind fabric Nature LF PAP PES 200cm oak
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Tokio',
    'Roller blind fabric Nature LF PAP PES 200cm oak',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-TOKIO-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 420: RF-TOKIO-0300 | Tokio | Roller blind fabric Nature LF PAP PES 200cm teak
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Tokio',
    'Roller blind fabric Nature LF PAP PES 200cm teak',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-TOKIO-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 421: RF-TOKIO-0400 | Tokio | Roller blind fabric Nature LF PAP PES 200cm palisander
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Tokio',
    'Roller blind fabric Nature LF PAP PES 200cm palisander',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-TOKIO-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 422: RF-TOULOUSE-0100 | Toulouse | Roller blind fabric Texture LF PES 280cm flour
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Toulouse',
    'Roller blind fabric Texture LF PES 280cm flour',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-TOULOUSE-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 423: RF-TOULOUSE-5100 | Toulouse | Roller blind fabric Texture BO PES 280 cm flour
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Toulouse',
    'Roller blind fabric Texture BO PES 280 cm flour',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-TOULOUSE-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 424: RF-UBUD-0100 | Ubud | Roller blind fabric Nature SH 240cm natural
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm natural',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 425: RF-UBUD-0200 | Ubud | Roller blind fabric Nature SH 240cm fossil
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm fossil',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 426: RF-UBUD-0300 | Ubud | Roller blind fabric Nature SH 240cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 427: RF-UBUD-0400 | Ubud | Roller blind fabric Nature SH 240cm bean
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm bean',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 428: RF-UBUD-0500 | Ubud | Roller blind fabric Nature SH 240cm wood
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm wood',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 429: RF-UBUD-0600 | Ubud | Roller blind fabric Nature SH 240cm smoke
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm smoke',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 430: RF-UBUD-0700 | Ubud | Roller blind fabric Nature SH 240cm charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 431: RF-UBUD-1200 | Ubud | Roller blind fabric Nature SH 240cm teak
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ubud',
    'Roller blind fabric Nature SH 240cm teak',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-UBUD-1200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 432: RF-WELLINGTON-5100 | Wellington | Roller blind fabric plain BO PES 300cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Wellington',
    'Roller blind fabric plain BO PES 300cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WELLINGTON-5100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 433: RF-WELLINGTON-5400 | Wellington | Roller blind fabric plain BO PES 300cm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Wellington',
    'Roller blind fabric plain BO PES 300cm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WELLINGTON-5400' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 434: RF-WELLINGTON-5500 | Wellington | Roller blind fabric plain BO PES 300cm taupe
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Wellington',
    'Roller blind fabric plain BO PES 300cm taupe',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WELLINGTON-5500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 435: RF-WELLINGTON-5600 | Wellington | Roller blind fabric plain BO PES 300cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Wellington',
    'Roller blind fabric plain BO PES 300cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WELLINGTON-5600' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 436: RF-WELLINGTON-5700 | Wellington | Roller blind fabric plain BO PES 300cm antracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Wellington',
    'Roller blind fabric plain BO PES 300cm antracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WELLINGTON-5700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 437: RF-WELLINGTON-5800 | Wellington | Roller blind fabric plain BO PES 300cm black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Wellington',
    'Roller blind fabric plain BO PES 300cm black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WELLINGTON-5800' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 438: RF-WINCHESTER-0100 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-0100' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 439: RF-WINCHESTER-0200 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-0200' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 440: RF-WINCHESTER-0300 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-0300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 441: RF-WINCHESTER-0500 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-0500' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 442: RF-WINCHESTER-0700 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm bison
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm bison',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-0700' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 443: RF-WINCHESTER-0900 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm castle rock
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm castle rock',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-0900' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 444: RF-WINCHESTER-1000 | Winchester | Roller blind fabric Texture SH PES TREV CS 300cm frost
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Winchester',
    'Roller blind fabric Texture SH PES TREV CS 300cm frost',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-WINCHESTER-1000' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 445: SCA5-LINEN-01-250 | Screen linen | Screen linen 5% 250cmx2740cm shifting sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen linen',
    'Screen linen 5% 250cmx2740cm shifting sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCA5-LINEN-01-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 446: SCA5-LINEN-02-250 | Screen linen | Screen linen 5% 250cmx2740cm feather grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen linen',
    'Screen linen 5% 250cmx2740cm feather grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCA5-LINEN-02-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 447: SCA5-LINEN-03-250 | Screen linen | Screen linen 5% 250cmx2740cm moon mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen linen',
    'Screen linen 5% 250cmx2740cm moon mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCA5-LINEN-03-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 448: SCA5-LINEN-04-250 | Screen linen | Screen linen 5% 250cmx2740cm frost
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen linen',
    'Screen linen 5% 250cmx2740cm frost',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCA5-LINEN-04-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 449: SCA5-LINEN-05-250 | Screen linen | Screen linen 5% 250cmx2740cm raven
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen linen',
    'Screen linen 5% 250cmx2740cm raven',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCA5-LINEN-05-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 450: SCR-3001-01-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-01-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 451: SCR-3001-01-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 452: SCR-3001-02-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-02-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 453: SCR-3001-02-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 454: SCR-3001-03-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-03-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 455: SCR-3001-03-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 456: SCR-3001-05-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-05-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 457: SCR-3001-05-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-05-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 458: SCR-3001-06-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-06-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 459: SCR-3001-06-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 460: SCR-3001-08-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-08-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 461: SCR-3001-08-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-08-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 462: SCR-3001-10-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-10-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 463: SCR-3001-10-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-10-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 464: SCR-3001-11-250 | Screen 3001 | Screen 3001 1% 250cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 250cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-11-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 465: SCR-3001-11-300 | Screen 3001 | Screen 3001 1% 300cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3001',
    'Screen 3001 1% 300cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3001-11-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 466: SCR-3003-01-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-01-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 467: SCR-3003-01-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 468: SCR-3003-02-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-02-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 469: SCR-3003-02-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 470: SCR-3003-03-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-03-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 471: SCR-3003-03-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 472: SCR-3003-05-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-05-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 473: SCR-3003-05-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-05-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 474: SCR-3003-06-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-06-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 475: SCR-3003-06-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 476: SCR-3003-08-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-08-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 477: SCR-3003-08-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-08-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 478: SCR-3003-10-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-10-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 479: SCR-3003-10-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-10-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 480: SCR-3003-11-250 | Screen 3003 | Screen 3003 3% 250cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 250cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-11-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 481: SCR-3003-11-300 | Screen 3003 | Screen 3003 3% 300cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3003',
    'Screen 3003 3% 300cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3003-11-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 482: SCR-3005-01-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-01-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 483: SCR-3005-01-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 484: SCR-3005-02-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-02-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 485: SCR-3005-02-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 486: SCR-3005-03-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-03-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 487: SCR-3005-03-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 488: SCR-3005-05-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-05-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 489: SCR-3005-05-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-05-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 490: SCR-3005-06-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-06-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 491: SCR-3005-06-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 492: SCR-3005-08-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-08-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 493: SCR-3005-08-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-08-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 494: SCR-3005-10-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-10-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 495: SCR-3005-10-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-10-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 496: SCR-3005-11-250 | Screen 3005 | Screen 3005 5% 250cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 250cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-11-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 497: SCR-3005-11-300 | Screen 3005 | Screen 3005 5% 300cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3005',
    'Screen 3005 5% 300cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3005-11-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 498: SCR-3010-01-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-01-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 499: SCR-3010-01-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 500: SCR-3010-02-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-02-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 501: SCR-3010-02-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm chalk beige cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm chalk beige cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 502: SCR-3010-03-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-03-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 503: SCR-3010-03-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 504: SCR-3010-05-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-05-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 505: SCR-3010-05-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-05-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 506: SCR-3010-06-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-06-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 507: SCR-3010-06-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm ebony
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm ebony',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 508: SCR-3010-08-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-08-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 509: SCR-3010-08-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-08-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 510: SCR-3010-10-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-10-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 511: SCR-3010-10-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-10-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 512: SCR-3010-11-250 | Screen 3010 | Screen 3010 10% 250cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 250cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-11-250' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 513: SCR-3010-11-300 | Screen 3010 | Screen 3010 10% 300cmx2740cm beige pearl grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen 3010',
    'Screen 3010 10% 300cmx2740cm beige pearl grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-3010-11-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 514: SCR3-SATINE-01-300 | Satine | Screen Satine 3% 300cmx2740cm Soft Grey / Ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Satine',
    'Screen Satine 3% 300cmx2740cm Soft Grey / Ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR3-SATINE-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 515: SCR3-SATINE-02-300 | Satine | Screen Satine 3% 300cmx2740cm Dark Bronze / Ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Satine',
    'Screen Satine 3% 300cmx2740cm Dark Bronze / Ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR3-SATINE-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 516: SCR3-SATINE-03-300 | Satine | Screen Satine 3% 300cmx2740cm Ebony / Ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Satine',
    'Screen Satine 3% 300cmx2740cm Ebony / Ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR3-SATINE-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 517: SCR5-EXPLORE-20-300 | Explore | Screen Explore 5% 300cmx2740cm pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-20-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 518: SCR5-EXPLORE-21-300 | Explore | Screen Explore 5% 300cmx2740cm gold
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm gold',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-21-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 519: SCR5-EXPLORE-22-300 | Explore | Screen Explore 5% 300cmx2740cm silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-22-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 520: SCR5-EXPLORE-23-300 | Explore | Screen Explore 5% 300cmx2740cm tin
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm tin',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-23-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 521: SCR5-EXPLORE-24-300 | Explore | Screen Explore 5% 300cmx2740cm nickel
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm nickel',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-24-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 522: SCR5-EXPLORE-28-300 | Explore | Screen Explore 5% 300cmx2740cm bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-28-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 523: SCR5-EXPLORE-29-300 | Explore | Screen Explore 5% 300cmx2740cm copper
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm copper',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-29-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 524: SCR5-EXPLORE-30-300 | Explore | Screen Explore 5% 300cmx2740cm steel
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm steel',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-30-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 525: SCR5-EXPLORE-31-300 | Explore | Screen Explore 5% 300cmx2740cm lead
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Explore',
    'Screen Explore 5% 300cmx2740cm lead',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-EXPLORE-31-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 526: SCR5-GLOW-01-300 | Glow | Screen GLOW 5% 300cmx2740cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 527: SCR5-GLOW-02-300 | Glow | Screen GLOW 5% 300cmx2740cm cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 528: SCR5-GLOW-03-300 | Glow | Screen GLOW 5% 300cmx2740cm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 529: SCR5-GLOW-04-300 | Glow | Screen GLOW 5% 300cmx2740cm sand
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm sand',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-04-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 530: SCR5-GLOW-06-300 | Glow | Screen GLOW 5% 300cmx2740cm anthracite
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm anthracite',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 531: SCR5-GLOW-07-300 | Glow | Screen GLOW 5% 300cmx2740cm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-07-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 532: SCR5-GLOW-08-300 | Glow | Screen GLOW 5% 300cmx2740cm light grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Glow',
    'Screen GLOW 5% 300cmx2740cm light grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR5-GLOW-08-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 533: SCR-AMAZON-31-300 | Amazon | Screen Amazon 300cmx2740cm mist
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm mist',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-31-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 534: SCR-AMAZON-32-300 | Amazon | Screen Amazon 300cmx2740cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-32-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 535: SCR-AMAZON-33-300 | Amazon | Screen Amazon 300cmx2740cm leaf
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm leaf',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-33-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 536: SCR-AMAZON-34-300 | Amazon | Screen Amazon 300cmx2740cm mocca
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm mocca',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-34-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 537: SCR-AMAZON-36-300 | Amazon | Screen Amazon 300cmx2740cm coffee
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm coffee',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-36-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 538: SCR-AMAZON-37-300 | Amazon | Screen Amazon 300cmx2740cm charcoal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm charcoal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-37-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 539: SCR-AMAZON-38-300 | Amazon | Screen Amazon 300cmx2740cm dust
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Amazon',
    'Screen Amazon 300cmx2740cm dust',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-AMAZON-38-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 540: SCR-NOBLE-20-300 | Noble | Noble Screen 300cmx2000cm pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Noble',
    'Noble Screen 300cmx2000cm pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-NOBLE-20-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 541: SCR-NOBLE-21-300 | Noble | Noble Screen 300cmx2000cm gold
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Noble',
    'Noble Screen 300cmx2000cm gold',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-NOBLE-21-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 542: SCR-NOBLE-22-300 | Noble | Noble Screen 300cmx2000cm silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Noble',
    'Noble Screen 300cmx2000cm silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-NOBLE-22-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 543: SCR-NOBLE-24-300 | Noble | Noble Screen 300cmx2000cm nickel
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Noble',
    'Noble Screen 300cmx2000cm nickel',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-NOBLE-24-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 544: SCR-NOBLE-25-300 | Noble | Noble Screen 300cmx2000cm coal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Noble',
    'Noble Screen 300cmx2000cm coal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-NOBLE-25-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 545: SCR-REFLECTION-01-24 | Reflection | Screen REFLECTION 240cmx3000cm chalk
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Reflection',
    'Screen REFLECTION 240cmx3000cm chalk',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-REFLECTION-01-24' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 546: SCR-REFLECTION-03-24 | Reflection | Screen REFLECTION 240cmx3000cm chalk soft grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Reflection',
    'Screen REFLECTION 240cmx3000cm chalk soft grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-REFLECTION-03-24' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 547: SCR-REFLECTION-05-24 | Reflection | Screen REFLECTION 240cmx3000cm charcoal iron grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Reflection',
    'Screen REFLECTION 240cmx3000cm charcoal iron grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-REFLECTION-05-24' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 548: SCR-REFLECTION-10-24 | Reflection | Screen REFLECTION 240cmx3000cm charcoal dark bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Reflection',
    'Screen REFLECTION 240cmx3000cm charcoal dark bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-REFLECTION-10-24' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 549: SCR-REFLECTION-12-24 | Reflection | Screen REFLECTION 240cmx3000cm white linen
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Reflection',
    'Screen REFLECTION 240cmx3000cm white linen',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-REFLECTION-12-24' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 550: SCR-REFLECTION-13-24 | Reflection | Screen REFLECTION 240cmx3000cm charcoal cream
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Reflection',
    'Screen REFLECTION 240cmx3000cm charcoal cream',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-REFLECTION-13-24' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 551: SCR-RINGS-01-300 | Ring | Screen Rings 300cmx2740cm white
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ring',
    'Screen Rings 300cmx2740cm white',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-RINGS-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 552: SCR-RINGS-03-300 | Ring | Screen Rings 300cmx2740cm silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ring',
    'Screen Rings 300cmx2740cm silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-RINGS-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 553: SCR-RINGS-04-300 | Ring | Screen Rings 300cmx2740cm bronze
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ring',
    'Screen Rings 300cmx2740cm bronze',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-RINGS-04-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 554: SCR-RINGS-05-300 | Ring | Screen Rings 300cmx2740cm iron
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Ring',
    'Screen Rings 300cmx2740cm iron',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-RINGS-05-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 555: SCR-STYLE-01-300 | Style | Screen STYLE 3% 300cmx2740cm ivory
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Style',
    'Screen STYLE 3% 300cmx2740cm ivory',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-STYLE-01-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 556: SCR-STYLE-02-300 | Style | Screen STYLE 3% 300cmx2740cm pearl
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Style',
    'Screen STYLE 3% 300cmx2740cm pearl',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-STYLE-02-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 557: SCR-STYLE-03-300 | Style | Screen STYLE 3% 300cmx2740cm silver
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Style',
    'Screen STYLE 3% 300cmx2740cm silver',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-STYLE-03-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 558: SCR-STYLE-04-300 | Style | Screen STYLE 3% 300cmx2740cm warm beige
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Style',
    'Screen STYLE 3% 300cmx2740cm warm beige',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-STYLE-04-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 559: SCR-STYLE-06-300 | Style | Screen STYLE 3% 300cmx2740cm warm grey
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Style',
    'Screen STYLE 3% 300cmx2740cm warm grey',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-STYLE-06-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 560: SCR-STYLE-08-300 | Style | Screen STYLE 3% 300cmx2740cm nearly black
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Style',
    'Screen STYLE 3% 300cmx2740cm nearly black',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SCR-STYLE-08-300' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 561: SFN-20003-7100-285-M | Screen Natural | Screen Natural 3% Trevira CS 285cm Aluback white metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen Natural',
    'Screen Natural 3% Trevira CS 285cm Aluback white metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SFN-20003-7100-285-M' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 562: SFN-20003-7300-285-M | Screen Natural | Screen Natural 3% Trevira CS 285cm Aluback silver metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen Natural',
    'Screen Natural 3% Trevira CS 285cm Aluback silver metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SFN-20003-7300-285-M' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 563: SFN-20003-7400-285-M | Screen Natural | Screen Natural 3% Trevira CS 285cm Aluback grey metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen Natural',
    'Screen Natural 3% Trevira CS 285cm Aluback grey metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SFN-20003-7400-285-M' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 564: SFN-20003-7500-285-M | Screen Natural | Screen Natural 3% Trevira CS 285cm Aluback anthracite metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen Natural',
    'Screen Natural 3% Trevira CS 285cm Aluback anthracite metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SFN-20003-7500-285-M' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;


-- Insert 565: SFN-20003-7600-285-M | Screen Natural | Screen Natural 3% Trevira CS 285cm Aluback black metal
INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    'Screen Natural',
    'Screen Natural 3% Trevira CS 285cm Aluback black metal',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = 'SFN-20003-7600-285-M' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;



-- ====================================================
-- Verification Query
-- ====================================================

SELECT 
    collection_name,
    COUNT(*) as total_items,
    COUNT(DISTINCT variant_name) as unique_variants
FROM "CollectionsCatalog"
WHERE deleted = false
GROUP BY collection_name
ORDER BY collection_name;
