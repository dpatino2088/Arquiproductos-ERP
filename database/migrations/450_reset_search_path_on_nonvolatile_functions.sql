-- ====================================================
-- Migration 450: Reset search_path on ALL functions (comprehensive fix)
-- ====================================================
-- PROBLEMA: Funciones con SET search_path en proconfig causan error
-- "SET is not allowed in a non-volatile function" cuando se consulta Quotes
-- SOLUCIÓN: ALTER FUNCTION ... RESET search_path para TODAS las funciones
-- ====================================================
-- 
-- Este script detecta TODAS las funciones (STABLE, IMMUTABLE, VOLATILE)
-- que tienen search_path configurado en pg_proc.proconfig y lo resetea.
-- 
-- No recrea funciones, solo resetea la configuración.
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Reset search_path on ALL functions (comprehensive)
-- ====================================================
DO $$
DECLARE
  v_func_record RECORD;
  v_func_signature text;
  v_reset_count integer := 0;
BEGIN
  RAISE NOTICE 'Starting comprehensive search_path reset for ALL functions...';
  
  -- Find ALL functions (STABLE, IMMUTABLE, VOLATILE) with search_path in proconfig
  -- Use more robust detection: check each element in proconfig array
  FOR v_func_record IN
    SELECT 
      p.oid,
      n.nspname AS schema_name,
      p.proname AS function_name,
      pg_get_function_identity_arguments(p.oid) AS args,
      p.proconfig,
      CASE 
        WHEN p.provolatile = 's' THEN 'STABLE'
        WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
        WHEN p.provolatile = 'v' THEN 'VOLATILE'
        ELSE 'UNKNOWN'
      END as volatility
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proconfig IS NOT NULL
      AND EXISTS (
        SELECT 1 
        FROM unnest(p.proconfig) AS config_item
        WHERE config_item LIKE 'search_path=%'
      )
    ORDER BY p.proname, pg_get_function_identity_arguments(p.oid)
  LOOP
    -- Get function signature using oid::regprocedure
    v_func_signature := v_func_record.oid::regprocedure::text;
    
    -- Reset search_path for this function
    BEGIN
      EXECUTE format('ALTER FUNCTION %s RESET search_path', v_func_signature);
      
      v_reset_count := v_reset_count + 1;
      RAISE NOTICE '✅ Reset search_path: % (volatility: %)', 
        v_func_signature,
        v_func_record.volatility;
      
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING '❌ Failed to reset search_path for %: %', 
          v_func_signature,
          SQLERRM;
    END;
  END LOOP;
  
  IF v_reset_count = 0 THEN
    RAISE NOTICE '✅ No functions found with search_path configuration';
  ELSE
    RAISE NOTICE '✅ Successfully reset search_path on % function(s)', v_reset_count;
  END IF;
END $$;

-- ====================================================
-- STEP 2: Verify no functions have search_path
-- ====================================================
DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proconfig IS NOT NULL
    AND EXISTS (
      SELECT 1 
      FROM unnest(p.proconfig) AS config_item
      WHERE config_item LIKE 'search_path=%'
    );
  
  IF v_count > 0 THEN
    RAISE WARNING '⚠️ Still found % function(s) with search_path in proconfig', v_count;
  ELSE
    RAISE NOTICE '✅ Verification passed: All functions are clean (no search_path in proconfig)';
  END IF;
END $$;

-- ====================================================
-- STEP 3: Notify PostgREST to reload schema
-- ====================================================
NOTIFY pgrst, 'reload schema';

COMMIT;

