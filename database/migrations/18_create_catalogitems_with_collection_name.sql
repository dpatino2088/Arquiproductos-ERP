-- ====================================================
-- Script para crear CatalogItems con collection_name
-- ====================================================
-- Este script crea la tabla CatalogItems si no existe
-- e incluye collection_name desde el inicio (sin FK)
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Creando tabla CatalogItems con collection_name...';

  -- ====================================================
  -- STEP 1: Crear la tabla CatalogItems si no existe
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) THEN
    RAISE NOTICE '📝 Creando tabla CatalogItems...';
    
    CREATE TABLE IF NOT EXISTS public."CatalogItems" (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
      
      -- Basic information
      sku text NOT NULL,
      name text,
      item_name text,  -- Nombre del item desde CSV
      description text,
      
      -- Relationships (sin FK para collection_name)
      manufacturer_id uuid REFERENCES "Manufacturers"(id) ON DELETE SET NULL,
      item_category_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL,
      collection_id uuid,  -- Mantenido por compatibilidad, sin FK
      collection_name text,  -- NUEVO: nombre directo sin FK
      
      -- Variant
      variant_name text,  -- Nombre de variante (texto, no FK)
      
      -- Item type
      item_type text,
      
      -- Measurement and pricing
      measure_basis text,  -- Cambiado de enum a text para flexibilidad
      uom text NOT NULL DEFAULT 'unit',
      
      -- Fabric-specific fields
      is_fabric boolean NOT NULL DEFAULT false,
      roll_width_m numeric(10, 3),
      fabric_pricing_mode text,  -- Cambiado de enum a text
      
      -- Pricing
      unit_price numeric(12, 2) NOT NULL DEFAULT 0,
      cost_price numeric(12, 2) NOT NULL DEFAULT 0,
      cost_exw numeric(12, 2) NOT NULL DEFAULT 0,  -- Costo EXW desde staging
      
      -- Status
      active boolean NOT NULL DEFAULT true,
      discontinued boolean NOT NULL DEFAULT false,
      
      -- Metadata
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      
      -- Audit fields
      deleted boolean NOT NULL DEFAULT false,
      archived boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      created_by uuid,
      updated_by uuid
    );

    RAISE NOTICE '✅ Tabla CatalogItems creada';

    -- ====================================================
    -- STEP 2: Crear índices
    -- ====================================================
    CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_items_org_sku_unique 
      ON "CatalogItems"(organization_id, sku) 
      WHERE deleted = false;

    CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_id 
      ON "CatalogItems"(organization_id);

    CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_deleted 
      ON "CatalogItems"(organization_id, deleted);

    CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_active 
      ON "CatalogItems"(organization_id, active, deleted);

    CREATE INDEX IF NOT EXISTS idx_catalog_items_sku 
      ON "CatalogItems"(sku);

    CREATE INDEX IF NOT EXISTS idx_catalog_items_is_fabric 
      ON "CatalogItems"(is_fabric) WHERE is_fabric = true;

    CREATE INDEX IF NOT EXISTS idx_catalog_items_collection_name 
      ON "CatalogItems"(collection_name) WHERE collection_name IS NOT NULL;

    RAISE NOTICE '✅ Índices creados';

  ELSE
    RAISE NOTICE 'ℹ️  La tabla CatalogItems ya existe';
    
    -- ====================================================
    -- STEP 3: Agregar collection_name si no existe
    -- ====================================================
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'collection_name'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN collection_name text;
      
      CREATE INDEX IF NOT EXISTS idx_catalog_items_collection_name 
        ON "CatalogItems"(collection_name) WHERE collection_name IS NOT NULL;
      
      RAISE NOTICE '✅ Columna collection_name agregada';
    ELSE
      RAISE NOTICE 'ℹ️  La columna collection_name ya existe';
    END IF;

    -- ====================================================
    -- STEP 4: Agregar otras columnas si no existen
    -- ====================================================
    
    -- item_name
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'item_name'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN item_name text;
      RAISE NOTICE '✅ Columna item_name agregada';
    END IF;

    -- variant_name
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'variant_name'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN variant_name text;
      RAISE NOTICE '✅ Columna variant_name agregada';
    END IF;

    -- item_type
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'item_type'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN item_type text;
      RAISE NOTICE '✅ Columna item_type agregada';
    END IF;

    -- cost_exw
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'cost_exw'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN cost_exw numeric(12, 2) NOT NULL DEFAULT 0;
      RAISE NOTICE '✅ Columna cost_exw agregada';
    END IF;

    -- manufacturer_id
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'manufacturer_id'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN manufacturer_id uuid REFERENCES "Manufacturers"(id) ON DELETE SET NULL;
      RAISE NOTICE '✅ Columna manufacturer_id agregada';
    END IF;

    -- item_category_id
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems' 
        AND column_name = 'item_category_id'
    ) THEN
      ALTER TABLE public."CatalogItems" 
      ADD COLUMN item_category_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL;
      RAISE NOTICE '✅ Columna item_category_id agregada';
    END IF;

  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Proceso completado!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 La tabla CatalogItems está lista con collection_name (sin FK)';

END $$;

