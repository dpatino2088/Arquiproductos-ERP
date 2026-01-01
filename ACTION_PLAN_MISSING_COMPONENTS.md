# 🎯 Plan de Acción: Componentes Faltantes y UOM

## 📊 Situación Actual

**Visto en Cut List:**
- ✅ `bottom_rail_end_cap` (RCA-21-W) - 2 ea
- ✅ `bracket` (RC3104-W) - 2 ea
- ❌ **Faltan:** Componentes con `measure_basis = 'linear_m'` (tubes, rails, cassettes, etc.)

---

## 🔍 Diagnóstico Necesario

### **Paso 1: Verificar QuoteLineComponents**

Ejecuta este query para ver QUÉ componentes deberían estar en el BOM:

```sql
-- Reemplaza 'TU_MO_ID' con el ID real de MO-000003
SELECT 
    qlc.component_role,
    ci.sku,
    ci.measure_basis,
    ci.item_type,
    qlc.qty,
    qlc.uom,
    qlc.source
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000003'
AND qlc.deleted = false
ORDER BY ci.measure_basis, qlc.component_role;
```

**Preguntas clave:**
1. ¿Hay componentes con `measure_basis = 'linear_m'` en `QuoteLineComponents`?
2. ¿Tienen `source = 'configured_component'`?
3. ¿Qué UOM tienen?

---

### **Paso 2: Verificar BomInstanceLines**

```sql
SELECT 
    bil.part_role,
    bil.resolved_sku,
    ci.measure_basis,
    bil.qty,
    bil.uom
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000003'
AND bil.deleted = false
ORDER BY ci.measure_basis, bil.part_role;
```

**Compara:**
- ¿Qué hay en QuoteLineComponents vs BomInstanceLines?
- ¿Faltan componentes lineales?

---

## 🎯 Posibles Causas

### **Causa 1: Componentes no generados en Quote**
- Los componentes lineales pueden no haberse generado cuando se creó el Quote
- Solución: Regenerar QuoteLineComponents para ese Quote

### **Causa 2: UOM incorrecto bloquea generación**
- Si `measure_basis = 'linear_m'` pero `uom = 'ea'`, puede causar problemas
- Solución: Corregir UOM en QuoteLineComponents o normalizar en BOM generation

### **Causa 3: Filtro en función de BOM**
- La función solo copia `source = 'configured_component'`
- Si los componentes lineales tienen otro `source`, no se copian
- Solución: Verificar `source` de los componentes faltantes

---

## ✅ Acción Inmediata

**Ejecuta `QUICK_CHECK_MO_000003.sql` y comparte los resultados** para identificar exactamente qué está pasando.

Los resultados mostrarán:
- ✅ Qué componentes hay en QuoteLineComponents
- ✅ Qué componentes hay en BomInstanceLines
- ✅ Qué `measure_basis` tienen
- ✅ Si los UOM son correctos
- ✅ Qué componentes faltan

---

## 📝 Nota sobre UOM

Según lo conversado, los UOM deberían ser:
- `measure_basis = 'linear_m'` → `uom = 'm'` o `'m2'`
- `measure_basis = 'fabric_wxh'` → `uom = 'm2'`
- `measure_basis = 'unit'` → `uom = 'ea'`

Si hay discrepancias, podemos:
1. Corregir UOM en `QuoteLineComponents`
2. Agregar normalización en `generate_bom_for_manufacturing_order`

---

**¿Puedes ejecutar el diagnóstico y compartir los resultados?**






