# 📊 Origen de Datos: SO-000010 y "Di Panama"

## 🔍 **DE DÓNDE VIENE CADA DATO**

### 1. **SO-000010** (Sale Order Number)
- **Origen**: Tabla `SaleOrders`
- **Campo**: `sale_order_no`
- **Query en UI**: `ApprovedBOMList.tsx` línea 58-79
  ```typescript
  const { data: saleOrders } = await supabase
    .from('SaleOrders')
    .select('id, sale_order_no, customer_id, created_at, ...')
    .eq('organization_id', activeOrganizationId)
    .eq('deleted', false);
  ```

### 2. **"Di Panama"** (Customer Name)
- **Origen**: Tabla `DirectoryCustomers`
- **Campo**: `customer_name`
- **Relación**: `SaleOrders.customer_id` → `DirectoryCustomers.id`
- **Query en UI**: `ApprovedBOMList.tsx` línea 114-126
  ```typescript
  const customerIds = [...new Set(saleOrders.map((so: any) => so.customer_id))];
  const { data: customers } = await supabase
    .from('DirectoryCustomers')
    .select('id, customer_name')
    .in('id', customerIds);
  ```

### 3. **Componentes BOM** (Materiales)
- **Origen**: Vista `SaleOrderMaterialList`
- **Vista agrega datos de**:
  - `SaleOrders` (sale_order_id, sale_order_no)
  - `BomInstances` (vinculado a SaleOrderLines)
  - `BomInstanceLines` (materiales individuales)
  - `CatalogItems` (SKU, item_name)
- **Query en UI**: `ApprovedBOMList.tsx` línea 106-112
  ```typescript
  const { data: materialList } = await supabase
    .from('SaleOrderMaterialList')
    .select('*')
    .in('sale_order_id', saleOrders.map((so: any) => so.id));
  ```

---

## 🔄 **FLUJO DE DATOS COMPLETO**

```
SaleOrders (SO-000010)
  ├── customer_id → DirectoryCustomers → customer_name ("Di Panama")
  └── SaleOrderLines
        └── BomInstances
              └── BomInstanceLines
                    └── CatalogItems (SKU, item_name)
                          ↓
                    SaleOrderMaterialList (VISTA AGREGADA)
```

---

## ✅ **CÓMO VERIFICAR SI ESTÁ FUNCIONANDO**

### **Paso 1: Ejecutar Script de Verificación**
```bash
# Ejecutar en Supabase SQL Editor o psql
psql $DATABASE_URL -f VERIFY_SO_000010_COMPLETE.sql
```

Este script verificará:
- ✅ Si SO-000010 existe
- ✅ Si el customer "Di Panama" existe y está vinculado
- ✅ Si hay SaleOrderLines
- ✅ Si hay BomInstances
- ✅ Si hay BomInstanceLines
- ✅ Si la vista SaleOrderMaterialList tiene datos

### **Paso 2: Verificar en la UI**
1. Abrir consola del navegador (F12)
2. Ir a Network tab
3. Navegar a Manufacturing → Bill Of Materials
4. Verificar las queries:
   - `SaleOrders` query
   - `DirectoryCustomers` query
   - `SaleOrderMaterialList` query

### **Paso 3: Verificar Errores**
- Si no aparecen datos → Verificar errores en consola
- Si aparecen datos pero incorrectos → Verificar la vista `SaleOrderMaterialList`
- Si el customer name es "N/A" → Verificar que `customer_id` esté correcto en `SaleOrders`

---

## 🐛 **PROBLEMAS COMUNES**

### **Problema 1: Customer name muestra "N/A"**
**Causa**: `customer_id` en `SaleOrders` no existe en `DirectoryCustomers`
**Solución**: Verificar que el customer exista y esté vinculado correctamente

### **Problema 2: No aparecen materiales**
**Causa**: 
- No hay `BomInstances` generados
- No hay `BomInstanceLines` generados
- La vista `SaleOrderMaterialList` no tiene datos

**Solución**: 
- Verificar que el quote fue aprobado correctamente
- Verificar que `on_quote_approved_create_operational_docs()` se ejecutó
- Regenerar BOM si es necesario

### **Problema 3: Datos desactualizados**
**Causa**: La vista `SaleOrderMaterialList` está cacheada o desactualizada
**Solución**: Refrescar la página o verificar que la vista esté actualizada

---

## 📝 **PRÓXIMOS PASOS**

1. **Ejecutar** `VERIFY_SO_000010_COMPLETE.sql` para diagnóstico completo
2. **Revisar** los resultados del script
3. **Si hay problemas**, regenerar BOM con:
   ```sql
   -- Regenerar BOM para SO-000010
   SELECT public.regenerate_bom_for_sale_order('SO-000010');
   ```








