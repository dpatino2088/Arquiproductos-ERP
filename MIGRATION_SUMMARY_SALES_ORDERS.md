# Migración: SaleOrders → SalesOrders (Convención de Nombres)

## 📋 Resumen

Se ha actualizado la convención de nombres de tablas para seguir el estándar:
**Dominio (plural) + Entidad (singular) + Lines (plural)**

### Cambios Realizados

#### 1. **Tablas Renombradas**
- `SaleOrders` → `SalesOrders` ✅
- `SaleOrderLines` → `SalesOrderLines` ✅

#### 2. **Archivos SQL Creados/Actualizados**

##### Migraciones
- ✅ `database/migrations/198_rename_sale_orders_to_sales_orders.sql`
  - Renombra las tablas
  - Actualiza constraints, índices, triggers
  - Actualiza políticas RLS
  - Actualiza comentarios

##### Funciones y Triggers
- ✅ `RECREATE_TRIGGER_FUNCTION_COMPLETE.sql`
  - Actualizado para usar `SalesOrders` y `SalesOrderLines`
  
- ✅ `UPDATE_ALL_SQL_REFERENCES_TO_SALES_ORDERS.sql`
  - Actualiza función `on_sale_order_confirmed_create_manufacturing_order`
  - Actualiza trigger `trg_on_sale_order_confirmed_create_manufacturing_order`
  - Actualiza vista `SaleOrderMaterialList`

#### 3. **Archivos TypeScript/React Actualizados**

##### Hooks
- ✅ `src/hooks/useSaleOrders.ts`
  - Actualizado `.from('SaleOrders')` → `.from('SalesOrders')`
  - Actualizado `.from('SaleOrderLines')` → `.from('SalesOrderLines')`

- ✅ `src/hooks/useQuotes.ts`
  - Actualizado `.from('SaleOrders')` → `.from('SalesOrders')`

- ✅ `src/hooks/useManufacturing.ts`
  - Actualizado `.from('SaleOrderLines')` → `.from('SalesOrderLines')`

##### Páginas
- ✅ `src/pages/sales/SaleOrders.tsx`
- ✅ `src/pages/sales/SaleOrderNew.tsx`
- ✅ `src/pages/sales/Quotes.tsx`
- ✅ `src/pages/manufacturing/OrderList.tsx`
- ✅ `src/pages/catalog/ApprovedBOMList.tsx`

## 🚀 Pasos para Ejecutar la Migración

### Paso 1: Ejecutar Migración de Tablas
```sql
-- Ejecutar en Supabase SQL Editor
\i database/migrations/198_rename_sale_orders_to_sales_orders.sql
```

### Paso 2: Actualizar Funciones y Triggers
```sql
-- Ejecutar en Supabase SQL Editor
\i UPDATE_ALL_SQL_REFERENCES_TO_SALES_ORDERS.sql
\i RECREATE_TRIGGER_FUNCTION_COMPLETE.sql
```

### Paso 3: Verificar
```sql
-- Verificar que las tablas existen con los nuevos nombres
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('SalesOrders', 'SalesOrderLines');

-- Verificar que los triggers están activos
SELECT tgname, tgrelid::regclass, tgenabled
FROM pg_trigger
WHERE tgrelid::regclass::text IN ('SalesOrders', 'SalesOrderLines')
AND NOT tgisinternal;
```

## ⚠️ Notas Importantes

1. **Vista `SaleOrderMaterialList`**: 
   - La vista se recrea en `UPDATE_ALL_SQL_REFERENCES_TO_SALES_ORDERS.sql`
   - Mantiene el nombre original para compatibilidad con código existente

2. **Políticas RLS**:
   - Todas las políticas se recrean con nuevos nombres
   - Formato: `sales_orders_*` y `sales_order_lines_*`

3. **Foreign Keys**:
   - Se actualizan automáticamente en la migración
   - Las referencias en otras tablas (como `ManufacturingOrders.sale_order_id`) siguen funcionando

4. **Código TypeScript**:
   - Todas las referencias a `.from('SaleOrders')` se actualizaron
   - Los tipos TypeScript (`SaleOrder`, `SaleOrderLine`) no cambian
   - Solo cambian los nombres de las tablas en las queries

## 🔍 Verificación Post-Migración

1. Verificar que las queries funcionan:
   - Listar Sales Orders
   - Crear/Editar Sales Orders
   - Ver Sales Order Lines
   - Crear Manufacturing Orders desde Sales Orders

2. Verificar triggers:
   - Aprobar un Quote y verificar que se crea un Sales Order
   - Confirmar un Sales Order y verificar que se crea un Manufacturing Order

3. Verificar RLS:
   - Probar acceso desde diferentes organizaciones
   - Verificar que los datos están aislados correctamente

## 📝 Convención Aplicada

La convención ahora es consistente:
- ✅ `SalesOrders` (Dominio plural + Entidad singular)
- ✅ `SalesOrderLines` (Dominio plural + Entidad singular + Lines plural)
- ✅ `ManufacturingOrders` (ya estaba correcto)
- ⏳ `ManufacturingOrderSteps` (pendiente de crear)

## 🎯 Próximos Pasos

1. Ejecutar las migraciones SQL en orden
2. Probar todas las funcionalidades
3. Verificar que no hay errores en la consola
4. Crear `ManufacturingOrderSteps` cuando sea necesario








