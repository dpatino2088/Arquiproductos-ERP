# GUÍA: RESET COMPLETO Y LIMPIO DEL SISTEMA BOM

## 🎯 Objetivo
Limpiar toda la configuración actual de BOM y re-poblar desde cero con el sistema correcto PADRE-HIJO.

## ⚠️ IMPORTANTE
**Esta guía borra y recrea todos los BOMTemplateSlots. Los BOMComponents se preservan como referencia.**

---

## 📋 PASOS A EJECUTAR (EN ORDEN)

### 1️⃣ RESET: Borrar slots y children existentes

```sql
-- En Supabase SQL Editor
backups/RESET_BOM_CLEAN.sql
```

**Resultado esperado:**
```
NOTICE: Deleted X BOMTemplateSlots
NOTICE: Deleted Y CatalogItemComponents
```

---

### 2️⃣ POBLACIÓN: Crear slots desde BOMComponents

```sql
-- En Supabase SQL Editor
backups/POPULATE_BOM_FINAL.sql
```

**Resultado esperado:**
```
NOTICE: Template: ROLLER_MANUAL_M (Roller Manual M)
NOTICE:   → drive (SKU: RC3001-W)
NOTICE:   → bracket (SKU: RC3006-W)
NOTICE:   → bottom_bar (SKU: RCA-04-W)
NOTICE:   → tube (SKU: user choice)
...
NOTICE: Total slots creados: XX
```

**Al final del script, debes ver una tabla con:**
- `template_code` | `slots_count` | `slots_detail`
- Cada template debe tener al menos 2-4 slots

---

### 3️⃣ CREAR POLICIES (RLS) para CatalogItemComponents

```sql
-- En Supabase SQL Editor
backups/fix_catalogitemcomponents_rls.sql
```

**Resultado esperado:**
```
CREATE POLICY (3 policies creadas)
```

---

### 4️⃣ VERIFICACIÓN EN UI

1. **Abrir Adaptio ERP** → `/catalog/bom`
2. **Editar cualquier template** (ej: "Roller Motorizada M")
3. **Verificar que aparezcan:**
   - ✅ Roles listados (bottom_bar, tube, etc.)
   - ✅ SKUs poblados donde corresponda
   - ✅ Botón verde 📦 habilitado en filas con SKU
4. **Click 📦 en una fila con SKU:**
   - ✅ Debe abrir modal "Manage Child Components"
   - ✅ Debe permitir "Add Child Component"
   - ✅ Al guardar, debe persistir

---

## 🧪 VERIFICACIÓN EN BASE DE DATOS

### Ver slots por template:

```sql
SELECT 
  bt.code,
  bts.item_role,
  bts.catalog_item_id IS NOT NULL as has_sku,
  ci.sku,
  ci.name
FROM public."BOMTemplateSlots" bts
JOIN public."BOMTemplates" bt ON bt.id = bts.bom_template_id
LEFT JOIN public."CatalogItems" ci ON ci.id = bts.catalog_item_id
WHERE bts.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
ORDER BY bt.code, bts.item_role;
```

**Esperado:**
- `ROLLER_MANUAL_M` → drive, bracket, bottom_bar, tube
- `ROLLER_MOTORIZADA_M` → motor, bracket, bottom_bar, tube
- etc.

### Ver children (hijos) por SKU padre:

```sql
SELECT 
  parent.sku as padre_sku,
  cic.child_role,
  child.sku as hijo_sku,
  cic.qty
FROM public."CatalogItemComponents" cic
JOIN public."CatalogItems" parent ON parent.id = cic.parent_item_id
JOIN public."CatalogItems" child ON child.id = cic.child_item_id
WHERE cic.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND cic.deleted = false
ORDER BY parent.sku, cic.sort_order;
```

---

## 🔧 Si algo falla

### Problema: "Template sin slots después de poblar"

**Causa:** El template no tiene BOMComponents PADRE

**Solución:** Agregar manualmente el slot:

```sql
INSERT INTO public."BOMTemplateSlots" (
  organization_id,
  bom_template_id,
  item_role,
  required,
  catalog_item_id,
  qty,
  notes
) VALUES (
  '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid,
  (SELECT id FROM public."BOMTemplates" WHERE code = 'TU_TEMPLATE_CODE' LIMIT 1),
  'motor', -- o 'drive', 'bracket', etc.
  true,
  NULL, -- o el catalog_item_id del SKU fijo
  1,
  'Manual slot'
);
```

---

### Problema: "Add Child Component falla con RLS error"

**Causa:** Falta policy de INSERT

**Solución:** Re-ejecutar `fix_catalogitemcomponents_rls.sql`

---

### Problema: "SKUs no aparecen en modal"

**Causa:** Frontend cacheado

**Solución:** 
1. Hard refresh: `Cmd+Shift+R` (Mac) o `Ctrl+Shift+R` (Windows)
2. Cerrar y reabrir modal

---

## ✅ CHECKLIST FINAL

- [ ] `RESET_BOM_CLEAN.sql` ejecutado sin errores
- [ ] `POPULATE_BOM_FINAL.sql` ejecutado sin errores
- [ ] `fix_catalogitemcomponents_rls.sql` ejecutado sin errores
- [ ] Al menos 1 template tiene slots visibles en UI
- [ ] Botón 📦 está habilitado en filas con SKU
- [ ] Modal de hijos abre correctamente
- [ ] Puedo agregar un child component sin error

---

## 🆘 Soporte

Si después de seguir esta guía algo no funciona:

1. Copia el mensaje de error completo
2. Copia el resultado de:
   ```sql
   SELECT COUNT(*) as slots_count 
   FROM public."BOMTemplateSlots" 
   WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2';
   ```
3. Comparte ambos y lo revisamos juntos

---

**Última actualización:** 2026-01-19
