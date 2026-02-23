-- ============================================================
-- PASO 2: Constraints de integridad en OrganizationUsers y DealerUsers
-- ============================================================
-- Objetivo: Impedir status = 'active' sin user_id (evita RLS silencioso con 0 filas).
-- Idempotente: UPDATE correctivo primero; ADD CONSTRAINT con IF NOT EXISTS no existe en PG,
--   usamos DO block para agregar solo si no existe.
-- ============================================================

-- ---------- OrganizationUsers ----------
-- Fix previo: filas activas sin user_id pasan a 'invited'
UPDATE public."OrganizationUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND deleted = false;

ALTER TABLE public."OrganizationUsers"
  DROP CONSTRAINT IF EXISTS chk_orguser_active_has_userid;

ALTER TABLE public."OrganizationUsers"
  ADD CONSTRAINT chk_orguser_active_has_userid
  CHECK (status <> 'active' OR user_id IS NOT NULL);

COMMENT ON CONSTRAINT chk_orguser_active_has_userid ON public."OrganizationUsers" IS
  'Active rows must have user_id set (invited rows may have NULL until they accept).';

-- ---------- DealerUsers ----------
UPDATE public."DealerUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND (deleted IS NULL OR deleted = false);

ALTER TABLE public."DealerUsers"
  DROP CONSTRAINT IF EXISTS chk_dealeruser_active_has_userid;

ALTER TABLE public."DealerUsers"
  ADD CONSTRAINT chk_dealeruser_active_has_userid
  CHECK (status <> 'active' OR user_id IS NOT NULL);

COMMENT ON CONSTRAINT chk_dealeruser_active_has_userid ON public."DealerUsers" IS
  'Active portal users must have user_id set.';

-- Validación manual: INSERT con status='active' y user_id NULL debe fallar en ambas tablas.
