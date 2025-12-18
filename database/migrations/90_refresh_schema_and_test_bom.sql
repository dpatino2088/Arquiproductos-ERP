-- ====================================================
-- Migration 90: Refrescar schema y probar BOMTemplates
-- ====================================================
-- Este script verifica las políticas RLS y hace una prueba
-- de inserción para forzar la actualización del schema cache
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  test_template_id uuid;
  test_product_type_id uuid;
  policy_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICACIÓN Y PRUEBA DE BOMTemplates';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Verificar que la tabla existe
  -- ====================================================
  RAISE NOTICE 'PASO 1: Verificando tabla...';
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMTemplates'
  ) THEN
    RAISE EXCEPTION 'ERROR: La tabla BOMTemplates no existe. Ejecuta el script 88 primero.';
  END IF;
  
  RAISE NOTICE '   ✅ Tabla BOMTemplates existe';

  -- ====================================================
  -- PASO 2: Verificar políticas RLS
  -- ====================================================
  RAISE NOTICE 'PASO 2: Verificando políticas RLS...';
  
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'BOMTemplates';
  
  RAISE NOTICE '   Políticas RLS encontradas: %', policy_count;
  
  IF policy_count = 0 THEN
    RAISE WARNING '   ⚠️  No hay políticas RLS. Esto puede causar problemas de acceso.';
  END IF;

  -- ====================================================
  -- PASO 3: Obtener un product_type_id de prueba
  -- ====================================================
  RAISE NOTICE 'PASO 3: Obteniendo product_type_id de prueba...';
  
  -- Intentar primero ProductTypes (tabla moderna)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'ProductTypes'
  ) THEN
    RAISE NOTICE '   Intentando obtener de tabla ProductTypes...';
    SELECT id INTO test_product_type_id
    FROM public."ProductTypes"
    WHERE organization_id = target_org_id
      AND deleted = false
    LIMIT 1;
  END IF;
  
  -- Si no se encontró en ProductTypes, intentar Profiles
  IF test_product_type_id IS NULL THEN
    RAISE NOTICE '   Intentando obtener de tabla Profiles...';
    SELECT id INTO test_product_type_id
    FROM public."Profiles"
    WHERE deleted = false
      AND (type = 'product_type' OR type IS NULL)
    LIMIT 1;
  END IF;
  
  IF test_product_type_id IS NULL THEN
    RAISE WARNING '   ⚠️  No se encontró ningún product_type. No se puede hacer prueba de inserción.';
  ELSE
    RAISE NOTICE '   ✅ Product Type ID encontrado: %', test_product_type_id;
  END IF;

  -- ====================================================
  -- PASO 4: Hacer una prueba de inserción (y luego eliminar)
  -- ====================================================
  IF test_product_type_id IS NOT NULL THEN
    RAISE NOTICE 'PASO 4: Haciendo prueba de inserción...';
    
    BEGIN
      INSERT INTO public."BOMTemplates" (
        organization_id,
        product_type_id,
        name,
        description,
        active,
        deleted,
        archived
      ) VALUES (
        target_org_id,
        test_product_type_id,
        'TEST TEMPLATE - DELETE ME',
        'This is a test template. It will be deleted immediately.',
        true,
        false,
        false
      ) RETURNING id INTO test_template_id;
      
      RAISE NOTICE '   ✅ Inserción exitosa. Template ID: %', test_template_id;
      
      -- Eliminar el template de prueba inmediatamente
      DELETE FROM public."BOMTemplates" WHERE id = test_template_id;
      RAISE NOTICE '   ✅ Template de prueba eliminado';
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '   ⚠️  Error en prueba de inserción: %', SQLERRM;
      RAISE WARNING '   💡 Esto puede indicar un problema con las políticas RLS';
    END;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ VERIFICACIÓN COMPLETADA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '💡 Si aún ves el error en el frontend:';
  RAISE NOTICE '   1. Espera 1-2 minutos para que Supabase actualice el schema cache';
  RAISE NOTICE '   2. Recarga la página del frontend (Ctrl+Shift+R o Cmd+Shift+R)';
  RAISE NOTICE '   3. O ve a Supabase Dashboard → Settings → API → "Reload schema"';
  RAISE NOTICE '';

END $$;

-- Mostrar todas las políticas RLS
SELECT 
  policyname,
  cmd as command,
  roles,
  qual as using_expression,
  with_check
FROM pg_policies
WHERE tablename = 'BOMTemplates'
ORDER BY policyname;
