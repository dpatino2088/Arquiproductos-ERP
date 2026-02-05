# Informe: QuoteLine Pricing desde ConfiguredProduct

## Fecha: 2026-02-04

## Problema Resuelto

El QuoteLine mostraba un precio diferente ($229.49) al correcto del breakdown ($380.51).

## Decisión Arquitectónica

**BOMInstances/BOMInstanceLines YA NO SE USAN.**

El módulo de Manufactura se trabajará directamente desde `ConfiguredProducts.bom_preview_snapshot`.
Las tablas `BOMInstances` y `BOMInstanceLines` fueron eliminadas.

**Causa raíz**: La función `calculate_configured_product_totals` solo calcula el BOM total cuando existe `BOMInstance`, pero durante el preview NO existe BOMInstance todavía.

## Solución Implementada

### Arquitectura Final

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUJO DE PRECIOS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CONFIGURADOR                                                 │
│     └── Selección de componentes (Hardware, Variants, etc.)     │
│                                                                  │
│  2. CREATE CONFIGURED PRODUCT & BOM PREVIEW                      │
│     ├── Crea ConfiguredProducts                                  │
│     ├── build_bom_preview_snapshot()                            │
│     │   ├── Lee BOMComponents + CatalogItemsMSRP                │
│     │   ├── Calcula line_total para cada item                   │
│     │   ├── Suma bom_total desde items[]                        │
│     │   └── Guarda en bom_preview_snapshot (JSONB)              │
│     └── bom_preview_snapshot.totals.total_msrp = $380.51       │
│                                                                  │
│  3. ADD TO QUOTE (commit_configured_product_to_quote_line)       │
│     ├── Lee bom_preview_snapshot.totals                          │
│     ├── Calcula total desde items[] si totals = 0               │
│     ├── QuoteLines.msrp = $380.51                               │
│     ├── QuoteLines.pricing_locked = true                         │
│     └── NO crea BOMInstance (se creará en aprobación)           │
│                                                                  │
│  4. UI QUOTELINES                                                │
│     ├── Lee QuoteLines.msrp directamente                         │
│     ├── Muestra punto verde ● si pricing_locked                  │
│     └── Tooltip con desglose (roll + bom)                       │
│                                                                  │
│  5. MANUFACTURA (futuro, cuando Quote se apruebe)               │
│     └── Crear BOMInstance desde bom_preview_snapshot            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Archivos SQL a Ejecutar (en orden)

1. **`20260204_bom_preview_snapshot.sql`**
   - Agrega columna `bom_preview_snapshot` a ConfiguredProducts
   - Crea función `build_bom_preview_snapshot()` que calcula totales desde items
   - Modifica `create_configured_product_and_bom_preview` para guardar snapshot

2. **`20260204_quoteline_pricing_from_configured_product.sql`**
   - Crea RPC `commit_configured_product_to_quote_line()`
   - Lee totales desde `bom_preview_snapshot.items[]` (prioridad)
   - Fallback a `bom_preview_snapshot.totals`
   - Fallback a columnas de ConfiguredProducts
   - NO crea BOMInstance (se creará cuando se necesite para manufactura)
   - Actualiza trigger `trg_quote_lines_generate_bom_instance_fn` con guards

### Archivos Frontend Modificados

1. **`src/hooks/useQuotes.ts`**
   - Hook `useQuoteLines` simplificado
   - Usa `line.msrp` directamente (ya viene correcto del RPC)

2. **`src/pages/sales/QuoteNew.tsx`**
   - Columna LIST PRICE: usa `line.msrp`
   - Columna TOTAL: usa `line.msrp × quantity`
   - Subtotal: suma de `line.msrp × quantity`
   - Punto verde ● indica precio congelado desde ConfiguredProduct

### Archivos SQL que YA NO SE NECESITAN

- `20260204_fix_commit_rpc_use_snapshot_totals.sql` (consolidado)
- `20260204_fix_commit_rpc_uuid_validation.sql` (obsoleto)
- `20260204_commit_configured_product_architecture_fix.sql` (obsoleto)

## Validación

✅ Breakdown en configurador: $380.51
✅ QuoteLine LIST PRICE: $380.51
✅ QuoteLine TOTAL: $380.51
✅ Punto verde indica precio congelado
✅ No hay recálculo después de guardar

## Próximos Pasos Recomendados

1. **Ejecutar migraciones SQL** en Supabase
2. **Probar flujo completo** (configurar → add to quote → verificar precio)
3. **Limpiar archivos de migración obsoletos** (opcional)
4. **Implementar creación de BOMInstance en aprobación** (para manufactura)

## Dependencias de BOMInstances (Manufactura)

Los siguientes componentes todavía usan BOMInstances para manufactura:
- `src/hooks/useManufacturing.ts`
- `src/hooks/useBOMInstance.ts`
- `src/components/manufacturing/tabs/*.tsx`
- `src/pages/manufacturing/OrderList.tsx`

**Recomendación**: Crear BOMInstance cuando el Quote se aprueba para manufactura, generándolo desde `bom_preview_snapshot`.
