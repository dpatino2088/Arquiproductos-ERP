# 📋 Análisis: Normalización de `affects_role` a Enum/Catálogo

**Fecha:** Diciembre 2024  
**Estado:** Análisis - No urgente

---

## 🔍 Situación Actual

### Implementación Actual
- `affects_role` es un campo `text NULL` en `BOMComponents`
- Se usa como texto libre (ej: "tube", "fabric", "bracket")
- **Riesgo:** Typos como "tube" vs "tubes", "bracket" vs "brackets"

### Uso en Código
En `apply_engineering_rules_to_bom_instance()` se comparan así:
```sql
IF v_target_line.part_role = 'tube' THEN
ELSIF v_target_line.part_role IN ('fabric', 'fabric_panel') THEN
ELSIF v_target_line.part_role IN ('bracket', 'brackets') THEN
```

**Problema identificado:**
- Se aceptan variantes: `'bracket'` y `'brackets'` (plural)
- No hay validación centralizada
- Typos pueden causar que las reglas no se apliquen

---

## 📊 Roles Identificados en el Sistema

Basado en el código actual, los roles comunes son:

### Roles Principales
1. **`tube`** - Tubos (componente lineal)
2. **`fabric`** / **`fabric_panel`** - Tela/paneles de tela
3. **`bracket`** / **`brackets`** - Brackets (soporte)
4. **`rail`** - Rieles (probable)
5. **`channel`** - Canales (probable)
6. **`hardware`** - Hardware general (probable)

### Observaciones
- Hay variantes en plural/singular: `bracket` vs `brackets`
- Algunos roles pueden tener sufijos: `fabric_panel`
- No hay catálogo centralizado de roles válidos

---

## 💡 Opciones de Implementación

### Opción A: Enum PostgreSQL (Recomendada)

**Ventajas:**
- ✅ Validación a nivel de base de datos
- ✅ No permite typos
- ✅ Performance mejor (índices más eficientes)
- ✅ Type-safe en TypeScript

**Desventajas:**
- ⚠️ Requiere migración para agregar nuevos valores
- ⚠️ Menos flexible que catálogo

**Implementación:**
```sql
CREATE TYPE component_role_enum AS ENUM (
  'tube',
  'fabric',
  'fabric_panel',
  'bracket',
  'rail',
  'channel',
  'hardware',
  'accessory'
);

ALTER TABLE "BOMComponents"
ALTER COLUMN affects_role TYPE component_role_enum 
USING affects_role::component_role_enum;
```

### Opción B: Tabla Catálogo (Más Flexible)

**Ventajas:**
- ✅ Muy flexible (agregar roles sin migración)
- ✅ Puede tener metadata (descripción, icono, etc.)
- ✅ Fácil de mantener desde UI

**Desventajas:**
- ⚠️ Requiere JOIN para validación
- ⚠️ Más complejo de implementar

**Implementación:**
```sql
CREATE TABLE "ComponentRoles" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,  -- 'tube', 'fabric', etc.
  name text NOT NULL,         -- 'Tube', 'Fabric', etc.
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Foreign key constraint
ALTER TABLE "BOMComponents"
ADD CONSTRAINT fk_affects_role 
FOREIGN KEY (affects_role) REFERENCES "ComponentRoles"(code);
```

### Opción C: Normalización con Trigger (Híbrida)

**Ventajas:**
- ✅ Mantiene flexibilidad de texto libre
- ✅ Normaliza automáticamente (ej: "tubes" → "tube")
- ✅ No requiere cambios en estructura

**Desventajas:**
- ⚠️ No previene todos los typos
- ⚠️ Requiere mapeo de variantes

**Implementación:**
```sql
CREATE OR REPLACE FUNCTION normalize_component_role()
RETURNS trigger AS $$
BEGIN
  IF NEW.affects_role IS NOT NULL THEN
    -- Normalizar variantes comunes
    NEW.affects_role := CASE lower(trim(NEW.affects_role))
      WHEN 'tubes' THEN 'tube'
      WHEN 'brackets' THEN 'bracket'
      WHEN 'fabrics' THEN 'fabric'
      ELSE lower(trim(NEW.affects_role))
    END;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## 🎯 Recomendación

### Para Implementación Inmediata (No Urgente)
**Opción C: Normalización con Trigger** es la más práctica porque:
1. ✅ No requiere cambios estructurales grandes
2. ✅ Resuelve el problema de variantes comunes
3. ✅ Backward compatible
4. ✅ Fácil de implementar

### Para Futuro (Cuando se Necesite Más Control)
**Opción A: Enum** cuando:
- Se tenga una lista definitiva de roles
- Se necesite validación estricta
- Se quiera type-safety completo

---

## 📝 Plan de Implementación (Opción C - Híbrida)

### Paso 1: Crear función de normalización
```sql
CREATE OR REPLACE FUNCTION normalize_component_role(p_role text)
RETURNS text AS $$
BEGIN
  IF p_role IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Normalizar a lowercase y trim
  p_role := lower(trim(p_role));
  
  -- Mapear variantes comunes
  RETURN CASE p_role
    WHEN 'tubes' THEN 'tube'
    WHEN 'brackets' THEN 'bracket'
    WHEN 'fabrics' THEN 'fabric'
    WHEN 'fabric_panels' THEN 'fabric_panel'
    WHEN 'rails' THEN 'rail'
    WHEN 'channels' THEN 'channel'
    ELSE p_role
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### Paso 2: Crear trigger
```sql
CREATE OR REPLACE FUNCTION normalize_affects_role()
RETURNS trigger AS $$
BEGIN
  IF NEW.affects_role IS NOT NULL THEN
    NEW.affects_role := normalize_component_role(NEW.affects_role);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_normalize_affects_role
BEFORE INSERT OR UPDATE ON "BOMComponents"
FOR EACH ROW
EXECUTE FUNCTION normalize_affects_role();
```

### Paso 3: Actualizar función de engineering rules
```sql
-- Usar función de normalización en comparaciones
IF normalize_component_role(v_target_line.part_role) = 'tube' THEN
ELSIF normalize_component_role(v_target_line.part_role) IN ('fabric', 'fabric_panel') THEN
```

### Paso 4: Actualizar UI (opcional)
- Dropdown con opciones predefinidas
- Validación en frontend
- Autocompletado

---

## ✅ Conclusión

**Estado Actual:**
- ✅ Implementación funcional
- ⚠️ Riesgo de typos (bajo, pero existe)
- ✅ No es urgente

**Recomendación:**
- **Corto plazo:** Implementar Opción C (normalización con trigger)
- **Largo plazo:** Considerar Opción A (enum) cuando se estabilice la lista de roles

**Prioridad:** Baja (no urgente, pero buena práctica)

---

## ✅ Estado Actual de la Implementación

### Revisión del Código

**Función `apply_engineering_rules_to_bom_instance()`:**
- ✅ Compara roles exactos: `'tube'`, `'fabric'`, `'fabric_panel'`, `'bracket'`, `'brackets'`
- ⚠️ Acepta variantes: `'bracket'` y `'brackets'` (ambos válidos)
- ⚠️ No normaliza antes de comparar

**Función `derive_category_code_from_role()`:**
- ✅ Usa pattern matching con `LIKE '%tube%'`, `LIKE '%bracket%'`
- ✅ Más tolerante a variantes
- ✅ Funciona bien para categorización

**Conclusión:**
- ✅ **La implementación actual funciona correctamente**
- ⚠️ Hay riesgo de typos (bajo, pero existe)
- ✅ No es urgente, pero normalizar mejoraría la robustez

---

## 🎯 Recomendación Final

### Opción Implementada: Normalización Híbrida (Migración 206)

**Ventajas:**
1. ✅ **No rompe nada:** Backward compatible
2. ✅ **Previene typos:** Normaliza automáticamente "tubes" → "tube"
3. ✅ **Robusto:** Comparaciones más seguras en engineering rules
4. ✅ **Fácil de mantener:** Agregar nuevas variantes es simple
5. ✅ **No urgente:** Puede ejecutarse cuando sea conveniente

**Implementación:**
- Función `normalize_component_role()` mapea variantes comunes
- Trigger normaliza `affects_role` antes de guardar
- Función `apply_engineering_rules_to_bom_instance()` usa normalización en comparaciones
- Backfill de datos existentes

**Resultado:**
- ✅ "tubes" se guarda como "tube"
- ✅ "brackets" se guarda como "bracket"
- ✅ Comparaciones funcionan incluso con typos
- ✅ No requiere cambios en UI (opcional mejorar UI después)

**Archivo creado:**
- `database/migrations/206_normalize_affects_role_component_roles.sql`

---

**Fin del análisis**

