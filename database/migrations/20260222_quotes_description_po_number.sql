-- Add description and po_number to Quotes for Dealer use (description = label for notes; PO = tracking number)
BEGIN;

-- description: free text for quote description (replaces/labels "notes" in UI)
ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS description text;

-- po_number: dealer's PO tracking number (optional)
ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS po_number text;

COMMENT ON COLUMN public."Quotes".description IS 'Quote description or notes. Shown as Description in UI.';
COMMENT ON COLUMN public."Quotes".po_number IS 'Dealer PO / order tracking number (optional).';

COMMIT;
