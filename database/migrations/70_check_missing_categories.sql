-- ====================================================
-- Migration 70: Verificar y Asegurar Categorías Hijas Estrictas
-- ====================================================
-- Verifica que SOLO estas categorías sean hijos activos:
-- - Accessories, Brackets, Cassette, Chains, Controls, Fabrics,
--   Hardware, Motors, Servicio, Side Channel, Tool, Tubo and Profile
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  comp_parent_id uuid;
  acc_parent_id uuid;
  motor_parent_id uuid;
  fab_parent_id uuid;
  tubo_profile_id uuid;
  updated_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Verificación Estricta de Categorías Hijas';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Obtener IDs de categorías padre
  -- ====================================================
  RAISE NOTICE 'PASO 1: Obteniendo IDs de categorías padre...';
  
  SELECT id INTO comp_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'COMP' AND is_group = true AND deleted = false LIMIT 1;
  
  SELECT id INTO acc_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'ACC' AND is_group = true AND deleted = false LIMIT 1;
  
  SELECT id INTO motor_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'MOTOR' AND is_group = true AND deleted = false LIMIT 1;
  
  SELECT id INTO fab_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'FABRIC' AND deleted = false LIMIT 1;
  
  SELECT id INTO tubo_profile_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'COMP-TUBO-PROFILE' AND deleted = false LIMIT 1;
  
  RAISE NOTICE '   ✅ IDs obtenidos';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Verificar qué categorías existen
  -- ====================================================
  RAISE NOTICE 'PASO 2: Verificando categorías existentes...';
  
  DECLARE
    cat_rec RECORD;
    found_categories text[] := ARRAY[]::text[];
  BEGIN
    -- Listar todas las categorías activas
    FOR cat_rec IN
      SELECT name, code, parent_category_id, is_group
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND deleted = false
      ORDER BY code, name
    LOOP
      found_categories := array_append(found_categories, cat_rec.code || ' - ' || cat_rec.name);
      RAISE NOTICE '   - % (code: %, is_group: %, parent: %)', 
        cat_rec.name,
        cat_rec.code,
        cat_rec.is_group,
        COALESCE((SELECT name FROM public."ItemCategories" WHERE id = cat_rec.parent_category_id), 'NULL');
    END LOOP;
    
    RAISE NOTICE '   Total categorías activas encontradas: %', array_length(found_categories, 1);
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 3: Verificar categorías específicas requeridas
  -- ====================================================
  RAISE NOTICE 'PASO 3: Verificando categorías requeridas...';
  
  -- Categorías que DEBEN existir como hijos
  DECLARE
    required_categories text[][] := ARRAY[
      ['COMP-BRACKET', 'Brackets', 'COMP'],
      ['COMP-CASSETTE', 'Cassette', 'COMP-TUBO-PROFILE'],
      ['COMP-SIDE', 'Side Channel', 'COMP-TUBO-PROFILE'],
      ['COMP-BOTTOM', 'Bottom Bar', 'COMP-TUBO-PROFILE'],
      ['COMP-TUBE', 'Tube', 'COMP-TUBO-PROFILE'],
      ['ACC-BATTERY', 'Batteries', 'ACC'],
      ['ACC-REMOTE', 'Remotes', 'ACC'],
      ['ACC-SENSOR', 'Sensors', 'ACC'],
      ['MOTOR-MANUAL', 'Manual Drives', 'MOTOR'],
      ['MOTOR-MOTORIZED', 'Motorized Drives', 'MOTOR'],
      ['MOTOR-CONTROL', 'Controls', 'MOTOR'],
      ['WINDOW-FILM', 'Window Film', 'FABRIC']
    ];
    
    optional_categories text[][] := ARRAY[
      ['COMP-TUBO-PROFILE', 'Tubo and Profile', 'COMP'],
      ['ACC', 'Accessories', NULL],
      ['CHAIN', 'Chains', 'COMP'],
      ['HARDWARE', 'Hardware', 'COMP'],
      ['TOOL', 'Tool', 'ACC'],
      ['SERVICE', 'Servicio', NULL],
      ['FABRIC', 'Fabric', NULL]
    ];
    
    cat_code text;
    cat_name text;
    expected_parent text;
    cat_id uuid;
    parent_id uuid;
    found boolean;
  BEGIN
    -- Verificar categorías requeridas
    RAISE NOTICE '   Categorías REQUERIDAS:';
    FOR i IN 1..array_length(required_categories, 1) LOOP
      cat_code := required_categories[i][1];
      cat_name := required_categories[i][2];
      expected_parent := required_categories[i][3];
      
      SELECT id INTO cat_id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND code = cat_code
        AND deleted = false
      LIMIT 1;
      
      found := (cat_id IS NOT NULL);
      
      IF found THEN
        SELECT parent_category_id INTO parent_id
        FROM public."ItemCategories"
        WHERE id = cat_id;
        
        IF expected_parent = 'COMP' THEN
          IF parent_id = comp_parent_id THEN
            RAISE NOTICE '      ✅ % (code: %) → Components', cat_name, cat_code;
          ELSE
            RAISE WARNING '      ⚠️  % (code: %) tiene padre incorrecto', cat_name, cat_code;
          END IF;
        ELSIF expected_parent = 'COMP-TUBO-PROFILE' THEN
          IF parent_id = tubo_profile_id THEN
            RAISE NOTICE '      ✅ % (code: %) → Tubo and Profile', cat_name, cat_code;
          ELSE
            RAISE WARNING '      ⚠️  % (code: %) tiene padre incorrecto', cat_name, cat_code;
          END IF;
        ELSIF expected_parent = 'ACC' THEN
          IF parent_id = acc_parent_id THEN
            RAISE NOTICE '      ✅ % (code: %) → Accessories', cat_name, cat_code;
          ELSE
            RAISE WARNING '      ⚠️  % (code: %) tiene padre incorrecto', cat_name, cat_code;
          END IF;
        ELSIF expected_parent = 'MOTOR' THEN
          IF parent_id = motor_parent_id THEN
            RAISE NOTICE '      ✅ % (code: %) → Drives & Controls', cat_name, cat_code;
          ELSE
            RAISE WARNING '      ⚠️  % (code: %) tiene padre incorrecto', cat_name, cat_code;
          END IF;
        ELSIF expected_parent = 'FABRIC' THEN
          IF parent_id = fab_parent_id THEN
            RAISE NOTICE '      ✅ % (code: %) → Fabric', cat_name, cat_code;
          ELSE
            RAISE WARNING '      ⚠️  % (code: %) tiene padre incorrecto', cat_name, cat_code;
          END IF;
        END IF;
      ELSE
        RAISE WARNING '      ❌ % (code: %) NO ENCONTRADO', cat_name, cat_code;
      END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '   Categorías OPCIONALES:';
    FOR i IN 1..array_length(optional_categories, 1) LOOP
      cat_code := optional_categories[i][1];
      cat_name := optional_categories[i][2];
      expected_parent := optional_categories[i][3];
      
      SELECT id INTO cat_id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = cat_code OR code LIKE cat_code || '%')
        AND deleted = false
      LIMIT 1;
      
      found := (cat_id IS NOT NULL);
      
      IF found THEN
        SELECT parent_category_id INTO parent_id
        FROM public."ItemCategories"
        WHERE id = cat_id;
        
        RAISE NOTICE '      ℹ️  % (code: %) encontrado, parent: %', 
          cat_name, 
          cat_code,
          COALESCE((SELECT name FROM public."ItemCategories" WHERE id = parent_id), 'NULL');
      ELSE
        RAISE NOTICE '      ⚪ % (code: %) no encontrado (opcional)', cat_name, cat_code;
      END IF;
    END LOOP;
  END;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Verificación completada';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

END $$;

-- Query final: Mostrar solo las categorías hijas activas
SELECT 
  name,
  code,
  CASE 
    WHEN parent_category_id IS NULL THEN 'NULL (Padre/Hoja)'
    ELSE (SELECT name FROM public."ItemCategories" p WHERE p.id = c.parent_category_id)
  END as parent_name,
  is_group,
  deleted
FROM public."ItemCategories" c
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
ORDER BY 
  code,
  name;
