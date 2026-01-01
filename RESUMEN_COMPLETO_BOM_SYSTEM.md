# 📋 Resumen Completo: Sistema BOM y Soluciones

## 🎯 Contexto del Problema

### Problema Principal
Los **BOMs (Bills of Materials)** no aparecen en las listas del módulo Manufacturing > Material, aunque existen `BomInstances` en la base de datos. El problema específico es:
- ✅ `BomInstances` se crean correctamente
- ❌ `BomInstanceLines` (las líneas/componentes del BOM) **NO se están copiando** desde `QuoteLineComponents`

### Estado Actual
- **Manufacturing Order**: MO-000001
- **Sales Order**: SO-025080
- **BomInstances**: 1 ✅
- **BomInstanceLines**: 0 ❌

---

## 🔄 Flujo Operacional del Sistema

### Flujo Normal (Cómo DEBERÍA funcionar)

```
1. Quote (Cotización)
   └─> Usuario crea Quote con QuoteLines
   └─> Usuario aprueba Quote (status = 'approved')
   
2. Sales Order (Orden de Venta) - AUTOMÁTICO
   └─> Trigger: on_quote_approved_create_operational_docs
   └─> Crea SalesOrder con status = 'Draft'
   └─> Crea SalesOrderLines desde QuoteLines
   └─> NO crea BOM todavía
   
3. Order List (Lista de Órdenes) - VISTA
   └─> Muestra SalesOrders con status = 'Confirmed'
   └─> Usuario puede crear Manufacturing Order manualmente
   
4. Manufacturing Order (Orden de Manufactura) - MANUAL
   └─> Usuario crea MO desde Order List
   └─> Trigger: on_manufacturing_order_insert_generate_bom
   └─> Genera QuoteLineComponents (si no existen)
   └─> Crea BomInstance
   └─> COPIA QuoteLineComponents → BomInstanceLines ⚠️ AQUÍ ESTÁ EL PROBLEMA
   └─> Actualiza SalesOrder.status = 'In Production'
   
5. BOM List (Lista de BOMs) - VISTA
   └─> Muestra BomInstanceLines agrupadas por SalesOrder
   └─> Usuario puede ver materiales necesarios para producción
```

### Punto Crítico del Problema

El trigger `on_manufacturing_order_insert_generate_bom` **debería**:
1. ✅ Generar `QuoteLineComponents` usando `generate_configured_bom_for_quote_line()`
2. ✅ Crear `BomInstance` para cada `SalesOrderLine`
3. ❌ **FALLA AQUÍ**: Copiar `QuoteLineComponents` → `BomInstanceLines`

**Resultado**: `BomInstances` existen pero están vacíos (sin líneas).

---

## 🗄️ Estructura de Datos

### Tablas Clave

#### 1. `Quotes` y `QuoteLines`
```sql
Quotes
├── id (uuid)
├── quote_no (text) - Ej: 'QT-000001'
├── status (enum) - 'draft', 'sent', 'approved', 'rejected'
├── organization_id (uuid)
└── customer_id (uuid)

QuoteLines
├── id (uuid)
├── quote_id (uuid) → Quotes.id
├── product_type_id (uuid) → ProductTypes.id
├── width_m, height_m, qty
└── drive_type, bottom_rail_type, cassette, etc.
```

#### 2. `SalesOrders` y `SalesOrderLines`
```sql
SalesOrders
├── id (uuid)
├── sale_order_no (text) - Ej: 'SO-000100'
├── quote_id (uuid) → Quotes.id
├── status (text) - 'Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered'
├── order_progress_status (text) - 'approved_awaiting_confirmation', etc.
└── organization_id (uuid)

SalesOrderLines
├── id (uuid)
├── sale_order_id (uuid) → SalesOrders.id
├── quote_line_id (uuid) → QuoteLines.id
└── line_number, qty, unit_price, etc.
```

#### 3. `ManufacturingOrders`
```sql
ManufacturingOrders
├── id (uuid)
├── manufacturing_order_no (text) - Ej: 'MO-000001'
├── sale_order_id (uuid) → SalesOrders.id
├── status (enum) - 'planned', 'in_production', 'completed', 'cancelled'
└── organization_id (uuid)
```

#### 4. `QuoteLineComponents`
```sql
QuoteLineComponents
├── id (uuid)
├── quote_line_id (uuid) → QuoteLines.id
├── catalog_item_id (uuid) → CatalogItems.id
├── component_role (text) - 'fabric', 'hardware', 'accessory', etc.
├── qty, uom, unit_cost_exw
├── source (text) - 'configured_component', 'manual', etc.
└── deleted (boolean)
```

#### 5. `BomInstances` y `BomInstanceLines`
```sql
BomInstances
├── id (uuid)
├── sale_order_line_id (uuid) → SalesOrderLines.id
├── quote_line_id (uuid) → QuoteLines.id
├── status (text) - 'locked', 'unlocked'
└── organization_id (uuid)

BomInstanceLines ⚠️ ESTA ES LA TABLA QUE NO SE ESTÁ LLENANDO
├── id (uuid)
├── bom_instance_id (uuid) → BomInstances.id
├── resolved_part_id (uuid) → CatalogItems.id
├── resolved_sku (text)
├── part_role (text)
├── qty, uom
├── unit_cost_exw, total_cost_exw
├── category_code (text) - 'fabric', 'hardware', 'accessory'
└── deleted (boolean)
```

---

## 🔧 Triggers y Funciones Clave

### 1. Trigger: `trg_on_quote_approved_create_operational_docs`
**Función**: `on_quote_approved_create_operational_docs()`

**Cuándo se activa**: Cuando `Quotes.status` cambia a `'approved'`

**Qué hace**:
```sql
1. Verifica si ya existe SalesOrder para este Quote
2. Si no existe:
   - Genera sale_order_no usando get_next_document_number()
   - Crea SalesOrder con status = 'Draft'
   - Crea SalesOrderLines desde QuoteLines
3. NO crea BOM (esto es correcto)
```

**Estado**: ✅ Funcionando correctamente

---

### 2. Trigger: `trg_mo_insert_generate_bom`
**Función**: `on_manufacturing_order_insert_generate_bom()`

**Cuándo se activa**: Cuando se INSERTA un `ManufacturingOrder` con `deleted = false`

**Qué DEBERÍA hacer**:
```sql
1. Obtiene SalesOrder asociado
2. Para cada SalesOrderLine:
   a. Obtiene QuoteLine asociado
   b. Genera QuoteLineComponents usando generate_configured_bom_for_quote_line()
   c. Crea BomInstance (si no existe)
   d. COPIA QuoteLineComponents → BomInstanceLines ⚠️ AQUÍ FALLA
3. Actualiza SalesOrder.status = 'In Production'
```

**Estado**: ⚠️ **PROBLEMA**: No está copiando `QuoteLineComponents` → `BomInstanceLines`

**Código del Trigger** (versión que debería funcionar):
```sql
CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
BEGIN
    -- Para cada QuoteLine en el SalesOrder
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            sol.id as sale_order_line_id,
            -- ... otros campos
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
        WHERE sol.sale_order_id = NEW.sale_order_id
    LOOP
        -- 1. Generar QuoteLineComponents
        v_result := public.generate_configured_bom_for_quote_line(...);
        
        -- 2. Crear BomInstance
        INSERT INTO "BomInstances" (...) VALUES (...) 
        RETURNING id INTO v_bom_instance_id;
        
        -- 3. COPIA QuoteLineComponents → BomInstanceLines ⚠️ ESTO FALLA
        FOR v_component_record IN
            SELECT * FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line_record.quote_line_id
            AND source = 'configured_component'
        LOOP
            INSERT INTO "BomInstanceLines" (
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                description,
                unit_cost_exw,
                total_cost_exw,
                category_code,
                deleted
            ) VALUES (
                v_bom_instance_id,
                v_component_record.catalog_item_id,
                v_component_record.sku,
                v_component_record.component_role,
                v_component_record.qty,
                v_canonical_uom, -- Normalizado
                v_component_record.item_name,
                v_unit_cost_exw, -- Calculado
                v_total_cost_exw, -- Calculado
                v_category_code, -- Derivado del role
                false
            );
        END LOOP;
    END LOOP;
    
    RETURN NEW;
END;
$$;
```

---

## 🐛 Problemas Identificados

### Problema 1: Trigger No Copia Componentes
**Síntoma**: `BomInstances` existen pero `BomInstanceLines` están vacíos (count = 0)

**Causa Raíz**: El trigger `on_manufacturing_order_insert_generate_bom` no está ejecutando correctamente la copia de `QuoteLineComponents` → `BomInstanceLines`

**Posibles Razones**:
1. El trigger no tiene el código de copia
2. El código de copia tiene errores (excepciones silenciosas)
3. Los `QuoteLineComponents` no existen cuando se ejecuta el trigger
4. Hay problemas con las funciones auxiliares (`normalize_uom_to_canonical`, `get_unit_cost_in_uom`, etc.)

---

### Problema 2: QuoteLineComponents No Existen
**Síntoma**: No hay `QuoteLineComponents` para el `QuoteLine` asociado

**Causa**: La función `generate_configured_bom_for_quote_line()` no se ejecutó o falló silenciosamente

**Solución**: Regenerar `QuoteLineComponents` antes de copiar a `BomInstanceLines`

---

### Problema 3: quote_line_id NULL en BomInstance
**Síntoma**: `BomInstance.quote_line_id` es NULL

**Causa**: El trigger no está estableciendo correctamente el `quote_line_id` al crear el `BomInstance`

**Solución**: Obtener `quote_line_id` del `SalesOrderLine` asociado

---

## 🛠️ Soluciones Propuestas

### Solución 1: Script de Diagnóstico
**Archivo**: `CHECK_WHY_NO_BOM_LINES.sql`

**Propósito**: Diagnosticar por qué no hay `BomInstanceLines`

**Qué verifica**:
1. Si existe `BomInstance` para el SalesOrder
2. Si existe `quote_line_id` en el `BomInstance` o `SalesOrderLine`
3. Si existen `QuoteLineComponents` para ese `QuoteLine`
4. Cuántos `BomInstanceLines` existen actualmente

**Uso**: Ejecutar primero para entender el problema

---

### Solución 2: Script Simple de Copia
**Archivo**: `FIX_BOM_LINES_SIMPLE.sql`

**Propósito**: Copiar directamente `QuoteLineComponents` → `BomInstanceLines` sin funciones complejas

**Cómo funciona**:
```sql
1. Encuentra todos los BomInstances sin BomInstanceLines
2. Para cada BomInstance:
   a. Obtiene quote_line_id (del BomInstance o SalesOrderLine)
   b. Busca QuoteLineComponents para ese quote_line_id
   c. Copia directamente a BomInstanceLines (sin normalizar UOM ni calcular costos complejos)
3. Muestra resultados
```

**Ventajas**:
- Simple y directo
- No depende de funciones auxiliares complejas
- Fácil de depurar

**Desventajas**:
- No normaliza UOM (puede haber duplicados)
- No calcula costos correctamente
- Puede fallar si hay conflictos de constraint

---

### Solución 3: Script Completo con Generación
**Archivo**: `FIX_ALL_BOM_LINES_FINAL.sql`

**Propósito**: Solución completa que genera y copia componentes

**Cómo funciona**:
```sql
1. Encuentra todos los BomInstances sin BomInstanceLines
2. Para cada BomInstance:
   a. Obtiene QuoteLine asociado
   b. Verifica si existen QuoteLineComponents
   c. Si no existen, los genera usando generate_configured_bom_for_quote_line()
   d. Copia QuoteLineComponents → BomInstanceLines usando funciones auxiliares:
      - normalize_uom_to_canonical() - Normaliza unidades de medida
      - get_unit_cost_in_uom() - Calcula costo unitario en UOM correcta
      - derive_category_code_from_role() - Deriva código de categoría
   e. Inserta en BomInstanceLines con ON CONFLICT para evitar duplicados
3. Muestra resultados detallados
```

**Ventajas**:
- Solución completa
- Normaliza UOM correctamente
- Calcula costos correctamente
- Maneja conflictos

**Desventajas**:
- Más complejo
- Depende de funciones auxiliares
- Puede fallar si alguna función no existe o tiene errores

---

### Solución 4: Script Específico para SO-025080
**Archivo**: `FIX_SPECIFIC_BOM_SO_025080.sql`

**Propósito**: Corregir un BOM específico con logs detallados

**Uso**: Para debugging de un caso específico

---

## 📊 Funciones Auxiliares Necesarias

### 1. `generate_configured_bom_for_quote_line()`
**Propósito**: Genera `QuoteLineComponents` basado en configuración del `QuoteLine`

**Parámetros**:
- `quote_line_id` (uuid)
- `product_type_id` (uuid)
- `organization_id` (uuid)
- `drive_type`, `bottom_rail_type`, `cassette`, `side_channel`, etc.
- `width_m`, `height_m`, `qty`

**Qué hace**:
1. Busca `BOMTemplate` para el `product_type_id`
2. Resuelve componentes basados en configuración
3. Crea `QuoteLineComponents` con `source = 'configured_component'`

**Estado**: ✅ Existe y funciona

---

### 2. `normalize_uom_to_canonical()`
**Propósito**: Normaliza unidades de medida a formato canónico

**Ejemplo**: 'EA', 'ea', 'Ea' → 'ea'

**Estado**: ✅ Existe

---

### 3. `get_unit_cost_in_uom()`
**Propósito**: Obtiene costo unitario de un `CatalogItem` en una UOM específica

**Parámetros**:
- `catalog_item_id` (uuid)
- `uom` (text)
- `organization_id` (uuid)

**Estado**: ✅ Existe

---

### 4. `derive_category_code_from_role()`
**Propósito**: Deriva código de categoría desde `component_role`

**Ejemplo**: 'fabric' → 'fabric', 'hardware' → 'hardware', 'accessory' → 'accessory'

**Estado**: ✅ Existe

---

## 🔍 Cómo Diagnosticar un Problema

### Paso 1: Verificar Estado del BOM
```sql
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    CASE
        WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅ Has Lines'
        ELSE '❌ No Lines'
    END as status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE mo.deleted = false
AND mo.organization_id = 'TU_ORG_ID'
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no;
```

**Interpretación**:
- `bom_instances > 0` y `bom_lines = 0` → **Problema**: No se copiaron las líneas
- `bom_instances = 0` → **Problema**: No se creó el BomInstance
- `bom_instances > 0` y `bom_lines > 0` → ✅ **OK**

---

### Paso 2: Verificar QuoteLineComponents
```sql
SELECT 
    COUNT(*) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = COALESCE(bi.quote_line_id, sol.quote_line_id)
WHERE so.sale_order_no = 'SO-025080'
AND qlc.source = 'configured_component'
AND qlc.deleted = false;
```

**Interpretación**:
- `component_count = 0` → **Problema**: No hay `QuoteLineComponents`, necesitas generarlos
- `component_count > 0` → ✅ Hay componentes, el problema es la copia

---

### Paso 3: Verificar quote_line_id
```sql
SELECT 
    bi.id as bom_instance_id,
    bi.quote_line_id as bom_quote_line_id,
    sol.quote_line_id as sol_quote_line_id,
    CASE
        WHEN bi.quote_line_id IS NULL AND sol.quote_line_id IS NULL THEN '❌ No quote_line_id'
        WHEN bi.quote_line_id IS NULL THEN '⚠️ NULL in BomInstance, exists in SalesOrderLine'
        ELSE '✅ OK'
    END as status
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false;
```

**Interpretación**:
- `status = '❌ No quote_line_id'` → **Problema**: No hay forma de obtener los componentes
- `status = '⚠️ NULL in BomInstance'` → **Solución**: Usar `sol.quote_line_id` en el script
- `status = '✅ OK'` → ✅ `quote_line_id` existe

---

### Paso 4: Verificar Funciones
```sql
SELECT 
    proname as function_name,
    CASE 
        WHEN proname IN (
            'generate_configured_bom_for_quote_line',
            'normalize_uom_to_canonical',
            'get_unit_cost_in_uom',
            'derive_category_code_from_role'
        ) THEN '✅ Exists'
        ELSE '❌ Missing'
    END as status
FROM pg_proc
WHERE proname IN (
    'generate_configured_bom_for_quote_line',
    'normalize_uom_to_canonical',
    'get_unit_cost_in_uom',
    'derive_category_code_from_role'
)
AND pronamespace = 'public'::regnamespace;
```

**Interpretación**:
- Todas deben mostrar `✅ Exists`
- Si alguna muestra `❌ Missing`, necesitas crearla o verificar el nombre

---

## 🚀 Plan de Acción Recomendado

### Para Resolver el Problema Actual

1. **Ejecutar Diagnóstico**:
   ```sql
   -- Ejecutar CHECK_WHY_NO_BOM_LINES.sql
   -- O ejecutar DIAGNOSE_BOM_INSTANCE.sql para un caso específico
   ```

2. **Ejecutar Solución Simple** (si hay `QuoteLineComponents`):
   ```sql
   -- Ejecutar FIX_BOM_LINES_SIMPLE.sql
   -- Este script copia directamente sin funciones complejas
   ```

3. **Si la solución simple no funciona, ejecutar solución completa**:
   ```sql
   -- Ejecutar FIX_ALL_BOM_LINES_FINAL.sql
   -- Este script genera QuoteLineComponents si no existen y luego copia
   ```

4. **Verificar Resultados**:
   ```sql
   -- Ejecutar la query de verificación del script
   -- Debe mostrar "✅ Has Lines" para todos los BOMs
   ```

---

### Para Prevenir el Problema en el Futuro

1. **Corregir el Trigger**:
   - Asegurar que `on_manufacturing_order_insert_generate_bom()` copie correctamente `QuoteLineComponents` → `BomInstanceLines`
   - Agregar logs detallados para debugging
   - Manejar excepciones correctamente (no silenciarlas)

2. **Verificar el Trigger Está Activo**:
   ```sql
   SELECT 
       tgname as trigger_name,
       tgenabled as enabled,
       CASE tgenabled
           WHEN 'O' THEN '✅ Enabled'
           WHEN 'D' THEN '❌ Disabled'
           ELSE '⚠️ Unknown'
       END as status
   FROM pg_trigger t
   JOIN pg_class c ON t.tgrelid = c.oid
   WHERE c.relname = 'ManufacturingOrders'
   AND tgname = 'trg_mo_insert_generate_bom';
   ```

3. **Monitorear Creación de BOMs**:
   - Agregar alertas si `BomInstance` se crea sin `BomInstanceLines`
   - Ejecutar script de verificación periódicamente

---

## 📝 Notas Importantes

### Convenciones de Nombres
- **Tablas**: Plurales con mayúsculas iniciales → `"SalesOrders"`, `"BomInstances"`
- **Columnas**: snake_case → `sale_order_id`, `quote_line_id`
- **Funciones**: snake_case → `generate_configured_bom_for_quote_line()`

### Multi-Tenancy
- **CRÍTICO**: Todos los queries deben filtrar por `organization_id`
- Los scripts deben usar `organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'` (o el ID correcto)

### Soft Delete
- **CRÍTICO**: Todos los queries deben filtrar por `deleted = false`
- No mostrar registros eliminados

### Constraints
- `BomInstanceLines` tiene constraint único: `(bom_instance_id, resolved_part_id, part_role, uom, deleted)`
- Usar `ON CONFLICT` para evitar duplicados al insertar

---

## 🔗 Archivos de Scripts

1. **`CHECK_WHY_NO_BOM_LINES.sql`** - Diagnóstico general
2. **`DIAGNOSE_BOM_INSTANCE.sql`** - Diagnóstico específico para un SO
3. **`FIX_BOM_LINES_SIMPLE.sql`** - Solución simple (copia directa)
4. **`FIX_ALL_BOM_LINES_FINAL.sql`** - Solución completa (genera y copia)
5. **`FIX_SPECIFIC_BOM_SO_025080.sql`** - Fix específico con logs detallados

---

## ❓ Preguntas Frecuentes

### ¿Por qué no se copian automáticamente los componentes?
El trigger `on_manufacturing_order_insert_generate_bom` debería hacerlo, pero parece que no está ejecutando correctamente la copia. Posibles razones:
- El código de copia tiene errores
- Las funciones auxiliares fallan silenciosamente
- Los `QuoteLineComponents` no existen cuando se ejecuta el trigger

### ¿Puedo ejecutar los scripts múltiples veces?
Sí, los scripts usan `ON CONFLICT` para evitar duplicados. Es seguro ejecutarlos múltiples veces.

### ¿Qué pasa si no hay QuoteLineComponents?
El script `FIX_ALL_BOM_LINES_FINAL.sql` los genera automáticamente usando `generate_configured_bom_for_quote_line()`.

### ¿Cómo sé si el problema está resuelto?
Ejecuta la query de verificación. Debe mostrar `bom_lines > 0` y `status = '✅ Has Lines'` para todos los BOMs.

---

## 📞 Información para Soporte Técnico

### Información Necesaria para Diagnosticar

1. **Sales Order Number**: Ej: `SO-025080`
2. **Manufacturing Order Number**: Ej: `MO-000001`
3. **Organization ID**: Ej: `4de856e8-36ce-480a-952b-a2f5083c69d6`
4. **Resultados de Diagnóstico**: Ejecutar `CHECK_WHY_NO_BOM_LINES.sql`
5. **Logs del Trigger**: Si es posible, verificar logs de PostgreSQL cuando se crea el MO

### Queries Útiles para Soporte

```sql
-- Ver estado de todos los BOMs
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE mo.deleted = false
AND mo.organization_id = 'TU_ORG_ID'
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;
```

---

**Última Actualización**: 2025-01-XX
**Versión**: 1.0
**Autor**: Sistema de Documentación Automática






