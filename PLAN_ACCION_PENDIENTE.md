# 📋 Plan de Acción - Tareas Pendientes

## 🎯 Problemas Principales Identificados

### 1. **BOM solo genera fabric** ❌
- **Síntoma**: Solo aparecen componentes de tela en Manufacturing Order BOM
- **Causa posible**: `block_condition` no hace match, o `generate_configured_bom_for_quote_line` tiene lógica incorrecta
- **Estado**: En diagnóstico

### 2. **UOM de fabrics muestra "ea"** ❌
- **Síntoma**: Telas muestran UOM "ea" en lugar de "m" o "m2"
- **Causa**: `CatalogItems.uom` o función de generación no fuerza UOM correcto
- **Estado**: Scripts creados pero problema persiste

### 3. **Tabla Profiles** ✅
- **Estado**: Tabla independiente y correcta (perfiles de usuario)
- **Nota**: No requiere corrección - es una tabla legítima separada de `ProductOptionValues`

---

## ✅ Tareas Completadas

- [x] Scripts de diagnóstico creados
- [x] Script `COMPLETE_FIX_ALL_ISSUES.sql` creado
- [x] Script `ENSURE_ORGANIZATION_ID_BOMINSTANCELINES.sql` creado
- [x] Script `FIX_MIGRATION_177_ADD_ORG_ID.sql` creado
- [x] Script `VERIFY_PROFILES_TABLE.sql` creado

---

## 🔴 Tareas Pendientes (Prioridad Alta)

### **TAREA 1: Ejecutar diagnóstico completo del BOM**
**Script**: `DIAGNOSE_WHY_ONLY_FABRIC_GENERATED.sql`
- **Objetivo**: Identificar por qué solo se genera fabric
- **Pasos**:
  1. Ejecutar script completo
  2. Revisar Step 4 (simulación de `block_condition` matching)
  3. Identificar qué componentes deberían generarse y por qué no se generan
- **Resultado esperado**: Lista de componentes que fallan el match y razón

### **TAREA 2: Ejecutar fix completo de BOM**
**Script**: `COMPLETE_FIX_ALL_ISSUES.sql`
- **Objetivo**: Aplicar todas las correcciones en un solo script
- **Pasos**:
  1. Ejecutar script completo
  2. Verificar resultados en `QuoteLineComponents`
  3. Verificar resultados en `BomInstanceLines`
  4. Verificar en UI (Manufacturing Order Materials)
- **Resultado esperado**: Todos los componentes visibles en UI con UOM correcto

### **TAREA 3: Verificar flujo completo end-to-end**
**Objetivo**: Probar que el flujo completo funciona
- **Pasos**:
  1. Crear nuevo Quote con configuración completa
  2. Aprobar Quote → debe generar Sale Order
  3. Verificar que Sale Order tiene todos los componentes
  4. Verificar que Manufacturing Order muestra todos los materiales
  5. Verificar UOM de fabrics (debe ser "m" o "m2", nunca "ea")
- **Resultado esperado**: Flujo completo funciona sin errores

---

## 🟡 Tareas Pendientes (Prioridad Media)

### **TAREA 4: Revisar función `generate_configured_bom_for_quote_line`**
- **Objetivo**: Verificar lógica de `block_condition` matching
- **Pasos**:
  1. Revisar código de la función
  2. Verificar si hay typos (ej: 'casette' vs 'cassette')
  3. Verificar lógica de `block_condition` JSONB matching
  4. Probar con diferentes configuraciones
- **Resultado esperado**: Función genera todos los componentes correctamente

### **TAREA 5: Verificar BOM Templates activos**
- **Objetivo**: Asegurar que solo hay un template activo por ProductType
- **Script**: `FIX_MULTIPLE_BOM_TEMPLATES.sql` (ya existe)
- **Pasos**:
  1. Verificar que no hay múltiples templates activos
  2. Verificar que todos los componentes tienen `component_item_id` o `auto_select = true`
  3. Verificar que `block_condition` está correctamente configurado
- **Resultado esperado**: Un solo template activo por ProductType con componentes correctos

---

## 🟢 Tareas Pendientes (Prioridad Baja)

### **TAREA 6: Documentar estructura de BOM**
- **Objetivo**: Crear documentación clara del sistema BOM
- **Contenido**:
  - Cómo funcionan los BOM Templates
  - Cómo funcionan los `block_condition`
  - Cómo se resuelven los SKUs
  - Cómo se calculan las cantidades

### **TAREA 7: Optimizar queries de BOM**
- **Objetivo**: Asegurar que no hay N+1 queries
- **Pasos**:
  1. Revisar queries en `useManufacturingMaterials`
  2. Verificar que `SaleOrderMaterialList` está optimizada
  3. Agregar índices si es necesario

---

## 📝 Scripts Disponibles

### Diagnósticos
- `DIAGNOSE_WHY_ONLY_FABRIC_GENERATED.sql` - Diagnóstico completo del problema
- `CHECK_UI_DATA_SOURCE.sql` - Verificar datos en UI

### Fixes
- `COMPLETE_FIX_ALL_ISSUES.sql` - Fix completo (org_id, UOM, BOM, copy)
- `FIX_FABRIC_UOM_EA_FINAL.sql` - Fix específico para UOM de fabrics
- `FIX_MIGRATION_177_ADD_ORG_ID.sql` - Fix para incluir org_id en función

---

## 🚀 Próximos Pasos Inmediatos

1. **Ejecutar `DIAGNOSE_WHY_ONLY_FABRIC_GENERATED.sql`** para diagnosticar BOM
2. **Revisar resultados** y aplicar correcciones necesarias
3. **Ejecutar `COMPLETE_FIX_ALL_ISSUES.sql`** para aplicar todas las correcciones
4. **Probar flujo completo** creando un nuevo Quote y verificando BOM

---

## ⚠️ Notas Importantes

- **NO usar `family`** en ningún filtro o join
- **Fabric UOM** debe ser siempre "m" o "m2", nunca "ea"
- **organization_id** debe estar presente en todas las tablas multi-org
- **block_condition** debe hacer match correctamente con la configuración del QuoteLine
- **Side Channel y Bottom Rail** son independientes (no se afectan mutuamente)

---

## 📊 Estado Actual

- **BOM Generation**: ❌ Solo genera fabric
- **Fabric UOM**: ❌ Muestra "ea" en lugar de "m"/"m2"
- **UI Display**: ❌ No muestra todos los componentes
- **Tabla Profiles**: ✅ Tabla independiente y correcta
- **organization_id**: ✅ Corregido en BomInstanceLines
- **BOM Templates**: ✅ Estructura correcta

---

**Última actualización**: 2025-12-21

