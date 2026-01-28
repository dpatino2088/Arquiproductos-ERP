-- ====================================================
-- VERIFICACIÓN: No hay doble cálculo en funciones
-- Date: 2026-01-25
-- Description: Verifica que create_configured_product_and_bom_preview
--              llame a calculate_configured_product_totals (no duplicado)
-- ====================================================

-- Verificar si create_configured_product_and_bom_preview llama a calculate_configured_product_totals
SELECT 
  proname as function_name,
  CASE 
    WHEN prosrc LIKE '%calculate_configured_product_totals%' THEN '✅ Llama a calculate_configured_product_totals'
    WHEN prosrc LIKE '%roll_msrp_total%' AND prosrc LIKE '%bom_total%' THEN '⚠️ Puede estar calculando directamente (verificar)'
    ELSE 'ℹ️ No calcula totals directamente'
  END as calculation_method
FROM pg_proc
WHERE proname = 'create_configured_product_and_bom_preview';

-- Verificar que calculate_configured_product_totals no se llama múltiples veces
-- (esto se verifica en el código, no en SQL)
