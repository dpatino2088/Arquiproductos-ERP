-- Add unit_cost to ProposalLines for custom lines (cost per unit; margin % = (unit_price - unit_cost) / unit_price)
ALTER TABLE public."ProposalLines"
  ADD COLUMN IF NOT EXISTS unit_cost numeric(12,4);

COMMENT ON COLUMN public."ProposalLines"."unit_cost" IS 'Unit cost for custom lines. Margin % on sale = (unit_price - unit_cost) / unit_price * 100.';

-- Add area and position for custom lines (e.g. "Cocina", "V.1")
ALTER TABLE public."ProposalLines"
  ADD COLUMN IF NOT EXISTS area text,
  ADD COLUMN IF NOT EXISTS position text;

COMMENT ON COLUMN public."ProposalLines"."area" IS 'Area/location for the line (custom lines).';
COMMENT ON COLUMN public."ProposalLines"."position" IS 'Position identifier for the line (custom lines).';
