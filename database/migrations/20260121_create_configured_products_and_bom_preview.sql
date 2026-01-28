-- ====================================================
-- Migration: Create ConfiguredProducts and enable BOM preview
-- Date: 2026-01-21
-- Description: 
--   1. Crea tabla ConfiguredProducts para snapshot de configuración antes de QuoteLine
--   2. Modifica BOMInstances para permitir configured_product_id (make quote_line_id nullable)
--   3. Agrega XOR constraint: exactamente uno de (quote_line_id, configured_product_id) debe ser not null
--   4. Crea funciones RPC para generar preview
--   5. Crea RLS policies
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 0: Actualizar constraint de item_role en CatalogItems
-- ====================================================
-- Necesitamos agregar los roles faltantes que están siendo usados en el sistema
-- Roles adicionales: motor, headbox, bottom_bar, side_channel, bottom_channel, drive
-- IMPORTANTE: Primero verificamos qué valores existen en la DB para incluirlos todos

DO $$
DECLARE
    v_role_list text[];
    v_all_roles text;
BEGIN
    -- Eliminar constraint existente si existe (para poder verificar valores actuales)
    ALTER TABLE "public"."CatalogItems"
        DROP CONSTRAINT IF EXISTS "catalogitems_item_role_check";
    
    -- Obtener lista de todos los roles únicos que existen en la tabla (excepto NULL)
    SELECT ARRAY_AGG(DISTINCT item_role ORDER BY item_role)
    INTO v_role_list
    FROM "public"."CatalogItems"
    WHERE item_role IS NOT NULL;
    
    -- Si no hay roles en la tabla, usar lista por defecto
    IF v_role_list IS NULL OR array_length(v_role_list, 1) IS NULL THEN
        v_role_list := ARRAY[
            -- Roles originales
            'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
            'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
            'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
            'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
            'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
            'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film',
            -- Roles adicionales usados en el sistema
            'motor', 'headbox', 'bottom_bar', 'side_channel', 'bottom_channel', 'drive'
        ];
    ELSE
        -- Combinar roles existentes con roles requeridos
        -- Agregar roles requeridos que puedan no estar en la tabla aún
        v_role_list := v_role_list || ARRAY[
            'motor', 'headbox', 'bottom_bar', 'side_channel', 'bottom_channel', 'drive',
            'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
            'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
            'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
            'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
            'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
            'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film'
        ];
        -- Eliminar duplicados y ordenar
        SELECT ARRAY(SELECT DISTINCT unnest(v_role_list) ORDER BY 1)
        INTO v_role_list;
    END IF;
    
    -- Construir lista de roles para el CHECK constraint
    -- Convertir array a string con formato IN (...)
    SELECT string_agg(quote_literal(role), ', ')
    INTO v_all_roles
    FROM unnest(v_role_list) AS role;
    
    -- Crear nuevo constraint con todos los roles (incluyendo los que existen en la DB)
    EXECUTE format(
        'ALTER TABLE "public"."CatalogItems" 
        ADD CONSTRAINT "catalogitems_item_role_check" 
        CHECK (
            "item_role" IS NULL OR "item_role" IN (%s)
        )',
        v_all_roles
    );
    
    RAISE NOTICE 'Constraint creado con % roles: %', array_length(v_role_list, 1), v_role_list;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error al crear constraint: %. Continuando...', SQLERRM;
END $$;

-- ====================================================
-- STEP 1: Crear tabla ConfiguredProducts o agregar columnas roll_* si ya existe
-- ====================================================

-- Si la tabla ya existe con columnas fabric_*, agregar columnas roll_*
DO $$
DECLARE
    v_update_sql text;
    v_has_fabric_sku boolean;
    v_has_fabric_collection_name boolean;
    v_has_fabric_variant_name boolean;
    v_has_fabric_roll_width boolean;
    v_has_fabric_msrp_total boolean;
    v_has_fabric_plus_bom_total boolean;
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts'
    ) THEN
        -- Agregar columnas roll_* si no existen (migración desde fabric_*)
        ALTER TABLE "public"."ConfiguredProducts"
            ADD COLUMN IF NOT EXISTS "roll_catalog_item_id" uuid,
            ADD COLUMN IF NOT EXISTS "roll_sku" text,
            ADD COLUMN IF NOT EXISTS "roll_collection_name" text,
            ADD COLUMN IF NOT EXISTS "roll_variant_name" text,
            ADD COLUMN IF NOT EXISTS "roll_width" numeric(12,4),
            ADD COLUMN IF NOT EXISTS "roll_msrp_total" numeric(12,4) DEFAULT 0,
            ADD COLUMN IF NOT EXISTS "roll_plus_bom_total" numeric(12,4) DEFAULT 0;
        
        -- Migrar datos de fabric_* a roll_* si existen las columnas fabric_*
        -- Verificar cada columna antes de copiarla para evitar errores
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'ConfiguredProducts' 
            AND column_name = 'fabric_catalog_item_id'
        ) THEN
            -- Verificar qué columnas fabric_* existen
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'ConfiguredProducts' 
                AND column_name = 'fabric_sku'
            ) INTO v_has_fabric_sku;
            
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'ConfiguredProducts' 
                AND column_name = 'fabric_collection_name'
            ) INTO v_has_fabric_collection_name;
            
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'ConfiguredProducts' 
                AND column_name = 'fabric_variant_name'
            ) INTO v_has_fabric_variant_name;
            
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'ConfiguredProducts' 
                AND column_name = 'fabric_roll_width'
            ) INTO v_has_fabric_roll_width;
            
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'ConfiguredProducts' 
                AND column_name = 'fabric_msrp_total'
            ) INTO v_has_fabric_msrp_total;
            
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'ConfiguredProducts' 
                AND column_name = 'fabric_plus_bom_total'
            ) INTO v_has_fabric_plus_bom_total;
            
            -- Construir UPDATE solo con columnas que existen
            v_update_sql := 'UPDATE "public"."ConfiguredProducts" SET ';
            v_update_sql := v_update_sql || 'roll_catalog_item_id = COALESCE(roll_catalog_item_id, fabric_catalog_item_id)';
            
            IF v_has_fabric_sku THEN
                v_update_sql := v_update_sql || ', roll_sku = COALESCE(roll_sku, fabric_sku)';
            END IF;
            
            IF v_has_fabric_collection_name THEN
                v_update_sql := v_update_sql || ', roll_collection_name = COALESCE(roll_collection_name, fabric_collection_name)';
            END IF;
            
            IF v_has_fabric_variant_name THEN
                v_update_sql := v_update_sql || ', roll_variant_name = COALESCE(roll_variant_name, fabric_variant_name)';
            END IF;
            
            IF v_has_fabric_roll_width THEN
                v_update_sql := v_update_sql || ', roll_width = COALESCE(roll_width, fabric_roll_width)';
            END IF;
            
            IF v_has_fabric_msrp_total THEN
                v_update_sql := v_update_sql || ', roll_msrp_total = COALESCE(roll_msrp_total, fabric_msrp_total)';
            END IF;
            
            IF v_has_fabric_plus_bom_total THEN
                v_update_sql := v_update_sql || ', roll_plus_bom_total = COALESCE(roll_plus_bom_total, fabric_plus_bom_total)';
            END IF;
            
            v_update_sql := v_update_sql || ' WHERE roll_catalog_item_id IS NULL AND fabric_catalog_item_id IS NOT NULL';
            
            -- Ejecutar UPDATE dinámico
            EXECUTE v_update_sql;
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Si hay error en la migración, solo registrar warning y continuar
        RAISE WARNING 'Error al agregar columnas roll_* o migrar datos: %. Continuando...', SQLERRM;
END $$;

CREATE TABLE IF NOT EXISTS "public"."ConfiguredProducts" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "quote_id" uuid,
    "bom_template_id" uuid NOT NULL,
    "product_type_id" uuid NOT NULL,
    
    -- Roll Configuration (fabric items are rolls)
    "roll_catalog_item_id" uuid,
    "roll_sku" text,
    "roll_collection_name" text,
    "roll_variant_name" text,
    "roll_width" numeric(12,4), -- Ancho del rollo total en metros (desde CatalogItems.roll_width)
    
    -- Measurements
    "width_mm" numeric(12,4),
    "height_mm" numeric(12,4),
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    
    -- Component Selections (snapshot - principal SKUs)
    "hardware_color" text,
    "bottom_bar_item_id" uuid,
    "bottom_bar_sku" text,
    "headbox_item_id" uuid,
    "headbox_sku" text,
    "side_channel_item_id" uuid,
    "side_channel_sku" text,
    "bottom_channel_item_id" uuid,
    "bottom_channel_sku" text,
    "motor_item_id" uuid,
    "motor_sku" text,
    "drive_item_id" uuid,
    "drive_sku" text,
    "tube_item_id" uuid,
    "tube_sku" text,
    "operating_type" text, -- 'manual' or 'motor'
    
    -- Pricing (calculated before QuoteLine creation)
    "roll_msrp_total" numeric(12,4) DEFAULT 0,
    "bom_total" numeric(12,4) DEFAULT 0,
    "roll_plus_bom_total" numeric(12,4) DEFAULT 0,
    "labor_pct" numeric(5,2) DEFAULT 0,
    "accessories_total" numeric(12,4) DEFAULT 0,
    "total_msrp" numeric(12,4) DEFAULT 0,
    
    -- Full configuration snapshot (JSONB)
    "config_snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb,
    
    -- Metadata
    "metadata" jsonb NOT NULL DEFAULT '{}'::jsonb,
    
    -- Timestamps
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    
    CONSTRAINT "configuredproducts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "configuredproducts_organization_fkey" 
        FOREIGN KEY ("organization_id") 
        REFERENCES "public"."Organizations"("id") 
        ON DELETE RESTRICT,
    CONSTRAINT "configuredproducts_quote_fkey" 
        FOREIGN KEY ("quote_id") 
        REFERENCES "public"."Quotes"("id") 
        ON DELETE SET NULL,
    CONSTRAINT "configuredproducts_bom_template_fkey" 
        FOREIGN KEY ("bom_template_id") 
        REFERENCES "public"."BOMTemplates"("id") 
        ON DELETE RESTRICT,
    CONSTRAINT "configuredproducts_product_type_fkey" 
        FOREIGN KEY ("product_type_id") 
        REFERENCES "public"."ProductTypes"("id") 
        ON DELETE RESTRICT,
    CONSTRAINT "configuredproducts_roll_item_fkey" 
        FOREIGN KEY ("roll_catalog_item_id") 
        REFERENCES "public"."CatalogItems"("id") 
        ON DELETE SET NULL
);

-- Agregar FK constraint para roll_catalog_item_id si no existe
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'roll_catalog_item_id'
    ) THEN
        -- Agregar FK constraint si no existe
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'configuredproducts_roll_item_fkey'
        ) THEN
            ALTER TABLE "public"."ConfiguredProducts"
                ADD CONSTRAINT "configuredproducts_roll_item_fkey" 
                FOREIGN KEY ("roll_catalog_item_id") 
                REFERENCES "public"."CatalogItems"("id") 
                ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

COMMENT ON TABLE "public"."ConfiguredProducts" IS 
'Snapshot completo de producto configurado (Roll + BOM) antes de crear QuoteLine. Contiene precios calculados y toda la configuración.';

COMMENT ON COLUMN "public"."ConfiguredProducts"."config_snapshot" IS 
'JSONB con snapshot completo de la configuración desde ProductConfigurator. Incluye todas las selecciones y opciones.';

COMMENT ON COLUMN "public"."ConfiguredProducts"."metadata" IS 
'JSONB para datos adicionales flexibles.';

COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_plus_bom_total" IS 
'Suma de Roll MSRP + BOM Total (antes de aplicar labor y accessories).';

COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total" IS 
'Total MSRP sale_out de todos los componentes BOM (padres + hijos) desde BOMInstanceLines.';

COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_msrp_total" IS 
'MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements × quantity.';

-- Índices
CREATE INDEX IF NOT EXISTS "idx_configuredproducts_quote" 
    ON "public"."ConfiguredProducts"("quote_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_configuredproducts_organization" 
    ON "public"."ConfiguredProducts"("organization_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_configuredproducts_template" 
    ON "public"."ConfiguredProducts"("bom_template_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_configuredproducts_product_type" 
    ON "public"."ConfiguredProducts"("product_type_id") 
    WHERE "deleted" = false;

-- GIN index para búsquedas en JSONB
CREATE INDEX IF NOT EXISTS "idx_configuredproducts_config_snapshot" 
    ON "public"."ConfiguredProducts" USING GIN ("config_snapshot");

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_configuredproducts_updated_at" ON "public"."ConfiguredProducts";
CREATE TRIGGER "trg_configuredproducts_updated_at"
    BEFORE UPDATE ON "public"."ConfiguredProducts"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 2: Modificar BOMInstances para soportar ConfiguredProducts
-- ====================================================

-- Verificar si la tabla existe antes de modificarla
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        -- Si no existe, crearla primero (estructura mínima)
        CREATE TABLE IF NOT EXISTS "public"."BomInstances" (
            "id" uuid DEFAULT gen_random_uuid() NOT NULL,
            "organization_id" uuid NOT NULL,
            "sale_order_line_id" uuid,
            "quote_line_id" uuid,
            "bom_template_id" uuid NOT NULL,
            "deleted" boolean DEFAULT false NOT NULL,
            "created_at" timestamptz DEFAULT now() NOT NULL,
            "updated_at" timestamptz DEFAULT now() NOT NULL,
            CONSTRAINT "bominstances_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "bominstances_bom_template_fkey" 
                FOREIGN KEY ("bom_template_id") 
                REFERENCES "public"."BOMTemplates"("id") 
                ON DELETE RESTRICT
        );
        
        -- Agregar FK a QuoteLines solo si existe la tabla
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'QuoteLines'
        ) THEN
            ALTER TABLE "public"."BomInstances"
                ADD CONSTRAINT "bominstances_quote_line_fkey" 
                FOREIGN KEY ("quote_line_id") 
                REFERENCES "public"."QuoteLines"("id") 
                ON DELETE CASCADE;
        END IF;
        
        -- Agregar índice básico
        CREATE INDEX IF NOT EXISTS "idx_bominstances_quote_line" 
            ON "public"."BomInstances"("quote_line_id") 
            WHERE "deleted" = false;
            
        -- Trigger updated_at
        DROP TRIGGER IF EXISTS "trg_bominstances_updated_at" ON "public"."BomInstances";
        CREATE TRIGGER "trg_bominstances_updated_at"
            BEFORE UPDATE ON "public"."BomInstances"
            FOR EACH ROW
            EXECUTE FUNCTION "public"."set_updated_at"();
    END IF;
END $$;

-- Hacer quote_line_id nullable (si existe la columna)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'quote_line_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE "public"."BomInstances"
            ALTER COLUMN "quote_line_id" DROP NOT NULL;
    END IF;
END $$;

-- Agregar configured_product_id solo si la tabla existe
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        -- Agregar columna si no existe
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'BomInstances' 
            AND column_name = 'configured_product_id'
        ) THEN
            ALTER TABLE "public"."BomInstances"
                ADD COLUMN "configured_product_id" uuid;
        END IF;
        
        -- Agregar FK constraint (solo si ConfiguredProducts existe)
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'ConfiguredProducts'
        ) THEN
            ALTER TABLE "public"."BomInstances"
                DROP CONSTRAINT IF EXISTS "bominstances_configured_product_fkey";
                
            ALTER TABLE "public"."BomInstances"
                ADD CONSTRAINT "bominstances_configured_product_fkey"
                    FOREIGN KEY ("configured_product_id")
                    REFERENCES "public"."ConfiguredProducts"("id")
                    ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- XOR constraint: exactamente uno de (quote_line_id, configured_product_id) debe ser not null
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        ALTER TABLE "public"."BomInstances"
            DROP CONSTRAINT IF EXISTS "bominstances_xor_quote_line_or_configured_product";

        ALTER TABLE "public"."BomInstances"
            ADD CONSTRAINT "bominstances_xor_quote_line_or_configured_product"
                CHECK (
                    (quote_line_id IS NOT NULL AND configured_product_id IS NULL) OR
                    (quote_line_id IS NULL AND configured_product_id IS NOT NULL)
                );
    END IF;
END $$;

-- Índice para configured_product_id (solo si la tabla y la columna existen)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'configured_product_id'
    ) THEN
        CREATE INDEX IF NOT EXISTS "idx_bominstances_configured_product" 
            ON "public"."BomInstances"("configured_product_id") 
            WHERE "deleted" = false;
    END IF;
END $$;

-- Actualizar comentario de la tabla (solo si la tabla existe)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        EXECUTE 'COMMENT ON TABLE "public"."BomInstances" IS ''BOM generado para un QuoteLine o ConfiguredProduct. Debe tener exactamente uno de: quote_line_id (para QuoteLine) o configured_product_id (para preview).''';
        
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'BomInstances' 
            AND column_name = 'configured_product_id'
        ) THEN
            EXECUTE 'COMMENT ON COLUMN "public"."BomInstances"."configured_product_id" IS ''FK a ConfiguredProducts. Permite crear BOM preview antes de crear QuoteLine. XOR con quote_line_id.''';
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 3: Función para seleccionar BOM template desde config_snapshot
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_configured_product"(
    "p_org_id" uuid,
    "p_product_type_id" uuid,
    "p_config_snapshot" jsonb
) RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_color text;
    v_best_template_id uuid;
    v_best_score int := -1;
    v_candidate RECORD;
    v_match_score int;
    v_selected_skus jsonb;
    v_slot RECORD;
    v_slot_sku text;
    v_user_sku text;
    v_selected_roles text[];
BEGIN
    -- 1. Obtener hardware_color desde config_snapshot
    v_color := COALESCE(
        p_config_snapshot->>'hardware_color',
        p_config_snapshot->>'hardwareColor',
        p_config_snapshot->>'operatingSystemColor'
    );
    
    -- Normalizar color (capitalize first letter)
    IF v_color IS NOT NULL THEN
        v_color := UPPER(SUBSTRING(v_color, 1, 1)) || LOWER(SUBSTRING(v_color, 2));
    END IF;

    -- 2. Obtener SKUs seleccionados desde config_snapshot
    -- Extraer todos los SKUs de selecciones (bottom_bar_sku, headbox_sku, etc.)
    v_selected_skus := jsonb_build_object(
        'bottom_bar', COALESCE(p_config_snapshot->>'bottom_bar_sku', p_config_snapshot->>'bottomBarSku'),
        'headbox', COALESCE(p_config_snapshot->>'headbox_sku', p_config_snapshot->>'headboxSku'),
        'side_channel', COALESCE(p_config_snapshot->>'side_channel_sku', p_config_snapshot->>'sideChannelSku'),
        'bottom_channel', COALESCE(p_config_snapshot->>'bottom_channel_sku', p_config_snapshot->>'bottomChannelSku'),
        'motor', COALESCE(p_config_snapshot->>'motor_sku', p_config_snapshot->>'motorSku'),
        'drive', COALESCE(p_config_snapshot->>'drive_sku', p_config_snapshot->>'driveSku'),
        'tube', COALESCE(p_config_snapshot->>'tube_sku', p_config_snapshot->>'tubeSku')
    );

    -- Obtener roles que tienen SKU seleccionado
    SELECT ARRAY_AGG(key) INTO v_selected_roles
    FROM jsonb_each_text(v_selected_skus)
    WHERE value IS NOT NULL AND value != '';

    v_selected_roles := COALESCE(v_selected_roles, ARRAY[]::text[]);

    -- 3. Buscar templates que coincidan con product_type_id y hardware_color
    FOR v_candidate IN
        SELECT 
            bt.id,
            bt.hardware_color,
            bt.updated_at,
            COALESCE((bt.metadata->>'priority')::int, 0) AS priority
        FROM public."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false
            AND (
                v_color IS NULL 
                OR bt.hardware_color IS NULL 
                OR LOWER(TRIM(bt.hardware_color)) = LOWER(TRIM(v_color))
            )
        ORDER BY 
            CASE WHEN v_color IS NOT NULL AND LOWER(TRIM(bt.hardware_color)) = LOWER(TRIM(v_color)) THEN 0 ELSE 1 END,
            priority DESC,
            bt.updated_at DESC
    LOOP
        -- 4. Calcular score: contar cuántos slots del template tienen SKU que coincide
        v_match_score := 0;
        
        -- Para cada slot del template, verificar si su SKU coincide con selección del usuario
        FOR v_slot IN
            SELECT 
                slots.item_role,
                ci.sku AS slot_sku
            FROM public."BOMTemplateSlots" slots
            LEFT JOIN public."CatalogItems" ci ON ci.id = slots.catalog_item_id
            WHERE slots.organization_id = p_org_id
                AND slots.bom_template_id = v_candidate.id
        LOOP
            -- Obtener SKU seleccionado por el usuario para este role
            v_user_sku := v_selected_skus->>v_slot.item_role;
            v_slot_sku := v_slot.slot_sku;
            
            -- Si ambos SKUs existen y coinciden exactamente (trim), sumar al score
            IF v_user_sku IS NOT NULL AND v_slot_sku IS NOT NULL THEN
                IF TRIM(v_user_sku) = TRIM(v_slot_sku) THEN
                    v_match_score := v_match_score + 1;
                END IF;
            END IF;
        END LOOP;

        -- 5. Si este template tiene mejor score que el anterior, actualizar
        IF v_match_score > v_best_score THEN
            v_best_score := v_match_score;
            v_best_template_id := v_candidate.id;
        END IF;
    END LOOP;

    -- 6. Si no encontramos ninguno con matches, usar el primero que coincida con product_type + color
    IF v_best_template_id IS NULL THEN
        SELECT bt.id INTO v_best_template_id
        FROM public."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false
            AND (
                v_color IS NULL 
                OR bt.hardware_color IS NULL 
                OR LOWER(TRIM(bt.hardware_color)) = LOWER(TRIM(v_color))
            )
        ORDER BY 
            CASE WHEN v_color IS NOT NULL AND LOWER(TRIM(bt.hardware_color)) = LOWER(TRIM(v_color)) THEN 0 ELSE 1 END,
            COALESCE((bt.metadata->>'priority')::int, 0) DESC,
            bt.updated_at DESC
        LIMIT 1;
    END IF;

    RETURN v_best_template_id;
END;
$$;

COMMENT ON FUNCTION "public"."select_best_bom_template_for_configured_product"(uuid, uuid, jsonb) IS 
'Selecciona el mejor BOMTemplate para una configuración basándose en product_type_id, hardware_color, y matching exacto de SKUs. Usa la misma lógica que select_best_bom_template_for_quote_line pero trabaja con config_snapshot JSONB directamente.';

-- ====================================================
-- STEP 4: Función para generar BOM desde ConfiguredProduct
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots_for_configured_product"(
    "p_org_id" uuid,
    "p_configured_product_id" uuid,
    "p_product_type_id" uuid
) RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_cp RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config_snapshot jsonb;
    v_selected_item_id uuid;
    v_selected_sku text;
    v_mounting_clip_qty numeric(12,4);
    v_mounting_clip_rule RECORD;
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id 
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    v_config_snapshot := v_cp.config_snapshot;
    v_template_id := v_cp.bom_template_id;

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'BOMTemplate not set in ConfiguredProduct %', p_configured_product_id;
    END IF;

    -- 2. Soft-delete instancias previas (idempotencia)
    UPDATE public."BomInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND configured_product_id = p_configured_product_id
        AND deleted = false;

    -- 3. Crear nueva instancia
    -- ✅ Validar que configured_product_id no sea NULL (requerido por constraint XOR)
    IF p_configured_product_id IS NULL THEN
        RAISE EXCEPTION 'configured_product_id cannot be NULL for preview BOMInstance';
    END IF;

    BEGIN
        INSERT INTO public."BomInstances"(
            organization_id, 
            configured_product_id, 
            bom_template_id,
            quote_line_id  -- ✅ NULL para preview (XOR constraint requiere uno de los dos)
        )
        VALUES (p_org_id, p_configured_product_id, v_template_id, NULL)
        RETURNING id INTO v_instance_id;

        -- Validar que el INSERT fue exitoso
        IF v_instance_id IS NULL THEN
            RAISE EXCEPTION 'Failed to create BomInstance: RETURNING id returned NULL. ConfiguredProduct: %, Template: %', p_configured_product_id, v_template_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Failed to create BomInstance for ConfiguredProduct %: %. Check XOR constraint and schema.', p_configured_product_id, SQLERRM;
    END;

    v_width_mm := COALESCE(v_cp.width_mm, 0);
    v_height_mm := COALESCE(v_cp.height_mm, 0);

    -- 4. Iterar BOMTemplateSlots (PADRES)
    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        -- PASO 1: Resolver SKU PADRE desde config_snapshot (elección del usuario)
        v_selected_item_id := NULL;
        v_selected_sku := NULL;
        
        -- Buscar en config_snapshot por role (ej: bottom_bar_item_id, bottom_bar_sku)
        CASE v_slot.item_role
            WHEN 'bottom_bar' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_bar_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_bar_sku';
            WHEN 'headbox' THEN
                v_selected_item_id := (v_config_snapshot->>'headbox_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'headbox_sku';
            WHEN 'side_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'side_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'side_channel_sku';
            WHEN 'bottom_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_channel_sku';
            WHEN 'motor' THEN
                v_selected_item_id := (v_config_snapshot->>'motor_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'motor_sku';
            WHEN 'drive' THEN
                v_selected_item_id := (v_config_snapshot->>'drive_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'drive_sku';
            WHEN 'tube' THEN
                v_selected_item_id := (v_config_snapshot->>'tube_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'tube_sku';
            ELSE
                -- ⚠️ Si el role no está en el CASE, intentar usar nombre genérico (item_role + _item_id y _sku)
                v_selected_item_id := (v_config_snapshot->>(v_slot.item_role || '_item_id'))::uuid;
                v_selected_sku := v_config_snapshot->>(v_slot.item_role || '_sku');
                -- Si aún no hay nada, dejar NULL (se usará catalog_item_id del slot)
        END CASE;

        -- Si hay SKU seleccionado, verificar que coincida con el slot (matching exacto)
        IF v_selected_sku IS NOT NULL AND v_slot.catalog_item_id IS NOT NULL THEN
            SELECT ci.sku INTO v_resolved_item
            FROM public."CatalogItems" ci
            WHERE ci.id = v_slot.catalog_item_id
                AND TRIM(ci.sku) = TRIM(v_selected_sku);
                
            IF v_resolved_item IS NOT NULL THEN
                v_resolved_item := v_slot.catalog_item_id;
            END IF;
        ELSIF v_selected_item_id IS NOT NULL THEN
            -- Si hay item_id, usarlo directamente
            v_resolved_item := v_selected_item_id;
        ELSE
            -- Si no eligió, usar catalog_item_id fijo del slot (si existe)
            v_resolved_item := v_slot.catalog_item_id;
        END IF;

        -- PASO 2: Obtener reglas de qty/corte desde BOMComponents
        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        -- PASO 3: Calcular cantidad
        IF v_has_component_rules THEN
            IF v_component.qty_type = 'fixed' THEN
                v_qty := v_component.qty_value;
            ELSIF v_component.qty_type = 'per_width' THEN
                v_qty := ((v_width_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_height' THEN
                v_qty := ((v_height_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_area' THEN
                v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_component.qty_value;
            ELSE
                v_qty := v_component.qty_value;
            END IF;

            -- Aplicar waste_pct
            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        -- PASO 4: Obtener costo y UOM
        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        -- PASO 5: Insertar línea del BOM (PADRE)
        -- ✅ Solo insertar si hay un item resuelto válido (resolved_part_id es NOT NULL)
        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
            INSERT INTO public."BomInstanceLines"(
                organization_id,
                bom_instance_id,
                resolved_part_id,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                deleted
            ) VALUES (
                p_org_id,
                v_instance_id,
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        ELSIF v_resolved_item IS NULL AND v_qty > 0 THEN
            -- ⚠️ Log warning si hay cantidad pero no hay item resuelto
            RAISE WARNING 'Skipping BOM line insertion for role %: qty=% but resolved_part_id is NULL', v_slot.item_role, v_qty;
        END IF;

        -- PASO 6: Si hay SKU resuelto, agregar HIJOS desde CatalogItemComponents
        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                SELECT 
                    cic.child_item_id,
                    cic.child_role,
                    cic.qty,
                    cic.uom,
                    COALESCE(ci.cost_exw, 0) AS child_cost
                FROM public."CatalogItemComponents" cic
                JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                WHERE cic.organization_id = p_org_id
                    AND cic.parent_item_id = v_resolved_item
                    AND cic.deleted = false
                ORDER BY cic.sort_order ASC
            LOOP
                -- ✅ REGLA ESPECIAL: mounting_clip con qty_type=per_width
                -- Si el child_role es mounting_clip, verificar si hay regla BOMComponents
                IF v_child.child_role = 'mounting_clip' THEN
                    -- Buscar regla mounting_clip que depende del role padre actual
                    SELECT * INTO v_mounting_clip_rule
                    FROM public."BOMComponents"
                    WHERE organization_id = p_org_id
                        AND bom_template_id = v_template_id
                        AND component_role = 'mounting_clip'
                        AND depends_on_role = v_slot.item_role
                        AND qty_type = 'per_width'
                        AND deleted = false
                    LIMIT 1;

                    IF v_mounting_clip_rule.id IS NOT NULL THEN
                        -- Calcular qty basado en ancho: ceil(width_m * qty_value) con mínimo 2
                        v_mounting_clip_qty := CEIL((v_width_mm / 1000.0) * v_mounting_clip_rule.qty_value);
                        IF v_mounting_clip_qty < 2 THEN
                            v_mounting_clip_qty := 2;
                        END IF;
                        -- Aplicar al qty del child (multiplicar por qty del padre)
                        v_child.qty := v_mounting_clip_qty * v_qty;
                        -- Forzar UOM a 'ea' para mounting_clip
                        v_child.uom := 'ea';
                    END IF;
                END IF;

                INSERT INTO public."BomInstanceLines"(
                    organization_id,
                    bom_instance_id,
                    resolved_part_id,
                    part_role,
                    qty,
                    uom,
                    unit_cost_exw,
                    deleted
                ) VALUES (
                    p_org_id,
                    v_instance_id,
                    v_child.child_item_id,
                    v_child.child_role,
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;

COMMENT ON FUNCTION "public"."generate_bom_from_slots_for_configured_product"(uuid, uuid, uuid) IS 
'Genera BOMInstance y BOMInstanceLines para un ConfiguredProduct. Lee selecciones desde config_snapshot JSONB. Aplica reglas mounting_clip con qty_type=per_width. Similar a generate_bom_from_slots pero para preview.';

-- ====================================================
-- STEP 5: Función para calcular totals y actualizar ConfiguredProduct
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."calculate_configured_product_totals"(
    "p_configured_product_id" uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_cp RECORD;
    v_bom_instance_id uuid;
    v_roll_msrp_total numeric(12,4) := 0;
    v_bom_total numeric(12,4) := 0;
    v_roll_plus_bom_total numeric(12,4) := 0;
    v_labor_pct numeric(5,2) := 0;
    v_accessories_total numeric(12,4) := 0;
    v_total_msrp numeric(12,4) := 0;
    v_width_m numeric(12,4);
    v_height_m numeric(12,4);
    v_quantity numeric(12,4);
    v_roll_msrp numeric(12,4);
    v_bom_line RECORD;
    v_part_msrp numeric(12,4);
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    -- 2. Obtener BOMInstance asociado
    SELECT id INTO v_bom_instance_id
    FROM public."BomInstances"
    WHERE configured_product_id = p_configured_product_id
        AND deleted = false
    ORDER BY created_at DESC
    LIMIT 1;

    -- 3. Calcular Roll MSRP Total
    -- ✅ FÓRMULA: MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements
    -- Donde:
    -- - MSRP Sale out = msrp_sale_out del roll (desde CatalogItemsMSRP)
    -- - Ancho del rollo total = roll_width del roll (desde CatalogItems.roll_width)
    -- - Altura de la medida = height_mm del producto (medida de measurements)
    IF v_cp.roll_catalog_item_id IS NOT NULL THEN
        -- Obtener MSRP sale_out del roll
        -- ✅ Usar roll_width guardado en ConfiguredProduct (snapshot) en lugar de buscarlo
        SELECT msrp_sale_out INTO v_roll_msrp
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_cp.roll_catalog_item_id
            AND (organization_id = v_cp.organization_id OR organization_id IS NULL)
        ORDER BY organization_id DESC NULLS LAST
        LIMIT 1;

        v_roll_msrp := COALESCE(v_roll_msrp, 0);
        
        -- ✅ Usar roll_width guardado en ConfiguredProduct (snapshot)
        v_width_m := COALESCE(v_cp.roll_width, 0); -- roll_width ya está en metros (guardado como snapshot)

        IF v_roll_msrp > 0 AND v_width_m > 0 AND v_cp.height_mm IS NOT NULL THEN
            v_height_m := v_cp.height_mm / 1000.0; -- Convertir mm a metros
            v_quantity := COALESCE(v_cp.quantity, 1);
            -- ✅ Fórmula: MSRP Sale out × Ancho del rollo total × Altura de la medida
            v_roll_msrp_total := v_roll_msrp * v_width_m * v_height_m * v_quantity;
        END IF;
    END IF;

    -- 4. Calcular BOM Total (sumar todas las líneas de BOMInstanceLines)
    IF v_bom_instance_id IS NOT NULL THEN
        FOR v_bom_line IN
            SELECT 
                bil.resolved_part_id,
                bil.qty
            FROM public."BomInstanceLines" bil
            WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.deleted = false
                AND bil.resolved_part_id IS NOT NULL
        LOOP
            -- Obtener MSRP sale_out de cada componente
            SELECT msrp_sale_out INTO v_part_msrp
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_bom_line.resolved_part_id
                AND (organization_id = v_cp.organization_id OR organization_id IS NULL)
            ORDER BY organization_id DESC NULLS LAST
            LIMIT 1;

            v_part_msrp := COALESCE(v_part_msrp, 0);
            v_bom_total := v_bom_total + (v_part_msrp * v_bom_line.qty);
        END LOOP;
    END IF;

    -- 5. Calcular Fabric + BOM Total
    v_roll_plus_bom_total := v_roll_msrp_total + v_bom_total;

    -- 6. Obtener labor_pct (de cost settings o metadata)
    v_labor_pct := COALESCE(
        (v_cp.metadata->>'labor_pct')::numeric,
        v_cp.labor_pct,
        0
    );

    -- 7. Obtener accessories_total (si existe en metadata)
    v_accessories_total := COALESCE(
        (v_cp.metadata->>'accessories_total')::numeric,
        v_cp.accessories_total,
        0
    );

    -- 8. Calcular Total MSRP final
    -- Formula: (Roll + BOM) * (1 + labor_pct) + Accessories
    v_total_msrp := (v_roll_plus_bom_total * (1 + (v_labor_pct / 100))) + v_accessories_total;

    -- 9. Actualizar ConfiguredProduct con totals
    UPDATE public."ConfiguredProducts"
    SET 
        roll_msrp_total = v_roll_msrp_total,
        bom_total = v_bom_total,
        roll_plus_bom_total = v_roll_plus_bom_total,
        labor_pct = v_labor_pct,
        accessories_total = v_accessories_total,
        total_msrp = v_total_msrp
    WHERE id = p_configured_product_id;

    -- 10. Retornar totals como JSONB
    RETURN jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'roll_plus_bom_total', v_roll_plus_bom_total,
        'labor_pct', v_labor_pct,
        'accessories_total', v_accessories_total,
        'total_msrp', v_total_msrp
    );
END;
$$;

COMMENT ON FUNCTION "public"."calculate_configured_product_totals"(uuid) IS 
'Calcula y actualiza totals de ConfiguredProduct: roll_msrp_total, bom_total (sumando MSRP sale_out de todas las BOMInstanceLines), roll_plus_bom_total, y total_msrp final con labor y accessories.';

-- ====================================================
-- STEP 6: Función RPC principal para crear ConfiguredProduct + BOM preview
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."create_configured_product_and_bom_preview"(
    "p_org_id" uuid,
    "p_product_type_id" uuid,
    "p_config_snapshot" jsonb,
    "p_quote_id" uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_configured_product_id uuid;
    v_bom_template_id uuid;
    v_bom_instance_id uuid;
    v_totals jsonb;
    v_hardware_color text;
    v_fabric_item_id uuid;
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_quantity numeric(12,4);
    v_roll_sku text;
    v_roll_collection_name text;
    v_roll_variant_name text;
    v_roll_width numeric(12,4);
BEGIN
    -- 1. Resolver BOM template usando config_snapshot
    v_bom_template_id := public.select_best_bom_template_for_configured_product(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
    );

    IF v_bom_template_id IS NULL THEN
        RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', 
            p_org_id, p_product_type_id;
    END IF;

    -- 2. Extraer datos principales del config_snapshot
    v_hardware_color := COALESCE(
        p_config_snapshot->>'hardware_color',
        p_config_snapshot->>'hardwareColor',
        p_config_snapshot->>'operatingSystemColor'
    );
    
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
    IF v_fabric_item_id IS NULL THEN
        v_fabric_item_id := (p_config_snapshot->>'fabric_catalog_item_id')::uuid; -- Legacy compatibility
    END IF;
    IF v_fabric_item_id IS NULL THEN
        v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
    END IF;
    
    v_width_mm := (p_config_snapshot->>'width_mm')::numeric;
    IF v_width_mm IS NULL THEN
        v_width_mm := COALESCE((p_config_snapshot->>'width_m')::numeric, 0) * 1000;
    END IF;
    
    v_height_mm := (p_config_snapshot->>'height_mm')::numeric;
    IF v_height_mm IS NULL THEN
        v_height_mm := COALESCE((p_config_snapshot->>'height_m')::numeric, 0) * 1000;
    END IF;
    
    v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric, 1);

    -- 3. Obtener info del roll si existe
    -- ✅ CRITICAL: Filtrar por is_fabric=true primero para asegurar que es un roll (fabric)
    IF v_fabric_item_id IS NOT NULL THEN
        SELECT 
            ci.sku, 
            ci.collection_name, 
            ci.variant_name,
            ci.roll_width
        INTO 
            v_roll_sku, 
            v_roll_collection_name, 
            v_roll_variant_name,
            v_roll_width
        FROM public."CatalogItems" ci
        WHERE ci.id = v_fabric_item_id
            AND ci.is_fabric = true
            AND ci.is_active = true
            AND (ci.organization_id = p_org_id OR ci.organization_id IS NULL)
        LIMIT 1;
    END IF;

    -- 4. Crear ConfiguredProduct
    INSERT INTO public."ConfiguredProducts"(
        organization_id,
        quote_id,
        bom_template_id,
        product_type_id,
        roll_catalog_item_id,
        roll_sku,
        roll_collection_name,
        roll_variant_name,
        roll_width,
        width_mm,
        height_mm,
        quantity,
        hardware_color,
        bottom_bar_item_id,
        bottom_bar_sku,
        headbox_item_id,
        headbox_sku,
        side_channel_item_id,
        side_channel_sku,
        bottom_channel_item_id,
        bottom_channel_sku,
        motor_item_id,
        motor_sku,
        drive_item_id,
        drive_sku,
        tube_item_id,
        tube_sku,
        operating_type,
        config_snapshot
    ) VALUES (
        p_org_id,
        p_quote_id,
        v_bom_template_id,
        p_product_type_id,
        v_fabric_item_id,
        v_roll_sku,
        v_roll_collection_name,
        v_roll_variant_name,
        v_roll_width,
        v_width_mm,
        v_height_mm,
        v_quantity,
        v_hardware_color,
        (p_config_snapshot->>'bottom_bar_item_id')::uuid,
        p_config_snapshot->>'bottom_bar_sku',
        (p_config_snapshot->>'headbox_item_id')::uuid,
        p_config_snapshot->>'headbox_sku',
        (p_config_snapshot->>'side_channel_item_id')::uuid,
        p_config_snapshot->>'side_channel_sku',
        (p_config_snapshot->>'bottom_channel_item_id')::uuid,
        p_config_snapshot->>'bottom_channel_sku',
        (p_config_snapshot->>'motor_item_id')::uuid,
        p_config_snapshot->>'motor_sku',
        (p_config_snapshot->>'drive_item_id')::uuid,
        p_config_snapshot->>'drive_sku',
        (p_config_snapshot->>'tube_item_id')::uuid,
        p_config_snapshot->>'tube_sku',
        COALESCE(
            p_config_snapshot->>'operating_type',
            p_config_snapshot->>'operation_type',
            p_config_snapshot->>'drive_type'
        ),
        p_config_snapshot
    )
    RETURNING id INTO v_configured_product_id;

    -- 5. Generar BOMInstance y BOMInstanceLines
    v_bom_instance_id := public.generate_bom_from_slots_for_configured_product(
        p_org_id,
        v_configured_product_id,
        p_product_type_id
    );

    -- 6. Calcular totals
    v_totals := public.calculate_configured_product_totals(v_configured_product_id);

    -- 7. Retornar resultado
    RETURN jsonb_build_object(
        'configured_product_id', v_configured_product_id,
        'bom_instance_id', v_bom_instance_id,
        'bom_template_id', v_bom_template_id,
        'totals', v_totals
    );
END;
$$;

COMMENT ON FUNCTION "public"."create_configured_product_and_bom_preview"(uuid, uuid, jsonb, uuid) IS 
'Función RPC principal para crear ConfiguredProduct + BOM preview. Resuelve BOM template, crea snapshot, genera BOMInstance, y calcula totals (roll + bom). Todo en una transacción atómica.';

-- ====================================================
-- STEP 7: RLS Policies para ConfiguredProducts
-- ====================================================

-- Habilitar RLS
ALTER TABLE "public"."ConfiguredProducts" ENABLE ROW LEVEL SECURITY;

-- Drop existing policies si existen
DROP POLICY IF EXISTS "configuredproducts_org_members_select" ON "public"."ConfiguredProducts";
DROP POLICY IF EXISTS "configuredproducts_org_members_insert" ON "public"."ConfiguredProducts";
DROP POLICY IF EXISTS "configuredproducts_org_members_update" ON "public"."ConfiguredProducts";

-- SELECT: Solo miembros de la organización
CREATE POLICY "configuredproducts_org_members_select"
    ON "public"."ConfiguredProducts"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "ConfiguredProducts".organization_id
                AND ou.user_id = auth.uid()
                AND ou.status = 'active'
                AND ou.deleted = false
        )
    );

-- INSERT: Solo miembros de la organización
CREATE POLICY "configuredproducts_org_members_insert"
    ON "public"."ConfiguredProducts"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "ConfiguredProducts".organization_id
                AND ou.user_id = auth.uid()
                AND ou.status = 'active'
                AND ou.deleted = false
        )
    );

-- UPDATE: Solo miembros de la organización
CREATE POLICY "configuredproducts_org_members_update"
    ON "public"."ConfiguredProducts"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "ConfiguredProducts".organization_id
                AND ou.user_id = auth.uid()
                AND ou.status = 'active'
                AND ou.deleted = false
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "ConfiguredProducts".organization_id
                AND ou.user_id = auth.uid()
                AND ou.status = 'active'
                AND ou.deleted = false
        )
    );

-- ====================================================
-- STEP 8: Actualizar RLS Policies para BOMInstances (agregar soporte para configured_product_id)
-- ====================================================

-- Verificar si existen policies existentes y agregar lógica para configured_product_id
-- Las policies existentes para quote_line_id seguirán funcionando
-- Agregamos policy adicional para configured_product_id

DROP POLICY IF EXISTS "bominstances_configured_product_access" ON "public"."BomInstances";

CREATE POLICY "bominstances_configured_product_access"
    ON "public"."BomInstances"
    FOR ALL
    USING (
        -- Si tiene quote_line_id, usar policies existentes (no cambiar)
        (quote_line_id IS NOT NULL) OR
        -- Si tiene configured_product_id, validar acceso por ConfiguredProduct.organization_id
        (
            configured_product_id IS NOT NULL AND
            EXISTS (
                SELECT 1 FROM public."ConfiguredProducts" cp
                JOIN public."OrganizationUsers" ou ON ou.organization_id = cp.organization_id
                WHERE cp.id = "BomInstances".configured_product_id
                    AND ou.user_id = auth.uid()
                    AND ou.status = 'active'
                    AND ou.deleted = false
                    AND cp.deleted = false
            )
        )
    )
    WITH CHECK (
        -- Mismo check para INSERT/UPDATE
        (quote_line_id IS NOT NULL) OR
        (
            configured_product_id IS NOT NULL AND
            EXISTS (
                SELECT 1 FROM public."ConfiguredProducts" cp
                JOIN public."OrganizationUsers" ou ON ou.organization_id = cp.organization_id
                WHERE cp.id = "BomInstances".configured_product_id
                    AND ou.user_id = auth.uid()
                    AND ou.status = 'active'
                    AND ou.deleted = false
                    AND cp.deleted = false
            )
        )
    );

COMMIT;
