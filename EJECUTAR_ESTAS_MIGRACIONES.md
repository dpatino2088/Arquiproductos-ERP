# 🚀 Ejecutar Estas Migraciones (Orden Correcto)

## ⚠️ IMPORTANTE: Ejecutar en este orden exacto

### 1️⃣ Primero: Migración 326 (Trigger Minimal + Función Idempotente)
**⚠️ IMPORTANTE: Esta migración crea el trigger que SOLO crea SalesOrder (sin SalesOrderLines)**

### 2️⃣ Segundo: Migración 328 (Agregar SalesOrderLines al Trigger)
**Archivo:** `database/migrations/328_add_salesorder_lines_to_minimal_trigger.sql`

**Qué hace:**
- ✅ Actualiza el trigger minimal para también crear SalesOrderLines
- ✅ Mantiene el principio: NO crea BOM/components (solo SO + SOL)
- ✅ Backfill de SalesOrderLines faltantes para SalesOrders existentes
- ✅ Verificación final

**Ejecutar en Supabase SQL Editor después de la migración 326**

---

### 3️⃣ Tercero: Migración 327 (Corregir sale_order_no faltantes)
**Archivo:** `database/migrations/326_minimal_trigger_salesorder_only.sql`

**Qué hace:**
- ✅ Crea unique index para idempotencia
- ✅ Reimplementa función `ensure_sales_order_for_approved_quote` (robusta)
- ✅ Crea trigger MINIMAL (solo SalesOrder, sin BOM)
- ✅ Backfill de SalesOrders faltantes
- ✅ Queries de verificación

**Ejecutar en Supabase SQL Editor**

---

### 4️⃣ Cuarto: Migración 327 (Corregir sale_order_no faltantes)
**Archivo:** `database/migrations/327_fix_missing_sale_order_no.sql`

**Qué hace:**
- ✅ Identifica SalesOrders sin `sale_order_no`
- ✅ Los corrige generando el número
- ✅ Verificación final

**Ejecutar en Supabase SQL Editor**

---

## ✅ Verificación Post-Migración

Después de ejecutar todas las migraciones (326, 328, 327), ejecutar:

Después de ejecutar ambas migraciones, ejecutar:

```sql
-- Verificación completa
SELECT 
    'Summary' as check_name,
    COUNT(DISTINCT q.id) FILTER (WHERE q.status::text ILIKE 'approved') as total_approved,
    COUNT(DISTINCT so.id) FILTER (WHERE q.status::text ILIKE 'approved') as approved_with_so,
    COUNT(DISTINCT q.id) FILTER (
        WHERE q.status::text ILIKE 'approved' AND so.id IS NULL
    ) as approved_without_so,
    COUNT(*) FILTER (WHERE so.sale_order_no IS NULL OR so.sale_order_no = '') as so_without_number,
    CASE 
        WHEN COUNT(DISTINCT q.id) FILTER (
            WHERE q.status::text ILIKE 'approved' AND so.id IS NULL
        ) = 0 
        AND COUNT(*) FILTER (WHERE so.sale_order_no IS NULL OR so.sale_order_no = '') = 0
        THEN '✅ ALL OK'
        ELSE '❌ ISSUES FOUND'
    END as overall_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.deleted = false;
```

**Resultado esperado:**
- `approved_without_so`: `0`
- `so_without_number`: `0`
- `overall_status`: `✅ ALL OK`

---

## 🧪 Prueba Manual

1. Crear un nuevo Quote
2. Aprobarlo desde la UI
3. Verificar que:
   - ✅ SalesOrder se crea automáticamente
   - ✅ SalesOrder tiene `sale_order_no` (ej: `SO-090157`)
   - ✅ No hay duplicados

---

## 📝 Notas Importantes

- **El trigger ahora es MINIMAL**: Solo crea SalesOrder, NO crea BOM/components
- **BOM generation**: Debe hacerse después, en Manufacturing step o botón "Generate BOM"
- **Frontend**: Solo debe hacer `PATCH Quotes.status='approved'`, nada más
- **Idempotencia**: Puedes aprobar el mismo quote múltiples veces sin crear duplicados

