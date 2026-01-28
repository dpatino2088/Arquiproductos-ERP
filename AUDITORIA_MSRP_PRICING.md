# Auditoría de Pricing Architecture - MSRP vs Customer Discounts

## Estado Actual (según DB dump 2026-01-14)

### Tabla `CatalogItemsMSRP` - Columnas reales:
```sql
CREATE TABLE "CatalogItemsMSRP" (
    catalog_item_id uuid NOT NULL (PK),
    organization_id uuid NOT NULL,
    category_id uuid,
    cost_exw numeric(12,4) NOT NULL,
    import_tax_pct numeric(7,4) NOT NULL,
    shipping_pct numeric(7,4) NOT NULL,
    minimum_margin_pct numeric(7,4) NOT NULL,
    msrp_pct numeric(7,4) NOT NULL,  -- ❌ PROBLEMA: se usa como anchor_discount_pct (distributor)
    import_tax_cost numeric(12,4) NOT NULL,
    shipping_cost numeric(12,4) NOT NULL,
    total_cost numeric(12,4) NOT NULL,
    msrp_sale_in numeric(12,4) NOT NULL,
    msrp_sale_out numeric(12,4) NOT NULL
)
```

### Función `recalc_catalog_item_msrp` - Lógica actual:
```sql
-- Cálculo INCORRECTO actual:
v_sale_in := v_total_cost / (1 - v_min_margin_pct);
v_sale_out := v_sale_in / (1 - v_distributor_disc);  -- ❌ USA DESCUENTO DE CLIENTE

-- Guarda en msrp_pct el anchor_discount_pct (distributor_discount_pct)
-- Esto es CONCEPTUALMENTE INCORRECTO
```

### Tabla `CostSettings` - Descuentos por customer_type:
```sql
distributor_discount_pct numeric(7,4)
reseller_discount_pct numeric(7,4)
partner_discount_pct numeric(7,4)
vip_discount_pct numeric(7,4)
```

## Arquitectura CORRECTA (target)

### MSRP debe ser independiente de customer type:
```sql
total_cost = cost_exw + import_tax_cost + shipping_cost
msrp_sale_out = total_cost * (1 + msrp_pct_sale_out)  -- ✅ NO usa discounts
```

### Customer discounts se aplican SOLO en QuoteLines:
```sql
unit_price = msrp_sale_out * (1 - customer_discount_pct)
donde customer_discount_pct viene de CostSettings según customer_type de la Company
```

## Plan de Corrección

### Opción A: Renombrar `msrp_pct` conceptualmente
- Interpretar `msrp_pct` como el markup/margin para MSRP (no como discount)
- Actualizar función `recalc_catalog_item_msrp` para NO usar distributor_discount_pct
- Usar `msrp_pct` = margin/markup percentage para Sale Out

### Opción B: Agregar nueva columna `msrp_markup_pct`
- Agregar `msrp_markup_pct` a CatalogItemsMSRP
- Mantener `msrp_pct` como está (legacy)
- Usar `msrp_markup_pct` para calcular Sale Out

## Cambios Necesarios (mínimos)

### 1. DB Migration:
```sql
-- Si se usa Opción A (renombrar conceptualmente):
-- NO se necesita migration, solo actualizar la función

-- Si se usa Opción B (nueva columna):
ALTER TABLE public."CatalogItemsMSRP"
ADD COLUMN IF NOT EXISTS msrp_markup_pct numeric(7,4) DEFAULT 0.35;

-- Backfill initial values
UPDATE public."CatalogItemsMSRP"
SET msrp_markup_pct = 0.35  -- o calcular desde minimum_margin_pct
WHERE msrp_markup_pct IS NULL OR msrp_markup_pct = 0;
```

### 2. Función `recalc_catalog_item_msrp`:
```sql
-- Cambiar de:
v_sale_out := v_sale_in / (1 - v_distributor_disc);

-- A:
v_sale_out := v_total_cost * (1 + v_msrp_markup_pct);
-- donde v_msrp_markup_pct viene de CategoryMargins.default_margin_pct o un valor por defecto
```

### 3. Frontend (UI Rates tab):
- NO cambiar visualmente
- Solo asegurar que el preview use la fórmula correcta (sin distributor discount)

### 4. QuoteLines pricing:
- Asegurar que aplique customer discount SOLO en QuoteLines
- NO en CatalogItemsMSRP

## Próximos Pasos
1. Usuario confirma qué opción prefiere (A o B)
2. Crear migration SQL
3. Actualizar función recalc_catalog_item_msrp
4. Actualizar frontend preview (solo cálculo, no UI)
5. Testing end-to-end
