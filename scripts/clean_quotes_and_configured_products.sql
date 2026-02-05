-- ============================================================================
-- Limpiar todos los registros de Quotes y ConfiguredProducts
-- Fecha: 2026-02-04
-- Uso: Ejecutar en Supabase SQL Editor o psql. Hacer backup antes.
-- ============================================================================
-- Orden respetando FKs:
--   QuoteLineCosts (si existe) → QuoteLineBOMSelections → QuoteLines
--   → SalesOrders.quote_id = NULL (para poder borrar Quotes)
--   → Quotes → ConfiguredProducts
-- ============================================================================

BEGIN;

-- 1) Tablas que referencian QuoteLines (eliminar primero)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'QuoteLineCosts') THEN
    DELETE FROM public."QuoteLineCosts";
  END IF;
END $$;
DELETE FROM public."QuoteLineBOMSelections";

-- 2) Líneas de cotización
DELETE FROM public."QuoteLines" WHERE true;

-- 3) Permitir borrar Quotes: SalesOrders tiene FK quote_id -> Quotes ON DELETE RESTRICT
--    Desvinculamos órdenes de venta de sus cotizaciones
UPDATE public."SalesOrders" SET quote_id = NULL WHERE quote_id IS NOT NULL;

-- 4) Cotizaciones
DELETE FROM public."Quotes" WHERE true;

-- 5) Productos configurados (ConfiguredProducts.quote_id queda NULL al borrar Quotes;
--    los borramos explícitamente para dejar la tabla vacía)
DELETE FROM public."ConfiguredProducts" WHERE true;

COMMIT;

-- Verificación
DO $$
DECLARE
  v_ql int; v_q int; v_cp int;
BEGIN
  SELECT COUNT(*) INTO v_ql FROM public."QuoteLines";
  SELECT COUNT(*) INTO v_q FROM public."Quotes";
  SELECT COUNT(*) INTO v_cp FROM public."ConfiguredProducts";
  RAISE NOTICE 'QuoteLines: %, Quotes: %, ConfiguredProducts: %', v_ql, v_q, v_cp;
END $$;
