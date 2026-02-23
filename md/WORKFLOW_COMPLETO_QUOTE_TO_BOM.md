# 🔄 Workflow Completo: Quote → SalesOrder → BOM

## 📋 Resumen Ejecutivo

Este documento describe el flujo completo desde que se aprueba un Quote hasta que se genera y visualiza el BOM (Bill of Materials) en la UI.

---

## 🎯 FASE 1: Aprobación del Quote

### 1.1 Usuario aprueba Quote en la UI
- **Acción**: Usuario cambia el `status` del Quote de `'draft'` a `'approved'` en la UI
- **Tabla afectada**: `Quotes`
- **Campo cambiado**: `status = 'approved'`

### 1.2 Trigger se dispara automáticamente
- **Trigger**: `trg_on_quote_approved_create_operational_docs`
- **Tabla**: `Quotes`
- **Evento**: `AFTER UPDATE OF status`
- **Condición**: `WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')`
- **Función ejecutada**: `on_quote_approved_create_operational_docs()`

---

## 🎯 FASE 2: Creación de SalesOrder (en `on_quote_approved_create_operational_docs`)

### 2.1 Verificar si SalesOrder ya existe
```sql
SELECT id FROM "SalesOrders"
WHERE quote_id = NEW.id
AND organization_id = v_quote_record.organization_id
AND deleted = false
```

### 2.2 Si NO existe, crear SalesOrder
- **Generar número**: `SO-` + contador (ej: `SO-090151`)
- **Insertar en**: `SalesOrders`
- **Campos importantes**:
  - `quote_id` = ID del Quote aprobado
  - `sale_order_no` = Número generado
  - `status` = `'draft'`
  - `deleted` = `false` ⚠️ **CRÍTICO**
  - `organization_id` = Del Quote
  - `customer_id` = Del Quote
  - `subtotal`, `tax`, `total` = Del Quote

### 2.3 Crear SalesOrderLines
- **Para cada** `QuoteLine` del Quote:
  - **Insertar en**: `SalesOrderLines`
  - **Campos importantes**:
    - `sale_order_id` = ID del SalesOrder creado
    - `quote_line_id` = ID del QuoteLine
    - `catalog_item_id` = Del QuoteLine
    - `width_m`, `height_m` = Del QuoteLine ⚠️ **CRÍTICO para BOM**
    - `product_type_id` = Del QuoteLine ⚠️ **CRÍTICO para BOM**
    - `deleted` = `false`

---

## 🎯 FASE 3: Generación de QuoteLineComponents (si no existen)

### 3.1 Verificar si QuoteLineComponents existen
```sql
SELECT COUNT(*) FROM "QuoteLineComponents"
WHERE quote_line_id = v_quote_line_record.id
AND source = 'configured_component'
AND deleted = false
```

### 3.2 Si NO existen y hay `product_type_id`
- **Llamar función**: `generate_configured_bom_for_quote_line()`
- **Parámetros**:
  - `quote_line_id`
  - `product_type_id`
  - `organization_id`
  - `drive_type`, `bottom_rail_type`, etc.
  - `width_m`, `height_m`, `qty`
- **Resultado**: Crea `QuoteLineComponents` con todos los componentes del BOM

### 3.3 QuoteLineComponents creados
- **Tabla**: `QuoteLineComponents`
- **Campos importantes**:
  - `quote_line_id` = ID del QuoteLine
  - `catalog_item_id` = ID del componente (ej: tube, bracket, fabric)
  - `component_role` = Rol del componente (ej: `'tube'`, `'bracket'`, `'fabric'`)
  - `qty` = Cantidad
  - `uom` = Unidad de medida
  - `source` = `'configured_component'`
  - `deleted` = `false`

---

## 🎯 FASE 4: Creación de BomInstance

### 4.1 Buscar BOMTemplate
```sql
SELECT id FROM "BOMTemplates"
WHERE product_type_id = v_quote_line_record.product_type_id
AND deleted = false
AND active = true
ORDER BY organization_id match, created_at DESC
LIMIT 1
```

### 4.2 Crear BomInstance
- **Insertar en**: `BomInstances`
- **Campos importantes**:
  - `organization_id` = Del Quote
  - `sale_order_line_id` = ID del SalesOrderLine
  - `quote_line_id` = ID del QuoteLine
  - `bom_template_id` = ID del BOMTemplate encontrado
  - `deleted` = `false`

---

## 🎯 FASE 5: Creación de BomInstanceLines (desde QuoteLineComponents)

### 5.1 Para cada QuoteLineComponent
- **Iterar sobre**: Todos los `QuoteLineComponents` del QuoteLine
- **Filtrar**: `source = 'configured_component'` y `deleted = false`

### 5.2 Insertar BomInstanceLine
- **Insertar en**: `BomInstanceLines`
- **Campos importantes**:
  - `bom_instance_id` = ID del BomInstance
  - `resolved_part_id` = `catalog_item_id` del QuoteLineComponent
  - `resolved_sku` = SKU del CatalogItem
  - `part_role` = `component_role` del QuoteLineComponent ⚠️ **CRÍTICO**
  - `qty` = Del QuoteLineComponent
  - `uom` = Normalizado a canónico (ej: `'ea'`, `'m'`, `'m2'`)
  - `description` = Nombre del item
  - `unit_cost_exw`, `total_cost_exw` = Calculados
  - `category_code` = Derivado del `component_role`
  - `deleted` = `false`
  - `cut_length_mm` = `NULL` (se calcula después)
  - `cut_width_mm` = `NULL`
  - `cut_height_mm` = `NULL`
  - `calc_notes` = `NULL`

### 5.3 Estado después de esta fase
- ✅ BomInstance creado
- ✅ BomInstanceLines creados
- ❌ `cut_length_mm` = NULL (aún no calculado)
- ❌ Materiales lineales aún en `uom='ea'` (aún no convertidos)

---

## 🎯 FASE 6: Aplicación de Reglas de Ingeniería

### 6.1 Llamar función de reglas
- **Función**: `apply_engineering_rules_and_convert_linear_uom(bom_instance_id)`
- **Esta función hace 3 cosas**:
  1. Aplica reglas de ingeniería (calcula `cut_length_mm`)
  2. Corrige `part_role` NULL
  3. Convierte materiales lineales a metros

### 6.2 Paso 6.2.1: Aplicar reglas de ingeniería
- **Función interna**: `apply_engineering_rules_to_bom_instance(bom_instance_id)`

#### 6.2.1.1 Obtener dimensiones
- **Desde**: `SalesOrderLines` → `width_m`, `height_m`
- **Si no hay**: Intentar desde `QuoteLines`

#### 6.2.1.2 Para cada BomInstanceLine
- **Obtener**: `part_role` del BomInstanceLine (ej: `'tube'`, `'fabric'`, `'bracket'`)
- **Normalizar**: `normalize_component_role(part_role)` (ej: `'tubes'` → `'tube'`)

#### 6.2.1.3 Calcular dimensiones base
- **Si `part_role = 'tube'`**: `base_length_mm = width_m * 1000`
- **Si `part_role = 'bottom_rail_profile'`**: `base_length_mm = width_m * 1000`
- **Si `part_role = 'fabric'`**: `base_width_mm = width_m * 1000`, `base_height_mm = height_m * 1000`

#### 6.2.1.4 Buscar reglas que afectan este material
```sql
SELECT * FROM "BOMComponents"
WHERE bom_template_id = v_bom_template_id
AND affects_role = v_normalized_target_role  -- ⚠️ MATCH con part_role
AND cut_axis IS NOT NULL
AND cut_axis <> 'none'
AND cut_delta_mm IS NOT NULL
```

**⚠️ IMPORTANTE**: El match es `bil.part_role` vs `bc.affects_role` (NO `component_role`)

#### 6.2.1.5 Aplicar deltas
- **Para cada regla encontrada**:
  - Buscar materiales "fuente" con `part_role = bc.component_role`
  - Aplicar `cut_delta_mm` según `cut_axis` y `cut_delta_scope`
  - Acumular deltas: `cut_length_mm = base_length_mm + deltas`

#### 6.2.1.6 Actualizar BomInstanceLine
- **Actualizar**:
  - `cut_length_mm` = Valor calculado
  - `cut_width_mm` = Valor calculado (si aplica)
  - `cut_height_mm` = Valor calculado (si aplica)
  - `calc_notes` = Notas explicativas

### 6.3 Paso 6.3: Corregir part_role NULL
- **Función**: `fix_null_part_roles(bom_instance_id)`
- **Hace**: Si `part_role` es NULL, intenta obtenerlo de `BOMComponents` o `QuoteLineComponents`

### 6.4 Paso 6.4: Convertir materiales lineales a metros
- **Función**: `convert_linear_roles_to_meters(bom_instance_id)`

#### 6.4.1 Identificar materiales lineales
- **Función helper**: `is_linear_role(part_role)`
- **Roles lineales**: `'tube'`, `'bottom_rail_profile'`

#### 6.4.2 Convertir a metros
- **Condición**: `part_role IN ('tube', 'bottom_rail_profile')` AND `cut_length_mm IS NOT NULL` AND `uom = 'ea'`
- **Actualizar**:
  - `uom` = `'m'`
  - `qty` = `round(cut_length_mm / 1000, 3)`
  - `updated_at` = `now()`

---

## 🎯 FASE 7: Visualización en UI

### 7.1 Usuario navega a Manufacturing Order
- **Ruta**: `/manufacturing/manufacturing-orders/{mo_id}`
- **Tab**: "Materials"

### 7.2 Hook carga materiales
- **Hook**: `useManufacturingMaterials(saleOrderId)`
- **Query**:
  1. Obtener `SalesOrderLines` del `sale_order_id`
  2. Obtener `BomInstances` de esos `SalesOrderLines`
  3. Obtener `BomInstanceLines` de esos `BomInstances`
  4. Filtrar: `deleted = false` y `organization_id = activeOrganizationId`

### 7.3 UI muestra materiales
- **Tabla**: Muestra cada BomInstanceLine
- **Columnas**: SKU, Descripción, Qty, UOM, Costo, Cut Length (mm)
- **Agrupado por**: `part_role` o `category_code`

---

## ⚠️ PUNTOS CRÍTICOS DEL WORKFLOW

### 1. SalesOrder debe tener `deleted = false`
- **Problema**: Si `deleted = true`, no aparece en UI
- **Solución**: Migración 224 corrige el INSERT para incluir `deleted = false`

### 2. QuoteLineComponents deben existir
- **Problema**: Sin QuoteLineComponents, no se crean BomInstanceLines
- **Solución**: El trigger intenta generarlos automáticamente si no existen

### 3. SalesOrderLine debe tener dimensiones
- **Problema**: Sin `width_m` o `height_m`, no se pueden calcular cortes
- **Solución**: Se copian del QuoteLine al crear SalesOrderLine

### 4. BOMTemplate debe existir y estar activo
- **Problema**: Sin BOMTemplate, no se crea BomInstance
- **Solución**: Verificar que existe para el `product_type_id`

### 5. Reglas de ingeniería deben estar configuradas
- **Problema**: Sin reglas, no se calcula `cut_length_mm`
- **Solución**: Verificar que `BOMComponents` tiene reglas con `affects_role` correcto

### 6. Match de roles debe ser correcto
- **Problema**: `bil.part_role` debe coincidir con `bc.affects_role` (NO `component_role`)
- **Solución**: Función `apply_engineering_rules_to_bom_instance` hace el match correcto

### 7. Materiales lineales deben convertirse
- **Problema**: `tube` y `bottom_rail_profile` deben estar en metros, no en `'ea'`
- **Solución**: Función `convert_linear_roles_to_meters` hace la conversión

---

## 🔍 DIAGNÓSTICO ACTUAL

### Problema identificado:
- ✅ SalesOrder se crea correctamente
- ✅ BomInstance se crea correctamente
- ✅ BomInstanceLines se crean correctamente
- ❌ Reglas de ingeniería NO se aplican
- ❌ Materiales lineales NO se convierten a metros

### Causa probable:
Según la query #4 de `DEBUG_WHY_RULES_NOT_APPLYING.sql`:
- El material es `fabric` (no es lineal)
- Las reglas afectan a `tube` y `bottom_rail_profile`
- **NO HAY MATCH** porque `fabric` ≠ `tube` ni `bottom_rail_profile`

### Solución:
1. Verificar si hay materiales `tube` o `bottom_rail_profile` en el BOM
2. Si no hay, las reglas no aplican (es correcto)
3. Si hay pero no se aplican, verificar dimensiones y configuración de reglas

---

## 📝 CHECKLIST DE VERIFICACIÓN

Para verificar que el workflow funciona correctamente:

- [ ] Quote tiene `status = 'approved'`
- [ ] SalesOrder existe con `deleted = false`
- [ ] SalesOrderLines existen con `width_m` y `height_m` NOT NULL
- [ ] QuoteLineComponents existen (al menos 1)
- [ ] BomInstance existe
- [ ] BomInstanceLines existen
- [ ] BOMTemplate existe y está activo
- [ ] BOMComponents tiene reglas con `affects_role` correcto
- [ ] Materiales lineales (`tube`, `bottom_rail_profile`) tienen `cut_length_mm` NOT NULL
- [ ] Materiales lineales tienen `uom = 'm'` y `qty` en metros
- [ ] UI muestra los materiales correctamente



