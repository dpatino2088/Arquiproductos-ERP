-- BOMTemplateSlots: selection_mode, fixed_catalog_item_id, slot_sku
-- Stop depending on notes "Fixed SKU: …"; make filtering stable.
-- 1) Add columns
-- 2) Data migration from notes
-- 3) Trigger to keep slot_sku in sync

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) ADD COLUMNS
-- ---------------------------------------------------------------------------
ALTER TABLE public."BOMTemplateSlots"
  ADD COLUMN IF NOT EXISTS selection_mode text NOT NULL DEFAULT 'user_select',
  ADD COLUMN IF NOT EXISTS fixed_catalog_item_id uuid NULL,
  ADD COLUMN IF NOT EXISTS slot_sku text NULL;

-- Constrain allowed values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bomtemplateslots_selection_mode_check'
  ) THEN
    ALTER TABLE public."BOMTemplateSlots"
      ADD CONSTRAINT bomtemplateslots_selection_mode_check
      CHECK (selection_mode IN ('user_select', 'fixed', 'none_allowed'));
  END IF;
END $$;

-- FK for fixed_catalog_item_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'BOMTemplateSlots_fixed_catalog_item_id_fkey'
  ) THEN
    ALTER TABLE public."BOMTemplateSlots"
      ADD CONSTRAINT "BOMTemplateSlots_fixed_catalog_item_id_fkey"
      FOREIGN KEY (fixed_catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2) DATA MIGRATION: notes ILIKE '%Fixed SKU:%'
-- ---------------------------------------------------------------------------
WITH extracted AS (
  SELECT
    bts.id,
    bts.organization_id,
    bts.notes,
    trim(regexp_replace(trim(bts.notes), '^.*Fixed SKU:\s*', '', 'i')) AS extracted_sku
  FROM public."BOMTemplateSlots" bts
  WHERE bts.notes IS NOT NULL
    AND bts.notes ILIKE '%Fixed SKU:%'
    AND trim(regexp_replace(trim(bts.notes), '^.*Fixed SKU:\s*', '', 'i')) <> ''
),
matched AS (
  SELECT
    e.id,
    e.organization_id,
    e.extracted_sku,
    (SELECT ci.id
     FROM public."CatalogItems" ci
     WHERE ci.organization_id = e.organization_id
       AND trim(ci.sku) = e.extracted_sku
       AND ci.is_active = true
     LIMIT 1) AS catalog_id
  FROM extracted e
)
UPDATE public."BOMTemplateSlots" bts
SET
  selection_mode = 'fixed',
  fixed_catalog_item_id = m.catalog_id,
  slot_sku = m.extracted_sku,
  notes = NULL
FROM matched m
WHERE bts.id = m.id
  AND m.catalog_id IS NOT NULL;

-- Optional: clear notes for "Fixed SKU" rows where we didn't find a CatalogItem
-- (leave selection_mode as user_select, clear notes only)
WITH extracted AS (
  SELECT bts.id
  FROM public."BOMTemplateSlots" bts
  WHERE bts.notes IS NOT NULL AND bts.notes ILIKE '%Fixed SKU:%'
)
UPDATE public."BOMTemplateSlots" bts
SET notes = NULL
FROM extracted e
WHERE bts.id = e.id AND bts.selection_mode = 'user_select';

-- ---------------------------------------------------------------------------
-- 3) TRIGGER: sync slot_sku when catalog_item_id or fixed_catalog_item_id change
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_bom_template_slot_sku()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_item_id uuid;
  v_sku text;
BEGIN
  v_item_id := COALESCE(NEW.fixed_catalog_item_id, NEW.catalog_item_id);
  IF v_item_id IS NULL THEN
    NEW.slot_sku := NULL;
    RETURN NEW;
  END IF;

  SELECT trim(ci.sku) INTO v_sku
  FROM public."CatalogItems" ci
  WHERE ci.id = v_item_id
    AND (ci.organization_id = NEW.organization_id OR ci.organization_id IS NULL)
  LIMIT 1;

  NEW.slot_sku := v_sku;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_bom_template_slot_sku ON public."BOMTemplateSlots";
CREATE TRIGGER trg_sync_bom_template_slot_sku
  BEFORE INSERT OR UPDATE OF catalog_item_id, fixed_catalog_item_id
  ON public."BOMTemplateSlots"
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_bom_template_slot_sku();

-- Backfill slot_sku for existing rows (fixed + user_select with catalog_item_id)
UPDATE public."BOMTemplateSlots" bts
SET slot_sku = sub.sku
FROM (
  SELECT
    b.id,
    trim(ci.sku) AS sku
  FROM public."BOMTemplateSlots" b
  JOIN public."CatalogItems" ci
    ON ci.id = COALESCE(b.fixed_catalog_item_id, b.catalog_item_id)
   AND (ci.organization_id = b.organization_id OR ci.organization_id IS NULL)
  WHERE COALESCE(b.fixed_catalog_item_id, b.catalog_item_id) IS NOT NULL
) sub
WHERE bts.id = sub.id
  AND (bts.slot_sku IS DISTINCT FROM sub.sku);

COMMIT;
