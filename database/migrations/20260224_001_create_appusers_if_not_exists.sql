-- ============================================================
-- PASO 1: Migración base para AppUsers (si no existe)
-- ============================================================
-- Objetivo: Garantizar DDL declarativo de AppUsers con constraints
-- correctos. Idempotente: CREATE TABLE IF NOT EXISTS, índices IF NOT EXISTS.
-- Referencia: plan Estabilización Dealers Acting-As RLS.
-- ============================================================

-- AppUserPreferences y 20260223 referencian AppUsers(id); Dealers se asume existente.
-- Si la tabla ya existe (creada fuera del repo), esta migración no la sobrescribe.

CREATE TABLE IF NOT EXISTS public."AppUsers" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  user_type text NOT NULL CHECK (user_type IN ('org', 'dealer')),
  dealer_id uuid REFERENCES public."Dealers"(id) ON DELETE SET NULL,
  auth_user_id uuid NOT NULL,
  email text,
  display_name text,
  role_code text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  must_change_password boolean DEFAULT false,
  deleted boolean NOT NULL DEFAULT false,
  invited_by_app_user_id uuid REFERENCES public."AppUsers"(id) ON DELETE SET NULL,
  temp_password_set_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_appusers_org_dealer
    CHECK (
      (user_type = 'org' AND dealer_id IS NULL)
      OR (user_type = 'dealer' AND dealer_id IS NOT NULL)
    )
);

COMMENT ON TABLE public."AppUsers" IS 'Unified app user view (org vs dealer). Single source for current_dealer_id() and RLS.';

-- Unicidad: una fila por (auth_user_id, user_type, dealer_id) con dealer_id NULL para org.
-- Usamos índice único sobre expresión para permitir ON CONFLICT en triggers (PASO 3).
CREATE UNIQUE INDEX IF NOT EXISTS idx_appusers_auth_user_type_dealer_unique
  ON public."AppUsers" (
    auth_user_id,
    user_type,
    COALESCE(dealer_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_appusers_auth_user_type
  ON public."AppUsers"(auth_user_id, user_type)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_appusers_organization_id
  ON public."AppUsers"(organization_id)
  WHERE deleted = false;

-- Trigger updated_at (reutilizar función existente)
-- Primero asegurar que la función existe; luego el trigger (evita $$ anidados)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $fn$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_appusers_updated_at') THEN
    CREATE TRIGGER trg_appusers_updated_at
      BEFORE UPDATE ON public."AppUsers"
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- Validación: tabla existe y se puede consultar
-- SELECT count(*) FROM public."AppUsers";
