-- ====================================================
-- Migration: Import Catalog Data from Staging Table
-- ====================================================
-- This script imports data from _stg_catalog_items staging table
-- Updated structure: variant_name as text, item_name field
-- ====================================================

BEGIN;

DO $$
DECLARE
    target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
BEGIN

    -- ====================================================
    -- STEP 1: Import Manufacturers
    -- ====================================================
    -- Note: Supabase converts column names to lowercase when importing CSV
    INSERT INTO public."Manufacturers" (organization_id, name)
    SELECT DISTINCT
      target_org_id,
      trim(manufacturer)
    FROM public."_stg_catalog_items"
    WHERE manufacturer IS NOT NULL AND trim(manufacturer) <> ''
    ON CONFLICT DO NOTHING;

    RAISE NOTICE '✅ Manufacturers imported';

    -- ====================================================
    -- STEP 2: Import CollectionsCatalog
    -- ====================================================
    -- Import ALL collections that have a value (not just fabrics)
    -- Note: Supabase converts column names to lowercase when importing CSV
    -- Use LEFT JOIN to import collections even if manufacturer is missing
    INSERT INTO public."CollectionsCatalog" (organization_id, manufacturer_id, collection_name)
    SELECT DISTINCT
      target_org_id,
      m.id,  -- Will be NULL if manufacturer doesn't exist
      trim(s.collection)
    FROM public."_stg_catalog_items" s
    LEFT JOIN public."Manufacturers" m
      ON lower(m.name) = lower(trim(s.manufacturer))
    WHERE s.collection IS NOT NULL 
      AND trim(s.collection) <> ''
    ON CONFLICT DO NOTHING;

    RAISE NOTICE '✅ Collections imported';

    -- ====================================================
    -- STEP 3: Import CatalogItems
    -- ====================================================
    -- IMPORTANT: variant_name is now a text field, not FK
    -- item_name is stored from CSV Item_name column
    -- First UPDATE existing records, then INSERT new ones
    
    -- Update existing CatalogItems
    UPDATE public."CatalogItems" ci
    SET
      item_name = trim(s.item_name),
      description = trim(s.item_description),
      manufacturer_id = m.id,
      item_category_id = ic.id,
      collection_id = CASE 
        WHEN COALESCE(s.is_fabric, FALSE) = TRUE
          AND s.collection IS NOT NULL 
          AND trim(s.collection) <> ''
        THEN c.id
        ELSE NULL
      END,
      variant_name = CASE 
        WHEN COALESCE(s.is_fabric, FALSE) = TRUE
          AND (s.variant IS NOT NULL OR s."Variant" IS NOT NULL)
          AND (trim(COALESCE(s.variant, s."Variant", '')) <> '')
        THEN trim(COALESCE(s.variant, s."Variant", ''))
        ELSE NULL
      END,
      item_type = s.item_type,
      measure_basis = s.measure_basis,
      uom = s.uom,
      is_fabric = COALESCE(s.is_fabric, FALSE),
      roll_width_m = s.roll_width_m,
      fabric_pricing_mode = s.fabric_pricing_mode,
      active = COALESCE(s.active, TRUE),
      discontinued = COALESCE(s.discontinued, FALSE),
      updated_at = now()
    FROM public."_stg_catalog_items" s
    LEFT JOIN public."Manufacturers" m
      ON lower(m.name) = lower(trim(s.manufacturer))
    LEFT JOIN public."ItemCategories" ic
      ON lower(ic.name) = lower(trim(s.category))
    LEFT JOIN public."CollectionsCatalog" c
      ON lower(c.collection_name) = lower(trim(s.collection))
      AND c.organization_id = target_org_id
    WHERE ci.organization_id = target_org_id
      AND lower(trim(ci.sku)) = lower(trim(s.sku))
      AND s.sku IS NOT NULL 
      AND trim(s.sku) <> '';

    RAISE NOTICE '✅ Existing CatalogItems updated';

    -- Insert new CatalogItems (those that don't exist)
    INSERT INTO public."CatalogItems" (
      organization_id, 
      sku, 
      item_name,           -- NEW: from CSV Item_name
      description,
      manufacturer_id, 
      item_category_id,
      collection_id,       -- FK to CollectionsCatalog (only for fabrics)
      variant_name,        -- NEW: text field from CSV Variant (not FK)
      item_type, 
      measure_basis, 
      uom,
      is_fabric, 
      roll_width_m, 
      fabric_pricing_mode,
      active, 
      discontinued, 
      cost_exw
    )
    SELECT
      target_org_id,
      trim(s.sku),
      trim(s.item_name),                    -- item_name from CSV (lowercase after import)
      trim(s.item_description),             -- item_description from CSV
      m.id,
      ic.id,
      CASE 
        WHEN COALESCE(s.is_fabric, FALSE) = TRUE
          AND s.collection IS NOT NULL 
          AND trim(s.collection) <> ''
        THEN c.id
        ELSE NULL
      END,                                    -- collection_id only for fabrics
      CASE 
        WHEN COALESCE(s.is_fabric, FALSE) = TRUE
          AND (s.variant IS NOT NULL OR s."Variant" IS NOT NULL)
          AND (trim(COALESCE(s.variant, s."Variant", '')) <> '')
        THEN trim(COALESCE(s.variant, s."Variant", ''))
        ELSE NULL
      END,                                    -- variant_name as text (only for fabrics)
      s.item_type,
      s.measure_basis,
      s.uom,
      COALESCE(s.is_fabric, FALSE),
      s.roll_width_m,                        -- Already numeric type
      s.fabric_pricing_mode,                  -- Already numeric type
      COALESCE(s.active, TRUE),
      COALESCE(s.discontinued, FALSE),
      0
    FROM public."_stg_catalog_items" s
    LEFT JOIN public."Manufacturers" m
      ON lower(m.name) = lower(trim(s.manufacturer))
    LEFT JOIN public."ItemCategories" ic
      ON lower(ic.name) = lower(trim(s.category))
    LEFT JOIN public."CollectionsCatalog" c
      ON lower(c.collection_name) = lower(trim(s.collection))
      AND c.organization_id = target_org_id
    WHERE s.sku IS NOT NULL 
      AND trim(s.sku) <> ''
      AND NOT EXISTS (
        SELECT 1 
        FROM public."CatalogItems" ci
        WHERE ci.organization_id = target_org_id
          AND lower(trim(ci.sku)) = lower(trim(s.sku))
      );

    RAISE NOTICE '✅ CatalogItems imported';

    -- ====================================================
    -- STEP 4: Import ProductTypes (family)
    -- ====================================================
    WITH exploded_families AS (
      SELECT
        trim(s.sku) AS sku,
        trim(f) AS family_name
      FROM public."_stg_catalog_items" s,
           unnest(string_to_array(s.family, ',')) AS f
      WHERE s.family IS NOT NULL AND trim(s.family) <> ''
    )
    INSERT INTO public."CatalogItemProductTypes" (
      organization_id, 
      catalog_item_id, 
      product_type_id
    )
    SELECT DISTINCT
      target_org_id,
      ci.id,
      pt.id
    FROM exploded_families ef
    JOIN public."CatalogItems" ci
      ON lower(ci.sku) = lower(ef.sku)
      AND ci.organization_id = target_org_id
    JOIN public."ProductTypes" pt
      ON lower(pt.name) = lower(ef.family_name)
    ON CONFLICT DO NOTHING;

    RAISE NOTICE '✅ ProductTypes relationships imported';

    RAISE NOTICE '✅ All catalog data imported successfully!';

END $$;

COMMIT;

-- ====================================================
-- Notes:
-- - variant_name is stored as text in CatalogItems (not FK to CollectionVariants)
-- - item_name is stored from CSV Item_name column
-- - collection_id is only set for fabrics (is_fabric = TRUE)
-- - CollectionVariants table is not used in this structure
-- ====================================================

