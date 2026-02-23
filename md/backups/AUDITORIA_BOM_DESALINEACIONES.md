# 🔍 AUDITORÍA BOM: Desalineaciones con Principio Fundamental

**Fecha:** 2026-01-19  
**Esquema base:** `backups/2026-01-19full.sql`  
**Código base:** Codebase actual

---

## 🧠 PRINCIPIO FUNDAMENTAL (Referencia)

> **El configurador arma una decisión comercial.**  
> **El BOM traduce esa decisión a materiales.**
> 
> - El BOMTemplate **NO** toma decisiones comerciales  
> - El BOMTemplate **NO** elige SKUs automáticamente

---

## ❌ DESALINEACIONES DETECTADAS

### 1. `BOMComponents` contiene lógica de auto-selección

**📂 Ubicación:** `BOMComponents` (tabla) + `useBOM.ts` (hook)

**❌ Problema:**
- Campo `auto_select` (boolean) existe y se usa
- Campo `sku_resolution_rule` (text) define heurísticas:
  - `'ROLE_AND_COLOR'` (por defecto)
  - `'SKU_SUFFIX_COLOR'`
  - `'EXACT_SKU'`
  - `'CATEGORY_FIRST_MATCH'`
- El sistema **inventa SKUs** basado en estas reglas

**📍 Evidencia en código:**

```sql
-- Tabla BOMComponents (línea 2951-2976)
"auto_select" boolean DEFAULT true NOT NULL,
"sku_resolution_rule" "text" DEFAULT 'ROLE_AND_COLOR'::"text" NOT NULL,
```

```typescript
// src/hooks/useBOM.ts (líneas 341-346, 406-410)
const payload = {
  ...componentData,
  organization_id: orgIdToUse,
  auto_select: false, // MVP: siempre false ✅ Ya está corregido en frontend
  qty_value: componentData.qty_value || 1,
  deleted: false,
  archived: false,
};
```

**✅ Estado actual:** Frontend ya pone `auto_select = false`, pero **el campo existe en DB** y la función SQL lo puede usar.

---

### 2. `generate_bom_instance_for_quote_line()` usa heurísticas

**📂 Ubicación:** Función SQL (líneas 874-1002)

**❌ Problema:**
```sql
-- Llama a resolve_component_item_id() con sku_resolution_rule
v_item_id := public.resolve_component_item_id(
  p_org_id,
  v_comp.component_role,
  v_comp.sku_resolution_rule, -- ❌ Usa regla del componente
  p_quote_line_id,
  v_config,
  v_comp.component_item_id,
  v_override_item
);
```

**`resolve_component_item_id()` aplica lógica automática:**
- Si `sku_rule = 'FABRIC_BY_COLLECTION_VARIANT'`: busca por collection + variant
- Si `sku_rule = 'ROLE_AND_COLOR'` (default): busca por `item_role` + `color`
- **Inventa** el SKU si el usuario no lo eligió explícitamente

**✅ Violación:** Esto es **auto-selección prohibida**.

---

### 3. `BOMTemplateSlots` NO se usa en generación de BOM

**📂 Ubicación:** Función SQL `generate_bom_instance_for_quote_line()` (líneas 916-996)

**❌ Problema:**
La función itera sobre `BOMComponents`:

```sql
FOR v_comp IN
  SELECT *
  FROM public."BOMComponents"  -- ❌ Lee de BOMComponents
  WHERE organization_id = p_org_id
    AND bom_template_id = v_template_id
    AND deleted = false
    AND archived = false
  ORDER BY (depends_on_role IS NOT NULL)::int, sort_order ASC
LOOP
  -- ... resuelve y crea líneas
END LOOP;
```

**Pero NO usa `BOMTemplateSlots`**, que según tu principio es la lista de componentes PADRE.

**✅ Violación:** El template define estructura via `BOMComponents` en lugar de `BOMTemplateSlots`.

---

### 4. `BOMInstanceLines.resolved_part_id` es NOT NULL

**📂 Ubicación:** Tabla `BOMInstanceLines` (línea 2986)

**❌ Problema:**
```sql
"resolved_part_id" "uuid" NOT NULL,
```

Esto **fuerza** resolución de SKU siempre. No permite líneas vacías.

**✅ Violación:** No permite "líneas estructurales sin SKU".

---

### 5. No existe relación explícita SKU → HIJOS

**📂 Ubicación:** Esquema completo

**❌ Problema:**
- `CatalogRoleRelations` define **rol ↔ rol**, no **SKU → HIJOS**
- No hay tabla del tipo: `CatalogItemComponents` o `SKU_Subcomponents`
- Los subcomponentes (end_cap, adapter, screw, etc.) no tienen forma de vincularse a un SKU PADRE

**✅ Violación:** No se pueden agregar HIJOS "como consecuencia del SKU elegido".

---

### 6. `BOMTemplates.tsx` gestiona `BOMComponents`, no `BOMTemplateSlots`

**📂 Ubicación:** `src/pages/catalog/BOMTemplates.tsx`

**❌ Problema:**
El UI actual:
- Crea/edita registros en `BOMComponents`
- **NO usa `BOMTemplateSlots`**
- Mezcla PADRES e HIJOS en la misma tabla

**Evidencia:**
```typescript
// BOMTemplates.tsx (líneas 314-316)
const { data: componentsData, error: componentsError } = await supabase
  .from('BOMComponents')  // ❌ Lee de BOMComponents
  .select('*')
  .in('bom_template_id', templateIds)
```

**✅ Violación:** El UI no distingue PADRES de HIJOS.

---

## ✅ RESUMEN DE VIOLACIONES

| # | Violación | Severidad | Ubicación | Estado |
|---|-----------|-----------|-----------|--------|
| 1 | `auto_select` y `sku_resolution_rule` existen | 🔴 Alta | DB Schema + SQL Functions | Activo |
| 2 | `generate_bom_instance_for_quote_line()` usa heurísticas | 🔴 Alta | SQL Function | Activo |
| 3 | `BOMTemplateSlots` no se usa en generación | 🔴 Alta | SQL Function | Activo |
| 4 | `BOMInstanceLines.resolved_part_id` NOT NULL | 🟡 Media | DB Schema | Activo |
| 5 | No existe relación SKU → HIJOS | 🔴 Alta | DB Schema | Faltante |
| 6 | UI gestiona `BOMComponents`, no `BOMTemplateSlots` | 🟡 Media | Frontend | Activo |

---

## ✅ CAMBIOS MÍNIMOS NECESARIOS (sin romper nada)

### 🎯 **FASE 1: Backend (SQL)**

#### 1.1. Crear tabla `CatalogItemComponents` (SKU → HIJOS)

```sql
-- Nueva tabla para relacionar SKUs PADRE con HIJOS
CREATE TABLE IF NOT EXISTS "public"."CatalogItemComponents" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "parent_item_id" uuid NOT NULL, -- FK → CatalogItems (SKU PADRE)
    "child_item_id" uuid NOT NULL,  -- FK → CatalogItems (SKU HIJO)
    "child_role" text NOT NULL,      -- Rol del hijo (end_cap, adapter, screw, etc)
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
            'chain_stop', 'chain_tensioner', 'end_plug', 'filler'
        ]))
);

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
```

**✅ Qué hace:** Permite vincular SKUs PADRE (motor, bracket) con sus HIJOS (adapter, end_cap).

**✅ Qué NO hace:** No rompe nada existente. Es una tabla nueva independiente.

---

#### 1.2. Modificar `BOMInstanceLines` para permitir `resolved_part_id NULL`

```sql
-- Permitir NULL temporalmente (hasta que el usuario elija SKU)
ALTER TABLE "public"."BOMInstanceLines" 
    ALTER COLUMN "resolved_part_id" DROP NOT NULL;
```

**✅ Qué hace:** Permite líneas estructurales sin SKU.

**✅ Qué NO hace:** No afecta líneas existentes (todas tienen SKU resuelto ya).

---

#### 1.3. Nueva función: `generate_bom_from_slots()`

```sql
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
    -- Resolver SKU PADRE desde QuoteLineComponents (elección del usuario)
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

    -- Obtener datos del componente desde BOMComponents (reglas de qty/corte)
    SELECT * INTO v_component
    FROM public."BOMComponents"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
      AND component_role = v_slot.item_role
      AND deleted = false
    LIMIT 1;

    -- Calcular cantidad (usar BOMComponent rules si existe)
    IF v_component.id IS NOT NULL THEN
      -- Usar lógica de qty_type del componente
      IF v_component.qty_type = 'fixed' THEN
        v_qty := v_component.qty_value;
      ELSIF v_component.qty_type = 'per_width' THEN
        v_qty := ((v_width_mm + v_component.qty_delta_mm) / 1000.0) * v_component.qty_value;
      ELSIF v_component.qty_type = 'per_height' THEN
        v_qty := ((v_height_mm + v_component.qty_delta_mm) / 1000.0) * v_component.qty_value;
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

    -- Obtener costo (solo si hay SKU resuelto)
    IF v_resolved_item IS NOT NULL THEN
      SELECT ci.cost_exw INTO v_unit_cost
      FROM public."CatalogItems" ci
      WHERE ci.id = v_resolved_item;
    ELSE
      v_unit_cost := NULL;
    END IF;

    -- Crear línea del PADRE (permitir resolved_part_id NULL)
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
      v_component.id, -- Puede ser NULL si no hay BOMComponent
      v_resolved_item, -- ✅ NULL si el usuario no eligió
      v_slot.item_role,
      v_qty,
      COALESCE(v_component.uom, 'ea'),
      CASE WHEN v_component.cut_axis = 'length' THEN (v_width_mm + v_component.cut_delta_mm) ELSE NULL END,
      CASE WHEN v_component.cut_axis = 'width'  THEN (v_width_mm + v_component.cut_delta_mm) ELSE NULL END,
      CASE WHEN v_component.cut_axis = 'height' THEN (v_height_mm + v_component.cut_delta_mm) ELSE NULL END,
      v_unit_cost,
      CASE WHEN v_unit_cost IS NULL THEN NULL ELSE v_unit_cost * v_qty END
    );

    -- ✅ NUEVO: Si el usuario eligió un SKU PADRE, agregar sus HIJOS
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
          bom_component_id,
          resolved_part_id,
          part_role,
          qty,
          uom,
          unit_cost_exw,
          total_cost_exw
        ) VALUES (
          v_instance_id,
          NULL, -- HIJO no viene de BOMComponent
          v_child.child_item_id,
          v_child.child_role,
          v_child.qty,
          v_child.uom,
          v_unit_cost,
          CASE WHEN v_unit_cost IS NULL THEN NULL ELSE v_unit_cost * v_child.qty END
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN v_instance_id;
END $$;
```

**✅ Qué hace:**
1. Lee de `BOMTemplateSlots` (PADRES)
2. Busca elecciones del usuario en `QuoteLineComponents` (kind='selection')
3. Usa reglas de qty/corte de `BOMComponents` (si existen)
4. Permite `resolved_part_id = NULL`
5. Expande HIJOS desde `CatalogItemComponents`

**✅ Qué NO hace:**
- No usa `auto_select`
- No usa `sku_resolution_rule`
- No inventa SKUs
- No rompe `BOMComponents` existentes (sigue usándolos para reglas de qty)

---

### 🎯 **FASE 2: Frontend (UI)**

#### 2.1. Modificar `BOMTemplates.tsx` para usar `BOMTemplateSlots`

**❌ Estado actual:**
- Gestiona `BOMComponents` directamente
- No distingue PADRES de HIJOS

**✅ Cambio mínimo:**
- Al crear template, crear registros en `BOMTemplateSlots` (PADRES)
- Al expandir un PADRE, mostrar/editar sus HIJOS desde `CatalogItemComponents`
- Mantener `BOMComponents` solo para reglas de qty/corte (no para resolución de SKU)

---

#### 2.2. Modificar `QuoteLineComponents` para guardar SKUs elegidos

**❌ Estado actual:**
- Solo guarda `kind = 'option'` (opciones de configuración)

**✅ Cambio mínimo:**
- Agregar `kind = 'selection'` para SKUs elegidos por el usuario
- Ejemplo:
  ```json
  {
    "kind": "selection",
    "component_role": "motor",
    "catalog_item_id": "uuid-del-motor-elegido",
    "payload": { "sku": "MTR-01-W" }
  }
  ```

---

#### 2.3. Modificar configurador para guardar SKUs elegidos

**❌ Estado actual:**
- Solo guarda opciones (color, system_size, etc.)
- No guarda SKUs específicos

**✅ Cambio mínimo:**
- En `OperatingSystemStep.tsx`: al elegir motor/drive, guardar en `QuoteLineComponents`
- En `HardwareStep.tsx`: al elegir bottom_bar/headbox, guardar en `QuoteLineComponents`
- Usar `kind = 'selection'`

---

### 🎯 **FASE 3: Migración (sin pérdida de datos)**

1. **Crear `CatalogItemComponents`** (tabla nueva, no afecta nada)
2. **Modificar `BOMInstanceLines.resolved_part_id`** a nullable
3. **Crear `generate_bom_from_slots()`** (función nueva, legacy sigue disponible)
4. **Poblar `BOMTemplateSlots`** desde `BOMComponents` existentes (migración de datos)
5. **Actualizar frontend** para usar nueva función y UI

---

## 🔄 FLUJO CORRECTO (POST-CAMBIOS)

### 1️⃣ **Creación de BOMTemplate**
```
Admin crea template → Define PADRES en BOMTemplateSlots
(motor, bracket, tube, bottom_bar, headbox, etc.)
```

### 2️⃣ **Configuración de HIJOS (UX contextual)**
```
Admin abre template → Expande "Motor MTR-01-W" → Agrega hijos:
- Adapter (ADT-01)
- End Cap (ECP-01)
→ Se guarda en CatalogItemComponents
```

### 3️⃣ **Usuario configura producto**
```
Usuario elige:
- ProductType: Roller Shade
- Fabric: Collection A, Variant Blue
- Hardware Color: White
- Motor: MTR-01-W ← ✅ Elección explícita
→ Se guarda en QuoteLineComponents (kind='selection')
```

### 4️⃣ **Generación de BOM**
```
Se llama generate_bom_from_slots() →
1. Lee PADRES de BOMTemplateSlots
2. Para cada PADRE:
   - Busca SKU elegido en QuoteLineComponents
   - Si NO eligió, deja resolved_part_id = NULL
   - Si SÍ eligió, busca HIJOS en CatalogItemComponents
3. Crea BOMInstanceLines:
   - Línea del PADRE (con o sin SKU)
   - Líneas de HIJOS (solo si hay SKU PADRE)
```

---

## 📊 COMPARATIVA: ANTES vs DESPUÉS

| Aspecto | ❌ ANTES (Actual) | ✅ DESPUÉS (Correcto) |
|---------|-------------------|----------------------|
| **Template define** | SKUs + heurísticas | Solo PADRES (roles) |
| **HIJOS viven en** | BOMComponents (mezclado) | CatalogItemComponents (por SKU) |
| **Resolución de SKU** | Automática (ROLE_AND_COLOR) | Usuario elige |
| **Líneas sin SKU** | Bloqueadas (NOT NULL) | Permitidas (NULL) |
| **UX Template** | Lista plana de componentes | Lista de PADRES + HIJOS expandibles |
| **Subcomponentes** | Por rol (heurística) | Por SKU explícito |

---

## 🛡️ GARANTÍAS (sin romper nada)

✅ **Datos existentes:**
- `BOMTemplates` actual → No se modifica
- `BOMComponents` actual → Sigue existiendo (solo para reglas qty/corte)
- `BOMInstances` actual → Compatibles con nueva función

✅ **Funciones existentes:**
- `generate_bom_instance_for_quote_line()` → Sigue disponible (legacy)
- `resolve_component_item_id()` → No se elimina (por si acaso)
- `select_best_bom_template()` → Sin cambios

✅ **Frontend existente:**
- `ProductConfigurator` → Sin cambios inmediatos (sigue funcionando)
- `BOMTemplates.tsx` → Se extiende, no se reescribe

---

## 🎯 PLAN DE EJECUCIÓN (orden recomendado)

### ✅ **Sprint 1: Backend (no invasivo)**
1. Crear tabla `CatalogItemComponents` (migration)
2. Modificar `BOMInstanceLines.resolved_part_id` a nullable
3. Crear función `generate_bom_from_slots()`
4. Poblar `BOMTemplateSlots` desde `BOMComponents` (script migración)
5. Testing de función nueva vs legacy (paralelo)

### ✅ **Sprint 2: Frontend (incremental)**
6. Agregar tab "Children" en BOMTemplates UI para editar HIJOS
7. Modificar configurador para guardar SKUs elegidos (kind='selection')
8. Actualizar `createQuoteLineFromRollerConfig()` para llamar `generate_bom_from_slots()`

### ✅ **Sprint 3: Cleanup (opcional)**
9. Deprecar `auto_select` y `sku_resolution_rule` en UI (no eliminar de DB)
10. Agregar warnings si se detectan templates usando lógica legacy
11. Documentar flujo correcto en wiki

---

## 🔐 VALIDACIÓN FINAL

### ✅ Checklist de alineación

- [ ] BOMTemplate NO decide SKUs → ✅ Slots definen roles, no SKUs
- [ ] Usuario elige SKUs → ✅ Guardado en QuoteLineComponents
- [ ] Heurísticas eliminadas → ✅ generate_bom_from_slots() no usa ROLE_AND_COLOR
- [ ] HIJOS vienen del SKU → ✅ CatalogItemComponents
- [ ] Permite líneas vacías → ✅ resolved_part_id nullable
- [ ] Sin tablas nuevas innecesarias → ✅ Solo CatalogItemComponents (necesaria)
- [ ] Sin romper datos → ✅ Todo compatible

---

## 📝 CONCLUSIÓN

**Estado actual:** ❌ **6 desalineaciones mayores** detectadas  
**Cambio propuesto:** ✅ **Mínimo, quirúrgico, sin romper nada**  
**Riesgo:** 🟢 **Bajo** (funciones legacy siguen disponibles)  
**Complejidad:** 🟡 **Media** (requiere migración de datos + nuevo flujo UI)

---

**Próximo paso:** ¿Implementar Sprint 1 (Backend)?

---

**Última actualización:** 2026-01-19  
**Autor:** Análisis basado en esquema `2026-01-19full.sql` y codebase actual
