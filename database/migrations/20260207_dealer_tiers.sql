-- ============================================================
-- Migration: DealerTiers + dealer_tier_id en Dealers
-- ============================================================
-- Tiers de descuento por organización (Platinum/Gold/Silver/Bronze).
-- Cada Dealer referencia un DealerTier; Quote/SalesOrder leen desde ahí.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Crear tabla public."DealerTiers"
-- ============================================================
CREATE TABLE IF NOT EXISTS public."DealerTiers" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  discount_pct numeric(5,2) NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

CREATE INDEX IF NOT EXISTS idx_dealertiers_org_sort
  ON public."DealerTiers"(organization_id, sort_order);

-- Trigger updated_at (usa función existente set_updated_at si existe)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_dealertiers_updated_at ON public."DealerTiers";
    CREATE TRIGGER trg_dealertiers_updated_at
      BEFORE UPDATE ON public."DealerTiers"
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ============================================================
-- 2) Agregar dealer_tier_id a public."Dealers"
-- ============================================================
ALTER TABLE public."Dealers"
  ADD COLUMN IF NOT EXISTS dealer_tier_id uuid NULL
  REFERENCES public."DealerTiers"(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_dealers_dealer_tier_id
  ON public."Dealers"(dealer_tier_id) WHERE dealer_tier_id IS NOT NULL;

-- ============================================================
-- 3) Seed idempotente por organización (Platinum 65, Gold 55, Silver 45, Bronze 35)
-- ============================================================
INSERT INTO public."DealerTiers" (organization_id, code, name, discount_pct, sort_order, active)
SELECT o.id, t.code, t.name, t.discount_pct, t.sort_order, true
FROM public."Organizations" o
CROSS JOIN (VALUES
  ('PLATINUM', 'Platinum', 65.00, 10),
  ('GOLD', 'Gold', 55.00, 20),
  ('SILVER', 'Silver', 45.00, 30),
  ('BRONZE', 'Bronze', 35.00, 40)
) AS t(code, name, discount_pct, sort_order)
ON CONFLICT (organization_id, code) DO UPDATE
SET name = EXCLUDED.name,
    discount_pct = EXCLUDED.discount_pct,
    sort_order = EXCLUDED.sort_order,
    active = true,
    updated_at = now();

-- ============================================================
-- 4) RLS en DealerTiers (mismo patrón que Dealers)
-- ============================================================
ALTER TABLE public."DealerTiers" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dealertiers_select_own_org ON public."DealerTiers";
CREATE POLICY dealertiers_select_own_org
  ON public."DealerTiers" FOR SELECT
  USING (public.is_org_member(organization_id));

DROP POLICY IF EXISTS dealertiers_insert_own_org ON public."DealerTiers";
CREATE POLICY dealertiers_insert_own_org
  ON public."DealerTiers" FOR INSERT
  WITH CHECK (public.is_org_owner_or_admin(organization_id));

DROP POLICY IF EXISTS dealertiers_update_own_org ON public."DealerTiers";
CREATE POLICY dealertiers_update_own_org
  ON public."DealerTiers" FOR UPDATE
  USING (public.is_org_owner_or_admin(organization_id))
  WITH CHECK (public.is_org_owner_or_admin(organization_id));

COMMIT;
