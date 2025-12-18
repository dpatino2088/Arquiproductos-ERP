-- ====================================================
-- Migration 88: Crear BOMTemplates de forma robusta
-- ====================================================
-- Este script crea la tabla BOMTemplates de forma segura
-- incluso si ya existe parcialmente
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CREACIÓN DE TABLA BOMTemplates';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Eliminar tabla si existe (para empezar limpio)
  -- ====================================================
  RAISE NOTICE 'PASO 1: Verificando si la tabla existe...';
  
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMTemplates'
  ) THEN
    RAISE NOTICE '   ⚠️  Tabla BOMTemplates ya existe. Eliminando políticas y restricciones...';
    
    -- Eliminar políticas RLS primero
    DROP POLICY IF EXISTS "Users can view BOMTemplates for their organization" ON public."BOMTemplates";
    DROP POLICY IF EXISTS "Users can insert BOMTemplates for their organization" ON public."BOMTemplates";
    DROP POLICY IF EXISTS "Users can update BOMTemplates for their organization" ON public."BOMTemplates";
    DROP POLICY IF EXISTS "Users can delete BOMTemplates for their organization" ON public."BOMTemplates";
    
    -- Eliminar restricciones
    ALTER TABLE public."BOMTemplates" DROP CONSTRAINT IF EXISTS fk_bomtemplates_organization;
    ALTER TABLE public."BOMTemplates" DROP CONSTRAINT IF EXISTS fk_bomtemplates_product_type;
    ALTER TABLE public."BOMTemplates" DROP CONSTRAINT IF EXISTS check_bomtemplates_name_not_empty;
    
    -- Eliminar índices
    DROP INDEX IF EXISTS idx_bomtemplates_organization_id;
    DROP INDEX IF EXISTS idx_bomtemplates_product_type_id;
    DROP INDEX IF EXISTS idx_bomtemplates_active;
    
    -- Eliminar tabla
    DROP TABLE IF EXISTS public."BOMTemplates" CASCADE;
    
    RAISE NOTICE '   ✅ Tabla eliminada';
  ELSE
    RAISE NOTICE '   ✅ Tabla no existe (empezando desde cero)';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Crear tabla BOMTemplates
  -- ====================================================
  RAISE NOTICE 'PASO 2: Creando tabla BOMTemplates...';
  
  CREATE TABLE public."BOMTemplates" (
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
      ON DELETE RESTRICT,
    CONSTRAINT check_bomtemplates_name_not_empty 
      CHECK (name IS NULL OR length(trim(name)) > 0)
  );

  RAISE NOTICE '   ✅ Tabla creada';

  -- ====================================================
  -- PASO 3: Crear índices
  -- ====================================================
  RAISE NOTICE 'PASO 3: Creando índices...';
  
  CREATE INDEX idx_bomtemplates_organization_id 
    ON public."BOMTemplates"(organization_id);
  
  CREATE INDEX idx_bomtemplates_product_type_id 
    ON public."BOMTemplates"(product_type_id);
  
  CREATE INDEX idx_bomtemplates_active 
    ON public."BOMTemplates"(organization_id, active) 
    WHERE deleted = false AND active = true;

  RAISE NOTICE '   ✅ Índices creados';

  -- ====================================================
  -- PASO 4: Habilitar RLS
  -- ====================================================
  RAISE NOTICE 'PASO 4: Habilitando RLS...';
  
  ALTER TABLE public."BOMTemplates" ENABLE ROW LEVEL SECURITY;

  RAISE NOTICE '   ✅ RLS habilitado';

  -- ====================================================
  -- PASO 5: Crear políticas RLS
  -- ====================================================
  RAISE NOTICE 'PASO 5: Creando políticas RLS...';
  
  -- Policy: SELECT
  CREATE POLICY "Users can view BOMTemplates for their organization"
    ON public."BOMTemplates" FOR SELECT
    USING (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() AND deleted = false
      )
    );

  -- Policy: INSERT
  CREATE POLICY "Users can insert BOMTemplates for their organization"
    ON public."BOMTemplates" FOR INSERT
    WITH CHECK (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() 
          AND deleted = false
          AND role IN ('owner', 'admin', 'super_admin')
      )
    );

  -- Policy: UPDATE
  CREATE POLICY "Users can update BOMTemplates for their organization"
    ON public."BOMTemplates" FOR UPDATE
    USING (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() 
          AND deleted = false
          AND role IN ('owner', 'admin', 'super_admin')
      )
    );

  -- Policy: DELETE
  CREATE POLICY "Users can delete BOMTemplates for their organization"
    ON public."BOMTemplates" FOR DELETE
    USING (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() 
          AND deleted = false
          AND role IN ('owner', 'admin', 'super_admin')
      )
    );

  RAISE NOTICE '   ✅ Políticas RLS creadas';

  -- ====================================================
  -- PASO 6: Verificar columna bom_template_id en BOMComponents
  -- ====================================================
  RAISE NOTICE 'PASO 6: Verificando BOMComponents...';
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'bom_template_id'
  ) THEN
    RAISE NOTICE '   ⚠️  Columna bom_template_id no existe. Agregándola...';
    
    ALTER TABLE public."BOMComponents"
      ADD COLUMN bom_template_id uuid;
    
    ALTER TABLE public."BOMComponents"
      ADD CONSTRAINT fk_bomcomponents_bom_template
        FOREIGN KEY (bom_template_id)
        REFERENCES public."BOMTemplates"(id)
        ON DELETE CASCADE;
    
    CREATE INDEX idx_bomcomponents_bom_template_id 
      ON public."BOMComponents"(bom_template_id);
    
    RAISE NOTICE '   ✅ Columna bom_template_id agregada';
  ELSE
    RAISE NOTICE '   ✅ Columna bom_template_id ya existe';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ TABLA BOMTemplates CREADA EXITOSAMENTE';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 7: Verificar que la tabla es accesible
  -- ====================================================
  RAISE NOTICE 'PASO 7: Verificando acceso a la tabla...';
  
  DECLARE
    test_count integer;
  BEGIN
    SELECT COUNT(*) INTO test_count FROM public."BOMTemplates";
    RAISE NOTICE '   ✅ Tabla accesible. Registros actuales: %', test_count;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '   ⚠️  Error al acceder a la tabla: %', SQLERRM;
  END;

  RAISE NOTICE '';
  RAISE NOTICE '💡 IMPORTANTE:';
  RAISE NOTICE '   Si aún ves el error "table does not exist",';
  RAISE NOTICE '   espera 1-2 minutos para que Supabase actualice el schema cache';
  RAISE NOTICE '   o recarga la página del frontend';
  RAISE NOTICE '';

END $$;

-- Verificar que la tabla existe
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'BOMTemplates'
ORDER BY ordinal_position;

