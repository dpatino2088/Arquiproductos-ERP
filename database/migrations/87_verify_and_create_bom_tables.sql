-- ====================================================
-- Migration 87: Verificar y crear tablas BOM si no existen
-- ====================================================
-- Este script verifica si las tablas BOMTemplates y BOMComponents
-- existen, y las crea si no existen
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICACIÓN DE TABLAS BOM';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Verificar si BOMTemplates existe
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMTemplates'
  ) THEN
    RAISE NOTICE '⚠️  Tabla BOMTemplates NO existe. Creándola...';
    
    -- Crear tabla BOMTemplates
    CREATE TABLE IF NOT EXISTS public."BOMTemplates" (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id uuid NOT NULL,
      product_type_id uuid NOT NULL,
      name text,
      description text,
      active boolean NOT NULL DEFAULT true,
      deleted boolean NOT NULL DEFAULT false,
      archived boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT NOW(),
      updated_at timestamptz NOT NULL DEFAULT NOW(),
      CONSTRAINT fk_bomtemplates_organization 
        FOREIGN KEY (organization_id) 
        REFERENCES public."Organizations"(id) 
        ON DELETE CASCADE,
      CONSTRAINT fk_bomtemplates_product_type 
        FOREIGN KEY (product_type_id) 
        REFERENCES public."Profiles"(id) 
        ON DELETE CASCADE,
      CONSTRAINT check_bomtemplates_name_not_empty 
        CHECK (name IS NULL OR trim(name) <> '')
    );

    -- Crear índices
    CREATE INDEX IF NOT EXISTS idx_bomtemplates_organization_id 
      ON public."BOMTemplates"(organization_id);
    CREATE INDEX IF NOT EXISTS idx_bomtemplates_product_type_id 
      ON public."BOMTemplates"(product_type_id);
    CREATE INDEX IF NOT EXISTS idx_bomtemplates_active 
      ON public."BOMTemplates"(organization_id, active) 
      WHERE deleted = false;

    -- Habilitar RLS
    ALTER TABLE public."BOMTemplates" ENABLE ROW LEVEL SECURITY;

    -- Crear políticas RLS
    DROP POLICY IF EXISTS "Users can view BOMTemplates for their organization" ON public."BOMTemplates";
    CREATE POLICY "Users can view BOMTemplates for their organization"
      ON public."BOMTemplates" FOR SELECT
      USING (
        organization_id IN (
          SELECT organization_id FROM public."OrganizationUsers"
          WHERE user_id = auth.uid() AND deleted = false
        )
      );

    DROP POLICY IF EXISTS "Users can insert BOMTemplates for their organization" ON public."BOMTemplates";
    CREATE POLICY "Users can insert BOMTemplates for their organization"
      ON public."BOMTemplates" FOR INSERT
      WITH CHECK (
        organization_id IN (
          SELECT organization_id FROM public."OrganizationUsers"
          WHERE user_id = auth.uid() 
            AND deleted = false
            AND role IN ('owner', 'admin')
        )
      );

    DROP POLICY IF EXISTS "Users can update BOMTemplates for their organization" ON public."BOMTemplates";
    CREATE POLICY "Users can update BOMTemplates for their organization"
      ON public."BOMTemplates" FOR UPDATE
      USING (
        organization_id IN (
          SELECT organization_id FROM public."OrganizationUsers"
          WHERE user_id = auth.uid() 
            AND deleted = false
            AND role IN ('owner', 'admin')
        )
      );

    DROP POLICY IF EXISTS "Users can delete BOMTemplates for their organization" ON public."BOMTemplates";
    CREATE POLICY "Users can delete BOMTemplates for their organization"
      ON public."BOMTemplates" FOR DELETE
      USING (
        organization_id IN (
          SELECT organization_id FROM public."OrganizationUsers"
          WHERE user_id = auth.uid() 
            AND deleted = false
            AND role IN ('owner', 'admin')
        )
      );

    RAISE NOTICE '   ✅ Tabla BOMTemplates creada';
  ELSE
    RAISE NOTICE '   ✅ Tabla BOMTemplates ya existe';
  END IF;

  RAISE NOTICE '';

  -- Verificar si BOMComponents existe y tiene bom_template_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'bom_template_id'
  ) THEN
    RAISE NOTICE '⚠️  Columna bom_template_id NO existe en BOMComponents. Agregándola...';
    
    -- Agregar columna bom_template_id si no existe
    ALTER TABLE public."BOMComponents"
      ADD COLUMN IF NOT EXISTS bom_template_id uuid,
      ADD CONSTRAINT fk_bomcomponents_template 
        FOREIGN KEY (bom_template_id) 
        REFERENCES public."BOMTemplates"(id) 
        ON DELETE CASCADE;

    CREATE INDEX IF NOT EXISTS idx_bomcomponents_template_id 
      ON public."BOMComponents"(bom_template_id);

    RAISE NOTICE '   ✅ Columna bom_template_id agregada';
  ELSE
    RAISE NOTICE '   ✅ Columna bom_template_id ya existe';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ VERIFICACIÓN COMPLETADA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

END $$;

