-- Normalize UOM values to canonical forms across CatalogItems and BOMComponents.
-- unit variants (set, pcs, pair, pack, each, unit) -> ea
-- linear variants (ft, yd, cm) -> m
-- area variants (ft2, yd2) -> m2

-- 1. Fix CatalogItems.unit_of_measure
UPDATE "CatalogItems"
SET unit_of_measure = 'ea'
WHERE lower(trim(unit_of_measure)) IN ('set', 'pcs', 'pair', 'pack', 'each', 'unit')
  AND lower(trim(unit_of_measure)) != 'ea';

UPDATE "CatalogItems"
SET unit_of_measure = 'm'
WHERE lower(trim(unit_of_measure)) IN ('ft', 'yd', 'cm', 'mm')
  AND lower(trim(unit_of_measure)) != 'm';

UPDATE "CatalogItems"
SET unit_of_measure = 'm2'
WHERE lower(trim(unit_of_measure)) IN ('ft2', 'yd2')
  AND lower(trim(unit_of_measure)) != 'm2';

-- 2. Fix BOMComponents.uom
UPDATE "BOMComponents"
SET uom = 'ea'
WHERE lower(trim(uom)) IN ('set', 'pcs', 'pair', 'pack', 'each', 'unit')
  AND lower(trim(uom)) != 'ea';

UPDATE "BOMComponents"
SET uom = 'm'
WHERE lower(trim(uom)) IN ('ft', 'yd', 'cm', 'mm')
  AND lower(trim(uom)) != 'm';

UPDATE "BOMComponents"
SET uom = 'm2'
WHERE lower(trim(uom)) IN ('ft2', 'yd2')
  AND lower(trim(uom)) != 'm2';

-- 3. Sync BOMComponents.uom from their CatalogItem where they differ
UPDATE "BOMComponents" bc
SET uom = CASE
  WHEN ci.measure_basis = 'linear' THEN 'm'
  WHEN ci.measure_basis = 'area' THEN 'm2'
  ELSE 'ea'
END
FROM "CatalogItems" ci
WHERE bc.component_item_id = ci.id
  AND bc.deleted = false
  AND bc.uom != CASE
    WHEN ci.measure_basis = 'linear' THEN 'm'
    WHEN ci.measure_basis = 'area' THEN 'm2'
    ELSE 'ea'
  END;
