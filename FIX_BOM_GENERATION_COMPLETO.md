# ✅ FIX COMPLETO: BOM Generation Failed

**Fecha:** 2026-01-20  
**Problema:** "BOM Generation Failed" - la RPC `generate_bom_from_slots()` está fallando

---

## 🔍 PROBLEMA IDENTIFICADO

1. **Frontend no muestra el error real del RPC:**
   - Solo muestra mensaje genérico "BOM Generation Failed"
   - No muestra `error.details` ni `error.hint`
   - Los logs muestran "[circular]" en lugar del error real

2. **RLS probablemente bloqueando inserts:**
   - La función `generate_bom_from_slots` no es `SECURITY DEFINER`
   - Ejecuta con permisos del usuario, y RLS bloquea inserts en `BOMInstances`/`BOMInstanceLines`

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **1. Frontend: Mostrar error real del RPC**

**En `src/pages/sales/QuoteNew.tsx`:**

✅ Agregada función `safeErr()` para serialización segura de errores
✅ Reemplazada llamada a `generate_bom_from_slots` para:
  - Loggear args con `console.log`
  - Si hay error, mostrar `safeErr(error)` completo
  - Notification con `error.message + error.details + error.hint`
  - **Return inmediato** si hay error (no continuar a pricing)

**Código:**
```typescript
const rpcArgs = {
  p_org_id: activeOrganizationId,
  p_quote_line_id: finalLineId,
  p_product_type_id: productTypeId,
};

console.log("🔧 RPC generate_bom_from_slots args:", rpcArgs);

const { data: bomInstanceId, error: bomError } = await supabase.rpc(
  'generate_bom_from_slots',
  rpcArgs
);

if (bomError) {
  console.error("❌ RPC generate_bom_from_slots failed:", safeErr(bomError));
  
  const errorMsg = 
    (bomError.message ?? "Unknown RPC error") +
    (bomError.details ? ` | ${bomError.details}` : "") +
    (bomError.hint ? ` | Hint: ${bomError.hint}` : "");

  useUIStore.getState().addNotification({
    type: 'error',
    title: 'BOM Generation Failed',
    message: errorMsg,
  });

  // IMPORTANT: stop aquí (si sigues a pricing, vas a 0 o inconsistente)
  return;
}

console.log("✅ RPC generate_bom_from_slots OK:", bomInstanceId);
```

### **2. Fix "Error getting user profile [circular]"**

**En `src/lib/supabase/client.ts`:**
- ✅ Ya usa `safeErr()` para serialización segura

### **3. SQL para verificar y fixear función**

**Archivos creados:**
- ✅ `backups/FIX_GENERATE_BOM_FROM_SLOTS.sql` - Queries de diagnóstico
- ✅ `backups/FIX_GENERATE_BOM_FROM_SLOTS_SECURITY_DEFINER.sql` - Fix completo

---

## 🚀 EJECUTAR SQL

### **Paso 1: Verificar estado actual**
```sql
-- Ejecutar: backups/FIX_GENERATE_BOM_FROM_SLOTS_SECURITY_DEFINER.sql
-- Paso 1: Verificar si ya es SECURITY DEFINER
```

**Si `is_security_definer = false` → ejecutar pasos 2-4**

### **Paso 2-4: Convertir a SECURITY DEFINER**
```sql
-- Ejecutar pasos 2, 3 y 4 del mismo archivo
-- Esto convierte la función a SECURITY DEFINER
-- Con esto, la función ejecuta como postgres owner y bypassea RLS
```

### **Paso 5: Verificar que quedó bien**
```sql
-- Ejecutar paso 5 para confirmar que is_security_definer = true
```

---

## 🧪 PRUEBA

### **1. Reiniciar dev server:**
```bash
# Ctrl+C y luego npm run dev
```

### **2. Hard refresh:**
- `Cmd+Shift+R` (Mac) o `Ctrl+Shift+R` (Windows)

### **3. Probar crear Quote Line:**
1. Abrir `/sales/quotes/new`
2. Click "Add Line"
3. Configurar producto "roller-shade"
4. Click "Add to Quote"

### **4. Verificar en consola:**
- ✅ Debe aparecer: `🔧 RPC generate_bom_from_slots args: {...}`
- ✅ Si hay error, debe aparecer: `❌ RPC generate_bom_from_slots failed:` con detalles completos
- ✅ Si funciona, debe aparecer: `✅ RPC generate_bom_from_slots OK: <id>`
- ✅ El error debe mostrar `message`, `details`, `hint`, `code`

### **5. Verificar en UI:**
- ✅ Si hay error, notification debe mostrar el mensaje completo con detalles
- ✅ NO debe aparecer mensaje genérico "BOM Generation Failed"
- ✅ Si funciona, debe aparecer `✅ BOM Instance created`

---

## 📋 VERIFICACIÓN

### **Frontend:**
- ✅ `safeErr()` agregada en `QuoteNew.tsx`
- ✅ Llamada a RPC muestra error completo
- ✅ "Error getting user profile" usa `safeErr()`

### **Backend (ejecutar SQL):**
- ⏳ Verificar si función es `SECURITY DEFINER`
- ⏳ Si no, convertir a `SECURITY DEFINER`
- ⏳ Grant execute a `authenticated`

---

## 🔄 SIGUIENTE PASO

1. **Ejecutar SQL:** `backups/FIX_GENERATE_BOM_FROM_SLOTS_SECURITY_DEFINER.sql`
2. **Reiniciar dev server**
3. **Probar crear Quote Line**
4. **Verificar que el error real se muestra en consola y UI**

**Si aún falla:**
- El error en consola ahora mostrará `details` y `hint` reales
- Con eso podemos diagnosticar si es:
  - RLS bloqueando
  - Template no encontrado
  - SKU faltante
  - Otro problema
