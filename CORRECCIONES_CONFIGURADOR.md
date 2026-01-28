# Correcciones del Configurador - Resumen

## ✅ Cambios Implementados

### 1. Flujo Unificado de Creación

**Orden correcto (implementado):**
```
1. Insert QuoteLine PRIMERO (con bom_template_id, medidas, etc.)
   ✅ GUARDRAIL: Verificar que retorna ID (returning)
   
2. Create BOMInstance (con quote_line_id NOT NULL)
   ✅ GUARDRAIL: Mutex para evitar doble creación
   
3. Recalcular totales (bom_total, roll_total, msrp, etc.)
   - Solo si ConfiguredProduct existe
   
4. Update QuoteLine con snapshots finales
   - roll_msrp_snapshot, bom_msrp_snapshot, msrp, total_cost
   - pricing_locked = true
```

**Archivo:** `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`

### 2. ConfiguredProduct es Opcional

- **ConfiguredProduct es solo para preview/draft**
- **QuoteLine es la fuente de verdad** para el quote final
- Si ConfiguredProduct existe, se usa para obtener datos iniciales
- Si no existe, QuoteLine se crea directamente con los datos proporcionados
- Los snapshots finales se calculan después de crear BOMInstance

### 3. Auto-selección Mejorada

**Reglas implementadas en `ProductConfigurator.tsx`:**

1. **Mantener template si sigue siendo válido**
   - Si el template previamente seleccionado aún está en `availableTemplates` → mantenerlo

2. **Resetear si se vuelve inválido**
   - Si el template seleccionado ya no está disponible → resetear a `null`

3. **Nunca auto-seleccionar si faltan campos obligatorios**
   - No auto-seleccionar si falta `bottom_bar_sku`, `tube_sku`, o `operation_type`

4. **Nunca auto-seleccionar si hay motor + manual sin operation_type**
   - Si hay templates de motor Y manual disponibles → esperar selección explícita

5. **Solo auto-seleccionar si hay exactamente 1 template**
   - Después de todos los filtros, si queda solo 1 → auto-seleccionar

### 4. Filtrado de Headbox Bidireccional

**Reglas implementadas en `useBOMTemplates.ts`:**

1. **Si `headbox_sku = null` (usuario seleccionó "None")**
   - Excluir templates que tengan slots de headbox
   - Solo templates sin headbox pasan el filtro

2. **Si `headbox_sku` tiene valor**
   - Template DEBE tener slot con ese SKU exacto (trim, case-sensitive)
   - Solo templates con ese SKU exacto pasan el filtro

3. **Si `headbox_sku = undefined` (aún no seleccionado)**
   - No filtrar por headbox (pasa cualquier template)

### 5. Checkbox "ADD BOTTOM CHANNEL"

**Ya estaba correcto en `HardwareStep.tsx`:**
- Checkbox deshabilitado cuando `side_channel_item_id = null`
- Al seleccionar "None" en Side Channel, se limpia `side_channel_item_id = null`
- Esto deshabilita automáticamente el checkbox

### 6. Guardrails Implementados

1. **QuoteLine ID Verification**
   ```typescript
   if (!newQuoteLine?.id) {
     throw new Error('Failed to create QuoteLine: INSERT succeeded but no ID returned');
   }
   ```

2. **BOMInstance Mutex**
   ```typescript
   const bomCreationKey = `bom_creation:${configuredProductId}:${quoteLineId}`;
   // Evita doble creación cuando operation_type cambia rápido
   ```

3. **Validación de campos obligatorios**
   - Antes de auto-seleccionar, verificar que todos los campos obligatorios estén presentes

## 📋 Migración SQL Requerida

**Ejecutar:** `database/migrations/20260127_fix_bom_generation_filter_by_operation_type.sql`

Esta migración corrige el filtrado de slots por `operation_type`:
- Si `operation_type = 'motor'`, excluye slots con `item_role = 'drive'`
- Si `operation_type = 'manual'`, excluye slots con `item_role = 'motor'`

**Sin esta migración, motor y manual seguirán teniendo el mismo precio.**

## 🧪 Testing Checklist

- [ ] Crear quote line con motor → verificar precio
- [ ] Crear quote line con manual → verificar precio diferente
- [ ] Verificar que QuoteLine siempre se inserta y retorna ID
- [ ] Verificar que BOMInstance siempre tiene `quote_line_id NOT NULL`
- [ ] Verificar que checkbox "ADD BOTTOM CHANNEL" se deshabilita cuando Side Channel = "None"
- [ ] Verificar que no hay auto-selección prematura de templates
- [ ] Verificar que headbox "None" excluye templates con headbox
- [ ] Verificar que headbox con SKU solo muestra templates con ese SKU exacto

## 📝 Notas Finales

- **No se crearon archivos V2** - se mejoraron los archivos originales
- **Flujo unificado y documentado** - QuoteLine → BOMInstance → Recalcular → Update QuoteLine
- **ConfiguredProduct es opcional** - QuoteLine es la fuente de verdad
- **Guardrails en todos los puntos críticos** - verificación de IDs, mutex, validaciones
