# Mapping BOM Templates to Fingerprints

## Fingerprint Structure

Cada `BOMTemplate` debe tener un fingerprint completo y único que coincide con:

```typescript
{
  product_type: string;            // 'roller' | 'dual' | 'triple' | 'drapery'
  headbox_type: 'none' | 'cassette';
  system_size: 's' | 'm' | 'l' | 'xl';
  color: string;                   // 'white' | 'black' | etc.
  side_channel_mode: 'none' | 'side_only' | 'side_plus_bottom';
  operating_system: 'manual' | 'motor';
}
```

## Mapping de Templates Existentes

### ROLLER SHADE

| Template Code | product_type | headbox_type | system_size | color | side_channel_mode | operating_system | Notas |
|---------------|--------------|--------------|-------------|-------|-------------------|------------------|-------|
| ROLLER_MANUAL_M | roller | none | m | white | none | manual | Básico manual M |
| ROLLER_MANUAL_DOBLE_M | roller | none | m | white | side_plus_bottom | manual | Manual con side+bottom channel |
| ROLLER_MOTORIZADA_M | roller | none | m | white | none | motor | Básico motor M |
| ROLLER_MOTORIZADA_DOBLE_M | roller | none | m | white | side_plus_bottom | motor | Motor con side+bottom channel |
| MOTORIZADA_SENCILLA_L | roller | none | l | white | none | motor | Motor L sin channels |
| MOTORIZADA_DOBLE_L | roller | none | l | white | side_plus_bottom | motor | Motor L con side+bottom channel |

**Interpretación de "DOBLE":**
- "DOBLE" en roller significa que tiene side channel + bottom channel
- `side_channel_mode = 'side_plus_bottom'`

### DUAL SHADE

| Template Code | product_type | headbox_type | system_size | color | side_channel_mode | operating_system | Notas |
|---------------|--------------|--------------|-------------|-------|-------------------|------------------|-------|
| DOBLE_SHADE | dual | **none** | m | white | none | motor | Dual sin cassette |
| DOBLE_SHADE_MOTORIZADA | dual | cassette | m | white | none | motor | Dual con cassette |

**Solución a Conflictos:**
- **DOBLE_SHADE**: Cambiado a `headbox_type='none'` (sin cassette)
- **DOBLE_SHADE_MOTORIZADA**: Mantiene `headbox_type='cassette'`
- Ahora tienen fingerprints únicos

### TRIPLE SHADE

| Template Code | product_type | headbox_type | system_size | color | side_channel_mode | operating_system | Notas |
|---------------|--------------|--------------|-------------|-------|-------------------|------------------|-------|
| TRIPLE_SHADE | triple | cassette | m | white | none | motor | Triple básico |
| TRIPLE_SHADE_DOBLE | triple | cassette | m | white | side_plus_bottom | motor | Triple con side+bottom channel |

### DRAPERY

| Template Code | product_type | headbox_type | system_size | color | side_channel_mode | operating_system | Notas |
|---------------|--------------|--------------|-------------|-------|-------------------|------------------|-------|
| PA_O_FIJO_RIPPLE_Y_PLEAT | drapery | none | **s** | white | none | manual | Paño fijo (fixed panel) - Size S para unique fingerprint |
| RIEL_MANUAL_RIPPLE | drapery | none | m | white | none | manual | Manual ripple |
| RIEL_MANUAL_PLEAT | drapery | none | m | **black** | none | manual | Manual pleat - Color black para unique fingerprint |
| RIEL_MOTORIZADO_RIPPLE | drapery | none | m | white | none | motor | Motorizado ripple |
| RIEL_MOTORIZADO_PLEAT | drapery | none | m | **black** | none | motor | Motorizado pleat - Color black para unique fingerprint |

**Solución a Conflictos:**
- **PA_O_FIJO_RIPPLE_Y_PLEAT**: Cambiado a `system_size='s'` (Small) ya que es paño fijo
- **RIEL_MANUAL_PLEAT**: Cambiado a `color='black'` para distinguirlo de RIPPLE
- **RIEL_MOTORIZADO_PLEAT**: Cambiado a `color='black'` para distinguirlo de RIPPLE
- Todos tienen `metadata.style` adicional para referencia
- `metadata.allows_color_override=true` indica que el color del fingerprint es solo para uniqueness, no restricción real

## Reglas de Metadata

### `metadata.defaults`
```json
{
  "tube_type": "RTU-42",  // Default tube for this template
  "bracket_item_id": "uuid",
  "idler_item_id": "uuid"
}
```

### `metadata.allowed`
```json
{
  "colors": ["white", "black"],
  "system_sizes": ["m", "l"]
}
```

### `metadata.rules`
```json
{
  "cassette_requires_system_size": "m",
  "bottom_channel_requires_side_channel": true,
  "max_width_mm": 4000,
  "max_height_mm": 3500
}
```

### `metadata.pricing`
```json
{
  "bottom_bar_wrapped_pct": 0.08  // 8% surcharge for wrapped bottom bar
}
```

### `metadata.style` (for drapery only)
```json
{
  "style": "ripple" | "pleat" | "fixed"
}
```

## BOMTemplateSlots vs BOMComponents

### BOMTemplateSlots (Nueva implementación)
- Más simple: `item_role`, `catalog_item_id`, `qty`, `required`
- Usado por `resolveBomTemplate()` y `generateBomInstance()`
- `catalog_item_id` puede ser NULL para items user-selectable (motor, tube, headbox, side_channel, bottom_channel)

### BOMComponents (Legacy/Existing)
- Más complejo: `qty_type`, `qty_value`, `qty_delta_mm`, `waste_pct`, `cut_axis`, etc.
- Usado por `generate_bom_instance_for_quote_line()` RPC
- Mantener por compatibilidad con flujo existente

## Estrategia de Migración

1. **Corto plazo:** Mantener ambos (Slots y Components)
2. **Mediano plazo:** Usar Slots en frontend, Components en backend RPC
3. **Largo plazo:** Migrar todo a Slots o Components (decisión arquitectónica)

## Conflictos de Fingerprint

Si dos templates tienen el mismo fingerprint exacto:
- Solo uno será devuelto por `resolveBomTemplate()`
- Usar `metadata.priority` para desambiguar
- O añadir más columnas al fingerprint (ej: `style` para drapery)

## Testing del Fingerprint

```sql
-- Test: Buscar template exacto
SELECT id, code, name
FROM public."BOMTemplates"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND product_type = 'roller'
  AND headbox_type = 'none'
  AND system_size = 'm'
  AND color = 'white'
  AND side_channel_mode = 'none'
  AND operating_system = 'manual'
  AND active = true
  AND deleted = false
  AND archived = false;
-- Expected: ROLLER_MANUAL_M
```
