# Implementación: Editar y Duplicar Quote Lines

Este documento describe en detalle los cambios realizados para implementar **EDIT** (misma QuoteLine + nuevo ConfiguredProduct al guardar) y **DUPLICAR** (abrir configurador en modo Add con config prellenado desde una línea existente).

---

## 1. Objetivo y patrón

| Flujo | Comportamiento |
|-------|----------------|
| **ADD** (ya existía) | Durante el configurador se llama `create_configured_product_and_bom_preview` → se obtiene un ConfiguredProduct. Al guardar, `commitConfiguredProductToQuoteLine()` invoca la RPC `commit_configured_product_to_quote_line`, que crea la QuoteLine y el BOMInstance. |
| **EDIT** (nuevo) | Misma QuoteLine; al guardar se crea un **ConfiguredProduct nuevo (CP_NEW)** con el estado actual del formulario, se actualiza la QuoteLine con `configured_product_id = CP_NEW` y dimensiones/totales, y se sincronizan accesorios. No se crea CP al abrir Edit, solo al guardar. |
| **DUPLICAR** (nuevo) | Se carga el config de una línea existente (QuoteLine + ConfiguredProduct.config_snapshot), se abre el configurador en modo **Add** (sin `editingLineId`) con ese config como `initialLineConfig`. Al guardar se usa el flujo ADD (nuevo CP + RPC commit). |

---

## 2. Archivos creados

### 2.1 `src/lib/quotes/getConfigFromQuoteLine.ts`

**Propósito:** Función pura que, dado un `lineId`, devuelve un `ProductConfig` listo para abrir el configurador (Edit o Duplicar), sin tocar estado de React.

**Firma:**

```ts
export interface GetConfigFromQuoteLineParams {
  supabase: SupabaseClient;
  organizationId: string;
  lineId: string;
  forEdit?: boolean;  // true = incluye quote_line_id (Edit); false = no (Duplicar)
}

export async function getConfigFromQuoteLine(params): Promise<ProductConfig | null>
```

**Comportamiento:**

1. **Carga QuoteLine** por `id` y `organization_id`.
2. **Carga CatalogItem** si la línea tiene `catalog_item_id`.
3. **Carga ProductType** (por `product_type_id` o por `product_type` string).
4. **Carga accesorios** desde `QuoteLineComponents` (source/component_role = accessory) y sus CatalogItems.
5. **Construye el config** según tipo de producto (roller-shade, dual-shade, etc.) con: productTypeId, area, position, quantity, width_mm, height_mm, variantId, collectionName, variantName, drive_type, hardware_color, accessories, etc.
6. Si la línea tiene **`configured_product_id`**, carga `ConfiguredProducts.config_snapshot` y:
   - Asigna `config.measurements` y `config.panels` desde el snapshot (fuente de verdad para paneles).
   - Asigna `config.width_mm` = `measurements.width_total_mm` (ancho total).
   - Asigna `config.height_mm` desde snapshot.
7. Si `forEdit === true`, incluye `quote_line_id: lineId` en el config; si `forEdit === false`, no lo incluye (para Duplicar).

**Uso:**

- **Edit:** El `useEffect` de `loadLineConfig` en QuoteNew sigue usando su propia lógica (no llama a esta función) para no cambiar el flujo actual de carga al editar. Opcionalmente se podría migrar a usar `getConfigFromQuoteLine` con `forEdit: true`.
- **Duplicar:** Se llama `getConfigFromQuoteLine({ supabase, organizationId, lineId, forEdit: false })`, se eliminan `quote_line_id` y `configured_product_id` del objeto devuelto y se pasa como `initialLineConfig`.

---

## 3. Cambios en `src/pages/sales/QuoteNew.tsx`

### 3.1 Imports añadidos

- `createConfiguredProductPreview` desde `../../lib/bom/createConfiguredProductPreview` (para crear CP_NEW en Edit).
- `normalizeConfig` desde `./product-config/config-contract` (para construir el snapshot en Edit).
- `getConfigFromQuoteLine` desde `../../lib/quotes/getConfigFromQuoteLine`.
- Icono `Copy` desde `lucide-react` (botón Duplicar).

### 3.2 Función `buildConfigSnapshotFromProductConfig(productConfig)`

**Ubicación:** Después de `resolveProductTypeId`, antes del bloque de BOM Pricing (legacy).

**Propósito:** Construir el objeto `config_snapshot` que espera la RPC `create_configured_product_and_bom_preview`, a partir del estado actual del formulario (`productConfig`), de forma alineada con lo que hace ProductConfigurator al enviar.

**Contenido del snapshot:**

- **Paneles y medidas:** `panelsList` desde `configAny.panels`, `panelCount` desde `measurements.panel_count` o longitud de panels, `widthTotalMm` desde `measurements.width_total_mm` o suma de panels. Objeto `measurements` con `height_mm`, `width_total_mm`, `panel_count`, `panels` (con `index`), `is_interconnected`.
- **Ancho para BOM:** `width_mm` = ancho total (si `panel_count > 1` → `widthTotalMm`; si no → ancho del primer paño o `configAny.width_mm`).
- **Altura:** `height_mm` desde config normalizado o measurements.
- **Hardware y SKUs:** `hardware_color` (normalizado), `bottom_bar_*`, `headbox_*`, `side_channel_*`, `bottom_channel_*`, `motor_*`, `drive_*`, `tube_*`, `operating_type`.
- **Roll y cantidad:** `roll_catalog_item_id` (variantId/catalogItemId), `quantity`.
- **Instalación:** `fabricDrop`, `installationType`, `installationLocation`.
- **Accesorios:** `accessories` (array del config).

Se usa `normalizeConfig(productConfig)` para obtener el config normalizado y rellenar campos de forma consistente con el configurador.

### 3.3 Validación al inicio del submit

- **Antes:** Se exigía siempre `configured_product_id` para continuar.
- **Ahora:** Solo se exige si **no** se está editando:
  - `if (!editingLineId && !configuredProductId) { ... error; return; }`
  - Así, en Edit no hace falta tener un CP previo en el config (se crea CP_NEW al guardar).

### 3.4 Variables en ámbito superior del submit

Se declaran antes del `if (editingLineId)` para que el código que corre después del bloque ADD (Guardar roll, opciones, BOM, etc.) siga teniendo acceso cuando se viene del flujo ADD:

- `finalLineId`, `rollItemId` (ya existían conceptualmente; `finalLineId` y `rollItemId` se declaran al inicio).
- `catalogItem`, `collectionName`, `variantName`, `productTypeId`, `width_m`, `height_m`, `quantity`, `normalized`, `shouldUseSnapshotService`.

En el bloque **else** (ADD) se **asignan** estas variables en lugar de declararlas con `const`/`let`, para que el resto del handler las use.

### 3.5 Bloque EDIT SAVE (`if (editingLineId)`)

**Orden de ejecución:**

1. **Resolver product_type_id:**  
   `productTypeId = productConfig.productTypeId || await resolveProductTypeId(supabase, activeOrganizationId, productConfig.productType)`.  
   Si no hay productTypeId y sí productType → notificación de error y return.

2. **Construir config_snapshot:**  
   `configSnapshot = buildConfigSnapshotFromProductConfig(productConfig)`.

3. **Crear ConfiguredProduct nuevo:**  
   `createConfiguredProductPreview({ organization_id: activeOrganizationId, product_type_id: productTypeId, config_snapshot: configSnapshot, quote_id: quoteId || null })`.  
   Se obtiene `cpNewId` y `totals`.

4. **Dimensiones desde productConfig (invariante: ancho total):**  
   - `widthTotalMm` = `productConfig.width_mm ?? productConfig.measurements?.width_total_mm`.  
   - `heightMm` = `productConfig.height_mm ?? productConfig.measurements?.height_mm`.  
   - `width_m` = widthTotalMm / 1000 (o fallback desde productConfig).  
   - `height_m` = heightMm / 1000 (o fallback).

5. **Payload de actualización de QuoteLine:**  
   - `configured_product_id`: CP_NEW.  
   - `width_m`, `height_m`, `msrp` (totals.total_msrp), `last_priced_at`.  
   - `area`, `position`, `quantity`, `fabric_drop`, `installation_type`, `installation_location`.  
   - Se consulta el nuevo CP para rellenar `catalog_item_id`, `collection_name`, `variant_name` (roll) y se añaden al payload.  
   - `rollItemId` se deja asignado para uso posterior si hiciera falta (en EDIT no se usa más abajo porque se hace return).

6. **Update en BD:**  
   `supabase.from('QuoteLines').update(updatePayload).eq('id', editingLineId).eq('organization_id', activeOrganizationId)`.

7. **Sincronizar accesorios:**  
   - Soft-delete de componentes accesorios de esa línea:  
     `QuoteLineComponents` con `quote_line_id = editingLineId` y `source = 'accessory'` o `component_role = 'accessory'` → `update({ deleted: true })`.  
   - Inserción de los actuales desde `productConfig.accessories` (mismo formato que en ADD: organization_id, quote_line_id, catalog_item_id, qty, unit_cost_exw, source/component_role 'accessory').

8. **Coste y cierre:**  
   - `supabase.rpc('compute_quote_line_cost', { p_quote_line_id: editingLineId })`.  
   - `refetchLines()`, `setShowConfigurator(false)`, `setEditingLineId(null)`, **return** (no se ejecuta el flujo ADD ni “Guardar roll” ni el resto del submit).

**No se borra ni se archiva el CP anterior;** la línea simplemente pasa a apuntar al nuevo CP.

### 3.6 Eliminación del update directo en modo Edit (rama antigua)

- **Antes:** En el flujo ADD existía una rama `else if (editingLineId)` que hacía solo `supabase.from('QuoteLines').update(sanitizedQuoteLineData)` (sin crear CP nuevo).  
- **Ahora:** Esa rama se eliminó. Todo el flujo de Edit se resuelve en el bloque `if (editingLineId)` descrito arriba. La rama `else` solo contiene el flujo ADD (RPC commit o legacy insert).

### 3.7 Cierre del bloque ADD

- Tras el `else` que contiene la carga de ConfiguredProduct, construcción de quoteLineData, RPC commit (ADD) o insert legacy, se añadió un `} // end else (ADD path)` para cerrar correctamente el `else` que envuelve todo el flujo ADD (y no Edit).

### 3.8 Duplicar: botón y handler

- **Botón:** En la tabla de líneas, por cada fila, se añade un botón con icono `Copy` y título "Duplicar línea", antes del botón de Editar.
- **Handler `handleDuplicateLine(lineId)`:**  
  1. Llama a `getConfigFromQuoteLine({ supabase, organizationId: activeOrganizationId, lineId, forEdit: false })`.  
  2. Si no hay config, muestra notificación de error y return.  
  3. Quita del config las propiedades `quote_line_id` y `configured_product_id` (destructuring y `rest`).  
  4. `setInitialLineConfig(rest)`, `setEditingLineId(null)`, `setShowConfigurator(true)`, `clearConfiguratorDraft()`.  

Con esto el configurador se abre en modo **Add** (título "Add Quote Line") con los pasos prellenados. Al completar, el configurador crea un nuevo ConfiguredProduct y llama a `onComplete`; en `handleProductConfigComplete` se cumple `shouldUseSnapshotService` (hay configured_product_id y no hay editingLineId) y se ejecuta la RPC `commit_configured_product_to_quote_line`, creando una **nueva** QuoteLine. La línea original no se modifica.

---

## 4. Flujo resumido por acción

| Acción | Qué pasa al abrir | Qué pasa al guardar |
|--------|-------------------|----------------------|
| **Add** | Configurador vacío (o draft). Usuario configura y en el configurador se crea un CP. | Se llama `commitConfiguredProductToQuoteLine` con ese CP → RPC crea QuoteLine + BOMInstance. |
| **Edit** | Se carga la línea y su CP (`loadLineConfig`); se rellenan panels/measurements desde `config_snapshot`. No se crea CP. | Se construye snapshot del estado actual, se crea CP_NEW con `createConfiguredProductPreview`, se actualiza la QuoteLine (configured_product_id, width_m, height_m, msrp, etc.) y se sincronizan accesorios. Luego return (no flujo ADD). |
| **Duplicar** | Se llama `getConfigFromQuoteLine(lineId, forEdit: false)`, se quitan quote_line_id y configured_product_id, y se abre el configurador en modo Add con ese config. | Igual que Add: el configurador crea un nuevo CP y al completar se ejecuta la RPC commit → nueva QuoteLine. |

---

## 5. Invariantes y reglas respetadas

- **config.width_mm = ancho total** en snapshot y en actualización de QuoteLine (desde `productConfig.width_mm` o `measurements.width_total_mm`).
- **QuoteLine** guarda solo totales: `width_m`, `height_m` en metros (ancho total y altura). El detalle por paño sigue en `ConfiguredProducts.config_snapshot.measurements.panels`.
- **No se crea CP al abrir Edit;** solo al guardar (CP_NEW).
- **CP_OLD no se borra** al editar; la línea pasa a apuntar al nuevo CP.
- **Duplicar** no modifica la línea original; genera una nueva línea con el flujo ADD.
- **Accesorios** en Edit se persisten igual que en ADD: soft-delete de los anteriores de esa línea e inserción desde `productConfig.accessories` en `QuoteLineComponents`.

---

## 6. Archivos modificados / creados

| Archivo | Tipo | Descripción |
|---------|------|-------------|
| `src/lib/quotes/getConfigFromQuoteLine.ts` | Nuevo | Función pura para obtener ProductConfig desde una QuoteLine (Edit/Duplicar). |
| `src/pages/sales/QuoteNew.tsx` | Modificado | Imports (createConfiguredProductPreview, normalizeConfig, getConfigFromQuoteLine, Copy); `buildConfigSnapshotFromProductConfig`; validación condicional de configured_product_id; variables en ámbito del submit; bloque completo EDIT SAVE (CP_NEW + update QuoteLine + accesorios + return); eliminación de la rama antigua `else if (editingLineId)`; cierre del else ADD; botón Duplicar y `handleDuplicateLine`. |

---

## 7. Referencias

- **Flujo de paneles:** `FLUJO_PANELES_PANOS_DETALLE.md` (fuente de verdad de panels = measurements.panels, width_mm = ancho total).
- **Informe previo:** `INFORME_EDITAR_Y_DUPLICAR_QUOTE_LINES.md` (recomendaciones que se implementaron).
