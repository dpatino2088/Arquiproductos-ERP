-- ====================================================
-- Migration: Create BOMTemplates for Roller Shade, Dual Shade, Triple Shade
-- ====================================================
-- This creates 6 BOMTemplates (White and Black versions for each product type)
-- with the following components:
-- - Fabric (No SKU, uses width and height from MeasurementsStep)
-- - SystemDrives Manual/Motorizado (1 per curtain)
-- - Brackets (2 units per curtain)
-- - Bottom_bar (per linear meter, uses width from MeasurementsStep)
-- - Tube (per linear meter, uses width from MeasurementsStep)
-- - End Caps (2 units per curtain)
-- - Brackets End Cap (2 per curtain)
-- - Screw End Cap (2 per curtain)
-- ====================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN
  -- ====================================================
  -- STEP 0: Ensure BOMComponents has required columns
  -- ====================================================
  RAISE NOTICE 'STEP 0: Checking BOMComponents structure...';
  
  -- Check if component_role column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'component_role'
  ) INTO col_exists;
  
  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN component_role text;
    RAISE NOTICE '  ✅ Added component_role column to BOMComponents';
  ELSE
    RAISE NOTICE '  ℹ️  component_role column already exists';
  END IF;
  
  -- Check if auto_select column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'auto_select'
  ) INTO col_exists;
  
  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN auto_select boolean NOT NULL DEFAULT false;
    RAISE NOTICE '  ✅ Added auto_select column to BOMComponents';
  ELSE
    RAISE NOTICE '  ℹ️  auto_select column already exists';
  END IF;
  
  -- Clean existing data: set invalid component_role values to NULL
  UPDATE public."BOMComponents"
  SET component_role = NULL
  WHERE component_role IS NOT NULL
    AND component_role NOT IN (
      'fabric',
      'tube',
      'bracket',
      'cassette',
      'bottom_bar',
      'operating_system_drive'
    );
  RAISE NOTICE '  ✅ Cleaned invalid component_role values (set to NULL)';
  
  -- Check if check constraint exists and update it if needed
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_schema = 'public' 
    AND constraint_name = 'check_bomcomponents_role_valid'
  ) THEN
    -- Drop existing constraint to update it
    ALTER TABLE public."BOMComponents"
      DROP CONSTRAINT IF EXISTS check_bomcomponents_role_valid;
    RAISE NOTICE '  ℹ️  Dropped existing check_bomcomponents_role_valid constraint';
  END IF;
  
  -- Add or recreate constraint with all valid component roles
  ALTER TABLE public."BOMComponents"
    ADD CONSTRAINT check_bomcomponents_role_valid 
    CHECK (
      component_role IS NULL 
      OR component_role IN (
        'fabric',           -- Fabric/tela
        'tube',             -- Tube/tubo
        'bracket',          -- Bracket/soporte
        'cassette',         -- Cassette
        'bottom_bar',       -- Bottom bar/barra inferior
        'operating_system_drive'  -- Operating system drive (motor/manual)
      )
    );
  RAISE NOTICE '  ✅ Added/updated check_bomcomponents_role_valid constraint';
  
  RAISE NOTICE '';
END $$;

DO $$
DECLARE
  v_org_id UUID := '4de856e8-36ce-480a-952b-a2f5083c69d6'::UUID;
  v_roller_shade_id UUID;
  v_dual_shade_id UUID;
  v_triple_shade_id UUID;
  v_bom_template_id UUID;
  v_component_id UUID;
  v_sequence_order INTEGER := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Creating BOMTemplates for Shades';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Get ProductType IDs
  -- ====================================================
  RAISE NOTICE 'STEP 1: Getting ProductType IDs...';
  
  -- Get Roller Shade ProductType ID
  SELECT id INTO v_roller_shade_id
  FROM "ProductTypes"
  WHERE organization_id = v_org_id
    AND deleted = false
    AND (name = 'Roller Shade' OR name ILIKE '%roller%shade%')
  LIMIT 1;
  
  IF v_roller_shade_id IS NULL THEN
    RAISE EXCEPTION 'Roller Shade ProductType not found. Please run migration 127 first.';
  END IF;
  RAISE NOTICE '  ✅ Roller Shade ID: %', v_roller_shade_id;
  
  -- Get Dual Shade ProductType ID
  SELECT id INTO v_dual_shade_id
  FROM "ProductTypes"
  WHERE organization_id = v_org_id
    AND deleted = false
    AND (name = 'Dual Shade' OR name ILIKE '%dual%shade%')
  LIMIT 1;
  
  IF v_dual_shade_id IS NULL THEN
    RAISE EXCEPTION 'Dual Shade ProductType not found. Please run migration 127 first.';
  END IF;
  RAISE NOTICE '  ✅ Dual Shade ID: %', v_dual_shade_id;
  
  -- Get Triple Shade ProductType ID
  SELECT id INTO v_triple_shade_id
  FROM "ProductTypes"
  WHERE organization_id = v_org_id
    AND deleted = false
    AND (name = 'Triple Shade' OR name ILIKE '%triple%shade%')
  LIMIT 1;
  
  IF v_triple_shade_id IS NULL THEN
    RAISE EXCEPTION 'Triple Shade ProductType not found. Please run migration 127 first.';
  END IF;
  RAISE NOTICE '  ✅ Triple Shade ID: %', v_triple_shade_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 2: Delete existing BOMTemplates for these product types
  -- ====================================================
  RAISE NOTICE 'STEP 2: Cleaning up existing BOMTemplates...';
  
  UPDATE "BOMTemplates"
  SET deleted = true
  WHERE organization_id = v_org_id
    AND product_type_id IN (v_roller_shade_id, v_dual_shade_id, v_triple_shade_id)
    AND deleted = false;
  
  RAISE NOTICE '  ✅ Marked existing BOMTemplates as deleted';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 3: Create BOMTemplates
  -- ====================================================
  RAISE NOTICE 'STEP 3: Creating BOMTemplates...';
  
  -- Helper function to create BOMTemplate and components
  -- We'll create templates inline for each product type and color
  
  -- ====================================================
  -- 3.1: Roller Shade - White
  -- ====================================================
  INSERT INTO "BOMTemplates" (
    id, organization_id, product_type_id, name, description, active, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_roller_shade_id, 
    'Roller Shade - White', 
    'BOM Template for Roller Shade in White color',
    true, false, NOW(), NOW()
  ) RETURNING id INTO v_bom_template_id;
  RAISE NOTICE '  ✅ Created BOMTemplate: Roller Shade - White (ID: %)', v_bom_template_id;
  
  -- Fabric (No SKU, uses width and height from MeasurementsStep)
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id, 
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'fabric', NULL,
    1, 'sqm', 1, true, false, NOW(), NOW()
  );
  
  -- SystemDrives Manual/Motorizado (1 per curtain) - Will be resolved by operating_system
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'operating_system_drive', NULL,
    1, 'unit', 2, true, false, NOW(), NOW()
  );
  
  -- Brackets (2 units per curtain)
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL,
    2, 'unit', 3, true, false, NOW(), NOW()
  );
  
  -- Bottom_bar (per linear meter, uses width from MeasurementsStep)
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'bottom_bar', NULL,
    1, 'linear_m', 4, true, false, NOW(), NOW()
  );
  
  -- Tube (per linear meter, uses width from MeasurementsStep)
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'tube', NULL,
    1, 'linear_m', 5, true, false, NOW(), NOW()
  );
  
  -- End Caps (2 units per curtain)
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'cassette', NULL,
    2, 'unit', 6, true, false, NOW(), NOW()
  );
  
  -- Brackets End Cap (2 per curtain)
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL,
    2, 'unit', 7, true, false, NOW(), NOW()
  );
  
  -- Screw End Cap (2 per curtain) - Using bracket role for now, can be extended later
  INSERT INTO "BOMComponents" (
    id, organization_id, bom_template_id, component_role, component_item_id,
    qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL,
    2, 'unit', 8, true, false, NOW(), NOW()
  );
  
  RAISE NOTICE '    ✅ Created 8 BOMComponents for Roller Shade - White';
  
  -- ====================================================
  -- 3.2: Roller Shade - Black
  -- ====================================================
  INSERT INTO "BOMTemplates" (
    id, organization_id, product_type_id, name, description, active, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_roller_shade_id, 
    'Roller Shade - Black', 
    'BOM Template for Roller Shade in Black color',
    true, false, NOW(), NOW()
  ) RETURNING id INTO v_bom_template_id;
  RAISE NOTICE '  ✅ Created BOMTemplate: Roller Shade - Black (ID: %)', v_bom_template_id;
  
  -- Same components as White (we'll use the same structure)
  INSERT INTO "BOMComponents" (id, organization_id, bom_template_id, component_role, component_item_id, qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at) VALUES
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'fabric', NULL, 1, 'sqm', 1, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'operating_system_drive', NULL, 1, 'unit', 2, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 3, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bottom_bar', NULL, 1, 'linear_m', 4, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'tube', NULL, 1, 'linear_m', 5, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'cassette', NULL, 2, 'unit', 6, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 7, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 8, true, false, NOW(), NOW());
  
  RAISE NOTICE '    ✅ Created 8 BOMComponents for Roller Shade - Black';
  
  -- ====================================================
  -- 3.3: Dual Shade - White
  -- ====================================================
  INSERT INTO "BOMTemplates" (
    id, organization_id, product_type_id, name, description, active, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_dual_shade_id, 
    'Dual Shade - White', 
    'BOM Template for Dual Shade in White color',
    true, false, NOW(), NOW()
  ) RETURNING id INTO v_bom_template_id;
  RAISE NOTICE '  ✅ Created BOMTemplate: Dual Shade - White (ID: %)', v_bom_template_id;
  
  INSERT INTO "BOMComponents" (id, organization_id, bom_template_id, component_role, component_item_id, qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at) VALUES
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'fabric', NULL, 1, 'sqm', 1, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'operating_system_drive', NULL, 1, 'unit', 2, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 3, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bottom_bar', NULL, 1, 'linear_m', 4, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'tube', NULL, 1, 'linear_m', 5, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'cassette', NULL, 2, 'unit', 6, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 7, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 8, true, false, NOW(), NOW());
  
  RAISE NOTICE '    ✅ Created 8 BOMComponents for Dual Shade - White';
  
  -- ====================================================
  -- 3.4: Dual Shade - Black
  -- ====================================================
  INSERT INTO "BOMTemplates" (
    id, organization_id, product_type_id, name, description, active, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_dual_shade_id, 
    'Dual Shade - Black', 
    'BOM Template for Dual Shade in Black color',
    true, false, NOW(), NOW()
  ) RETURNING id INTO v_bom_template_id;
  RAISE NOTICE '  ✅ Created BOMTemplate: Dual Shade - Black (ID: %)', v_bom_template_id;
  
  INSERT INTO "BOMComponents" (id, organization_id, bom_template_id, component_role, component_item_id, qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at) VALUES
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'fabric', NULL, 1, 'sqm', 1, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'operating_system_drive', NULL, 1, 'unit', 2, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 3, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bottom_bar', NULL, 1, 'linear_m', 4, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'tube', NULL, 1, 'linear_m', 5, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'cassette', NULL, 2, 'unit', 6, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 7, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 8, true, false, NOW(), NOW());
  
  RAISE NOTICE '    ✅ Created 8 BOMComponents for Dual Shade - Black';
  
  -- ====================================================
  -- 3.5: Triple Shade - White
  -- ====================================================
  INSERT INTO "BOMTemplates" (
    id, organization_id, product_type_id, name, description, active, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_triple_shade_id, 
    'Triple Shade - White', 
    'BOM Template for Triple Shade in White color',
    true, false, NOW(), NOW()
  ) RETURNING id INTO v_bom_template_id;
  RAISE NOTICE '  ✅ Created BOMTemplate: Triple Shade - White (ID: %)', v_bom_template_id;
  
  INSERT INTO "BOMComponents" (id, organization_id, bom_template_id, component_role, component_item_id, qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at) VALUES
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'fabric', NULL, 1, 'sqm', 1, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'operating_system_drive', NULL, 1, 'unit', 2, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 3, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bottom_bar', NULL, 1, 'linear_m', 4, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'tube', NULL, 1, 'linear_m', 5, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'cassette', NULL, 2, 'unit', 6, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 7, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 8, true, false, NOW(), NOW());
  
  RAISE NOTICE '    ✅ Created 8 BOMComponents for Triple Shade - White';
  
  -- ====================================================
  -- 3.6: Triple Shade - Black
  -- ====================================================
  INSERT INTO "BOMTemplates" (
    id, organization_id, product_type_id, name, description, active, deleted, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_org_id, v_triple_shade_id, 
    'Triple Shade - Black', 
    'BOM Template for Triple Shade in Black color',
    true, false, NOW(), NOW()
  ) RETURNING id INTO v_bom_template_id;
  RAISE NOTICE '  ✅ Created BOMTemplate: Triple Shade - Black (ID: %)', v_bom_template_id;
  
  INSERT INTO "BOMComponents" (id, organization_id, bom_template_id, component_role, component_item_id, qty_per_unit, uom, sequence_order, auto_select, deleted, created_at, updated_at) VALUES
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'fabric', NULL, 1, 'sqm', 1, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'operating_system_drive', NULL, 1, 'unit', 2, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 3, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bottom_bar', NULL, 1, 'linear_m', 4, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'tube', NULL, 1, 'linear_m', 5, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'cassette', NULL, 2, 'unit', 6, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 7, true, false, NOW(), NOW()),
    (gen_random_uuid(), v_org_id, v_bom_template_id, 'bracket', NULL, 2, 'unit', 8, true, false, NOW(), NOW());
  
  RAISE NOTICE '    ✅ Created 8 BOMComponents for Triple Shade - Black';
  RAISE NOTICE '';

  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📝 Created 6 BOMTemplates with 8 components each';
  RAISE NOTICE '   - Roller Shade (White & Black)';
  RAISE NOTICE '   - Dual Shade (White & Black)';
  RAISE NOTICE '   - Triple Shade (White & Black)';
  RAISE NOTICE '========================================';

END $$;

