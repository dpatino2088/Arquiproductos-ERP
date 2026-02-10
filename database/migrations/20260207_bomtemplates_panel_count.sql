-- BOMTemplates: add panel_count_min / panel_count_max for filtering by number of panels (1-3).
-- Filter order: product_type_id -> panel_count -> color -> rest.

-- 1) Add columns
ALTER TABLE public."BOMTemplates"
  ADD COLUMN IF NOT EXISTS panel_count_min int NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS panel_count_max int NOT NULL DEFAULT 1;

-- 2) Backfill existing rows (single panel, not interconnected)
UPDATE public."BOMTemplates"
SET panel_count_min = 1, panel_count_max = 1
WHERE panel_count_min IS NULL OR panel_count_max IS NULL;

-- 3) Enforce NOT NULL (in case add was with NULL default elsewhere)
ALTER TABLE public."BOMTemplates"
  ALTER COLUMN panel_count_min SET DEFAULT 1,
  ALTER COLUMN panel_count_max SET DEFAULT 1;

-- 4) Optional index for filter order: product_type_id, panel_count range, color
CREATE INDEX IF NOT EXISTS idx_bomtemplates_product_type_panel_count_color
  ON public."BOMTemplates" (product_type_id, panel_count_min, panel_count_max, hardware_color)
  WHERE is_active = true AND (archived = false OR archived IS NULL);

COMMENT ON COLUMN public."BOMTemplates".panel_count_min IS 'Minimum number of panels (paños) this template supports (1-3).';
COMMENT ON COLUMN public."BOMTemplates".panel_count_max IS 'Maximum number of panels (paños) this template supports (1-3).';
