-- ====================================================
-- MIGRATION: Agregar columnas snapshot a QuoteLines
-- Date: 2026-01-25
-- Description: Agrega columnas para capturar snapshots desglosados de roll y BOM
--              al momento de crear QuoteLine desde ConfiguredProduct
-- ====================================================

BEGIN;

-- 1) Agregar columnas snapshot en QuoteLines (si no existen)
ALTER TABLE public."QuoteLines"
  ADD COLUMN IF NOT EXISTS roll_cost_snapshot numeric(12,4) NULL,
  ADD COLUMN IF NOT EXISTS bom_cost_snapshot  numeric(12,4) NULL,
  ADD COLUMN IF NOT EXISTS roll_msrp_snapshot numeric(12,4) NULL,
  ADD COLUMN IF NOT EXISTS bom_msrp_snapshot  numeric(12,4) NULL;

COMMENT ON COLUMN public."QuoteLines".roll_cost_snapshot IS
  'Snapshot del costo total del roll (material + import/shipping/labor si aplica) al momento de crear la QuoteLine.';
COMMENT ON COLUMN public."QuoteLines".bom_cost_snapshot IS
  'Snapshot del costo total del BOM al momento de crear la QuoteLine.';
COMMENT ON COLUMN public."QuoteLines".roll_msrp_snapshot IS
  'Snapshot del MSRP del roll al momento de crear la QuoteLine.';
COMMENT ON COLUMN public."QuoteLines".bom_msrp_snapshot IS
  'Snapshot del MSRP del BOM al momento de crear la QuoteLine.';

-- 2) (Opcional recomendado) defaults a 0 para evitar nulls en UI
-- Si prefieres permitir NULL, comenta este bloque.
UPDATE public."QuoteLines"
SET
  roll_cost_snapshot = COALESCE(roll_cost_snapshot, 0),
  bom_cost_snapshot  = COALESCE(bom_cost_snapshot, 0),
  roll_msrp_snapshot = COALESCE(roll_msrp_snapshot, 0),
  bom_msrp_snapshot  = COALESCE(bom_msrp_snapshot, 0)
WHERE
  roll_cost_snapshot IS NULL
  OR bom_cost_snapshot IS NULL
  OR roll_msrp_snapshot IS NULL
  OR bom_msrp_snapshot IS NULL;

COMMIT;
