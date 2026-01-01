# ⚡ Orden de Ejecución Rápido - BOM Determinístico

## 📋 Lista de Migraciones (en orden)

Ejecuta en este orden exacto:

1. ✅ **267_create_bom_role_sku_mapping_table.sql**
   - Crea tabla `BomRoleSkuMapping`

2. ✅ **268_create_motor_tube_compatibility_table.sql**
   - Crea tabla `MotorTubeCompatibility`

3. ✅ **269_create_validate_quote_line_configuration.sql**
   - Crea función `validate_quote_line_configuration()`

4. ✅ **270_create_resolve_bom_role_to_catalog_item_id.sql**
   - Crea función `resolve_bom_role_to_catalog_item_id()`

5. ✅ **271_update_bom_generator_use_deterministic_resolver.sql**
   - Actualiza `generate_configured_bom_for_quote_line()`

6. ✅ **272_create_defaults_trigger_quote_lines.sql**
   - Crea trigger de defaults para `tube_type`

7. ✅ **273_seed_bom_role_sku_mapping_and_verification.sql**
   - **IMPORTANTE**: Pobla datos iniciales (seed)

8. ✅ **274_verification_deterministic_bom_comparison.sql**
   - Queries de verificación básicas

9. ✅ **275_final_verification_deterministic_bom.sql**
   - Verificación final completa

---

## 🚀 Comando Rápido (Supabase SQL Editor)

Copia y pega cada archivo en orden en el SQL Editor de Supabase:

```sql
-- 1. Ejecuta 267
-- 2. Ejecuta 268
-- 3. Ejecuta 269
-- 4. Ejecuta 270
-- 5. Ejecuta 271
-- 6. Ejecuta 272
-- 7. Ejecuta 273 (seed data - revisa logs)
-- 8. Ejecuta 274
-- 9. Ejecuta 275 (verificación final)
```

---

## ✅ Verificación Rápida Post-Ejecución

```sql
-- 1. Verificar tablas creadas
SELECT COUNT(*) FROM "BomRoleSkuMapping";
SELECT COUNT(*) FROM "MotorTubeCompatibility";

-- 2. Verificar funciones creadas
SELECT proname FROM pg_proc 
WHERE proname IN (
    'validate_quote_line_configuration',
    'resolve_bom_role_to_catalog_item_id',
    'generate_configured_bom_for_quote_line'
);

-- 3. Verificar seed data
SELECT component_role, COUNT(*) 
FROM "BomRoleSkuMapping" 
WHERE deleted = false 
GROUP BY component_role;

-- 4. Verificar compatibilidades
SELECT operating_system_variant, tube_type 
FROM "MotorTubeCompatibility" 
WHERE deleted = false 
ORDER BY operating_system_variant, tube_type;
```

---

## 📖 Guía Completa

Para detalles completos, ver: **GUIA_EJECUCION_BOM_DETERMINISTICO.md**


