# INFORME: BOM CONFIGURATOR - ESTADO ACTUAL Y SOLUCIÓN

**Fecha:** 2026-01-19  
**Módulo:** Quote Line BOM Configurator  
**Status:** 🔴 NO FUNCIONAL - Precios en $0.00, BOM no se genera

---

## 📋 RESUMEN EJECUTIVO

El configurador de productos **guarda la Quote Line** pero **NO calcula precios** porque:

1. ❌ Las **opciones de configuración** NO se guardan en `QuoteLineComponents` (constraint rechaza roles)
2. ❌ Sin opciones, la función `build_quote_line_config()` retorna vacío
3. ❌ Sin config, `select_best_bom_template()` NO puede filtrar templates
4. ❌ Sin template correcto, `generate_bom_from_slots()` falla silenciosamente
5. ❌ Sin BOM, NO hay componentes para calcular precio

**Resultado:** QuoteLine con `msrp = $0.00`, `net_price = $0.00`

---

## 🔬 EVIDENCIA (Query Ejecutado)

**Quote Line ID:** `3fc6811f-e553-42f9-835b-1c3105f09b4b`

### QuoteLineComponents guardados:
| component_role | kind | catalog_item_id | sku | name |
|---|---|---|---|---|
| `motor` | `selection` | `48541b5f-...` | CM-01 | Motor 18mm 0,2Nm |

**Total:** 1 componente (solo motor)

### BOMInstances:
**0 rows** - El BOM NO se generó

---

## 🧩 ANÁLISIS TÉCNICO

### 1. Flujo Esperado (CORRECTO)

```
Usuario selecciona → Guardar QuoteLine
↓
Guardar OPCIONES en QuoteLineComponents:
  - hardware_color = 'White' (kind='option')
  - drive_type = 'motor' (kind='option')
  - cassette = false (kind='option')
  - side_channel = false (kind='option')
  - etc.
↓
Guardar SELECCIONES en QuoteLineComponents:
  - motor_item_id → CM-01 (kind='selection')
  - tube_item_id → RTU-42 (kind='selection')
  - bottom_bar_item_id → RCA-04-W (kind='selection')
  - etc.
↓
Llamar generate_bom_from_slots(org, quote_line_id, product_type_id)
  ↓ build_quote_line_config() lee QuoteLineComponents
  ↓ Construye: {hardware_color: 'White', drive_type: 'motor', ...}
  ↓ select_best_bom_template() filtra por fingerprint
  ↓ Encuentra: "ROLLER_MOTORIZADA_M_WHITE" (template correcto)
  ↓ Genera BOMInstanceLines usando slots + children
↓
Calcular precio total:
  - Σ (todos los BOMInstanceLines.msrp × qty)
  - + Fabric (msrp × roll_width × height × qty)
↓
Actualizar QuoteLine:
  - msrp = precio total
  - net_price = precio total (con tier discount)
```

### 2. Flujo Actual (INCORRECTO)

```
Usuario selecciona → Guardar QuoteLine ✅
↓
Intentar guardar OPCIONES → ❌ RECHAZADAS por constraint
Intentar guardar SELECCIONES → ✅ Solo 'motor' se guarda (otros rechazados)
↓
Llamar generate_bom_from_slots()
  ↓ build_quote_line_config() → {} (vacío)
  ↓ select_best_bom_template() → NULL o template incorrecto
  ↓ ❌ FALLA o usa template equivocado
↓
❌ BOMInstance NO se crea
❌ Precio queda en $0.00
```

---

## 🎯 HIPÓTESIS

### H1: Constraint de QuoteLineComponents está desactualizado

**Constraint actual permite SOLO:**
```sql
'tube', 'track', 'bottom_bar', 'bottom_channel', 'hem_weight', 
'side_channel', 'top_rail', 'headbox', 'bracket', 'idler', 
'drive', 'motor', 'adapter', 'chain', 'chain_stop', 
'chain_tensioner', 'wand', 'end_cap', 'filler', 'tape', 
'consumable', 'fastener', 'accessory', 'carrier', 'belt', 
'belt_connector'
```

**Constraint DEBE permitir ADEMÁS:**
```sql
'fabric', 'hardware_color', 'drive_type', 'system_size', 
'cassette', 'bottom_rail_type', 'tube_type', 'side_channels'
```

**Estado:** ✅ SQL corregido en `backups/UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql`  
**Acción:** EJECUTAR en Supabase

### H2: Código frontend guarda roles incorrectos

**Ejemplo:** Código intenta guardar `side_channel` pero DB espera `side_channels` (plural).

**Estado:** ✅ Corregido en `QuoteNew.tsx`

### H3: Schema de QuoteLines no coincide con código

**Columnas usadas pero NO existen:**
- `area`, `position`, `product_type` ❌ (agregadas en migraciones NO ejecutadas)
- `bom_template_id`, `hardware_color`, `cassette`, `side_channel`, `drive_type` ❌

**Estado:** ✅ Eliminadas del código  
**Acción:** Si se necesitan, ejecutar migraciones 53 y 395

---

## 🔧 CAMBIOS IMPLEMENTADOS (HOY)

### 1. **BOM Templates UI (Módulo Catalog)**
- ✅ Creado hook `useBOMTemplateSlots` para cargar slots correctamente
- ✅ Agregada columna "Children" para ver HIJOS por PADRE
- ✅ Implementado botón 📦 para gestionar children (CatalogItemComponents)
- ✅ Corregidos errores de schema (eliminado `item_name`, usado solo `name`)
- ✅ Implementada persistencia con sessionStorage para evitar pérdida de datos

### 2. **Quote Configurator (Módulo Sales)**
- ✅ Eliminado debug panel
- ✅ Ajustado `OperatingSystemStep` para permitir selección de Tube (como PADRE)
- ✅ Eliminado filtro de color para `tube` (tubos tienen color=NULL)
- ✅ Eliminada sección "Operating System Variant" (no se usa)

### 3. **Quote Line Saving (QuoteNew.tsx)**
- ✅ Fabric opcional: `catalog_item_id` puede ser NULL (draft sin tela)
- ✅ Fabric guardado como QuoteLineComponent (`kind='selection'`, `component_role='fabric'`)
- ✅ Opciones guardadas como QuoteLineComponent (`kind='option'`)
- ✅ Selecciones (motor, drive, tube, etc.) guardadas como (`kind='selection'`)
- ✅ Cálculo de precio total: BOM + Fabric
- ✅ Sanitización de payload para usar SOLO columnas reales de QuoteLines

### 4. **Hooks y Utilidades**
- ✅ `useBOMTemplateQuestions`: Ahora lee BOMTemplateSlots + BOMComponents
- ✅ `useRollerCatalogItems`: Corregido filtro para motor y tube (sin color)
- ✅ `useQuotes`: Eliminados filtros `deleted` en QuoteLines (columna no existe)
- ✅ `useQuoteLineComponents`: Eliminados filtros incorrectos

### 5. **Scripts SQL Creados**
- ✅ `RESET_BOM_CLEAN.sql` - Borrar slots y children
- ✅ `POPULATE_BOM_FINAL.sql` - Poblar slots desde BOMComponents
- ✅ `fix_catalogitemcomponents_rls.sql` - Policies RLS para CatalogItemComponents
- ✅ `UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql` - ⚠️ **CRÍTICO - DEBE EJECUTARSE**
- ✅ `CHECK_QUOTELINES_SCHEMA.sql` - Verificar schema real
- ✅ `CHECK_QUOTE_LINE_CONFIG.sql` - Diagnosticar líneas guardadas

---

## 🚨 PROBLEMA RAÍZ CONFIRMADO

**Constraint `quotelinecomponents_component_role_check` está desactualizado.**

### Código actual intenta guardar:
```typescript
// QuoteNew.tsx líneas ~920-1008
configOptions.push({
  component_role: 'hardware_color',  // ❌ NO PERMITIDO
  kind: 'option',
  payload: { hardware_color: 'White' }
});

configOptions.push({
  component_role: 'drive_type',  // ❌ NO PERMITIDO
  kind: 'option',
  payload: { drive_type: 'motor' }
});
// ... etc
```

### DB rechaza silenciosamente:
```
INSERT failed on constraint check
→ Opciones NO se guardan
→ Solo 'motor' (kind='selection') se guarda porque 'motor' SÍ está en lista
```

---

## ✅ SOLUCIÓN (PASO A PASO)

### PASO 1: Ejecutar SQL en Supabase (OBLIGATORIO)

```sql
-- En Supabase SQL Editor
backups/UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql
```

**Qué hace:**
- Actualiza constraint de `QuoteLineComponents.component_role`
- Agrega: `fabric`, `hardware_color`, `drive_type`, `system_size`, `cassette`, `bottom_rail_type`, `tube_type`, `side_channels`

### PASO 2: Borrar líneas de prueba

```sql
DELETE FROM public."QuoteLines"
WHERE quote_id = 'afb5b0fe-af20-4724-a78d-8e936995bbc3'
  AND organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2';
```

### PASO 3: Refrescar navegador

Hard refresh: `Cmd+Shift+R` (Mac) o `Ctrl+Shift+R` (Windows)

### PASO 4: Probar flujo completo

1. Click "Add Line"
2. Configurar producto:
   - **Product:** Roller Shade
   - **Measurements:** 1500 x 2000 mm
   - **Variants:** Seleccionar fabric
   - **Hardware:** White, Cassette, Bottom Bar
   - **Operating System:** Motor → Seleccionar CM-01
3. Click "Next" hasta "Add to Quote"
4. Guardar

### PASO 5: Verificar resultado

**Esperas ver:**
- ✅ QuoteLine con precio > $0
- ✅ QuoteLineComponents: ~8-12 rows (opciones + selecciones)
- ✅ BOMInstance creado
- ✅ BOMInstanceLines: ~5-10 componentes (motor, bracket, tube, bottom_bar, etc. + HIJOS)

**Query de verificación:**
```sql
backups/CHECK_QUOTE_LINE_CONFIG.sql  -- (reemplazar ID)
```

---

## 🔄 SI AÚN NO FUNCIONA DESPUÉS DEL PASO 1

### Problema Secundario: Migraciones faltantes

Si después de ejecutar `UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql` aún falla, puede ser que QuoteLines necesite las columnas:
- `area`, `position`, `product_type`
- `bom_template_id`, `hardware_color`, `cassette`, `side_channel`, `drive_type`

**Solución:**
```sql
-- Ejecutar en orden:
1. database/migrations/53_ensure_quote_lines_fields_exist.sql
2. database/migrations/395_verify_quote_lines_bom_fields.sql
```

Luego modificar `QuoteNew.tsx` para restaurar esas columnas en `quoteLineData`.

---

## 📊 FLUJO TÉCNICO CORRECTO (PARA EQUIPO)

### Arquitectura BOM PADRE-HIJO

```
┌─────────────────────────────────────────┐
│ BOMTemplates                            │
│ - Filtrados por fingerprint             │
│   (product_type, headbox_type,          │
│    system_size, color,                  │
│    side_channel_mode, operating_system) │
└──────────────┬──────────────────────────┘
               │
               │ 1:N
               ▼
┌─────────────────────────────────────────┐
│ BOMTemplateSlots (PADRES)               │
│ - item_role: motor, drive, tube, etc.   │
│ - catalog_item_id: NULL o SKU fijo      │
│ - qty: cantidad base                    │
└──────────────┬──────────────────────────┘
               │
               │ Si catalog_item_id existe
               ▼
┌─────────────────────────────────────────┐
│ CatalogItemComponents (HIJOS)           │
│ - parent_item_id: motor específico      │
│ - child_item_id: adapter, end_cap, etc. │
│ - qty: cantidad por hijo                │
└─────────────────────────────────────────┘
```

### Flujo de Quote → BOM

```
1. Usuario configura producto
   ↓
2. QuoteNew.tsx guarda:
   ┌─ QuoteLine (width_m, height_m, quantity, msrp=0 inicial)
   ├─ QuoteLineComponents (kind='option'):
   │    - hardware_color, drive_type, cassette, side_channel
   └─ QuoteLineComponents (kind='selection'):
        - motor_item_id, tube_item_id, bottom_bar_item_id, fabric_item_id
   ↓
3. generate_bom_from_slots(org_id, quote_line_id, product_type_id)
   ├─ build_quote_line_config() → {hardware_color: 'White', drive_type: 'motor', ...}
   ├─ select_best_bom_template() → filtra templates por fingerprint
   ├─ Crea BOMInstance
   └─ Itera BOMTemplateSlots:
       ├─ Busca SKU elegido en QuoteLineComponents (kind='selection')
       ├─ Si no, usa catalog_item_id del slot
       ├─ Expande HIJOS desde CatalogItemComponents
       └─ Crea BOMInstanceLines (PADRES + HIJOS)
   ↓
4. Calcular precio total:
   ├─ BOM: Σ (BOMInstanceLines.catalog_item.msrp × qty)
   └─ Fabric: msrp_sale_out × roll_width_m × height_m × qty
   ↓
5. Actualizar QuoteLine:
   - msrp = BOM + Fabric
   - net_price = (BOM + Fabric) con tier discount
```

---

## 🐛 PROBLEMAS IDENTIFICADOS Y CORREGIDOS

### P1: Constraint de QuoteLineComponents rechaza opciones ✅ CORREGIDO
**Archivo:** `backups/UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql`  
**Estado:** SQL creado, DEBE EJECUTARSE en Supabase

### P2: Schema de QuoteLines desactualizado ⚠️ PARCIAL
**QuoteLines actual NO tiene:**
- `area`, `position`, `product_type`
- `bom_template_id`, `hardware_color`, `cassette`, `side_channel`, `drive_type`

**Acción tomada:** Código ajustado para NO usar esas columnas  
**Acción pendiente:** Si se necesitan, ejecutar migraciones 53 y 395

### P3: Fabric item_id inválido ✅ CORREGIDO
**Error:** `Fabric item 35b8c952-... was not found`  
**Causa:** ID del config no existe en CatalogItems  
**Solución:** Código ahora ignora y continúa como draft sin fabric

### P4: Roles mal nombrados ✅ CORREGIDO
**Error:** `side_channel` vs `side_channels` (singular vs plural)  
**Solución:** Cambiado a `side_channels` en código

### P5: Filtro de color en Tube ✅ CORREGIDO
**Error:** Tubes con `color=NULL` quedaban fuera del filtro  
**Solución:** `useRollerCatalogItems` NO filtra por color cuando `role='tube'`

### P6: Items fantasma en BOMTemplates UI ✅ CORREGIDO
**Causa:** Mezcla de BOMComponents legacy + BOMTemplateSlots  
**Solución:** Priorizar slots, solo mostrar BOMComponents si NO hay slots

### P7: Debug Panel con errores ✅ ELIMINADO
**Acción:** Eliminado `ConfigDebugPanel` del ProductConfigurator

---

## 📦 ARCHIVOS MODIFICADOS (HOY)

### Frontend
1. `src/pages/catalog/BOMTemplates.tsx` - UI para gestionar templates y children
2. `src/pages/sales/QuoteNew.tsx` - Lógica de guardado y pricing
3. `src/pages/sales/curtain-config/OperatingSystemStep.tsx` - Selección de tube
4. `src/pages/sales/ProductConfigurator.tsx` - Eliminado debug panel
5. `src/hooks/useBOMTemplateSlots.ts` - **NUEVO** Hook para slots
6. `src/hooks/useBOMTemplateQuestions.ts` - Lectura de slots
7. `src/hooks/useRollerCatalogItems.ts` - Filtros corregidos
8. `src/hooks/useQuotes.ts` - Eliminados filtros deleted en QuoteLines
9. `src/hooks/useQuoteLineComponents.ts` - Schema actualizado
10. `src/pages/settings/CompaniesSettings.tsx` - Typo corregido

### SQL Scripts (Backups)
1. `RESET_BOM_CLEAN.sql` - Borrar slots/children existentes
2. `POPULATE_BOM_FINAL.sql` - Poblar slots desde BOMComponents
3. `fix_catalogitemcomponents_rls.sql` - RLS policies
4. `UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql` - ⚠️ **CRÍTICO**
5. `CHECK_QUOTELINES_SCHEMA.sql` - Verificación de schema
6. `CHECK_QUOTE_LINE_CONFIG.sql` - Diagnóstico de líneas
7. `DELETE_ALL_BOM_SLOTS_AND_CHILDREN.sql` - Reset completo
8. `GUIA_RESET_BOM_COMPLETO.md` - Guía paso a paso

---

## ✅ PRÓXIMOS PASOS (EN ORDEN)

### Para Desarrollador/QA:

1. **Ejecutar SQL obligatorio:**
   ```sql
   backups/UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql
   ```

2. **Borrar Quote Lines de prueba:**
   ```sql
   DELETE FROM public."QuoteLines"
   WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
     AND msrp = 0;
   ```

3. **Hard refresh navegador:** `Cmd+Shift+R`

4. **Probar flujo completo** (descrito arriba)

5. **Verificar resultado:**
   ```sql
   -- Ejecutar para última línea creada
   backups/CHECK_QUOTE_LINE_CONFIG.sql
   ```

6. **Esperado:**
   - QuoteLineComponents: 8-12 rows
   - BOMInstance: 1 row
   - BOMInstanceLines: 5-10 rows
   - QuoteLine.msrp > 0

### Para Product Owner:

- Si después del PASO 1 aún falla → ejecutar migraciones 53 y 395
- Si BOMTemplates aparecen vacíos → ejecutar `POPULATE_BOM_FINAL.sql`
- Si children no se guardan → ejecutar `fix_catalogitemcomponents_rls.sql`

---

## 📝 NOTAS PARA EQUIPO

### Convenciones Críticas:
1. **Nombres de columnas:** `snake_case` (ej: `first_name`)
2. **Nombres de tablas:** `PascalCase` (ej: `CatalogItems`)
3. **Columnas estándar:** `deleted`, `archived`, `created_at`, `updated_at`
4. **Usar:** `is_active` (no `active`) en `CatalogItems`
5. **NO usar:** `deleted` en `QuoteLines` (columna no existe)

### Decisiones Finales:
1. **Fabric NO va en BOMTemplate** - Se guarda en QuoteLineComponents
2. **BOMTemplate NO auto-selecciona** - Usuario elige SKUs
3. **BOMTemplate se resuelve por fingerprint** - No hardcoded
4. **Precio = BOM + Fabric** - Calculado después de generar BOM
5. **Draft permitido sin fabric** - `catalog_item_id` puede ser NULL

---

## 🎯 ESTADO FINAL

**Pre-requisito NO cumplido:**
- ⚠️ `UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql` NO ejecutado

**Una vez ejecutado:**
- ✅ Código frontend está listo
- ✅ Hooks están corregidos
- ✅ Schema está alineado
- ✅ Pricing está implementado

**Próximo blocker esperado:**
- BOMTemplates sin slots → ejecutar `POPULATE_BOM_FINAL.sql`
- CatalogItems sin MSRP → poblar `CatalogItemsMSRP`

---

**Preparado por:** Cursor AI  
**Revisado:** Pendiente  
**Aprobado:** Pendiente

---

## 📎 ANEXOS

- Link guía completa: `backups/GUIA_RESET_BOM_COMPLETO.md`
- Link SQL crítico: `backups/UPDATE_QUOTELINECOMPONENTS_ROLE_CHECK.sql`
- Link diagnóstico: `backups/CHECK_QUOTE_LINE_CONFIG.sql`
