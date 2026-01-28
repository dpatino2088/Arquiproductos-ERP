# DEBUG: Template Selection Not Working

## Síntoma
- Usuario selecciona Bottom Bar, Headbox, Motor, Tube
- Debug muestra "Template Found: 0 template(s) found"
- "BOM Template ID: Not resolved"

## Qué revisar

### 1. Logs de consola necesarios
Buscar en orden:

```
[ProductConfigurator] Templates pipeline
[useBOMTemplates] Base templates (after structural filters)
[useBOMTemplates] 🔍 Starting SKU-based filtering
[useBOMTemplates] 🔍 Checking operation_type filter
[useBOMTemplates] ❌ Template XXX filtered out
[useBOMTemplates] Filtered templates (after selections)
```

### 2. Verificar que SKUs lleguen al filtro

**En ProductConfigurator:**
```
[ProductConfigurator] bottom bar selection
  - resolvedSku: "RCA-04-W" ✅ o undefined ❌
  - motor_sku: "CM-09-OC100" ✅ o null ❌
  - drive_sku: null (correcto si es motor)
```

**En useBOMTemplates:**
```
[useBOMTemplates] 🔍 Starting SKU-based filtering
  filters: {
    operation_type: "motor",
    motor_sku: "CM-09-OC100",
    bottom_bar_sku: "RCA-04-W",
    tube_sku: "RTU-42",
    headbox_sku: "RC-2053-W" o null
  }
```

### 3. Puntos donde se puede perder

#### A) operation_type elimina todos
```
❌ Template XXX filtered out - has drive role but operation_type is 'motor'
```
**Causa:** Template tiene slots de drive Y motor (no debe pasar)
**Fix:** Revisar que templates tengan SOLO motor slots (no drive)

#### B) motor_sku no coincide
```
❌ Template XXX filtered out - missing motor SKU: "CM-09-OC100"
```
**Causa:** El SKU del slot no coincide exactamente
**Fix:** 
- Verificar que `BOMTemplateSlots` tenga ese SKU exacto
- Verificar que `item_role` sea exactamente "motor" (no "motor_family")

#### C) bottom_bar_sku no coincide
```
❌ Template XXX filtered out - missing bottom_bar SKU: "RCA-04-W"
```
**Causa:** Similar a motor

#### D) tube_sku no coincide
```
❌ Template XXX filtered out - missing tube SKU: "RTU-42"
```

### 4. Query de diagnóstico SQL

```sql
-- Ver slots del template candidato
SELECT 
  bts.id,
  bts.bom_template_id,
  bts.item_role,
  bts.catalog_item_id,
  ci.sku,
  ci.name,
  ci.is_active
FROM "BOMTemplateSlots" bts
LEFT JOIN "CatalogItems" ci ON ci.id = bts.catalog_item_id
WHERE bts.bom_template_id = 'TEMPLATE_ID_AQUI'
  AND bts.organization_id = 'ORG_ID'
ORDER BY bts.item_role;

-- Buscar templates que SÍ tengan el motor SKU
SELECT DISTINCT
  bt.id,
  bt.name,
  bt.hardware_color,
  bt.product_type_id
FROM "BOMTemplates" bt
JOIN "BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
JOIN "CatalogItems" ci ON ci.id = bts.catalog_item_id
WHERE bt.organization_id = 'ORG_ID'
  AND bt.product_type_id = 'PRODUCT_TYPE_ID'
  AND bt.hardware_color = 'White'
  AND bts.item_role = 'motor'
  AND ci.sku = 'CM-09-OC100'
  AND ci.is_active = true;
```

### 5. Fix más probable

**Si el problema es que `motor_sku` está null aunque seleccionaste motor:**

En `OperatingSystemStep.tsx`, verificar que `handleMotorSelect` esté guardando el SKU:

```typescript
const handleMotorSelect = (itemId: string, itemName: string, itemSku: string) => {
  console.log('[OperatingSystemStep] Motor selected', { itemId, itemSku }); // ✅ Log
  onUpdate({
    motor_item_id: itemId,
    motor_sku: itemSku, // ✅ CRITICAL
    motor_family: itemName,
    drive_item_id: undefined,
    drive_sku: null,
  } as any);
};
```

**Si el problema es que los roles en slots son distintos:**

Ejemplo: Si en DB el role es `motorized` pero buscamos `motor`:
- Agregar mapping en `normalizeRole` o usar `ilike` en query de slots

## Acción inmediata

1. Abrir DevTools Console
2. Filtrar por `[useBOMTemplates]`
3. Buscar líneas con "❌ Template XXX filtered out"
4. Compartir ESA línea exacta para fix específico
