SET search_path = public;

ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS project_address text;
