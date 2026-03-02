-- ====================================================
-- Migration 86: Import CatalogItems v2 (category leaf)
-- ====================================================
-- Goal:
-- - Import from staging tables (_stg_catalog_items / _stg_catalog_update)
-- - Map categories to CatalogCategories leaf nodes (CatalogItems.category_id)
-- - Preserve base purchasing/pricing fields in CatalogItems
-- - Recompute derived layers (CatalogItemConversions trigger + MSRP function)
-- - Emit actionable integrity counters
-- ====================================================

DO $$
DECLARE
  -- Adjust target org as needed for your environment
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';

  has_stg_items boolean := false;
  has_stg_update boolean := false;

  raw_count integer := 0;
  norm_count integer := 0;
  impacted_count integer := 0;
  missing_category_count integer := 0;
  ambiguous_category_count integer := 0;
  recompute_ok_count integer := 0;
  recompute_fail_count integer := 0;
  _item record;
  _unmapped record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'IMPORT CATALOG v2 (leaf category model)';
  RAISE NOTICE '========================================';

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = '_stg_catalog_items'
  ) INTO has_stg_items;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = '_stg_catalog_update'
  ) INTO has_stg_update;

  IF NOT has_stg_items AND NOT has_stg_update THEN
    RAISE EXCEPTION 'No staging tables found. Expected _stg_catalog_items and/or _stg_catalog_update.';
  END IF;

  CREATE TEMP TABLE _import_v2_raw (
    source_table text NOT NULL,
    source_priority integer NOT NULL,
    row_num bigserial,
    sku text NOT NULL,
    item_name_text text NULL,
    description_text text NULL,
    category_text text NULL,
    subcategory_text text NULL,
    manufacturer_text text NULL,
    measure_basis_text text NULL,
    uom_text text NULL,
    is_roll_text text NULL,
    roll_type_text text NULL,
    collection_name_text text NULL,
    variant_name_text text NULL,
    roll_width_value_text text NULL,
    roll_width_uom_text text NULL,
    roll_width_m_text text NULL,
    roll_length_value_text text NULL,
    roll_length_uom_text text NULL,
    cost_exw_text text NULL,
    purchase_mode_text text NULL,
    stock_basis_text text NULL,
    purchase_uom_text text NULL,
    purchase_unit_text text NULL,
    units_per_purchase_text text NULL,
    is_active_text text NULL
  ) ON COMMIT DROP;

  IF has_stg_items THEN
    INSERT INTO _import_v2_raw (
      source_table, source_priority, sku, item_name_text, description_text,
      category_text, subcategory_text, manufacturer_text, measure_basis_text, uom_text,
      is_roll_text, roll_type_text, collection_name_text, variant_name_text,
      roll_width_value_text, roll_width_uom_text, roll_width_m_text,
      roll_length_value_text, roll_length_uom_text,
      cost_exw_text, purchase_mode_text, stock_basis_text, purchase_uom_text,
      purchase_unit_text, units_per_purchase_text, is_active_text
    )
    SELECT
      '_stg_catalog_items',
      1,
      trim(coalesce(j->>'sku', '')),
      nullif(trim(coalesce(j->>'item_name', j->>'Item_name', j->>'name', '')), ''),
      nullif(trim(coalesce(j->>'item_description', j->>'description', '')), ''),
      nullif(trim(coalesce(j->>'category', '')), ''),
      nullif(trim(coalesce(j->>'subcategory', j->>'sub_category', j->>'subcategoria', '')), ''),
      nullif(trim(coalesce(j->>'manufacturer', '')), ''),
      nullif(trim(coalesce(j->>'measure_basis', '')), ''),
      nullif(trim(coalesce(j->>'unit_of_measure', j->>'uom', '')), ''),
      nullif(trim(coalesce(j->>'is_roll', j->>'is_fabric', '')), ''),
      nullif(trim(coalesce(j->>'roll_type', '')), ''),
      nullif(trim(coalesce(j->>'collection_name', j->>'Collection', j->>'collection', '')), ''),
      nullif(trim(coalesce(j->>'variant_name', j->>'Variant', j->>'variant', '')), ''),
      nullif(trim(coalesce(j->>'roll_width_value', j->>'roll_width', '')), ''),
      nullif(trim(coalesce(j->>'roll_width_uom', '')), ''),
      nullif(trim(coalesce(j->>'roll_width_m', j->>'roll_widt', '')), ''),
      nullif(trim(coalesce(j->>'roll_length_value', '')), ''),
      nullif(trim(coalesce(j->>'roll_length_uom', '')), ''),
      nullif(trim(coalesce(j->>'cost_exw', j->>'cost_price_exw', j->>'fabric_prici', '')), ''),
      nullif(trim(coalesce(j->>'purchase_mode', '')), ''),
      nullif(trim(coalesce(j->>'stock_basis', '')), ''),
      nullif(trim(coalesce(j->>'purchase_uom', '')), ''),
      nullif(trim(coalesce(j->>'purchase_unit', '')), ''),
      nullif(trim(coalesce(j->>'units_per_purchase_unit', '')), ''),
      nullif(trim(coalesce(j->>'is_active', j->>'active', '')), '')
    FROM public."_stg_catalog_items" s
    CROSS JOIN LATERAL to_jsonb(s) j
    WHERE trim(coalesce(j->>'sku', '')) <> '';
  END IF;

  IF has_stg_update THEN
    INSERT INTO _import_v2_raw (
      source_table, source_priority, sku, item_name_text, description_text,
      category_text, subcategory_text, manufacturer_text, measure_basis_text, uom_text,
      is_roll_text, roll_type_text, collection_name_text, variant_name_text,
      roll_width_value_text, roll_width_uom_text, roll_width_m_text,
      roll_length_value_text, roll_length_uom_text,
      cost_exw_text, purchase_mode_text, stock_basis_text, purchase_uom_text,
      purchase_unit_text, units_per_purchase_text, is_active_text
    )
    SELECT
      '_stg_catalog_update',
      2,
      trim(coalesce(j->>'sku', '')),
      nullif(trim(coalesce(j->>'item_name', j->>'name', '')), ''),
      nullif(trim(coalesce(j->>'item_description', j->>'description', '')), ''),
      nullif(trim(coalesce(j->>'category', '')), ''),
      nullif(trim(coalesce(j->>'subcategory', j->>'sub_category', j->>'subcategoria', '')), ''),
      nullif(trim(coalesce(j->>'manufacturer', '')), ''),
      nullif(trim(coalesce(j->>'measure_basis', '')), ''),
      nullif(trim(coalesce(j->>'unit_of_measure', j->>'uom', '')), ''),
      nullif(trim(coalesce(j->>'is_roll', j->>'is_fabric', '')), ''),
      nullif(trim(coalesce(j->>'roll_type', '')), ''),
      nullif(trim(coalesce(j->>'collection_name', j->>'collection', '')), ''),
      nullif(trim(coalesce(j->>'variant_name', j->>'variant', '')), ''),
      nullif(trim(coalesce(j->>'roll_width_value', j->>'roll_width', '')), ''),
      nullif(trim(coalesce(j->>'roll_width_uom', '')), ''),
      nullif(trim(coalesce(j->>'roll_width_m', j->>'roll_widt', '')), ''),
      nullif(trim(coalesce(j->>'roll_length_value', '')), ''),
      nullif(trim(coalesce(j->>'roll_length_uom', '')), ''),
      nullif(trim(coalesce(j->>'cost_exw', j->>'cost_price_exw', j->>'fabric_prici', '')), ''),
      nullif(trim(coalesce(j->>'purchase_mode', '')), ''),
      nullif(trim(coalesce(j->>'stock_basis', '')), ''),
      nullif(trim(coalesce(j->>'purchase_uom', '')), ''),
      nullif(trim(coalesce(j->>'purchase_unit', '')), ''),
      nullif(trim(coalesce(j->>'units_per_purchase_unit', '')), ''),
      nullif(trim(coalesce(j->>'is_active', j->>'active', '')), '')
    FROM public."_stg_catalog_update" s
    CROSS JOIN LATERAL to_jsonb(s) j
    WHERE trim(coalesce(j->>'sku', '')) <> '';
  END IF;

  SELECT COUNT(*) INTO raw_count FROM _import_v2_raw;
  IF raw_count = 0 THEN
    RAISE EXCEPTION 'Staging tables found but no valid rows with SKU.';
  END IF;

  CREATE TEMP TABLE _import_v2_norm AS
  SELECT DISTINCT ON (upper(trim(sku)))
    upper(trim(sku)) AS sku,
    nullif(trim(item_name_text), '') AS item_name_text,
    nullif(trim(description_text), '') AS description_text,
    nullif(trim(category_text), '') AS category_text,
    nullif(trim(subcategory_text), '') AS subcategory_text,
    nullif(trim(manufacturer_text), '') AS manufacturer_text,
    nullif(trim(measure_basis_text), '') AS measure_basis_text,
    nullif(trim(uom_text), '') AS uom_text,
    nullif(trim(is_roll_text), '') AS is_roll_text,
    nullif(trim(roll_type_text), '') AS roll_type_text,
    nullif(trim(collection_name_text), '') AS collection_name_text,
    nullif(trim(variant_name_text), '') AS variant_name_text,
    nullif(trim(roll_width_value_text), '') AS roll_width_value_text,
    nullif(trim(roll_width_uom_text), '') AS roll_width_uom_text,
    nullif(trim(roll_width_m_text), '') AS roll_width_m_text,
    nullif(trim(roll_length_value_text), '') AS roll_length_value_text,
    nullif(trim(roll_length_uom_text), '') AS roll_length_uom_text,
    nullif(trim(cost_exw_text), '') AS cost_exw_text,
    nullif(trim(purchase_mode_text), '') AS purchase_mode_text,
    nullif(trim(stock_basis_text), '') AS stock_basis_text,
    nullif(trim(purchase_uom_text), '') AS purchase_uom_text,
    nullif(trim(purchase_unit_text), '') AS purchase_unit_text,
    nullif(trim(units_per_purchase_text), '') AS units_per_purchase_text,
    nullif(trim(is_active_text), '') AS is_active_text,
    NULL::uuid AS category_id,
    NULL::text AS category_match_note
  FROM _import_v2_raw
  ORDER BY upper(trim(sku)), source_priority ASC, row_num DESC;

  -- Map category_id to CatalogCategories leaf nodes.
  -- Priority:
  -- 1) subcategory + parent(category) exact
  -- 2) subcategory exact leaf
  -- 3) category exact leaf
  -- 4) category as parent + child named General
  WITH leaves AS (
    SELECT
      child.id AS leaf_id,
      child.organization_id,
      lower(trim(child.name)) AS leaf_name,
      lower(trim(parent.name)) AS parent_name
    FROM public."CatalogCategories" child
    JOIN public."CatalogCategories" parent
      ON parent.id = child.parent_id
    WHERE child.organization_id = target_org_id
      AND child.parent_id IS NOT NULL
      AND COALESCE(child.is_group, false) = false
      AND COALESCE(child.deleted, false) = false
      AND COALESCE(parent.deleted, false) = false
  ),
  mapped AS (
    SELECT
      n.sku,
      COALESCE(m1.leaf_id, m2.leaf_id, m3.leaf_id, m4.leaf_id) AS mapped_leaf_id,
      COALESCE(m1.note, m2.note, m3.note, m4.note, 'unmapped') AS mapped_note
    FROM _import_v2_norm n
    LEFT JOIN LATERAL (
      SELECT
        CASE WHEN COUNT(*) = 1 THEN MIN(l.leaf_id) END AS leaf_id,
        CASE
          WHEN COUNT(*) = 1 THEN 'subcategory+parent exact'
          WHEN COUNT(*) > 1 THEN 'ambiguous subcategory+parent'
          ELSE NULL
        END AS note
      FROM leaves l
      WHERE n.subcategory_text IS NOT NULL
        AND n.category_text IS NOT NULL
        AND l.leaf_name = lower(n.subcategory_text)
        AND l.parent_name = lower(n.category_text)
    ) m1 ON true
    LEFT JOIN LATERAL (
      SELECT
        CASE WHEN COUNT(*) = 1 THEN MIN(l.leaf_id) END AS leaf_id,
        CASE
          WHEN COUNT(*) = 1 THEN 'subcategory exact'
          WHEN COUNT(*) > 1 THEN 'ambiguous subcategory'
          ELSE NULL
        END AS note
      FROM leaves l
      WHERE m1.leaf_id IS NULL
        AND n.subcategory_text IS NOT NULL
        AND l.leaf_name = lower(n.subcategory_text)
    ) m2 ON true
    LEFT JOIN LATERAL (
      SELECT
        CASE WHEN COUNT(*) = 1 THEN MIN(l.leaf_id) END AS leaf_id,
        CASE
          WHEN COUNT(*) = 1 THEN 'category exact leaf'
          WHEN COUNT(*) > 1 THEN 'ambiguous category leaf'
          ELSE NULL
        END AS note
      FROM leaves l
      WHERE m1.leaf_id IS NULL
        AND m2.leaf_id IS NULL
        AND n.category_text IS NOT NULL
        AND l.leaf_name = lower(n.category_text)
    ) m3 ON true
    LEFT JOIN LATERAL (
      SELECT
        CASE WHEN COUNT(*) = 1 THEN MIN(l.leaf_id) END AS leaf_id,
        CASE
          WHEN COUNT(*) = 1 THEN 'category parent + General child'
          WHEN COUNT(*) > 1 THEN 'ambiguous category parent+General'
          ELSE NULL
        END AS note
      FROM leaves l
      WHERE m1.leaf_id IS NULL
        AND m2.leaf_id IS NULL
        AND m3.leaf_id IS NULL
        AND n.category_text IS NOT NULL
        AND l.parent_name = lower(n.category_text)
        AND l.leaf_name = 'general'
    ) m4 ON true
  )
  UPDATE _import_v2_norm n
  SET
    category_id = mapped.mapped_leaf_id,
    category_match_note = mapped.mapped_note
  FROM mapped
  WHERE mapped.sku = n.sku;

  SELECT COUNT(*) INTO norm_count FROM _import_v2_norm;

  SELECT COUNT(*) INTO missing_category_count
  FROM _import_v2_norm
  WHERE category_id IS NULL
    AND (category_text IS NOT NULL OR subcategory_text IS NOT NULL);

  SELECT COUNT(*) INTO ambiguous_category_count
  FROM _import_v2_norm
  WHERE category_match_note ILIKE 'ambiguous%';

  CREATE TEMP TABLE _import_v2_impacted (
    id uuid PRIMARY KEY
  ) ON COMMIT DROP;

  WITH prepared AS (
    SELECT
      n.sku,
      COALESCE(NULLIF(n.item_name_text, ''), n.sku) AS item_name,
      n.description_text,
      n.category_id,
      n.collection_name_text,
      n.variant_name_text,
      CASE
        WHEN lower(COALESCE(n.measure_basis_text, '')) IN ('linear', 'linear_m', 'length') THEN 'linear'
        WHEN lower(COALESCE(n.measure_basis_text, '')) IN ('area', 'm2', 'sqm') THEN 'area'
        ELSE 'unit'
      END AS measure_basis_norm,
      CASE
        WHEN lower(COALESCE(n.uom_text, '')) IN ('ea', 'each', 'unit', 'units', 'pcs', 'pc') THEN 'ea'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('m', 'meter', 'meters') THEN 'm'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('ft', 'feet') THEN 'ft'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('yd', 'yard', 'yards') THEN 'yd'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('m2', 'sqm', 'square_meter') THEN 'm2'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('ft2', 'sqft') THEN 'ft2'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('yd2', 'sqyd') THEN 'yd2'
        WHEN lower(COALESCE(n.uom_text, '')) IN ('roll') THEN 'roll'
        ELSE COALESCE(NULLIF(lower(n.uom_text), ''), 'ea')
      END AS unit_of_measure_norm,
      CASE
        WHEN lower(COALESCE(n.is_roll_text, '')) IN ('true', '1', 't', 'yes', 'y') THEN true
        WHEN lower(COALESCE(n.roll_type_text, '')) IN ('fabric', 'window_film', 'vinyl', 'mesh', 'paper', 'other') THEN true
        WHEN n.collection_name_text IS NOT NULL AND n.variant_name_text IS NOT NULL THEN true
        ELSE false
      END AS is_roll_norm,
      CASE
        WHEN lower(COALESCE(n.roll_type_text, '')) IN ('fabric', 'window_film', 'vinyl', 'mesh', 'paper', 'other')
          THEN lower(n.roll_type_text)
        ELSE NULL
      END AS roll_type_norm,
      CASE
        WHEN n.roll_width_value_text ~ '^[0-9]+(\.[0-9]+)?$' THEN n.roll_width_value_text::numeric
        ELSE NULL
      END AS roll_width_value_norm,
      CASE
        WHEN lower(COALESCE(n.roll_width_uom_text, '')) IN ('m', 'yd', 'ft', 'in') THEN lower(n.roll_width_uom_text)
        ELSE NULL
      END AS roll_width_uom_norm,
      CASE
        WHEN n.roll_width_m_text ~ '^[0-9]+(\.[0-9]+)?$' THEN n.roll_width_m_text::numeric
        WHEN n.roll_width_value_text ~ '^[0-9]+(\.[0-9]+)?$'
             AND lower(COALESCE(n.roll_width_uom_text, '')) = 'm' THEN n.roll_width_value_text::numeric
        WHEN n.roll_width_value_text ~ '^[0-9]+(\.[0-9]+)?$'
             AND lower(COALESCE(n.roll_width_uom_text, '')) = 'yd' THEN n.roll_width_value_text::numeric * 0.9144
        WHEN n.roll_width_value_text ~ '^[0-9]+(\.[0-9]+)?$'
             AND lower(COALESCE(n.roll_width_uom_text, '')) = 'ft' THEN n.roll_width_value_text::numeric * 0.3048
        WHEN n.roll_width_value_text ~ '^[0-9]+(\.[0-9]+)?$'
             AND lower(COALESCE(n.roll_width_uom_text, '')) = 'in' THEN n.roll_width_value_text::numeric * 0.0254
        ELSE NULL
      END AS roll_width_m_norm,
      CASE
        WHEN n.roll_length_value_text ~ '^[0-9]+(\.[0-9]+)?$' THEN n.roll_length_value_text::numeric
        ELSE NULL
      END AS roll_length_value_norm,
      CASE
        WHEN lower(COALESCE(n.roll_length_uom_text, '')) IN ('m', 'yd', 'ft', 'in') THEN lower(n.roll_length_uom_text)
        ELSE NULL
      END AS roll_length_uom_norm,
      CASE
        WHEN n.cost_exw_text ~ '^[0-9]+(\.[0-9]+)?$' THEN n.cost_exw_text::numeric
        ELSE NULL
      END AS cost_exw_norm,
      CASE
        WHEN lower(COALESCE(n.purchase_mode_text, '')) IN ('unit_packaged', 'linear_direct', 'roll')
          THEN lower(n.purchase_mode_text)
        WHEN lower(COALESCE(n.is_roll_text, '')) IN ('true', '1', 't', 'yes', 'y')
          OR lower(COALESCE(n.roll_type_text, '')) IN ('fabric', 'window_film', 'vinyl', 'mesh', 'paper', 'other')
          THEN 'roll'
        WHEN lower(COALESCE(n.measure_basis_text, '')) IN ('linear', 'linear_m', 'length')
          THEN 'linear_direct'
        ELSE 'unit_packaged'
      END AS purchase_mode_norm,
      CASE
        WHEN lower(COALESCE(n.stock_basis_text, '')) IN ('ea', 'linear_m')
          THEN lower(n.stock_basis_text)
        WHEN lower(COALESCE(n.is_roll_text, '')) IN ('true', '1', 't', 'yes', 'y')
          OR lower(COALESCE(n.measure_basis_text, '')) IN ('linear', 'linear_m', 'length')
          THEN 'linear_m'
        ELSE 'ea'
      END AS stock_basis_norm,
      CASE
        WHEN lower(COALESCE(n.purchase_uom_text, '')) <> '' THEN lower(n.purchase_uom_text)
        WHEN lower(COALESCE(n.purchase_mode_text, '')) = 'roll' THEN 'roll'
        WHEN lower(COALESCE(n.measure_basis_text, '')) IN ('linear', 'linear_m', 'length')
          THEN COALESCE(NULLIF(lower(n.uom_text), ''), 'm')
        ELSE COALESCE(NULLIF(lower(n.purchase_unit_text), ''), 'each')
      END AS purchase_uom_norm,
      CASE
        WHEN lower(COALESCE(n.purchase_unit_text, '')) IN ('each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton', 'roll', 'm', 'ft', 'yd')
          THEN lower(n.purchase_unit_text)
        WHEN lower(COALESCE(n.purchase_mode_text, '')) = 'roll' THEN 'roll'
        ELSE 'each'
      END AS purchase_unit_norm,
      CASE
        WHEN n.units_per_purchase_text ~ '^[0-9]+(\.[0-9]+)?$' THEN GREATEST(n.units_per_purchase_text::numeric, 1)
        ELSE 1
      END AS units_per_purchase_norm,
      CASE
        WHEN lower(COALESCE(n.is_active_text, '')) IN ('false', '0', 'f', 'no', 'n') THEN false
        ELSE true
      END AS is_active_norm,
      m.id AS manufacturer_id
    FROM _import_v2_norm n
    LEFT JOIN public."Manufacturers" m
      ON m.organization_id = target_org_id
     AND COALESCE(m.deleted, false) = false
     AND lower(trim(m.name)) = lower(trim(n.manufacturer_text))
  ),
  upserted AS (
    INSERT INTO public."CatalogItems" (
      organization_id,
      sku,
      name,
      description,
      category_id,
      collection_name,
      variant_name,
      measure_basis,
      unit_of_measure,
      is_roll,
      roll_type,
      roll_width_value,
      roll_width_uom,
      roll_width_m,
      roll_length_value,
      roll_length_uom,
      cost_exw,
      manufacturer_id,
      purchase_mode,
      stock_basis,
      purchase_uom,
      purchase_unit,
      units_per_purchase_unit,
      is_active,
      updated_at
    )
    SELECT
      target_org_id,
      p.sku,
      p.item_name,
      p.description_text,
      p.category_id,
      p.collection_name_text,
      p.variant_name_text,
      p.measure_basis_norm,
      p.unit_of_measure_norm,
      p.is_roll_norm,
      p.roll_type_norm::public.roll_type,
      p.roll_width_value_norm,
      p.roll_width_uom_norm,
      p.roll_width_m_norm,
      p.roll_length_value_norm,
      p.roll_length_uom_norm,
      p.cost_exw_norm,
      p.manufacturer_id,
      p.purchase_mode_norm,
      p.stock_basis_norm,
      p.purchase_uom_norm,
      p.purchase_unit_norm,
      p.units_per_purchase_norm,
      p.is_active_norm,
      now()
    FROM prepared p
    ON CONFLICT (organization_id, sku) WHERE deleted = false
    DO UPDATE SET
      name = COALESCE(EXCLUDED.name, public."CatalogItems".name),
      description = COALESCE(EXCLUDED.description, public."CatalogItems".description),
      category_id = COALESCE(EXCLUDED.category_id, public."CatalogItems".category_id),
      collection_name = COALESCE(EXCLUDED.collection_name, public."CatalogItems".collection_name),
      variant_name = COALESCE(EXCLUDED.variant_name, public."CatalogItems".variant_name),
      measure_basis = COALESCE(EXCLUDED.measure_basis, public."CatalogItems".measure_basis),
      unit_of_measure = COALESCE(EXCLUDED.unit_of_measure, public."CatalogItems".unit_of_measure),
      is_roll = COALESCE(EXCLUDED.is_roll, public."CatalogItems".is_roll),
      roll_type = COALESCE(EXCLUDED.roll_type, public."CatalogItems".roll_type),
      roll_width_value = COALESCE(EXCLUDED.roll_width_value, public."CatalogItems".roll_width_value),
      roll_width_uom = COALESCE(EXCLUDED.roll_width_uom, public."CatalogItems".roll_width_uom),
      roll_width_m = COALESCE(EXCLUDED.roll_width_m, public."CatalogItems".roll_width_m),
      roll_length_value = COALESCE(EXCLUDED.roll_length_value, public."CatalogItems".roll_length_value),
      roll_length_uom = COALESCE(EXCLUDED.roll_length_uom, public."CatalogItems".roll_length_uom),
      cost_exw = COALESCE(EXCLUDED.cost_exw, public."CatalogItems".cost_exw),
      manufacturer_id = COALESCE(EXCLUDED.manufacturer_id, public."CatalogItems".manufacturer_id),
      purchase_mode = COALESCE(EXCLUDED.purchase_mode, public."CatalogItems".purchase_mode),
      stock_basis = COALESCE(EXCLUDED.stock_basis, public."CatalogItems".stock_basis),
      purchase_uom = COALESCE(EXCLUDED.purchase_uom, public."CatalogItems".purchase_uom),
      purchase_unit = COALESCE(EXCLUDED.purchase_unit, public."CatalogItems".purchase_unit),
      units_per_purchase_unit = COALESCE(EXCLUDED.units_per_purchase_unit, public."CatalogItems".units_per_purchase_unit),
      is_active = COALESCE(EXCLUDED.is_active, public."CatalogItems".is_active),
      updated_at = now()
    RETURNING id
  )
  INSERT INTO _import_v2_impacted (id)
  SELECT DISTINCT u.id
  FROM upserted u
  ON CONFLICT (id) DO NOTHING;

  SELECT COUNT(*) INTO impacted_count FROM _import_v2_impacted;

  -- Controlled recompute for derived layers.
  -- 1) CatalogItemConversions: trigger recompute via no-op UPDATE on watched column.
  -- 2) CatalogItemsMSRP: explicit function call per item with error isolation.
  FOR
    _item IN
      SELECT ci.id, ci.organization_id
      FROM public."CatalogItems" ci
      JOIN _import_v2_impacted i ON i.id = ci.id
  LOOP
    BEGIN
      UPDATE public."CatalogItems"
      SET cost_exw = cost_exw, updated_at = now()
      WHERE id = _item.id
        AND organization_id = _item.organization_id;

      PERFORM public.msrp_compute_for_item(_item.id);
      recompute_ok_count := recompute_ok_count + 1;
    EXCEPTION WHEN OTHERS THEN
      recompute_fail_count := recompute_fail_count + 1;
      RAISE NOTICE 'Recompute failed for item %: %', _item.id, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '-------------- IMPORT V2 REPORT --------------';
  RAISE NOTICE 'Raw staging rows: %', raw_count;
  RAISE NOTICE 'Normalized distinct SKUs: %', norm_count;
  RAISE NOTICE 'Impacted CatalogItems (insert+update): %', impacted_count;
  RAISE NOTICE 'SKUs with missing category mapping: %', missing_category_count;
  RAISE NOTICE 'SKUs with ambiguous category mapping: %', ambiguous_category_count;
  RAISE NOTICE 'Recompute OK: %', recompute_ok_count;
  RAISE NOTICE 'Recompute FAIL: %', recompute_fail_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Top unmapped category samples (max 20):';
  FOR _unmapped IN
    SELECT sku, category_text, subcategory_text, category_match_note
    FROM _import_v2_norm
    WHERE category_id IS NULL
      AND (category_text IS NOT NULL OR subcategory_text IS NOT NULL)
    ORDER BY sku
    LIMIT 20
  LOOP
    RAISE NOTICE '  SKU=% | category=% | subcategory=% | note=%',
      _unmapped.sku,
      COALESCE(_unmapped.category_text, '<null>'),
      COALESCE(_unmapped.subcategory_text, '<null>'),
      COALESCE(_unmapped.category_match_note, '<null>');
  END LOOP;

  RAISE NOTICE 'Done.';
  RAISE NOTICE '-----------------------------------------------';
END $$;
