# Esquema UI ↔ DB: Edit Item / Rates

## Resumen

En **Catalog → Edit Item → Rates** se muestran costes y MSRP. Estas son las tablas y columnas que usa el UI y deben existir en la DB.

---

## Tablas y columnas

### 1. CostSettings (por organización)

| Columna DB              | Uso en UI / Fórmula |
|-------------------------|----------------------|
| `shipping_pct`          | Shipping = cost_exw × shipping_pct |
| `global_import_tax_pct` | Import Tax % cuando no hay regla por categoría. Import Tax = cost_exw × import_tax_pct |
| `import_tax_pct`        | **Generada** como `global_import_tax_pct`. Corrige `column cs.import_tax_pct does not exist`. |
| `default_margin_pct`    | **Añadida** (backfill desde `minimum_margin_pct`). Corrige `cs.default_margin_pct`. |
| `msrp_pct_sale_out`     | **Generada** desde `default_msrp_pct_sale_out`. Corrige `cs.msrp_pct_sale_out`. |
| `minimum_margin_pct`    | Fallback para "Minimum Margin %" si CategoryMargins no define la categoría |
| `default_msrp_pct_sale_out` | Fallback para "MSRP % Sale Out" si CategoryMargins no define la categoría |

### 2. ImportTaxRules (por categoría)

| Columna DB      | Uso en UI |
|-----------------|-----------|
| `organization_id` | Filtro |
| `category_id`   | Coincide con `CatalogItems.category_id` para elegir la regla |
| `import_tax_pct` | Override de `CostSettings.global_import_tax_pct` para esa categoría |

Prioridad: `ImportTaxRules.import_tax_pct` (por categoría) > `CostSettings.global_import_tax_pct`.

### 3. CategoryMargins (por categoría, alias `cm`)

| Columna DB           | Uso en UI |
|----------------------|-----------|
| `msrp_pct_sale_in`   | "Minimum Margin %" (margin-on-sale). Sale In = Total Cost / (1 - msrp_pct_sale_in) |
| `minimum_margin_pct` | **Generada** desde `msrp_pct_sale_in`. Corrige `cm.minimum_margin_pct`. |
| `msrp_pct_sale_out`  | "MSRP % Sale Out". Sale Out = Sale In / (1 - msrp_pct_sale_out) |

Si no hay fila para la categoría: se usan `CostSettings.minimum_margin_pct` y `CostSettings.default_msrp_pct_sale_out`.

### 4. CatalogItems (por ítem)

| Columna DB   | Uso en Rates |
|--------------|--------------|
| `cost_exw`   | Base para Import Tax, Shipping y Total Cost |
| `category_id`| Para buscar ImportTaxRules y CategoryMargins |

### 5. CatalogItemsMSRP (caché calculada)

Rellenada por `msrp_compute_for_item` (trigger al cambiar `cost_exw` o `category_id`). El UI de Rates hace un **preview** con CostSettings, ImportTaxRules y CategoryMargins; no depende de CatalogItemsMSRP para el cálculo en vivo, pero el resto de la app sí.

---

## Fórmulas (preview en Rates)

- **Import Tax** = `cost_exw × import_tax_pct`  
  (`import_tax_pct` = regla por categoría o `global_import_tax_pct`)

- **Shipping** = `cost_exw × shipping_pct`

- **Total Cost** (simplificado en el preview) =  
  `cost_exw × (1 + import_tax_pct + shipping_pct)`  
  (en DB: `cost_exw + shipping_cost + import_tax_cost`; shipping e import tax se calculan con sus propias fórmulas.)

- **MSRP Sale In** = `Total Cost / (1 - Minimum Margin %)`

- **MSRP Sale Out** = `Sale In / (1 - MSRP % Sale Out)`

---

## Cambios realizados (2026-01-29)

1. **Migración `20260129_add_import_tax_pct_to_cost_settings.sql`**  
   - **CostSettings (cs):** `import_tax_pct`, `default_margin_pct`, `msrp_pct_sale_out`.  
   - **CategoryMargins (cm):** `minimum_margin_pct` (generada desde `msrp_pct_sale_in`). Corrige `cm.minimum_margin_pct`.

2. **`useCatalogItemById`**  
   Se eliminó `.eq('archived', false)` porque **CatalogItems** no tiene columna `archived` (solo `is_active`).

---

## Cómo aplicar la migración

```bash
# Con Supabase CLI (o el cliente SQL que uses)
psql $DATABASE_URL -f database/migrations/20260129_add_import_tax_pct_to_cost_settings.sql
```

O ejecutar el contenido del archivo en el SQL Editor de Supabase.
