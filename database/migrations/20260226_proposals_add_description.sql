-- Add description column to Proposals (short description; notes = Notes / Terms and Conditions).
ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS description text;

COMMENT ON COLUMN public."Proposals"."description" IS 'Short proposal description (header). Use notes for Notes / Terms and Conditions.';
