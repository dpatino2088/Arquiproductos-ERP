-- ====================================================
-- ADD FABRIC COLUMNS TO CATALOGITEMS
-- ====================================================
-- Agrega columnas necesarias para specs de fabrics
-- IDEMPOTENTE: Se puede ejecutar múltiples veces
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '🚀 Agregando columnas de fabric specs a CatalogItems';
    RAISE NOTICE '====================================================';
    
    -- Gramaje (peso de la tela en gramos por metro cuadrado)
    -- Puede que ya exista como weight_gsm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'weight_gsm'
    ) THEN
        ALTER TABLE "CatalogItems" 
        ADD COLUMN weight_gsm NUMERIC(10,2) NULL;
        RAISE NOTICE '✅ Columna weight_gsm agregada';
    ELSE
        RAISE NOTICE 'ℹ️  Columna weight_gsm ya existe';
    END IF;
    
    -- Apertura / Openness (para telas screen)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'openness'
    ) THEN
        ALTER TABLE "CatalogItems" 
        ADD COLUMN openness TEXT NULL;
        RAISE NOTICE '✅ Columna openness agregada';
    ELSE
        RAISE NOTICE 'ℹ️  Columna openness ya existe';
    END IF;
    
    -- Composición del material (ej: "100% Polyester", "PVC 80% + Fiberglass 20%")
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'composition'
    ) THEN
        ALTER TABLE "CatalogItems" 
        ADD COLUMN composition TEXT NULL;
        RAISE NOTICE '✅ Columna composition agregada';
    ELSE
        RAISE NOTICE 'ℹ️  Columna composition ya existe';
    END IF;
    
    -- Stock status (stock, por_pedido, descontinuado)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'stock_status'
    ) THEN
        ALTER TABLE "CatalogItems" 
        ADD COLUMN stock_status TEXT NULL 
        CHECK (stock_status IN ('stock', 'por_pedido', 'descontinuado', NULL));
        RAISE NOTICE '✅ Columna stock_status agregada';
    ELSE
        RAISE NOTICE 'ℹ️  Columna stock_status ya existe';
    END IF;
    
    -- Verificar columnas que deberían existir
    RAISE NOTICE '';
    RAISE NOTICE '📋 Verificando otras columnas importantes:';
    
    -- roll_width_m (ancho del rollo en metros)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'roll_width_m'
    ) THEN
        RAISE NOTICE '✅ roll_width_m ya existe';
    ELSE
        ALTER TABLE "CatalogItems" 
        ADD COLUMN roll_width_m NUMERIC(10,2) NULL;
        RAISE NOTICE '✅ Columna roll_width_m agregada';
    END IF;
    
    -- can_rotate (si la tela se puede rotar para optimizar)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'can_rotate'
    ) THEN
        RAISE NOTICE '✅ can_rotate ya existe';
    ELSE
        ALTER TABLE "CatalogItems" 
        ADD COLUMN can_rotate BOOLEAN DEFAULT false;
        RAISE NOTICE '✅ Columna can_rotate agregada';
    END IF;
    
    -- can_heatseal (si la tela se puede heat-seal)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'can_heatseal'
    ) THEN
        RAISE NOTICE '✅ can_heatseal ya existe';
    ELSE
        ALTER TABLE "CatalogItems" 
        ADD COLUMN can_heatseal BOOLEAN DEFAULT false;
        RAISE NOTICE '✅ Columna can_heatseal agregada';
    END IF;
    
    -- heatseal_price_per_meter (precio del heat-seal por metro)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'heatseal_price_per_meter'
    ) THEN
        RAISE NOTICE '✅ heatseal_price_per_meter ya existe';
    ELSE
        ALTER TABLE "CatalogItems" 
        ADD COLUMN heatseal_price_per_meter NUMERIC(10,2) NULL;
        RAISE NOTICE '✅ Columna heatseal_price_per_meter agregada';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ MIGRACIÓN COMPLETADA';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Columnas de fabric specs disponibles:';
    RAISE NOTICE '   - roll_width_m (ancho del rollo en metros)';
    RAISE NOTICE '   - weight_gsm (gramaje g/m²)';
    RAISE NOTICE '   - openness (apertura para screens)';
    RAISE NOTICE '   - composition (composición del material)';
    RAISE NOTICE '   - can_rotate (si se puede rotar)';
    RAISE NOTICE '   - can_heatseal (si se puede heat-seal)';
    RAISE NOTICE '   - heatseal_price_per_meter (precio heat-seal)';
    RAISE NOTICE '   - stock_status (stock, por_pedido, descontinuado)';
    
END $$;










