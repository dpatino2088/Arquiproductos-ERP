# PATCH: Bottom Bar Filtering Fix - COMPLETADO

## 🎯 Objetivo del Patch

**Bottom Bar solo filtra cuando está SELECTED**
- Nunca excluir templates por ausencia de bottom_bar
- Bottom Bar es hard-required (debe existir en el template, pero no filtra si no está seleccionado)

## ✅ Cambios Implementados

### 1. Constante `REQUIRED_TEMPLATE_ROLES`

```typescript
// ✅ CONSTANTE: Roles que SIEMPRE deben existir en el template (hard-required)
const REQUIRED_TEMPLATE_ROLES = new Set<string>([
  'bottom_bar',
  'tube',
]);
```

### 2. Filtrado de Bottom Bar Corregido

**Antes:**
- Filtraba incluso cuando `bottom_bar_sku` era `undefined`/`null`
- Excluía templates por ausencia de bottom_bar

**Después:**
- ✅ Solo filtra cuando `bottom_bar_sku` tiene valor válido (SELECTED)
- ✅ Si `bottom_bar_sku` es `undefined`/`null`/`''` → NO filtra (templates siguen apareciendo)
- ❌ Eliminado el bloque `else` que manejaba UNSET como "no coincide"

### 3. Blindaje Defensivo Agregado

Al final del filtrado, verifica que el template tenga roles requeridos:
- Solo excluye si el template NO tiene el rol (template mal formado)
- NO excluye si el usuario no ha seleccionado el SKU

### 4. Logs de Debug Detallados

Agregados logs específicos para validación:

```typescript
// Log inicial antes del filtrado
[useBOMTemplates] 📊 [BOTTOM_BAR_FILTER] Starting filtering phase

// Log por cada template evaluado
[useBOMTemplates] 🔍 [BOTTOM_BAR_FILTER] Starting filter for template...
[useBOMTemplates] 🔍 [BOTTOM_BAR_FILTER] Comparing SKUs: { slotSku, expectedSku, matches }

// Log cuando template pasa/falla
[useBOMTemplates] ✅ [BOTTOM_BAR_FILTER] Template MATCHES
[useBOMTemplates] ❌ [BOTTOM_BAR_FILTER] Template FILTERED OUT

// Log resumen final
[useBOMTemplates] 📊 [BOTTOM_BAR_FILTER] Summary: {
  templatesBefore,
  templatesAfter,
  templatesFilteredOut,
  remainingTemplates
}
```

## 📁 Archivos Modificados

- `src/hooks/useBOMTemplates.ts`
  - Agregada constante `REQUIRED_TEMPLATE_ROLES`
  - Corregido filtrado de `bottom_bar` (solo cuando SELECTED)
  - Agregado blindaje defensivo para roles requeridos
  - Agregados logs de debug detallados

## 🧪 Validaciones Requeridas

### Escenario 1: Bottom Bar UNSET (sin seleccionar)

**Pasos:**
1. Entrar a Hardware step
2. NO seleccionar Bottom Bar (dejar sin seleccionar)

**Resultado Esperado:**
- ✅ Templates deben aparecer (no se filtran)
- ✅ Log debe mostrar: `bottom_bar_sku is UNSET, skipping filter (templates continue)`

### Escenario 2: Bottom Bar SELECTED

**Pasos:**
1. Entrar a Hardware step
2. Seleccionar Bottom Bar "RCA-04-W"

**Resultado Esperado:**
- ✅ Templates se filtran a los que tienen `bottom_bar` con SKU "RCA-04-W"
- ✅ Log debe mostrar: `[BOTTOM_BAR_FILTER] Summary` con conteo antes/después
- ✅ Log debe mostrar: `Comparing SKUs: { slotSku: "RCA-04-W", expectedSku: "RCA-04-W", matches: true }`

### Escenario 3: Cambiar Bottom Bar

**Pasos:**
1. Seleccionar Bottom Bar "RCA-04-W" → ver templates filtrados
2. Cambiar a otro Bottom Bar (ej: "RCA-04-W_2")

**Resultado Esperado:**
- ✅ Templates cambian a los que tienen el nuevo SKU
- ✅ Log debe mostrar el cambio de `expectedSku`

### Escenario 4: Side/Bottom Channel

**Pasos:**
1. Seleccionar Side Channel "None" o un SKU específico
2. Marcar/desmarcar "ADD BOTTOM CHANNEL"

**Resultado Esperado:**
- ✅ UI cambia (selección se guarda)
- ✅ Template count NO cambia (side_channel y bottom_channel NO filtran templates)

## 🔍 Cómo Validar con Logs

1. Abrir DevTools Console
2. Filtrar por `[BOTTOM_BAR_FILTER]`
3. Verificar:
   - `Starting filtering phase`: muestra conteo inicial
   - `Comparing SKUs`: muestra comparación exacta
   - `Summary`: muestra conteo antes/después

**Ejemplo de log esperado:**

```
[useBOMTemplates] 📊 [BOTTOM_BAR_FILTER] Starting filtering phase {
  templatesBeforeFiltering: 10,
  bottom_bar_sku: "RCA-04-W",
  bottom_bar_item_id: "57c04500-3931-44fd-9272-05e199f1b6c2"
}

[useBOMTemplates] 🔍 [BOTTOM_BAR_FILTER] Comparing SKUs: {
  slotSku: "RCA-04-W",
  expectedSku: "RCA-04-W",
  matches: true,
  item_role: "bottom_bar"
}

[useBOMTemplates] ✅ [BOTTOM_BAR_FILTER] Template MATCHES {
  expectedSku: "RCA-04-W",
  matchingSlots: [...]
}

[useBOMTemplates] 📊 [BOTTOM_BAR_FILTER] Summary: {
  bottom_bar_sku: "RCA-04-W",
  templatesBefore: 10,
  templatesAfter: 3,
  templatesFilteredOut: 7,
  remainingTemplates: [...]
}
```

## ⚠️ Alertas Importantes

### Blindaje Defensivo

El blindaje verifica que templates tengan roles requeridos (`bottom_bar`, `tube`). Si un template tiene el rol con un nombre diferente (ej: `bottom_bar_profile`, `bottom_rail`), será excluido.

**Validar:**
- Si en tu DB el `item_role` es exactamente `bottom_bar` y `tube` → ✅ Perfecto
- Si hay variaciones de nombres → ajustar el blindaje para aceptar variaciones

### Naming de Roles

Si encuentras templates válidos siendo excluidos por el blindaje, revisa:
1. Los `item_role` reales en `BOMTemplateSlots`
2. Ajustar el blindaje para aceptar variaciones si es necesario

## 📝 Notas Técnicas

- **Bottom Bar** y **Tube** son roles hard-required: deben existir en el template (estructura)
- Pero solo filtran por SKU cuando el usuario eligió uno (SELECTED)
- Si el usuario no ha seleccionado (UNSET), templates siguen apareciendo
- Side Channel y Bottom Channel NO filtran templates (solo afectan BOM generation)

## ✅ Estado

- [x] Constante `REQUIRED_TEMPLATE_ROLES` agregada
- [x] Filtrado de Bottom Bar corregido (solo cuando SELECTED)
- [x] Blindaje defensivo implementado
- [x] Logs de debug detallados agregados
- [x] Tube actualizado con misma lógica
- [ ] Validación en UI (pendiente usuario)
- [ ] Verificar blindaje no excluye templates válidos (pendiente usuario)
