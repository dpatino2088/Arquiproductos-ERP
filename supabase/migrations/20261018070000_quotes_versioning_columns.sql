-- Quote versioning: add parent/root/version columns, backfill root_quote_id=id, add indexes

ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS parent_quote_id uuid REFERENCES public."Quotes"(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS root_quote_id uuid REFERENCES public."Quotes"(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS version_no int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_version boolean DEFAULT false;

UPDATE public."Quotes" SET root_quote_id = id WHERE root_quote_id IS NULL;
UPDATE public."Quotes" SET version_no = 1 WHERE version_no IS NULL;
UPDATE public."Quotes" SET is_version = false WHERE is_version IS NULL;

ALTER TABLE public."Quotes" ALTER COLUMN version_no SET NOT NULL;
ALTER TABLE public."Quotes" ALTER COLUMN is_version SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quotes_root_quote_id ON public."Quotes"(root_quote_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_quotes_parent_quote_id ON public."Quotes"(parent_quote_id) WHERE deleted = false;
