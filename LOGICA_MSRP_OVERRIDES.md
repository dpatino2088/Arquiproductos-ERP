# Lógica de MSRP por Categoría

## Conceptos Clave

### Margen sobre Venta (NO Markup)
- **Margen sobre venta**: El margen se calcula como porcentaje del precio de venta
- **Fórmula**: `Precio = Costo / (1 - Margen%)`
- **Ejemplo**: Costo $100, Margen 35% → Precio = $100 / 0.65 = $153.85

### Tablas Principales

1. **CategoryMargins** (FUENTE DE VERDAD - por categoría)
   - `msrp_pct_sale_in`: % margen para MSRP Sale-In (precio distribuidor/interno)
   - `msrp_pct_sale_out`: % margen para MSRP Sale-Out (precio público)
   - **TODOS los items de una categoría usan estos valores**

2. **CostSettings** (1 row por organización - valores globales de fallback)
   - `shipping_pct`: % de envío sobre cost_exw
   - `global_import_tax_pct`: % impuesto importación global
   - `minimum_margin_pct`: Fallback para msrp_pct_sale_in si no hay CategoryMargin
   - `default_msrp_pct_sale_out`: Fallback para msrp_pct_sale_out si no hay CategoryMargin

3. **CatalogItemsMSRP** (CACHE de resultados - NO guarda porcentajes)
   - Campos calculados (auto-update por trigger):
     - `cost_exw`, `import_tax_cost`, `shipping_cost`, `total_cost`
     - `msrp_sale_in`, `msrp_sale_out`
   - También guarda los porcentajes usados para el cálculo (para referencia):
     - `import_tax_pct`, `shipping_pct`, `minimum_margin_pct`, `msrp_pct_sale_out`

4. **ImportTaxRules** (override por categoría)
   - `import_tax_pct` por category_id
   - Prioridad: ImportTaxRules > CostSettings.global_import_tax_pct

## Flujo de Cálculo

### Resolución de Valores (Prioridad)

**Shipping %:**
1. `CostSettings.shipping_pct` (global)
2. `0` (fallback)

**Import Tax %:**
1. `ImportTaxRules.import_tax_pct` (por categoría)
2. `CostSettings.global_import_tax_pct` (global)
3. `0` (fallback)

**MSRP % Sale-In (para Sale-In):**
1. `CategoryMargins.msrp_pct_sale_in` (por categoría) ⭐ FUENTE DE VERDAD
2. `CostSettings.minimum_margin_pct` (global fallback)
3. `0.35` (fallback hardcoded = 35%)

**MSRP % Sale Out:**
1. `CategoryMargins.msrp_pct_sale_out` (por categoría) ⭐ FUENTE DE VERDAD
2. `CostSettings.default_msrp_pct_sale_out` (global fallback)
3. `0.65` (fallback hardcoded = 65%)

### Fórmulas de Cálculo

```
1. import_tax_cost = cost_exw × import_tax_pct
2. shipping_cost = cost_exw × shipping_pct
3. total_cost = cost_exw + import_tax_cost + shipping_cost
4. msrp_sale_in = total_cost ÷ (1 - minimum_margin_pct)     [margin-on-sale]
5. msrp_sale_out = msrp_sale_in ÷ (1 - msrp_pct_sale_out)   [margin-on-sale]
```

### Ejemplo Completo

**Datos:**
- cost_exw = $100
- shipping_pct = 15% (0.15)
- import_tax_pct = 6% (0.06)
- minimum_margin_pct = 35% (0.35)
- msrp_pct_sale_out = 65% (0.65)

**Cálculo:**
```
import_tax_cost = 100 × 0.06 = $6.00
shipping_cost = 100 × 0.15 = $15.00
total_cost = 100 + 6 + 15 = $121.00

msrp_sale_in = 121 ÷ (1 - 0.35) = 121 ÷ 0.65 = $186.15
msrp_sale_out = 186.15 ÷ (1 - 0.65) = 186.15 ÷ 0.35 = $531.86
```

## UI Behavior

### Settings > Cost Engine > Cost Engine Defaults
- Muestra valores globales (fallback cuando no hay CategoryMargin)
- Campo "MSRP % Sale Out (Global)": default 65%
- Al cambiar y guardar: actualiza `CostSettings.default_msrp_pct_sale_out`
- Trigger recalcula todos los items que NO tienen CategoryMargin

### Settings > Cost Engine > Category Margins ⭐ FUENTE DE VERDAD
- Lista todas las categorías
- Por cada categoría, editar:
  - **MSRP % Sale-In**: margen para calcular precio distribuidor/interno
  - **MSRP % Sale Out**: margen para calcular precio público
- Al guardar: trigger `trg_categorymargins_recompute_msrp` recalcula todos los items de esa categoría
- **Todos los items de una categoría usan los mismos porcentajes**

### Catalog > Items > Edit > Rates Tab

**Solo Preview (no editable):**
- Muestra cálculo de MSRP basado en:
  - `cost_exw` del item
  - Porcentajes de la categoría (desde `CategoryMargins`)
  - Fallback a `CostSettings` si no hay CategoryMargin
- Preview en tiempo real
- Mensaje: "Para cambiar porcentajes, ir a Settings → Cost Engine → Category Margins"

## Database Triggers

### `catalogitemsmsrp_recalc()`
- Trigger: BEFORE INSERT OR UPDATE en `CatalogItemsMSRP`
- Recalcula: `import_tax_cost`, `shipping_cost`, `total_cost`, `msrp_sale_in`, `msrp_sale_out`
- **CRÍTICO**: NO sobrescribe `msrp_pct_sale_out` (preserva NULL o valor)

### `recalc_catalog_item_msrp(p_catalog_item_id)`
- Función: recalcula MSRP para un item específico
- Lee overrides existentes de `CatalogItemsMSRP`
- Usa global de `CostSettings` si override es NULL
- Actualiza campos calculados, preserva overrides

### `trg_catalogitems_cost_exw_recalc_msrp`
- Trigger: AFTER INSERT OR UPDATE en `CatalogItems`
- Cuando cambia `cost_exw` o `category_id`
- Llama a `recalc_catalog_item_msrp()`

### `trg_costsettings_recalc_all_msrp`
- Trigger: AFTER UPDATE en `CostSettings`
- Cuando cambian: `shipping_pct`, `global_import_tax_pct`, `minimum_margin_pct`, `default_msrp_pct_sale_out`
- Recalcula MSRP de todos los items activos de la organización
- Respeta overrides existentes (solo afecta items sin override)

## Descuentos por Tipo de Cliente

Los descuentos (`distributor_discount_pct`, `reseller_discount_pct`, `partner_discount_pct`, `vip_discount_pct`) son SOLO para QuoteLines, NO se usan para calcular MSRP.

### Fórmula de Precio con Descuento (QuoteLines)
```
precio_final = msrp_sale_out × (1 - discount_pct)
```

**MSRP es INDEPENDIENTE de los descuentos comerciales.**
