-- ============================================================================
-- ADD: organization_id y deleted a BOMInstanceLines
-- ============================================================================
-- Fecha: 2026-01-20
-- Objetivo: Agregar columnas organization_id y deleted a BOMInstanceLines
-- ============================================================================

BEGIN;

-- 0) Asegurar que la tabla BomInstances existe primero (requisito para BomInstanceLines)
CREATE TABLE IF NOT EXISTS "public"."BomInstances" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "sale_order_line_id" uuid,
    "quote_line_id" uuid,
    "bom_template_id" uuid NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    "configured_product_id" uuid,
    CONSTRAINT "bominstances_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "bominstances_bom_template_fkey" 
        FOREIGN KEY ("bom_template_id") 
        REFERENCES "public"."BOMTemplates"("id") 
        ON DELETE RESTRICT
);

-- 0.1) Asegurar que la tabla BomInstanceLines existe
-- Si no existe, crearla (esto puede pasar si la migración 20260116 no se ejecutó)
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
    -- NOTA: NO crear CHECK constraint aquí. 
    -- El constraint bominstancelines_part_role_check será reemplazado por FK 
    -- contra CatalogItemRoles en la migración 20260123_replace_check_with_fk_for_part_role.sql
);

-- Agregar deleted si no existe (para compatibilidad)
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
END $$;

-- 1) Agregar organization_id (NOT NULL con valor por defecto, luego hacer NOT NULL)
-- Primero agregamos la columna permitiendo NULL (si no existe)
ALTER TABLE public."BomInstanceLines"
  ADD COLUMN IF NOT EXISTS organization_id uuid;

-- 2) Poblar organization_id desde BomInstances
UPDATE public."BomInstanceLines" bil
SET organization_id = bi.organization_id
FROM public."BomInstances" bi
WHERE bil.bom_instance_id = bi.id
  AND bil.organization_id IS NULL;

-- 3) Hacer organization_id NOT NULL después de poblar (solo si es nullable)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BomInstanceLines'
      AND column_name = 'organization_id'
      AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE public."BomInstanceLines"
      ALTER COLUMN organization_id SET NOT NULL;
  END IF;
END $$;

-- 4) Agregar FK constraint para organization_id (si no existe)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'bominstancelines_organization_fk'
  ) THEN
    ALTER TABLE public."BomInstanceLines"
      ADD CONSTRAINT bominstancelines_organization_fk
        FOREIGN KEY (organization_id)
        REFERENCES public."Organizations"(id)
        ON DELETE CASCADE;
  END IF;
END $$;

-- 5) Agregar deleted (boolean, default false, NOT NULL)
ALTER TABLE public."BomInstanceLines"
  ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false NOT NULL;

-- 6) Agregar index para performance (filtrado por organization_id y deleted)
CREATE INDEX IF NOT EXISTS bominstancelines_org_deleted_idx
  ON public."BomInstanceLines"(organization_id, deleted)
  WHERE deleted = false;

-- 7) NOTA ARQUITECTÓNICA IMPORTANTE:
--    El constraint bominstancelines_part_role_check será eliminado y reemplazado
--    por FOREIGN KEY contra CatalogItemRoles en la migración 20260123_replace_check_with_fk_for_part_role.sql
--    
--    Esta es la arquitectura correcta: fuente única de verdad para roles.
--    NO usar CHECK constraints para roles - usar FK constraint contra tabla canónica.

-- 8) Verificar que las columnas se agregaron correctamente
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'BomInstanceLines'
  AND column_name IN ('organization_id', 'deleted')
ORDER BY column_name;

COMMIT;
