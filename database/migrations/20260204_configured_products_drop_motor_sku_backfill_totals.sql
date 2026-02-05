-- ============================================================================
-- ConfiguredProducts: 1) Eliminar columna redundante motor_sku (está en config_snapshot)
--                    2) Rellenar totales en cero desde bom_preview_snapshot (backfill)
-- Fecha: 2026-02-04
-- Referencia: dump backups/2026-02_04_V2_full.sql
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) Eliminar motor_sku (redundante con config_snapshot)
-- ----------------------------------------------------------------------------
ALTER TABLE public."ConfiguredProducts"
  DROP COLUMN IF EXISTS motor_sku;

-- ----------------------------------------------------------------------------
-- 2) Backfill: actualizar totales desde bom_preview_snapshot donde columnas están en 0
--    Solo toca filas con snapshot válido (version=1 y totals presentes)
-- ----------------------------------------------------------------------------
UPDATE public."ConfiguredProducts" cp
SET
  roll_msrp_total = COALESCE(t.roll_msrp_total, cp.roll_msrp_total),
  bom_total = COALESCE(t.bom_total, cp.bom_total),
  roll_plus_bom_total = COALESCE(t.roll_msrp_total, 0) + COALESCE(t.bom_total, 0),
  total_msrp = COALESCE(t.total_msrp, cp.total_msrp),
  roll_total_cost = COALESCE(t.roll_total_cost, cp.roll_total_cost),
  bom_total_cost = COALESCE(t.bom_total_cost, cp.bom_total_cost),
  labor_amount = COALESCE(t.labor_amount, cp.labor_amount),
  accessories_total = COALESCE(t.accessories_total, cp.accessories_total),
  updated_at = now()
FROM (
  SELECT cp_inner.id,
    (cp_inner.bom_preview_snapshot->'totals'->>'roll_msrp_total')::numeric AS roll_msrp_total,
    (cp_inner.bom_preview_snapshot->'totals'->>'bom_total')::numeric AS bom_total,
    (cp_inner.bom_preview_snapshot->'totals'->>'total_msrp')::numeric AS total_msrp,
    (cp_inner.bom_preview_snapshot->'totals'->>'roll_total_cost')::numeric AS roll_total_cost,
    (cp_inner.bom_preview_snapshot->'totals'->>'bom_total_cost')::numeric AS bom_total_cost,
    (cp_inner.bom_preview_snapshot->'totals'->>'labor_amount')::numeric AS labor_amount,
    (cp_inner.bom_preview_snapshot->'totals'->>'accessories_total')::numeric AS accessories_total
  FROM public."ConfiguredProducts" cp_inner
  WHERE cp_inner.bom_preview_snapshot->>'version' = '1'
    AND cp_inner.bom_preview_snapshot->'totals' IS NOT NULL
    AND (
      COALESCE(cp_inner.roll_msrp_total, 0) = 0
      OR COALESCE(cp_inner.bom_total, 0) = 0
      OR COALESCE(cp_inner.total_msrp, 0) = 0
      OR COALESCE(cp_inner.roll_total_cost, 0) = 0
      OR COALESCE(cp_inner.bom_total_cost, 0) = 0
    )
) t
WHERE cp.id = t.id;

COMMIT;
