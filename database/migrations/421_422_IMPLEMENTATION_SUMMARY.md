# 🎯 Resumen de Implementación: BOM Fabric, UOM y Reset

## ✅ Cambios Implementados

### 1. **Nuevas Funciones Helper (Migración 421)**

#### `normalize_uom_to_canonical(p_uom, p_role, p_qty_type)`
- Normaliza UOM a valores canónicos: `m`, `m2`, `ea`
- Conversiones:
  - `ft`, `foot`, `feet` → `m`
  - `pcs`, `pc`, `piece`, `set` → `ea`
  - `m2`, `sqm` → `m2`
- Usa `role` y `qty_type` para inferir UOM si es desconocido

#### `convert_qty_by_uom(p_qty, p_uom_original, p_uom_canonical)`
- Convierte cantidades cuando cambia el UOM:
  - `ft` → `m`: multiplica por `0.3048`
  - `mm` → `m`: divide por `1000.0`
  - `pcs`/`set` → `ea`: sin conversión (1:1)

#### `reset_bom_for_manufacturing_order(p_manufacturing_order_id)`
- Soft-delete de todos los `BomInstances` y `BomInstanceLines` para un MO
- Retorna JSON con conteos de eliminados
- **NO** borra físicamente, solo marca `deleted = true`

### 2. **Mejoras en `generate_bom_for_manufacturing_order` (Migración 405 actualizada)**

#### Resolución de Fabric Mejorada (SO-Driven)
- **Prioridad 1:** `QuoteLineComponents` con `role='fabric'`
- **Prioridad 2:** `ConfiguredProduct.fabric_catalog_item_id`
- **Prioridad 3:** Match por `collection_name`/`variant_name` desde `QuoteLine`
- **Prioridad 4:** Auto-select del template (fallback)

#### Normalización de UOM en TODOS los INSERTs
- **QuoteLineComponents INSERT:** Normaliza UOM y convierte qty
- **Auto-Select INSERT:** Normaliza UOM y convierte qty
- **Assembly Children INSERT:** Normaliza UOM y convierte qty

#### Conversión de Cantidades
- Aplica `convert_qty_by_uom()` cuando el UOM cambia
- Ejemplo: `qty_ft = 10` → `qty_m = 3.048` (10 × 0.3048)

### 3. **Actualización de UI (MaterialsTab.tsx)**

#### Flujo de "Generate BOM"
1. **Paso 1:** Llama `reset_bom_for_manufacturing_order(mo_id)` para borrar BOMs viejos
2. **Paso 2:** Llama `generate_bom_for_manufacturing_order(mo_id)` para crear nuevo BOM
3. **Paso 3:** Refetch de materials y monitoring

### 4. **useBOMMonitoring ya actualizado**
- Ordena por `generated_at DESC, created_at DESC`
- Selecciona el BOM más reciente correctamente

---

## 📋 Pasos de Ejecución

### PASO 1: Ejecutar Migración 421
```sql
-- Ejecutar: database/migrations/421_fix_bom_fabric_uom_and_reset.sql
-- Esto crea las funciones helper y reset_bom_for_manufacturing_order
```

### PASO 2: Actualizar generate_bom_for_manufacturing_order
```sql
-- Ejecutar la función COMPLETA desde: database/migrations/405_fix_bom_instances_rls_and_return_counts.sql
-- Busca: CREATE OR REPLACE FUNCTION generate_bom_for_manufacturing_order
-- Copia TODO hasta el $$; final
```

### PASO 3: Verificar Funciones
```sql
-- Verificar que las funciones existen
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'normalize_uom_to_canonical',
    'convert_qty_by_uom',
    'reset_bom_for_manufacturing_order'
);
-- Debería devolver 3 filas
```

### PASO 4: Probar Reset
```sql
-- Obtener un manufacturing_order_id
SELECT id FROM "ManufacturingOrders" WHERE deleted = false LIMIT 1;

-- Probar reset (reemplaza el UUID)
SELECT public.reset_bom_for_manufacturing_order('TU-MO-ID-AQUI'::uuid);
-- Debería devolver JSON con deleted_instances y deleted_lines
```

### PASO 5: Regenerar BOM desde UI
1. Ve a Manufacturing Orders
2. Selecciona un MO
3. Click en "Generate BOM"
4. Verifica que:
   - El fabric coincide con el Sales Order
   - Los UOMs son solo `m`, `m2`, `ea`
   - Se crea un nuevo `bom_instance_id`

### PASO 6: Ejecutar Queries de Verificación
```sql
-- Ejecutar: database/migrations/QUERY_VERIFY_BOM_FABRIC_UOM_FIXES.sql
-- Query 1: Verificar fabric matches (debería mostrar ✅ MATCH)
-- Query 2: Verificar UOM normalization (solo m, m2, ea)
-- Query 3: Verificar no hay UOMs no normalizados (debería ser 0)
-- Query 4: Verificar conversiones de cantidad
-- Query 5: Verificar latest BOM selection
-- Query 6: Análisis de resolución de fabric
```

---

## 🎯 Criterios de Aceptación

### ✅ Fabric Resolution
- [ ] Para un SO line con Collection "Screen 3001 - beige pearl grey", el BOM fabric debe ser exactamente esa misma tela
- [ ] Query 1 muestra `✅ MATCH` para todos los casos
- [ ] Query 6 muestra el path de resolución correcto

### ✅ UOM Normalization
- [ ] Query 2 muestra SOLO `m`, `m2`, `ea` (0 filas con otros UOMs)
- [ ] Query 3 devuelve 0 filas (no hay UOMs no normalizados)
- [ ] No aparece `ft`, `pcs`, `set` en la UI

### ✅ Reset y Regeneración
- [ ] Al hacer "Generate BOM", se borran los BOMs viejos (soft-delete)
- [ ] Se crea un nuevo `bom_instance_id`
- [ ] El monitor muestra el BOM más reciente
- [ ] Query 5 muestra `✅ SINGLE BOM` o `⚠️ MULTIPLE BOMs` (si hay múltiples, reset debería limpiarlos)

---

## 🔍 Troubleshooting

### Problema: Fabric no coincide
**Solución:**
1. Ejecuta Query 6 para ver qué path de resolución se usó
2. Verifica que `QuoteLine.collection_name` o `variant_name` estén correctos
3. Verifica que existe un `CatalogItem` con ese `collection_name`/`variant_name` y `category_code='FABRIC'`

### Problema: UOMs no normalizados
**Solución:**
1. Ejecuta Query 3 para ver qué UOMs quedan
2. Si hay UOMs viejos, ejecuta la migración 418: `418_normalize_existing_bom_uom.sql`
3. Regenera el BOM desde la UI

### Problema: Múltiples BOMs para el mismo SOL
**Solución:**
1. Ejecuta Query 5 para ver cuántos BOMs hay
2. Si hay múltiples, el botón "Generate BOM" debería hacer reset primero
3. Verifica que `reset_bom_for_manufacturing_order` se está llamando correctamente

---

## 📝 Archivos Modificados

1. **database/migrations/421_fix_bom_fabric_uom_and_reset.sql** (NUEVO)
   - Funciones helper de UOM
   - Función `reset_bom_for_manufacturing_order`

2. **database/migrations/405_fix_bom_instances_rls_and_return_counts.sql** (ACTUALIZADO)
   - Mejora en resolución de fabric
   - Normalización de UOM en todos los INSERTs
   - Conversión de cantidades

3. **src/components/manufacturing/tabs/MaterialsTab.tsx** (ACTUALIZADO)
   - Llama `reset_bom_for_manufacturing_order` antes de `generate_bom_for_manufacturing_order`

4. **database/migrations/QUERY_VERIFY_BOM_FABRIC_UOM_FIXES.sql** (NUEVO)
   - 6 queries de verificación

---

## ✅ Estado Final

- ✅ Función `reset_bom_for_manufacturing_order` creada
- ✅ Resolución de fabric mejorada (SO-driven)
- ✅ Normalización de UOM implementada
- ✅ Conversión de cantidades implementada
- ✅ UI actualizada para reset + generate
- ✅ Queries de verificación creados

**Próximo paso:** Ejecutar las migraciones y probar desde la UI.


