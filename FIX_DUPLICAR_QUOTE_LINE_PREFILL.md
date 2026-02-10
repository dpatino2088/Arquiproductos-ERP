# Fix: Duplicar Quote Line — prefill estable y a prueba de balas

Este documento resume los cambios hechos para que **Duplicar** abra el configurador con todo prellenado (medidas, drive, tube, tela, hardware, etc.) y no se pierda por draft ni por inconsistencias internas. Sirve como referencia para el equipo.

---

## 1. Problema que teníamos

Al hacer **Duplicar** en una línea de cotización:

- El configurador se abría en modo "Add Quote Line".
- Aparecía el toast **"Configuration Incomplete"**: Width, Height, Manual drive selection, Tube selection requeridos.
- En la UI las medidas (1200 x 2000) sí se veían, pero el validador del configurador no las recibía o se pisaban.

**Causas identificadas:**

1. **Orden del handler:** Se llamaba `clearConfiguratorDraft()` **después** de `setInitialLineConfig` y `setShowConfigurator(true)`. El draft (o el estado inicial del modal) podía pisar el prefill al montar.
2. **Prefill incompleto:** `getConfigFromQuoteLine()` cargaba medidas y panels desde el snapshot, pero **no** subía al config raíz los campos que el validador exige: `drive_type`, `drive_item_id`, `tube_item_id`, etc. Esos viven en el snapshot y no se estaban copiando.
3. **Riesgo de merge:** Si en el futuro se hacía merge tipo `{ ...config, ...snapshot }`, cualquier clave del snapshot con valor `undefined` podía borrar valores buenos del config.
4. **Riesgo de desincronización:** Copiar `width_m`/`height_m` directo del snapshot podía dejar `width_mm` de un valor y `width_m` de otro (redondeos o snapshots viejos), y romper validaciones o cálculos.

---

## 2. Qué hicimos (resumen)

| Objetivo | Cambio |
|----------|--------|
| Evitar que el draft pise el prefill | Reordenar el handler: **primero** `clearConfiguratorDraft()` y `setEditingLineId(null)`, **luego** cargar config, setear `initialLineConfig` y **al final** `setShowConfigurator(true)`. |
| Prefill completo para el validador | En `getConfigFromQuoteLine()`, cuando existe `ConfiguredProducts.config_snapshot`, copiar al config raíz: medidas (mm + measurements/panels), drive_type, operation_type, tube_item_id, drive_item_id, motor_item_id, _sku, hardware_color, accesorios, etc. |
| No pisar con `undefined` | Usar un helper **`setIfDefined(target, source, ...keys)`** que solo asigna `target[k] = source[k]` si `source[k] !== undefined`. Todas las propiedades que vienen del snapshot se copian con este criterio. |
| Una sola fuente de verdad en medidas | **No** copiar `width_m`/`height_m` del snapshot. **Sí** derivarlos siempre al final: `width_m = width_mm / 1000`, `height_m = height_mm / 1000`. |
| Poder depurar rápido | Añadir `console.debug` (solo DEV) en el handler de Duplicar con: width_mm, height_mm, width_total_mm, panel_count, suma de panels, drive_type, tube_item_id, drive_item_id, etc. |

---

## 3. Reglas que quedaron fijas

- **Orden en Duplicar:**  
  `clearConfiguratorDraft()` → `setEditingLineId(null)` → `await getConfigFromQuoteLine(...)` → `setInitialLineConfig(prefillConfig)` → `setShowConfigurator(true)`.  
  Así no hay “primer render vacío” y el modal usa siempre el prefill.

- **Merge desde snapshot:**  
  Solo escribir en el config valores que **están definidos** en el snapshot (nunca escribir `undefined` encima de un valor que ya tenía el config).  
  Implementación: `setIfDefined(config, snap, 'drive_type', 'operation_type', 'tube_item_id', ...)`.

- **Medidas:**  
  En el config del configurador la representación “que manda” es **mm + measurements** (y panels).  
  `width_m` y `height_m` son **siempre derivados** de `width_mm` y `height_mm` al final de `getConfigFromQuoteLine()`, para que duplicado/edición no introduzcan desincronización.

- **Objetivo de uso:**  
  Duplicar = abrir con **todo** igual (medidas, paños, tela, hardware, drive, tube, color, accesorios). El usuario solo cambia lo que quiera (ej. Area o Position) y guarda. Internamente seguimos las reglas anteriores para que no falle la validación ni los cálculos.

- **A) Consistencia measurements vs width_mm (normalización panels):**  
  Si hay `measurements.panels` (o `config.panels`) con `length > 0`: se recalcula `sumPanelsMm = sum(panel.width_mm)`. Si `measurements.width_total_mm` falta o no coincide con `sumPanelsMm`, se corrige: `width_total_mm = sumPanelsMm` y `config.width_mm = sumPanelsMm`. Así se evita el bug “paneles 1200+900 pero width_total=2000”. Implementado en helper `normalizeWidthFromPanels()` al final del merge con snapshot.

- **B) hardware_color como canónico:**  
  La fuente canónica es `hardware_color` (la que usa el filtro de templates). `hardwareColor` se mantiene como alias derivado: después del merge con snapshot, si `config.hardware_color` está definido, se setea `config.hardwareColor = config.hardware_color` para que UI y validador no tengan drift.

- **C) Accesorios: una sola fuente:**  
  Los accesorios se cargan primero desde **QuoteLineComponents** (tabla). Si el snapshot trae `accessories`, solo se usan para rellenar cuando la tabla no aportó ninguno: `if (snap.accessories && (!config.accessories || config.accessories.length === 0))`. Así se evitan duplicados silenciosos por doble fuente.

---

## 4. Checklist para validar que está estable

| Caso | Qué validar |
|------|-------------|
| **1) Línea moderna (snapshot completo)** | Duplicar → abre sin toast. Panels visibles. Drive/tube ya seleccionados. Puedes cambiar solo Area y guardar. |
| **2) Línea vieja (snapshot incompleto o sin drive/tube)** | Duplicar → abre prellenado de medidas si existen. El toast puede pedir drive/tube (OK). Seleccionas esos 2 campos y guardas. |
| **3) Multi-panel** | `sumPanelsMm === measurements.width_total_mm === config.width_mm`. `width_m === width_mm/1000`. No hay inconsistencia al guardar. |
| **4) Accesorios** | Duplicado trae exactamente los mismos accesorios **una sola vez** (sin duplicar por snapshot + tabla). |

---

## 5. Archivos tocados

| Archivo | Cambios |
|---------|--------|
| **`src/pages/sales/QuoteNew.tsx`** | En `handleDuplicateLine`: orden (clearConfiguratorDraft primero, setInitialLineConfig y setShowConfigurator al final). `console.debug` del prefill con width_mm, height_mm, width_total_mm, panel_count, sumPanelsMm, drive_type, tube_item_id, drive_item_id, motor_item_id, panelsLength. |
| **`src/lib/quotes/getConfigFromQuoteLine.ts`** | (1) Merge desde snapshot solo con valores definidos: `setIfDefined(config, snap, ...)` para drive_type, operation_type, tube_*, drive_*, motor_*, hardware_color, etc. (2) Medidas: width_mm/height_mm desde measurements/snapshot; **no** copiar width_m/height_m del snapshot. (3) Al final: `width_m = width_mm / 1000`, `height_m = height_mm / 1000`. (4) **A** Helper `normalizeWidthFromPanels(config)`: si hay panels, recalcula sum y corrige width_total_mm/width_mm si faltan o no cuadran. (5) **B** hardware_color canónico; hardwareColor = alias. (6) **C** Accesorios desde snapshot solo si la tabla (QuoteLineComponents) no aportó ninguno. Helper `setIfDefined` en el mismo archivo. |

---

## 6. Cómo comprobar que todo va bien

1. **Duplicar una línea** que tenga medidas, manual drive y tube.
2. El configurador debe abrir **sin** toast "Configuration Incomplete" y con todos los pasos prellenados (medidas, variante, hardware, operating system, etc.).
3. En consola (solo en DEV) debe aparecer el log `[QuoteNew] Duplicate prefill config` con `width_mm`, `height_mm`, `width_total_mm`, `panel_count`, `sumPanelsMm`, `drive_type`, `tube_item_id`, `drive_item_id` con valores coherentes.
4. Cambiar solo un dato (ej. Area) y guardar: debe crear una **nueva** línea con el mismo producto/config y el dato cambiado.
5. Validar los 4 casos del **Checklist** (sección 4): línea moderna, línea vieja, multi-panel, accesorios sin duplicar.

Con esto el equipo tiene claro qué estamos haciendo en Duplicar y por qué (orden, prefill, merge definido, medidas derivadas de mm, normalización panels, color canónico y una sola fuente de accesorios).
