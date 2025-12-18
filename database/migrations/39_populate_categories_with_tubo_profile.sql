-- ====================================================
-- POBLAR ItemCategories CON ESTRUCTURA CORRECTA
-- ====================================================
-- Estructura final:
-- - Fabric (hoja, sin padre)
-- - Window Film (hoja, sin padre)
-- - Components (padre)
--   - Tubo and Profile (padre intermedio)
--     - Tube
--     - Cassette
--     - Bottom Bar
--     - Side Channel
--   - Brackets (hijo directo)
-- - Drives & Controls (padre) → 3 hijos
-- - Accessories (padre) → 3 hijos
-- ====================================================

DO $$
DECLARE
  v_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
  comp_parent_id uuid;
  tubo_profile_parent_id uuid;
  motor_parent_id uuid;
  acc_parent_id uuid;
BEGIN
  RAISE NOTICE 'Creando categorías para organización: %', v_org_id;

  -- ====================================================
  -- 1. CREAR CATEGORÍAS HOJA (sin padre, sin subcategorías)
  -- ====================================================
  
  -- Fabric
  INSERT INTO public."ItemCategories" (
    organization_id,
    name,
    code,
    is_group,
    parent_category_id,
    sort_order,
    deleted,
    archived,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    'Fabric',
    'FABRIC',
    false,
    NULL,
    1,
    false,
    false,
    NOW(),
    NOW()
  );

  -- Window Film
  INSERT INTO public."ItemCategories" (
    organization_id,
    name,
    code,
    is_group,
    parent_category_id,
    sort_order,
    deleted,
    archived,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    'Window Film',
    'WINDOW-FILM',
    false,
    NULL,
    2,
    false,
    false,
    NOW(),
    NOW()
  );

  -- ====================================================
  -- 2. CREAR CATEGORÍAS PADRE (is_group=true)
  -- ====================================================
  
  -- Components
  INSERT INTO public."ItemCategories" (
    organization_id,
    name,
    code,
    is_group,
    parent_category_id,
    sort_order,
    deleted,
    archived,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    'Components',
    'COMP',
    true,
    NULL,
    3,
    false,
    false,
    NOW(),
    NOW()
  ) RETURNING id INTO comp_parent_id;

  -- Drives & Controls
  INSERT INTO public."ItemCategories" (
    organization_id,
    name,
    code,
    is_group,
    parent_category_id,
    sort_order,
    deleted,
    archived,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    'Drives & Controls',
    'MOTOR',
    true,
    NULL,
    4,
    false,
    false,
    NOW(),
    NOW()
  ) RETURNING id INTO motor_parent_id;

  -- Accessories
  INSERT INTO public."ItemCategories" (
    organization_id,
    name,
    code,
    is_group,
    parent_category_id,
    sort_order,
    deleted,
    archived,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    'Accessories',
    'ACC',
    true,
    NULL,
    5,
    false,
    false,
    NOW(),
    NOW()
  ) RETURNING id INTO acc_parent_id;

  -- ====================================================
  -- 3. CREAR "Tubo and Profile" COMO PADRE INTERMEDIO
  -- ====================================================
  INSERT INTO public."ItemCategories" (
    organization_id,
    name,
    code,
    is_group,
    parent_category_id,
    sort_order,
    deleted,
    archived,
    created_at,
    updated_at
  ) VALUES (
    v_org_id,
    'Tubo and Profile',
    'COMP-TUBO-PROFILE',
    true,  -- ES grupo/padre
    comp_parent_id,  -- Padre es Components
    1,
    false,
    false,
    NOW(),
    NOW()
  ) RETURNING id INTO tubo_profile_parent_id;

  -- ====================================================
  -- 4. CREAR SUBCATEGORÍAS DE TUBO AND PROFILE
  -- ====================================================
  INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) VALUES
    (v_org_id, 'Tube', 'COMP-TUBE', false, tubo_profile_parent_id, 1, false, false, NOW(), NOW()),
    (v_org_id, 'Cassette', 'COMP-CASSETTE', false, tubo_profile_parent_id, 2, false, false, NOW(), NOW()),
    (v_org_id, 'Bottom Bar', 'COMP-BOTTOM', false, tubo_profile_parent_id, 3, false, false, NOW(), NOW()),
    (v_org_id, 'Side Channel', 'COMP-SIDE', false, tubo_profile_parent_id, 4, false, false, NOW(), NOW());

  -- ====================================================
  -- 5. CREAR BRACKETS COMO HIJO DIRECTO DE COMPONENTS
  -- ====================================================
  INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) VALUES
    (v_org_id, 'Brackets', 'COMP-BRACKET', false, comp_parent_id, 2, false, false, NOW(), NOW());

  -- ====================================================
  -- 6. CREAR SUBCATEGORÍAS DE DRIVES & CONTROLS
  -- ====================================================
  INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) VALUES
    (v_org_id, 'Manual Drives', 'MOTOR-MANUAL', false, motor_parent_id, 1, false, false, NOW(), NOW()),
    (v_org_id, 'Motorized Drives', 'MOTOR-MOTORIZED', false, motor_parent_id, 2, false, false, NOW(), NOW()),
    (v_org_id, 'Controls', 'MOTOR-CONTROL', false, motor_parent_id, 3, false, false, NOW(), NOW());

  -- ====================================================
  -- 7. CREAR SUBCATEGORÍAS DE ACCESSORIES
  -- ====================================================
  INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) VALUES
    (v_org_id, 'Remotes', 'ACC-REMOTE', false, acc_parent_id, 1, false, false, NOW(), NOW()),
    (v_org_id, 'Batteries', 'ACC-BATTERY', false, acc_parent_id, 2, false, false, NOW(), NOW()),
    (v_org_id, 'Sensors', 'ACC-SENSOR', false, acc_parent_id, 3, false, false, NOW(), NOW());

  RAISE NOTICE '✅ Categorías creadas exitosamente';
  RAISE NOTICE '   - Fabric (hoja)';
  RAISE NOTICE '   - Window Film (hoja)';
  RAISE NOTICE '   - Components (padre)';
  RAISE NOTICE '     └─ Tubo and Profile (padre intermedio) → 4 hijos';
  RAISE NOTICE '     └─ Brackets (hijo directo)';
  RAISE NOTICE '   - Drives & Controls (padre) → 3 hijos';
  RAISE NOTICE '   - Accessories (padre) → 3 hijos';
  RAISE NOTICE '   Total: 16 categorías';
END $$;

-- Verificar resultado
SELECT 
  CASE 
    WHEN is_group = true THEN '📁 ' || name || ' (Padre)'
    WHEN parent_category_id IS NULL THEN '📄 ' || name || ' (Hoja)'
    ELSE '  └─ ' || name || ' (Hijo)'
  END as estructura,
  code,
  is_group,
  (SELECT name FROM public."ItemCategories" p WHERE p.id = c.parent_category_id) as parent_name
FROM public."ItemCategories" c
WHERE deleted = false
ORDER BY 
  is_group DESC,
  parent_category_id NULLS FIRST,
  sort_order,
  name;

