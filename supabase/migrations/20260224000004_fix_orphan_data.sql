-- ============================================================
-- PASO 6: Fix de datos huérfanos
-- ============================================================
-- Ejecutar después de PASO 2 y 3, antes de PASO 4 y 5.
-- 6a/6b: Ya cubiertos por PASO 2 (UPDATE active→invited cuando user_id NULL).
-- 6c: AppUsers sin correspondencia en OrganizationUsers ni DealerUsers → deleted = true.
-- 6d: AppUserPreferences con active_dealer_id a dealer inexistente o deleted → NULL.
-- 6e: Solo diagnóstico (SELECT) para Quotes/Proposals/Directory con dealer_id huérfano.
-- ============================================================

-- ---------- 6a/6b (idempotente, por si se ejecuta en otro orden) ----------
UPDATE public."OrganizationUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND deleted = false;

UPDATE public."DealerUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND (deleted IS NULL OR deleted = false);

-- ---------- 6c: AppUsers huérfanos → deleted = true ----------
UPDATE public."AppUsers" au
SET deleted = true, updated_at = now()
WHERE au.deleted = false
  AND (
    (au.user_type = 'org' AND NOT EXISTS (
      SELECT 1 FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = au.organization_id
        AND ou.user_id = au.auth_user_id
        AND (ou.deleted = false)
    ))
    OR
    (au.user_type = 'dealer' AND au.dealer_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public."DealerUsers" du
      WHERE du.dealer_id = au.dealer_id
        AND du.user_id = au.auth_user_id
        AND (du.deleted IS NULL OR du.deleted = false)
    ))
  );

-- ---------- 6d: AppUserPreferences con active_dealer_id a dealer inexistente o deleted ----------
UPDATE public."AppUserPreferences" pref
SET active_dealer_id = NULL, updated_at = now()
WHERE pref.active_dealer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d
    WHERE d.id = pref.active_dealer_id
      AND (d.deleted IS NULL OR d.deleted = false)
  );

-- ---------- 6e: Diagnóstico (solo reporte, sin UPDATE) ----------
-- Descomentar y ejecutar manualmente para revisar filas con dealer_id huérfano:
/*
DO $$
DECLARE
  v_quotes bigint;
  v_proposals bigint;
  v_dc bigint;
  v_dcust bigint;
BEGIN
  SELECT count(*) INTO v_quotes FROM public."Quotes" q
  WHERE q.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = q.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  SELECT count(*) INTO v_proposals FROM public."Proposals" p
  WHERE p.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = p.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  SELECT count(*) INTO v_dc FROM public."DirectoryContacts" dc
  WHERE dc.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = dc.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  SELECT count(*) INTO v_dcust FROM public."DirectoryCustomers" dc
  WHERE dc.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = dc.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  RAISE NOTICE 'Quotes con dealer_id huérfano: %', v_quotes;
  RAISE NOTICE 'Proposals con dealer_id huérfano: %', v_proposals;
  RAISE NOTICE 'DirectoryContacts con dealer_id huérfano: %', v_dc;
  RAISE NOTICE 'DirectoryCustomers con dealer_id huérfano: %', v_dcust;
END $$;
*/
