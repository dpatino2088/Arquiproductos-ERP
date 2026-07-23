-- Expand proposal custom categories to match Quote custom lines
ALTER TYPE public.proposal_custom_category ADD VALUE IF NOT EXISTS 'product';
ALTER TYPE public.proposal_custom_category ADD VALUE IF NOT EXISTS 'shipping';
ALTER TYPE public.proposal_custom_category ADD VALUE IF NOT EXISTS 'made_to_measure';

-- MTM fields on ProposalLines (mirror QuoteLines custom MTM)
ALTER TABLE public."ProposalLines"
  ADD COLUMN IF NOT EXISTS width_m numeric,
  ADD COLUMN IF NOT EXISTS height_m numeric,
  ADD COLUMN IF NOT EXISTS product_type_id uuid REFERENCES public."ProductTypes"(id),
  ADD COLUMN IF NOT EXISTS drive_type text;

COMMENT ON COLUMN public."ProposalLines".width_m IS 'MTM custom lines only: width in meters (UI enters mm)';
COMMENT ON COLUMN public."ProposalLines".height_m IS 'MTM custom lines only: height in meters (UI enters mm)';
COMMENT ON COLUMN public."ProposalLines".product_type_id IS 'MTM custom lines: product type for manufacturing';
COMMENT ON COLUMN public."ProposalLines".drive_type IS 'MTM custom lines: manual | motor';
