# 🔧 Ejecutar Migraciones 333 y 334

## 🎯 Problema Identificado

El error era claro:
```
Error: null value in column "catalog_item_id" of relation "SalesOrderLines"
```

La columna `catalog_item_id` es **NOT NULL** pero no estaba siendo incluida en los INSERTs.

## ✅ Solución

**Migración 333:** Corrige el backfill para incluir `catalog_item_id`
**Migración 334:** Corrige el trigger para incluir `catalog_item_id` en futuras creaciones

## 🚀 Pasos de Ejecución

### 1️⃣ Ejecutar Migración 333 (Backfill)

**Archivo:** `database/migrations/333_fix_backfill_add_catalog_item_id.sql`

**Qué hace:**
- ✅ Crea SalesOrderLines para los 5 SalesOrders sin líneas
- ✅ Incluye `catalog_item_id` (requerido)
- ✅ Valida que `catalog_item_id` no sea NULL antes de crear
- ✅ Incluye verificación final

**Ejecutar en Supabase SQL Editor**

### 2️⃣ Ejecutar Migración 334 (Trigger Fix)

**Archivo:** `database/migrations/334_fix_trigger_add_catalog_item_id.sql`

**Qué hace:**
- ✅ Actualiza el trigger para incluir `catalog_item_id` en futuras creaciones
- ✅ Asegura que nuevos SalesOrders tengan líneas correctamente creadas

**Ejecutar en Supabase SQL Editor**

## ✅ Verificación Post-Ejecución

Después de ejecutar ambas migraciones, deberías ver:

1. **Resultado de migración 333:**
   ```
   so_without_lines: 0
   status: ✅ All SalesOrders have SalesOrderLines
   ```

2. **Verificar en UI:**
   - Ir a Manufacturing → Order List
   - Los SalesOrders deberían mostrar el botón "+ Create MO" habilitado
   - No debería aparecer el error "No Sales Order Lines found"

## 📝 Orden de Ejecución

**IMPORTANTE:** Ejecutar primero la 333 (backfill), luego la 334 (trigger fix).


