-- ====================================================
-- MIGRATION: Restaurar columnas faltantes en ConfiguredProducts
-- Date: 2026-01-24
-- Description: 
--   Restaura las columnas de componentes que fueron eliminadas por error
--   de la tabla ConfiguredProducts. Usa IF NOT EXISTS para ser idempotente.
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Verificar y restaurar columnas de componentes
-- ====================================================

DO $$
BEGIN
    -- bottom_bar_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'bottom_bar_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "bottom_bar_item_id" uuid;
        RAISE NOTICE '✅ Columna bottom_bar_item_id agregada';
    END IF;

    -- bottom_bar_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'bottom_bar_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "bottom_bar_sku" text;
        RAISE NOTICE '✅ Columna bottom_bar_sku agregada';
    END IF;

    -- headbox_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'headbox_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "headbox_item_id" uuid;
        RAISE NOTICE '✅ Columna headbox_item_id agregada';
    END IF;

    -- headbox_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'headbox_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "headbox_sku" text;
        RAISE NOTICE '✅ Columna headbox_sku agregada';
    END IF;

    -- side_channel_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'side_channel_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "side_channel_item_id" uuid;
        RAISE NOTICE '✅ Columna side_channel_item_id agregada';
    END IF;

    -- side_channel_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'side_channel_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "side_channel_sku" text;
        RAISE NOTICE '✅ Columna side_channel_sku agregada';
    END IF;

    -- bottom_channel_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'bottom_channel_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "bottom_channel_item_id" uuid;
        RAISE NOTICE '✅ Columna bottom_channel_item_id agregada';
    END IF;

    -- bottom_channel_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'bottom_channel_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "bottom_channel_sku" text;
        RAISE NOTICE '✅ Columna bottom_channel_sku agregada';
    END IF;

    -- motor_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'motor_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "motor_item_id" uuid;
        RAISE NOTICE '✅ Columna motor_item_id agregada';
    END IF;

    -- motor_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'motor_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "motor_sku" text;
        RAISE NOTICE '✅ Columna motor_sku agregada';
    END IF;

    -- drive_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'drive_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "drive_item_id" uuid;
        RAISE NOTICE '✅ Columna drive_item_id agregada';
    END IF;

    -- drive_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'drive_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "drive_sku" text;
        RAISE NOTICE '✅ Columna drive_sku agregada';
    END IF;

    -- tube_item_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'tube_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "tube_item_id" uuid;
        RAISE NOTICE '✅ Columna tube_item_id agregada';
    END IF;

    -- tube_sku
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'tube_sku'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "tube_sku" text;
        RAISE NOTICE '✅ Columna tube_sku agregada';
    END IF;

    -- operating_type
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'operating_type'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
        ADD COLUMN "operating_type" text;
        RAISE NOTICE '✅ Columna operating_type agregada';
    END IF;

    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ Migración completada: Columnas de ConfiguredProducts restauradas';
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
END $$;

COMMIT;

-- ====================================================
-- NOTAS POST-MIGRACIÓN:
-- ====================================================
-- 1. ✅ Todas las columnas de componentes han sido restauradas
-- 2. ✅ La migración es idempotente (puede ejecutarse múltiples veces)
-- 3. ✅ Las columnas se agregaron como NULL para no afectar datos existentes
-- ====================================================
