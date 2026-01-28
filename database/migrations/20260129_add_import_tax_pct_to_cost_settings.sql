-- ====================================================
-- Migration: Columnas de compatibilidad CostSettings (cs) y CategoryMargins (cm)
-- Date: 2026-01-29
-- ====================================================
-- Fixes:
--   - "column cs.import_tax_pct does not exist"
--   - "column cs.default_margin_pct does not exist"
--   - "column cs.msrp_pct_sale_out does not exist"
--   - "column cm.minimum_margin_pct does not exist"
--
-- cs = CostSettings; cm = CategoryMargins. Algunas vistas/funciones/RPC usan
-- nombres que no existen en el esquema actual. Se añaden columnas compatibilidad.
-- ====================================================

-- -------- CostSettings (alias cs) --------

-- 1) import_tax_pct := global_import_tax_pct
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='CostSettings' AND column_name='import_tax_pct') THEN
    ALTER TABLE public."CostSettings" ADD COLUMN import_tax_pct numeric(7,4) GENERATED ALWAYS AS (global_import_tax_pct) STORED;
    RAISE NOTICE '✅ CostSettings: import_tax_pct (from global_import_tax_pct)';
  END IF;
END $$;

-- 2) default_margin_pct: backfill desde minimum_margin_pct
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='CostSettings' AND column_name='default_margin_pct') THEN
    ALTER TABLE public."CostSettings" ADD COLUMN default_margin_pct numeric(7,4) NOT NULL DEFAULT 0.3500;
    UPDATE public."CostSettings" SET default_margin_pct = minimum_margin_pct;
    RAISE NOTICE '✅ CostSettings: default_margin_pct (backfill from minimum_margin_pct)';
  END IF;
END $$;

-- 3) msrp_pct_sale_out := default_msrp_pct_sale_out
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='CostSettings' AND column_name='msrp_pct_sale_out') THEN
    ALTER TABLE public."CostSettings" ADD COLUMN msrp_pct_sale_out numeric(7,4) GENERATED ALWAYS AS (default_msrp_pct_sale_out) STORED;
    RAISE NOTICE '✅ CostSettings: msrp_pct_sale_out (from default_msrp_pct_sale_out)';
  END IF;
END $$;

-- -------- CategoryMargins (alias cm) --------

-- 4) minimum_margin_pct := msrp_pct_sale_in (mismo concepto: margen mínimo / Sale In)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='CategoryMargins' AND column_name='minimum_margin_pct') THEN
    ALTER TABLE public."CategoryMargins" ADD COLUMN minimum_margin_pct numeric(7,4) GENERATED ALWAYS AS (msrp_pct_sale_in) STORED;
    RAISE NOTICE '✅ CategoryMargins: minimum_margin_pct (from msrp_pct_sale_in)';
  END IF;
END $$;
