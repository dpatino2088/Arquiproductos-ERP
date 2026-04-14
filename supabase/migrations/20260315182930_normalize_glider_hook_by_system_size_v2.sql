-- 1) Normalize parent glider condition by SKU
UPDATE "BOMComponents" p
SET condition_key = 'system_size',
    condition_value = CASE
      WHEN ci.sku = 'CC1028-W' THEN '48mm'
      WHEN ci.sku = 'CC1030-W' THEN '60mm'
      ELSE p.condition_value
    END,
    updated_at = now()
FROM "CatalogItems" ci
WHERE p.component_item_id = ci.id
  AND p.deleted = false
  AND p.archived = false
  AND p.component_role = 'glider'
  AND ci.sku IN ('CC1028-W', 'CC1030-W')
  AND (
    (ci.sku = 'CC1028-W' AND COALESCE(p.condition_value, '') <> '48mm')
    OR
    (ci.sku = 'CC1030-W' AND COALESCE(p.condition_value, '') <> '60mm')
  );

-- 2) Insert missing hook child (CC1031-W) for glider parents lacking children
WITH missing_parents AS (
  SELECT p.id AS parent_id,
         p.organization_id,
         p.bom_template_id,
         p.condition_key,
         p.condition_value
  FROM "BOMComponents" p
  JOIN "CatalogItems" pci ON pci.id = p.component_item_id
  WHERE p.deleted = false
    AND p.archived = false
    AND p.component_role = 'glider'
    AND p.condition_key = 'system_size'
    AND p.condition_value IN ('48mm','60mm')
    AND pci.sku IN ('CC1028-W','CC1030-W')
    AND NOT EXISTS (
      SELECT 1 FROM "BOMComponents" ch
      WHERE ch.parent_component_id = p.id
        AND ch.deleted = false
        AND ch.archived = false
    )
), donor_child AS (
  SELECT DISTINCT ON (p.bom_template_id)
         p.bom_template_id,
         ch.component_item_id,
         ch.component_role,
         ch.qty_type,
         ch.qty_value,
         ch.qty_delta_mm,
         ch.uom,
         ch.waste_pct,
         ch.auto_select,
         ch.sku_resolution_rule,
         ch.depends_on_role,
         ch.cut_axis,
         ch.cut_delta_mm,
         ch.sort_order,
         ch.component_mode,
         ch.is_required,
         ch.type_per_unit,
         ch.component_scope,
         ch.slot_id,
         ch.qty_min,
         ch.component_sub_role,
         ch.metadata,
         ch.cut_delta_scope,
         ch.affects_role,
         ch.engineering_delta_source,
         ch.engineering_attr_key,
         ch.engineering_scope,
         ch.engineering_source_role,
         ch.per_panel
  FROM "BOMComponents" p
  JOIN "BOMComponents" ch
    ON ch.parent_component_id = p.id
   AND ch.deleted = false
   AND ch.archived = false
  JOIN "CatalogItems" cci ON cci.id = ch.component_item_id
  WHERE p.deleted = false
    AND p.archived = false
    AND p.component_role = 'glider'
    AND p.condition_key = 'system_size'
    AND p.condition_value IN ('48mm','60mm')
    AND cci.sku = 'CC1031-W'
  ORDER BY p.bom_template_id, ch.sort_order, ch.created_at
)
INSERT INTO "BOMComponents" (
  organization_id,
  bom_template_id,
  parent_component_id,
  component_item_id,
  component_role,
  qty_type,
  qty_value,
  qty_delta_mm,
  uom,
  waste_pct,
  auto_select,
  sku_resolution_rule,
  depends_on_role,
  cut_axis,
  cut_delta_mm,
  sort_order,
  deleted,
  archived,
  created_at,
  updated_at,
  component_mode,
  is_required,
  type_per_unit,
  component_scope,
  slot_id,
  qty_spacing_mm,
  qty_min,
  component_sub_role,
  metadata,
  cut_delta_scope,
  affects_role,
  engineering_delta_source,
  engineering_attr_key,
  engineering_scope,
  engineering_source_role,
  condition_key,
  condition_value,
  per_panel
)
SELECT mp.organization_id,
       mp.bom_template_id,
       mp.parent_id,
       d.component_item_id,
       d.component_role,
       d.qty_type,
       d.qty_value,
       d.qty_delta_mm,
       d.uom,
       d.waste_pct,
       d.auto_select,
       d.sku_resolution_rule,
       d.depends_on_role,
       d.cut_axis,
       d.cut_delta_mm,
       d.sort_order,
       false,
       false,
       now(),
       now(),
       d.component_mode,
       d.is_required,
       d.type_per_unit,
       d.component_scope,
       d.slot_id,
       CASE WHEN mp.condition_value = '48mm' THEN 48 ELSE 60 END,
       d.qty_min,
       d.component_sub_role,
       d.metadata,
       d.cut_delta_scope,
       d.affects_role,
       d.engineering_delta_source,
       d.engineering_attr_key,
       d.engineering_scope,
       d.engineering_source_role,
       mp.condition_key,
       mp.condition_value,
       d.per_panel
FROM missing_parents mp
JOIN donor_child d ON d.bom_template_id = mp.bom_template_id;

-- 3) Force existing CC1031-W children to match parent condition and spacing
UPDATE "BOMComponents" ch
SET qty_spacing_mm = CASE WHEN p.condition_value = '48mm' THEN 48 ELSE 60 END,
    condition_key = p.condition_key,
    condition_value = p.condition_value,
    updated_at = now()
FROM "BOMComponents" p, "CatalogItems" cci
WHERE ch.parent_component_id = p.id
  AND cci.id = ch.component_item_id
  AND ch.deleted = false
  AND ch.archived = false
  AND p.deleted = false
  AND p.archived = false
  AND p.component_role = 'glider'
  AND p.condition_key = 'system_size'
  AND p.condition_value IN ('48mm','60mm')
  AND cci.sku = 'CC1031-W';;
