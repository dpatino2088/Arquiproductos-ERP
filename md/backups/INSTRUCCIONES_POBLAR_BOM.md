# Instrucciones para Poblar BOM Templates y Slots

## Archivos Disponibles

1. **`populate_bom_fingerprints_and_slots.sql`** - Script SQL principal
   - Actualiza BOMTemplates con fingerprints completos
   - Crea BOMTemplateSlots para cada template
   - Maneja conflictos de UNIQUE INDEX mediante diferenciación de fingerprints

2. **`MAPPING_TEMPLATES_TO_FINGERPRINTS.md`** - Documentación del mapping
   - Tabla completa de todos los templates con sus fingerprints
   - Explicación de resolución de conflictos
   - Guía de metadata

3. **`bom_templates_optionA_fixed_v3.sql`** - Script original (solo BOMComponents)
   - Mantener para referencia
   - Crear BOMComponents (usado por RPC existente)

## Pasos para Ejecutar

### 1. Ejecutar BOMComponents (Compatibilidad con RPC existente)

```bash
psql -U postgres -d your_database -f backups/bom_templates_optionA_fixed_v3.sql
```

Este script crea/actualiza:
- `BOMTemplates` (sin fingerprints completos)
- `BOMComponents` (necesarios para `generate_bom_instance_for_quote_line()` RPC)

### 2. Ejecutar Fingerprints y Slots (Nueva implementación)

```bash
psql -U postgres -d your_database -f backups/populate_bom_fingerprints_and_slots.sql
```

Este script:
- Actualiza `BOMTemplates` con fingerprints completos
- Crea `BOMTemplateSlots` (usados por el nuevo configurador)
- Resuelve conflictos de UNIQUE INDEX

### 3. Verificar Resultados

```sql
-- Verificar templates con fingerprints
SELECT 
  code, 
  name, 
  product_type,
  headbox_type,
  system_size,
  color,
  side_channel_mode,
  operating_system,
  active
FROM public."BOMTemplates"
WHERE organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND deleted=false
ORDER BY product_type, operating_system, system_size;

-- Verificar slots por template
SELECT 
  bt.code,
  COUNT(bts.id) as slots_count,
  STRING_AGG(bts.item_role, ', ' ORDER BY bts.item_role) as roles
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMTemplateSlots" bts ON bts.bom_template_id=bt.id
WHERE bt.organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted=false
GROUP BY bt.code
ORDER BY bt.code;

-- Verificar components por template (legacy)
SELECT 
  bt.code,
  COUNT(bc.id) as components_count
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMComponents" bc ON bc.bom_template_id=bt.id AND bc.deleted=false
WHERE bt.organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted=false
GROUP BY bt.code
ORDER BY bt.code;
```

## Resolución de Conflictos de Fingerprint

El esquema tiene un UNIQUE INDEX en BOMTemplates:
```sql
CREATE UNIQUE INDEX "bomtemplates_fingerprint_unique" 
ON "public"."BOMTemplates" 
USING "btree" ("organization_id", "product_type", "headbox_type", "system_size", "color", "side_channel_mode", "operating_system") 
WHERE ("deleted" = false);
```

### Conflictos Encontrados y Soluciones:

1. **DRAPERY Manual (3 templates con mismo fingerprint original)**
   - `RIEL_MANUAL_RIPPLE`: white, m (mantiene original)
   - `RIEL_MANUAL_PLEAT`: **black**, m (cambiado a black)
   - `PA_O_FIJO_RIPPLE_Y_PLEAT`: white, **s** (cambiado a size S)

2. **DRAPERY Motor (2 templates con mismo fingerprint original)**
   - `RIEL_MOTORIZADO_RIPPLE`: white, m (mantiene original)
   - `RIEL_MOTORIZADO_PLEAT`: **black**, m (cambiado a black)

3. **DUAL (2 templates con mismo fingerprint original)**
   - `DOBLE_SHADE`: **none**, m (sin cassette)
   - `DOBLE_SHADE_MOTORIZADA`: **cassette**, m (con cassette)

### Metadata para Flexibilidad

Aunque los fingerprints usan colores específicos (white/black) para uniqueness, `metadata.allows_color_override=true` indica que el template puede servir para otros colores también. El configurador puede:

1. Buscar template exacto por fingerprint (color incluido)
2. Si no encuentra, buscar por fingerprint sin color y usar metadata
3. Aplicar color seleccionado al resolver SKUs de componentes

## Testing

### Test 1: Roller Manual M (básico)

```typescript
const fingerprint = {
  product_type: 'roller',
  headbox_type: 'none',
  system_size: 'm',
  color: 'white',
  side_channel_mode: 'none',
  operating_system: 'manual'
};
// Expected: ROLLER_MANUAL_M
```

### Test 2: Roller Motor L con Side+Bottom Channel

```typescript
const fingerprint = {
  product_type: 'roller',
  headbox_type: 'none',
  system_size: 'l',
  color: 'white',
  side_channel_mode: 'side_plus_bottom',
  operating_system: 'motor'
};
// Expected: MOTORIZADA_DOBLE_L
```

### Test 3: Dual con Cassette

```typescript
const fingerprint = {
  product_type: 'dual',
  headbox_type: 'cassette',
  system_size: 'm',
  color: 'white',
  side_channel_mode: 'none',
  operating_system: 'motor'
};
// Expected: DOBLE_SHADE_MOTORIZADA
```

## Notas Importantes

1. **BOMTemplateSlots** es la nueva tabla usada por el configurador React
2. **BOMComponents** se mantiene para el RPC `generate_bom_instance_for_quote_line()`
3. Ambos coexisten: Slots para nueva UI, Components para backend legacy
4. Los slots con `catalog_item_id=NULL` indican que el usuario selecciona el SKU
5. Los slots con `catalog_item_id` fijo usan ese SKU siempre
6. `required=true` indica que el slot debe tener un item (ya sea fijo o seleccionado por usuario)

## Próximos Pasos

1. ✅ Ejecutar `bom_templates_optionA_fixed_v3.sql` (BOMComponents)
2. ✅ Ejecutar `populate_bom_fingerprints_and_slots.sql` (Fingerprints + Slots)
3. 🔲 Verificar que todos los SKUs existen en CatalogItems
4. 🔲 Verificar que todos los items tienen `item_role` correcto
5. 🔲 Testing en UI con el nuevo configurador
6. 🔲 Ajustar fingerprints según feedback de uso real
