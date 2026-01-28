# 🔍 VERIFICACIONES PENDIENTES: Funciones SQL

**Fecha:** 2026-01-25  
**Objetivo:** Verificar y corregir funciones SQL que usan tablas viejas

---

## ⚠️ FUNCIONES SQL QUE NECESITAN VERIFICACIÓN

### 1. `generate_bom_from_slots_for_configured_product`
**Ubicación en dump:** Línea 1503  
**Problema:** Usa `INSERT INTO public."BomInstances"` (camelCase)  
**Debería usar:** `INSERT INTO public."BOMInstances"` (mayúsculas)

```sql
-- ❌ INCORRECTO (en dump):
INSERT INTO public."BomInstances"(
    organization_id, 
    configured_product_id, 
    bom_template_id,
    quote_line_id
)

-- ✅ CORRECTO:
INSERT INTO public."BOMInstances"(
    organization_id, 
    configured_product_id, 
    bom_template_id,
    quote_line_id
)
```

**Nota:** Esta función crea BOM para ConfiguredProducts (preview). Según el objetivo, esto está permitido pero `quote_line_id` debe ser NULL para previews.

---

### 2. `generate_bom_instance_for_quote_line`
**Ubicación en dump:** Línea 1770  
**Problema:** Usa `INSERT INTO public."BomInstances"` (camelCase)  
**Debería usar:** `INSERT INTO public."BOMInstances"` (mayúsculas)

```sql
-- ❌ INCORRECTO (en dump):
INSERT INTO public."BomInstances"(organization_id, quote_line_id, bom_template_id)

-- ✅ CORRECTO:
INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id)
```

---

### 3. `calculate_configured_product_totals`
**Ubicación en dump:** Líneas 477, 518  
**Problema:** Usa `FROM public."BomInstances"` y `FROM public."BomInstanceLines"` (camelCase)  
**Debería usar:** `FROM public."BOMInstances"` y `FROM public."BOMInstanceLines"` (mayúsculas)

```sql
-- ❌ INCORRECTO (en dump):
SELECT id INTO v_bom_instance_id
FROM public."BomInstances"
WHERE configured_product_id = p_configured_product_id

-- ✅ CORRECTO:
SELECT id INTO v_bom_instance_id
FROM public."BOMInstances"
WHERE configured_product_id = p_configured_product_id
```

```sql
-- ❌ INCORRECTO (en dump):
FROM public."BomInstanceLines" bil
WHERE bil.bom_instance_id = v_bom_instance_id

-- ✅ CORRECTO:
FROM public."BOMInstanceLines" bil
WHERE bil.bom_instance_id = v_bom_instance_id
```

---

## ✅ FUNCIONES QUE YA ESTÁN CORRECTAS

### `generate_bom_from_slots`
**Ubicación en dump:** Líneas 1282, 1289, 1374, 1412  
**Estado:** ✅ Ya usa `BOMInstances` y `BOMInstanceLines` (mayúsculas)

---

## 📝 MIGRACIÓN RECOMENDADA

Crear una migración SQL para corregir estas funciones:

```sql
-- ====================================================
-- MIGRATION: Corregir referencias a tablas BOM en funciones SQL
-- Date: 2026-01-25
-- ====================================================

BEGIN;

-- 1. Corregir generate_bom_from_slots_for_configured_product
CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots_for_configured_product"(
    "p_org_id" "uuid", 
    "p_configured_product_id" "uuid", 
    "p_product_type_id" "uuid"
) RETURNS "uuid"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
-- ... (código completo con BOMInstances en mayúsculas)
$$;

-- 2. Corregir generate_bom_instance_for_quote_line
CREATE OR REPLACE FUNCTION "public"."generate_bom_instance_for_quote_line"(
    "p_org_id" "uuid", 
    "p_quote_line_id" "uuid", 
    "p_product_type_id" "uuid"
) RETURNS "uuid"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
-- ... (código completo con BOMInstances en mayúsculas)
$$;

-- 3. Corregir calculate_configured_product_totals
CREATE OR REPLACE FUNCTION "public"."calculate_configured_product_totals"(
    "p_configured_product_id" "uuid"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
-- ... (código completo con BOMInstances y BOMInstanceLines en mayúsculas)
$$;

COMMIT;
```

---

## 🔍 VERIFICACIÓN EN BASE DE DATOS

Ejecutar estas queries para verificar:

```sql
-- 1. Buscar funciones que usan tablas viejas
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND (
    pg_get_functiondef(p.oid) LIKE '%BomInstances%' 
    OR pg_get_functiondef(p.oid) LIKE '%BomInstanceLines%'
  )
  AND p.proname NOT LIKE '%deprecated%'
ORDER BY p.proname;

-- 2. Verificar que no existen tablas viejas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('BomInstances', 'BomInstanceLines');

-- 3. Verificar que existen tablas nuevas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('BOMInstances', 'BOMInstanceLines');
```

---

## ✅ ESTADO ACTUAL

- ✅ **Código frontend:** Todas las referencias actualizadas
- ✅ **Servicios/hooks:** Creados y listos para usar
- ✅ **Tipos TypeScript:** Definidos correctamente
- ⚠️ **Funciones SQL:** Necesitan verificación y corrección en base de datos

---

**Siguiente paso:** Ejecutar verificaciones en base de datos y corregir funciones SQL si es necesario.
