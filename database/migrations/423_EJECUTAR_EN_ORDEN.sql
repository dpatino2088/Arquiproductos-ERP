-- ====================================================
-- EJECUTAR ESTOS ARCHIVOS EN ESTE ORDEN
-- ====================================================
-- 
-- PASO 1: Ejecutar 421_fix_bom_fabric_uom_and_reset.sql
--         (Este archivo contiene las funciones helper)
--
-- PASO 2: Ejecutar la función generate_bom_for_manufacturing_order
--         desde 405_fix_bom_instances_rls_and_return_counts.sql
--         (Busca "CREATE OR REPLACE FUNCTION generate_bom_for_manufacturing_order")
--         (Copia TODO desde CREATE hasta el $$; final)
--
-- PASO 3: Probar desde UI o ejecutar queries de verificación
--
-- ====================================================
-- NO EJECUTES ESTE ARCHIVO - ES SOLO INSTRUCCIONES
-- ====================================================


