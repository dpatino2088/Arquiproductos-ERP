# Guía: Solución Integral BOM - Solo Telas

## 🎯 Objetivo
Resolver completamente el problema de que el BOM solo muestra telas, asegurando que todos los componentes necesarios aparezcan correctamente.

## 📋 Archivos Creados

### 1. Diagnóstico
- **`DIAGNOSE_BOM_COMPLETE.sql`**: Diagnóstico completo con 6 steps detallados
- **`SOLUCION_INTEGRAL_BOM_MASTER.sql`**: Script maestro que ejecuta diagnóstico y proporciona guía

### 2. Correcciones por Escenario
- **`FIX_BOM_TEMPLATE_COMPONENTS.sql`**: Agrega componentes faltantes al BOMTemplate
- **`FIX_BOM_COMPONENTS_RESOLUTION.sql`**: Mapea BOMComponents a CatalogItems
- **`FIX_BLOCK_CONDITIONS.sql`**: Ajusta block_conditions para que coincidan con configuraciones
- **`TEST_GENERATE_BOM_MANUAL.sql`**: Prueba la función manualmente

### 3. Ya Existentes
- **`FIX_MISSING_BOTTOM_RAIL_TYPE.sql`**: Corrige bottom_rail_type NULL (ya ejecutado)

## 🚀 Plan de Ejecución Paso a Paso

### PASO 1: Diagnóstico Inicial

Ejecuta **`SOLUCION_INTEGRAL_BOM_MASTER.sql`** con tu Sale Order number:

```sql
-- Cambia 'SO-000003' por tu Sale Order number real
```

Este script:
- Identifica problemas automáticamente
- Muestra qué scripts de corrección necesitas ejecutar
- Proporciona IDs necesarios (BOMTemplate ID, Organization ID, etc.)

### PASO 2: Diagnóstico Detallado

Ejecuta **`DIAGNOSE_BOM_COMPLETE.sql`** para ver detalles completos de los 6 steps:

```sql
-- Cambia 'SO-000003' por tu Sale Order number real
```

Revisa cada step:
- **STEP 1**: Configuración de QuoteLine
- **STEP 2**: BOMTemplate y componentes
- **STEP 3**: Resolución de BOMComponents
- **STEP 4**: QuoteLineComponents generados
- **STEP 5**: BomInstanceLines finales
- **STEP 6**: Simulación de block condition matching

### PASO 3: Aplicar Correcciones

Basado en los resultados, ejecuta los scripts correspondientes:

#### Si STEP 2 muestra "Only fabric component":
```sql
-- Ejecutar FIX_BOM_TEMPLATE_COMPONENTS.sql
-- Reemplazar 'YOUR_BOM_TEMPLATE_ID' y 'YOUR_ORGANIZATION_ID' con valores reales
```

#### Si STEP 3 muestra "MISSING: Cannot resolve":
```sql
-- Ejecutar FIX_BOM_COMPONENTS_RESOLUTION.sql
-- Reemplazar 'YOUR_BOM_TEMPLATE_ID' y 'YOUR_ORGANIZATION_ID' con valores reales
-- Revisar las sugerencias de CatalogItems y actualizar component_item_id
```

#### Si STEP 6 muestra muchos "BLOCKED":
```sql
-- Ejecutar FIX_BLOCK_CONDITIONS.sql
-- Reemplazar 'YOUR_BOM_TEMPLATE_ID' con valor real
-- Ajustar block_conditions según tus necesidades
```

### PASO 4: Prueba Manual

Ejecuta **`TEST_GENERATE_BOM_MANUAL.sql`** para probar la función:

```sql
-- Reemplazar todos los valores placeholder con valores reales
-- Revisar el resultado JSONB
-- Verificar QuoteLineComponents generados
```

### PASO 5: Verificación Final

Después de aplicar correcciones:

1. **Re-configurar el QuoteLine** en la UI
2. **Verificar QuoteLineComponents**:
   ```sql
   SELECT component_role, COUNT(*) 
   FROM "QuoteLineComponents" 
   WHERE quote_line_id = 'YOUR_QUOTE_LINE_ID'
     AND source = 'configured_component'
     AND deleted = false
   GROUP BY component_role;
   ```
   **Esperado**: Múltiples component_role (fabric, operating_system_drive, tube, bracket, etc.)

3. **Aprobar el Quote** y verificar BomInstanceLines:
   ```sql
   SELECT category_code, COUNT(*) 
   FROM "BomInstanceLines" bil
   INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
   INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
   WHERE sol.sale_order_id = 'YOUR_SALE_ORDER_ID'
     AND bil.deleted = false
   GROUP BY category_code;
   ```
   **Esperado**: Múltiples category_code (fabric, motor, tube, bracket, etc.)

## 🔍 Interpretación de Resultados

### STEP 1: Configuración
- ✅ **OK**: Todos los campos tienen valores
- ❌ **MISSING**: Ejecutar `FIX_MISSING_BOTTOM_RAIL_TYPE.sql` (ya hecho)

### STEP 2: BOMTemplate
- ✅ **OK**: Múltiples componentes
- ❌ **Only fabric**: Ejecutar `FIX_BOM_TEMPLATE_COMPONENTS.sql`

### STEP 3: Resolución
- ✅ **OK**: Todos pueden resolverse
- ❌ **MISSING**: Ejecutar `FIX_BOM_COMPONENTS_RESOLUTION.sql`

### STEP 4: QuoteLineComponents
- ✅ **OK**: Múltiples component_role
- ❌ **Only fabric**: El problema está en la generación (revisar STEP 2, 3, 6)

### STEP 5: BomInstanceLines
- ✅ **OK**: Múltiples category_code
- ❌ **Only fabric**: Esperado si STEP 4 solo tiene fabric

### STEP 6: Block Conditions
- ✅ **SHOULD MATCH**: Componentes deberían generarse
- ❌ **BLOCKED**: Ejecutar `FIX_BLOCK_CONDITIONS.sql`

## 📝 Notas Importantes

1. **Orden de ejecución**: Siempre ejecutar diagnóstico antes de correcciones
2. **IDs necesarios**: Los scripts de corrección requieren BOMTemplate ID y Organization ID
3. **Testing**: Después de cada corrección, probar re-generando el BOM
4. **Logs**: Revisar logs de Supabase para errores o warnings de la función

## 🎯 Resultado Esperado

Después de aplicar todas las correcciones:
- ✅ QuoteLineComponents tiene múltiples component_role
- ✅ BomInstanceLines tiene múltiples category_code
- ✅ El Manufacturing Order muestra todos los componentes necesarios








