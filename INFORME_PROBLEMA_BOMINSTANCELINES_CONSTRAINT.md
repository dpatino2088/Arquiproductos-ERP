# 📋 INFORME DETALLADO: Problema con BomInstanceLines Constraint

**Fecha:** 2026-01-21  
**Problema Principal:** Error de constraint CHECK en tabla `BomInstanceLines`  
**Estado:** 🔴 PENDIENTE DE RESOLVER

---

## 🎯 RESUMEN EJECUTIVO

### Error Actual
```
new row for relation "BomInstanceLines" violates check constraint "bominstancelines_part_role_check"
```

### Contexto
Durante la implementación del flujo de **ConfiguredProducts** y **BOM Preview**, se está intentando insertar registros en la tabla `BomInstanceLines` con valores de `part_role` que no están permitidos por el constraint CHECK de la base de datos.

### Impacto
- ❌ No se puede crear el preview del producto configurado
- ❌ El flujo completo de configuración está bloqueado
- ❌ No se pueden generar BOM instances desde el configurador

---

## 🔍 PROBLEMAS IDENTIFICADOS Y RESUELTOS

### 1. **Problema: Case Sensitivity en Nombres de Tablas**

#### Descripción
PostgreSQL es case-sensitive cuando se usan comillas dobles. Algunas migraciones usaban `"BOMInstanceLines"` (mayúsculas) mientras que la tabla real se llama `"BomInstanceLines"` (camelCase).

#### Errores Encontrados
- Error: `relation "public.BomInstanceLines" does not exist`
- El INSERT fallaba silenciosamente porque buscaba una tabla con nombre diferente

#### Solución Implementada
- ✅ Unificadas todas las referencias a `"BomInstanceLines"` (camelCase)
- ✅ Corregidos 2 INSERT statements en `20260121_create_configured_products_and_bom_preview.sql`
- ✅ Corregidas todas las referencias en `20260120_add_columns_to_bominstancelines.sql`

#### Archivos Modificados
- `database/migrations/20260121_create_configured_products_and_bom_preview.sql` (líneas 852, 916)
- `database/migrations/20260120_add_columns_to_bominstancelines.sql` (múltiples líneas)

---

### 2. **Problema: resolved_part_id NULL**

#### Descripción
El código permitía insertar líneas en `BomInstanceLines` con `resolved_part_id = NULL`, pero esta columna tiene una constraint NOT NULL.

#### Error Encontrado
```
null value in column "resolved_part_id" of relation "BomInstanceLines" violates not-null constraint
```

#### Solución Implementada
- ✅ Cambiada la condición de inserción de:
  ```sql
  IF v_resolved_item IS NOT NULL OR v_qty > 0 THEN
  ```
  a:
  ```sql
  IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
  ```
- ✅ Agregado WARNING log cuando hay cantidad pero no hay item resuelto

#### Archivo Modificado
- `database/migrations/20260121_create_configured_products_and_bom_preview.sql` (línea ~851)

---

### 3. **Problema: Roles No Contemplados en CASE Statement**

#### Descripción
El CASE statement que mapea `item_role` a campos en `config_snapshot` no tenía un `ELSE`, lo que podía dejar variables `NULL` si aparecía un role no contemplado.

#### Solución Implementada
- ✅ Agregado `ELSE` clause que intenta usar el nombre genérico del role como fallback
- ✅ Intenta extraer `{item_role}_item_id` y `{item_role}_sku` del config_snapshot

#### Archivo Modificado
- `database/migrations/20260121_create_configured_products_and_bom_preview.sql` (línea ~784)

---

### 4. **Problema: Tabla BomInstanceLines No Existía**

#### Descripción
La migración `20260120_add_columns_to_bominstancelines.sql` intentaba modificar una tabla que podía no existir.

#### Solución Implementada
- ✅ Agregado `CREATE TABLE IF NOT EXISTS` para `BomInstances` y `BomInstanceLines`
- ✅ Incluye todas las columnas y constraints necesarios
- ✅ Migración ahora es idempotente

#### Archivo Modificado
- `database/migrations/20260120_add_columns_to_bominstancelines.sql` (líneas 10-65)

---

## 🚨 PROBLEMA ACTUAL: Constraint CHECK Desactualizado

### Análisis del Problema

El constraint `bominstancelines_part_role_check` definido en la migración `20260116_bom_foundation_complete.sql` **NO incluye los roles adicionales** que el código está intentando usar.

#### Constraint Actual (Incompleto)
```sql
CONSTRAINT "bominstancelines_part_role_check" 
CHECK (
    "part_role" IN (
        'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
        'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
        'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
        'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
        'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
        'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film'
    )
)
```

#### Roles Faltantes (Usados en el Código)
El código en `generate_bom_from_slots_for_configured_product` usa estos roles adicionales:
- ❌ `'motor'` - Motor/actuador
- ❌ `'headbox'` - Caja superior
- ❌ `'bottom_bar'` - Barra inferior (diferente de `'bottom_bar_profile'`)
- ❌ `'side_channel'` - Canal lateral (diferente de `'side_channel_profile'`)
- ❌ `'bottom_channel'` - Canal inferior
- ❌ `'drive'` - Sistema de accionamiento (diferente de `'drive_manual'` y `'drive_motorized'`)

### ¿Por Qué Sigue Fallando?

1. **Migración No Ejecutada**: La migración `20260120_add_columns_to_bominstancelines.sql` puede no haberse ejecutado, o el bloque de actualización del constraint puede haber fallado silenciosamente.

2. **Constraint Ya Existente**: Si el constraint ya existe con el contenido antiguo, el `DROP CONSTRAINT IF EXISTS` puede no haberlo eliminado correctamente, o el `ADD CONSTRAINT` puede haber fallado con "constraint already exists".

3. **Orden de Ejecución**: Si la migración `20260116_bom_foundation_complete.sql` se ejecutó después de `20260120_add_columns_to_bominstancelines.sql`, puede haber sobrescrito el constraint actualizado.

4. **Error Silencioso**: El bloque `DO $$ ... EXCEPTION ... END $$` puede estar capturando errores y solo mostrando WARNINGs sin fallar la migración.

---

## ✅ SOLUCIÓN IMPLEMENTADA

### Código Agregado en `20260120_add_columns_to_bominstancelines.sql`

```sql
-- 7) Actualizar constraint part_role_check para incluir roles adicionales
DO $$
BEGIN
  -- Intentar eliminar el constraint si existe
  BEGIN
    ALTER TABLE public."BomInstanceLines"
      DROP CONSTRAINT IF EXISTS bominstancelines_part_role_check;
    RAISE NOTICE '✅ Constraint eliminado (si existía)';
  EXCEPTION
    WHEN undefined_object THEN
      RAISE NOTICE '⚠️ Constraint no existe, continuando...';
    WHEN OTHERS THEN
      RAISE NOTICE '⚠️ Error al eliminar constraint: %, continuando...', SQLERRM;
  END;
  
  -- Crear nuevo constraint con todos los roles necesarios
  BEGIN
    ALTER TABLE public."BomInstanceLines"
      ADD CONSTRAINT bominstancelines_part_role_check
      CHECK (
        part_role IN (
          -- Roles originales
          'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
          'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
          'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
          'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
          'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
          'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film',
          -- Roles adicionales CRÍTICOS
          'motor', 'headbox', 'bottom_bar', 'side_channel', 'bottom_channel', 'drive'
        )
      );
    
    RAISE NOTICE '✅ Constraint actualizado con roles adicionales';
  EXCEPTION
    WHEN duplicate_object THEN
      RAISE EXCEPTION 'Constraint ya existe con posible contenido antiguo. Ejecuta: ALTER TABLE "BomInstanceLines" DROP CONSTRAINT bominstancelines_part_role_check; y vuelve a ejecutar esta migración.';
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error al crear constraint: %', SQLERRM;
  END;
END $$;
```

---

## 🔧 SOLUCIÓN RECOMENDADA (INMEDIATA)

### Opción 1: Ejecutar SQL Manualmente (MÁS RÁPIDO)

Ejecuta directamente en tu base de datos PostgreSQL:

```sql
BEGIN;

-- 1. Eliminar constraint antiguo
ALTER TABLE "public"."BomInstanceLines" 
DROP CONSTRAINT IF EXISTS bominstancelines_part_role_check;

-- 2. Verificar que se eliminó (opcional)
SELECT conname 
FROM pg_constraint 
WHERE conrelid = 'public."BomInstanceLines"'::regclass 
  AND conname LIKE '%part_role%';

-- 3. Crear nuevo constraint con TODOS los roles
ALTER TABLE "public"."BomInstanceLines"
ADD CONSTRAINT bominstancelines_part_role_check
CHECK (
  part_role IN (
    -- Roles originales
    'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
    'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
    'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
    'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
    'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
    'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film',
    -- Roles adicionales CRÍTICOS
    'motor', 'headbox', 'bottom_bar', 'side_channel', 'bottom_channel', 'drive'
  )
);

COMMIT;
```

### Opción 2: Verificar Estado Actual

Antes de ejecutar la solución, verifica:

1. **Qué constraint existe actualmente:**
```sql
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'public."BomInstanceLines"'::regclass
  AND conname LIKE '%part_role%';
```

2. **Qué roles se están usando en BOMTemplateSlots:**
```sql
SELECT DISTINCT item_role 
FROM "BOMTemplateSlots" 
WHERE organization_id = '<tu_org_id>'
ORDER BY item_role;
```

3. **Verificar si hay registros que violan el constraint:**
```sql
-- Esto debería fallar si hay registros inválidos
SELECT part_role, COUNT(*) 
FROM "BomInstanceLines"
WHERE part_role NOT IN (
    'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
    'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
    'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
    'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
    'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
    'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film',
    'motor', 'headbox', 'bottom_bar', 'side_channel', 'bottom_channel', 'drive'
)
GROUP BY part_role;
```

---

## 📊 DIAGNÓSTICO ADICIONAL

### Verificar Qué Role Específico Está Causando el Error

Si el error persiste después de actualizar el constraint, necesitamos identificar qué `part_role` específico está intentando insertarse. Para esto:

1. **Revisa los logs de PostgreSQL** para ver el valor exacto del `part_role` en el error.

2. **Revisa el código que inserta:**
   - Función: `generate_bom_from_slots_for_configured_product`
   - Archivo: `database/migrations/20260121_create_configured_products_and_bom_preview.sql`
   - Línea ~865: `v_slot.item_role` se usa como `part_role`

3. **Verifica los roles en BOMTemplateSlots:**
```sql
SELECT DISTINCT bt.id as template_id, bt.name, bts.item_role
FROM "BOMTemplates" bt
JOIN "BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
WHERE bt.organization_id = '<tu_org_id>'
  AND bt.product_type_id = '<product_type_id_que_estas_usando>'
ORDER BY bt.id, bts.item_role;
```

---

## 📝 ARCHIVOS MODIFICADOS EN ESTA SESIÓN

1. **`database/migrations/20260120_add_columns_to_bominstancelines.sql`**
   - ✅ Agregado `CREATE TABLE IF NOT EXISTS` para `BomInstances` y `BomInstanceLines`
   - ✅ Corregidos nombres de tablas (case sensitivity)
   - ✅ Agregado bloque para actualizar constraint `part_role_check`

2. **`database/migrations/20260121_create_configured_products_and_bom_preview.sql`**
   - ✅ Corregidos nombres de tablas en INSERT statements (líneas 852, 916)
   - ✅ Corregida validación de `resolved_part_id` NOT NULL (línea ~851)
   - ✅ Agregado ELSE clause en CASE statement (línea ~784)
   - ✅ Agregadas validaciones después de INSERT en `BomInstances`

3. **`database/migrations/20260122_remove_fabric_legacy_columns.sql`**
   - ✅ Ya estaba actualizado (no se modificó en esta sesión)

---

## 🎯 PRÓXIMOS PASOS RECOMENDADOS

### Paso 1: Ejecutar Solución Inmediata
1. Ejecuta el SQL de la **Opción 1** para actualizar el constraint manualmente
2. Prueba crear un producto configurado nuevamente

### Paso 2: Verificar Resultado
- ✅ Si funciona: El problema está resuelto. Considera crear una migración separada solo para este cambio.
- ❌ Si sigue fallando: Revisa los logs de PostgreSQL para identificar el `part_role` específico que está causando el error.

### Paso 3: Validación Completa
Una vez resuelto el constraint, verifica:
- ✅ Crear un ConfiguredProduct desde el configurador
- ✅ Verificar que se crean los `BomInstances` correctamente
- ✅ Verificar que se crean los `BomInstanceLines` con todos los roles necesarios
- ✅ Verificar que los precios se calculan correctamente

### Paso 4: Crear Migración Dedicada (Opcional)
Si prefieres tener esto en una migración separada más limpia, puedo crear:
- `database/migrations/20260121_fix_bominstancelines_part_role_constraint.sql`

---

## 🔍 POSIBLES CAUSAS ADICIONALES

Si el problema persiste después de actualizar el constraint, considera:

1. **Otro constraint con nombre similar**: Puede haber múltiples constraints con nombres parecidos
2. **Roles desde otras fuentes**: El `part_role` podría estar viniendo de otra función o tabla
3. **Caché de constraints**: PostgreSQL puede estar usando una versión cacheada del constraint
4. **Permisos**: Puede haber un problema de permisos que impide actualizar el constraint

---

## 📚 REFERENCIAS

- **Constraint original**: `database/migrations/20260116_bom_foundation_complete.sql` (línea 423)
- **Función que inserta**: `database/migrations/20260121_create_configured_products_and_bom_preview.sql` (función `generate_bom_from_slots_for_configured_product`)
- **CASE statement**: `database/migrations/20260121_create_configured_products_and_bom_preview.sql` (línea ~762)

---

**Última actualización:** 2026-01-21  
**Estado:** 🔴 PENDIENTE - Requiere acción manual para actualizar constraint
