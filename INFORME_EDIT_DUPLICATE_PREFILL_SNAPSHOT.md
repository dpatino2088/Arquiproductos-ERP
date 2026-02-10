# Edit / Duplicate: prefill desde config_snapshot

**Objetivo:** Al **Editar** o **Duplicar** una línea de cotización, el configurador debe abrir con todas las cards ya seleccionadas (color, Bottom Bar, Headbox, etc.) usando la data guardada en el snapshot. No tiene sentido duplicar si el usuario tiene que rellenar todo de nuevo.

---

## 1. Dónde está la data (schema)

- **ConfiguredProducts** no tiene columnas propias para Bottom Bar, Headbox, Side Channel, etc.
- Toda esa configuración se guarda en el **JSON** `config_snapshot` (columna JSONB).
- Al guardar (Add to Quote / Save en Edit), el front envía un objeto con claves en **snake_case** y el RPC `create_configured_product_and_bom_preview` lo persiste tal cual en `config_snapshot`.

Claves relevantes dentro de `config_snapshot`:

| Clave | Uso |
|-------|-----|
| `hardware_color` / `hardwareColor` | Color (White, Black, Silver) |
| `bottom_bar_item_id`, `bottom_bar_sku` | Bottom Bar |
| `headbox_item_id`, `headbox_sku` | Headbox / Cassette |
| `side_channel_item_id`, `side_channel_sku` | Side Channel |
| `bottom_channel_item_id`, `bottom_channel_sku` | Bottom Channel |
| `tube_item_id`, `tube_sku` | Tube |
| `drive_item_id`, `drive_sku` | Drive (manual) |
| `motor_item_id`, `motor_sku` | Motor |
| `operation_type`, `drive_type` | Tipo de operación |

---

## 2. Flujo al abrir Edit o Duplicate

1. **QuoteNew** llama a `getConfigFromQuoteLine({ lineId, forEdit: true|false })`.
2. Se carga la **QuoteLine** y, si tiene `configured_product_id`, el **ConfiguredProduct** (solo columnas: `id`, `config_snapshot`, `hardware_color`).
3. Se arma el config base desde la QuoteLine (product_type, medidas, variante, etc.).
4. Si hay CP, se hace **merge desde `config_snapshot`** (snake + camel) sobre ese config: `bottom_bar_sku`, `bottom_bar_item_id`, `hardware_color`, headbox, side_channel, bottom_channel, tube, drive, motor, etc.
5. Se devuelve ese config y QuoteNew hace `setInitialLineConfig(config)` y abre el modal con `initialConfig={config}`.

---

## 3. Cómo se usa el config en el configurador

- **ProductConfigurator** recibe `initialConfig` y lo usa como estado inicial de `config`.
- Se añadió un **efecto** que, si `initialConfig` trae claves del snapshot y en el estado faltan, las rellena (para evitar pérdida por timing).
- En **handleUpdate** (cada vez que un paso hace `onUpdate`), se **preservan** las claves del snapshot: si el update no las manda o las manda a `undefined`, se mantiene el valor anterior. Así no se pierden al cambiar de paso o al actualizar solo una parte del config.
- **HardwareStep** (y demás pasos) leen `config.bottom_bar_sku`, `config.hardware_color`, etc., y marcan como seleccionada la card que coincida por `id` o por `sku` (normalizado).

---

## 4. Archivos tocados (resumen)

| Archivo | Qué hace |
|---------|----------|
| `src/lib/quotes/getConfigFromQuoteLine.ts` | Carga QuoteLine + CP; merge desde `config_snapshot` (snake + camel); solo SELECT `id, config_snapshot, hardware_color` (no hay columnas bottom_bar_* en la tabla). |
| `src/pages/sales/QuoteNew.tsx` | Edit: efecto que llama `getConfigFromQuoteLine` y pone el resultado en `initialLineConfig`. Duplicate: mismo get, quita `quote_line_id` y abre modal. |
| `src/pages/sales/ProductConfigurator.tsx` | Aplica claves del snapshot al montar si faltan; en `handleUpdate` preserva esas claves; carry-over de hardware/bottom_bar al objeto que se pasa a `onComplete`. |
| `src/pages/sales/curtain-config/HardwareStep.tsx` | `savedSku`/`savedId` desde `config`; `isSelected` por id o SKU; opción "pinned" si el SKU guardado no está en las opciones filtradas. |
| `src/pages/sales/QuoteNew.tsx` (buildConfigSnapshotFromProductConfig) | Construye el objeto que se envía al RPC con `bottom_bar_item_id`, `bottom_bar_sku`, `hardware_color`, etc., para que se persistan en `config_snapshot`. |

---

## 5. Cómo comprobar que funciona

1. **Edit:** Abrir una cotización → Editar una línea que ya tenga color y Bottom Bar guardados → Ir al paso Hardware. Debe verse el color y el Bottom Bar ya seleccionados.
2. **Duplicate:** Duplicar esa misma línea → Abrir el configurador. Debe verse el mismo prefill (color + Bottom Bar y resto de hardware si aplica).
3. **Después de guardar Edit:** Guardar sin cambiar nada y volver a editar la misma línea. Las selecciones deben seguir igual.

---

## 6. Si una línea no muestra prefill

- Esa línea puede tener el **ConfiguredProduct** con `config_snapshot` vacío o antiguo (p. ej. creada antes de estos cambios).
- Comprobar en base de datos:

```sql
SELECT
  ql.id AS quote_line_id,
  ql.configured_product_id,
  cp.config_snapshot IS NOT NULL AS has_snapshot,
  cp.config_snapshot->>'bottom_bar_sku' AS snapshot_bottom_bar_sku,
  cp.config_snapshot->>'bottom_bar_item_id' AS snapshot_bottom_bar_item_id,
  cp.config_snapshot->>'hardware_color' AS snapshot_hardware_color
FROM public."QuoteLines" ql
LEFT JOIN public."ConfiguredProducts" cp ON cp.id = ql.configured_product_id
WHERE ql.id = 'ID_DE_LA_LINEA';
```

- Si `has_snapshot` es true y los campos `snapshot_*` tienen valor, el prefill debería verse. Si no, la línea se creó/guardó sin rellenar bien el snapshot; **guardar una vez desde el configurador actual** (sin cambiar nada) suele rellenar el snapshot para la próxima vez.

---

## 7. Resumen para el equipo

- **Todo el hardware y componentes** (Bottom Bar, Headbox, color, tube, drive, motor, etc.) viven en el **JSON `config_snapshot`** del ConfiguredProduct. No hay columnas propias para ellos.
- **Edit y Duplicate** cargan ese snapshot vía `getConfigFromQuoteLine` y lo inyectan en el estado del configurador.
- El configurador **preserva** esas claves al hacer merge en `handleUpdate` y aplica las que falten al montar, para que las **cards salgan ya seleccionadas** y no haya que rellenar todo de nuevo al duplicar.
