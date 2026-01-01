# 📋 Guía de Ejecución: BOM Determinístico

## 🎯 Objetivo
Implementar sistema de BOM determinístico usando `BomRoleSkuMapping` y `MotorTubeCompatibility` en lugar de búsquedas LIKE.

---

## ⚠️ PRE-REQUISITOS

Antes de comenzar, verifica:

1. **Backup de la base de datos** (recomendado)
2. **Conexión a Supabase** configurada
3. **Tabla pivote confirmada**: `CatalogItemProductTypes` existe con columnas:
   - `catalog_item_id`
   - `product_type_id`
   - `organization_id`
   - `deleted`

---

## 📝 PASO A PASO DE EJECUCIÓN

### **PASO 1: Verificar Tabla Pivote** ✅

Ejecuta esta query para confirmar que la tabla existe:

```sql
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'CatalogItemProductTypes'
ORDER BY ordinal_position;
```

**Resultado esperado**: Debe mostrar las columnas mencionadas arriba.

---

### **PASO 2: Crear Tabla BomRoleSkuMapping** (Migración 267)

**Archivo**: `267_create_bom_role_sku_mapping_table.sql`

**Qué hace**:
- Crea tabla `BomRoleSkuMapping` para mapeos determinísticos
- Crea índices y constraints
- Crea trigger para `updated_at`

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 267_create_bom_role_sku_mapping_table.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT COUNT(*) FROM "BomRoleSkuMapping";
-- Debe retornar 0 (tabla vacía por ahora)
```

---

### **PASO 3: Crear Tabla MotorTubeCompatibility** (Migración 268)

**Archivo**: `268_create_motor_tube_compatibility_table.sql`

**Qué hace**:
- Crea tabla `MotorTubeCompatibility` para reglas de capacidad
- Crea índices
- Crea trigger para `updated_at`

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 268_create_motor_tube_compatibility_table.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT COUNT(*) FROM "MotorTubeCompatibility";
-- Debe retornar 0 (tabla vacía por ahora)
```

### **PASO 3B: Fix MotorTubeCompatibility (si es necesario)** ⚠️

**Archivo**: `268_fix_motor_tube_compatibility_columns.sql`

**Cuándo ejecutar**: Solo si obtienes error "column product_type_id does not exist" en el paso 8 (seed data)

**Qué hace**:
- Verifica si la tabla existe pero le faltan columnas
- Agrega columnas faltantes (`product_type_id`, `organization_id`, etc.)

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 268_fix_motor_tube_compatibility_columns.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'MotorTubeCompatibility'
ORDER BY ordinal_position;
-- Debe mostrar: id, organization_id, product_type_id, operating_system_variant, tube_type, max_width_mm, max_drop_mm, max_area_m2, active, deleted, created_at, updated_at
```

---

### **PASO 4: Crear Función de Validación** (Migración 269)

**Archivo**: `269_create_validate_quote_line_configuration.sql`

**Qué hace**:
- Crea función `validate_quote_line_configuration(quote_line_id)`
- Valida campos requeridos (`operating_system_variant`, `tube_type`)
- Valida compatibilidad usando `MotorTubeCompatibility`
- Valida límites de capacidad (width, height, area)

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 269_create_validate_quote_line_configuration.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT proname, pronargs 
FROM pg_proc 
WHERE proname = 'validate_quote_line_configuration';
-- Debe retornar 1 fila con pronargs = 1
```

---

### **PASO 5: Crear Resolver Determinístico** (Migración 270)

**Archivo**: `270_create_resolve_bom_role_to_catalog_item_id.sql`

**Qué hace**:
- Crea función `resolve_bom_role_to_catalog_item_id(...)`
- Usa `BomRoleSkuMapping` para resolver roles a SKUs
- Valida vía `CatalogItemProductTypes` (incluye `organization_id`)
- Prioriza mapeos más específicos

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 270_create_resolve_bom_role_to_catalog_item_id.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT proname, pronargs 
FROM pg_proc 
WHERE proname = 'resolve_bom_role_to_catalog_item_id';
-- Debe retornar 1 fila con pronargs = 8
```

---

### **PASO 6: Actualizar BOM Generator** (Migración 271)

**Archivo**: `271_update_bom_generator_use_deterministic_resolver.sql`

**Qué hace**:
- Actualiza `generate_configured_bom_for_quote_line()` para usar el nuevo resolver
- Llama `validate_quote_line_configuration()` al inicio
- Usa `resolve_bom_role_to_catalog_item_id()` en lugar de búsquedas LIKE
- Mantiene fallback al `component_item_id` del template

**⚠️ IMPORTANTE**: Esta migración hace `DROP FUNCTION ... CASCADE`, asegúrate de que no haya dependencias críticas.

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 271_update_bom_generator_use_deterministic_resolver.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT proname, pronargs 
FROM pg_proc 
WHERE proname = 'generate_configured_bom_for_quote_line';
-- Debe retornar 1 fila con pronargs = 15
```

---

### **PASO 7: Crear Trigger de Defaults** (Migración 272)

**Archivo**: `272_create_defaults_trigger_quote_lines.sql`

**Qué hace**:
- Crea trigger `BEFORE INSERT/UPDATE` en `QuoteLines`
- Establece defaults: `standard_m` → `RTU-42`, `standard_l` → `RTU-65`
- Solo aplica si `tube_type` es NULL

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 272_create_defaults_trigger_quote_lines.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
SELECT tgname, tgrelid::regclass 
FROM pg_trigger 
WHERE tgname = 'set_default_tube_type_trigger';
-- Debe retornar 1 fila
```

---

### **PASO 8: Seed Data** (Migración 273) 🌱

**Archivo**: `273_seed_bom_role_sku_mapping_and_verification.sql`

**Qué hace**:
- Pobla `BomRoleSkuMapping` con mapeos iniciales (usa LIKE solo aquí como bootstrap)
- Pobla `MotorTubeCompatibility` con reglas de capacidad
- Incluye: tube, bracket, bottom_rail_profile, bottom_rail_end_cap, operating_system_drive, motor, motor_adapter, fabric

**⚠️ IMPORTANTE**: 
- Esta migración busca SKUs usando patrones LIKE (solo permitido aquí como bootstrap)
- Si no encuentra SKUs, los mapeos quedarán vacíos y el resolver fallará
- Verifica los logs para ver qué se encontró

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 273_seed_bom_role_sku_mapping_and_verification.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Verificación**:
```sql
-- Verificar mapeos creados
SELECT 
    component_role,
    COUNT(*) as mapping_count
FROM "BomRoleSkuMapping"
WHERE deleted = false AND active = true
GROUP BY component_role
ORDER BY component_role;

-- Verificar compatibilidades creadas
SELECT 
    operating_system_variant,
    tube_type,
    max_width_mm
FROM "MotorTubeCompatibility"
WHERE deleted = false AND active = true
ORDER BY operating_system_variant, tube_type;
```

**Resultado esperado**:
- Al menos mapeos para: `tube`, `bracket`, `bottom_rail_profile`, `operating_system_drive`
- Compatibilidades para: `standard_m+RTU-42`, `standard_l+RTU-65`, `standard_l+RTU-80`

---

### **PASO 9: Verificación Básica** (Migración 274)

**Archivo**: `274_verification_deterministic_bom_comparison.sql`

**Qué hace**:
- Queries de verificación para demostrar determinismo
- Compara configuraciones diferentes
- Muestra mapeos y especificidad

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 274_verification_deterministic_bom_comparison.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Revisar resultados**:
- Verificación 1: Debe mostrar QuoteLines con diferentes configuraciones
- Verificación 3: Debe mostrar que diferentes configs resuelven a diferentes SKUs

---

### **PASO 10: Verificación Final Completa** (Migración 275) ✅

**Archivo**: `275_final_verification_deterministic_bom.sql`

**Qué hace**:
- Tests directos del resolver
- Comparación de defaults (`standard_m+RTU-42` vs `standard_l+RTU-65`)
- Test de validación de capacidad
- Muestra todos los mapeos y compatibilidades

**Ejecutar**:
```sql
-- Copia y pega el contenido completo de 275_final_verification_deterministic_bom.sql
-- en el SQL Editor de Supabase y ejecuta
```

**Revisar resultados**:
1. **VERIFICATION 1**: Confirma estructura de tabla pivote
2. **VERIFICATION 2**: Tests directos del resolver deben mostrar:
   - ✅ `tube (RTU-42, standard_m, white)` → SKU específico
   - ✅ `tube (RTU-65, standard_l, white)` → SKU diferente
   - ✅ `tube (RTU-80, standard_l, white)` → SKU (opcional)
3. **VERIFICATION 3**: Comparación de defaults debe mostrar diferentes `catalog_item_id` para `tube` role
4. **VERIFICATION 4**: Validación debe retornar `ok: true` para configuraciones válidas
5. **VERIFICATION 5**: Test de capacidad debe bloquear width excedido
6. **VERIFICATION 6**: Mapeos con especificidad
7. **VERIFICATION 7**: Reglas de compatibilidad

---

## 🔍 VERIFICACIÓN POST-EJECUCIÓN

### Test Manual del Resolver

```sql
-- Test 1: Resolver tube para standard_m + RTU-42
SELECT 
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id (Roller Shade)
        'tube',
        'standard_m',
        'RTU-42',
        NULL,
        NULL,
        'white',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_id;

-- Test 2: Resolver tube para standard_l + RTU-65
SELECT 
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,
        'tube',
        'standard_l',
        'RTU-65',
        NULL,
        NULL,
        'white',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    ) as resolved_id;

-- Los dos resolved_id deben ser DIFERENTES (diferentes SKUs para diferentes configs)
```

### Test de Validación

```sql
-- Encuentra un QuoteLine existente
SELECT id, operating_system_variant, tube_type
FROM "QuoteLines"
WHERE deleted = false
    AND product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
    AND operating_system_variant IS NOT NULL
    AND tube_type IS NOT NULL
LIMIT 1;

-- Usa el id del resultado anterior
SELECT public.validate_quote_line_configuration('TU_QUOTE_LINE_ID_AQUI'::uuid);
-- Debe retornar JSONB con ok: true (si la config es válida)
```

### Test de Generación de BOM

```sql
-- Encuentra un QuoteLine para probar
SELECT id 
FROM "QuoteLines"
WHERE deleted = false
    AND product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
    AND operating_system_variant IS NOT NULL
    AND tube_type IS NOT NULL
LIMIT 1;

-- Marca componentes existentes como deleted
UPDATE "QuoteLineComponents"
SET deleted = true, updated_at = now()
WHERE quote_line_id = 'TU_QUOTE_LINE_ID_AQUI'::uuid
    AND source = 'configured_component'
    AND deleted = false;

-- Llama a la función (ajusta los parámetros según tu QuoteLine)
SELECT public.generate_configured_bom_for_quote_line(
    'TU_QUOTE_LINE_ID_AQUI'::uuid,
    '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
    '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,  -- organization_id
    'motor',                                        -- drive_type
    'standard',                                     -- bottom_rail_type
    false,                                          -- cassette
    NULL,                                           -- cassette_type
    false,                                          -- side_channel
    NULL,                                           -- side_channel_type
    'white',                                       -- hardware_color
    1.000,                                          -- width_m
    1.000,                                          -- height_m
    1,                                              -- qty
    'RTU-42',                                       -- tube_type
    'standard_m'                                    -- operating_system_variant
);

-- Verifica componentes creados
SELECT 
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLineComponents" qlc
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = 'TU_QUOTE_LINE_ID_AQUI'::uuid
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
ORDER BY qlc.component_role;
```

---

## ⚠️ TROUBLESHOOTING

### Error: "Function not found"
- **Causa**: Migración anterior no se ejecutó correctamente
- **Solución**: Ejecuta las migraciones en orden (267 → 275)

### Error: "No mapping found" en resolver
- **Causa**: Seed data (273) no encontró SKUs o no se ejecutó
- **Solución**: 
  1. Verifica que la migración 273 se ejecutó correctamente
  2. Revisa los logs de la migración 273 para ver qué SKUs encontró
  3. Verifica que existen SKUs en `CatalogItems` para los roles necesarios
  4. Verifica que los SKUs están vinculados a Roller Shade en `CatalogItemProductTypes`

### Error: "Tube type not compatible"
- **Causa**: `MotorTubeCompatibility` no tiene la combinación
- **Solución**: Verifica que la migración 273 creó las compatibilidades necesarias

### Resolver retorna NULL
- **Causa**: No hay mapeo en `BomRoleSkuMapping` o el SKU no está en `CatalogItemProductTypes`
- **Solución**:
  1. Verifica mapeos: `SELECT * FROM "BomRoleSkuMapping" WHERE component_role = 'tube' AND deleted = false;`
  2. Verifica que el SKU está vinculado: `SELECT * FROM "CatalogItemProductTypes" WHERE catalog_item_id = 'SKU_ID';`

---

## ✅ CHECKLIST FINAL

- [ ] Todas las migraciones ejecutadas (267 → 275)
- [ ] Tabla `BomRoleSkuMapping` tiene mapeos
- [ ] Tabla `MotorTubeCompatibility` tiene reglas
- [ ] Función `resolve_bom_role_to_catalog_item_id()` retorna IDs diferentes para diferentes configs
- [ ] Función `validate_quote_line_configuration()` valida correctamente
- [ ] Función `generate_configured_bom_for_quote_line()` genera componentes usando el resolver
- [ ] Trigger de defaults funciona (crea QuoteLine sin tube_type y verifica que se asigna default)
- [ ] Verificación 275 muestra determinismo (diferentes configs → diferentes SKUs)

---

## 📞 SIGUIENTE PASO

Una vez completada la ejecución, comparte:
1. Output de la migración 275 (VERIFICATION 2 especialmente)
2. Resultados de los tests manuales del resolver
3. Cualquier error o warning que aparezca

¡Listo para ejecutar! 🚀

