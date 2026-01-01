# 📋 Sistema de BOM (Bill of Materials) - Referencia Completa

## ⚠️ IMPORTANTE: NO MODIFICAR ESTE PROCESO SIN REVISAR ESTE DOCUMENTO

Este documento describe cómo funciona el sistema de generación automática de BOM. **NUNCA modificar triggers, funciones o flujos sin entender completamente este proceso.**

---

## 🎯 Flujo Completo de Generación de BOM

### 1. **Creación de QuoteLine** (Frontend: `src/pages/sales/QuoteNew.tsx`)

Cuando se crea un QuoteLine:
- ✅ Se guarda `product_type_id` automáticamente (con múltiples fallbacks)
- ✅ Se llama a `generate_configured_bom_for_quote_line()` para generar `QuoteLineComponents`
- ✅ Los componentes se guardan en `QuoteLineComponents` con `source = 'configured_component'`

**Código crítico:**
```typescript
// Línea ~403: Se guarda product_type_id
product_type_id: productTypeId,

// Línea ~557: Se genera BOM automáticamente
await supabase.rpc('generate_configured_bom_for_quote_line', {
  p_quote_line_id: finalLineId,
  p_product_type_id: productTypeId,
  // ... otros parámetros
});
```

---

### 2. **Aprobación de Quote** (Trigger: `on_quote_approved_create_operational_docs`)

**Migración:** `database/migrations/190_fix_auto_bom_generation.sql`

Cuando un Quote cambia a status `'approved'`:
- ✅ Se crea `SaleOrder` automáticamente
- ✅ Se crean `SaleOrderLines` automáticamente
- ✅ **NUEVO:** Se verifica si existen `QuoteLineComponents`
  - Si NO existen Y hay `product_type_id` → Se generan automáticamente
- ✅ Se crean `BomInstances` automáticamente
- ✅ Se copian `QuoteLineComponents` a `BomInstanceLines`

**Trigger:**
```sql
CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();
```

**Función clave:**
- Verifica `v_qlc_count` (línea ~227)
- Si `v_qlc_count = 0` y hay `product_type_id` → Genera componentes (línea ~234-260)

---

### 3. **Cambio de Status de Sale Order** (Trigger: `on_sale_order_status_changed_generate_bom`)

**Migración:** `database/migrations/191_create_sale_order_status_trigger.sql`

Cuando un Sale Order cambia a status `'confirmed'` o `'in_production'`:
- ✅ Se verifica si existen `QuoteLineComponents`
  - Si NO existen Y hay `product_type_id` → Se generan automáticamente
- ✅ Se crean `BomInstances` si no existen
- ✅ Se copian `QuoteLineComponents` a `BomInstanceLines`

**Trigger:**
```sql
CREATE TRIGGER trg_on_sale_order_status_changed_generate_bom
    AFTER UPDATE OF status ON "SaleOrders"
    FOR EACH ROW
    WHEN (NEW.status IN ('confirmed', 'in_production'))
    EXECUTE FUNCTION public.on_sale_order_status_changed_generate_bom();
```

---

## 🔧 Funciones Críticas

### `generate_configured_bom_for_quote_line()`

**Ubicación:** `database/migrations/188_rebuild_bom_function_clean.sql`

**Propósito:** Genera `QuoteLineComponents` basado en:
- `product_type_id` → Busca `BOMTemplate`
- `BOMTemplate` → Busca `BOMComponents`
- `BOMComponents` → Resuelve `CatalogItems` según `block_condition`
- Crea `QuoteLineComponents` con `source = 'configured_component'`

**Parámetros requeridos:**
- `p_quote_line_id` (UUID)
- `p_product_type_id` (UUID) - **CRÍTICO: Debe existir**
- `p_organization_id` (UUID)
- `p_drive_type`, `p_bottom_rail_type`, `p_cassette`, `p_side_channel`, etc.
- `p_width_m`, `p_height_m`, `p_qty`

**Reglas importantes:**
- ✅ NO incluye fabric en BOMTemplates (se agrega por separado)
- ✅ UOM para fabrics: siempre `'m'`, `'m2'`, `'yd'`, `'yd2'`, `'ft'`, `'ft2'` (NUNCA `'ea'`)
- ✅ Resuelve componentes según `block_condition` y `hardware_color`

---

## 📊 Estructura de Datos

### Tablas Principales

1. **QuoteLines**
   - `product_type_id` (UUID) - **CRÍTICO: Debe existir para generar BOM**
   - `organization_id` (UUID) - **CRÍTICO: Debe existir**
   - `drive_type`, `bottom_rail_type`, `cassette`, `side_channel`, etc.

2. **QuoteLineComponents**
   - `quote_line_id` (UUID) → FK a QuoteLines
   - `catalog_item_id` (UUID) → FK a CatalogItems
   - `source = 'configured_component'` - Identifica componentes generados automáticamente
   - `component_role` - Rol del componente (fabric, tube, bracket, etc.)
   - `uom` - Unidad de medida (debe cumplir constraint `check_quote_line_components_uom_valid`)

3. **BomInstances**
   - `sale_order_line_id` (UUID) → FK a SaleOrderLines
   - `quote_line_id` (UUID) → FK a QuoteLines
   - `bom_template_id` (UUID) → FK a BOMTemplates

4. **BomInstanceLines**
   - `bom_instance_id` (UUID) → FK a BomInstances
   - `resolved_part_id` (UUID) → FK a CatalogItems
   - `part_role` - Rol del componente
   - `qty`, `uom`, `unit_cost_exw`, `total_cost_exw`

5. **SaleOrderMaterialList** (View)
   - Vista que agrega materiales de `BomInstanceLines` por Sale Order
   - Usada por `ApprovedBOMList.tsx` para mostrar BOM en la UI

---

## 🚨 Reglas Críticas - NUNCA VIOLAR

### 1. **product_type_id es OBLIGATORIO**
- ❌ NO crear QuoteLines sin `product_type_id`
- ✅ Siempre buscar `product_type_id` con múltiples fallbacks (código, tipo común, cualquier disponible)
- ✅ Si no se encuentra, mostrar warning pero NO fallar silenciosamente

### 2. **UOM para Fabrics**
- ❌ NUNCA usar `'ea'` para fabrics
- ✅ Solo: `'m'`, `'m2'`, `'yd'`, `'yd2'`, `'ft'`, `'ft2'`
- ✅ Constraint: `check_quote_line_components_uom_valid`

### 3. **component_role válidos**
- ✅ Valores permitidos: `'fabric'`, `'tube'`, `'bracket'`, `'cassette'`, `'bottom_bar'`, `'operating_system_drive'`, `'bottom_rail_profile'`, `'bottom_rail_end_cap'`, `'side_channel_profile'`, `'side_channel_cover'`, `'motor_crown'`, `'motor_drive'`, `'cassette_profile'`, `'cassette_end_cap'`, `'accessory'`, `'insert'`, `'gasket'`
- ✅ Constraint: `check_component_role_valid`

### 4. **Generación Automática**
- ✅ Al crear QuoteLine → Generar `QuoteLineComponents` si hay `product_type_id`
- ✅ Al aprobar Quote → Verificar y generar `QuoteLineComponents` si no existen
- ✅ Al cambiar Sale Order a `'confirmed'` o `'in_production'` → Verificar y generar BOM si no existe

### 5. **BOMTemplates**
- ❌ NO incluir fabric en BOMTemplates
- ✅ Fabric se agrega por separado en `QuoteLineComponents`
- ✅ BOMTemplates solo definen estructura y fórmulas de cantidad

---

## 🔍 Diagnóstico de Problemas

### Si un Sale Order no tiene BOM:

1. **Verificar product_type_id:**
   ```sql
   SELECT ql.id, ql.product_type_id, pt.name
   FROM "QuoteLines" ql
   LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
   WHERE ql.id = 'quote_line_id';
   ```

2. **Verificar QuoteLineComponents:**
   ```sql
   SELECT COUNT(*) 
   FROM "QuoteLineComponents"
   WHERE quote_line_id = 'quote_line_id'
     AND source = 'configured_component'
     AND deleted = false;
   ```

3. **Verificar BomInstances:**
   ```sql
   SELECT bi.id, bi.sale_order_line_id
   FROM "BomInstances" bi
   INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
   WHERE sol.sale_order_id = 'sale_order_id';
   ```

4. **Verificar triggers activos:**
   ```sql
   SELECT trigger_name, event_manipulation, action_timing
   FROM information_schema.triggers
   WHERE event_object_table = 'Quotes' OR event_object_table = 'SaleOrders';
   ```

---

## 📝 Scripts de Corrección

### Para corregir QuoteLines sin product_type_id:
- `FIX_MISSING_PRODUCT_TYPE_ID_AUTOMATIC.sql`

### Para corregir Sale Orders sin BOM:
- `FIX_AUTO_BOM_GENERATION_COMPLETE.sql`
- `FIX_SO_014_015_SPECIFIC.sql` (para casos específicos)

### Para diagnosticar:
- `DIAGNOSE_AUTO_BOM_GENERATION.sql`
- `VERIFY_AND_FIX_FUNCTION_AUTO_BOM.sql`

---

## ✅ Checklist Antes de Modificar Cualquier Código Relacionado con BOM

- [ ] ¿Entiendo cómo funciona `generate_configured_bom_for_quote_line()`?
- [ ] ¿Entiendo los triggers `on_quote_approved_create_operational_docs` y `on_sale_order_status_changed_generate_bom`?
- [ ] ¿He verificado que `product_type_id` siempre se guarde correctamente?
- [ ] ¿He verificado que los UOM para fabrics sean correctos?
- [ ] ¿He verificado que los `component_role` sean válidos?
- [ ] ¿He probado el flujo completo: crear Quote → aprobar → verificar BOM?
- [ ] ¿He revisado este documento de referencia?

---

## 🎯 Resumen Ejecutivo

**El sistema de BOM funciona en 3 niveles:**

1. **Frontend (QuoteNew.tsx):** Guarda `product_type_id` y genera `QuoteLineComponents` al crear QuoteLine
2. **Trigger en Quote Approval:** Genera `QuoteLineComponents` si no existen cuando se aprueba Quote
3. **Trigger en Sale Order Status:** Genera BOM completo cuando Sale Order cambia a `'confirmed'` o `'in_production'`

**Regla de oro:** Si un Sale Order no tiene BOM, siempre verificar:
1. ¿Tiene `product_type_id`?
2. ¿Tiene `QuoteLineComponents`?
3. ¿Tiene `BomInstances` y `BomInstanceLines`?

---

**Última actualización:** 2024-12-21
**Mantenido por:** Sistema de referencia para evitar romper el flujo de BOM








