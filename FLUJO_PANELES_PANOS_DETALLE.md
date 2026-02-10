# Flujo detallado: Paneles (paños) en el configurador y BOM

Este documento describe cómo funcionan los paneles (1, 2 o 3 paños) en el sistema: dónde se capturan, cómo se persisten y dónde puede fallar si no ves los paños por separado.

---

## 1. Modelo de datos

### 1.1 En el config (frontend)

- **Fuente de verdad de panels:** `config.measurements.panels` (array con `index` y `width_mm` por paño). Ej: `[{ index: 1, width_mm: 1200 }, { index: 2, width_mm: 1500 }]`.
- **`config.measurements`**: objeto con:
  - `height_mm`: altura común (mm).
  - `width_total_mm`: suma de `measurements.panels[].width_mm` (debe coincidir con la suma; ver validación más abajo).
  - `panel_count`: 1, 2 o 3.
  - `panels`: **única fuente de verdad** de los paños (con `index` y `width_mm`).
  - `is_interconnected`: `panel_count > 1`.
- **`config.panels`** (opcional): si se mantiene, es **solo copia/fallback** de `measurements.panels`; puede desaparecer en el futuro para evitar duplicidad.
- **`config.width_mm`** (legacy, pero **regla obligatoria**): siempre representa el **ancho total** en mm.
  - Si `panel_count === 1`: `width_mm === panels[0].width_mm`.
  - Si `panel_count > 1`: `width_mm === measurements.width_total_mm` (**NO** el ancho del panel 1).
  - Motivo: si alguien usa `config.width_mm` en un cálculo (área, BOM, validaciones), debe ser seguro y consistente.

### 1.2 En base de datos

- **ConfiguredProducts**
  - `width_mm`: debe ser **ancho total** (suma de paños) cuando hay 2 o 3 paños (lo fija el RPC desde `config_snapshot.measurements.width_total_mm`).
  - `height_mm`: altura común.
  - `config_snapshot` (JSONB): debe incluir `measurements` y `panels` tal cual los envía el front.
- **QuoteLines**
  - `width_m`, `height_m`: en metros; normalmente el ancho total y la altura (para área y totales).
  - No guardan `panels` ni `measurements`; eso vive solo en `ConfiguredProducts.config_snapshot`.

---

## 2. Flujo paso a paso

### 2.1 MeasurementsStep (captura)

- **Archivo:** `src/pages/sales/curtain-config/MeasurementsStep.tsx`.
- Product types con paneles: `roller-shade`, `dual-shade`, `triple-shade` (`supportsPanels`).
- El usuario introduce:
  - **Altura:** común para todos los paños.
  - **Ancho por paño:** Panel 1, Panel 2 (si hay 2), Panel 3 (si hay 3). Botones "Add panel" / "Remove".
- Cada cambio llama a `pushMeasurementsAndPanels(heightMm, newPanels)`, que:
  - Construye `measurements`: `height_mm`, `width_total_mm`, `panel_count`, `panels: [{ index, width_mm }, ...]`, `is_interconnected`.
  - Hace `onUpdate({ panels, measurements, width_mm: measurements.width_total_mm, width_m: ... })`.
- **Validación (multi-panel):** si `panel_count > 1`, debe cumplirse `abs(width_total_mm - sum(panels[].width_mm)) <= 5` (mm). Si falla: bloquear "Next" o mostrar warning. Evita tener "2420 total" con panels que no cuadran.
- Resultado: en el estado del configurador quedan `config.measurements` (y opcionalmente `config.panels`) correctos.

### 2.2 ProductConfigurator (al guardar / previsualizar)

- **Archivo:** `src/pages/sales/ProductConfigurator.tsx` (bloque que arma `configSnapshot`).
- Antes de llamar al RPC o al fallback de insert:
  - Lee `panelsList` de `configAny.panels` (array).
  - `panelCount` = `configAny.measurements?.panel_count ?? panelsList.length || 1`.
  - `widthTotalMm` = `configAny.measurements?.width_total_mm ?? suma(panelsList[].width_mm)`.
  - Arma `measurements` con `height_mm`, `width_total_mm`, `panel_count`, `panels` (con `index`).
  - **BOM:** `width_mm` en config/snapshot debe ser **siempre** el ancho total (incluso con `panel_count === 1`). Por tanto: `widthMmForBom = config.width_mm` (que ya es total). No hay rama por panel_count.
  - Incluye en `configSnapshot`: `measurements`, `width_mm: widthTotalMm` (siempre total), `height_mm`, y el resto de campos.
- Ese `configSnapshot` es el que se envía en el RPC `create_configured_product_and_bom_preview` y se guarda en `ConfiguredProducts.config_snapshot`.

#### 2.2.1 Fuente de verdad (regla anti-bugs)

- **Fuente de verdad de panels = `measurements.panels`** (en config y en config_snapshot). No hay otra.
- `panels` al root (`config.panels` o `config_snapshot.panels`) es **opcional y solo fallback**; puede desaparecer para evitar duplicidad e inconsistencias.
- En lectura/UI: usar siempre `measurements.panels`; si no existe, fallback a `panels` al root.
- Si existe `config_snapshot.measurements`, es la fuente de verdad para `panel_count`, `width_total_mm` y `panels[]`.

### 2.3 Backend (RPC y BOM)

- **create_configured_product_and_bom_preview** (migración `20260207_bom_preview_width_total_panel_count.sql`):
  - Toma `v_width_mm` de `p_config_snapshot.measurements.width_total_mm` si existe, si no de `p_config_snapshot.width_mm`.
  - Inserta en `ConfiguredProducts` con ese `width_mm` (ancho total cuando hay varios paños).
- **build_bom_preview_snapshot** (misma migración):
  - Lee `v_config = config_snapshot` del ConfiguredProduct.
  - `v_panel_count` = `v_config.measurements.panel_count` (default 1).
  - `v_width_mm` = `v_config.measurements.width_total_mm` ?? `v_cp.width_mm` (ancho total).
  - Reglas BOM:
    - **Roll/fabric:** área = `v_width_mm * v_height_mm` (ancho total × altura).
    - **Tubo:** siempre per_width → longitud = `v_width_mm` (ancho total).
    - **Bottom bar:** per_width → longitud = `v_width_mm`.
    - **Headbox / Bottom channel:** por ancho total (qty = `v_width_mm` en m).

Si `config_snapshot` no trae `measurements` o `measurements.width_total_mm`, el backend usa solo `v_cp.width_mm` (que puede ser el de un solo paño si el front no envió total).

### 2.4 Commit a Quote Line

- **Archivo:** `src/lib/quotes/commitConfiguredProductToQuoteLine.ts`.
- Escribe en QuoteLine: `width_m`, `height_m` desde el ConfiguredProduct (que ya tiene `width_mm` = ancho total).
- **Regla:** QuoteLine **siempre** refleja ancho total y altura: `width_m` = ancho total (nunca solo panel 1). Alinea pricing y reportes.
- **No** escribe `panels` ni `measurements` en QuoteLines; eso vive solo en `ConfiguredProducts.config_snapshot`.

### 2.5 Visualización en lista y popup (QuoteNew)

- **Tabla de líneas:** dimensiones con `formatDimensionsDisplayCompact(source)`. El `source` se arma con `line.ConfiguredProduct?.config_snapshot` (y width_m/height_m de la línea si falta snapshot).
- **Cuándo mostrar desglose por paño:** detectar multi-panel con **`source.measurements?.panels?.length > 1`** o, en fallback, **`source.panels?.length > 1`**. No basarse solo en “existe config_snapshot.panels” (podría ser un array de 1 elemento).
- Si no hay ConfiguredProduct, o no hay multi-panel (length ≤ 1), usar `line.width_m` y `line.height_m` → un solo valor (ancho total × altura).
- **Popup:** mismo criterio: `formatDimensionsDisplay(source)` devuelve varias líneas (una por paño) solo cuando `source.measurements?.panels?.length > 1` o `source.panels?.length > 1`.

Para que se vean los paños por separado, la línea debe tener **ConfiguredProduct** con **config_snapshot.measurements.panels** (o `config_snapshot.panels`) con más de un elemento. `useQuotes` debe traer ConfiguredProducts con `config_snapshot`.

### 2.6 ReviewStep (paso QUOTE en el configurador)

- **Archivo:** `src/pages/sales/curtain-config/ReviewStep.tsx`.
- Dimensiones: usa `formatDimensionsDisplay(config)` y muestra cada línea del string (una por paño si hay varios).
- El `config` aquí es el estado actual del configurador; si ese estado tiene `config.panels` y `config.measurements` bien poblados, se ven los paños independientes.
- Total tela (m²): se toma del BOM snapshot (ítem roll/fabric).

### 2.7 Editar una línea existente (Edit Quote Line)

- **Archivo:** `src/pages/sales/QuoteNew.tsx`, efecto que hace `loadLineConfig` cuando `editingLineId` está definido.
- Al editar, el objetivo es **reconstruir el estado del configurador** con el mismo detalle con el que se creó la línea originalmente.
- Regla de carga:
  - Si existe `ConfiguredProduct.config_snapshot.measurements`, **se usa siempre** para inicializar `config.measurements` y `config.panels` (desde `measurements.panels`).
  - Si no existe (caso viejo), fallback: **1 panel** desde `QuoteLine.width_m/height_m`.
- **Regla al guardar:** aunque el usuario edite panels (2 o 3 paños), al commit: **QuoteLine.width_m** debe seguir siendo **ancho total**, no el ancho del panel 1. Alinea con pricing y reportes.
- Resultado: líneas multi-panel vuelven a abrir con 2 o 3 paños y el configurador no “colapsa” a 1 paño.

---

## 3. Resumen de puntos de fallo

| Dónde | Qué debe pasar | Qué puede fallar |
|-------|----------------|------------------|
| MeasurementsStep | Usuario define N paños y anchos; se guardan `panels` y `measurements` en config. | Correcto si no se pisa el estado. |
| ProductConfigurator (guardar) | Arma `configSnapshot` con `measurements` y `width_mm` = ancho total. | Si `config.panels` o `config.measurements` no existen (ej. viene de un draft antiguo), se usa un solo paño. |
| RPC create_configured_product | Lee `measurements.width_total_mm` y persiste en `ConfiguredProducts.width_mm`. | Si el front no envía `measurements`, el backend usa solo `width_mm` del root. |
| build_bom_preview_snapshot | Usa `measurements.width_total_mm` y `measurements.panel_count` del config_snapshot. | Si `config_snapshot.measurements` no existe, usa `v_cp.width_mm` y panel_count 1. |
| useQuotes (enriquecer líneas) | Adjunta ConfiguredProduct con `config_snapshot` a cada línea. | Si no se hace select de `config_snapshot` o no se asigna a la línea, tabla y popup no tienen panels. |
| loadLineConfig (editar línea) | Rellena `panels` y `measurements` desde ConfiguredProduct.config_snapshot (si existe). | Si no existe ConfiguredProduct/config_snapshot (caso viejo), debe hacer fallback a 1 panel derivado de QuoteLine. |

---

## 4. Formato de dimensiones en UI

- **Vista compacta (tabla Quote Lines):** muestra anchos por paño en una misma “celda” (stack) y el alto a la derecha del “x”.
  - Ej multi-panel: `1200 | 1500 x 3000` (mm)
  - Ej 1 panel: `2700 x 3000` (mm)
- **Vista detalle (popup / ReviewStep):** puede renderizar varias líneas (una por paño) si existen panels.
- Los m² totales de tela salen del BOM (ítem roll/fabric) y se muestran como “Total tela” + valor con unidad (ej. `4.80 m²`) donde corresponda.

---

## 5. Qué hacer para que los paneles funcionen al editar

1. **Al abrir Edit Quote Line:** además de cargar la QuoteLine, cargar el **ConfiguredProduct** de esa línea (por `configured_product_id`).
2. Si el ConfiguredProduct tiene `config_snapshot.measurements`:
   - Inicializar con **`measurements` = `config_snapshot.measurements`** (fuente de verdad). Los panels vienen de **`measurements.panels`** (o `config_snapshot.panels` solo como fallback).
   - Así MeasurementsStep verá 2 o 3 paños y los mostrará por separado.
3. Si no hay ConfiguredProduct o no hay `measurements` (caso viejo), derivar **1 panel** desde `lineData.width_m` y `lineData.height_m`.

### 5.1 Nota de performance / reporting (opcional)

- **No necesitas columnas por panel.**
- Si más adelante quieres filtros o reportes rápidos, puedes considerar:
  - persistir/idx `panel_count`
  - persistir/idx `width_total_mm`
  - (sin abandonar `config_snapshot.measurements` como fuente de verdad)

---

## 6. Invariantes del sistema

Reglas que no deben romperse en edición, BOM ni UI:

1. **`config.width_mm` siempre = ancho total** (nunca solo panel 1).
2. **Si `panel_count > 1`:** templates/validaciones pensadas para un solo paño se descartan o no aplican.
3. **Fuente de verdad de panels = `measurements.panels`** (root `panels` es opcional y puede desaparecer).
4. **QuoteLine guarda total** (`width_m`, `height_m`); **ConfiguredProduct guarda detalle** (`config_snapshot.measurements` con `panels`).

Con esto, el comportamiento de los paneles queda alineado en captura, guardado, BOM y edición, y el documento sirve como referencia detallada del flujo.
