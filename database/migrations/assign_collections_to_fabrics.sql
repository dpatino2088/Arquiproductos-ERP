-- ====================================================
-- Assign Collections to Fabric Items
-- Generated from: catalog_items_import_DP.csv
-- Organization ID: 4de856e8-36ce-480a-952b-a2f5083c69d6
-- ====================================================

DO $$
DECLARE
    org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    collection_id_var uuid;
    collection_name_var text;
    sku_var text;
    updated_count int := 0;
BEGIN

    -- Collection: BLOCK (4 fabrics)
    collection_name_var := 'BLOCK';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-BLOCK-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-BLOCK-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-BLOCK-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-BLOCK-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: FIJI (5 fabrics)
    collection_name_var := 'FIJI';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-FIJI-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-FIJI-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-FIJI-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-FIJI-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-FIJI-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: HONEY (4 fabrics)
    collection_name_var := 'HONEY';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-HONEY-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HONEY-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HONEY-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HONEY-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: HYDRA (6 fabrics)
    collection_name_var := 'HYDRA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-HYDRA-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HYDRA-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HYDRA-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HYDRA-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HYDRA-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-HYDRA-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: IKARIA (6 fabrics)
    collection_name_var := 'IKARIA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-IKARIA-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-IKARIA-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-IKARIA-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-IKARIA-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-IKARIA-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-IKARIA-0900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: MADAGASCAR (4 fabrics)
    collection_name_var := 'MADAGASCAR';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-MADAGASCAR-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-MADAGASCAR-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-MADAGASCAR-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-MADAGASCAR-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: NAXOS (4 fabrics)
    collection_name_var := 'NAXOS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-NAXOS-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-NAXOS-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-NAXOS-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-NAXOS-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: PARGA (3 fabrics)
    collection_name_var := 'PARGA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-PARGA-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-PARGA-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-PARGA-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: POROS (4 fabrics)
    collection_name_var := 'POROS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-POROS-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-POROS-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-POROS-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-POROS-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: SAMOS (4 fabrics)
    collection_name_var := 'SAMOS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-SAMOS-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SAMOS-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SAMOS-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SAMOS-0900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: SKYROS (6 fabrics)
    collection_name_var := 'SKYROS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-SKYROS-S-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SKYROS-S-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SKYROS-S-1400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SKYROS-S-1600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SKYROS-S-1700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SKYROS-S-2300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: SPETSES (5 fabrics)
    collection_name_var := 'SPETSES';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-SPETSES-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SPETSES-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SPETSES-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SPETSES-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-SPETSES-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: THASOS (4 fabrics)
    collection_name_var := 'THASOS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-THASOS-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-THASOS-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-THASOS-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-THASOS-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: ZAKYNTHOS (11 fabrics)
    collection_name_var := 'ZAKYNTHOS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'DRF-ZAKYNTHOS-01-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-02-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-04-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-05-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-07-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-08-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-09-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-10-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-11-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-12-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'DRF-ZAKYNTHOS-20-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: BALI (4 fabrics)
    collection_name_var := 'BALI';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-BALI-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BALI-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BALI-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BALI-0800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: BASIC (18 fabrics)
    collection_name_var := 'BASIC';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-BASIC-BO-01-183-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-01-244-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-01-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-02-183-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-02-244-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-02-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-03-183-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-03-244-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-03-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-04-183-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-04-244-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-04-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-05-183-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-05-244-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-05-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-06-183-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-06-244-N';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BASIC-BO-06-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: BEIJING (1 fabrics)
    collection_name_var := 'BEIJING';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-BEIJING-01-240';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: BERLIN (26 fabrics)
    collection_name_var := 'BERLIN';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-BERLIN-0100-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0120-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0220-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0300-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0500-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0540-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0600-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0610-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-0800-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-1000-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-1200-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-1300-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-1320-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5100-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5120-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5220-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5300-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5500-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5540-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5600-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5610-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5800-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-5900-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-6000-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-6300-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BERLIN-6320-250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: BOMBAY (6 fabrics)
    collection_name_var := 'BOMBAY';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-BOMBAY-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BOMBAY-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BOMBAY-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BOMBAY-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BOMBAY-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BOMBAY-0800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: BRASILIA (4 fabrics)
    collection_name_var := 'BRASILIA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-BRASILIA-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BRASILIA-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BRASILIA-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-BRASILIA-0800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: COMO (6 fabrics)
    collection_name_var := 'COMO';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-COMO-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-COMO-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-COMO-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-COMO-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-COMO-5700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-COMO-5800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: DARWIN (6 fabrics)
    collection_name_var := 'DARWIN';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-DARWIN-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DARWIN-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DARWIN-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DARWIN-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DARWIN-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DARWIN-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: DURBAN (4 fabrics)
    collection_name_var := 'DURBAN';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-DURBAN-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DURBAN-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DURBAN-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-DURBAN-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: EKO50 (9 fabrics)
    collection_name_var := 'EKO50';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-EKO50-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-1900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-2000';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-2100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-2200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-2300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-EKO50-2400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: ESVEDRA (8 fabrics)
    collection_name_var := 'ESVEDRA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-ESVEDRA-0100-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-0200-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-3000-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-3200-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-3300-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-3400-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-3500-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-ESVEDRA-3600-280';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: GUNSANG (1 fabrics)
    collection_name_var := 'GUNSANG';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-GUNSANG-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: GUNSANGSPNGL (1 fabrics)
    collection_name_var := 'GUNSANGSPNGL';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-GUNSANGSPNGL-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: HAMPTON (12 fabrics)
    collection_name_var := 'HAMPTON';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-HAMPTON-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-0150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-5150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HAMPTON-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: HONGKONG (1 fabrics)
    collection_name_var := 'HONGKONG';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-HONGKONG-01';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: HUEVA (5 fabrics)
    collection_name_var := 'HUEVA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-HUEVA-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HUEVA-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HUEVA-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HUEVA-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-HUEVA-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: JA21001 (4 fabrics)
    collection_name_var := 'JA21001';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-JA21001-001';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA21001-002';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA21001-003';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA21001-004';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: JA (5 fabrics)
    collection_name_var := 'JA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-JA-ARETHA-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA-ARETHA-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA-ARETHA-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA-ARETHA-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JA-ARETHA-0800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: JINJU (3 fabrics)
    collection_name_var := 'JINJU';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-JINJU-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JINJU-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-JINJU-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: LISBOA (5 fabrics)
    collection_name_var := 'LISBOA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-LISBOA-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-LISBOA-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-LISBOA-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-LISBOA-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-LISBOA-5700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: MELBOURNE (8 fabrics)
    collection_name_var := 'MELBOURNE';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-MELBOURNE-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MELBOURNE-0900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: MEXICO (4 fabrics)
    collection_name_var := 'MEXICO';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-MEXICO-5102';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MEXICO-5105';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MEXICO-5106';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MEXICO-5107';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: MIAMI (7 fabrics)
    collection_name_var := 'MIAMI';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-MIAMI-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MIAMI-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MIAMI-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MIAMI-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MIAMI-6000';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MIAMI-6100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MIAMI-6200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: MOMBASSA (14 fabrics)
    collection_name_var := 'MOMBASSA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-MOMBASSA-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-0150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MOMBASSA-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: MUENCHEN (32 fabrics)
    collection_name_var := 'MUENCHEN';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-MUENCHEN-0150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-0150-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-0301';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-0301-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-0401';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-0401-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-1002';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-1002-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-2700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-2700-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-4301';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-4301-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-4400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-4400-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-4601';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-4601-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-5001';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-5001-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-5300-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-5401';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-5401-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-6250';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-6250-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-6301';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-6301-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-6400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-6400-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-7600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-7600-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-7700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-MUENCHEN-7700-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: NATAL (14 fabrics)
    collection_name_var := 'NATAL';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-NATAL-0150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-0900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5150';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-NATAL-5900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: OSAKA (3 fabrics)
    collection_name_var := 'OSAKA';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-OSAKA-0100-185';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-OSAKA-0300-185';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-OSAKA-0400-185';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: PAP2 (1 fabrics)
    collection_name_var := 'PAP2';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-PAP2-240';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: PAP3 (1 fabrics)
    collection_name_var := 'PAP3';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-PAP3-240';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: PAP7 (1 fabrics)
    collection_name_var := 'PAP7';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-PAP7-240';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: PARIS (8 fabrics)
    collection_name_var := 'PARIS';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-PARIS-0100-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-0150-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-0400-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-3300-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-3400-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-3500-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-3800-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PARIS-4200-300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: PR180660 (3 fabrics)
    collection_name_var := 'PR180660';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-PR180660-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PR180660-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-PR180660-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: RICHMOND (7 fabrics)
    collection_name_var := 'RICHMOND';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-RICHMOND-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-RICHMOND-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-RICHMOND-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-RICHMOND-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-RICHMOND-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-RICHMOND-0900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-RICHMOND-1000';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: SAIGON (4 fabrics)
    collection_name_var := 'SAIGON';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-SAIGON-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SAIGON-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SAIGON-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SAIGON-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: SALVADOR (9 fabrics)
    collection_name_var := 'SALVADOR';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-SALVADOR-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-0800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-1100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-1300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SALVADOR-1400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: SANTIAGO (8 fabrics)
    collection_name_var := 'SANTIAGO';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-SANTIAGO-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-5200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-5300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-5700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-5800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-SANTIAGO-6000';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: TOKIO (4 fabrics)
    collection_name_var := 'TOKIO';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-TOKIO-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-TOKIO-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-TOKIO-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-TOKIO-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: TOULOUSE (2 fabrics)
    collection_name_var := 'TOULOUSE';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-TOULOUSE-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-TOULOUSE-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: UBUD (8 fabrics)
    collection_name_var := 'UBUD';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-UBUD-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-0400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-0600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-UBUD-1200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: WELLINGTON (6 fabrics)
    collection_name_var := 'WELLINGTON';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-WELLINGTON-5100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WELLINGTON-5400';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WELLINGTON-5500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WELLINGTON-5600';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WELLINGTON-5700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WELLINGTON-5800';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    -- Collection: WINCHESTER (7 fabrics)
    collection_name_var := 'WINCHESTER';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "Collections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "Collections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics

    sku_var := 'RF-WINCHESTER-0100';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WINCHESTER-0200';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WINCHESTER-0300';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WINCHESTER-0500';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WINCHESTER-0700';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WINCHESTER-0900';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    sku_var := 'RF-WINCHESTER-1000';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;

    RAISE NOTICE 'Total fabrics updated: %', updated_count;
END $$;

-- Verify results
SELECT 
    c.name AS collection_name,
    COUNT(ci.id) AS fabric_count
FROM "Collections" c
LEFT JOIN "CatalogItems" ci ON ci.collection_id = c.id AND ci.item_type = 'fabric' AND ci.deleted = false
WHERE c.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND c.deleted = false
GROUP BY c.id, c.name
ORDER BY c.name;
