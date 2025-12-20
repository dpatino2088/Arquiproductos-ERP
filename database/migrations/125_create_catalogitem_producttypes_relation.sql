-- ====================================================
-- Migration 125: Create many-to-many relationship between CatalogItems and ProductTypes
-- ====================================================
-- This allows a single SKU to be used in multiple ProductTypes
-- (e.g., a fabric can be used in both Roller Shade and Dual Shade)
-- ====================================================

DO $$
DECLARE
    v_table_exists BOOLEAN;
    v_org_id UUID;
    v_migrated_count INTEGER;
BEGIN
    RAISE NOTICE '🚀 Starting Migration 125: Create CatalogItem-ProductTypes relation';
    RAISE NOTICE '====================================================';
    
    -- Check if table already exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemProductTypes'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        RAISE NOTICE 'ℹ️  Table CatalogItemProductTypes already exists. Skipping creation.';
    ELSE
        RAISE NOTICE '📝 Creating table CatalogItemProductTypes...';
        
        -- Create the junction table
        CREATE TABLE IF NOT EXISTS "CatalogItemProductTypes" (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            catalog_item_id UUID NOT NULL,
            product_type_id UUID NOT NULL,
            organization_id UUID NOT NULL,
            is_primary BOOLEAN DEFAULT false, -- Indicates if this is the primary ProductType for this item
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            deleted BOOLEAN NOT NULL DEFAULT false,
            
            -- Foreign keys
            CONSTRAINT fk_catalogitem_producttypes_item 
                FOREIGN KEY (catalog_item_id) 
                REFERENCES "CatalogItems"(id) 
                ON DELETE CASCADE,
            CONSTRAINT fk_catalogitem_producttypes_producttype 
                FOREIGN KEY (product_type_id) 
                REFERENCES "ProductTypes"(id) 
                ON DELETE CASCADE,
            CONSTRAINT fk_catalogitem_producttypes_organization 
                FOREIGN KEY (organization_id) 
                REFERENCES "Organizations"(id) 
                ON DELETE CASCADE,
            
            -- Unique constraint: one item can only be linked to a ProductType once
            CONSTRAINT uq_catalogitem_producttype 
                UNIQUE (catalog_item_id, product_type_id, organization_id)
        );
        
        -- Create indexes
        CREATE INDEX IF NOT EXISTS idx_catalogitem_producttypes_item 
            ON "CatalogItemProductTypes"(catalog_item_id) 
            WHERE deleted = false;
        
        CREATE INDEX IF NOT EXISTS idx_catalogitem_producttypes_producttype 
            ON "CatalogItemProductTypes"(product_type_id) 
            WHERE deleted = false;
        
        CREATE INDEX IF NOT EXISTS idx_catalogitem_producttypes_organization 
            ON "CatalogItemProductTypes"(organization_id) 
            WHERE deleted = false;
        
        CREATE INDEX IF NOT EXISTS idx_catalogitem_producttypes_primary 
            ON "CatalogItemProductTypes"(catalog_item_id, is_primary) 
            WHERE deleted = false AND is_primary = true;
        
        RAISE NOTICE '✅ Table CatalogItemProductTypes created successfully';
    END IF;
    
    RAISE NOTICE '';
    
    -- Get the first organization
    SELECT id INTO v_org_id
    FROM "Organizations"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE NOTICE '⚠️  No organization found. Skipping data migration.';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Organization ID: %', v_org_id;
    RAISE NOTICE '';
    
    -- Migrate existing data from family column to the new relation table
    RAISE NOTICE 'STEP 1: Migrating existing family values to CatalogItemProductTypes...';
    
    INSERT INTO "CatalogItemProductTypes" (
        catalog_item_id,
        product_type_id,
        organization_id,
        is_primary,
        created_at,
        updated_at,
        deleted
    )
    SELECT DISTINCT
        ci.id as catalog_item_id,
        pt.id as product_type_id,
        ci.organization_id,
        true as is_primary, -- Mark as primary since it came from the family column
        NOW() as created_at,
        NOW() as updated_at,
        false as deleted
    FROM "CatalogItems" ci
    INNER JOIN "ProductTypes" pt ON (
        pt.organization_id = ci.organization_id
        AND pt.deleted = false
        AND pt.name = ci.family -- Match family with ProductTypes.name
    )
    WHERE ci.organization_id = v_org_id
      AND ci.deleted = false
      AND ci.family IS NOT NULL
      AND NOT EXISTS (
          -- Avoid duplicates
          SELECT 1 FROM "CatalogItemProductTypes" cipt
          WHERE cipt.catalog_item_id = ci.id
            AND cipt.product_type_id = pt.id
            AND cipt.organization_id = ci.organization_id
      );
    
    GET DIAGNOSTICS v_migrated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Migrated % CatalogItems to CatalogItemProductTypes', v_migrated_count;
    RAISE NOTICE '';
    
    -- Show statistics
    RAISE NOTICE 'STEP 2: Migration statistics:';
    
    -- Items with relations
    SELECT COUNT(DISTINCT catalog_item_id) INTO v_migrated_count
    FROM "CatalogItemProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false;
    RAISE NOTICE '   - Items with ProductType relations: %', v_migrated_count;
    
    -- Items with multiple ProductTypes
    SELECT COUNT(*) INTO v_migrated_count
    FROM (
        SELECT catalog_item_id
        FROM "CatalogItemProductTypes"
        WHERE organization_id = v_org_id
          AND deleted = false
        GROUP BY catalog_item_id
        HAVING COUNT(*) > 1
    ) multi;
    RAISE NOTICE '   - Items linked to multiple ProductTypes: %', v_migrated_count;
    
    -- Items without relations (should be 0 if all had family values)
    SELECT COUNT(*) INTO v_migrated_count
    FROM "CatalogItems" ci
    WHERE ci.organization_id = v_org_id
      AND ci.deleted = false
      AND ci.family IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM "CatalogItemProductTypes" cipt
          WHERE cipt.catalog_item_id = ci.id
            AND cipt.organization_id = ci.organization_id
            AND cipt.deleted = false
      );
    
    IF v_migrated_count > 0 THEN
        RAISE NOTICE '   ⚠️  Items with family but no ProductType relation: %', v_migrated_count;
        RAISE NOTICE '   These items may have family values that do not match any ProductTypes.name';
    ELSE
        RAISE NOTICE '   ✅ All items with family values have been linked to ProductTypes';
    END IF;
    RAISE NOTICE '';
    
    RAISE NOTICE '✅ Migration 125 completed successfully!';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Next steps:';
    RAISE NOTICE '   1. Update frontend to use CatalogItemProductTypes instead of family';
    RAISE NOTICE '   2. The family column can remain for backward compatibility';
    RAISE NOTICE '   3. Consider making family nullable or removing it in future migrations';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error in Migration 125: %', SQLERRM;
        RAISE;
END $$;


