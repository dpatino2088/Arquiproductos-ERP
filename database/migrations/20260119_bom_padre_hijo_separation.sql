/**
 * Migration: Separación PADRE-HIJO en BOM (Principio Fundamental)
 * 
 * Fecha: 2026-01-19
 * Objetivo: Alinear BOM con principio canónico (sin auto-selección)
 * Referencia: AUDITORIA_BOM_DESALINEACIONES.md
 * 
 * CAMBIOS:
 * 1. Crear tabla CatalogItemComponents (SKU → HIJOS)
 * 2. Modificar BOMInstanceLines.resolved_part_id a nullable
 * 3. Crear función generate_bom_from_slots() (nueva lógica)
 * 4. Agregar kind='selection' a QuoteLineComponents
 * 
 * GARANTÍA: No rompe datos existentes ni funciones legacy
 */

-- ============================================================================
-- 1. CREAR TABLA CatalogItemComponents (SKU → HIJOS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS "public"."CatalogItemComponents" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "parent_item_id" uuid NOT NULL,
    "child_item_id" uuid NOT NULL,
    "child_role" text NOT NULL,
    "qty" numeric(12,4) DEFAULT 1 NOT NULL,
    "uom" text DEFAULT 'ea' NOT NULL,
    "required" boolean DEFAULT true NOT NULL,
    "notes" text,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    
    CONSTRAINT "catalogitemcomponents_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "catalogitemcomponents_parent_fk" 
        FOREIGN KEY ("parent_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE,
    CONSTRAINT "catalogitemcomponents_child_fk" 
        FOREIGN KEY ("child_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT,
    CONSTRAINT "catalogitemcomponents_child_role_check" 
        CHECK ("child_role" = ANY (ARRAY[
            'adapter', 'end_cap', 'screw', 'fastener', 'idler', 
            'chain_stop', 'chain_tensioner', 'end_plug', 'filler',
            'washer', 'nut', 'bolt', 'clip', 'pin'
        ]))
);

-- Comentarios
COMMENT ON TABLE "public"."CatalogItemComponents" IS 'SKU → HIJOS relationship. Defines which child components (adapter, end_cap, screw, etc) are included with a parent SKU (motor, bracket, etc). Used by generate_bom_from_slots() to expand children components.';
COMMENT ON COLUMN "public"."CatalogItemComponents"."parent_item_id" IS 'FK to CatalogItems. The parent SKU (motor, bracket, tube, etc).';
COMMENT ON COLUMN "public"."CatalogItemComponents"."child_item_id" IS 'FK to CatalogItems. The child component (adapter, end_cap, screw, etc).';
COMMENT ON COLUMN "public"."CatalogItemComponents"."child_role" IS 'Role of child component. Must be a valid child role (adapter, end_cap, screw, etc).';

-- Índices
CREATE INDEX "idx_catalogitemcomponents_parent" 
    ON "public"."CatalogItemComponents" ("organization_id", "parent_item_id") 
    WHERE "deleted" = false;

CREATE INDEX "idx_catalogitemcomponents_child_role" 
    ON "public"."CatalogItemComponents" ("organization_id", "child_role") 
    WHERE "deleted" = false;

-- Unique: un HIJO solo puede estar una vez por PADRE
CREATE UNIQUE INDEX "catalogitemcomponents_unique_parent_child" 
    ON "public"."CatalogItemComponents" ("organization_id", "parent_item_id", "child_item_id") 
    WHERE "deleted" = false;

-- RLS Policies (mismas que BOMComponents)
ALTER TABLE "public"."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;

-- ✅ Copiar policies de BOMComponents (org member access)
-- TODO: Ajustar según RLS policies reales de la organización

-- Grants
GRANT SELECT ON TABLE "public"."CatalogItemComponents" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemComponents" TO "service_role";

-- ============================================================================
-- 2. MODIFICAR BOMInstanceLines.resolved_part_id A NULLABLE
-- ============================================================================

-- Permitir NULL para líneas estructurales sin SKU
ALTER TABLE "public"."BOMInstanceLines" 
    ALTER COLUMN "resolved_part_id" DROP NOT NULL;

COMMENT ON COLUMN "public"."BOMInstanceLines"."resolved_part_id" IS 'FK to CatalogItems. Can be NULL for structural lines without SKU (user has not selected yet).';

-- ============================================================================
-- 3. CREAR FUNCIÓN generate_bom_from_slots() (Nueva lógica sin heurísticas)
-- ============================================================================

CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots"(
  "p_org_id" uuid,
  "p_quote_line_id" uuid,
  "p_product_type_id" uuid
) RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_config jsonb;
  v_template_id uuid;
  v_instance_id uuid;
  v_ql public."QuoteLines";
  v_slot RECORD;
  v_component RECORD;
  v_resolved_item uuid;
  v_qty numeric(12,4);
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_unit_cost numeric(12,4);
  v_child RECORD;
  v_has_component_rules boolean;
BEGIN
  -- 1. Obtener QuoteLine
  SELECT * INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id AND organization_id = p_org_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  -- 2. Construir config desde QuoteLineComponents
  v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
  
  -- 3. Seleccionar mejor template
  v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

  -- 4. Soft-delete instancias previas (idempotencia)
  UPDATE public."BOMInstances"
    SET deleted = true
  WHERE organization_id = p_org_id
    AND quote_line_id = p_quote_line_id
    AND deleted = false;

  -- 5. Crear nueva instancia
  INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id)
  VALUES (p_org_id, p_quote_line_id, v_template_id)
  RETURNING id INTO v_instance_id;

  v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
  v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

  -- ✅ NUEVO: Iterar BOMTemplateSlots (PADRES), no BOMComponents
  FOR v_slot IN
    SELECT *
    FROM public."BOMTemplateSlots"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
    ORDER BY item_role ASC
  LOOP
    -- ✅ PASO 1: Resolver SKU PADRE desde QuoteLineComponents (elección del usuario)
    -- Buscar si el usuario eligió un SKU para este role
    SELECT qlc.catalog_item_id INTO v_resolved_item
    FROM public."QuoteLineComponents" qlc
    WHERE qlc.organization_id = p_org_id
      AND qlc.quote_line_id = p_quote_line_id
      AND qlc.component_role = v_slot.item_role
      AND qlc.kind = 'selection' -- ✅ NUEVO kind para SKUs elegidos
      AND qlc.deleted = false
    LIMIT 1;

    -- Si no eligió, usar catalog_item_id fijo del slot (si existe)
    IF v_resolved_item IS NULL THEN
      v_resolved_item := v_slot.catalog_item_id;
    END IF;

    -- ✅ PASO 2: Obtener reglas de qty/corte desde BOMComponents (si existen)
    -- BOMComponents ahora solo sirve para definir reglas de cálculo, NO para resolución de SKU
    SELECT * INTO v_component
    FROM public."BOMComponents"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
      AND component_role = v_slot.item_role
      AND deleted = false
    LIMIT 1;

    v_has_component_rules := (v_component.id IS NOT NULL);

    -- ✅ PASO 3: Calcular cantidad
    IF v_has_component_rules THEN
      -- Usar lógica de qty_type del componente
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
      -- Fallback: cantidad del slot
      v_qty := v_slot.qty;
    END IF;

    -- ✅ PASO 4: Obtener costo (solo si hay SKU resuelto)
    IF v_resolved_item IS NOT NULL THEN
      SELECT ci.cost_exw INTO v_unit_cost
      FROM public."CatalogItems" ci
      WHERE ci.id = v_resolved_item;
    ELSE
      v_unit_cost := NULL;
    END IF;

    -- ✅ PASO 5: Crear línea del PADRE (permitir resolved_part_id NULL)
    INSERT INTO public."BOMInstanceLines"(
      bom_instance_id,
      bom_component_id,
      resolved_part_id, -- ✅ Puede ser NULL
      part_role,
      qty,
      uom,
      cut_length_mm,
      cut_width_mm,
      cut_height_mm,
      unit_cost_exw,
      total_cost_exw
    ) VALUES (
      v_instance_id,
      v_component.id, -- Puede ser NULL si no hay BOMComponent con reglas
      v_resolved_item, -- ✅ NULL si el usuario no eligió
      v_slot.item_role,
      v_qty,
      COALESCE(v_component.uom, 'ea'),
      CASE 
        WHEN v_has_component_rules AND v_component.cut_axis = 'length' 
        THEN (v_width_mm + COALESCE(v_component.cut_delta_mm, 0)) 
        ELSE NULL 
      END,
      CASE 
        WHEN v_has_component_rules AND v_component.cut_axis = 'width' 
        THEN (v_width_mm + COALESCE(v_component.cut_delta_mm, 0)) 
        ELSE NULL 
      END,
      CASE 
        WHEN v_has_component_rules AND v_component.cut_axis = 'height' 
        THEN (v_height_mm + COALESCE(v_component.cut_delta_mm, 0)) 
        ELSE NULL 
      END,
      v_unit_cost,
      CASE WHEN v_unit_cost IS NULL THEN NULL ELSE v_unit_cost * v_qty END
    );

    -- ✅ PASO 6: Si el usuario eligió un SKU PADRE, agregar sus HIJOS
    IF v_resolved_item IS NOT NULL THEN
      FOR v_child IN
        SELECT *
        FROM public."CatalogItemComponents"
        WHERE organization_id = p_org_id
          AND parent_item_id = v_resolved_item
          AND deleted = false
        ORDER BY sort_order ASC
      LOOP
        -- Obtener costo del HIJO
        SELECT ci.cost_exw INTO v_unit_cost
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.child_item_id;

        -- Insertar línea del HIJO
        INSERT INTO public."BOMInstanceLines"(
          bom_instance_id,
          bom_component_id, -- NULL para hijos (no vienen de BOMComponent)
          resolved_part_id,
          part_role,
          qty,
          uom,
          cut_length_mm,
          cut_width_mm,
          cut_height_mm,
          unit_cost_exw,
          total_cost_exw
        ) VALUES (
          v_instance_id,
          NULL, -- ✅ HIJO no viene de BOMComponent
          v_child.child_item_id,
          v_child.child_role,
          v_child.qty,
          v_child.uom,
          NULL, -- Hijos no requieren corte
          NULL,
          NULL,
          v_unit_cost,
          CASE WHEN v_unit_cost IS NULL THEN NULL ELSE v_unit_cost * v_child.qty END
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN v_instance_id;
END $$;

ALTER FUNCTION "public"."generate_bom_from_slots"(uuid, uuid, uuid) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."generate_bom_from_slots"(uuid, uuid, uuid) IS 'Generate BOM instance using BOMTemplateSlots (PARENTS) and CatalogItemComponents (CHILDREN). No auto-selection or heuristics. User selections from QuoteLineComponents (kind=selection). Allows resolved_part_id NULL for unselected items.';

-- Grants
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots"(uuid, uuid, uuid) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots"(uuid, uuid, uuid) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots"(uuid, uuid, uuid) TO "service_role";

-- ============================================================================
-- 4. POBLAR BOMTemplateSlots DESDE BOMComponents (Migración de datos)
-- ============================================================================

-- Solo copiar componentes PADRE (roles principales que el usuario elige)
-- Excluir HIJOS (adapter, end_cap, screw, etc) que deben vivir en CatalogItemComponents

DO $$
DECLARE
  v_parent_roles text[] := ARRAY[
    'tube', 'track', 'bottom_bar', 'bottom_channel', 
    'side_channel', 'top_rail', 'headbox', 'bracket', 
    'drive', 'motor', 'hem_weight', 'tape', 'belt', 'carrier'
  ];
  v_record RECORD;
  v_count integer := 0;
BEGIN
  -- Insertar slots solo para roles PADRE, evitando duplicados
  FOR v_record IN
    SELECT DISTINCT ON (organization_id, bom_template_id, component_role)
      organization_id,
      bom_template_id,
      component_role,
      component_item_id,
      uom,
      CASE 
        WHEN qty_type = 'fixed' THEN qty_value 
        ELSE 1 
      END as qty
    FROM public."BOMComponents"
    WHERE deleted = false
      AND archived = false
      AND component_role = ANY(v_parent_roles)
    ORDER BY organization_id, bom_template_id, component_role, created_at DESC
  LOOP
    -- Verificar si ya existe el slot
    IF NOT EXISTS (
      SELECT 1 
      FROM public."BOMTemplateSlots"
      WHERE organization_id = v_record.organization_id
        AND bom_template_id = v_record.bom_template_id
        AND item_role = v_record.component_role
    ) THEN
      -- Insertar slot
      INSERT INTO public."BOMTemplateSlots" (
        organization_id,
        bom_template_id,
        item_role,
        required,
        catalog_item_id,
        qty,
        notes
      ) VALUES (
        v_record.organization_id,
        v_record.bom_template_id,
        v_record.component_role,
        true, -- Por defecto requerido
        v_record.component_item_id, -- Puede ser NULL (auto-select en legacy)
        v_record.qty,
        'Migrated from BOMComponents'
      );
      
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'Migrated % BOMTemplateSlots from BOMComponents', v_count;
END $$;

-- ============================================================================
-- 5. AGREGAR kind='selection' A QuoteLineComponents (documentación)
-- ============================================================================

-- No requiere cambio de schema, solo agregar validación en constraint
-- QuoteLineComponents.kind ya es text, solo se agrega valor 'selection'

COMMENT ON COLUMN "public"."QuoteLineComponents"."kind" IS 'Type of component entry: 
- "option": Configuration option (color, size, etc)
- "override": Manual override of BOM component
- "selection": User-selected SKU for a parent role (motor, bracket, etc)';

-- ============================================================================
-- 6. FUNCIÓN HELPER: get_parent_sku_selections() (para debugging)
-- ============================================================================

CREATE OR REPLACE FUNCTION "public"."get_parent_sku_selections"(
  "p_org_id" uuid,
  "p_quote_line_id" uuid
) RETURNS TABLE(
  component_role text,
  catalog_item_id uuid,
  sku text,
  item_name text
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    qlc.component_role,
    qlc.catalog_item_id,
    ci.sku,
    ci.name as item_name
  FROM public."QuoteLineComponents" qlc
  LEFT JOIN public."CatalogItems" ci ON ci.id = qlc.catalog_item_id
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection'
    AND qlc.deleted = false
  ORDER BY qlc.created_at ASC;
$$;

ALTER FUNCTION "public"."get_parent_sku_selections"(uuid, uuid) OWNER TO "postgres";
COMMENT ON FUNCTION "public"."get_parent_sku_selections"(uuid, uuid) IS 'Get all parent SKU selections made by user for a quote line. Used for debugging and validation.';

-- Grants
GRANT ALL ON FUNCTION "public"."get_parent_sku_selections"(uuid, uuid) TO "anon";
GRANT ALL ON FUNCTION "public"."get_parent_sku_selections"(uuid, uuid) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_parent_sku_selections"(uuid, uuid) TO "service_role";

-- ============================================================================
-- 7. TRIGGER: Auto-update updated_at para CatalogItemComponents
-- ============================================================================

CREATE OR REPLACE TRIGGER "trg_catalogitemcomponents_updated_at" 
  BEFORE UPDATE ON "public"."CatalogItemComponents" 
  FOR EACH ROW 
  EXECUTE FUNCTION "public"."set_updated_at"();

-- ============================================================================
-- 8. VALIDACIÓN: Verificar integridad post-migración
-- ============================================================================

-- Query de verificación (ejecutar después de migración)
DO $$
DECLARE
  v_templates_count integer;
  v_slots_count integer;
  v_components_count integer;
BEGIN
  SELECT COUNT(*) INTO v_templates_count FROM public."BOMTemplates" WHERE deleted = false;
  SELECT COUNT(*) INTO v_slots_count FROM public."BOMTemplateSlots";
  SELECT COUNT(*) INTO v_components_count FROM public."BOMComponents" WHERE deleted = false;

  RAISE NOTICE 'BOMTemplates: %, BOMTemplateSlots: %, BOMComponents: %', 
    v_templates_count, v_slots_count, v_components_count;
  
  IF v_templates_count > 0 AND v_slots_count = 0 THEN
    RAISE WARNING 'BOMTemplates exist but no BOMTemplateSlots found. Run migration script to populate slots.';
  END IF;
END $$;

-- ============================================================================
-- 9. DEPRECATION NOTICE (no eliminar, solo marcar como legacy)
-- ============================================================================

-- Agregar comentarios deprecation a funciones legacy
COMMENT ON FUNCTION "public"."generate_bom_instance_for_quote_line"(uuid, uuid, uuid) IS 
'LEGACY function. Uses BOMComponents with auto-selection heuristics. 
Use generate_bom_from_slots() instead for new implementations. 
Kept for backward compatibility with existing data.';

COMMENT ON FUNCTION "public"."resolve_component_item_id"(uuid, text, text, uuid, jsonb, uuid, uuid) IS 
'LEGACY function. Uses sku_resolution_rule heuristics (ROLE_AND_COLOR, etc). 
New BOM generation uses explicit user selections (QuoteLineComponents kind=selection). 
Kept for backward compatibility.';

-- ============================================================================
-- 10. EJEMPLO: Poblar HIJOS para un motor (manual de uso)
-- ============================================================================

-- Ejemplo: Motor MTR-01-W tiene adapter y end_cap como HIJOS
-- Ejecutar manualmente después de crear los CatalogItems correspondientes

/*
-- Primero, obtener IDs
SELECT id, sku, name FROM public."CatalogItems" 
WHERE sku IN ('MTR-01-W', 'ADT-01', 'ECP-01-W')
  AND organization_id = 'YOUR_ORG_ID';

-- Luego, insertar relaciones
INSERT INTO public."CatalogItemComponents" (
  organization_id,
  parent_item_id,
  child_item_id,
  child_role,
  qty,
  uom,
  required,
  notes
) VALUES 
  -- Motor MTR-01-W → Adapter ADT-01
  ('YOUR_ORG_ID', 'ID_MTR_01_W', 'ID_ADT_01', 'adapter', 1, 'ea', true, 'Required adapter for motor'),
  -- Motor MTR-01-W → End Cap ECP-01-W
  ('YOUR_ORG_ID', 'ID_MTR_01_W', 'ID_ECP_01_W', 'end_cap', 2, 'ea', true, 'Left and right end caps');
*/

-- ============================================================================
-- NOTAS FINALES
-- ============================================================================

-- ✅ Esta migración NO rompe:
--   - BOMTemplates existentes (sin cambios)
--   - BOMComponents existentes (siguen disponibles para reglas de qty)
--   - generate_bom_instance_for_quote_line() sigue funcionando (legacy)
--   - Datos existentes de BOMInstances / BOMInstanceLines

-- ✅ Esta migración AGREGA:
--   - Tabla CatalogItemComponents (SKU → HIJOS)
--   - Función generate_bom_from_slots() (sin heurísticas)
--   - BOMTemplateSlots poblados desde BOMComponents (PADRES)
--   - Soporte para resolved_part_id NULL

-- ✅ Próximo paso:
--   - Frontend: Modificar BOMTemplates UI para editar HIJOS
--   - Configurador: Guardar SKUs elegidos (kind='selection')
--   - Cambiar llamada de generate_bom_instance_for_quote_line() → generate_bom_from_slots()
