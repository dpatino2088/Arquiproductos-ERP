# Informe: Edit Quote Line — Backend como única fuente de verdad

**Fecha:** Febrero 2026  
**Objetivo:** Documentar los cambios realizados en el flujo de **Editar línea de cotización** para que el equipo tenga una referencia clara de qué se hizo y qué responsabilidades tiene cada capa (Frontend vs Backend).

---

## 1. Resumen ejecutivo

Se corrigieron múltiples problemas en el flujo **Edit Quote Line**: dimensiones que quedaban en 0, precios (MSRP/total) desalineados, y errores de esquema (columna `metadata` inexistente). La solución adoptada fue **eliminar todos los cálculos de precios y dimensiones en el Frontend** y usar **solo lo que devuelve el Backend**. El Frontend se limita a armar el snapshot de configuración, enviarlo al Backend y copiar los valores que el Backend devuelve a la tabla QuoteLines; el pricing lo calcula íntegramente el Backend vía RPC `compute_quote_line_cost`.

---

## 2. Problemas que se abordaron

| Problema | Síntoma | Causa raíz abordada |
|----------|---------|----------------------|
| Width = 0 al guardar | Tras editar, la línea mostraba 0 x 2000 en la tabla | Frontend calculaba width/height desde varias fuentes y a veces fallaba; ahora se leen solo del ConfiguredProduct creado por el Backend |
| MSRP/total incorrectos | Un monto (ej. 666.66) se conservaba; total no cuadraba con unit price | Frontend escribía `msrp` manualmente o sincronizaba desde CP; se generaban inconsistencias. Ahora el Frontend **no escribe** msrp; solo llama `compute_quote_line_cost` |
| Editar sin tocar nada cambiaba montos | Al guardar sin modificar, aparecían cifras que no correspondían | Lógica de “sync MSRP desde CP” y recálculos en Frontend pisaban valores correctos del Backend |
| Error PGRST204 (metadata) | "Could not find the 'metadata' column of 'QuoteLines'" | El código hacía SELECT/UPDATE de `QuoteLines.metadata`; esa columna no existe. Se eliminó todo uso de `metadata` en QuoteLines |
| Validación "Invalid Dimensions" | No se podía guardar aunque las medidas se veían bien | Validación y fuentes de width/height eran contradictorias; se unificó: solo se acepta lo que viene del Backend (CP_NEW) |

---

## 3. Principio rector: Cero cálculos de negocio en el Frontend

- **Dimensiones (width_m, height_m):** El Backend las calcula al crear el ConfiguredProduct (RPC `create_configured_product_and_bom_preview` o flujo equivalente). El Frontend **solo lee** `width_mm` y `height_mm` del CP recién creado y los convierte a metros para QuoteLines.
- **Precios (MSRP, net_price, total, cost):** El Backend los calcula en la RPC `compute_quote_line_cost`. El Frontend **no escribe** `msrp` ni otros campos de pricing en el UPDATE de QuoteLines; solo actualiza datos estructurales (configured_product_id, width_m, height_m, catalog_item_id, collection_name, variant_name, area, position, quantity, fabric_drop, installation_*, accesorios).

---

## 4. Flujo actual: Edit Save (paso a paso)

Cuando el usuario hace clic en **Guardar** en el modal de Editar línea:

1. **Construir snapshot**  
   El Frontend arma un objeto `config_snapshot` con la configuración actual del producto (medidas, panels, hardware, tela, etc.) mediante `buildConfigSnapshotFromProductConfig(productConfig)`.

2. **Crear ConfiguredProduct en el Backend**  
   Se llama `createConfiguredProductPreview({ organization_id, product_type_id, config_snapshot, quote_id })`.  
   - El Backend crea un nuevo registro en `ConfiguredProducts` (CP_NEW) con dimensiones y totales calculados por su lógica.  
   - Devuelve `configured_product_id` (cpNewId).

3. **Leer CP_NEW del Backend**  
   El Frontend hace un `SELECT width_mm, height_mm, roll_catalog_item_id, roll_collection_name, roll_variant_name FROM ConfiguredProducts WHERE id = cpNewId`.  
   - **width_m** y **height_m** se obtienen únicamente de aquí: `width_m = width_mm / 1000`, `height_m = height_mm / 1000`.  
   - Si el Backend no devuelve dimensiones válidas, se muestra error y no se continúa.

4. **Actualizar QuoteLines (solo datos estructurales)**  
   Se hace `UPDATE QuoteLines SET configured_product_id = cpNewId, width_m = ..., height_m = ..., catalog_item_id, collection_name, variant_name, area, position, quantity, fabric_drop, installation_type, installation_location WHERE id = editingLineId`.  
   - **No se incluye** `msrp` ni ningún campo de pricing en este UPDATE.

5. **Sincronizar accesorios**  
   Se marcan como deleted los QuoteLineComponents de tipo accesorio de la línea y se insertan los accesorios que el usuario tiene en el configurator (sin lógica de precios en Frontend; costos los puede resolver el Backend si aplica).

6. **Calcular precios en el Backend**  
   Se llama `compute_quote_line_cost({ p_quote_line_id: editingLineId })`.  
   - Esta RPC debe actualizar en QuoteLines: msrp, net_price, cost, total, etc., según la configuración y el ConfiguredProduct asociado.

7. **Refrescar lista**  
   Se llama `refetchLines()` para que la tabla muestre los datos ya actualizados por el Backend.

---

## 5. Archivos modificados (resumen)

| Archivo | Cambio principal |
|---------|------------------|
| `database/migrations/20260206_sync_quote_line_pricing_from_configured_product.sql` | Nueva función `sync_quote_line_pricing_from_configured_product(p_quote_line_id)`: lee QuoteLine y su ConfiguredProduct, aplica la misma lógica de totales que `commit_configured_product_to_quote_line`, y hace UPDATE en QuoteLines de roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot, unit_msrp, msrp, total_cost, last_priced_at, pricing_version, pricing_locked. |
| `src/pages/sales/QuoteNew.tsx` | Flujo Edit Save: tras UPDATE estructural, se llama **sync_quote_line_pricing_from_configured_product(editingLineId)** para alinear pricing con ADD; luego opcionalmente compute_quote_line_cost. Log de debug en DEV: compara QuoteLines.msrp con CP snapshot total_msrp. |
| `src/lib/quotes/getConfigFromQuoteLine.ts` | (Sin cambios en esta última iteración; ya existía prefill unificado para Edit/Duplicate con fabricDrop, installationType, hardware con SKU/NONE, panels desde snapshot o metadata.) |
| `src/pages/sales/product-config/config-contract.ts` | `normalizeConfig` ahora deriva `width_m`/`height_m` desde `width_mm`/`height_mm` cuando faltan, para que la validación del configurator no falle por estado incompleto. |
| `src/pages/sales/curtain-config/MeasurementsStep.tsx` | (Sin cambios en esta iteración.) |
| `src/pages/sales/curtain-config/HardwareStep.tsx` | Comentario/documentación: no limpiar selección de hardware mientras las opciones siguen cargando. |
| `src/pages/sales/ProductConfigurator.tsx` | Validación de dimensiones en handleComplete usa varias fuentes (width_m, width_mm, measurements, panels) para no bloquear el guardado por un solo campo vacío; antes de onComplete se rellenan width_m/height_m y se pasan width_mm, height_mm, panels, measurements al handler para que Edit Save reciba datos completos. |

---

## 6. Sync de pricing en EDIT: misma fuente que ADD

**Problema:** ADD/Duplicate usan `commit_configured_product_to_quote_line`, que escribe en QuoteLines: `msrp`, `unit_msrp`, `roll_msrp_snapshot`, `bom_msrp_snapshot`, `roll_cost_snapshot`, `bom_cost_snapshot`, `total_cost`, `last_priced_at`, `pricing_version`, `pricing_locked`. En cambio, **EDIT** solo actualizaba `configured_product_id` y dimensiones y llamaba `compute_quote_line_cost`, que **no** actualiza esos campos en QuoteLines (solo QuoteLineCosts/ImportTaxBreakdown). Resultado: montos desalineados.

**Solución:** Se añadió la función **`sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)`** (migración `20260206_sync_quote_line_pricing_from_configured_product.sql`). Esta función:

- Lee la QuoteLine y su `configured_product_id`.
- Lee el ConfiguredProduct y su `bom_preview_snapshot` (y columnas de totales si hace falta).
- Calcula `roll_msrp_snapshot`, `bom_msrp_snapshot`, `roll_cost_snapshot`, `bom_cost_snapshot`, `unit_msrp`, `msrp`, `total_cost` con la **misma lógica** que `commit_configured_product_to_quote_line`.
- Hace `UPDATE QuoteLines SET ... WHERE id = p_quote_line_id`.

En el flujo EDIT Save (QuoteNew.tsx), **después** del UPDATE estructural se llama a esta RPC; **después** (opcional) se sigue llamando a `compute_quote_line_cost` solo como motor auxiliar de costos/reporting. **No** se confía en `compute_quote_line_cost` para rellenar `msrp`/`unit_msrp` en QuoteLines.

---

## 7. Responsabilidades claras para el equipo

### Backend debe garantizar

- **create_configured_product_and_bom_preview** (o el flujo que crea el ConfiguredProduct): que `ConfiguredProducts.width_mm`, `height_mm` y los totales/snapshot se rellenen correctamente.
- **sync_quote_line_pricing_from_configured_product**: que, dado un `quote_line_id`, se actualicen en esa fila de QuoteLines los campos de pricing desde el ConfiguredProduct asociado (misma lógica que commit).
- **compute_quote_line_cost**: opcional para EDIT; usado para QuoteLineCosts/reporting. **No** es la fuente de `msrp`/`unit_msrp` en QuoteLines.

### Frontend hace solo

- Armar `config_snapshot` con lo que el usuario eligió (incluidas medidas y panels).
- Llamar al Backend para crear CP_NEW y, después, leer de la BD los campos necesarios del CP_NEW (dimensiones, roll_catalog_item_id, etc.).
- Escribir en QuoteLines **únicamente** identificadores y datos estructurales (configured_product_id, width_m, height_m, etc.).
- Llamar **`sync_quote_line_pricing_from_configured_product(p_quote_line_id)`** después del UPDATE para que los montos queden igual que en ADD.
- Opcionalmente llamar `compute_quote_line_cost` para cost/reporting; refrescar la lista.

---

## 8. Cómo validar

1. **Editar una línea** (con 1 paño o 2 paños), cambiar dimensiones, guardar.  
   - En la tabla deben verse las dimensiones correctas (ej. 1200 x 2000 o 1200+1500).  
   - MSRP y total deben ser coherentes entre sí y con lo que el Backend calcula (revisar en BD o en tooltip si existe).

2. **Editar una línea sin cambiar nada**, guardar.  
   - Los montos no deben cambiar; si cambian, el fallo está en el Backend (compute_quote_line_cost o datos que lee).

3. **Revisar en Base de Datos**  
   - Tras guardar, en `QuoteLines`: `width_m`, `height_m`, `configured_product_id`, `msrp`.  
   - En `ConfiguredProducts` para ese `configured_product_id`: `width_mm`, `height_mm`, totales.  
   - Debe haber coherencia entre CP y QuoteLine; el Frontend ya no introduce lógica de cálculo propia.

---

## 9. Referencia cruzada

- Detalle de prefill (Edit/Duplicate), selecciones y medidas: **INFORME_EDIT_DUPLICATE_QUOTE_LINE_SELECCIONES_Y_MEDIAS.md**  
- Este documento se centra en: **reglas de Edit Save y que todo el cálculo (dimensiones y precios) quede en el Backend.**

Si necesitan ampliar algún punto (por ejemplo, contrato exacto de `compute_quote_line_cost` o de `create_configured_product_and_bom_preview`), se puede añadir una sección en este mismo informe o en un anexo técnico.
