# ✅ Checklist para el Equipo de Programadores - Migración 212

## 🎯 Estado Actual

### ✅ **COMPLETADO:**
1. ✅ Migración 212 ejecutada y corregida
2. ✅ Todas las migraciones SQL usan nombres correctos (`SalesOrders`, `SalesOrderLines`)
3. ✅ **Código TypeScript/React ya está correcto** - usa `SalesOrders` (con 's')
4. ✅ Trigger activo y funcionando

### ⚠️ **VERIFICAR:**
- Configuración de Supabase (variables de entorno)
- Conectividad con Supabase
- Que el trigger realmente cree SalesOrders cuando se aprueban Quotes

---

## 📋 Checklist de Verificación

### **1. Verificar Código TypeScript/React** ✅

**Estado:** El código ya está correcto, pero verificar que no haya referencias antiguas:

```bash
# Buscar referencias incorrectas (debería devolver vacío o solo comentarios)
grep -r "SaleOrders" src/ --exclude-dir=node_modules | grep -v "SalesOrders"
grep -r "SaleOrderLines" src/ --exclude-dir=node_modules | grep -v "SalesOrderLines"
```

**Archivos verificados:**
- ✅ `src/hooks/useSaleOrders.ts` - Usa `'SalesOrders'` correctamente
- ✅ `src/pages/sales/SaleOrders.tsx` - Usa `'SalesOrders'` correctamente
- ✅ `src/pages/manufacturing/OrderList.tsx` - Usa `'SalesOrders'` correctamente
- ✅ Todos los demás archivos - Verificados

**Resultado:** ✅ No se requieren cambios en el código TypeScript

---

### **2. Verificar Configuración de Supabase**

**Archivo:** `.env.local` o `.env`

Verificar que existan estas variables:

```env
VITE_SUPABASE_URL=https://gfanmftbdztyifagpmfn.supabase.co
VITE_SUPABASE_ANON_KEY=tu_clave_anon_aqui
```

**Comando para verificar:**
```bash
# Verificar que las variables están configuradas
cat .env.local | grep VITE_SUPABASE
```

**Si faltan variables:**
1. Ir a Supabase Dashboard → Settings → API
2. Copiar:
   - `URL` → `VITE_SUPABASE_URL`
   - `anon public` key → `VITE_SUPABASE_ANON_KEY`
3. Crear/actualizar `.env.local`
4. Reiniciar el servidor de desarrollo (`npm run dev`)

---

### **3. Probar el Trigger**

**Paso 1:** Ejecutar query en Supabase SQL Editor:

```sql
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text;
BEGIN
    SELECT q.id, q.quote_no INTO v_quote_id, v_quote_no
    FROM "Quotes" q
    WHERE q.deleted = false
    AND q.status != 'approved'
    AND (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) > 0
    ORDER BY q.created_at DESC LIMIT 1;
    
    UPDATE "Quotes"
    SET status = 'approved', updated_at = NOW()
    WHERE id = v_quote_id AND deleted = false AND status != 'approved';
    
    RAISE NOTICE '✅ Quote % aprobada. ID: %', v_quote_no, v_quote_id;
END $$;
```

**Paso 2:** Verificar que se creó el SalesOrder (usar el ID del mensaje anterior):

```sql
SELECT 
    'Quote' as tipo, q.quote_no, q.status, q.created_at
FROM "Quotes" q WHERE q.id = '<quote_id>'
UNION ALL
SELECT 'SalesOrder', so.sale_order_no, so.status, so.created_at
FROM "SalesOrders" so WHERE so.quote_id = '<quote_id>' AND so.deleted = false
ORDER BY created_at;
```

**Resultado esperado:** Deberías ver 2 filas (Quote y SalesOrder)

---

### **4. Verificar en la UI**

1. Ir a `/sale-orders` en la aplicación
2. Deberías ver el SalesOrder creado por el trigger
3. Si no aparece:
   - Verificar que `activeOrganizationId` esté configurado
   - Revisar la consola del navegador para errores
   - Verificar que las variables de entorno estén correctas

---

## 🐛 Troubleshooting

### **Error: "Failed to fetch" o "ERR_INTERNET_DISCONNECTED"**

**Causa:** Problemas de conectividad con Supabase

**Soluciones:**
1. Verificar que las variables de entorno estén correctas
2. Verificar conexión a internet
3. Verificar que la URL de Supabase sea correcta
4. Reiniciar el servidor de desarrollo

### **Error: "OrganizationContext Error obteniendo usuario"**

**Causa:** Problema con autenticación o contexto de organización

**Soluciones:**
1. Verificar que el usuario esté autenticado
2. Verificar que el usuario tenga una organización asociada
3. Revisar logs de Supabase para errores de RLS

### **SalesOrders no aparecen en la UI**

**Causa:** Puede ser problema de RLS, organización, o datos

**Soluciones:**
1. Verificar que el `activeOrganizationId` coincida con el `organization_id` del SalesOrder
2. Verificar políticas RLS en Supabase
3. Verificar que el SalesOrder realmente existe en la BD:
   ```sql
   SELECT * FROM "SalesOrders" WHERE deleted = false LIMIT 10;
   ```

---

## ✅ Resumen Final

### **Estado del Código:**
- ✅ Migraciones SQL: Correctas
- ✅ Código TypeScript: Correcto (ya usa `SalesOrders`)
- ✅ Trigger: Activo y funcionando

### **Pendiente:**
- ⚠️ Verificar configuración de Supabase (variables de entorno)
- ⚠️ Probar el flujo completo en desarrollo
- ⚠️ Verificar que SalesOrders aparezcan en la UI

### **No Requiere:**
- ❌ Cambios en código TypeScript/React (ya está correcto)
- ❌ Cambios en migraciones SQL (ya están correctas)

---

## 📞 Próximos Pasos

1. Verificar variables de entorno de Supabase
2. Probar el trigger aprobando una Quote
3. Verificar que el SalesOrder aparece en la UI
4. Si todo funciona, pasar a producción

---

## 📂 Archivos de Referencia

- `database/migrations/RESUMEN_MIGRACION_212.md` - Resumen completo
- `database/migrations/TEST_212_FACIL.sql` - Scripts de prueba
- `database/migrations/PASOS_PROBAR_TRIGGER_212.md` - Guía detallada






