# Informe: Edit y Duplicar Quote Line — selecciones y medidas

Este documento describe **qué estaba pasando**, **por qué** y **qué se hizo** para corregir los problemas de mantener selecciones y medidas al Editar o Duplicar una línea de cotización.

---

## 1. Resumen de síntomas

| Síntoma | Dónde se veía |
|--------|----------------|
| Al **Editar**, los cards de FABRIC DROP e INSTALLATION TYPE & LOCATION no mostraban selección (aunque la línea ya tuviera valores). | Modal "Edit Quote Line", step Measurements |
| Al **Duplicar**, lo mismo: cards sin marcar. | Modal "Add Quote Line" (modo duplicado) |
| Al **Editar/Duplicar**, el step **Hardware** no mantenía: Color y Bottom bar sí; Headbox, Side Channel y Bottom Channel no (o aparecían "Not Included" cuando había selección). | Step Hardware |
| Al **Editar**, si la línea tenía **2 paños**, al abrir el modal solo aparecía un ancho (se “perdían” los paños). | Measurements step, dimensiones |
| Al **Editar**, las medidas se veían bien en el modal, pero al **guardar** la línea quedaba con **width = 0** en la tabla. | Lista de líneas del quote |

---

## 2. Por qué pasaba (causas raíz)

### 2.1 Cards de Measurements (Fabric Drop, Installation Type/Location)

- **Dónde se lee la selección:** En `MeasurementsStep.tsx` los cards comparan con `config.fabricDrop`, `config.installationType`, `config.installationLocation` (camelCase).
- **Qué ocurría:**
  - **Duplicar:** El config de prefill lo construía `getConfigFromQuoteLine()`, que **no** rellenaba esos campos (ni desde `QuoteLines.fabric_drop/installation_type/installation_location` ni desde `config_snapshot`). El UI nunca recibía valores → ningún card quedaba marcado.
  - **Editar:** El config lo armaba **otra función** (lógica manual en `QuoteNew.tsx`, `loadLineConfig`), que tampoco rellenaba `fabricDrop` / `installationType` / `installationLocation`. Además, esa lógica era distinta a la de Duplicar, así que las correcciones que se hicieran en un flujo no aplicaban al otro.

### 2.2 Hardware (Headbox, Side Channel, Bottom Channel)

- **Dónde se lee la selección:** En `HardwareStep.tsx` se usa el sistema **RoleSelection** (UNSET / NONE / SELECTED), que depende de:
  - `*_item_id` (UUID del ítem o el string `'NONE'`)
  - `*_sku` (string; si falta, se considera UNSET aunque exista `item_id`)
- **Qué ocurría:**
  - En `getConfigFromQuoteLine()` solo se copiaban del snapshot los `*_item_id` (p. ej. `headbox_item_id`). **No** se copiaban los `*_sku` (p. ej. `headbox_sku`). Para el código de RoleSelection, `sku === undefined` → UNSET → el card no se marca.
  - Algunos snapshots antiguos guardaban “Not Included” como `{ sku: null, item_id: null }`. El UI espera `*_item_id === 'NONE'` para marcar el botón “Not Included”. Sin esa conversión, el botón no aparecía seleccionado.
  - Snapshots viejos a veces tenían solo `*_sku` y no `*_item_id`. Los cards se marcan por `item_id` contra la lista de opciones; sin `item_id` no hay coincidencia.
  - **Editar** no usaba `getConfigFromQuoteLine()`, así que no se beneficiaba de ninguna corrección hecha ahí para Duplicar.

### 2.3 Pérdida de los 2 paños al Editar

- **Dónde se leen los paños:** En el configurador, `config.panels` y `config.measurements` (con `panel_count`, `width_total_mm`, etc.).
- **Qué ocurría:**
  - Líneas “legacy” o creadas con flujos antiguos tenían los paños solo en **`QuoteLines.metadata.panels`**, no necesariamente en `ConfiguredProducts.config_snapshot`.
  - Al unificar Edit para usar `getConfigFromQuoteLine()`, el código solo rellenaba `panels`/`measurements` desde el **config_snapshot**. Si el snapshot no traía panels, no había fallback → el config llegaba con un solo ancho (o el de la línea) y “desaparecían” los 2 paños en la UI.

### 2.4 Width = 0 al guardar (Edit)

- **Dónde se escribe:** En `QuoteNew.tsx`, al guardar en modo Edit se construye `updatePayload` con `width_m` y `height_m` y se hace `QuoteLines.update(updatePayload)`.
- **Qué ocurría:**
  - El cálculo era:  
    `widthTotalMm = productConfig.width_mm ?? productConfig.measurements?.width_total_mm ?? null`  
    y  
    `width_m = widthTotalMm != null ? widthTotalMm / 1000 : productConfig.width_m ?? null`.
  - En **multi-paño**, el estado del configurador suele tener `config.panels` (y a veces `measurements.width_total_mm`), pero **no** siempre `config.width_mm` en la raíz. Si el config no tenía `width_mm` ni `measurements.width_total_mm` bien seteados en el momento del guardado, `widthTotalMm` quedaba **null** → `width_m` **null** → en la tabla se muestra como 0.
  - No se usaba la **suma de `config.panels`** como fuente (a diferencia de `buildConfigSnapshotFromProductConfig`, que sí deriva `width_total_mm` desde los panels). Esa inconsistencia hacía que, en la práctica, al guardar se perdiera el ancho cuando la única fuente de verdad en ese momento eran los panels.

---

## 3. Qué se hizo (cambios realizados)

### 3.1 Unificar prefill de Edit con Duplicar

- **Archivo:** `src/pages/sales/QuoteNew.tsx`
- **Cambio:** Se eliminó la lógica manual de `loadLineConfig` (fetch de QuoteLine, CatalogItem, ProductType, accesorios, construcción de config por tipo de producto, merge parcial del snapshot). Ahora **Edit** usa el mismo flujo que Duplicar:
  1. `clearConfiguratorDraft()`
  2. `getConfigFromQuoteLine({ supabase, organizationId, lineId: editingLineId, forEdit: true })`
  3. `setInitialLineConfig(config)` y `setShowConfigurator(true)`
- **Motivo:** Un solo lugar (`getConfigFromQuoteLine`) para prefill garantiza que todas las mejoras (medidas, panels, hardware, fabric drop, installation) apliquen por igual a Edit y Duplicar.

### 3.2 Rellenar Fabric Drop e Installation en el prefill

- **Archivo:** `src/lib/quotes/getConfigFromQuoteLine.ts`
- **Cambio:**
  - En `baseConfigCommon` se añadieron:  
    `fabricDrop`, `installationType`, `installationLocation`  
    tomados de `lineData.fabric_drop`, `lineData.installation_type`, `lineData.installation_location` y normalizados con `normalizeEnum()` a los ids del UI (`normal`/`inverted`, `inside`/`outside`, `ceiling`/`wall`).
  - En el merge desde `config_snapshot` se añadió la misma lógica para camelCase y snake_case del snapshot, y se normalizan con `normalizeEnum()` antes de asignar al config.
- **Archivo:** `src/pages/sales/curtain-config/MeasurementsStep.tsx`
- **Cambio:** Los cards leen ahora de variables que aceptan legacy:  
  `currentFabricDrop = config.fabricDrop ?? config.fabric_drop`,  
  `currentInstallationType = config.installationType ?? config.installation_type`,  
  `currentInstallationLocation = config.installationLocation ?? config.installation_location`.  
  Así, aunque el snapshot use snake_case, la selección se muestra bien.

### 3.3 Hardware: SKUs, NONE y hydratar item_id desde SKU

- **Archivo:** `src/lib/quotes/getConfigFromQuoteLine.ts`
- **Cambios:**
  1. **Merge desde snapshot:** Se copian también los campos `*_sku` (p. ej. `headbox_sku`, `side_channel_sku`, `bottom_channel_sku`) además de los `*_item_id`, y se aceptan variantes en camelCase (p. ej. `headboxSku`).
  2. **Normalización de color:** Se normaliza `hardware_color` a formato DB/UI (`White`/`Black`/`Silver`) con `normalizeHardwareColor()`.
  3. **Trim de SKUs:** `normalizeSkuFields()` para que los SKUs no queden vacíos o con espacios y el RoleSelection no los trate como UNSET.
  4. **Sentinel NONE:** Si para headbox/side_channel/bottom_channel el snapshot tiene `*_sku === null` y `*_item_id === null`, se setea `*_item_id = 'NONE'` para que el botón “Not Included” quede seleccionado.
  5. **Hydratar item_id desde SKU:** Si falta `*_item_id` pero existe `*_sku`, se busca en `CatalogItems` por SKU (org o global) y se rellena `*_item_id`. Así los cards pueden marcarse aunque el snapshot solo traiga SKU.

### 3.4 Fallback de panels desde metadata (legacy multi-paño)

- **Archivo:** `src/lib/quotes/getConfigFromQuoteLine.ts`
- **Cambio:** Después de aplicar el config_snapshot, si `config.panels` no existe o está vacío y `lineData.metadata.panels` existe, se reconstruye:
  - `config.panels = metadata.panels` (como `[{ width_mm }, ...]`)
  - `config.measurements` con `panel_count`, `width_total_mm` (suma de panels), `panels`, `is_interconnected`
  - Luego se sigue usando la normalización existente (`normalizeWidthFromPanels`) para alinear `width_mm` con la suma.
- **Motivo:** Líneas que guardaron los paños solo en `metadata.panels` vuelven a mostrar 2 (o más) paños al Editar/Duplicar.

### 3.5 Cálculo de width/height al guardar (Edit) y persistencia de panels

- **Archivo:** `src/pages/sales/QuoteNew.tsx` (bloque “EDIT SAVE”)
- **Cambios:**
  1. **Derivar width igual que en el snapshot:** Se obtiene `panelsList` de `productConfig.panels`.  
     `widthTotalMm` se calcula como:  
     `productConfig.width_mm ?? productConfig.measurements?.width_total_mm ?? (panelsList.length > 0 ? suma(panels[].width_mm) : null)`.  
     Así, si la única fuente de verdad en el estado son los panels, el ancho total no se pierde.
  2. **No guardar 0 como medida:**  
     `width_m` y `height_m` solo se setean si el valor derivado es **> 0**; si no, se deja `null` para no persistir 0.
  3. **Persistir panels en la línea:** Si hay varios paños (`panelsList.length > 0`), se añade al payload de update:  
     `metadata: { panels: panelsList.map(p => ({ width_mm: p.width_mm })) }`.  
     Así la próxima vez que se abra Edit (o se use el fallback desde metadata en `getConfigFromQuoteLine`) se siguen viendo los paños.

### 3.6 Edit Save: CP_NEW como fuente de verdad para width/height

- **Archivo:** `src/pages/sales/QuoteNew.tsx` (bloque "EDIT SAVE")
- **Cambios:**
  1. Tras `createConfiguredProductPreview(...)` se hace **un único select** del CP recién creado:  
     `select width_mm, height_mm, roll_catalog_item_id, roll_collection_name, roll_variant_name from ConfiguredProducts where id = cpNewId`.
  2. **width_m y height_m se calculan preferentemente desde CP_NEW:**  
     `width_m = (cpNew.width_mm != null && cpNew.width_mm > 0) ? cpNew.width_mm / 1000 : null` (y análogo para height_m).  
     Así Edit queda tan estable como Add: el backend (BOM preview / CP) ya normalizó las medidas.
  3. **Fallback solo si CP no trae medidas:** Si `cpNew.width_mm` o `cpNew.height_mm` son null/0, se usa la misma lógica que antes: `productConfig.width_mm`, `measurements.width_total_mm`, suma de `productConfig.panels` o `measurements.panels`, y en DEV se loguea para depuración.
  4. Se eliminó el segundo select de ConfiguredProducts; se reutiliza el mismo `cpNew` para `catalog_item_id`, `collection_name`, `variant_name` y `rollItemId`.
- **Motivo:** Evitar que la QuoteLine quede con width = 0 cuando `productConfig` en el momento del guardado está incompleto (p. ej. multi-panel con panels en otra forma o estado React desincronizado). El motor de CP ya calcula bien; usarlo como salida final alinea Edit con el flujo Add (commit RPC).

### 3.7 Validación del step Variants (roller/dual/triple)

- **Archivos:** `src/pages/sales/product-config/products/roller-shade/index.ts`, `dual-shade/index.ts`, `triple-shade/index.ts`
- **Cambio:** En `validateStep('variants')` se dejó de validar solo `collectionId` y `variantId` (o `frontFabric`). Ahora se considera válido si hay **collection** (`collectionName` o `collection_name` o `collectionId`) y **variant** (`variantId` o `fabric_catalog_item_id` o `fabric_variant_id`), alineado con lo que realmente usa `VariantsStep.tsx`.  
  Evita que “Next” se habilite o deshabilite de forma incoherente con lo que muestra el UI.

---

## 4. Archivos tocados (resumen)

| Archivo | Cambios |
|--------|--------|
| `src/lib/quotes/getConfigFromQuoteLine.ts` | Prefill de fabricDrop/installationType/installationLocation (desde línea y snapshot). Merge de hardware con *_sku y *_item_id. Normalización de hardware_color. normalizeSkuFields. applyNoneSentinel. hydrateItemIdsFromSkus. Fallback panels desde metadata. normalizeWidthFromPanels ya existía. |
| `src/pages/sales/curtain-config/MeasurementsStep.tsx` | Uso de currentFabricDrop, currentInstallationType, currentInstallationLocation con fallback a snake_case. |
| `src/pages/sales/QuoteNew.tsx` | Edit: loadLineConfig reemplazado por getConfigFromQuoteLine (forEdit: true). Edit save: CP_NEW como fuente de verdad para width_m/height_m (select tras createConfiguredProductPreview), fallback desde productConfig/panels; persistir metadata.panels; un solo select para roll_catalog_item_id/collection/variant. |
| `src/pages/sales/product-config/products/roller-shade/index.ts` | validateStep('variants') acepta collectionName/collection_name/variantId/fabric_catalog_item_id. |
| `src/pages/sales/product-config/products/dual-shade/index.ts` | Idem para variants. |
| `src/pages/sales/product-config/products/triple-shade/index.ts` | Idem para variants. |

---

## 5. Cómo validar

1. **Edit – Measurements:** Abrir Edit en una línea con fabric drop e instalación definidos → los cards Normal/Inverted y Inside/Outside/Ceiling/Wall deben aparecer seleccionados.
2. **Edit – Hardware:** Abrir Edit en una línea con headbox (o “Not Included”), side channel y bottom channel definidos → los cards y el botón “Not Included” deben reflejar la selección previa.
3. **Edit – 2 paños:** Línea con 2 paños (legacy en metadata o en snapshot) → al abrir Edit deben verse los dos anchos; al guardar, la tabla debe seguir mostrando dimensiones correctas (no 0 en width).
4. **Duplicar:** Misma línea → Duplicar y comprobar que Measurements, Hardware y (si aplica) paños se prellenan igual que en Edit.
5. **Guardar Edit:** Editar una línea con 2 paños, no cambiar medidas, guardar → en la lista, width no debe ser 0 y las dimensiones deben coincidir con lo editado.

---

## 6. Conclusión

Los fallos venían de: (1) **dos fuentes de prefill** (Edit vs Duplicar) con lógica distinta y sin campos de measurements/hardware completos; (2) **Hardware** dependiente de *_sku y del sentinel 'NONE', que no se estaban rellenando ni normalizando; (3) **panels** solo leídos del config_snapshot, sin fallback a `metadata.panels`; (4) **guardado en Edit** sin derivar el ancho desde la suma de panels y sin persistir metadata.panels. Unificando el prefill en `getConfigFromQuoteLine`, completando allí todos los campos que usan los steps (incluido hardware con SKUs y NONE), añadiendo el fallback de panels desde metadata y alineando el guardado de Edit con la misma lógica de medidas y panels, las selecciones y las medidas se mantienen tanto al Editar como al Duplicar y al guardar.
