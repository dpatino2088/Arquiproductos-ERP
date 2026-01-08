# 🧪 Pasos para Probar el Trigger de Quote Approved (Migración 212)

## 📋 Resumen
Cuando apruebas una Quote (cambias su status a 'approved'), el trigger debe crear automáticamente:
- ✅ SalesOrder
- ✅ SalesOrderLines (una por cada QuoteLine)
- ✅ BomInstances (uno por cada SalesOrderLine)
- ✅ BomInstanceLines (componentes del BOM)

---

## 🔍 PASO 1: Encontrar una Quote para probar

Ejecuta esta query en Supabase SQL Editor:

```sql
SELECT 
    q.id,
    q.quote_no,
    q.status,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM "SalesOrders" so 
            WHERE so.quote_id = q.id 
            AND so.deleted = false
        ) THEN '✅ SalesOrder exists'
        ELSE '❌ No SalesOrder'
    END as sales_order_status
FROM "Quotes" q
WHERE q.deleted = false
AND q.status != 'approved'
AND (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) > 0
ORDER BY q.created_at DESC
LIMIT 5;
```

**Resultado esperado:** Verás una lista de Quotes en estado "draft" que no tienen SalesOrder.

**Acción:** Copia el `id` de una Quote (preferiblemente una con `line_count > 0`).

---

## ✅ PASO 2: Aprobar la Quote

Ejecuta este UPDATE (reemplaza `<quote_id>` con el ID que copiaste):

```sql
UPDATE "Quotes"
SET status = 'approved',
    updated_at = NOW()
WHERE id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL
AND deleted = false
AND status != 'approved';
```

**Resultado esperado:** 
- Debería mostrar "Success. No rows returned" o "1 row updated"
- El trigger se ejecutará automáticamente en segundo plano

**⚠️ IMPORTANTE:** Si la Quote ya tiene un SalesOrder, el trigger no creará uno nuevo (es idempotente).

---

## 🔍 PASO 3: Verificar que se creó el SalesOrder

Ejecuta esta query (reemplaza `<quote_id>` con el mismo ID):

```sql
SELECT 
    so.id as sales_order_id,
    so.sale_order_no,
    so.status,
    so.quote_id,
    so.subtotal,
    so.tax,
    so.total,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL
AND so.deleted = false;
```

**Resultado esperado:**
- Deberías ver 1 fila con el SalesOrder creado
- `sale_order_no` debería tener formato "SO-000001" (o similar)
- `status` debería ser 'draft'
- `line_count` debería coincidir con el número de QuoteLines

**Si no aparece nada:** El trigger no se ejecutó. Revisa los logs de PostgreSQL/Supabase.

---

## 🔍 PASO 4: Verificar SalesOrderLines

Ejecuta esta query:

```sql
SELECT 
    sol.id,
    sol.line_number,
    sol.sku,
    sol.item_name,
    sol.qty,
    sol.unit_price,
    sol.line_total,
    sol.product_type,
    sol.drive_type
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL
AND sol.deleted = false
ORDER BY sol.line_number;
```

**Resultado esperado:**
- Deberías ver una fila por cada QuoteLine de la Quote original
- Los datos deberían coincidir con los QuoteLines

---

## 🔍 PASO 5: Verificar BomInstances

Ejecuta esta query:

```sql
SELECT 
    bi.id as bom_instance_id,
    bi.status,
    sol.line_number,
    sol.sku,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil WHERE bil.bom_instance_id = bi.id AND bil.deleted = false) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL
AND bi.deleted = false
ORDER BY sol.line_number;
```

**Resultado esperado:**
- Deberías ver un BomInstance por cada SalesOrderLine
- `status` debería ser 'locked'
- `component_count` debería ser > 0 si la QuoteLine tenía componentes configurados

---

## 🔍 PASO 6: Verificar BomInstanceLines (Componentes del BOM)

Ejecuta esta query:

```sql
SELECT 
    bil.id,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.description,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.category_code,
    ci.sku as resolved_sku,
    sol.line_number as sale_order_line_number
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL
AND bil.deleted = false
ORDER BY sol.line_number, bil.part_role;
```

**Resultado esperado:**
- Deberías ver los componentes del BOM (fabric, tube, bracket, etc.)
- Cada componente debería tener su `part_role`, `qty`, `uom`, y costos

---

## 📊 PASO 7: Resumen Final

Ejecuta esta query para ver un resumen completo:

```sql
SELECT 
    'Quote' as entity_type,
    q.quote_no as document_number,
    q.status as status,
    q.created_at,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count
FROM "Quotes" q
WHERE q.id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL

UNION ALL

SELECT 
    'SalesOrder' as entity_type,
    so.sale_order_no as document_number,
    so.status as status,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID REAL
AND so.deleted = false

ORDER BY created_at;
```

**Resultado esperado:**
- Deberías ver 2 filas: una para la Quote y otra para el SalesOrder
- Ambos deberían tener el mismo número de líneas

---

## ✅ Checklist de Verificación

- [ ] Paso 1: Encontré una Quote sin SalesOrder
- [ ] Paso 2: Aprobé la Quote (UPDATE ejecutado)
- [ ] Paso 3: Se creó el SalesOrder
- [ ] Paso 4: Se crearon los SalesOrderLines
- [ ] Paso 5: Se crearon los BomInstances
- [ ] Paso 6: Se crearon los BomInstanceLines
- [ ] Paso 7: El resumen muestra Quote y SalesOrder correctamente

---

## 🐛 Si algo falla

1. **No se creó el SalesOrder:**
   - Verifica que el trigger esté habilitado:
     ```sql
     SELECT tgname, tgenabled 
     FROM pg_trigger 
     WHERE tgname = 'trg_on_quote_approved_create_operational_docs';
     ```
   - Revisa los logs de PostgreSQL/Supabase para ver mensajes de `RAISE NOTICE`

2. **SalesOrder se creó pero sin líneas:**
   - Verifica que la Quote tenga QuoteLines:
     ```sql
     SELECT COUNT(*) FROM "QuoteLines" 
     WHERE quote_id = '<quote_id>' AND deleted = false;
     ```

3. **BomInstances no se crearon:**
   - Verifica que los QuoteLines tengan QuoteLineComponents:
     ```sql
     SELECT COUNT(*) FROM "QuoteLineComponents" qlc
     INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
     WHERE ql.quote_id = '<quote_id>' 
     AND qlc.deleted = false;
     ```

---

## 📝 Notas

- El trigger es **idempotente**: si ya existe un SalesOrder para la Quote, no creará uno duplicado
- El trigger solo se ejecuta cuando el status cambia **de otro valor a 'approved'**
- Si la Quote ya estaba en 'approved', el trigger no se ejecutará






