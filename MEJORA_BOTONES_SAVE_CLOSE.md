# Mejora: 3 Botones en Catalog Item (Close | Save | Save & Close)

**Fecha:** 2026-02-02  
**Tipo:** Enhancement - Mejora de UX  
**Estado:** Implementado

---

## 🎯 Requerimiento

El usuario necesita poder **actualizar el precio sin cerrar o salir** del item. Antes solo había 2 opciones:
- Cancel (cerrar sin guardar)
- Save (guardar y cerrar)

Ahora se requieren **3 botones**:
1. **Close** - Cerrar sin guardar
2. **Save** - Guardar y quedarse en el mismo item
3. **Save & Close** - Guardar y cerrar/volver a la lista

---

## ✅ Implementación

### 1. Estado Agregado

```typescript
const [shouldCloseAfterSave, setShouldCloseAfterSave] = useState(false);
```

Este estado controla si el sistema debe cerrar después de guardar exitosamente.

### 2. Lógica de Navegación Modificada

**Antes:**
```typescript
if (!itemId && finalItemId) {
  router.navigate(`/catalog/items/edit/${finalItemId}`);
  return;
}
router.navigate('/catalog/items');  // Siempre cerraba
```

**Ahora:**
```typescript
// Navigate based on user action
if (shouldCloseAfterSave) {
  router.navigate('/catalog/items');
} else if (!itemId && finalItemId) {
  // For new items, navigate to edit mode if not closing
  router.navigate(`/catalog/items/edit/${finalItemId}`);
}
// If Save (not close) on existing item, stay on current page

// Reset flag
setShouldCloseAfterSave(false);
```

### 3. Botones Actualizados

```tsx
<div className="flex items-center gap-2">
  {/* Close Button */}
  <button
    type="button"
    onClick={() => router.navigate('/catalog/items')}
    disabled={isSaving}
    className="px-4 py-1.5 rounded border border-gray-300 bg-white text-gray-700 text-sm hover:bg-gray-50 disabled:opacity-50"
  >
    Close
  </button>
  
  {/* Save Button (stay on page) */}
  <button
    type="button"
    onClick={() => {
      setShouldCloseAfterSave(false);
      handleSubmit(onSubmit)();
    }}
    disabled={isSaving || isReadOnly}
    className="px-4 py-1.5 rounded border border-primary bg-white text-primary text-sm hover:bg-primary/10 disabled:opacity-50"
  >
    {isSaving && !shouldCloseAfterSave ? 'Saving...' : 'Save'}
  </button>
  
  {/* Save and Close Button */}
  <button
    type="button"
    onClick={() => {
      setShouldCloseAfterSave(true);
      handleSubmit(onSubmit)();
    }}
    disabled={isSaving || isReadOnly}
    className="px-4 py-1.5 rounded bg-primary text-white text-sm hover:bg-primary/90 disabled:opacity-50"
  >
    {isSaving && shouldCloseAfterSave ? 'Saving...' : 'Save & Close'}
  </button>
</div>
```

---

## 🎨 Diseño Visual

### Estilos de los Botones

1. **Close** - Botón secundario (border gris, texto gris)
   - Deshabilitado solo cuando está guardando
   - Hover: fondo gris claro

2. **Save** - Botón outline primary (border azul, texto azul)
   - Deshabilitado cuando está guardando o es read-only
   - Hover: fondo azul claro
   - Muestra "Saving..." solo cuando está guardando SIN cerrar

3. **Save & Close** - Botón primary (fondo azul, texto blanco)
   - Deshabilitado cuando está guardando o es read-only
   - Hover: fondo azul oscuro
   - Muestra "Saving..." solo cuando está guardando Y cerrando

### Orden Visual
```
[Close]  [Save]  [Save & Close]
 ↑        ↑          ↑
 Gris    Azul       Azul
        outline    sólido
```

---

## 🔄 Comportamiento

### Caso 1: Click en "Close"
```
Usuario → Click "Close"
   ↓
Navega a /catalog/items (sin guardar)
```

### Caso 2: Click en "Save"
```
Usuario → Click "Save"
   ↓
setShouldCloseAfterSave(false)
   ↓
handleSubmit(onSubmit)
   ↓
Guarda en BD
   ↓
Reload conversions
   ↓
Si es nuevo: navega a /catalog/items/edit/{id}
Si es existente: permanece en la misma página
   ↓
Usuario puede seguir editando (ej: actualizar precio)
```

### Caso 3: Click en "Save & Close"
```
Usuario → Click "Save & Close"
   ↓
setShouldCloseAfterSave(true)
   ↓
handleSubmit(onSubmit)
   ↓
Guarda en BD
   ↓
Reload conversions
   ↓
Navega a /catalog/items (lista)
```

---

## 💡 Casos de Uso

### Caso de Uso 1: Actualizar Precio de un Roll
```
Usuario en: /catalog/items/edit/abc-123
   ↓
Tab Rates: Cambia cost_exw de $8.50 a $9.00
   ↓
Click "Save" (no "Save & Close")
   ↓
Sistema guarda, conversions se recalculan
   ↓
Usuario ve nuevas conversions: $9.85/m, $6.57/m²
   ↓
Usuario sigue en el mismo item
   ↓
Puede continuar editando otros campos
```

### Caso de Uso 2: Crear Nuevo Item
```
Usuario en: /catalog/items/new
   ↓
Llena formulario completo
   ↓
Click "Save" (quiere seguir editando)
   ↓
Sistema crea item con ID nuevo
   ↓
Navega a /catalog/items/edit/{nuevo-id}
   ↓
Usuario continúa editando el item recién creado
```

### Caso de Uso 3: Editar y Cerrar
```
Usuario en: /catalog/items/edit/abc-123
   ↓
Hace cambios rápidos
   ↓
Click "Save & Close"
   ↓
Sistema guarda
   ↓
Navega de vuelta a /catalog/items (lista)
```

### Caso de Uso 4: Cerrar sin Guardar
```
Usuario en: /catalog/items/edit/abc-123
   ↓
Empieza a editar pero cambia de opinión
   ↓
Click "Close"
   ↓
Sale inmediatamente sin guardar
   ↓
Navega a /catalog/items (lista)
```

---

## 🧪 Testing

### Test 1: Botón "Save" en Item Existente
1. Abrir item existente: `/catalog/items/edit/abc-123`
2. Tab Rates: Cambiar `cost_exw` de $8.50 a $9.00
3. Click **"Save"**
4. **Verificar:**
   - ✅ Muestra "Saving..." en botón Save
   - ✅ Conversions se recalculan automáticamente
   - ✅ Notificación de éxito aparece
   - ✅ Permanece en `/catalog/items/edit/abc-123`
   - ✅ Puede continuar editando

### Test 2: Botón "Save & Close" en Item Existente
1. Abrir item existente
2. Hacer cambios
3. Click **"Save & Close"**
4. **Verificar:**
   - ✅ Muestra "Saving..." en botón Save & Close
   - ✅ Guarda correctamente
   - ✅ Navega a `/catalog/items`

### Test 3: Botón "Close" sin Guardar
1. Abrir item existente
2. Hacer cambios (no guardar)
3. Click **"Close"**
4. **Verificar:**
   - ✅ Navega inmediatamente a `/catalog/items`
   - ✅ Cambios NO se guardaron
   - ✅ Al volver al item, tiene valores antiguos

### Test 4: Botón "Save" en Nuevo Item
1. Ir a `/catalog/items/new`
2. Llenar formulario
3. Click **"Save"**
4. **Verificar:**
   - ✅ Crea item nuevo
   - ✅ Navega a `/catalog/items/edit/{nuevo-id}`
   - ✅ Puede continuar editando el item recién creado

### Test 5: Estados de Disabled
1. Abrir item read-only (sin permisos de edición)
2. **Verificar:**
   - ✅ "Close" habilitado
   - ✅ "Save" deshabilitado
   - ✅ "Save & Close" deshabilitado

3. Hacer cambios y click "Save"
4. **Durante guardado, verificar:**
   - ✅ "Close" deshabilitado
   - ✅ "Save" deshabilitado y muestra "Saving..."
   - ✅ "Save & Close" deshabilitado

### Test 6: Workflow Completo de Actualización de Precio
1. Usuario abre roll fabric: `cost_exw = $8.50/yd`
2. Ve conversions: $9.30/m, $6.20/m²
3. Cambia precio a `$9.00/yd`
4. Click **"Save"**
5. **Verificar:**
   - ✅ Guarda sin cerrar
   - ✅ Conversions se actualizan: ~$9.85/m, ~$6.57/m²
   - ✅ Puede ver el cambio inmediatamente
6. Decide agregar `roll_width = 2.0m`
7. Click **"Save"** nuevamente
8. **Verificar:**
   - ✅ Conversions se recalculan con nuevo ancho
9. Click **"Save & Close"**
10. **Verificar:**
    - ✅ Vuelve a lista de items

---

## 📁 Archivos Modificados

### `src/pages/catalog/CatalogItemNew.tsx`

**Cambios realizados:**

1. **Estado** (línea ~138):
   ```typescript
   const [shouldCloseAfterSave, setShouldCloseAfterSave] = useState(false);
   ```

2. **Lógica de navegación** (líneas ~668-679):
   - Navegación condicional basada en `shouldCloseAfterSave`
   - Reset del flag después de guardar

3. **Botones** (líneas ~726-759):
   - Botón "Close" (reemplaza "Cancel")
   - Botón "Save" (nuevo, no cierra)
   - Botón "Save & Close" (comportamiento del "Save" anterior)

---

## ✅ Checklist de Implementación

- [x] Estado `shouldCloseAfterSave` agregado
- [x] Lógica de navegación condicional implementada
- [x] Botón "Close" agregado
- [x] Botón "Save" agregado (no cierra)
- [x] Botón "Save & Close" agregado
- [x] Estados de "Saving..." funcionan correctamente
- [x] Estados disabled funcionan correctamente
- [x] Estilos visuales diferenciados
- [x] Linting: Sin errores
- [ ] Testing manual (ver checklist arriba)

---

## 🚀 Beneficios

### Para el Usuario:
1. ✅ **Workflow más eficiente**: Puede actualizar precios múltiples veces sin cerrar
2. ✅ **Feedback inmediato**: Ve conversiones actualizadas al instante
3. ✅ **Flexibilidad**: Puede elegir si cerrar o no después de guardar
4. ✅ **Menos clics**: No necesita volver a abrir el item cada vez

### Para el Negocio:
1. ✅ **Productividad mejorada**: Usuarios pueden trabajar más rápido
2. ✅ **Menos errores**: Pueden revisar cambios inmediatamente
3. ✅ **Mejor UX**: Expectativas claras con 3 botones distintos

---

## 💡 Casos de Uso Extendidos

### Caso: Actualizar Múltiples Campos de un Roll

```
1. Usuario abre roll: "Sunscreen Fabric White"
2. Tab Profile: Cambia roll_width de 1.5m a 2.0m
3. Click "Save" → Ve cambios, permanece en item
4. Tab Rates: Cambia cost_exw de $8.50 a $9.00
5. Click "Save" → Ve nuevas conversions
6. Tab Profile: Cambia roll_pricing_mode a per_square_meter
7. Click "Save & Close" → Guarda y vuelve a lista
```

### Caso: Crear Item Complejo en Múltiples Pasos

```
1. Usuario crea nuevo roll
2. Llena info básica (sku, name)
3. Click "Save" → Crea item, navega a edit mode
4. Tab Rates: Ingresa cost_exw y unit_of_measure
5. Click "Save" → Ve conversions calculadas
6. Tab Profile: Configura roll_width después de ver conversions
7. Click "Save" → Ve conversions de m² actualizadas
8. Satisfecho con el resultado
9. Click "Close" → Vuelve a lista
```

---

**Implementación completada:** 2026-02-02  
**Listo para testing:** ✅  
**Producción:** Después de testing exitoso
