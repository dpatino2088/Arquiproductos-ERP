# 🔧 FIX: Problema "No se puede agregar hijos" - Frontend

**Fecha:** 20 de Enero, 2026  
**Problema:** No se pueden agregar hijos en BOM Templates  
**Causa Raíz:** Frontend - Payload incompleto o errores no mostrados

---

## ✅ CORRECCIONES APLICADAS

### **1. Validación explícita de `organization_id`**

**Problema:** Si `organization_id` viene `undefined/null`, RLS bloquea silenciosamente el insert.

**Solución:**
```typescript
// ✅ Validación ANTES del insert
if (!payload.organization_id) {
  throw new Error('organization_id is missing - RLS will block this insert');
}

// ✅ Payload explícito (NO confiar en triggers)
const payload = {
  organization_id: activeOrganizationId, // 👈 CRÍTICO: Debe estar explícito
  parent_item_id: editingParentComponentId,
  child_item_id: childFormData.child_item_id,
  child_role: normalizedChildRole,
  // ...
};
```

**Archivo:** `src/pages/catalog/BOMTemplates.tsx` (líneas 2162-2172)

---

### **2. Validación de `child_role` contra CHECK constraint**

**Problema:** Si `child_role` no pasa el CHECK constraint (valores como 'end-cap', 'End Cap', etc.), el error no se muestra.

**Solución:**
```typescript
// ✅ Normalizar y validar ANTES del insert
const normalizedChildRole = normalizeSubRole(childFormData.child_role || '') || childFormData.child_role || '';

// ✅ Validar contra lista permitida (CHECK constraint)
if (!normalizedChildRole || !childRoleOptions.includes(normalizedChildRole)) {
  const errorMsg = `Invalid child role: "${childFormData.child_role}" → "${normalizedChildRole}". Valid roles: ${childRoleOptions.join(', ')}`;
  console.error('[handleAddChild] Child role validation failed:', errorMsg);
  // Mostrar error claro
  return;
}

// ✅ Validación final antes de insertar
if (!payload.child_role || !childRoleOptions.includes(payload.child_role)) {
  throw new Error(`Invalid child_role: "${payload.child_role}". Valid roles: ${childRoleOptions.join(', ')}`);
}
```

**Valores permitidos (CHECK constraint):**
- `adapter`, `end_cap`, `screw`, `fastener`, `idler`, `chain_stop`, `chain_tensioner`, `end_plug`, `filler`, `washer`, `nut`, `bolt`, `clip`, `pin`

**Archivo:** `src/pages/catalog/BOMTemplates.tsx` (líneas 2129-2137, 2191-2192)

---

### **3. Manejo de errores sin objetos circulares**

**Problema:** Errores se "tragaban" porque se logueaban objetos completos con referencias circulares.

**Solución:**
```typescript
// ✅ ANTES (incorrecto):
catch (err) {
  console.log(err); // ❌ objeto circular
}

// ✅ DESPUÉS (correcto):
if (error) {
  const safeErr = {
    message: error?.message || 'Unknown error',
    code: error?.code || 'UNKNOWN',
    details: error?.details || null,
    hint: error?.hint || null,
  };
  console.error("CatalogItemComponents INSERT/UPDATE error", safeErr);
  throw errorMessage;
}

catch (err) {
  const safeErr = {
    message: err instanceof Error ? err.message : String(err),
    code: (err as any)?.code || null,
    details: (err as any)?.details || null,
    hint: (err as any)?.hint || null,
  };
  console.error('[handleAddChild] Error caught:', safeErr);
  // Mostrar notificación con mensaje claro
}
```

**Archivo:** `src/pages/catalog/BOMTemplates.tsx` (líneas 2228-2250, 2252-2285)

---

### **4. Mapeo de códigos de error SQL a mensajes user-friendly**

**Problema:** Errores SQL (23505, 23503, 23514, etc.) no se traducían a mensajes claros.

**Solución:**
```typescript
let userMessage = safeErr.message || 'Failed to add child component';

if (safeErr.code === '23505') {
  userMessage = 'This child component already exists for this parent';
} else if (safeErr.code === '23503') {
  userMessage = 'Invalid parent or child item ID. Please verify the SKUs exist.';
} else if (safeErr.code === '23514') {
  // ✅ CHECK constraint violation (child_role)
  userMessage = `Invalid child role. Valid roles are: ${childRoleOptions.join(', ')}. You sent: "${childFormData.child_role}"`;
} else if (safeErr.code === '42501') {
  userMessage = 'Permission denied. Please check RLS policies.';
} else if (safeErr.hint) {
  userMessage = `${userMessage}\n\nHint: ${safeErr.hint}`;
}
```

**Archivo:** `src/pages/catalog/BOMTemplates.tsx` (líneas 2300-2318)

---

### **5. Logging detallado para debugging**

**Problema:** No había suficiente información para diagnosticar problemas.

**Solución:**
```typescript
// ✅ Logging antes del insert (como sugiere el usuario)
console.log("INSERT CatalogItemComponents payload", {
  organization_id: payload.organization_id,
  parent_item_id: payload.parent_item_id,
  child_item_id: payload.child_item_id,
  child_role: payload.child_role,
  qty: payload.qty,
  uom: payload.uom,
  required: payload.required,
  sort_order: payload.sort_order,
});

// ✅ Logging antes de intentar agregar
console.log("ADD CHILD DEBUG", {
  editingChildId,
  editingParentComponentId,
  activeOrganizationId,
  childFormData: {
    child_item_id: childFormData.child_item_id,
    child_role: childFormData.child_role,
    qty: childFormData.qty,
    uom: childFormData.uom,
    required: childFormData.required,
    notes: childFormData.notes,
  },
  childRoleOptions,
});

// ✅ Logging de normalización de child_role
console.log('[handleAddChild] Child role normalization:', {
  original: childFormData.child_role,
  normalized: normalizedChildRole,
  isValid: childRoleOptions.includes(normalizedChildRole),
  validOptions: childRoleOptions,
});
```

**Archivo:** `src/pages/catalog/BOMTemplates.tsx` (múltiples lugares)

---

## 🧪 PRUEBA FINAL

### **Pasos para verificar:**

1. **Abrir Console (F12)**
2. **Abrir modal "Add Child"**
3. **Click en "Add Child Component"**
4. **Buscar SKU hijo y seleccionar**
5. **Seleccionar child role**
6. **Click en "Add Child"**

### **Verificar en Console:**

✅ Debe aparecer:
```
ADD CHILD DEBUG { ... }
[handleAddChild] Child role normalization: { ... }
INSERT CatalogItemComponents payload { ... }
INSERT CatalogItemComponents { ... }
```

❌ Si hay error, debe aparecer:
```
CatalogItemComponents INSERT/UPDATE error { message, code, details, hint }
[handleAddChild] Error caught: { ... }
```

### **Verificar valores:**

- ✅ `organization_id` debe ser un UUID válido (no `undefined` o `null`)
- ✅ `child_role` debe ser exactamente uno de: `adapter`, `end_cap`, `screw`, etc.
- ✅ `parent_item_id` debe ser un UUID válido
- ✅ `child_item_id` debe ser un UUID válido
- ✅ `qty` debe ser un número
- ✅ `uom` debe ser un string (no `null`)

---

## 🔍 DIAGNÓSTICO DE PROBLEMAS

### **Si `organization_id` es `undefined`:**

**Causa:** `activeOrganizationId` no está disponible en el contexto.

**Solución:**
```typescript
// Verificar que useOrganizationContext() retorna activeOrganizationId
const { activeOrganizationId } = useOrganizationContext();

// Si es null, mostrar error claro
if (!activeOrganizationId) {
  useUIStore.getState().addNotification({
    type: 'error',
    title: 'Error',
    message: 'Organization ID is missing. Please select an organization.',
  });
  return;
}
```

### **Si `child_role` falla CHECK constraint:**

**Causa:** El valor no está en la lista permitida.

**Solución:**
- Verificar que `normalizeSubRole()` está normalizando correctamente
- Verificar que el valor está en `childRoleOptions`
- Verificar que no hay espacios extra o caracteres especiales

### **Si el error no se muestra:**

**Causa:** Objeto circular en el catch.

**Solución:**
- Ya corregido: usar `safeErr` en lugar de `err` completo
- Verificar que `useUIStore.getState().addNotification()` se está llamando

---

## 📝 CHECKLIST DE VERIFICACIÓN

- [x] `organization_id` se valida antes del insert
- [x] `child_role` se normaliza y valida contra CHECK constraint
- [x] Errores se extraen de forma segura (sin objetos circulares)
- [x] Códigos de error SQL se mapean a mensajes user-friendly
- [x] Logging detallado para debugging
- [x] Validación de duplicados antes de insertar
- [x] Mensajes de error claros y descriptivos

---

## 🚀 PRÓXIMOS PASOS

1. **Probar en DEV:**
   - Abrir Console (F12)
   - Intentar agregar hijo
   - Verificar logs
   - Verificar que el error se muestra si falla

2. **Si aún no funciona:**
   - Revisar logs en Console
   - Verificar que `activeOrganizationId` está disponible
   - Verificar permisos RLS en Supabase
   - Verificar que los SKUs existen

3. **Si funciona:**
   - Remover logs de debug excesivos (mantener solo los críticos)
   - Documentar el flujo para el equipo

---

**Fin del Fix**
