# 🔧 Ejecutar Migración 329: Backfill Missing SalesOrderLines

## 📋 Problema Actual

Las imágenes muestran que hay **5 SalesOrders sin SalesOrderLines**. Esto impide crear Manufacturing Orders.

## ✅ Solución

Ejecutar la migración **329** que crea las SalesOrderLines faltantes.

---

## 🚀 Pasos a Ejecutar

### 1️⃣ Ejecutar Migración 329

**Archivo:** `database/migrations/329_backfill_missing_salesorder_lines.sql`

**Qué hace:**
- ✅ Identifica SalesOrders sin SalesOrderLines
- ✅ Crea SalesOrderLines para cada QuoteLine correspondiente
- ✅ Validación de `side_channel_type`
- ✅ Verificación final

**Ejecutar en Supabase SQL Editor**

---

## ✅ Verificación Post-Ejecución

Después de ejecutar la migración, deberías ver:

1. **Logs de ejecución:**
   - `Processing SalesOrder SO-XXXXX`
   - `✅ Created SalesOrderLine ...`
   - `✅ Completed SalesOrder SO-XXXXX`

2. **Resultado de verificación:**
   ```
   so_without_lines: 0
   status: ✅ All SalesOrders have SalesOrderLines
   ```

---

## 🧪 Prueba en UI

Después de ejecutar la migración:

1. Ir a Manufacturing → Order List
2. Verificar que el SalesOrder ahora muestra el botón "+ Create MO" habilitado
3. Intentar crear un Manufacturing Order
4. Debería funcionar correctamente

---

## 📝 Notas

- Esta migración es **idempotente**: puede ejecutarse múltiples veces sin crear duplicados
- Solo crea SalesOrderLines para SalesOrders que no las tienen
- Usa la misma lógica que el trigger, asegurando consistencia


