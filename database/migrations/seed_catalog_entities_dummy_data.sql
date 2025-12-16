-- ====================================================
-- Seed Dummy Data for Catalog Entities
-- ====================================================
-- NOTE: This script checks if tables exist before inserting
-- If tables don't exist, it will skip them gracefully
-- ====================================================
-- Automatically uses the first organization_id from "Organizations"
-- ====================================================

DO $$
DECLARE
    org_id uuid;
    fabrics_id uuid;
    components_id uuid;
    motors_id uuid;
    accessories_id uuid;
    ess3000_id uuid;
    sunset_id uuid;
    solar_id uuid;
    table_exists boolean;
BEGIN
    -- Get the first organization
    SELECT id INTO org_id FROM "Organizations" LIMIT 1;
    
    IF org_id IS NULL THEN
        RAISE EXCEPTION 'No organization found. Please create an organization first.';
    END IF;

    RAISE NOTICE 'Using organization_id: %', org_id;

    -- ====================================================
    -- STEP 1: Insert Manufacturers (if table exists)
    -- ====================================================
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Manufacturers'
    ) INTO table_exists;

    IF table_exists THEN
        INSERT INTO "Manufacturers" (organization_id, name, code, notes, deleted, archived)
        VALUES
            (org_id, 'Coulisse', 'COU', 'Coulisse - Leading manufacturer of window coverings', false, false),
            (org_id, 'Vertilux', 'VER', 'Vertilux - Premium window solutions', false, false),
            (org_id, 'Lutron', 'LUT', 'Lutron - Smart lighting and shading controls', false, false),
            (org_id, 'Motion Blinds', 'MOT', 'Motion Blinds - Motorized window coverings', false, false)
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Inserted Manufacturers';
    ELSE
        RAISE NOTICE '⏭️  Manufacturers table does not exist, skipping...';
    END IF;

    -- ====================================================
    -- STEP 2: Insert ItemCategories (if table exists)
    -- ====================================================
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'ItemCategories'
    ) INTO table_exists;

    IF table_exists THEN
        -- Insert root categories
        INSERT INTO "ItemCategories" (organization_id, parent_id, name, code, sort_order, deleted, archived)
        VALUES
            (org_id, NULL, 'Fabrics', 'FAB', 1, false, false),
            (org_id, NULL, 'Components', 'COMP', 2, false, false),
            (org_id, NULL, 'Motors & Controls', 'MOTOR', 3, false, false),
            (org_id, NULL, 'Accessories', 'ACC', 4, false, false)
        ON CONFLICT DO NOTHING;

        -- Get the inserted category IDs
        SELECT id INTO fabrics_id FROM "ItemCategories" 
        WHERE organization_id = org_id AND name = 'Fabrics' AND deleted = false LIMIT 1;
        
        SELECT id INTO components_id FROM "ItemCategories" 
        WHERE organization_id = org_id AND name = 'Components' AND deleted = false LIMIT 1;
        
        SELECT id INTO motors_id FROM "ItemCategories" 
        WHERE organization_id = org_id AND name = 'Motors & Controls' AND deleted = false LIMIT 1;
        
        SELECT id INTO accessories_id FROM "ItemCategories" 
        WHERE organization_id = org_id AND name = 'Accessories' AND deleted = false LIMIT 1;

        -- Insert subcategories for Fabrics
        IF fabrics_id IS NOT NULL THEN
            INSERT INTO "ItemCategories" (organization_id, parent_id, name, code, sort_order, deleted, archived)
            VALUES
                (org_id, fabrics_id, 'Roller Shade Fabrics', 'FAB-ROLLER', 1, false, false),
                (org_id, fabrics_id, 'Drapery Fabrics', 'FAB-DRAPERY', 2, false, false),
                (org_id, fabrics_id, 'Window Film', 'FAB-FILM', 3, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Insert subcategories for Components
        IF components_id IS NOT NULL THEN
            INSERT INTO "ItemCategories" (organization_id, parent_id, name, code, sort_order, deleted, archived)
            VALUES
                (org_id, components_id, 'Tubes & Cassettes', 'COMP-TUBE', 1, false, false),
                (org_id, components_id, 'Bottom Bars', 'COMP-BOTTOM', 2, false, false),
                (org_id, components_id, 'Side Channels', 'COMP-SIDE', 3, false, false),
                (org_id, components_id, 'Brackets', 'COMP-BRACKET', 4, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Insert subcategories for Motors & Controls
        IF motors_id IS NOT NULL THEN
            INSERT INTO "ItemCategories" (organization_id, parent_id, name, code, sort_order, deleted, archived)
            VALUES
                (org_id, motors_id, 'Manual Drives', 'MOTOR-MANUAL', 1, false, false),
                (org_id, motors_id, 'Motorized Drives', 'MOTOR-MOTORIZED', 2, false, false),
                (org_id, motors_id, 'Controls', 'MOTOR-CONTROL', 3, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Insert subcategories for Accessories
        IF accessories_id IS NOT NULL THEN
            INSERT INTO "ItemCategories" (organization_id, parent_id, name, code, sort_order, deleted, archived)
            VALUES
                (org_id, accessories_id, 'Remotes', 'ACC-REMOTE', 1, false, false),
                (org_id, accessories_id, 'Sensors', 'ACC-SENSOR', 2, false, false),
                (org_id, accessories_id, 'Batteries', 'ACC-BATTERY', 3, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        RAISE NOTICE '✅ Inserted ItemCategories';
    ELSE
        RAISE NOTICE '⏭️  ItemCategories table does not exist, skipping...';
    END IF;

    -- ====================================================
    -- STEP 3: Insert CatalogCollections (if table exists)
    -- ====================================================
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogCollections'
    ) INTO table_exists;

    IF table_exists THEN
        INSERT INTO "CatalogCollections" (organization_id, name, code, description, active, sort_order, deleted, archived)
        VALUES
            (org_id, 'Essential 3000', 'ESS3000', 'Essential 3000 collection - Premium roller shade fabrics', true, 1, false, false),
            (org_id, 'Sunset Blackout', 'SUNSET', 'Sunset Blackout collection - Complete light blocking', true, 2, false, false),
            (org_id, 'Solar Screen', 'SOLAR', 'Solar Screen collection - UV protection fabrics', true, 3, false, false)
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Inserted CatalogCollections';
    ELSE
        RAISE NOTICE '⏭️  CatalogCollections table does not exist, skipping...';
    END IF;

    -- ====================================================
    -- STEP 4: Insert CatalogVariants (if table exists)
    -- ====================================================
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogVariants'
    ) INTO table_exists;

    IF table_exists THEN
        -- Get collection IDs
        SELECT id INTO ess3000_id FROM "CatalogCollections" 
        WHERE organization_id = org_id AND name = 'Essential 3000' AND deleted = false LIMIT 1;
        
        SELECT id INTO sunset_id FROM "CatalogCollections" 
        WHERE organization_id = org_id AND name = 'Sunset Blackout' AND deleted = false LIMIT 1;
        
        SELECT id INTO solar_id FROM "CatalogCollections" 
        WHERE organization_id = org_id AND name = 'Solar Screen' AND deleted = false LIMIT 1;

        -- Variants for Essential 3000
        IF ess3000_id IS NOT NULL THEN
            INSERT INTO "CatalogVariants" (organization_id, collection_id, name, code, color_name, active, sort_order, deleted, archived)
            VALUES
                (org_id, ess3000_id, 'Chalk 5%', 'ESS3000-CHALK-5', 'Chalk', true, 1, false, false),
                (org_id, ess3000_id, 'Ivory 3%', 'ESS3000-IVORY-3', 'Ivory', true, 2, false, false),
                (org_id, ess3000_id, 'White 1%', 'ESS3000-WHITE-1', 'White', true, 3, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Variants for Sunset Blackout
        IF sunset_id IS NOT NULL THEN
            INSERT INTO "CatalogVariants" (organization_id, collection_id, name, code, color_name, active, sort_order, deleted, archived)
            VALUES
                (org_id, sunset_id, 'Ivory 118.11', 'SUNSET-IVORY-118', 'Ivory', true, 1, false, false),
                (org_id, sunset_id, 'White 118.11', 'SUNSET-WHITE-118', 'White', true, 2, false, false),
                (org_id, sunset_id, 'Beige 118.12', 'SUNSET-BEIGE-118', 'Beige', true, 3, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Variants for Solar Screen
        IF solar_id IS NOT NULL THEN
            INSERT INTO "CatalogVariants" (organization_id, collection_id, name, code, color_name, active, sort_order, deleted, archived)
            VALUES
                (org_id, solar_id, 'Charcoal 5%', 'SOLAR-CHARCOAL-5', 'Charcoal', true, 1, false, false),
                (org_id, solar_id, 'Taupe 10%', 'SOLAR-TAUPE-10', 'Taupe', true, 2, false, false)
            ON CONFLICT DO NOTHING;
        END IF;

        RAISE NOTICE '✅ Inserted CatalogVariants';
    ELSE
        RAISE NOTICE '⏭️  CatalogVariants table does not exist, skipping...';
    END IF;

    RAISE NOTICE '✅ Seed script completed!';

END $$;

