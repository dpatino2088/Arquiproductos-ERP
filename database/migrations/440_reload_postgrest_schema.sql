-- ====================================================
-- Migration 440: Reload PostgREST schema
-- ====================================================
-- OBJETIVO: Notificar a PostgREST para recargar el schema después de cambios
-- en funciones y vistas. Esto asegura que los cambios sean visibles inmediatamente.
-- ====================================================
-- NOTA: Este comando debe ejecutarse con permisos suficientes.
-- En Supabase, esto se hace automáticamente, pero incluimos el comando
-- para referencia en entornos self-hosted.
-- ====================================================

SET search_path = public;

BEGIN;

-- Notify PostgREST to reload schema
-- This is typically handled automatically by Supabase, but included for completeness
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ====================================================
-- INSTRUCCIONES POST-DEPLOY:
-- ====================================================
-- 1. Ejecutar migraciones 437, 438, 439, 440 en orden
-- 2. Verificar permisos:
--    SELECT has_table_privilege('anon', 'vw_bom_instances_safe', 'SELECT');
--    SELECT has_table_privilege('authenticated', 'vw_bom_instances_safe', 'SELECT');
-- 3. Verificar función:
--    SELECT proname, proargtypes FROM pg_proc WHERE proname = 'generate_bom_for_manufacturing_order';
-- 4. Probar generación de BOM:
--    SELECT * FROM generate_bom_for_manufacturing_order('<mo_id>'::uuid);
-- ====================================================

