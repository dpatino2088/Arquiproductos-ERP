# 📋 EVIDENCIA DE CAMBIOS: Fix SalesOrder Creation on Quote Approved

## 🎯 PROBLEMA IDENTIFICADO

Cuando un Quote se aprueba desde el UI, a veces:
- ❌ No se crea el SalesOrder para ese quote
- Los "fixes" temporales funcionan, pero luego se rompen de nuevo

**Causa raíz:**
1. El trigger verifica `NEW.status != 'approved'` (lowercase) pero el status puede ser `'Approved'` (capital A)
2. No verifica si el status realmente cambió (transición)
3. La creación de SalesOrder no es idempotente (no tiene unique constraint)
4. No maneja inserciones concurrentes de forma segura

---

## ✅ SOLUCIÓN IMPLEMENTADA

### Migración 315: `315_fix_salesorder_creation_on_quote_approved.sql`

#### Cambios Principales:

1. **Unique Index para Idempotencia:**
   ```sql
   CREATE UNIQUE INDEX ux_salesorders_org_quote_active
   ON "SalesOrders"(organization_id, quote_id)
   WHERE deleted = false;
   ```
   - Garantiza un solo SalesOrder por (organization_id, quote_id) activo
   - Previene duplicados a nivel de base de datos

2. **Función Helper Idempotente:**
   ```sql
   ensure_sales_order_for_approved_quote(p_quote_id uuid)
   ```
   - Verifica si ya existe un SalesOrder antes de crear
   - Si existe, retorna el existente (idempotente)
   - Si no existe, crea uno nuevo
   - Maneja inserciones concurrentes con `ON CONFLICT`

3. **Trigger Mejorado:**
   - **Case-insensitive status check:** `UPPER(TRIM(NEW.status)) = 'APPROVED'`
   - **Transition check:** `OLD.status IS DISTINCT FROM NEW.status`
   - **Usa función helper:** `ensure_sales_order_for_approved_quote()`
   - **Mantiene toda la lógica existente:** SalesOrderLines, BomInstances, etc.

4. **Manejo de Errores:**
   - Try-catch en la función helper
   - Manejo de `unique_violation` para inserciones concurrentes
   - Logging detallado con `RAISE NOTICE`

---

## 🔍 CAMBIOS TÉCNICOS DETALLADOS

### Antes:
```sql
-- Solo verifica lowercase
IF NEW.status != 'approved' THEN
    RETURN NEW;
END IF;

-- No verifica transición
-- No es idempotente (puede crear duplicados si se ejecuta dos veces)
SELECT id INTO v_sale_order_id
FROM "SalesOrders"
WHERE quote_id = NEW.id AND deleted = false;

IF NOT FOUND THEN
    INSERT INTO "SalesOrders" ...;  -- Puede fallar si hay concurrencia
END IF;
```

### Después:
```sql
-- Case-insensitive + verifica transición
v_status_normalized := UPPER(TRIM(COALESCE(NEW.status, '')));
IF v_status_normalized != 'APPROVED' THEN
    RETURN NEW;
END IF;
IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;  -- No cambió realmente
END IF;

-- Idempotente con unique index
v_sale_order_id := public.ensure_sales_order_for_approved_quote(NEW.id);
-- La función maneja existencia, creación, y concurrencia
```

---

## 📊 GARANTÍAS DE LA SOLUCIÓN

### 1. **Idempotencia:**
- ✅ Re-ejecutar el trigger no crea duplicados
- ✅ Unique index previene duplicados a nivel DB
- ✅ Función helper verifica existencia antes de crear

### 2. **Determinismo:**
- ✅ Si `quote.status = 'Approved'` → garantiza que existe un SalesOrder
- ✅ Un solo SalesOrder por quote (unique index)
- ✅ Status case-insensitive (`'Approved'`, `'approved'`, `'APPROVED'`)

### 3. **Robustez:**
- ✅ Maneja inserciones concurrentes
- ✅ Maneja errores sin romper el trigger
- ✅ Logging detallado para diagnóstico

### 4. **Backward Compatible:**
- ✅ Mantiene toda la lógica existente (SalesOrderLines, BomInstances, etc.)
- ✅ No cambia el comportamiento de otros componentes
- ✅ Solo mejora la creación de SalesOrder

---

## 🧪 VERIFICACIÓN

### Query 1: Approved quotes sin SalesOrder (debe estar vacío)
```sql
SELECT 
    q.id,
    q.quote_no,
    q.status,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing SalesOrder'
        ELSE '✅ Has SalesOrder'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE UPPER(TRIM(COALESCE(q.status, ''))) = 'APPROVED'
AND q.deleted = false
AND so.id IS NULL;
```

**Resultado esperado:** 0 filas

### Query 2: Duplicados (debe estar vacío)
```sql
SELECT 
    organization_id,
    quote_id,
    COUNT(*) as duplicate_count
FROM "SalesOrders"
WHERE deleted = false
GROUP BY organization_id, quote_id
HAVING COUNT(*) > 1;
```

**Resultado esperado:** 0 filas

### Query 3: Test manual de la función helper
```sql
SELECT public.ensure_sales_order_for_approved_quote('<QUOTE_ID>'::uuid);
```

**Resultado esperado:** Retorna el UUID del SalesOrder (existente o nuevo)

---

## 📝 NOTAS TÉCNICAS

### Unique Index
- **Nombre:** `ux_salesorders_org_quote_active`
- **Columnas:** `(organization_id, quote_id)`
- **Condición:** `WHERE deleted = false`
- **Efecto:** Previene duplicados a nivel de base de datos

### Función Helper
- **Nombre:** `ensure_sales_order_for_approved_quote(p_quote_id uuid)`
- **Retorna:** `uuid` (ID del SalesOrder)
- **Comportamiento:**
  1. Verifica si existe → retorna existente
  2. Si no existe → crea nuevo
  3. Si hay `unique_violation` → busca y retorna existente

### Trigger
- **Nombre:** `trg_on_quote_approved_create_operational_docs`
- **Evento:** `AFTER UPDATE OF status ON "Quotes"`
- **Condición:** 
  - `NEW.deleted = false`
  - `UPPER(TRIM(NEW.status)) = 'APPROVED'`
  - `OLD.status IS DISTINCT FROM NEW.status`

---

## ✅ CRITERIOS DE ÉXITO

- [x] Unique index creado para prevenir duplicados
- [x] Función helper idempotente implementada
- [x] Trigger actualizado para usar función helper
- [x] Case-insensitive status matching
- [x] Verificación de transición de status
- [x] Manejo de inserciones concurrentes
- [x] Mantiene toda la lógica existente
- [x] Queries de verificación incluidas

---

## 🔗 ARCHIVOS RELACIONADOS

- `315_fix_salesorder_creation_on_quote_approved.sql` - Migración principal
- `226_update_trigger_copy_config_fields.sql` - Versión anterior del trigger (reemplazada parcialmente)

---

**Fecha:** 31 de Diciembre, 2024  
**Estado:** ✅ Implementado y listo para pruebas


