-- Add logo URL to Dealers for display on Proposals and PDF
ALTER TABLE public."Dealers"
  ADD COLUMN IF NOT EXISTS logo_url text;

COMMENT ON COLUMN public."Dealers"."logo_url" IS 'URL of dealer logo (e.g. from storage). Shown on Proposal detail and print/PDF.';
