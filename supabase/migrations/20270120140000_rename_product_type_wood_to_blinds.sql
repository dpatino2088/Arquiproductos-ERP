-- Display name only: the "wood" ProductType is shown as "Blinds" across the app
-- (Custom Item modal, configurator card, quote/proposal lines, PDFs).
-- The `code` stays 'wood' because the configurator, BOM templates and
-- resolveProductTypeId() match on it, and lines reference the row by id.

SET search_path = public;

UPDATE public."ProductTypes"
SET name = 'Blinds',
    updated_at = now()
WHERE code = 'wood'
  AND name <> 'Blinds';
