-- ============================================================================
-- RECREATE CatalogItemComponents TABLE
-- ============================================================================
-- Script para recrear la tabla CatalogItemComponents si fue borrada accidentalmente
-- Basado en el esquema del dump: 2026-01-19_v2_full.sql
-- ============================================================================

-- 1. CREAR TABLA CatalogItemComponents
CREATE TABLE IF NOT EXISTS "public"."CatalogItemComponents" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "parent_item_id" uuid NOT NULL,
    "child_item_id" uuid NOT NULL,
    "child_role" text NOT NULL,
    "qty" numeric(12,4) DEFAULT 1 NOT NULL,
    "uom" text DEFAULT 'ea'::text NOT NULL,
    "required" boolean DEFAULT true NOT NULL,
    "notes" text,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "catalogitemcomponents_child_role_check" CHECK (
        ("child_role" = ANY (ARRAY[
            'adapter'::text, 
            'end_cap'::text, 
            'screw'::text, 
            'fastener'::text, 
            'idler'::text, 
            'chain_stop'::text, 
            'chain_tensioner'::text, 
            'end_plug'::text, 
            'filler'::text, 
            'washer'::text, 
            'nut'::text, 
            'bolt'::text, 
            'clip'::text, 
            'pin'::text
        ]))
    )
);

-- 2. PRIMARY KEY
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'catalogitemcomponents_pkey'
    ) THEN
        ALTER TABLE ONLY "public"."CatalogItemComponents"
            ADD CONSTRAINT "catalogitemcomponents_pkey" PRIMARY KEY ("id");
    END IF;
END $$;

-- 3. FOREIGN KEYS
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'catalogitemcomponents_child_fk'
    ) THEN
        ALTER TABLE ONLY "public"."CatalogItemComponents"
            ADD CONSTRAINT "catalogitemcomponents_child_fk" 
            FOREIGN KEY ("child_item_id") 
            REFERENCES "public"."CatalogItems"("id") 
            ON DELETE RESTRICT;
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'catalogitemcomponents_parent_fk'
    ) THEN
        ALTER TABLE ONLY "public"."CatalogItemComponents"
            ADD CONSTRAINT "catalogitemcomponents_parent_fk" 
            FOREIGN KEY ("parent_item_id") 
            REFERENCES "public"."CatalogItems"("id") 
            ON DELETE CASCADE;
    END IF;
END $$;

-- 4. ÍNDICES
-- Índice único: un HIJO solo puede estar una vez por PADRE
CREATE UNIQUE INDEX IF NOT EXISTS "catalogitemcomponents_unique_parent_child" 
    ON "public"."CatalogItemComponents" 
    USING btree ("organization_id", "parent_item_id", "child_item_id") 
    WHERE ("deleted" = false);

-- Índice por parent_item_id
CREATE INDEX IF NOT EXISTS "idx_catalogitemcomponents_parent" 
    ON "public"."CatalogItemComponents" 
    USING btree ("organization_id", "parent_item_id") 
    WHERE ("deleted" = false);

-- Índice por child_role
CREATE INDEX IF NOT EXISTS "idx_catalogitemcomponents_child_role" 
    ON "public"."CatalogItemComponents" 
    USING btree ("organization_id", "child_role") 
    WHERE ("deleted" = false);

-- 5. COMENTARIOS
COMMENT ON TABLE "public"."CatalogItemComponents" IS 
'SKU → HIJOS relationship. Defines which child components (adapter, end_cap, screw, etc) are included with a parent SKU (motor, bracket, etc). Used by generate_bom_from_slots() to expand children components.';

COMMENT ON COLUMN "public"."CatalogItemComponents"."parent_item_id" IS 
'FK to CatalogItems. The parent SKU (motor, bracket, tube, etc).';

COMMENT ON COLUMN "public"."CatalogItemComponents"."child_item_id" IS 
'FK to CatalogItems. The child component (adapter, end_cap, screw, etc).';

COMMENT ON COLUMN "public"."CatalogItemComponents"."child_role" IS 
'Role of child component. Must be a valid child role (adapter, end_cap, screw, etc).';

-- 6. TRIGGER: Auto-update updated_at
DROP TRIGGER IF EXISTS "trg_catalogitemcomponents_updated_at" ON "public"."CatalogItemComponents";
CREATE TRIGGER "trg_catalogitemcomponents_updated_at" 
    BEFORE UPDATE ON "public"."CatalogItemComponents" 
    FOR EACH ROW 
    EXECUTE FUNCTION "public"."set_updated_at"();

-- 7. GRANTS (Permisos)
GRANT SELECT ON TABLE "public"."CatalogItemComponents" TO "anon";
GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE "public"."CatalogItemComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemComponents" TO "service_role";

-- 8. ROW LEVEL SECURITY (RLS)
ALTER TABLE "public"."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;

-- 9. RLS POLICIES
-- Policy para SELECT: usuarios de la organización pueden leer
DROP POLICY IF EXISTS "catalogitemcomponents_select_own_org" ON "public"."CatalogItemComponents";
CREATE POLICY "catalogitemcomponents_select_own_org" 
    ON "public"."CatalogItemComponents" 
    FOR SELECT 
    USING (
        "public"."is_org_user_superadmin"("organization_id") 
        OR "public"."is_org_user_member"("organization_id")
    );

-- Policy para INSERT, UPDATE, DELETE: usuarios de la organización pueden escribir
DROP POLICY IF EXISTS "catalogitemcomponents_write_own_org" ON "public"."CatalogItemComponents";
CREATE POLICY "catalogitemcomponents_write_own_org" 
    ON "public"."CatalogItemComponents" 
    USING (
        (
            "public"."is_org_user_superadmin"("organization_id") 
            OR "public"."is_org_user_member"("organization_id")
        ) 
        AND ("deleted" = false)
    ) 
    WITH CHECK (
        "public"."is_org_user_superadmin"("organization_id") 
        OR "public"."is_org_user_member"("organization_id")
    );

-- 10. OWNER
ALTER TABLE "public"."CatalogItemComponents" OWNER TO "postgres";

-- ============================================================================
-- NOTAS:
-- - Esta tabla define la relación SKU → HIJOS (parent_item_id → child_item_id)
-- - Los child_role válidos están definidos en el CHECK constraint
-- - El índice único previene duplicados de la misma relación parent-child
-- - Los índices mejoran el rendimiento de las queries por parent_item_id y child_role
-- - RLS está habilitado con políticas para acceso por organización
-- ============================================================================
