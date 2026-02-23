-- ====================================================
-- Migration 20260325: QT y PRO consecutivos por dealer_id
-- ====================================================
-- Cada dealer_id tiene su propia secuencia independiente:
--   Dealer A: QT-000001, QT-000002, ...
--   Dealer B: QT-000001, QT-000002, ...
--   Igual para PRO (Proposals).
--
-- Cambios:
-- 1) Quotes: unique (organization_id, quote_no) → (organization_id, dealer_id, quote_no)
-- 2) Proposals: unique (organization_id, proposal_no) → (organization_id, dealer_id, proposal_no)
--
-- Nota: Quotes con dealer_id NULL comparten una secuencia (pool "sin dealer").
-- Proposals siempre tienen dealer_id (obligatorio).
-- ====================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) Quotes: nuevo unique por (organization_id, dealer_id, quote_no)
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS public.quotes_org_quote_no_unique;
DROP INDEX IF EXISTS public.quotes_unique_no;

-- Índice único: org + dealer + quote_no. dealer_id NULL tratado como distinto (cada NULL es único en PG)
CREATE UNIQUE INDEX quotes_org_dealer_quote_no_unique
  ON public."Quotes" (organization_id, dealer_id, quote_no)
  WHERE deleted = false;

COMMENT ON INDEX public.quotes_org_dealer_quote_no_unique IS
'Quote numbers are unique per organization and per dealer. Each dealer has independent sequence (QT-000001, QT-000002...).';

-- ----------------------------------------------------------------------------
-- 2) Proposals: nuevo unique por (organization_id, dealer_id, proposal_no)
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS public.uq_proposals_org_proposal_no;

CREATE UNIQUE INDEX uq_proposals_org_dealer_proposal_no
  ON public."Proposals" (organization_id, dealer_id, proposal_no)
  WHERE deleted = false AND proposal_no IS NOT NULL AND proposal_no <> '';

COMMENT ON INDEX public.uq_proposals_org_dealer_proposal_no IS
'Proposal numbers are unique per organization and per dealer. Each dealer has independent sequence (PRO-0100, PRO-0101...).';

COMMIT;
