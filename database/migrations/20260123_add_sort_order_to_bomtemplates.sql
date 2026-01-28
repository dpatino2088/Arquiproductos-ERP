-- Add sort_order column to BOMTemplates for drag-and-drop reordering

BEGIN;

DO $$
DECLARE
  v_col_exists boolean;
BEGIN
  -- Check if sort_order column exists
  SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'BOMTemplates'
      AND column_name = 'sort_order'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."BOMTemplates" 
      ADD COLUMN sort_order integer DEFAULT 0 NOT NULL;
    
    -- Initialize sort_order based on created_at for existing templates
    UPDATE public."BOMTemplates"
    SET sort_order = subquery.row_number
    FROM (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY created_at ASC) as row_number
      FROM public."BOMTemplates"
    ) AS subquery
    WHERE public."BOMTemplates".id = subquery.id;
    
    COMMENT ON COLUMN public."BOMTemplates".sort_order IS 
      'Display order for templates (lower numbers appear first). Used for drag-and-drop reordering.';
    
    RAISE NOTICE '✅ Added sort_order column to BOMTemplates and initialized with existing order';
  ELSE
    RAISE NOTICE 'ℹ️  sort_order column already exists in BOMTemplates';
  END IF;
END $$;

COMMIT;
