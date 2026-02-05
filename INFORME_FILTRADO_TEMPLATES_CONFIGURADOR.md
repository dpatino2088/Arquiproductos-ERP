# Informe: Filtrado de BOM Templates en el Configurador de Productos

**Fecha:** 2026-02-04  
**Módulo:** Add Quote Line / Product Configurator (Sales)  
**Objetivo:** Documentar cómo funciona actualmente el filtrado progresivo de BOM templates para el equipo.

---

## 1. Resumen ejecutivo

El configurador usa un **filtrado progresivo**: en cada paso (Hardware, Operating System) se reduce la lista de `BOMTemplates` válidos según las selecciones del usuario. Esa lista se guarda en el estado del config como `_hardware_filtered_templates` y se usa para:

- Mostrar solo opciones (SKUs) que existen en los templates que siguen siendo candidatos.
- Mostrar el texto "X template(s)" en las cards.
- Al final (Review / Add to Quote), para ayudar a resolver un único `bom_template_id` cuando hay uno solo, o para que el backend/frontend elija entre varios.

**Problema conocido:** Si al final de Operating System siguen quedando **2 (o más) templates**, el flujo puede fallar con "Ambiguous BOMTemplate match" en el fallback frontend, o el usuario ve "2 template(s)" cuando esperaría 1. Para llegar a **1 template** hace falta que las selecciones (color, bottom bar, headbox, drive, tube, etc.) discriminen hasta un único template en los datos (BOMTemplates + BOMComponents).

---

## 2. Flujo general

```
Product Step → Variants → [Measurements] → Hardware → Operating System → Accessories → Review/Quote
                              (no filtra)              (filtra por color + hardware)   (filtra por drive/tube)
```

- **Variants:** Solo selección de tela/variante (roll). **No participa en el filtrado de templates.**
- **Hardware:** Filtra por color y por componentes (bottom bar, headbox, side channel, bottom channel). Escribe `_hardware_filtered_templates`.
- **Operating System:** Parte de `_hardware_filtered_templates`, filtra por Manual/Motor y por drive/tube. Vuelve a escribir `_hardware_filtered_templates`.
- **Review / Add to Quote:** Usa `_hardware_filtered_templates` como `candidate_template_ids` en el snapshot; el backend (o el fallback frontend) resuelve el `bom_template_id` final.

---

## 3. Estado persistido en el config (ProductConfigurator)

Todo el estado del configurador vive en un único objeto `config` que se actualiza con `onUpdate` y se pasa a cada paso.

### 3.1 Campos que afectan al filtrado

| Campo | Dónde se escribe | Significado |
|-------|-------------------|-------------|
| `_hardware_filtered_templates` | HardwareStep, OperatingSystemStep | Array de UUIDs de BOMTemplates que siguen siendo candidatos tras las selecciones del paso actual. |
| `_operating_system_base_templates` | OperatingSystemStep | Copia de `_hardware_filtered_templates` al **entrar** a Operating System sin selección de operación; sirve como base al cambiar Manual ↔ Motor. |
| `hardware_color` / `hardwareColor` | HardwareStep | Color de hardware (White, Black, Silver). Define el conjunto inicial de templates en Hardware. |
| `bottom_bar_item_id`, `headbox_item_id`, `side_channel_item_id`, `bottom_channel_item_id` | HardwareStep | Componentes de hardware elegidos; cada uno reduce la lista de templates. |
| `operation_type` / `drive_type` | OperatingSystemStep | `'manual'` o `'motor'`. |
| `drive_item_id`, `motor_item_id`, `tube_item_id` | OperatingSystemStep | Componentes de operación; reducen la lista en ese paso. |

### 3.2 Limpieza al volver atrás

Al usar **Back** o al hacer clic en un paso anterior, `ProductConfigurator` aplica `getClearUpdatesForStepId` y limpia las selecciones (y estados de templates) de los pasos que quedan **por detrás** del paso al que se vuelve:

- Al volver **desde Hardware** (p.ej. a Variants): se limpian selecciones de hardware y **`_hardware_filtered_templates`**.
- Al volver **desde Operating System** (a Hardware): se limpian selecciones de operación, **`_operating_system_base_templates`** y **`_hardware_filtered_templates`**.

Así, al re-entrar en un paso, la lista de templates se vuelve a calcular a partir de las selecciones actuales de ese paso (y de los anteriores), sin arrastrar una lista “vieja”.

---

## 4. Paso a paso del filtrado

### 4.1 Variants

- **No filtra BOM templates.** Solo se elige fabricante, colección, variante (roll).
- El configurador **no** pasa `filteredTemplateIds` a ningún paso; cada paso que filtra usa solo `config` (y dentro de él `_hardware_filtered_templates` cuando corresponde).

### 4.2 Hardware

**Archivo:** `src/pages/sales/curtain-config/HardwareStep.tsx`

- **Entrada de templates:**  
  - El paso recibe `filteredTemplateIds` por props, pero **ProductConfigurator no lo rellena**, así que viene `undefined`.
  - Las opciones del primer bloque (bottom bar) se cargan con `useBOMTemplateOptionsSimple(productTypeId, currentHardwareColor, 'bottom_bar', undefined)`. Con `filteredTemplateIds === undefined`, el hook carga de BD todos los BOMTemplates del `product_type_id` y, si el rol depende de color, del `hardware_color` (White/Black/Silver).

- **Color:**  
  - Al elegir color se llama `loadTemplatesForColor(color)`: consulta `BOMTemplates` por `product_type_id` + `hardware_color` y escribe en config **`_hardware_filtered_templates`** con esos IDs (o con templates con `hardware_color` NULL si no hay con ese color).

- **Cadena de filtrado (useMemo):**
  - **templatesAfterBottomBar:** Si hay bottom bar seleccionado → solo los `templateIds` de esa opción; si no → `filteredTemplateIds` (null en la práctica).
  - **templatesAfterHeadbox:** Si hay headbox elegido → intersección con sus `templateIds`; si el usuario puso “None” o deseleccionó → no se filtra por headbox (se mantiene la lista anterior).
  - **templatesAfterSideChannel** y **templatesAfterBottomChannel:** Misma idea (intersección si hay selección; si “None”/deselección, no se filtra por ese rol).

- **Salida:**  
  - `finalFilteredTemplates` = resultado de la cadena anterior.  
  - Un `useEffect` escribe en config **`_hardware_filtered_templates`** cuando `finalFilteredTemplates` cambia.

Conclusión: en Hardware la lista se reduce por **color + bottom bar + headbox/side/bottom channel** (según lo que el usuario elija). Si no se elige headbox/side/bottom channel, no se aplica filtro extra por esos roles.

### 4.3 Operating System

**Archivo:** `src/pages/sales/curtain-config/OperatingSystemStep.tsx`

- **Entrada de templates:**  
  - **`hardwareFilteredTemplates`** = `config._hardware_filtered_templates` (lo que dejó Hardware).
  - Si no hay ninguna selección de operación (ni tipo ni drive/motor), un `useEffect` guarda esa lista en **`_operating_system_base_templates`** para usarla como base al cambiar Manual ↔ Motor.
  - **baseTemplatesForOptions** = `_operating_system_base_templates` si existe, si no `hardwareFilteredTemplates`.

- **Manual vs Motor:**  
  - Se consulta `BOMComponents` para los templates base y se separan:
    - **templatesForManual:** templates que tienen rol `drive`.
    - **templatesForMotor:** templates que tienen rol `motor`.
  - Al elegir Manual se actualiza **`_hardware_filtered_templates`** con `templatesForManual`; al elegir Motor, con `templatesForMotor`.

- **Drive / Motor / Tube:**  
  - Opciones cargadas con `useBOMTemplateOptionsSimple(..., 'drive'|'motor'|'tube', templatesForManual|templatesForMotor|templatesAfterOperation)`.
  - **templatesAfterOperation:** intersección de la base (manual o motor) con los `templateIds` del drive o motor seleccionado.
  - **finalFilteredTemplates:** si hay tube seleccionado, intersección de `templatesAfterOperation` con los `templateIds` del tube; si no, es `templatesAfterOperation`.
  - Un `useEffect` vuelve a escribir **`_hardware_filtered_templates`** con `finalFilteredTemplates`.

Por tanto, en Operating System la lista se reduce por **Manual/Motor** y luego por **drive/motor concreto** y **tube**. Si dos templates comparten el mismo drive y el mismo tube, la lista puede seguir teniendo 2 elementos y el usuario verá "2 template(s)".

### 4.4 Hook useBOMTemplateOptionsSimple

**Archivo:** `src/hooks/useBOMTemplateOptionsSimple.ts`

- **Parámetros:** `productTypeId`, `hardwareColor`, `role`, `filteredTemplateIds` (opcional).
- Si **`filteredTemplateIds`** tiene elementos, el hook consulta `BOMComponents` solo para esos templates y devuelve opciones (SKUs) con su **`templateIds`** (en qué templates aparece cada ítem).
- Si **`filteredTemplateIds`** es null/undefined, el hook obtiene templates de BD por `product_type_id` y, para roles que dependen de color, por `hardware_color`; luego hace la misma consulta de componentes para esos IDs.
- Cada opción devuelta incluye **`templateIds`**: lista de IDs de BOMTemplate donde ese componente (rol) existe. El paso usa esas listas para hacer intersecciones y calcular la siguiente lista filtrada.

---

## 5. Resolución final del BOM template (Add to Quote)

**Archivos:**  
`src/pages/sales/ProductConfigurator.tsx` (arma el snapshot),  
`src/lib/bom/createConfiguredProductPreview.ts` (resuelve template y crea preview).

- En **handleComplete**, el configurator arma un `configSnapshot` con todas las selecciones (bottom_bar_item_id, drive_item_id, tube_item_id, hardware_color, etc.).
- Si en config existe **`_hardware_filtered_templates`**, se copia a **`config_snapshot.candidate_template_ids`** (solo IDs válidos no vacíos).
- Si `candidate_template_ids` tiene **un solo ID**, además se setea **`config_snapshot.bom_template_id`** a ese ID.
- **createConfiguredProductPreview**:
  1. Intenta primero **resolveBomTemplateIdStrict** → RPC **`select_best_bom_template_v2_strict`** (p_org, p_product_type, p_config). El backend **no** recibe `candidate_template_ids`; solo el config con item IDs. Devuelve un único template según la lógica del servidor.
  2. Si esa RPC falla, usa **resolveBomTemplateIdFrontendStrict**:
     - Carga BOMTemplates (si hay `candidate_template_ids`, filtra por esos IDs).
     - Filtra por color y por componentes (bottom_bar, tube, drive/motor, headbox, side_channel, bottom_channel) y se queda con los templates que coinciden con todas las selecciones.
     - Si hay **0** matches → error "No BOMTemplate match found (frontend fallback)".
     - Si hay **más de 1** match → error **"Ambiguous BOMTemplate match (frontend fallback): N templates"**.

Por eso: si el filtrado progresivo deja 2 (o más) templates y ambos cumplen las mismas selecciones, el backend puede devolver uno cualquiera, pero el **fallback frontend** lanzará error de “Ambiguous” cuando se use.

---

## 6. Por qué puede seguir habiendo “2 template(s)”

1. **Datos:** Para el mismo product type + color + bottom bar + (opcionalmente headbox/side/bottom) + Manual + mismo drive + mismo tube, existen **dos BOMTemplates** en BD con los mismos BOMComponents (mismo bottom_bar, mismo drive, mismo tube). El filtrado no puede distinguirlos y deja 2 candidatos.
2. **Tube no seleccionado:** En Operating System, si el usuario no elige tube, `finalFilteredTemplates` = `templatesAfterOperation` (solo filtrado por drive). Si ese drive está en 2 templates, la lista sigue con 2.
3. **Opcionales sin filtrar:** En Hardware, si el usuario no elige headbox / side channel / bottom channel (o elige “None”), no se aplica filtro extra por esos roles; la lista puede seguir siendo la de “después de bottom bar” (p.ej. 2 templates).

Para llegar a **1 template** hace falta que, con las selecciones actuales, solo un BOMTemplate tenga exactamente esa combinación de componentes (incluyendo tube en Operating System si hay varias opciones de tube).

---

## 7. Diagrama de datos (resumen)

```
BOMTemplates (product_type_id, hardware_color, ...)
       ↓
BOMComponents (bom_template_id, component_role, component_item_id)
       ↓
Por cada rol (bottom_bar, drive, tube, headbox, ...):
  - Opciones = ítems distintos que aparecen en los templates actuales
  - Cada opción tiene templateIds = [ templates donde aparece ese ítem ]
       ↓
En cada paso:
  - Lista actual = intersección de (lista anterior, templateIds de la opción elegida)
  - Lista actual se guarda en config._hardware_filtered_templates
       ↓
Al final: candidate_template_ids = _hardware_filtered_templates
  → Backend (o frontend fallback) elige 1 template → bom_template_id
```

---

## 8. Recomendaciones para el equipo

1. **Revisar datos:** Para combinaciones que deberían ser únicas (mismo color, mismo bottom bar, mismo drive, mismo tube), comprobar en BD que no existan dos BOMTemplates con la misma combinación de BOMComponents. Si existen, o se unifican o se añade un componente que los diferencie (p.ej. otro rol en BOMComponents).
2. **Obligar tube en Operating System:** Si para el product type siempre hay tube y hay más de un template posible, exigir selección de tube antes de permitir “Next” puede asegurar que `finalFilteredTemplates` se reduzca a 1 cuando los templates difieren por tube.
3. **Backend y candidatos:** Si se quiere que el filtrado progresivo sea la única fuente de candidatos, habría que pasar `candidate_template_ids` al RPC `select_best_bom_template_v2_strict` (o a una variante) y que el backend solo elija entre esos IDs. Hoy el backend no recibe esa lista.
4. **Depuración:** En DEV, los logs de `[HardwareStep]` y `[OperatingSystemStep]` muestran tamaños de listas (templatesAfterBottomBar, templatesAfterHeadbox, finalFilteredTemplates, etc.). Revisar esos logs cuando el usuario vea "2 template(s)" para ver en qué paso deja de reducirse la lista.

---

## 9. Referencia rápida de archivos

| Archivo | Responsabilidad |
|---------|-----------------|
| `ProductConfigurator.tsx` | Orquestación, config único, limpieza al volver atrás, envío de `candidate_template_ids` en snapshot. |
| `HardwareStep.tsx` | Color + bottom bar + headbox + side_channel + bottom_channel → `_hardware_filtered_templates`. |
| `OperatingSystemStep.tsx` | Manual/Motor + drive/motor + tube → actualiza `_hardware_filtered_templates` y usa `_operating_system_base_templates`. |
| `useBOMTemplateOptionsSimple.ts` | Carga opciones (SKUs) por rol y lista de templates; devuelve `templateIds` por opción. |
| `createConfiguredProductPreview.ts` | Resuelve `bom_template_id` (RPC o frontend con `candidate_template_ids`), crea ConfiguredProduct y preview. |
| `ReviewStep.tsx` | Usa `_hardware_filtered_templates` / `bom_template_id` para desglose y totales. |

Si necesitas ampliar alguna sección (p.ej. solo Hardware o solo backend), se puede añadir un anexo con más detalle de código o de esquema de BD.
