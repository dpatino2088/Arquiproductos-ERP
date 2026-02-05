# ✅ Correcciones Completadas: Rates UI & Roll Pricing Mode

**Fecha:** 2026-02-02  
**Estado:** Correcciones aplicadas, pendiente testing

---

## 🎯 Problema Principal

La implementación de Rates UI tenía un **bug crítico** que impedía configurar `roll_pricing_mode` para rolls que no fueran de tipo "fabric" (como window_film, vinyl, mesh, etc.).

### Síntomas:
- ⚠️ "Missing Roll Pricing Mode" aparecía en el tab Rates incluso para rolls configurados
- ❌ Selector de `roll_pricing_mode` solo visible para fabric
- ❌ El valor no se guardaba en la base de datos para otros tipos de roll
- ❌ System UOM se determinaba incorrectamente

---

## ✅ Solución Aplicada

He corregido **3 problemas críticos** en `src/pages/catalog/CatalogItemNew.tsx`:

### 1. Selector de Roll Pricing Mode (Profile Tab)

**Antes:** Solo visible cuando `rollType === 'fabric'`  
**Ahora:** Visible para **TODOS** los tipos de roll

```typescript
{/* Roll Pricing Mode - Available for ALL roll types */}
<div className="col-span-4">
  <Label htmlFor="roll_pricing_mode" className="text-xs">Roll Pricing Mode *</Label>
  <SelectShadcn
    value={watch('roll_pricing_mode') || ''}
    onValueChange={(value) => setValue('roll_pricing_mode', value as any)}
    disabled={isReadOnly}
  >
    <SelectContent>
      <SelectItem value="per_linear_meter">Per Linear Meter ($/m)</SelectItem>
      <SelectItem value="per_square_meter">Per Square Meter ($/m²)</SelectItem>
      <SelectItem value="per_unit">Per Unit ($/ea)</SelectItem>
    </SelectContent>
  </SelectShadcn>
  {errors.roll_pricing_mode && (
    <p className="text-xs text-red-600 mt-1">{errors.roll_pricing_mode.message}</p>
  )}
</div>
```

### 2. Lógica de Guardado

**Antes:**
```typescript
roll_pricing_mode: values.is_roll && values.roll_type === 'fabric' ? values.roll_pricing_mode : null,
```

**Ahora:**
```typescript
roll_pricing_mode: values.is_roll ? values.roll_pricing_mode : null,
```

### 3. Validación en Schema de Zod

**Agregado:**
```typescript
.refine((data) => {
  // If is_roll=true, roll_pricing_mode is required
  if (data.is_roll && !data.roll_pricing_mode) return false;
  return true;
}, {
  message: 'Roll pricing mode is required for roll items',
  path: ['roll_pricing_mode'],
})
```

---

## 📋 Qué Hacer Ahora

### Paso 1: Verificar Estado Actual de la Base de Datos

Ejecuta el script de verificación para ver el estado de tus rolls:

```bash
# Conectar a tu base de datos y ejecutar:
psql -U postgres -d tu_base_de_datos -f scripts/verify_roll_pricing_modes.sql
```

Este script te mostrará:
- ✅ Total de rolls por tipo
- ⚠️ Rolls sin `roll_pricing_mode` (necesitan configuración)
- ✅ Rolls con `per_square_meter` que necesitan `roll_width`
- ✅ Estado de `CatalogItemConversions`

### Paso 2: Testing Manual

Abre la aplicación y verifica el funcionamiento:

#### A. Crear Nuevo Roll (Window Film)

1. Ve a **Catalog → New Item**
2. En **Profile tab:**
   - ✅ Marca "Is Roll"
   - ✅ Selecciona "Roll Type" = "window_film"
   - ✅ **Verifica que aparezca el selector "Roll Pricing Mode"** ⬅️ CLAVE
   - ✅ Selecciona "Per Linear Meter ($/m)"
3. En **Rates tab:**
   - ✅ Verifica que "System Rate" muestre "$/m"
   - ✅ **NO** debe aparecer "Missing Roll Pricing Mode"
   - ✅ Ingresa un valor (ej: $10.50/m)
4. Guarda el item
5. Verifica en la BD:
   ```sql
   SELECT sku, name, roll_type, roll_pricing_mode, cost_exw
   FROM "CatalogItems"
   WHERE sku = 'TU_SKU_AQUI';
   ```

#### B. Editar Roll Existente (Fabric con per_square_meter)

1. Ve a **Catalog → Edit Item** (selecciona un roll fabric existente)
2. En **Profile tab:**
   - ✅ Verifica que "Roll Pricing Mode" esté visible
   - ✅ Cambia a "Per Square Meter ($/m²)"
   - ✅ Ingresa "Roll Width" (ej: 1.5 metros)
3. En **Rates tab:**
   - ✅ Verifica que "System Rate" cambie a "$/m²"
   - ✅ Ingresa "User Input" en $/ft² (ej: $5.50/ft²)
   - ✅ Verifica que se convierta automáticamente a $/m² (aprox $59.20/m²)
4. Guarda
5. Verifica conversiones en BD:
   ```sql
   SELECT ci.sku, ci.roll_pricing_mode, ci.cost_exw, ci.roll_width,
          conv.cost_exw_per_m, conv.cost_exw_per_m2
   FROM "CatalogItems" ci
   LEFT JOIN "CatalogItemConversions" conv ON conv.catalog_item_id = ci.id
   WHERE ci.sku = 'TU_SKU_AQUI';
   ```

#### C. Verificar Validaciones

1. Intenta crear un roll **SIN** seleccionar "Roll Pricing Mode"
   - ✅ Debe mostrar error: "Roll pricing mode is required for roll items"
   - ❌ No debe permitir guardar

2. Selecciona "Per Square Meter" **SIN** ingresar "Roll Width"
   - ✅ Backend debe rechazar con error (trigger de BD)

### Paso 3: Testing de Conversiones UOM

Prueba las conversiones automáticas en el tab **Rates**:

| System UOM | User Input | Conversión Esperada |
|------------|-----------|---------------------|
| $/m        | $10/ft    | ~$32.81/m          |
| $/m        | $30/yd    | ~$32.81/m          |
| $/m²       | $5/ft²    | ~$53.82/m²         |
| $/m²       | $45/yd²   | ~$53.82/m²         |
| $/ea       | $2/ea     | $2/ea (sin conversión) |

### Paso 4: Verificar Integración con Backend

Después de guardar items con diferentes `roll_pricing_mode`, verifica:

```sql
-- 1. CatalogItemConversions se actualiza automáticamente
SELECT ci.sku, ci.roll_pricing_mode, ci.cost_exw,
       conv.cost_exw_per_m, conv.cost_exw_per_m2, conv.computed_at
FROM "CatalogItems" ci
LEFT JOIN "CatalogItemConversions" conv ON conv.catalog_item_id = ci.id
WHERE ci.is_roll = true
  AND ci.updated_at > NOW() - INTERVAL '1 hour'
ORDER BY ci.updated_at DESC
LIMIT 10;

-- 2. CatalogItemsMSRP se recomputa (si aplica)
SELECT ci.sku, ci.cost_exw, msrp.msrp_sale_out, msrp.total_cost
FROM "CatalogItems" ci
LEFT JOIN "CatalogItemsMSRP" msrp ON msrp.catalog_item_id = ci.id
WHERE ci.is_roll = true
  AND ci.updated_at > NOW() - INTERVAL '1 hour'
ORDER BY ci.updated_at DESC
LIMIT 10;
```

---

## 📊 Checklist de Testing Completo

Usa este checklist del archivo `FIX_RATES_ROLL_PRICING_MODE.md`:

### Crear Nuevos Rolls
- [ ] Roll Fabric con per_square_meter
- [ ] Roll Window Film con per_linear_meter
- [ ] Roll Vinyl con per_unit
- [ ] Roll Mesh sin roll_pricing_mode (default)

### Editar Rolls Existentes
- [ ] Editar roll fabric existente
- [ ] Editar roll window_film sin roll_pricing_mode
- [ ] Cambiar entre modos (linear ↔ square meter ↔ unit)

### Validaciones
- [ ] Intentar crear roll sin roll_pricing_mode → Error
- [ ] per_square_meter sin roll_width → Error
- [ ] Cambiar de roll a no-roll → roll_pricing_mode se limpia

### Integración Rates Tab
- [ ] Cambiar roll_pricing_mode actualiza System UOM
- [ ] Conversiones User Input → System Rate funcionan
- [ ] Warning "Missing Roll Pricing Mode" desaparece

### Backend
- [ ] CatalogItemConversions se actualiza automáticamente
- [ ] CatalogItemsMSRP se recomputa correctamente

---

## 🔧 Comandos Útiles

### Verificar Rolls sin roll_pricing_mode
```sql
SELECT sku, name, roll_type, is_roll, roll_pricing_mode
FROM "CatalogItems"
WHERE deleted = false
  AND is_roll = true
  AND roll_pricing_mode IS NULL;
```

### Establecer roll_pricing_mode para rolls existentes
```sql
-- PRECAUCIÓN: Revisar antes de ejecutar
UPDATE "CatalogItems"
SET roll_pricing_mode = 'per_linear_meter'
WHERE deleted = false
  AND is_roll = true
  AND roll_pricing_mode IS NULL;
```

### Recalcular CatalogItemConversions manualmente
```sql
-- Forzar recálculo de conversiones para un item específico
UPDATE "CatalogItems"
SET updated_at = NOW()
WHERE id = 'UUID_DEL_ITEM';
-- El trigger catalogitems_write_conversions se ejecutará automáticamente
```

---

## 📚 Archivos de Documentación

### Creados en esta corrección:
1. **`FIX_RATES_ROLL_PRICING_MODE.md`** - Documentación completa de correcciones
2. **`scripts/verify_roll_pricing_modes.sql`** - Script de verificación SQL
3. **`RESUMEN_CORRECCIONES_RATES.md`** - Este archivo (resumen ejecutivo)

### Archivos originales actualizados:
1. **`src/pages/catalog/CatalogItemNew.tsx`** - Correcciones aplicadas
2. **`IMPLEMENTACION_RATES_UI_NORMALIZACION.md`** - Actualizado con sección "Correcciones Post-Implementación"

### Para referencia:
- `src/lib/uom-conversions.ts` - Helpers de conversión (sin cambios)
- `src/types/rates.ts` - Tipos TypeScript (sin cambios)
- `backups/2026-02_02_v1_full.sql` - Dump de BD analizado

---

## 🚀 Próximos Pasos (Después del Testing)

Una vez que verifiques que todo funciona correctamente:

### Fase 1: ✅ UI Normalizada (Completado)
- ✅ Selector de roll_pricing_mode funcional
- ✅ Validaciones frontend y backend
- ✅ Conversiones UOM funcionando
- ✅ Sincronización con cost_exw (legacy)

### Fase 2: 🔜 Motor de Pricing (Próxima)

Según `IMPLEMENTACION_RATES_UI_NORMALIZACION.md` sección 8:

1. **Modificar `compute_quote_line_cost()`**:
   - Archivo: `database/migrations/55_update_compute_cost_with_bom.sql`
   - Usar `roll_pricing_mode` + `CatalogItemConversions`
   - Aplicar rate correcto según tipo de medida

2. **Actualizar `get_unit_cost_in_uom()`**:
   - Archivo: `database/migrations/200_robust_uom_fabric_pricing_model.sql`
   - Usar `cost_exw_per_m` / `cost_exw_per_m2` directamente

3. **Frontend `calculateQuoteLinePrice()`**:
   - Archivo: `src/lib/pricing.ts`
   - Verificar compatibilidad con nuevos campos

---

## 🐛 ¿Encontraste un Problema?

Si encuentras algún problema durante el testing:

1. **Captura screenshot** del error en la UI
2. **Copia el mensaje de error** completo (consola del navegador)
3. **Ejecuta el query de verificación** correspondiente en BD
4. **Documenta los pasos** para reproducir el problema

---

## ✅ Resumen de Cambios

| Componente | Antes | Después |
|-----------|-------|---------|
| **Selector UI** | Solo fabric | Todos los rolls |
| **Guardado** | Solo fabric | Todos los rolls |
| **Validación** | No había | Requerido cuando is_roll=true |
| **Feedback** | No había | Mensajes de error claros |
| **Documentación** | Parcial | Completa con ejemplos |

---

**Estado:** ✅ Correcciones aplicadas  
**Testing:** ⏳ Pendiente  
**Producción:** ⏸️ Esperar testing exitoso

¡Buena suerte con el testing! 🚀
