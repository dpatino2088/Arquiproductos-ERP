# 📊 Análisis: Items con measure_basis=linear_m

## Estado Actual

Según el CSV proporcionado, hay **128 items** con `measure_basis=linear_m`:

### Distribución de UOM:
- **FT (feet)**: ~120 items (válido, pero inconsistente)
- **M (meters)**: ~8 items (válido y consistente)

### Validación:
✅ **Todos los items son válidos** según `validate_uom_measure_basis()`:
- `linear_m` acepta: `m`, `ft`, `yd` (unidades de longitud)
- `FT` es válido para `linear_m`

## Recomendación

### Opción 1: Mantener FT (Actual)
- ✅ **Ventaja**: No requiere cambios
- ✅ **Ventaja**: Respeta UOM original de los items
- ⚠️ **Desventaja**: Inconsistencia (algunos en FT, otros en M)

### Opción 2: Normalizar FT → M (Recomendado)
- ✅ **Ventaja**: Consistencia total (todos en M)
- ✅ **Ventaja**: Facilita cálculos y reportes
- ⚠️ **Consideración**: Si `cost_exw` está en "por pie", necesita conversión:
  - `cost_exw_m = cost_exw_ft / 3.28084`

## Scripts Disponibles

1. **`FIX_INVALID_UOM_MEASURE_BASIS.sql`**
   - Corrige items inválidos (PCS → m)
   - **Ejecutar**: ✅ SÍ (corrige errores)

2. **`NORMALIZE_FT_TO_M_FOR_LINEAR_ITEMS.sql`**
   - Normaliza FT → M (opcional)
   - **Ejecutar**: ⚠️ OPCIONAL (solo si quieres consistencia)

3. **`FIX_BACKFILL_FORMAT_ERROR.sql`**
   - Corrige error de formato en backfill
   - **Ejecutar**: ✅ SÍ (corrige errores)

## Decisión Recomendada

**Para items con FT:**
- Si `cost_exw` está en "por metro" → Solo cambiar UOM a `m`
- Si `cost_exw` está en "por pie" → Cambiar UOM a `m` Y convertir costo

**Verificar antes de normalizar:**
```sql
-- Ver algunos ejemplos de costos
SELECT sku, item_name, uom, cost_exw, cost_uom
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
AND deleted = false
LIMIT 10;
```

Si `cost_uom` es `FT` o similar, entonces `cost_exw` está en "por pie" y necesita conversión.





