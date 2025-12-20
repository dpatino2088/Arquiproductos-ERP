-- ====================================================
-- Diagnostic Script: Check CollectionsCatalog Status
-- ====================================================
-- Helps diagnose why CollectionsCatalog might be empty
-- ====================================================

DO $$
DECLARE
    table_exists boolean;
    total_fabrics integer;
    total_collections integer;
    sample_sku text;
    sample_metadata jsonb;
    rec RECORD;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CollectionsCatalog'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE NOTICE '❌ Table CollectionsCatalog does NOT exist!';
        RAISE NOTICE '   Run create_collections_catalog_complete.sql first';
        RETURN;
    ELSE
        RAISE NOTICE '✅ Table CollectionsCatalog exists';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Statistics:';
    
    -- Count total fabrics in CatalogItems
    SELECT COUNT(*) INTO total_fabrics
    FROM "CatalogItems"
    WHERE is_fabric = true AND deleted = false;
    
    RAISE NOTICE '   Total fabrics in CatalogItems (is_fabric=true): %', total_fabrics;
    
    -- Count total records in CollectionsCatalog
    SELECT COUNT(*) INTO total_collections
    FROM "CollectionsCatalog"
    WHERE deleted = false;
    
    RAISE NOTICE '   Total records in CollectionsCatalog: %', total_collections;
    
    IF total_fabrics = 0 THEN
        RAISE NOTICE '';
        RAISE WARNING '⚠️  No fabrics found in CatalogItems!';
        RAISE NOTICE '   Check if CatalogItems has records with is_fabric = true';
        RETURN;
    END IF;
    
    IF total_collections = 0 THEN
        RAISE NOTICE '';
        RAISE WARNING '⚠️  CollectionsCatalog is empty!';
        RAISE NOTICE '   Run populate_collections_catalog_from_fabrics.sql';
    END IF;
    
    -- Show sample fabrics
    RAISE NOTICE '';
    RAISE NOTICE '📋 Sample Fabrics (first 5):';
    FOR rec IN 
        SELECT 
            id,
            organization_id,
            sku,
            name,
            item_type,
            is_fabric,
            metadata,
            roll_width_m,
            cost_price
        FROM "CatalogItems"
        WHERE is_fabric = true 
          AND deleted = false
        ORDER BY created_at DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '   Fabric: %', rec.name;
        RAISE NOTICE '      ID: %', rec.id;
        RAISE NOTICE '      SKU: %', rec.sku;
        RAISE NOTICE '      Item Type: %', rec.item_type;
        RAISE NOTICE '      Is Fabric: %', rec.is_fabric;
        RAISE NOTICE '      Roll Width: %', rec.roll_width_m;
        RAISE NOTICE '      Cost Price: %', rec.cost_price;
        
        IF rec.metadata IS NOT NULL THEN
            RAISE NOTICE '      Metadata: %', rec.metadata::text;
            
            -- Check for collection in metadata
            IF rec.metadata ? 'collection' THEN
                RAISE NOTICE '      → Collection (from metadata): %', rec.metadata->>'collection';
            ELSE
                RAISE NOTICE '      → Collection: NOT FOUND in metadata';
            END IF;
            
            -- Check for variant/color in metadata
            IF rec.metadata ? 'variant' THEN
                RAISE NOTICE '      → Variant (from metadata): %', rec.metadata->>'variant';
            ELSIF rec.metadata ? 'color' THEN
                RAISE NOTICE '      → Color (from metadata): %', rec.metadata->>'color';
            ELSIF rec.metadata ? 'color_name' THEN
                RAISE NOTICE '      → Color Name (from metadata): %', rec.metadata->>'color_name';
            ELSE
                RAISE NOTICE '      → Variant/Color: NOT FOUND in metadata';
            END IF;
        ELSE
            RAISE NOTICE '      Metadata: NULL';
            RAISE NOTICE '      → Will try to extract from SKU: %', rec.sku;
        END IF;
        
        -- Check if already in CollectionsCatalog
        IF EXISTS (
            SELECT 1 
            FROM "CollectionsCatalog" 
            WHERE catalog_item_id = rec.id 
              AND deleted = false
        ) THEN
            RAISE NOTICE '      ✅ Already in CollectionsCatalog';
        ELSE
            RAISE NOTICE '      ❌ NOT in CollectionsCatalog';
        END IF;
    END LOOP;
    
    -- Show sample CollectionsCatalog records if any
    IF total_collections > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '📋 Sample CollectionsCatalog Records (first 5):';
        FOR rec IN 
            SELECT 
                id,
                organization_id,
                catalog_item_id,
                sku,
                name,
                collection_name,
                variant_name,
                roll_width,
                grammage_gsm,
                openness_pct
            FROM "CollectionsCatalog"
            WHERE deleted = false
            ORDER BY created_at DESC
            LIMIT 5
        LOOP
            RAISE NOTICE '   % | Collection: % | Variant: % | SKU: %', 
                rec.name, 
                rec.collection_name, 
                rec.variant_name, 
                rec.sku;
        END LOOP;
    END IF;
    
    -- Check for common issues
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Checking for common issues:';
    
    -- Check if there are fabrics without metadata
    SELECT COUNT(*) INTO rec
    FROM "CatalogItems"
    WHERE is_fabric = true 
      AND deleted = false
      AND (metadata IS NULL OR metadata = '{}'::jsonb);
    
    IF rec > 0 THEN
        RAISE WARNING '   ⚠️  % fabrics have no metadata - extraction will rely on SKU/name', rec;
    END IF;
    
    -- Check if there are fabrics with metadata but no collection/variant
    SELECT COUNT(*) INTO rec
    FROM "CatalogItems"
    WHERE is_fabric = true 
      AND deleted = false
      AND metadata IS NOT NULL
      AND NOT (metadata ? 'collection')
      AND NOT (metadata ? 'variant')
      AND NOT (metadata ? 'color')
      AND NOT (metadata ? 'color_name');
    
    IF rec > 0 THEN
        RAISE WARNING '   ⚠️  % fabrics have metadata but no collection/variant fields', rec;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Diagnostic complete';
    
END $$;





