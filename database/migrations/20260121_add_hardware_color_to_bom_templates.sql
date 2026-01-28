-- Migration: Add hardware_color column to BOMTemplates
-- Date: 2026-01-21
-- Description: Agrega campo hardware_color a BOMTemplates para poder diferenciar templates por color (White/Black/etc)
-- 
-- Este campo es MANDATORIO y permite que cuando hay múltiples templates para el mismo ProductType,
-- se pueda seleccionar el correcto basándose en el color del hardware seleccionado en el configurador.
-- 
-- NOTA: Inicialmente se crea como NULL para permitir migración de datos existentes,
-- pero debería ser actualizado a NOT NULL después de migrar los templates existentes.

BEGIN;

-- Agregar columna hardware_color a BOMTemplates si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMTemplates' 
        AND column_name = 'hardware_color'
    ) THEN
        ALTER TABLE "public"."BOMTemplates"
        ADD COLUMN "hardware_color" text NULL;

        -- Agregar comentario
        COMMENT ON COLUMN "public"."BOMTemplates"."hardware_color" IS 
        'Hardware color (White, Black, Silver, Bronze, etc.) to differentiate templates for the same product type. MANDATORY field to filter templates in the product configurator.';
        
        RAISE NOTICE '✅ Added hardware_color column to BOMTemplates';
    ELSE
        RAISE NOTICE '⚠️ Column hardware_color already exists in BOMTemplates';
    END IF;
END $$;

COMMIT;
