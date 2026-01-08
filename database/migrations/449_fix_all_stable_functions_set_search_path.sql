-- ====================================================
-- Migration 449: Fix all STABLE functions with SET search_path
-- ====================================================
-- PROBLEMA: Funciones STABLE no pueden usar SET search_path
-- SOLUCIÓN: Eliminar SET search_path de funciones STABLE o cambiarlas a VOLATILE si es necesario
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Find and fix all STABLE functions with SET search_path
-- ====================================================
DO $$
DECLARE
  v_func_record RECORD;
  v_func_def text;
  v_new_def text;
BEGIN
  -- Find all STABLE functions (check for SET search_path inside the loop)
  FOR v_func_record IN
    SELECT 
      p.oid,
      n.nspname AS schema_name,
      p.proname AS function_name,
      pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.provolatile = 's'  -- 's' = STABLE
  LOOP
    -- Get function definition
    BEGIN
      v_func_def := pg_get_functiondef(v_func_record.oid);
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Could not get definition for %.%: %', 
          v_func_record.schema_name, 
          v_func_record.function_name,
          SQLERRM;
        CONTINUE;
    END;
    
    -- Skip if definition is empty or null
    IF v_func_def IS NULL OR v_func_def = '' THEN
      CONTINUE;
    END IF;
    
    -- Check if function has SET search_path
    IF v_func_def NOT LIKE '%SET search_path%' THEN
      CONTINUE;
    END IF;
    
    -- Remove SET search_path lines
    v_new_def := regexp_replace(
      v_func_def,
      E'[\\s]*SET\\s+search_path\\s*=[^;]*;?[\\s]*\\n?',
      '',
      'gi'
    );
    
    -- Skip if nothing changed
    IF v_new_def = v_func_def THEN
      CONTINUE;
    END IF;
    
    -- Log the fix
    RAISE NOTICE 'Fixing STABLE function: %.%(%)', 
      v_func_record.schema_name, 
      v_func_record.function_name,
      v_func_record.args;
    
    -- Execute the fixed function definition
    BEGIN
      EXECUTE v_new_def;
      RAISE NOTICE '✅ Fixed: %.%', v_func_record.schema_name, v_func_record.function_name;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING '❌ Failed to fix %.%: %', 
          v_func_record.schema_name, 
          v_func_record.function_name,
          SQLERRM;
    END;
  END LOOP;
END $$;

-- ====================================================
-- STEP 2: Verify no STABLE functions have SET search_path
-- ====================================================
DO $$
DECLARE
  v_count integer := 0;
  v_func_record RECORD;
  v_func_def text;
BEGIN
  -- Count STABLE functions with SET search_path (check inside loop)
  FOR v_func_record IN
    SELECT 
      p.oid,
      n.nspname AS schema_name,
      p.proname AS function_name
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.provolatile = 's'  -- STABLE
  LOOP
    BEGIN
      v_func_def := pg_get_functiondef(v_func_record.oid);
      IF v_func_def IS NOT NULL AND v_func_def LIKE '%SET search_path%' THEN
        v_count := v_count + 1;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        -- Skip functions we can't read
        NULL;
    END;
  END LOOP;
  
  IF v_count > 0 THEN
    RAISE WARNING '⚠️ Still found % STABLE functions with SET search_path', v_count;
  ELSE
    RAISE NOTICE '✅ All STABLE functions are clean (no SET search_path)';
  END IF;
END $$;

-- ====================================================
-- STEP 3: Notify PostgREST to reload schema
-- ====================================================
NOTIFY pgrst, 'reload schema';

COMMIT;

