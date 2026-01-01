# 📋 INFORME TECNICO: Análisis de BomInstanceLines No Generadas

**Fecha:** 31 de Diciembre, 2024  
**Problema:** BomInstanceLines no se están creando para ManufacturingOrder MO-000002  
**Estado:** En Investigación  
**Prioridad:** Alta

---

## 🔍 RESUMEN EJECUTIVO

El sistema está generando correctamente `BomInstances` (2 instancias encontradas) pero **NO está creando** los `BomInstanceLines` correspondientes (0 líneas encontradas). Los `QuoteLineComponents` existen y tienen el `source='configured_component'` correcto, lo que indica que el problema está en la fase de creación de `BomInstanceLines`.

---

## 📊 ESTADO ACTUAL DEL SISTEMA

### Datos Verificados

| Entidad | Cantidad | Estado |
|---------|----------|--------|
| ManufacturingOrders (MO-000002) | 1 | ✅ Existe |
| SalesOrders | 1 | ✅ Existe |
| SalesOrderLines | 2+ | ✅ Existen |
| BomInstances | 2 | ✅ Creadas correctamente |
| BomInstanceLines | 0 | ❌ **NO se están creando** |
| QuoteLineComponents | 2+ | ✅ Existen con `source='configured_component'` |

### Evidencia de QuoteLineComponents

**Ejemplos encontrados:**
- `bom_instance_id`: `bf016ef9-d4c7-4aca-a70e-3d81b6b61143`
  - `component_role`: `fabric`
  - `source`: `configured_component` ✅
  - `sku`: `RF-BALI-0300`
  - `qty`: `4.0000`
  - `uom`: `m2`

- `bom_instance_id`: `d4316700-f839-4f37-84f3-f69d82cd5fb8`
  - `component_role`: `fabric`
  - `source`: `configured_component` ✅
  - `sku`: `RF-BALI-0300`
  - `qty`: `1.0000`
  - `uom`: `m2`

---

## 🔬 ANÁLISIS TÉCNICO

### 1. Flujo Esperado

```
QuoteLine (con configuración)
    ↓
generate_configured_bom_for_quote_line()
    ↓
QuoteLineComponents (source='configured_component')
    ↓
ManufacturingOrder creado
    ↓
BomInstances creadas (✅ FUNCIONA)
    ↓
BomInstanceLines desde QuoteLineComponents (❌ FALLA AQUÍ)
```

### 2. Script de Creación: `306_create_bom_instances_and_lines.sql`

**Lógica del Script:**

```sql
-- Step 3: Create BomInstanceLines from QuoteLineComponents
FOR v_bom_instance_record IN
    SELECT bi.id, bi.quote_line_id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
    AND bi.deleted = false
    AND sol.deleted = false
LOOP
    -- Busca QuoteLineComponents
    FOR v_qlc_record IN
        SELECT qlc.*, ci.sku, ci.item_name
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'  -- ⚠️ FILTRO CRÍTICO
    LOOP
        -- INSERT con ON CONFLICT
        INSERT INTO "BomInstanceLines" (...)
        ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom)
        WHERE deleted = false
        DO NOTHING
    END LOOP;
END LOOP;
```

### 3. Posibles Causas del Problema

#### A. **ON CONFLICT está evitando inserciones silenciosamente**

**Hipótesis:** Ya existen `BomInstanceLines` con los mismos valores que causan conflictos.

**Verificación requerida:**
```sql
-- Verificar si existen BomInstanceLines que causen conflictos
SELECT 
    bil.bom_instance_id,
    bil.resolved_part_id,
    bil.part_role,
    bil.uom,
    bil.deleted
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bil.deleted = false;
```

#### B. **Error de validación silencioso**

**Hipótesis:** El `INSERT` está fallando por:
- Constraint de foreign key
- Tipo de dato incorrecto
- Valor NULL en campo NOT NULL
- Constraint de CHECK

**Verificación requerida:**
```sql
-- Intentar INSERT directo sin ON CONFLICT para ver error real
-- (Ver script 311_test_insert_bom_instance_lines.sql)
```

#### C. **Problema con el JOIN o filtro**

**Hipótesis:** El loop no está encontrando los `QuoteLineComponents` debido a:
- `quote_line_id` no coincide
- `source` tiene un valor diferente (espacios, mayúsculas, etc.)
- El `LEFT JOIN` con `CatalogItems` está causando problemas

**Verificación requerida:**
```sql
-- Verificar coincidencia exacta de quote_line_id
SELECT 
    bi.id as bom_instance_id,
    bi.quote_line_id,
    qlc.quote_line_id as qlc_quote_line_id,
    qlc.source,
    LENGTH(qlc.source) as source_length,
    qlc.deleted
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false;
```

#### D. **Problema con UOM mapping**

**Hipótesis:** El mapeo de UOM (`m` → `mts`) no coincide con el constraint o con valores existentes.

**Verificación requerida:**
```sql
-- Verificar UOM mapping
SELECT DISTINCT
    qlc.uom as original_uom,
    CASE qlc.uom
        WHEN 'm' THEN 'mts'
        WHEN 'm2' THEN 'm2'
        WHEN 'ea' THEN 'ea'
        WHEN 'pcs' THEN 'ea'
        ELSE COALESCE(qlc.uom, 'ea')
    END as mapped_uom
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND qlc.deleted = false
AND qlc.source = 'configured_component';
```

---

## 🛠️ SCRIPTS DE DIAGNÓSTICO DISPONIBLES

### Script 309: Verificación Básica
**Archivo:** `309_simple_check_quote_line_components.sql`

**Propósito:** Verificar existencia de `QuoteLineComponents` y sus `source`.

**Resultado esperado:** ✅ Confirmado - Existen componentes con `source='configured_component'`

### Script 310: Verificación de Conflictos
**Archivo:** `310_check_existing_bom_instance_lines.sql`

**Propósito:** Verificar si ya existen `BomInstanceLines` que causen conflictos.

**Estado:** ⏳ Pendiente de ejecución

### Script 311: Test de Inserción Directa
**Archivo:** `311_test_insert_bom_instance_lines.sql`

**Propósito:** Intentar insertar una línea directamente para ver el error real.

**Estado:** ⏳ Pendiente de ejecución

---

## 🔍 QUERIES DE VERIFICACIÓN RECOMENDADAS

### Query 1: Verificar Estructura de Datos

```sql
-- Verificar que todos los datos necesarios existen
SELECT 
    'ManufacturingOrder' as entity,
    COUNT(*) as count
FROM "ManufacturingOrders" mo
WHERE mo.manufacturing_order_no = 'MO-000002'
AND mo.deleted = false

UNION ALL

SELECT 
    'SalesOrder',
    COUNT(*)
FROM "SalesOrders" so
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND so.deleted = false

UNION ALL

SELECT 
    'SalesOrderLines',
    COUNT(*)
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND sol.deleted = false

UNION ALL

SELECT 
    'BomInstances',
    COUNT(*)
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false

UNION ALL

SELECT 
    'BomInstanceLines',
    COUNT(*)
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bil.deleted = false

UNION ALL

SELECT 
    'QuoteLineComponents (configured)',
    COUNT(*)
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND qlc.deleted = false
AND qlc.source = 'configured_component';
```

### Query 2: Verificar Coincidencia de IDs

```sql
-- Verificar que quote_line_id coincide correctamente
SELECT 
    bi.id as bom_instance_id,
    bi.quote_line_id,
    bi.sale_order_line_id,
    sol.quote_line_id as sol_quote_line_id,
    CASE 
        WHEN bi.quote_line_id = sol.quote_line_id THEN '✅ Match'
        ELSE '❌ Mismatch'
    END as id_match
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false;
```

### Query 3: Verificar Constraints de BomInstanceLines

```sql
-- Verificar estructura de la tabla y constraints
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = '"BomInstanceLines"'::regclass
ORDER BY contype, conname;
```

### Query 4: Verificar Valores NULL Problemáticos

```sql
-- Verificar si hay valores NULL que causen problemas
SELECT 
    qlc.id as qlc_id,
    qlc.quote_line_id,
    qlc.catalog_item_id,
    qlc.component_role,
    qlc.source,
    qlc.qty,
    qlc.uom,
    ci.sku,
    ci.item_name,
    CASE 
        WHEN qlc.catalog_item_id IS NULL THEN '❌ NULL catalog_item_id'
        WHEN qlc.component_role IS NULL THEN '❌ NULL component_role'
        WHEN qlc.qty IS NULL THEN '❌ NULL qty'
        WHEN qlc.uom IS NULL THEN '❌ NULL uom'
        WHEN ci.sku IS NULL THEN '⚠️ NULL sku (puede ser OK)'
        ELSE '✅ OK'
    END as validation_status
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
AND bi.deleted = false
AND sol.deleted = false;
```

---

## 💡 RECOMENDACIONES TÉCNICAS

### Acción Inmediata 1: Ejecutar Scripts de Diagnóstico

**Prioridad:** 🔴 Alta

1. Ejecutar `310_check_existing_bom_instance_lines.sql`
   - Verificar si ya existen líneas que causen conflictos
   - Si existen, decidir si eliminarlas o actualizarlas

2. Ejecutar `311_test_insert_bom_instance_lines.sql`
   - Ver el error real (si existe) al intentar insertar
   - Identificar constraints o validaciones que fallen

### Acción Inmediata 2: Mejorar Logging del Script 306

**Prioridad:** 🟡 Media

Agregar más `RAISE NOTICE` en puntos críticos:

```sql
-- Antes del loop de QuoteLineComponents
RAISE NOTICE '  Processing BomInstance % (QuoteLine: %)', 
    v_bom_instance_record.bom_instance_id, 
    v_bom_instance_record.quote_line_id;

-- Contar componentes encontrados
SELECT COUNT(*) INTO v_qlc_count
FROM "QuoteLineComponents" qlc
WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
AND qlc.deleted = false
AND qlc.source = 'configured_component';

RAISE NOTICE '    Found % QuoteLineComponents with source=configured_component', v_qlc_count;

-- Si no encuentra componentes, mostrar qué sources existen
IF v_qlc_count = 0 THEN
    FOR rec IN
        SELECT DISTINCT qlc.source, COUNT(*) as count
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
        AND qlc.deleted = false
        GROUP BY qlc.source
    LOOP
        RAISE NOTICE '      Source found: % (count: %)', rec.source, rec.count;
    END LOOP;
END IF;
```

### Acción Inmediata 3: Verificar Constraints y Unique Index

**Prioridad:** 🟡 Media

```sql
-- Verificar si existe el unique index/constraint
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'BomInstanceLines'
AND indexdef LIKE '%bom_instance_id%resolved_part_id%part_role%uom%';

-- Si no existe, puede ser que el ON CONFLICT esté fallando silenciosamente
```

### Solución Alternativa: Usar DO UPDATE en lugar de DO NOTHING

**Prioridad:** 🟢 Baja (solo si se confirma que es un problema de conflictos)

Si el problema es que `ON CONFLICT DO NOTHING` está evitando inserciones legítimas, considerar:

```sql
ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom)
WHERE deleted = false
DO UPDATE SET
    qty = EXCLUDED.qty,
    updated_at = now()
RETURNING id INTO v_bil_id;
```

Esto actualizaría las líneas existentes en lugar de ignorarlas.

---

## 📝 PLAN DE ACCIÓN SUGERIDO

### Fase 1: Diagnóstico (Inmediato)
- [ ] Ejecutar `310_check_existing_bom_instance_lines.sql`
- [ ] Ejecutar `311_test_insert_bom_instance_lines.sql`
- [ ] Ejecutar Query 1 (Verificar Estructura de Datos)
- [ ] Ejecutar Query 4 (Verificar Valores NULL)

### Fase 2: Análisis de Resultados
- [ ] Revisar logs de `RAISE NOTICE` del script 306
- [ ] Identificar si hay conflictos existentes
- [ ] Identificar si hay errores de validación
- [ ] Verificar constraints de la tabla `BomInstanceLines`

### Fase 3: Corrección
- [ ] Si hay conflictos: Decidir estrategia (eliminar, actualizar, o cambiar lógica)
- [ ] Si hay errores de validación: Corregir datos o constraints
- [ ] Si hay problema de lógica: Ajustar script 306
- [ ] Probar solución con un caso de prueba

### Fase 4: Validación
- [ ] Verificar que se crean `BomInstanceLines` correctamente
- [ ] Verificar que los datos son correctos (qty, uom, catalog_item_id, etc.)
- [ ] Verificar que no hay duplicados
- [ ] Probar con otro ManufacturingOrder

---

## 🔗 ARCHIVOS RELACIONADOS

- `database/migrations/306_create_bom_instances_and_lines.sql` - Script principal
- `database/migrations/309_simple_check_quote_line_components.sql` - Diagnóstico básico
- `database/migrations/310_check_existing_bom_instance_lines.sql` - Verificación de conflictos
- `database/migrations/311_test_insert_bom_instance_lines.sql` - Test de inserción directa
- `database/migrations/226_update_trigger_copy_config_fields.sql` - Trigger que crea QuoteLineComponents

---

## 📞 PRÓXIMOS PASOS

1. **Ejecutar scripts de diagnóstico** (310 y 311)
2. **Revisar logs** del script 306 en Supabase (pestaña "Logs")
3. **Compartir resultados** de los diagnósticos
4. **Aplicar corrección** basada en los hallazgos

---

**Documento generado automáticamente para análisis técnico del problema de BomInstanceLines.**


