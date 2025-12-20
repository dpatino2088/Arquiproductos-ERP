-- ====================================================
-- Migration 127: Fix Missing ProductTypes and Relations
-- ====================================================
-- This script ensures all required ProductTypes exist and are properly related
-- ====================================================

DO $$
DECLARE
    v_org_id UUID;
    v_product_type_id UUID;
    v_created_count INTEGER := 0;
    v_updated_count INTEGER := 0;
    v_relation_count INTEGER := 0;
    v_product_type_rec RECORD;
    v_catalog_item_rec RECORD;
    v_family_value TEXT;
    v_is_primary BOOLEAN;
    v_family_array TEXT[];
    v_primary_family TEXT;
BEGIN
    RAISE NOTICE '🚀 Starting Migration 127: Fix Missing ProductTypes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Get the first organization
    SELECT id INTO v_org_id
    FROM "Organizations"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE NOTICE '❌ No organization found.';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Organization ID: %', v_org_id;
    RAISE NOTICE '';
    
    -- Required ProductTypes (matching the FAMILY_MAP in VariantsStep.tsx)
    -- 'roller-shade': 'Roller Shade',
    -- 'dual-shade': 'Dual Shade',
    -- 'triple-shade': 'Triple Shade',
    -- 'drapery': 'Drapery',
    -- 'awning': 'Awning',
    -- 'window-film': 'Window Film',
    
    RAISE NOTICE 'STEP 1: Ensuring all required ProductTypes exist...';
    RAISE NOTICE '';
    
    -- Create or verify "Roller Shade"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND (name = 'Roller Shade' OR name = 'Roller Shades' OR name ILIKE '%roller%shade%')
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        INSERT INTO "ProductTypes" (id, organization_id, name, code, deleted, archived, created_at, updated_at)
        VALUES (gen_random_uuid(), v_org_id, 'Roller Shade', 'RS', false, false, NOW(), NOW())
        RETURNING id INTO v_product_type_id;
        v_created_count := v_created_count + 1;
        RAISE NOTICE '   ✅ Created ProductType: Roller Shade (ID: %)', v_product_type_id;
    ELSE
        -- Update name to exact match if needed
        UPDATE "ProductTypes"
        SET name = 'Roller Shade', updated_at = NOW()
        WHERE id = v_product_type_id AND name != 'Roller Shade';
        
        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '   ✅ Updated ProductType: Roller Shade (ID: %)', v_product_type_id;
        ELSE
            RAISE NOTICE '   ℹ️  ProductType already exists: Roller Shade (ID: %)', v_product_type_id;
        END IF;
    END IF;
    
    -- Create or verify "Dual Shade"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND (name = 'Dual Shade' OR name = 'Dual Shades' OR name ILIKE '%dual%shade%')
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        INSERT INTO "ProductTypes" (id, organization_id, name, code, deleted, archived, created_at, updated_at)
        VALUES (gen_random_uuid(), v_org_id, 'Dual Shade', 'DS', false, false, NOW(), NOW())
        RETURNING id INTO v_product_type_id;
        v_created_count := v_created_count + 1;
        RAISE NOTICE '   ✅ Created ProductType: Dual Shade (ID: %)', v_product_type_id;
    ELSE
        UPDATE "ProductTypes"
        SET name = 'Dual Shade', updated_at = NOW()
        WHERE id = v_product_type_id AND name != 'Dual Shade';
        
        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '   ✅ Updated ProductType: Dual Shade (ID: %)', v_product_type_id;
        ELSE
            RAISE NOTICE '   ℹ️  ProductType already exists: Dual Shade (ID: %)', v_product_type_id;
        END IF;
    END IF;
    
    -- Create or verify "Triple Shade"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND (name = 'Triple Shade' OR name = 'Triple Shades' OR name ILIKE '%triple%shade%')
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        INSERT INTO "ProductTypes" (id, organization_id, name, code, deleted, archived, created_at, updated_at)
        VALUES (gen_random_uuid(), v_org_id, 'Triple Shade', 'TS', false, false, NOW(), NOW())
        RETURNING id INTO v_product_type_id;
        v_created_count := v_created_count + 1;
        RAISE NOTICE '   ✅ Created ProductType: Triple Shade (ID: %)', v_product_type_id;
    ELSE
        UPDATE "ProductTypes"
        SET name = 'Triple Shade', updated_at = NOW()
        WHERE id = v_product_type_id AND name != 'Triple Shade';
        
        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '   ✅ Updated ProductType: Triple Shade (ID: %)', v_product_type_id;
        ELSE
            RAISE NOTICE '   ℹ️  ProductType already exists: Triple Shade (ID: %)', v_product_type_id;
        END IF;
    END IF;
    
    -- Create or verify "Drapery"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND (name = 'Drapery' OR name ILIKE '%drapery%')
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        INSERT INTO "ProductTypes" (id, organization_id, name, code, deleted, archived, created_at, updated_at)
        VALUES (gen_random_uuid(), v_org_id, 'Drapery', 'DR', false, false, NOW(), NOW())
        RETURNING id INTO v_product_type_id;
        v_created_count := v_created_count + 1;
        RAISE NOTICE '   ✅ Created ProductType: Drapery (ID: %)', v_product_type_id;
    ELSE
        UPDATE "ProductTypes"
        SET name = 'Drapery', updated_at = NOW()
        WHERE id = v_product_type_id AND name != 'Drapery';
        
        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '   ✅ Updated ProductType: Drapery (ID: %)', v_product_type_id;
        ELSE
            RAISE NOTICE '   ℹ️  ProductType already exists: Drapery (ID: %)', v_product_type_id;
        END IF;
    END IF;
    
    -- Create or verify "Awning"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND (name = 'Awning' OR name ILIKE '%awning%')
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        INSERT INTO "ProductTypes" (id, organization_id, name, code, deleted, archived, created_at, updated_at)
        VALUES (gen_random_uuid(), v_org_id, 'Awning', 'AW', false, false, NOW(), NOW())
        RETURNING id INTO v_product_type_id;
        v_created_count := v_created_count + 1;
        RAISE NOTICE '   ✅ Created ProductType: Awning (ID: %)', v_product_type_id;
    ELSE
        UPDATE "ProductTypes"
        SET name = 'Awning', updated_at = NOW()
        WHERE id = v_product_type_id AND name != 'Awning';
        
        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '   ✅ Updated ProductType: Awning (ID: %)', v_product_type_id;
        ELSE
            RAISE NOTICE '   ℹ️  ProductType already exists: Awning (ID: %)', v_product_type_id;
        END IF;
    END IF;
    
    -- Create or verify "Window Film"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND (name = 'Window Film' OR name ILIKE '%window%film%')
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        INSERT INTO "ProductTypes" (id, organization_id, name, code, deleted, archived, created_at, updated_at)
        VALUES (gen_random_uuid(), v_org_id, 'Window Film', 'WF', false, false, NOW(), NOW())
        RETURNING id INTO v_product_type_id;
        v_created_count := v_created_count + 1;
        RAISE NOTICE '   ✅ Created ProductType: Window Film (ID: %)', v_product_type_id;
    ELSE
        UPDATE "ProductTypes"
        SET name = 'Window Film', updated_at = NOW()
        WHERE id = v_product_type_id AND name != 'Window Film';
        
        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '   ✅ Updated ProductType: Window Film (ID: %)', v_product_type_id;
        ELSE
            RAISE NOTICE '   ℹ️  ProductType already exists: Window Film (ID: %)', v_product_type_id;
        END IF;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'STEP 2: Processing CatalogItems with multiple family values (comma-separated)...';
    RAISE NOTICE '';
    
    -- First, handle CatalogItems with multiple family values separated by commas
    -- This creates multiple relations in CatalogItemProductTypes
    FOR v_catalog_item_rec IN
        SELECT 
            ci.id,
            ci.sku,
            ci.family,
            -- Extract first family value as primary
            TRIM(SPLIT_PART(ci.family, ',', 1)) AS primary_family
        FROM "CatalogItems" ci
        WHERE ci.organization_id = v_org_id
          AND ci.deleted = false
          AND ci.family IS NOT NULL
          AND ci.family != ''
          AND ci.family LIKE '%,%'  -- Has comma (multiple values)
    LOOP
        RAISE NOTICE '   Processing SKU: % (Family: %)', v_catalog_item_rec.sku, v_catalog_item_rec.family;
        
        -- Extract primary family (first value)
        v_primary_family := TRIM(SPLIT_PART(v_catalog_item_rec.family, ',', 1));
        
        -- Split family string into array
        v_family_array := string_to_array(v_catalog_item_rec.family, ',');
        
        -- Process each family value
        FOREACH v_family_value IN ARRAY v_family_array
        LOOP
            v_family_value := TRIM(v_family_value);
            
            IF v_family_value = '' THEN
                CONTINUE;  -- Skip empty values
            END IF;
            
            -- Find matching ProductType (try exact match first, then case-insensitive, then partial)
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE organization_id = v_org_id
              AND deleted = false
              AND (
                name = v_family_value
                OR LOWER(TRIM(name)) = LOWER(v_family_value)
                OR name ILIKE '%' || v_family_value || '%'
                OR v_family_value ILIKE '%' || name || '%'
              )
            ORDER BY 
              CASE 
                WHEN name = v_family_value THEN 1
                WHEN LOWER(TRIM(name)) = LOWER(v_family_value) THEN 2
                ELSE 3
              END
            LIMIT 1;
            
            IF v_product_type_id IS NOT NULL THEN
                -- Check if relation already exists
                IF NOT EXISTS (
                    SELECT 1 FROM "CatalogItemProductTypes"
                    WHERE catalog_item_id = v_catalog_item_rec.id
                      AND product_type_id = v_product_type_id
                      AND organization_id = v_org_id
                      AND deleted = false
                ) THEN
                    -- Mark as primary if it's the first value
                    v_is_primary := (v_family_value = v_primary_family);
                    
                    -- Create relation
                    INSERT INTO "CatalogItemProductTypes" (
                        catalog_item_id,
                        product_type_id,
                        organization_id,
                        is_primary,
                        deleted,
                        created_at,
                        updated_at
                    )
                    VALUES (
                        v_catalog_item_rec.id,
                        v_product_type_id,
                        v_org_id,
                        v_is_primary,
                        false,
                        NOW(),
                        NOW()
                    )
                    ON CONFLICT (catalog_item_id, product_type_id, organization_id) DO NOTHING;
                    
                    v_relation_count := v_relation_count + 1;
                    RAISE NOTICE '     ✅ Linked to ProductType: % (Primary: %)', 
                        (SELECT name FROM "ProductTypes" WHERE id = v_product_type_id),
                        v_is_primary;
                END IF;
            ELSE
                RAISE NOTICE '     ⚠️  No ProductType found for: %', v_family_value;
            END IF;
        END LOOP;
        
        -- Normalize family column: keep only the primary (first) value
        UPDATE "CatalogItems"
        SET family = v_primary_family,
            updated_at = NOW()
        WHERE id = v_catalog_item_rec.id
          AND family != v_primary_family;
        
        IF FOUND THEN
            RAISE NOTICE '     ✅ Normalized family column to: %', v_primary_family;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'STEP 3: Ensuring CatalogItems with single family values are properly related...';
    RAISE NOTICE '';
    
    -- For each ProductType, ensure CatalogItems with matching single family value are related
    FOR v_product_type_rec IN
        SELECT id, name
        FROM "ProductTypes"
        WHERE organization_id = v_org_id
          AND deleted = false
          AND name IN ('Roller Shade', 'Dual Shade', 'Triple Shade', 'Drapery', 'Awning', 'Window Film')
    LOOP
        RAISE NOTICE '   Processing ProductType: % (ID: %)', v_product_type_rec.name, v_product_type_rec.id;
        
        -- Find CatalogItems with matching family that don't have a relation
        -- Also handle case-insensitive and partial matches
        FOR v_catalog_item_rec IN
            SELECT ci.id, ci.sku, ci.family
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cpt 
                ON ci.id = cpt.catalog_item_id 
                AND cpt.product_type_id = v_product_type_rec.id
                AND cpt.organization_id = v_org_id
                AND cpt.deleted = false
            WHERE ci.organization_id = v_org_id
              AND ci.deleted = false
              AND ci.family IS NOT NULL
              AND ci.family != ''
              AND ci.family NOT LIKE '%,%'  -- Single value only (no comma)
              AND (
                ci.family = v_product_type_rec.name
                OR LOWER(TRIM(ci.family)) = LOWER(v_product_type_rec.name)
                OR ci.family ILIKE '%' || v_product_type_rec.name || '%'
                OR v_product_type_rec.name ILIKE '%' || ci.family || '%'
              )
              AND cpt.id IS NULL
        LOOP
            -- Create relation
            INSERT INTO "CatalogItemProductTypes" (
                catalog_item_id,
                product_type_id,
                organization_id,
                is_primary,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                v_catalog_item_rec.id,
                v_product_type_rec.id,
                v_org_id,
                true, -- Mark as primary
                false,
                NOW(),
                NOW()
            )
            ON CONFLICT (catalog_item_id, product_type_id, organization_id) DO NOTHING;
            
            IF FOUND THEN
                v_relation_count := v_relation_count + 1;
                RAISE NOTICE '     ✅ Linked SKU: % (Family: %)', v_catalog_item_rec.sku, v_catalog_item_rec.family;
            END IF;
            
            -- Normalize family column to exact ProductType name if different
            IF v_catalog_item_rec.family != v_product_type_rec.name THEN
                UPDATE "CatalogItems"
                SET family = v_product_type_rec.name,
                    updated_at = NOW()
                WHERE id = v_catalog_item_rec.id;
                
                IF FOUND THEN
                    RAISE NOTICE '     ✅ Normalized family: "%" → "%"', 
                        v_catalog_item_rec.family, 
                        v_product_type_rec.name;
                END IF;
            END IF;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '   ProductTypes created: %', v_created_count;
    RAISE NOTICE '   ProductTypes updated: %', v_updated_count;
    RAISE NOTICE '   Relations created: %', v_relation_count;
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 127 complete';
    RAISE NOTICE '====================================================';
END $$;

