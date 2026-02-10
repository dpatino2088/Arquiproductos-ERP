-- ============================================================
-- Migration: Customer Proposals MVP
-- ============================================================
-- Creates Proposals (cabecera) and ProposalLines (líneas) for
-- customer-facing documents derived from Quotes. Does not modify
-- existing tables (Quotes, QuoteLines, etc.).
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Enums
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proposal_status') THEN
    CREATE TYPE public.proposal_status AS ENUM (
      'draft',
      'sent',
      'accepted',
      'rejected'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proposal_line_type') THEN
    CREATE TYPE public.proposal_line_type AS ENUM (
      'from_quote',
      'custom'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proposal_custom_line_category') THEN
    CREATE TYPE public.proposal_custom_line_category AS ENUM (
      'installation',
      'transportation',
      'other'
    );
  END IF;
END $$;

-- ============================================================
-- 2) Table: Proposals
-- ============================================================
CREATE TABLE IF NOT EXISTS public."Proposals" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  quote_id uuid NOT NULL REFERENCES public."Quotes"(id) ON DELETE RESTRICT,
  dealer_id uuid REFERENCES public."Dealers"(id) ON DELETE SET NULL,
  customer_id uuid REFERENCES public."DirectoryCustomers"(id) ON DELETE SET NULL,
  contact_id uuid REFERENCES public."DirectoryContacts"(id) ON DELETE SET NULL,

  proposal_no text,
  status public.proposal_status NOT NULL DEFAULT 'draft',
  currency text NOT NULL DEFAULT 'USD',

  global_discount_pct numeric(5,4),
  global_fee_amount numeric(12,4),
  notes text,
  valid_until date,

  created_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_portal_user_id uuid REFERENCES public."DealerUsers"(id) ON DELETE SET NULL,

  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT proposals_created_by_exactly_one
    CHECK (
      (created_by_user_id IS NOT NULL AND created_by_portal_user_id IS NULL)
      OR (created_by_user_id IS NULL AND created_by_portal_user_id IS NOT NULL)
    )
);

COMMENT ON TABLE public."Proposals" IS 'Customer-facing proposal derived from a Quote. Editable (overrides, extras). 1 Quote → N Proposals.';
COMMENT ON COLUMN public."Proposals"."quote_id" IS 'Source Quote (technical/audit). Proposal does not modify Quote.';
COMMENT ON COLUMN public."Proposals"."customer_id" IS 'Customer (DirectoryCustomers). Default from Quote but editable.';
COMMENT ON COLUMN public."Proposals"."contact_id" IS 'Contact (DirectoryContacts). Default from Quote but editable.';
COMMENT ON COLUMN public."Proposals"."global_discount_pct" IS 'Optional global discount applied to proposal total (e.g. 0.05 = 5%).';
COMMENT ON COLUMN public."Proposals"."global_fee_amount" IS 'Optional global fee added to proposal total.';

-- ============================================================
-- 3) Table: ProposalLines
-- ============================================================
CREATE TABLE IF NOT EXISTS public."ProposalLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id uuid NOT NULL REFERENCES public."Proposals"(id) ON DELETE CASCADE,
  line_type public.proposal_line_type NOT NULL,

  -- For line_type = 'from_quote': reference QuoteLine + overrides
  quote_line_id uuid REFERENCES public."QuoteLines"(id) ON DELETE SET NULL,
  discount_pct numeric(5,4),
  markup_pct numeric(5,4),
  fixed_unit_price numeric(12,4),

  -- For line_type = 'custom': description + qty × unit_price
  description text,
  quantity numeric(12,4),
  unit_price numeric(12,4),
  custom_category public.proposal_custom_line_category,

  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT proposallines_from_quote_check
    CHECK (
      (line_type <> 'from_quote')
      OR (line_type = 'from_quote' AND quote_line_id IS NOT NULL)
    ),
  CONSTRAINT proposallines_custom_check
    CHECK (
      (line_type <> 'custom')
      OR (
        line_type = 'custom'
        AND quote_line_id IS NULL
        AND description IS NOT NULL
        AND description <> ''
        AND quantity IS NOT NULL
        AND quantity >= 0
        AND unit_price IS NOT NULL
      )
    )
);

COMMENT ON TABLE public."ProposalLines" IS 'Lines of a Proposal: from_quote (QuoteLine + overrides) or custom (extras).';
COMMENT ON COLUMN public."ProposalLines"."quote_line_id" IS 'Required when line_type = from_quote. Optional override: discount_pct, markup_pct, or fixed_unit_price.';
COMMENT ON COLUMN public."ProposalLines"."description" IS 'Required for custom lines (e.g. Installation, Transport).';
COMMENT ON COLUMN public."ProposalLines"."custom_category" IS 'Category for custom line: installation, transportation, other.';

-- ============================================================
-- 3b) Trigger: validate quote_line_id belongs to Proposal's Quote
-- ============================================================
CREATE OR REPLACE FUNCTION public.proposal_lines_validate_quote_line()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.quote_line_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public."Proposals" p
      JOIN public."QuoteLines" ql ON ql.id = NEW.quote_line_id
      WHERE p.id = NEW.proposal_id AND ql.quote_id = p.quote_id
    ) THEN
      RAISE EXCEPTION 'ProposalLine quote_line_id must belong to the same Quote as the Proposal';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_proposal_lines_validate_quote_line
  BEFORE INSERT OR UPDATE OF quote_line_id, proposal_id
  ON public."ProposalLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.proposal_lines_validate_quote_line();

-- ============================================================
-- 4) Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_proposals_organization_id
  ON public."Proposals"(organization_id) WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_proposals_quote_id
  ON public."Proposals"(quote_id) WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_proposals_dealer_id
  ON public."Proposals"(dealer_id) WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_proposals_customer_id
  ON public."Proposals"(customer_id) WHERE (customer_id IS NOT NULL AND deleted = false);

CREATE INDEX IF NOT EXISTS idx_proposals_status
  ON public."Proposals"(status) WHERE deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_proposals_org_proposal_no
  ON public."Proposals"(organization_id, proposal_no)
  WHERE (deleted = false AND proposal_no IS NOT NULL AND proposal_no <> '');

CREATE INDEX IF NOT EXISTS idx_proposallines_proposal_id
  ON public."ProposalLines"(proposal_id);

CREATE INDEX IF NOT EXISTS idx_proposallines_quote_line_id
  ON public."ProposalLines"(quote_line_id)
  WHERE quote_line_id IS NOT NULL;

-- ============================================================
-- 5) Trigger: updated_at for Proposals
-- ============================================================
CREATE TRIGGER trg_proposals_updated_at
  BEFORE UPDATE ON public."Proposals"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 6) Trigger: updated_at for ProposalLines
-- ============================================================
CREATE TRIGGER trg_proposal_lines_updated_at
  BEFORE UPDATE ON public."ProposalLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 7) RLS: Proposals
-- ============================================================
ALTER TABLE public."Proposals" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proposals_select ON public."Proposals";
CREATE POLICY proposals_select
  ON public."Proposals" FOR SELECT
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user(dealer_id))
  );

DROP POLICY IF EXISTS proposals_insert ON public."Proposals";
CREATE POLICY proposals_insert
  ON public."Proposals" FOR INSERT
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(dealer_id))
  );

DROP POLICY IF EXISTS proposals_update ON public."Proposals";
CREATE POLICY proposals_update
  ON public."Proposals" FOR UPDATE
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(dealer_id))
  )
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(dealer_id))
  );

DROP POLICY IF EXISTS proposals_delete ON public."Proposals";
CREATE POLICY proposals_delete
  ON public."Proposals" FOR DELETE
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(dealer_id))
  );

-- ============================================================
-- 8) RLS: ProposalLines (access follows Proposal; insert must match Proposal ownership)
-- ============================================================
ALTER TABLE public."ProposalLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proposallines_select ON public."ProposalLines";
CREATE POLICY proposallines_select
  ON public."ProposalLines" FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS proposallines_insert ON public."ProposalLines";
CREATE POLICY proposallines_insert
  ON public."ProposalLines" FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND p.deleted = false
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS proposallines_update ON public."ProposalLines";
CREATE POLICY proposallines_update
  ON public."ProposalLines" FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS proposallines_delete ON public."ProposalLines";
CREATE POLICY proposallines_delete
  ON public."ProposalLines" FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  );

COMMIT;

-- ============================================================
-- SUGERENCIA FLUJO UI MÍNIMO (MVP)
-- ============================================================
-- 1) Botón "Create Proposal from Quote": en detalle de Quote, acción que
--    crea un registro en Proposals (quote_id, customer_id/contact_id desde Quote,
--    dealer_id, organization_id) y opcionalmente copia cada QuoteLine como
--    ProposalLine con line_type='from_quote' y quote_line_id apuntando a la línea.
--
-- 2) Lista Proposals por Quote y por Dealer: vista que filtra Proposals por
--    quote_id (en detalle de Quote) o por dealer_id (en portal del dealer);
--    mostrar proposal_no, status, customer, fecha.
--
-- 3) Editor de ProposalLines: en detalle de Proposal, permitir
--    - editar overrides por línea from_quote (descuento %, markup %, precio fijo);
--    - añadir líneas custom (descripción, cantidad, precio unitario, categoría);
--    - reordenar (sort_order).
--
-- 4) Botón "Generate PDF": construir PDF desde Proposal + ProposalLines (sin BOM/costos),
--    aplicando global_discount_pct y global_fee_amount al total.
