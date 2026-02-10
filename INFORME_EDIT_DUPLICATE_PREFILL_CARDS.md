# Informe: Prefill de selecciones en Edit y Duplicate (Cards Hardware / Bottom Bar)

**Fecha:** 2026-02-06  
**Problema reportado:** Al editar o duplicar una línea de cotización, las cards del configurador (especialmente color + Bottom Bar en el paso HARDWARE) no mostraban la selección anterior; el color a veces sí, el Bottom Bar casi nunca.

---

## 1. Causas identificadas

1. **Config pasado a `onComplete` incompleto (Edit Save)**  
   En modo Edit, `ProductConfigurator` pasaba a `onComplete` un objeto derivado de `normalizeConfig()`, que **no incluye** `bottom_bar_item_id`, `bottom_bar_sku`, ni otros campos de hardware. `QuoteNew` usa ese objeto para `buildConfigSnapshotFromProductConfig` y para crear el `ConfiguredProduct`. El snapshot se guardaba sin hardware → al reabrir Edit/Duplicate, no había datos para prefill del Bottom Bar.

2. **Prefill al cargar la línea (Edit/Duplicate)**  
   - `getConfigFromQuoteLine` solo leía `config_snapshot` del `ConfiguredProduct`; si el snapshot estaba vacío o legacy, no había fallback.  
   - No se usaban las **columnas planas** de `ConfiguredProducts` (`bottom_bar_item_id`, `bottom_bar_sku`, etc.) como respaldo.  
   - Solo se hidrataban `headbox` / `side_channel` / `bottom_channel` desde SKU → **no** `bottom_bar` ni `tube`.  
   - Si el CP no se encontraba por `organization_id` (legacy/org NULL), no había segundo intento por `id`.

3. **Match de selección en UI solo por `id`**  
   En `HardwareStep`, la card del Bottom Bar se marcaba como seleccionada solo si `config.bottom_bar_item_id === option.id`. Con datos legacy o IDs mixtos (org vs global), el id en config no coincidía con el id de la opción cargada por tipo + color, aunque el **SKU** sí fuera el correcto (ej. RCA-04-W). Resultado: la card aparecía pero sin borde de selección.

---

## 2. Cambios realizados (resumen)

| # | Archivo | Qué se hizo |
|---|--------|-------------|
| 1 | `src/pages/sales/ProductConfigurator.tsx` | Antes de `onComplete(finalNormalizedConfig)` se hace **carry-over** desde el estado actual del config (`configAny`) al objeto que se pasa al padre: `hardware_color`, `bottom_bar_item_id`, `bottom_bar_sku`, headbox/side_channel/bottom_channel, tube/drive/motor, `operation_type`, `accessories`, `fabricDrop`, `installationType`, `installationLocation`. Así Edit Save recibe un config completo y el snapshot del CP incluye hardware. |
| 2 | `src/lib/quotes/getConfigFromQuoteLine.ts` | • **Carga del CP por id únicamente**: `SELECT id, config_snapshot, hardware_color FROM ConfiguredProducts WHERE id = QuoteLine.configured_product_id` (sin filtrar por `organization_id`; la fuente de verdad es el id al que apunta la línea). • Si **no se encuentra CP**: se usa fallback desde QuoteLine (`_prefill_source = 'QUOTE_LINE_FALLBACK'`); `hardware_color` y `drive_type` ya vienen de `lineData`. • Merge desde `config_snapshot` (snake_case + camelCase); hidratación `bottom_bar`/tube/headbox/side_channel/bottom_channel con `hydrateItemIdsFromSkus`. • **Resolución case-insensitive**: si hay `bottom_bar_sku` pero no `bottom_bar_item_id`, se resuelve el id con `resolveCatalogItemIdBySkuCaseInsensitive`; si no se encuentra, se conserva el SKU (no se borra). • **Instrumentación**: con `window.__DEBUG_PREFILL === true` se loguea CP loaded/CP_NOT_FOUND, final prefill (hardware_color, bottom_bar_sku, bottom_bar_item_id). |
| 3 | `src/pages/sales/curtain-config/HardwareStep.tsx` | • **Match por id o SKU**: `isSelected = (config.bottom_bar_item_id === item.id) || (normSku(config.bottom_bar_sku) === normSku(item.sku))`. • **Pill "Selected: SKU (not available in current options)"**: cuando `config.bottom_bar_sku` existe pero ninguna opción tiene ese SKU; no se deselecciona automáticamente. • **Hidratación solo en prefill**: el efecto que rellena `bottom_bar_item_id` desde opciones por SKU solo corre si `!userInteractedRef.current` (al hacer clic en una card se pone `userInteractedRef.current = true`). • **DEBUG_PREFILL**: log cuando el SKU guardado no está en la lista de opciones (primeros 10 SKUs disponibles). |

---

## 3. Archivos tocados (lista para diff/review)

- `src/pages/sales/ProductConfigurator.tsx` — carry-over de hardware y componentes al objeto pasado a `onComplete`.
- `src/lib/quotes/getConfigFromQuoteLine.ts` — carga CP por id solo, fallback QuoteLine, resolución case-insensitive de bottom_bar_item_id desde SKU, DEBUG_PREFILL.
- `src/pages/sales/curtain-config/HardwareStep.tsx` — match por id o SKU, pill "Selected: SKU (not available...)", userInteractedRef para no hidratar tras clic, DEBUG_PREFILL.
- `src/pages/sales/QuoteNew.tsx` — logs DEBUG_PREFILL al abrir Edit/Duplicate (quote_line_id, configured_product_id, keys de resultado).

*(Otros cambios de la misma sesión: eliminación del badge verde "Repriced from config" en `QuoteNew.tsx`; migración guard rail pricing y RPC sync ya existían.)*

---

## 4. Cómo comprobar que funciona

1. **Edit**  
   - Abrir una cotización, editar una línea que tenga color (ej. White) y Bottom Bar (ej. RCA-04-W) ya guardados.  
   - En el modal "Edit Quote Line", ir al paso HARDWARE.  
   - Debe verse: color White seleccionado y card "Bottom Bar - RCA-04-W" con borde de selección.

2. **Duplicate**  
   - Duplicar esa misma línea (sin guardar cambios en Edit).  
   - En el configurador, paso HARDWARE: mismo comportamiento (color + Bottom Bar prefill).

3. **Guardar en Edit**  
   - En Edit, sin cambiar nada, pulsar guardar.  
   - Volver a editar la misma línea: las selecciones deben seguir igual (no se pierden después de guardar).

---

## 5. SQL de verificación (Supabase SQL Editor)

**Test manual tras guardar Edit:** confirmar que la línea apunta al CP recién guardado:

```sql
-- Tras guardar en Edit, pega el quote_line_id y el cp.id que devolvió createConfiguredProductPreview:
SELECT id, configured_product_id FROM public."QuoteLines" WHERE id = 'PASTE_QUOTE_LINE_ID';
-- configured_product_id debe ser el id del CP que se acaba de upsert.
```

Para inspeccionar una línea que no hace prefill correctamente:

```sql
-- 1) Ver QuoteLine
SELECT id, configured_product_id, hardware_color, drive_type
FROM public."QuoteLines"
WHERE id = 'PASTE_QUOTE_LINE_ID';

-- 2) Ver ConfiguredProduct ligado
SELECT id, organization_id, hardware_color, config_snapshot
FROM public."ConfiguredProducts"
WHERE id = (SELECT configured_product_id FROM public."QuoteLines" WHERE id = 'PASTE_QUOTE_LINE_ID');

-- 3) Ver si ese SKU existe y su id (reemplaza PASTE_BOTTOM_BAR_SKU por ej. 'RCA-04-W')
SELECT id, sku, name
FROM public."CatalogItems"
WHERE LOWER(TRIM(sku)) = LOWER(TRIM('PASTE_BOTTOM_BAR_SKU'));
```

---

## 6. Instrumentación (debug prefill)

Para activar logs de prefill en desarrollo:

1. En la consola del navegador (en la página de la cotización):  
   `window.__DEBUG_PREFILL = true`
2. Recarga o abre Edit/Duplicate de una línea.
3. En consola verás:
   - `[QuoteNew EDIT] opening prefill` — quote_line_id, configured_product_id
   - `[getConfigFromQuoteLine] CP loaded` o `CP_NOT_FOUND`
   - `[getConfigFromQuoteLine] final prefill` — hardware_color, bottom_bar_sku, bottom_bar_item_id, _prefill_source
   - `[QuoteNew EDIT] getConfigFromQuoteLine result keys`
   - En HardwareStep: `[HardwareStep] bottom_bar_sku saved but not in options` si el SKU guardado no está en la lista de opciones

Los logs solo se emiten cuando `process.env.NODE_ENV !== 'production'` y `window.__DEBUG_PREFILL === true`.

---

## 7. Si sigue fallando

- **Solo falla en ciertas líneas:** Revisar en BD que el `ConfiguredProduct` de esa línea tenga `config_snapshot` con `bottom_bar_item_id` y/o `bottom_bar_sku`, o que las columnas planas `bottom_bar_item_id` / `bottom_bar_sku` estén pobladas.  
- **Nunca muestra Bottom Bar:** Revisar que `useBOMTemplateOptionsSimple` devuelva opciones para ese `productTypeId` + color (White); si no hay templates para ese color, no habrá opciones y no se puede prefill.  
- **RLS:** Si el segundo intento de carga del CP por `id` falla por RLS, el prefill dependerá solo del primer query (por `organization_id`); en ese caso asegurar que el CP tenga `organization_id` correcto.

---

## 8. Resumen en una frase

Se corrigió el prefill en Edit/Duplicate asegurando que (1) el config que se guarda en Edit incluya hardware y Bottom Bar, (2) la carga de la línea use snapshot + columnas planas del CP + hidratación por SKU para bottom_bar y tube, y (3) en HardwareStep la card del Bottom Bar se marque por id o por SKU y se normalice el id desde SKU cuando haga falta.
