-- Add notes column to Quotes so UI field "Note" can persist and feed PDF "Notas".
-- Prevents: Could not find the 'notes' column of 'Quotes' in the schema cache (PGRST204)

ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS notes text;

COMMENT ON COLUMN public."Quotes".notes IS
  'Printable note for quote PDF left block (Notas). Distinct from description.';
