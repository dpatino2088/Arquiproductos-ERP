# 📋 Pasos de Verificación: Approval Flow

## ✅ PASO 1: Verificar Enum en Base de Datos (CRÍTICO)

**Ejecutar en Supabase SQL Editor:**

```sql
-- Verificar valores del enum quote_status
SELECT 
    t.typname as enum_name,
    e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname = 'quote_status'
ORDER BY e.enumsortorder;
```

**Resultado esperado:**
- Debe mostrar: `draft`, `sent`, `approved`, `rejected`, `cancelled` (todo minúscula)

**Si el enum tiene `'approved'` (minúscula):**
- ✅ El código actual con `'Approved'` puede fallar
- **Acción:** Cambiar en `src/hooks/useQuotes.ts` línea ~867:
  ```typescript
  status: 'approved',  // minúscula para coincidir con enum
  ```

**Si el enum acepta `'Approved'` (mayúscula):**
- ✅ El código actual está bien

---

## ✅ PASO 2: Probar Aprobación desde QuoteNew

### 2.1 Preparación
1. Abrir la aplicación en `localhost:5173`
2. Ir a **Sales → Quotes**
3. Crear o editar un Quote en estado **Draft**

### 2.2 Aprobar Quote
1. En el formulario de Quote, cambiar **Status** a **"Approved"**
2. Hacer clic en **"Save"** o **"Save & Close"**
3. **Observar:**
   - ¿Navega automáticamente a Quote Approved?
   - ¿Muestra mensaje de éxito?
   - ¿Hay errores en la consola?

### 2.3 Verificar en DevTools Network
1. Abrir **DevTools → Network**
2. Filtrar por **"Quotes"**
3. Buscar el **PATCH** request
4. **Verificar:**
   - ¿Hay un PATCH con `{"status":"Approved"}` o `{"status":"approved"}`?
   - ¿Cuántos PATCH hay? (puede haber 2: uno sin status, otro con status)
   - ¿El status cambió correctamente?

---

## ⚡ SOLUCIÓN RÁPIDA: Si SalesOrder no se crea

**Ejecutar este script completo en Supabase SQL Editor:**

```sql
-- Archivo: DIAGNOSTICO_RAPIDO_QT_000003.sql
-- Este script diagnostica y fuerza la creación del SalesOrder
```

O ejecutar directamente:

```sql
-- Forzar creación de SalesOrder para QT-000003
DO $$
DECLARE
    v_quote_id uuid;
    v_so_id uuid;
BEGIN
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE quote_no = 'QT-000003' AND deleted = false;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ Quote not found';
        RETURN;
    END IF;
    
    -- Verificar si ya existe
    SELECT so.id INTO v_so_id
    FROM "SalesOrders" so
    WHERE so.quote_id = v_quote_id AND so.deleted = false;
    
    IF v_so_id IS NOT NULL THEN
        RAISE NOTICE '✅ SalesOrder already exists';
        RETURN;
    END IF;
    
    -- Crear SalesOrder
    RAISE NOTICE '🔧 Creating SalesOrder...';
    v_so_id := public.ensure_sales_order_for_approved_quote(v_quote_id);
    
    IF v_so_id IS NOT NULL THEN
        RAISE NOTICE '✅ SalesOrder created: %', v_so_id;
    END IF;
END $$;
```

---

## ✅ PASO 3: Verificar SalesOrder en Base de Datos

### Opción A: Verificar Quote Específico (si conoces el quote_no)

**Ejecutar en Supabase SQL Editor:**

```sql
-- Reemplazar 'QT-000003' con el quote_no que acabas de aprobar
SELECT 
    q.id, 
    q.quote_no, 
    q.status, 
    so.id as sales_order_id, 
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ PROBLEM: No SalesOrder'
        ELSE '✅ OK: SalesOrder exists'
    END as verification
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'  -- ⚠️ REEMPLAZAR CON TU QUOTE_NO
AND q.deleted = false;
```

### Opción B: Verificar Todos los Quotes Aprobados (más fácil)

**Ejecutar en Supabase SQL Editor:**

```sql
-- Verifica TODOS los quotes aprobados y sus SalesOrders
SELECT 
    q.id, 
    q.quote_no, 
    q.status, 
    q.updated_at as quote_updated,
    so.id as sales_order_id, 
    so.sale_order_no,
    so.status as so_status,
    so.created_at as so_created,
    CASE 
        WHEN so.id IS NULL THEN '❌ PROBLEM: No SalesOrder'
        ELSE '✅ OK: SalesOrder exists'
    END as verification
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status::text ILIKE 'approved'
AND q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 10;
```

**Resultado esperado:**
- `status`: `approved` o `Approved`
- `sales_order_id`: Debe tener un UUID (no NULL)
- `sale_order_no`: Debe tener un valor como `SO-090XXX`
- `verification`: `✅ OK: SalesOrder exists`

**Si `sales_order_id` es NULL:**
- ⚠️ El trigger no se ejecutó o falló
- Ver **PASO 4** para diagnosticar

---

## ✅ PASO 4: Verificar Logs del Trigger (Si SalesOrder no existe)

**En Supabase Dashboard:**
1. Ir a **Logs → Postgres Logs**
2. Filtrar por tiempo reciente (últimos 5 minutos)
3. Buscar mensajes que contengan:
   - `🔔 Trigger on_quote_approved_create_operational_docs FIRED`
   - `✅ SalesOrder ensured`
   - `❌ Error` o `⚠️ Warning`

**Si NO aparecen logs del trigger:**
- El trigger no se ejecutó
- Verificar que el trigger esté habilitado (ver PASO 5)

**Si aparecen errores:**
- Copiar el error completo
- Revisar qué falló (SalesOrder creation, SalesOrderLines, etc.)

---

## ✅ PASO 5: Verificar Trigger Está Habilitado

**Ejecutar en Supabase SQL Editor:**

```sql
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE '⚠️ ' || tgenabled::text
    END as status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';
```

**Resultado esperado:**
- `status`: `✅ Enabled`
- `trigger_definition`: Debe mostrar `AFTER UPDATE ON "Quotes"`

**Si está `❌ Disabled`:**
- Ejecutar:
  ```sql
  ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;
  ```

---

## ✅ PASO 6: Verificar No Hay Duplicados

**Ejecutar en Supabase SQL Editor:**

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

**Resultado esperado:**
- **0 filas** (no debe haber duplicados)

**Si hay duplicados:**
- ⚠️ El unique index no está funcionando
- Verificar que existe: `ux_salesorders_org_quote_active`

---

## ✅ PASO 7: Probar Botón "Create Sales Order" (Opcional)

1. Ir a **Sales → Quotes**
2. Buscar un quote **Approved** que NO tenga SalesOrder
3. Hacer clic en el botón de **carrito** (Create Sales Order)
4. **Observar:**
   - ¿Aproba el quote primero si no estaba aprobado?
   - ¿Espera con polling (no sleep)?
   - ¿Navega al SalesOrder cuando aparece?

---

## 🔧 SI ALGO FALLA

### Error: "invalid input value for enum quote_status: 'Approved'"

**Solución:**
1. Abrir `src/hooks/useQuotes.ts`
2. Buscar línea ~867
3. Cambiar:
   ```typescript
   status: 'Approved',  // ❌ Cambiar esto
   ```
   Por:
   ```typescript
   status: 'approved',  // ✅ minúscula
   ```

### Error: SalesOrder no se crea

**Diagnóstico:**
1. Verificar logs del trigger (PASO 4)
2. Verificar trigger habilitado (PASO 5)
3. Verificar que el quote realmente cambió a `approved`:
   ```sql
   SELECT id, quote_no, status FROM "Quotes" WHERE id = '<QUOTE_ID>'::uuid;
   ```

### Error: Polling timeout

**Diagnóstico:**
1. Verificar que el trigger se ejecutó (logs)
2. Verificar que no hay errores en el trigger
3. Aumentar timeout en `waitForSalesOrder()` si es necesario (actualmente 8s)

---

## 📊 RESUMEN DE VERIFICACIÓN

| Paso | Qué Verificar | Resultado Esperado |
|------|---------------|-------------------|
| 1 | Enum values | `approved` (minúscula) |
| 2 | Aprobar desde UI | Navega a Quote Approved |
| 2.3 | Network PATCH | `{"status":"Approved"}` o `{"status":"approved"}` |
| 3 | SalesOrder en DB | Existe con `sales_order_id` |
| 4 | Logs del trigger | Mensajes de éxito |
| 5 | Trigger enabled | `✅ Enabled` |
| 6 | No duplicados | 0 filas |

---

## ✅ CRITERIO DE ÉXITO FINAL

**Todo funciona correctamente si:**
- ✅ Puedes aprobar un quote desde QuoteNew sin errores
- ✅ El SalesOrder se crea automáticamente (aparece en DB)
- ✅ No hay duplicados de SalesOrder
- ✅ El polling encuentra el SalesOrder (no timeout)
- ✅ No hay errores intermitentes

**Si todo lo anterior es ✅ → Implementación exitosa**

---

**Fecha:** 31 de Diciembre, 2024  
**Estado:** Listo para verificación

