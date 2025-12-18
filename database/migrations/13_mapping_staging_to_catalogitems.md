# Mapeo de Columnas: _stg_catalog_items → CatalogItems

## Columnas Identificadas en la Tabla Temporal (_stg_catalog_items)

Basado en las imágenes proporcionadas, estas son las columnas exactas:

1. `sku` (text)
2. `collection` (text)
3. `variant_name` (text)
4. `item_name` (text)
5. `item_description` (text)
6. `cost_price_exw` (numeric) → se mapea a `cost_exw`
7. `item_type` (text)
8. `roll_width_m` (numeric)
9. `measure_basis` (text)
10. `uom` (text)
11. `is_fabric` (bool)
12. `active` (bool)
13. `discontinued` (bool)
14. `manufacturer` (text)
15. `category` (text)
16. `family` (text)
17. `description` (text)

## Mapeo a CatalogItems

| Tabla Temporal (_stg_catalog_items) | CatalogItems | Notas |
|--------------------------------------|--------------|-------|
| `sku` | `sku` | Directo |
| `item_name` | `item_name` | Directo |
| `item_description` | `description` | Mapeo directo |
| `variant_name` | `variant_name` | Directo (solo para fabrics) |
| `collection` | `collection_name` | **DIRECTO** - sin FK, se almacena el nombre como texto |
| `manufacturer` | `manufacturer_id` | Necesita JOIN con Manufacturers |
| `category` | `item_category_id` | Necesita JOIN con ItemCategories |
| `item_type` | `item_type` | Directo |
| `measure_basis` | `measure_basis` | Directo |
| `uom` | `uom` | Directo |
| `is_fabric` | `is_fabric` | Conversión de texto a boolean |
| `roll_width_m` | `roll_width_m` | Directo (puede ser NULL) |
| `cost_price_exw` | `cost_exw` | Directo - mapeo de `cost_price_exw` (staging) → `cost_exw` (CatalogItems) |
| `active` | `active` | Conversión de texto a boolean |
| `discontinued` | `discontinued` | Conversión de texto a boolean |
| `family` | - | **NO SE MAPEA** (no existe en CatalogItems) |
| `description` | - | **Ya mapeado como `item_description` → `description`** |

## Columnas Adicionales en CatalogItems (no vienen del staging)

Estas columnas se generan automáticamente o tienen valores por defecto:

- `id` → `gen_random_uuid()`
- `organization_id` → Valor fijo: `'4de856e8-36ce-480a-952b-a2f5083c69d6'`
- `fabric_pricing_mode` → NULL (no viene del staging)
- `unit_price` → 0 (default)
- `metadata` → `'{}'::jsonb` (default)
- `deleted` → `false` (default)
- `archived` → `false` (default)
- `created_at` → `now()`
- `updated_at` → `now()`
- `created_by` → NULL
- `updated_by` → NULL

## Conversiones Necesarias

### Booleanos (is_fabric, active, discontinued)
```sql
CASE 
  WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
  WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
  ELSE false
END
```

### collection_name (desde collection)
```sql
CASE 
  WHEN is_fabric = TRUE AND s.collection IS NOT NULL AND trim(s.collection) <> ''
  THEN trim(s.collection)  -- Directo, sin JOIN
  ELSE NULL
END
```

### manufacturer_id (desde manufacturer)
```sql
(SELECT id FROM Manufacturers WHERE lower(name) = lower(trim(s.manufacturer)))
```

### item_category_id (desde category)
```sql
(SELECT id FROM ItemCategories WHERE lower(name) = lower(trim(s.category)))
```

## Notas Importantes

1. **variant_name**: Solo se asigna si `is_fabric = TRUE` y `variant_name` no está vacío
2. **collection_name**: Solo se asigna si `is_fabric = TRUE` y `collection` no está vacío. Se almacena directamente como texto (sin FK)
3. **family**: Esta columna NO se mapea a CatalogItems (no existe en la tabla destino)
4. **description vs item_description**: Ambos existen en staging, pero `item_description` es el que se mapea a `description` en CatalogItems
5. **CatalogItems es la tabla maestra**: No depende de CollectionsCatalog, almacena collection_name directamente

