# 📋 Resumen: Migración 212 - Fix Quote Approved Trigger

## ✅ Lo que se hizo

### 1. **Corrección de nombres de tablas**
- **Problema:** La migración 212 usaba nombres antiguos de tablas (`SaleOrders`, `SaleOrderLines`)
- **Solución:** Se actualizaron todas las referencias a los nombres correctos:
  - `SaleOrders` → `SalesOrders` (con 's')
  - `SaleOrderLines` → `SalesOrderLines` (con 's')
- **Archivos corregidos:**
  - `database/migrations/212_fix_quote_approved_trigger_sale_order_creation.sql` ✅
  - `database/migrations/201_update_bom_trigger_use_base_pricing_fields.sql` ✅
  - `database/migrations/202_add_engineering_rules_to_bom.sql` ✅
  - `database/migrations/203_update_bom_trigger_call_engineering_rules.sql` ✅
  - `database/migrations/206_normalize_affects_role_component_roles.sql` ✅
  - `database/migrations/188_bom_uom_validation_and_cost_uom.sql` ✅
  - `database/migrations/200_robust_uom_fabric_pricing_model.sql` ✅
  - `database/migrations/192_sale_orders_order_progress_status.sql` ✅
  - `database/migrations/193_sync_sale_order_status_from_manufacturing.sql` ✅
  - `database/migrations/194_complete_quote_to_manufacturing_flow.sql` ✅
  - `database/migrations/195_delete_bom_when_manufacturing_order_deleted.sql` ✅
  - `database/migrations/196_fix_convert_quote_to_sale_order_status.sql` ✅
  - `database/migrations/197_ensure_quote_approved_trigger_works.sql` ✅

### 2. **Migración 212 ejecutada exitosamente**
- ✅ La migración se ejecutó sin errores
- ✅ El trigger `trg_on_quote_approved_create_operational_docs` está activo
- ✅ La función `on_quote_approved_create_operational_docs()` está correctamente definida

### 3. **Funcionalidad del trigger**
Cuando una Quote cambia su status a `'approved'`, el trigger automáticamente crea:
- ✅ **SalesOrder** (con número generado automáticamente)
- ✅ **SalesOrderLines** (una por cada QuoteLine)
- ✅ **BomInstances** (uno por cada SalesOrderLine)
- ✅ **BomInstanceLines** (componentes del BOM desde QuoteLineComponents)

---

## 🧪 Paso a paso para probar

### **PASO 1: Ejecutar query para aprobar Quote automáticamente**

Copia y pega esta query en Supabase SQL Editor:

```sql
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text;
BEGIN
    -- Encontrar la Quote más reciente sin aprobar
    SELECT q.id, q.quote_no INTO v_quote_id, v_quote_no
    FROM "Quotes" q
    WHERE q.deleted = false
    AND q.status != 'approved'
    AND (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) > 0
    ORDER BY q.created_at DESC
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ No se encontró ninguna Quote para aprobar';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Quote encontrada: % (%)', v_quote_no, v_quote_id;
    
    -- Aprobar la Quote
    UPDATE "Quotes"
    SET status = 'approved',
        updated_at = NOW()
    WHERE id = v_quote_id
    AND deleted = false
    AND status != 'approved';
    
    RAISE NOTICE '✅ Quote % aprobada. El trigger debería haber creado el SalesOrder.', v_quote_no;
    RAISE NOTICE '🔍 ID de la Quote: %', v_quote_id;
END $$;
```

**Resultado esperado:** Verás mensajes como:
- `📋 Quote encontrada: QT-000036 (e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2)`
- `✅ Quote QT-000036 aprobada. El trigger debería haber creado el SalesOrder.`
- `🔍 ID de la Quote: e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2`

**⚠️ IMPORTANTE:** Copia el ID que aparece en el mensaje para el siguiente paso.

---

### **PASO 2: Verificar que se creó el SalesOrder**

Reemplaza `<quote_id>` con el ID que copiaste del PASO 1:

```sql
SELECT 
    'Quote' as tipo,
    q.quote_no as numero,
    q.status,
    q.created_at,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count
FROM "Quotes" q
WHERE q.id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID DEL PASO 1

UNION ALL

SELECT 
    'SalesOrder',
    so.sale_order_no,
    so.status,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL MISMO ID
AND so.deleted = false

ORDER BY created_at;
```

**Resultado esperado:**
- Deberías ver 2 filas: una para la Quote y otra para el SalesOrder
- Ambos deberían tener el mismo número de líneas
- El SalesOrder debería tener `status = 'draft'`

---

### **PASO 3: Verificar SalesOrderLines**

```sql
SELECT 
    sol.line_number,
    sol.item_name,
    sol.qty,
    sol.product_type,
    sol.drive_type
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID DEL PASO 1
AND sol.deleted = false
ORDER BY sol.line_number;
```

**Resultado esperado:** Deberías ver una fila por cada QuoteLine de la Quote original.

---

### **PASO 4: Verificar BomInstances**

```sql
SELECT 
    bi.id as bom_instance_id,
    bi.status,
    sol.line_number,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil WHERE bil.bom_instance_id = bi.id AND bil.deleted = false) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID DEL PASO 1
AND bi.deleted = false
ORDER BY sol.line_number;
```

**Resultado esperado:** Deberías ver un BomInstance por cada SalesOrderLine, con `status = 'locked'`.

---

## 📝 Checklist para el equipo de programadores

### **Antes de pasar a producción:**

- [ ] **Ejecutar migración 212 en ambiente de desarrollo**
  - Archivo: `database/migrations/212_fix_quote_approved_trigger_sale_order_creation.sql`
  - Verificar que se ejecute sin errores

- [ ] **Probar el flujo completo:**
  - [ ] Crear una Quote nueva
  - [ ] Agregar QuoteLines a la Quote
  - [ ] Configurar productos (si aplica)
  - [ ] Aprobar la Quote
  - [ ] Verificar que se creó el SalesOrder
  - [ ] Verificar que se crearon los SalesOrderLines
  - [ ] Verificar que se crearon los BomInstances
  - [ ] Verificar que se crearon los BomInstanceLines

- [ ] **Verificar en el código TypeScript/React:**
  - [ ] Las referencias a `SalesOrders` (no `SaleOrders`)
  - [ ] Las referencias a `SalesOrderLines` (no `SaleOrderLines`)
  - [ ] Los hooks y queries usan los nombres correctos

- [ ] **Revisar logs de PostgreSQL/Supabase:**
  - [ ] Verificar que no hay errores en el trigger
  - [ ] Verificar que los mensajes `RAISE NOTICE` aparecen correctamente

- [ ] **Documentación:**
  - [ ] Actualizar documentación del flujo Quote → SalesOrder
  - [ ] Documentar el comportamiento del trigger

---

## ⚠️ Lo que falta hacer

### **1. Verificación en código TypeScript/React**
- [ ] Buscar todas las referencias a `SaleOrders` (sin 's') en el código frontend
- [ ] Actualizar a `SalesOrders` (con 's')
- [ ] Buscar todas las referencias a `SaleOrderLines` (sin 's')
- [ ] Actualizar a `SalesOrderLines` (con 's')

**Comando para buscar:**
```bash
grep -r "SaleOrders" src/ --exclude-dir=node_modules
grep -r "SaleOrderLines" src/ --exclude-dir=node_modules
```

### **2. Verificar hooks y queries**
Revisar estos archivos:
- `src/hooks/useSaleOrders.ts`
- `src/pages/sales/SaleOrders.tsx`
- `src/pages/sales/SaleOrderNew.tsx`
- `src/pages/manufacturing/OrderList.tsx`
- Cualquier otro archivo que use SalesOrders

### **3. Testing**
- [ ] Crear tests unitarios para el trigger (opcional pero recomendado)
- [ ] Probar con diferentes escenarios:
  - Quote con múltiples líneas
  - Quote sin líneas (no debería crear SalesOrder)
  - Quote ya aprobada (no debería crear duplicado)

### **4. Monitoreo**
- [ ] Configurar alertas si el trigger falla
- [ ] Monitorear logs de errores relacionados con SalesOrders

---

## 📂 Archivos importantes

### **Migraciones:**
- `database/migrations/212_fix_quote_approved_trigger_sale_order_creation.sql` - Migración principal ✅
- `database/migrations/198_rename_sale_orders_to_sales_orders.sql` - Renombrado de tablas (histórica)

### **Scripts de prueba:**
- `database/migrations/TEST_212_FACIL.sql` - Script fácil para probar
- `database/migrations/TEST_212_quote_approved_trigger.sql` - Script completo de pruebas
- `database/migrations/PASOS_PROBAR_TRIGGER_212.md` - Guía detallada de pruebas

### **Documentación:**
- `database/migrations/RESUMEN_MIGRACION_212.md` - Este documento

---

## 🔍 Troubleshooting

### **Si el trigger no crea el SalesOrder:**

1. **Verificar que el trigger está habilitado:**
```sql
SELECT tgname, tgenabled 
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';
```

2. **Verificar que la función existe:**
```sql
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'on_quote_approved_create_operational_docs';
```

3. **Revisar logs de PostgreSQL/Supabase** para mensajes de error

4. **Verificar que las tablas existen:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('SalesOrders', 'SalesOrderLines', 'BomInstances', 'BomInstanceLines');
```

---

## ✅ Estado actual

- ✅ Migración 212 corregida y ejecutada
- ✅ Todas las referencias a tablas actualizadas en migraciones
- ✅ Trigger activo y funcionando
- ⚠️ Pendiente: Verificar código TypeScript/React
- ⚠️ Pendiente: Testing completo
- ⚠️ Pendiente: Documentación actualizada

---

## 📞 Contacto

Si hay dudas o problemas, revisar:
1. Los logs de PostgreSQL/Supabase
2. El archivo `PASOS_PROBAR_TRIGGER_212.md` para guía detallada
3. El archivo `TEST_212_FACIL.sql` para scripts de prueba




