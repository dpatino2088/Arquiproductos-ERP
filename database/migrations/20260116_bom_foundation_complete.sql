-- ====================================================
-- BOM FOUNDATION: Arquitectura 3 capas completa e idempotente
-- ====================================================
-- CONTRATO DEFINITIVO:
-- - Rolls (is_roll=true): se resuelven por (collection_name + variant_name)
-- - Hardware/Perfiles (is_roll=false): se resuelven por (item_role + color)
-- - NO usar sufijo SKU para color
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Agregar item_role a CatalogItems
-- ====================================================

-- Roles oficiales LOCKED
DO $$
BEGIN
    -- Agregar columna si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'item_role'
    ) THEN
        ALTER TABLE "public"."CatalogItems" 
        ADD COLUMN "item_role" text;
        
        COMMENT ON COLUMN "public"."CatalogItems"."item_role" IS 
        'Official component role: tube, fabric, cassette, bracket, etc. LOCKED list.';
    END IF;
END $$;

-- Check constraint para roles oficiales
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'catalogitems_item_role_check'
    ) THEN
        ALTER TABLE "public"."CatalogItems" 
        ADD CONSTRAINT "catalogitems_item_role_check" 
        CHECK (
            "item_role" IS NULL OR "item_role" IN (
                'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
                'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
                'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
                'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
                'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
                'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film'
            )
        );
    END IF;
END $$;

-- ====================================================
-- STEP 2: Crear QuoteLineComponents (configurador)
-- ====================================================

CREATE TABLE IF NOT EXISTS "public"."QuoteLineComponents" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "quote_line_id" uuid NOT NULL,
    "kind" text NOT NULL DEFAULT 'option' CHECK ("kind" IN ('option', 'override')),
    "component_role" text NOT NULL,
    "catalog_item_id" uuid,
    "payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "source" text DEFAULT 'configured_component' NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    CONSTRAINT "quotelinecomponents_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "quotelinecomponents_quote_line_fkey" 
        FOREIGN KEY ("quote_line_id") 
        REFERENCES "public"."QuoteLines"("id") 
        ON DELETE CASCADE,
    CONSTRAINT "quotelinecomponents_catalog_item_fkey" 
        FOREIGN KEY ("catalog_item_id") 
        REFERENCES "public"."CatalogItems"("id") 
        ON DELETE SET NULL,
    CONSTRAINT "quotelinecomponents_kind_option_check" 
        CHECK (
            ("kind" = 'option') OR 
            ("kind" = 'override' AND "component_role" IS NOT NULL AND "catalog_item_id" IS NOT NULL)
        )
);

COMMENT ON TABLE "public"."QuoteLineComponents" IS 
'Configurador: guarda selecciones del usuario (option: payload JSONB) y overrides (catalog_item_id específico para un role).';
COMMENT ON COLUMN "public"."QuoteLineComponents"."kind" IS 
'option: selección del configurador (payload JSONB). override: catalog_item_id específico para un component_role.';
COMMENT ON COLUMN "public"."QuoteLineComponents"."payload" IS 
'JSONB con configuraciones: { "hardware_color": "White" }';
COMMENT ON COLUMN "public"."QuoteLineComponents"."component_role" IS 
'Required si kind=override. Indica qué role se está overrrideando.';

-- Agregar columnas si no existen (para tablas existentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "public"."QuoteLineComponents" 
        ADD COLUMN "deleted" boolean DEFAULT false NOT NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'component_role'
    ) THEN
        ALTER TABLE "public"."QuoteLineComponents" 
        ADD COLUMN "component_role" text;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'kind'
    ) THEN
        ALTER TABLE "public"."QuoteLineComponents" 
        ADD COLUMN "kind" text NOT NULL DEFAULT 'option';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'payload'
    ) THEN
        ALTER TABLE "public"."QuoteLineComponents" 
        ADD COLUMN "payload" jsonb DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS "idx_quotelinecomponents_quote_line" 
    ON "public"."QuoteLineComponents"("quote_line_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_quotelinecomponents_role_kind" 
    ON "public"."QuoteLineComponents"("component_role", "kind") 
    WHERE "deleted" = false AND "kind" = 'override';

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_quotelinecomponents_updated_at" ON "public"."QuoteLineComponents";
CREATE TRIGGER "trg_quotelinecomponents_updated_at"
    BEFORE UPDATE ON "public"."QuoteLineComponents"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 3: Crear BOMTemplates (plantillas maestras)
-- ====================================================

CREATE TABLE IF NOT EXISTS "public"."BOMTemplates" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "product_type_id" uuid NOT NULL,
    "code" text,
    "name" text,
    "description" text,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    "active" boolean DEFAULT true NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT "bomtemplates_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "bomtemplates_product_type_fkey" 
        FOREIGN KEY ("product_type_id") 
        REFERENCES "public"."ProductTypes"("id") 
        ON DELETE RESTRICT,
    CONSTRAINT "bomtemplates_org_code_unique" 
        UNIQUE ("organization_id", "code") 
        DEFERRABLE INITIALLY DEFERRED
);

COMMENT ON TABLE "public"."BOMTemplates" IS 
'Plantillas maestras de BOM. metadata.compat: JSONB para best match. metadata.priority: int opcional.';
COMMENT ON COLUMN "public"."BOMTemplates"."metadata" IS 
'JSONB: { "compat": {...}, "priority": 10 }';

-- Agregar deleted y archived si no existen (para tablas existentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMTemplates' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "public"."BOMTemplates" 
        ADD COLUMN "deleted" boolean DEFAULT false NOT NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMTemplates' 
        AND column_name = 'archived'
    ) THEN
        ALTER TABLE "public"."BOMTemplates" 
        ADD COLUMN "archived" boolean DEFAULT false NOT NULL;
    END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS "idx_bomtemplates_product_type" 
    ON "public"."BOMTemplates"("product_type_id") 
    WHERE "deleted" = false AND "active" = true;

CREATE INDEX IF NOT EXISTS "idx_bomtemplates_org_active" 
    ON "public"."BOMTemplates"("organization_id", "active") 
    WHERE "deleted" = false;

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_bomtemplates_updated_at" ON "public"."BOMTemplates";
CREATE TRIGGER "trg_bomtemplates_updated_at"
    BEFORE UPDATE ON "public"."BOMTemplates"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 4: Crear BOMComponents (materiales del template)
-- ====================================================

CREATE TABLE IF NOT EXISTS "public"."BOMComponents" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "bom_template_id" uuid NOT NULL,
    "component_item_id" uuid,
    "component_role" text NOT NULL,
    "qty_type" text DEFAULT 'fixed' NOT NULL,
    "qty_value" numeric(12,4) DEFAULT 1 NOT NULL,
    "qty_delta_mm" numeric(12,4) DEFAULT 0 NOT NULL,
    "uom" text DEFAULT 'ea' NOT NULL,
    "waste_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "auto_select" boolean DEFAULT true NOT NULL,
    "sku_resolution_rule" text DEFAULT 'ROLE_AND_COLOR' NOT NULL,
    "depends_on_role" text,
    "cut_axis" text,
    "cut_delta_mm" numeric(12,4) DEFAULT 0 NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT "bomcomponents_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "bomcomponents_bom_template_fkey" 
        FOREIGN KEY ("bom_template_id") 
        REFERENCES "public"."BOMTemplates"("id") 
        ON DELETE CASCADE,
    CONSTRAINT "bomcomponents_component_item_fkey" 
        FOREIGN KEY ("component_item_id") 
        REFERENCES "public"."CatalogItems"("id") 
        ON DELETE SET NULL,
    CONSTRAINT "bomcomponents_component_role_check" 
        CHECK (
            "component_role" IN (
                'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
                'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
                'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
                'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
                'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
                'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film'
            )
        )
);

COMMENT ON TABLE "public"."BOMComponents" IS 
'Materiales del template. Define qué componentes necesita y cómo resolverlos.';
COMMENT ON COLUMN "public"."BOMComponents"."component_item_id" IS 
'NULL si auto_select=true. Fijo si sku_resolution_rule=EXACT_ITEM.';
COMMENT ON COLUMN "public"."BOMComponents"."sku_resolution_rule" IS 
'FABRIC_BY_COLLECTION_VARIANT: fabric por collection+variant. ROLE_AND_COLOR: hardware por role+color. EXACT_ITEM: usa component_item_id.';
COMMENT ON COLUMN "public"."BOMComponents"."cut_axis" IS 
'none, width, height, both. Para aplicar cut_delta_mm.';
COMMENT ON COLUMN "public"."BOMComponents"."cut_delta_mm" IS 
'Delta en mm a aplicar según cut_axis.';

-- Agregar columnas si no existen (para tablas existentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "public"."BOMComponents" 
        ADD COLUMN "deleted" boolean DEFAULT false NOT NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'component_role'
    ) THEN
        ALTER TABLE "public"."BOMComponents" 
        ADD COLUMN "component_role" text NOT NULL;
    END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS "idx_bomcomponents_template" 
    ON "public"."BOMComponents"("bom_template_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_bomcomponents_role" 
    ON "public"."BOMComponents"("component_role") 
    WHERE "deleted" = false;

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_bomcomponents_updated_at" ON "public"."BOMComponents";
CREATE TRIGGER "trg_bomcomponents_updated_at"
    BEFORE UPDATE ON "public"."BOMComponents"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 5: Crear BomInstances (BOM para pedido específico)
-- ====================================================

CREATE TABLE IF NOT EXISTS "public"."BomInstances" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "sale_order_line_id" uuid,
    "quote_line_id" uuid NOT NULL,
    "bom_template_id" uuid NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT "bominstances_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "bominstances_quote_line_fkey" 
        FOREIGN KEY ("quote_line_id") 
        REFERENCES "public"."QuoteLines"("id") 
        ON DELETE CASCADE,
    CONSTRAINT "bominstances_bom_template_fkey" 
        FOREIGN KEY ("bom_template_id") 
        REFERENCES "public"."BOMTemplates"("id") 
        ON DELETE RESTRICT
);

-- Agregar config_jsonb si no existe (para tablas existentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'config_jsonb'
    ) THEN
        ALTER TABLE "public"."BomInstances" 
        ADD COLUMN "config_jsonb" jsonb DEFAULT '{}'::jsonb;
        
        COMMENT ON COLUMN "public"."BomInstances"."config_jsonb" IS 
        'JSONB con configuración usada para generar este BOM (desde QuoteLineComponents).';
    END IF;
END $$;

COMMENT ON TABLE "public"."BomInstances" IS 
'BOM generado para un QuoteLine específico. Idempotente: si ya existe para quote_line_id, se marca deleted=true y se crea nuevo.';

-- Agregar deleted si no existe (para tablas existentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "public"."BomInstances" 
        ADD COLUMN "deleted" boolean DEFAULT false NOT NULL;
    END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS "idx_bominstances_quote_line" 
    ON "public"."BomInstances"("quote_line_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_bominstances_template" 
    ON "public"."BomInstances"("bom_template_id") 
    WHERE "deleted" = false;

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_bominstances_updated_at" ON "public"."BomInstances";
CREATE TRIGGER "trg_bominstances_updated_at"
    BEFORE UPDATE ON "public"."BomInstances"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 6: Crear BomInstanceLines (materiales calculados)
-- ====================================================

CREATE TABLE IF NOT EXISTS "public"."BomInstanceLines" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "bom_instance_id" uuid NOT NULL,
    "part_role" text NOT NULL,
    "resolved_part_id" uuid NOT NULL,
    "qty" numeric(12,4) NOT NULL,
    "uom" text NOT NULL,
    "cut_length_mm" numeric(12,4),
    "cut_width_mm" numeric(12,4),
    "cut_height_mm" numeric(12,4),
    "unit_cost_exw" numeric(12,4),
    "total_cost_exw" numeric(12,4),
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    CONSTRAINT "bominstancelines_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "bominstancelines_bom_instance_fkey" 
        FOREIGN KEY ("bom_instance_id") 
        REFERENCES "public"."BomInstances"("id") 
        ON DELETE CASCADE,
    CONSTRAINT "bominstancelines_resolved_part_fkey" 
        FOREIGN KEY ("resolved_part_id") 
        REFERENCES "public"."CatalogItems"("id") 
        ON DELETE RESTRICT,
    CONSTRAINT "bominstancelines_part_role_check" 
        CHECK (
            "part_role" IN (
                'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
                'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
                'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
                'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
                'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
                'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film'
            )
        )
);

COMMENT ON TABLE "public"."BomInstanceLines" IS 
'Materiales calculados del BOM. resolved_part_id: SKU real seleccionado. cut_*_mm: dimensiones de corte calculadas.';
COMMENT ON COLUMN "public"."BomInstanceLines"."resolved_part_id" IS 
'FK a CatalogItems: SKU real seleccionado según reglas de resolución.';
COMMENT ON COLUMN "public"."BomInstanceLines"."part_role" IS 
'Rol del componente (fabric, tube, bracket, etc.). Copiado de BOMComponents.component_role.';
COMMENT ON COLUMN "public"."BomInstanceLines"."cut_length_mm" IS 
'Longitud de corte calculada (width_m * 1000 + cut_delta_mm, etc.).';
COMMENT ON COLUMN "public"."BomInstanceLines"."unit_cost_exw" IS 
'Snapshot de CatalogItems.cost_exw al momento de generar.';
COMMENT ON COLUMN "public"."BomInstanceLines"."total_cost_exw" IS 
'unit_cost_exw * qty (snapshot).';

-- Agregar columnas si no existen (para tablas existentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "public"."BomInstanceLines" 
        ADD COLUMN "deleted" boolean DEFAULT false NOT NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE "public"."BomInstanceLines" 
        ADD COLUMN "updated_at" timestamptz DEFAULT now() NOT NULL;
    END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS "idx_bominstancelines_bom_instance" 
    ON "public"."BomInstanceLines"("bom_instance_id") 
    WHERE "deleted" = false;

CREATE INDEX IF NOT EXISTS "idx_bominstancelines_role" 
    ON "public"."BomInstanceLines"("part_role") 
    WHERE "deleted" = false;

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_bominstancelines_updated_at" ON "public"."BomInstanceLines";
CREATE TRIGGER "trg_bominstancelines_updated_at"
    BEFORE UPDATE ON "public"."BomInstanceLines"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 7: Funciones SQL (DROP primero para evitar conflictos de parámetros)
-- ====================================================

-- Drop funciones existentes (evitar conflicto de nombres de parámetros)
DROP FUNCTION IF EXISTS "public"."build_quote_line_config"(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS "public"."select_best_bom_template"(uuid, uuid, jsonb) CASCADE;
DROP FUNCTION IF EXISTS "public"."resolve_component_item"(uuid, text, text, uuid, jsonb, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS "public"."resolve_component_item_id"(uuid, text, text, uuid, jsonb, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS "public"."generate_bom_instance_for_quote_line"(uuid, uuid, uuid) CASCADE;

-- Función 1: build_quote_line_config(org_id, quote_line_id) -> jsonb
CREATE OR REPLACE FUNCTION "public"."build_quote_line_config"(
    "p_org_id" uuid,
    "p_quote_line_id" uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_config jsonb := '{}'::jsonb;
    v_row record;
BEGIN
    -- Construir config_jsonb desde QuoteLineComponents (kind='option')
    FOR v_row IN
        SELECT "payload"
        FROM "public"."QuoteLineComponents"
        WHERE "organization_id" = "p_org_id"
        AND "quote_line_id" = "p_quote_line_id"
        AND "kind" = 'option'
        AND "deleted" = false
    LOOP
        -- Merge payloads
        v_config := v_config || COALESCE(v_row."payload", '{}'::jsonb);
    END LOOP;
    
    RETURN v_config;
END;
$$;

COMMENT ON FUNCTION "public"."build_quote_line_config"(uuid, uuid) IS 
'Construye config_jsonb desde QuoteLineComponents (kind=option). Merge todos los payloads.';

-- Función 2: select_best_bom_template(org_id, product_type_id, config) -> uuid
CREATE OR REPLACE FUNCTION "public"."select_best_bom_template"(
    "p_org_id" uuid,
    "p_product_type_id" uuid,
    "p_config" jsonb
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_template_id uuid;
    v_best_template_id uuid;
    v_best_score integer := -1;
    v_score integer;
    v_compat jsonb;
    v_config_key text;
    v_config_value jsonb;
    v_priority integer;
BEGIN
    -- Iterar sobre templates activos para este product_type
    FOR v_template_id IN
        SELECT "id"
        FROM "public"."BOMTemplates"
        WHERE "organization_id" = "p_org_id"
        AND "product_type_id" = "p_product_type_id"
        AND "active" = true
        AND "deleted" = false
        ORDER BY COALESCE(("metadata"->>'priority')::integer, 0) DESC, "updated_at" DESC
    LOOP
        -- Obtener metadata.compat
        SELECT "metadata"->'compat'
        INTO v_compat
        FROM "public"."BOMTemplates"
        WHERE "id" = v_template_id;
        
        -- Si no hay compat, usar priority/updated_at como tie-break
        IF v_compat IS NULL OR jsonb_typeof(v_compat) != 'object' THEN
            IF v_best_template_id IS NULL THEN
                v_best_template_id := v_template_id;
                SELECT COALESCE(("metadata"->>'priority')::integer, 0)
                INTO v_priority
                FROM "public"."BOMTemplates"
                WHERE "id" = v_template_id;
                v_best_score := v_priority;
            END IF;
            CONTINUE;
        END IF;
        
        -- Calcular score: contar coincidencias entre compat y config
        v_score := 0;
        FOR v_config_key, v_config_value IN SELECT * FROM jsonb_each("p_config")
        LOOP
            IF v_compat ? v_config_key THEN
                IF v_compat->v_config_key = v_config_value THEN
                    v_score := v_score + 1;
                END IF;
            END IF;
        END LOOP;
        
        -- Si este template tiene mejor score, guardarlo
        IF v_score > v_best_score THEN
            v_best_template_id := v_template_id;
            v_best_score := v_score;
        END IF;
    END LOOP;
    
    -- Si no encontramos ninguno con match, usar el primero (priority desc, updated_at desc)
    IF v_best_template_id IS NULL THEN
        SELECT "id"
        INTO v_best_template_id
        FROM "public"."BOMTemplates"
        WHERE "organization_id" = "p_org_id"
        AND "product_type_id" = "p_product_type_id"
        AND "active" = true
        AND "deleted" = false
        ORDER BY COALESCE(("metadata"->>'priority')::integer, 0) DESC, "updated_at" DESC
        LIMIT 1;
    END IF;
    
    RETURN v_best_template_id;
END;
$$;

COMMENT ON FUNCTION "public"."select_best_bom_template"(uuid, uuid, jsonb) IS 
'Best match: score por coincidencias metadata.compat vs config. Tie-break: priority desc, updated_at desc.';

-- Función 3: resolve_component_item_id(...) -> uuid (nombre compatible con dump)
CREATE OR REPLACE FUNCTION "public"."resolve_component_item_id"(
    "p_org_id" uuid,
    "p_component_role" text,
    "p_sku_rule" text,
    "p_quote_line_id" uuid,
    "p_config" jsonb,
    "p_fixed_component_item_id" uuid,
    "p_override_item_id" uuid
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_resolved_id uuid;
    v_quote_line record;
    v_hardware_color text;
    v_match_count integer;
BEGIN
    -- 1. Si hay override, usar override_item_id
    IF "p_override_item_id" IS NOT NULL THEN
        RETURN "p_override_item_id";
    END IF;
    
    -- 2. Si hay fixed_item (EXACT_ITEM), usar fixed_component_item_id
    IF "p_fixed_component_item_id" IS NOT NULL THEN
        RETURN "p_fixed_component_item_id";
    END IF;
    
    -- 3. Obtener datos del QuoteLine
    SELECT "collection_name", "variant_name"
    INTO "v_quote_line"
    FROM "public"."QuoteLines"
    WHERE "id" = "p_quote_line_id"
    AND "organization_id" = "p_org_id";
    
    IF "v_quote_line" IS NULL THEN
        RAISE EXCEPTION 'QuoteLine not found: %', "p_quote_line_id";
    END IF;
    
    -- 4. Resolver según sku_rule
    IF "p_sku_rule" = 'FABRIC_BY_COLLECTION_VARIANT' OR "p_component_role" = 'fabric' THEN
        -- Fabric: buscar por collection_name + variant_name (is_roll=true)
        IF "v_quote_line"."collection_name" IS NULL OR "v_quote_line"."variant_name" IS NULL THEN
            RAISE EXCEPTION 'Fabric requiere collection_name y variant_name en QuoteLine (quote_line_id: %)', "p_quote_line_id";
        END IF;
        
        SELECT "id"
        INTO "v_resolved_id"
        FROM "public"."CatalogItems"
        WHERE "organization_id" = "p_org_id"
        AND "is_roll" = true
        AND "collection_name" = "v_quote_line"."collection_name"
        AND "variant_name" = "v_quote_line"."variant_name"
        AND "is_active" = true
        LIMIT 1;
        
        IF "v_resolved_id" IS NULL THEN
            RAISE EXCEPTION 'No se encontró fabric con collection_name=%, variant_name=%', 
                "v_quote_line"."collection_name", "v_quote_line"."variant_name";
        END IF;
        
        RETURN "v_resolved_id";
        
    ELSIF "p_sku_rule" = 'ROLE_AND_COLOR' THEN
        -- Hardware: buscar por item_role + color (is_roll=false)
        -- Obtener hardware_color del config JSONB
        "v_hardware_color" := COALESCE("p_config"->>'hardware_color', NULL);
        
        IF "v_hardware_color" IS NULL THEN
            RAISE EXCEPTION 'Hardware requiere hardware_color en config (component_role: %)', "p_component_role";
        END IF;
        
        -- Verificar que no hay ambigüedad
        SELECT COUNT(*)
        INTO "v_match_count"
        FROM "public"."CatalogItems"
        WHERE "organization_id" = "p_org_id"
        AND "is_roll" = false
        AND "item_role" = "p_component_role"
        AND LOWER(COALESCE("color", '')) = LOWER("v_hardware_color")
        AND "is_active" = true;
        
        IF "v_match_count" = 0 THEN
            RAISE EXCEPTION 'No se encontró item con item_role=%, color=%', "p_component_role", "v_hardware_color";
        ELSIF "v_match_count" > 1 THEN
            RAISE EXCEPTION 'Ambigüedad: se encontraron % items con item_role=%, color=%', 
                "v_match_count", "p_component_role", "v_hardware_color";
        END IF;
        
        SELECT "id"
        INTO "v_resolved_id"
        FROM "public"."CatalogItems"
        WHERE "organization_id" = "p_org_id"
        AND "is_roll" = false
        AND "item_role" = "p_component_role"
        AND LOWER(COALESCE("color", '')) = LOWER("v_hardware_color")
        AND "is_active" = true
        LIMIT 1;
        
        RETURN "v_resolved_id";
        
    ELSE
        RAISE EXCEPTION 'sku_resolution_rule desconocido o no implementado: %', "p_sku_rule";
    END IF;
END;
$$;

COMMENT ON FUNCTION "public"."resolve_component_item_id"(uuid, text, text, uuid, jsonb, uuid, uuid) IS 
'Resuelve SKU: override > fixed > FABRIC_BY_COLLECTION_VARIANT > ROLE_AND_COLOR. Validaciones duras.';

-- Función 4: generate_bom_instance_for_quote_line(...) -> uuid
CREATE OR REPLACE FUNCTION "public"."generate_bom_instance_for_quote_line"(
    "p_org_id" uuid,
    "p_quote_line_id" uuid,
    "p_product_type_id" uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_config jsonb;
    v_template_id uuid;
    v_bom_instance_id uuid;
    v_quote_line record;
    v_bom_component record;
    v_resolved_item_id uuid;
    v_resolved_sku text;
    v_resolved_cost numeric(12,4);
    v_resolved_name text;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_cut_length_mm numeric(12,4);
    v_cut_width_mm numeric(12,4);
    v_cut_height_mm numeric(12,4);
    v_override_item_id uuid;
BEGIN
    -- 1. Construir config
    "v_config" := "public"."build_quote_line_config"("p_org_id", "p_quote_line_id");
    
    -- 2. Seleccionar best match template
    "v_template_id" := "public"."select_best_bom_template"("p_org_id", "p_product_type_id", "v_config");
    
    IF "v_template_id" IS NULL THEN
        RAISE EXCEPTION 'No se encontró BOMTemplate activo para product_type_id: %', "p_product_type_id";
    END IF;
    
    -- 3. Obtener QuoteLine (necesitamos width_m, height_m)
    SELECT "width_m", "height_m", "collection_name", "variant_name"
    INTO "v_quote_line"
    FROM "public"."QuoteLines"
    WHERE "id" = "p_quote_line_id"
    AND "organization_id" = "p_org_id";
    
    IF "v_quote_line" IS NULL THEN
        RAISE EXCEPTION 'QuoteLine no encontrado: %', "p_quote_line_id";
    END IF;
    
    -- 4. Idempotencia: marcar deleted=true si ya existe
    UPDATE "public"."BomInstances"
    SET "deleted" = true, "updated_at" = now()
    WHERE "organization_id" = "p_org_id"
    AND "quote_line_id" = "p_quote_line_id"
    AND "deleted" = false;
    
    -- 5. Crear nuevo BomInstance (verificar si config_jsonb existe)
    BEGIN
        INSERT INTO "public"."BomInstances" (
            "organization_id", "quote_line_id", "bom_template_id", "config_jsonb"
        )
        VALUES (
            "p_org_id", "p_quote_line_id", "v_template_id", "v_config"
        )
        RETURNING "id" INTO "v_bom_instance_id";
    EXCEPTION
        WHEN undefined_column THEN
            -- Si config_jsonb no existe, insertarlo sin esa columna
            INSERT INTO "public"."BomInstances" (
                "organization_id", "quote_line_id", "bom_template_id"
            )
            VALUES (
                "p_org_id", "p_quote_line_id", "v_template_id"
            )
            RETURNING "id" INTO "v_bom_instance_id";
    END;
    
    -- 6. Convertir dimensiones a mm
    "v_width_mm" := COALESCE("v_quote_line"."width_m" * 1000, 0);
    "v_height_mm" := COALESCE("v_quote_line"."height_m" * 1000, 0);
    
    -- 7. Iterar BOMComponents y crear BomInstanceLines
    FOR "v_bom_component" IN
        SELECT *
        FROM "public"."BOMComponents"
        WHERE "bom_template_id" = "v_template_id"
        AND "deleted" = false
        AND "archived" = false
        ORDER BY COALESCE("sort_order", 0)
    LOOP
        -- 7.1 Buscar override si existe
        SELECT "catalog_item_id"
        INTO "v_override_item_id"
        FROM "public"."QuoteLineComponents"
        WHERE "organization_id" = "p_org_id"
        AND "quote_line_id" = "p_quote_line_id"
        AND "kind" = 'override'
        AND "component_role" = "v_bom_component"."component_role"
        AND "deleted" = false
        LIMIT 1;
        
        -- 7.2 Resolver SKU
        "v_resolved_item_id" := "public"."resolve_component_item_id"(
            "p_org_id",
            "v_bom_component"."component_role",
            COALESCE("v_bom_component"."sku_resolution_rule", 'ROLE_AND_COLOR'),
            "p_quote_line_id",
            "v_config",
            "v_bom_component"."component_item_id",
            "v_override_item_id"
        );
        
        -- 7.3 Obtener SKU, costo y name
        SELECT "sku", COALESCE("cost_exw", 0), "name"
        INTO "v_resolved_sku", "v_resolved_cost", "v_resolved_name"
        FROM "public"."CatalogItems"
        WHERE "id" = "v_resolved_item_id";
        
        -- 7.4 Calcular qty según qty_type
        IF "v_bom_component"."qty_type" = 'fixed' THEN
            "v_qty" := COALESCE("v_bom_component"."qty_value", 1);
        ELSIF "v_bom_component"."qty_type" = 'per_width' THEN
            "v_qty" := COALESCE("v_quote_line"."width_m", 0) * COALESCE("v_bom_component"."qty_value", 1);
        ELSIF "v_bom_component"."qty_type" = 'per_height' THEN
            "v_qty" := COALESCE("v_quote_line"."height_m", 0) * COALESCE("v_bom_component"."qty_value", 1);
        ELSIF "v_bom_component"."qty_type" = 'per_area' THEN
            "v_qty" := COALESCE("v_quote_line"."width_m", 0) * COALESCE("v_quote_line"."height_m", 0) * COALESCE("v_bom_component"."qty_value", 1);
        ELSE
            "v_qty" := COALESCE("v_bom_component"."qty_value", 1);
        END IF;
        
        -- 7.5 Calcular cuts
        "v_cut_length_mm" := NULL;
        "v_cut_width_mm" := NULL;
        "v_cut_height_mm" := NULL;
        
        IF "v_bom_component"."cut_axis" = 'width' AND "v_bom_component"."cut_delta_mm" IS NOT NULL THEN
            "v_cut_length_mm" := "v_width_mm" + "v_bom_component"."cut_delta_mm";
        ELSIF "v_bom_component"."cut_axis" = 'height' AND "v_bom_component"."cut_delta_mm" IS NOT NULL THEN
            "v_cut_height_mm" := "v_height_mm" + "v_bom_component"."cut_delta_mm";
        ELSIF "v_bom_component"."cut_axis" = 'both' AND "v_bom_component"."cut_delta_mm" IS NOT NULL THEN
            "v_cut_width_mm" := "v_width_mm" + "v_bom_component"."cut_delta_mm";
            "v_cut_height_mm" := "v_height_mm" + "v_bom_component"."cut_delta_mm";
        END IF;
        
        -- 7.6 Insertar BomInstanceLine (usar part_role que existe en la tabla real)
        BEGIN
            INSERT INTO "public"."BomInstanceLines" (
                "bom_instance_id", "part_role", "resolved_part_id",
                "qty", "uom", "cut_length_mm", "cut_width_mm", "cut_height_mm",
                "unit_cost_exw", "total_cost_exw"
            )
            VALUES (
                "v_bom_instance_id",
                "v_bom_component"."component_role",
                "v_resolved_item_id",
                "v_qty",
                "v_bom_component"."uom",
                "v_cut_length_mm",
                "v_cut_width_mm",
                "v_cut_height_mm",
                "v_resolved_cost",
                "v_resolved_cost" * "v_qty"
            );
        EXCEPTION
            WHEN undefined_column THEN
                -- Si faltan columnas opcionales, insertar sin ellas
                INSERT INTO "public"."BomInstanceLines" (
                    "bom_instance_id", "part_role", "resolved_part_id",
                    "qty", "uom", "unit_cost_exw", "total_cost_exw"
                )
                VALUES (
                    "v_bom_instance_id",
                    "v_bom_component"."component_role",
                    "v_resolved_item_id",
                    "v_qty",
                    "v_bom_component"."uom",
                    "v_resolved_cost",
                    "v_resolved_cost" * "v_qty"
                );
        END;
    END LOOP;
    
    RETURN "v_bom_instance_id";
END;
$$;
