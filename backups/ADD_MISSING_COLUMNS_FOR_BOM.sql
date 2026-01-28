-- ====================================================
-- Agregar columnas faltantes para BOM Configurator
-- ====================================================
-- Basado en análisis del UI y flujo de Quote → BOM
-- Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
-- ====================================================

BEGIN;

DO $$
DECLARE
  v_col_exists boolean;
BEGIN
  RAISE NOTICE '🔧 Agregando columnas faltantes a QuoteLines...';

  -- ====================================================
  -- QUOTELINES: Campos de configuración
  -- ====================================================

  -- 1. product_type (text)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'product_type'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN product_type text;
    RAISE NOTICE '✅ Added product_type';
  ELSE
    RAISE NOTICE 'ℹ️  product_type ya existe';
  END IF;

  -- 2. area (text)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'area'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN area text;
    RAISE NOTICE '✅ Added area';
  ELSE
    RAISE NOTICE 'ℹ️  area ya existe';
  END IF;

  -- 3. position (text)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'position'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN position text;
    RAISE NOTICE '✅ Added position';
  ELSE
    RAISE NOTICE 'ℹ️  position ya existe';
  END IF;

  -- 4. hardware_color (text)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'hardware_color'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN hardware_color text;
    COMMENT ON COLUMN public."QuoteLines".hardware_color IS 'Hardware color: white, black, silver, bronze, etc.';
    RAISE NOTICE '✅ Added hardware_color';
  ELSE
    RAISE NOTICE 'ℹ️  hardware_color ya existe';
  END IF;

  -- 5. cassette (boolean)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'cassette'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN cassette boolean DEFAULT false;
    COMMENT ON COLUMN public."QuoteLines".cassette IS 'Cassette enabled (headbox)';
    RAISE NOTICE '✅ Added cassette';
  ELSE
    RAISE NOTICE 'ℹ️  cassette ya existe';
  END IF;

  -- 6. side_channel (boolean)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'side_channel'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN side_channel boolean DEFAULT false;
    COMMENT ON COLUMN public."QuoteLines".side_channel IS 'Side channel enabled';
    RAISE NOTICE '✅ Added side_channel';
  ELSE
    RAISE NOTICE 'ℹ️  side_channel ya existe';
  END IF;

  -- 7. drive_type (text)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'drive_type'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN drive_type text;
    COMMENT ON COLUMN public."QuoteLines".drive_type IS 'Drive type: manual, motor';
    RAISE NOTICE '✅ Added drive_type';
  ELSE
    RAISE NOTICE 'ℹ️  drive_type ya existe';
  END IF;

  -- 8. bom_template_id (uuid FK)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'bom_template_id'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN bom_template_id uuid;
    
    -- Add FK if BOMTemplates exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'BOMTemplates') THEN
      ALTER TABLE public."QuoteLines"
        ADD CONSTRAINT fk_quote_lines_bom_template
        FOREIGN KEY (bom_template_id)
        REFERENCES public."BOMTemplates"(id)
        ON DELETE SET NULL;
      RAISE NOTICE '✅ Added bom_template_id with FK';
    ELSE
      RAISE NOTICE '✅ Added bom_template_id (FK pending - BOMTemplates not found)';
    END IF;
  ELSE
    RAISE NOTICE 'ℹ️  bom_template_id ya existe';
  END IF;

  -- ====================================================
  -- BOMCOMPONENTS: Campo is_required
  -- ====================================================

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'is_required'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."BOMComponents" ADD COLUMN is_required boolean DEFAULT false NOT NULL;
    COMMENT ON COLUMN public."BOMComponents".is_required IS 'Component is required for BOM';
    RAISE NOTICE '✅ Added is_required to BOMComponents';
  ELSE
    RAISE NOTICE 'ℹ️  is_required ya existe en BOMComponents';
  END IF;

  -- ====================================================
  -- Crear índices
  -- ====================================================

  CREATE INDEX IF NOT EXISTS idx_quote_lines_product_type 
    ON public."QuoteLines"(product_type) 
    WHERE product_type IS NOT NULL;

  CREATE INDEX IF NOT EXISTS idx_quote_lines_bom_template_id 
    ON public."QuoteLines"(bom_template_id) 
    WHERE bom_template_id IS NOT NULL;

  RAISE NOTICE '✅ Índices creados';

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Migración completada';
  RAISE NOTICE '📝 QuoteLines ahora tiene todos los campos para BOM';
  RAISE NOTICE '========================================';

END $$;

COMMIT;

-- Verificación final
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'QuoteLines'
  AND column_name IN ('product_type', 'area', 'position', 'hardware_color', 'cassette', 'side_channel', 'drive_type', 'bom_template_id')
ORDER BY column_name;
