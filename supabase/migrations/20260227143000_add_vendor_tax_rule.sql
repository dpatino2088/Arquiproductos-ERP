-- Add vendor tax rule to support local vs international purchases.
-- taxable: local vendor purchase with tax
-- tax_exempt: international purchase without tax

ALTER TABLE public."DirectoryVendors"
  ADD COLUMN IF NOT EXISTS tax_rule text NOT NULL DEFAULT 'taxable';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_directory_vendors_tax_rule'
      AND conrelid = 'public."DirectoryVendors"'::regclass
  ) THEN
    ALTER TABLE public."DirectoryVendors"
      ADD CONSTRAINT chk_directory_vendors_tax_rule
      CHECK (tax_rule IN ('taxable', 'tax_exempt'));
  END IF;
END
$$;
