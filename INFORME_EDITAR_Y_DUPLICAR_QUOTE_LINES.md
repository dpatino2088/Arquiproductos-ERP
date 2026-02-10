# Informe: Editar y duplicar Quote Lines

Este documento resume el estado actual de **edición** y **duplicación** de líneas de cotización (Quote Lines), qué falta y qué se recomienda para dejarlo estable y sin bugs.

---

## 1. Estado actual: Editar Quote Line

### 1.1 Lo que ya funciona

| Aspecto | Estado | Dónde |
|--------|--------|--------|
| Carga al abrir "Edit" | ✅ | `QuoteNew.tsx`: `loadLineConfig` (useEffect con `editingLineId`) |
| Carga QuoteLine + CatalogItem + ProductType + accesorios | ✅ | Selects a QuoteLines, CatalogItems, ProductTypes, QuoteLineComponents |
| Carga ConfiguredProduct.config_snapshot | ✅ | Si existe `lineData.configured_product_id`, se hace select a ConfiguredProducts por id |
| Relleno de panels/measurements en config | ✅ | Si `snapshot.measurements` o `snapshot.panels` existen, se asignan a `config.measurements`, `config.panels`, `config.width_mm`, `config.height_mm` |
| Fallback 1 panel desde QuoteLine | ✅ | Config inicial usa `lineData.width_m`/`height_m` cuando no hay snapshot; luego el bloque con `cpId` puede sobrescribir con snapshot |
| UI del configurador con pasos (Variants, Measurements, etc.) | ✅ | Mismo flujo que "Add"; título "Edit Quote Line" cuando `editingLineId` está definido |

Referencia de flujo detallado (paneles, fuente de verdad, invariantes): **`FLUJO_PANELES_PANOS_DETALLE.md`**.

### 1.2 Lo que falta o puede dar problemas al guardar (Edit)

1. **Origen de `width_m` / `height_m` al guardar**  
   En submit se construye `quoteLineData` con:
   - `width_m` = `configuredProductData.width_mm / 1000` (desde DB) **o** `productConfig.width_m`
   - `height_m` = igual con `height_mm` / `productConfig.height_m`  
   Se hace un fetch del ConfiguredProduct **actual** al inicio del submit, por tanto `configuredProductData` sigue siendo el estado **antiguo**. Si el usuario cambió dimensiones o paneles en el configurador, `productConfig` tiene lo nuevo pero la expresión da prioridad al valor del ConfiguredProduct en DB.  
   **Riesgo:** al editar y cambiar medidas, la QuoteLine puede quedar con `width_m`/`height_m` viejos.

2. **ConfiguredProduct no se actualiza en modo Edit**  
   En modo edición **no** se llama a la RPC `commit_configured_product_to_quote_line` (solo se usa para "Add"). Solo se hace:
   - `supabase.from('QuoteLines').update(sanitizedQuoteLineData).eq('id', editingLineId)`  
   Por tanto:
   - **QuoteLine** sí se actualiza (con los campos que llegan en `sanitizedQuoteLineData`).
   - **ConfiguredProduct** (config_snapshot, width_mm, height_mm, bom_preview_snapshot) **no** se toca.  
   Si el usuario cambia dimensiones, número de paños o variante, el ConfiguredProduct vinculado sigue con el snapshot y BOM antiguos. Listados, popup "Configured Product" y manufactura pueden seguir mostrando datos viejos.

3. **product_type_id en allowedQuoteLineFields**  
   `allowedQuoteLineFields` no incluye `product_type_id`; si en algún momento se quiere persistir el tipo de producto en la línea al editar, habría que añadirlo (y asegurar que el backend lo acepte).

---

## 2. Recomendaciones: Editar Quote Line

1. **Priorizar config del formulario para dimensiones al guardar (Edit)**  
   - Al construir `quoteLineData` en modo edición, usar **siempre** para `width_m` y `height_m` el valor derivado del estado actual del configurador:
     - `width_m` = `(productConfig.width_mm ?? productConfig.width_m) ?? configuredProductData.width_mm/1000`
     - `height_m` = `(productConfig.height_mm ? productConfig.height_mm/1000 : productConfig.height_m) ?? configuredProductData.height_mm/1000`  
   - Así QuoteLine refleja lo que el usuario ve en el formulario (y se cumple la invariante "QuoteLine guarda ancho total").

2. **Mantener ConfiguredProduct alineado con la edición**  
   Opciones (elegir una estrategia clara):
   - **A) Actualizar el ConfiguredProduct existente:**  
     Al guardar en modo Edit, además del `update` de QuoteLine:
     - Actualizar `ConfiguredProducts` del mismo `configured_product_id`: `config_snapshot` (con measurements, panels, y el resto del config actual), `width_mm`, `height_mm`.
     - Recalcular BOM: llamar a una función/RPC que regenere `bom_preview_snapshot` para ese ConfiguredProduct (por ejemplo reutilizando la lógica de `build_bom_preview_snapshot` o un RPC que reciba el nuevo config_snapshot y actualice el registro).  
     Así una sola fuente de verdad: el ConfiguredProduct siempre refleja lo guardado.
   - **B) Crear nuevo ConfiguredProduct en cada Edit (y reasignar la línea):**  
     Al guardar en Edit: crear un nuevo ConfiguredProduct con el config actual (igual que en "Add", p. ej. vía `create_configured_product_and_bom_preview` o un RPC específico "update or clone"), luego actualizar la QuoteLine con el nuevo `configured_product_id` y los campos de la línea (width_m, height_m, msrp, etc.).  
     Ventaja: historial claro (cada versión es un CP distinto). Desventaja: más registros y que la RPC actual está pensada para "crear", no "actualizar".

   **Recomendación:** A si ya existe o se puede exponer una forma de "actualizar config_snapshot + recalcular BOM" para un ConfiguredProduct existente; si no, B con un RPC o flujo que clone el CP y actualice la línea.

3. **Validaciones al guardar (Edit)**  
   - Asegurar que `config.width_mm` sea siempre ancho total (invariante del doc de paneles).
   - Si hay validación de tolerancia en MeasurementsStep (`abs(width_total_mm - sum(panels)) <= 5`), no permitir "Save" en Edit si esa validación no se cumple (o mostrar el mismo warning que en Add).

4. **Accesorios y otros campos**  
   Hoy se cargan accesorios desde QuoteLineComponents y se rellenan en `config.accessories`. Al guardar en Edit, el flujo actual no vuelve a escribir QuoteLineComponents de accesorios de forma explícita en el fragmento "Update existing line". Confirmar si existe otro camino que actualice componentes/accesorios al editar; si no, habría que persistir los accesorios del config actual en QuoteLineComponents (o en el snapshot) para que no se pierdan o queden desincronizados.

---

## 3. Estado actual: Duplicar Quote Line

- **No existe** en la UI un botón ni acción "Duplicar línea" (o "Copy line") en la pantalla de cotización.
- En el código no hay flujo específico para clonar una QuoteLine ni para reutilizar un ConfiguredProduct como base de otra línea.

---

## 4. Recomendaciones: Duplicar Quote Line

### 4.1 Comportamiento deseado

- El usuario selecciona "Duplicar" en una línea existente.
- El sistema crea una **nueva** línea en la misma cotización (o en otra, según diseño) con la misma configuración (variante, dimensiones, paneles, hardware, accesorios, etc.), de forma que el usuario pueda ajustar detalles y guardar como nueva línea.

### 4.2 Enfoque recomendado (sin nuevas tablas)

- **No** hace falta una columna extra en QuoteLines ni en ConfiguredProducts para "es duplicado de".
- Reutilizar la misma lógica que **Edit**: la "fuente de verdad" del detalle es el ConfiguredProduct (config_snapshot con measurements y panels).

**Opción recomendada: "Duplicar = abrir Add con config prellenado"**

1. **Acción "Duplicar"** (p. ej. botón o menú en cada fila de la tabla de líneas).
2. **Cargar la línea a duplicar** igual que en Edit:
   - Obtener QuoteLine por id.
   - Si tiene `configured_product_id`, cargar ConfiguredProduct y su `config_snapshot`.
   - Construir el mismo objeto `config` (initialLineConfig) que en `loadLineConfig`, **pero sin** asignar `editingLineId` y sin `quote_line_id` en el config (para que el flujo piense que es una línea nueva).
3. **Abrir el configurador en modo "Add Quote Line"** con `initialLineConfig` prellenado (pasos VARIANTES, MEASUREMENTS, HARDWARE, etc. ya rellenados).
4. El usuario revisa/cambia lo que quiera y pulsa "Add to Quote".
5. El flujo normal de "Add" crea un **nuevo** ConfiguredProduct (con el config actual, que puede haber sido modificado) y una **nueva** QuoteLine vía `commit_configured_product_to_quote_line`.

Ventajas:
- Reutiliza loadLineConfig (o una función compartida "getConfigFromQuoteLine(lineId)") y el flujo actual de creación.
- No requiere RPC nueva de "clonar ConfiguredProduct"; el nuevo CP se genera al guardar con el config actual.
- Paneles y measurements se mantienen por construcción (vienen del config_snapshot y se pasan al nuevo CP).

### 4.3 Implementación técnica sugerida

| Paso | Acción |
|------|--------|
| 1 | Añadir estado opcional, p. ej. `duplicatingFromLineId: string \| null`. Cuando el usuario hace "Duplicar", setear `duplicatingFromLineId = lineId` y no `editingLineId`. |
| 2 | Reutilizar la misma función que alimenta `initialLineConfig` en Edit (por ejemplo extraer `loadLineConfig` a una función async `getConfigForLine(lineId)` que devuelve el config sin setear estado). Para "Duplicar", llamarla con el id de la línea a duplicar y usar el resultado como `initialLineConfig` **sin** `quote_line_id` y sin `editingLineId`. |
| 3 | Abrir el configurador (`setShowConfigurator(true)`) con título "Add Quote Line (from duplicate)" o "Add Quote Line" y asegurar que al enviar el formulario se use la rama "Add" (crear nuevo CP y nueva QuoteLine), no la rama "Update". |
| 4 | Añadir en la tabla de líneas un botón/menú "Duplicar" por fila (y, si aplica, confirmación "Se creará una nueva línea con la misma configuración. ¿Continuar?"). |

### 4.4 Alternativa: duplicar en backend

Si se prefiere que "Duplicar" cree la nueva línea **sin** abrir el configurador (copia 1:1 y el usuario puede editar después):

- RPC o función en backend que:
  1. Dado `source_quote_line_id` y `quote_id` (y org):
     - Lee QuoteLine origen y su ConfiguredProduct.
    2. Crea un **nuevo** ConfiguredProduct copiando `config_snapshot`, `width_mm`, `height_mm`, etc., del origen (y opcionalmente regenerando `bom_preview_snapshot`).
  3. Llama a la lógica de `commit_configured_product_to_quote_line` con el nuevo `configured_product_id` y el mismo `quote_id` (y position/area si se quieren copiar o dejar vacíos).
- En el front, "Duplicar" solo llamaría a esa RPC y refrescaría la lista de líneas.

Ventaja: un clic y ya está la línea duplicada. Desventaja: requiere RPC nueva o extensión de la actual; si no existe "clone ConfiguredProduct", hay que implementarla.

---

## 5. Resumen de tareas

### Editar Quote Line

| # | Tarea | Prioridad |
|---|--------|------------|
| 1 | En submit (Edit), usar siempre `productConfig` para `width_m` y `height_m` (con fallback a ConfiguredProduct) para que QuoteLine guarde el ancho total actual. | Alta |
| 2 | Definir estrategia: actualizar ConfiguredProduct existente (config_snapshot + recalcular BOM) **o** crear nuevo CP y reasignar línea; implementarla al guardar en Edit. | Alta |
| 3 | Si se actualiza CP existente: implementar RPC o función que actualice `config_snapshot`, `width_mm`, `height_mm` y regenere `bom_preview_snapshot` para un ConfiguredProduct dado. | Alta (si estrategia A) |
| 4 | Asegurar que accesorios y otros campos (QuoteLineComponents, etc.) se persistan correctamente al guardar en Edit. | Media |
| 5 | Aplicar la misma validación de tolerancia (panels vs width_total_mm) en Edit que en Add. | Baja |

### Duplicar Quote Line

| # | Tarea | Prioridad |
|---|--------|------------|
| 1 | Añadir botón/acción "Duplicar" en la tabla de líneas (QuoteNew). | Alta |
| 2 | Extraer o reutilizar la lógica de carga de config (getConfigFromQuoteLine / loadLineConfig) para obtener config desde una línea por id. | Alta |
| 3 | Flujo "Duplicar": setear initialLineConfig desde la línea origen (sin quote_line_id y sin editingLineId), abrir configurador en modo Add, y al guardar crear nuevo CP y nueva QuoteLine. | Alta |
| 4 | (Opcional) Si se prefiere duplicado en 1 clic sin abrir configurador: implementar RPC/función que clone ConfiguredProduct y cree nueva QuoteLine, y llamarla desde el front. | Media |

---

## 6. Invariantes a respetar (referencia)

- **config.width_mm** siempre = ancho total (nunca solo panel 1).
- **Fuente de verdad de panels** = `measurements.panels` (en config y en config_snapshot).
- **QuoteLine** guarda solo totales: `width_m`, `height_m` = ancho total y altura; el detalle por paño vive en **ConfiguredProducts.config_snapshot**.
- Al **editar**, si existe ConfiguredProduct.config_snapshot.measurements, se usa para cargar; si no, fallback a 1 panel desde QuoteLine.width_m/height_m.
- Al **guardar** (Add o Edit), QuoteLine.width_m debe ser siempre ancho total.

Con esto, edición y duplicación quedan alineados con el flujo de paneles y con el documento **FLUJO_PANELES_PANOS_DETALLE.md**.
