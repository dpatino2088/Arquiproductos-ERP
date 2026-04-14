-- Archive (hide from main list); only cancelled/rejected/expired can be archived.
ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false;

ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public."Quotes".archived IS 'Archived quotes (cancelled/rejected/expired) hidden from main list; visible in Archivados tab.';
COMMENT ON COLUMN public."Proposals".archived IS 'Archived proposals (cancelled/rejected/expired) hidden from main list; visible in Archivados tab.';;
