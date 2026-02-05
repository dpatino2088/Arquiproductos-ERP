# Dump 2026-02_04_V2_full.sql – Estado y limpieza

## Resumen

El dump **V2** refleja el esquema después de eliminar tablas BOM legacy y parte de las columnas redundantes de `ConfiguredProducts`. Siguen aplicables migraciones para quitar la última columna redundante y rellenar totales en cero.

---

## Tablas que ya NO están en V2

- **BOMInstances** – Eliminadas (flujo pasa por `ConfiguredProducts.bom_preview_snapshot`).
- **BOMInstanceLines** – Eliminadas (los totales BOM viven en `ConfiguredProducts` y en el snapshot).

Las funciones del dump que aún mencionan `BOMInstances` / `BOMInstanceLines` corresponden a código legacy; si esas tablas se han dropeado con `20260204_drop_bom_instances_tables.sql`, esas funciones ya no se usan o deben estar eliminadas/actualizadas en migraciones posteriores.

---

## ConfiguredProducts en V2

### Columnas en el dump V2

- Identidad: `id`, `organization_id`, `quote_id`, `bom_template_id`, `product_type_id`
- Medidas: `width_mm`, `height_mm`, `quantity`
- Roll: `roll_catalog_item_id`, `roll_sku`, `roll_collection_name`, `roll_variant_name`, `roll_width`
- **Totales (a veces en cero si no se persistieron desde snapshot):**
  - `roll_msrp_total`, `roll_plus_bom_total`, `bom_total`, `total_msrp`
  - `roll_total_cost`, `bom_total_cost`, `labor_amount`, `accessories_total`
- Otros: `hardware_color`, `labor_pct`, `config_snapshot`, `bom_preview_snapshot`, `created_at`, `updated_at`, `deleted`
- **Redundante en V2:** `motor_sku` (ya está en `config_snapshot`)

### Columnas ya eliminadas por migraciones (no en V2 o a eliminar después de V2)

Eliminadas en `20260204_fix_quoteline_zero_msrp.sql`:

- `headbox_item_id`, `headbox_sku`, `side_channel_*`, `bottom_channel_*`, `bottom_bar_*`, `motor_item_id`, `motor_item_sku`, `drive_*`, `tube_*`, `operating_type`

Si en tu instancia el dump V2 aún tiene `motor_sku`, se elimina con:

- **20260204_configured_products_drop_motor_sku_backfill_totals.sql**

---

## “Varios total cost” y “columnas en cero”

- **Varios totales:** En `ConfiguredProducts` los totales están en columnas (`roll_msrp_total`, `bom_total`, `total_msrp`, `roll_total_cost`, `bom_total_cost`, `labor_amount`, `accessories_total`) y además en `bom_preview_snapshot.totals`. La fuente de verdad es el snapshot; las columnas son copia para consultas y para `commit_configured_product_to_quote_line`.
- **Ceros:** Filas creadas antes de persistir desde `bom_preview_snapshot` (o con snapshot vacío) pueden tener esas columnas en 0. La migración **20260204_configured_products_drop_motor_sku_backfill_totals.sql** hace **backfill** desde `bom_preview_snapshot.totals` cuando hay snapshot válido y el total correspondiente está en 0.

---

## Orden sugerido de migraciones (respecto al dump V2)

1. **20260204_fix_quoteline_zero_msrp.sql** – Persistir totales en `create_configured_product_and_bom_preview`, leer componentes desde `config_snapshot`, eliminar columnas de componentes (headbox, side_channel, etc.) y actualizar `commit` para `operating_type` solo desde `config_snapshot`.
2. **20260204_configured_products_drop_motor_sku_backfill_totals.sql** – Eliminar `motor_sku` y rellenar totales en cero desde `bom_preview_snapshot`.

Con eso, el esquema queda alineado con el dump V2 sin redundantes de componentes y con totales rellenados donde el snapshot lo permita.
