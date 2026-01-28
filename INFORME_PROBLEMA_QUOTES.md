# 🔴 INFORME DETALLADO: Problema Crítico - Módulo de Quotes

## 📋 Resumen Ejecutivo
El módulo de Quotes **NO muestra ningún dato** en la lista, incluso cuando existen registros en la base de datos con `deleted = false`. El problema persiste después de múltiples intentos de corrección y requiere análisis profundo del flujo de datos.

---

## 🐛 Problema Actual

### Síntomas:
1. **Después de eliminar un quote**: La página se queda en blanco o muestra "No quotes found"
2. **Requiere refresh manual**: El usuario debe refrescar la página para ver los quotes actualizados
3. **Datos existen en DB**: La tabla `Quotes` tiene registros con `deleted = false` pero no se muestran

### Errores en Consola (Críticos):
1. **`Error getting user profile "[circular]"`** (múltiples instancias)
   - Ubicación: `quotes:53`
   - Impacto: Puede bloquear la inicialización del componente

2. **`Error fetching SaleOrders with JOINS: "[circular]"`** (múltiples instancias)
   - Ubicación: `quotes:53`
   - Impacto: Errores en queries relacionadas

3. **`Multiple GoTrueClient instances detected`**
   - Impacto: Comportamiento indefinido en autenticación

4. **`No RCA-84 items found in loaded data`**
   - Impacto: Problemas con carga de datos relacionados

5. **`[useDirectoryContacts] Generic columns not found`** (warnings)
   - Impacto: Queries fallando, retrying con columnas explícitas

---

## 🔍 Análisis Técnico Detallado

### Flujo de Carga Actual (src/pages/sales/Quotes.tsx):

```
1. Componente monta → useEffect se dispara
2. fetchQuotes() ejecuta:
   a. Verifica activeOrganizationId
   b. Construye query: .eq('organization_id') + .eq('deleted', false)
   c. Si activeCompanyId existe: .eq('company_id')
   d. Ejecuta query con .order('created_at')
   e. Si hay datos:
      - Obtiene customerIds
      - Carga DirectoryCustomers (batch)
      - Carga QuoteLines (batches de 200)
      - Enriquece quotes con datos relacionados
      - setQuotes(enrichedQuotes)
   f. setLoading(false)
```

### Puntos de Falla Potenciales:

1. **activeOrganizationId es NULL/undefined**
   - Resultado: `setQuotes([])` y `setLoading(false)`
   - Estado: Lista vacía, no loading

2. **activeCompanyId filtra incorrectamente**
   - Si existe pero los quotes no tienen `company_id` → 0 resultados
   - Si es NULL pero se aplica filtro → 0 resultados

3. **RLS Policy bloquea la lectura**
   - Policy requiere: `deleted = false` Y membership en organización
   - Si el usuario no tiene membership activo → 0 resultados

4. **Query retorna 0 resultados**
   - Si `quotesData.length === 0` → `setQuotes([])` y return
   - No hay error, solo array vacío

5. **Errores en enriquecimiento**
   - Si DirectoryCustomers falla → quotes sin customer_name
   - Si QuoteLines falla → quotes sin totales
   - Pero aún deberían mostrarse

### Schema de Base de Datos (Revisado):
```sql
CREATE TABLE public."Quotes" (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL,
    company_id uuid,  -- Opcional
    quote_no text NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    customer_id uuid,
    contact_id uuid,
    created_by_user_id uuid,
    deleted boolean NOT NULL DEFAULT false,  -- ✅ Campo existe
    created_at timestamptz,
    updated_at timestamptz
);
```

### RLS Policies:
- ✅ Policy existe: "Users can read own organization quotes"
- ✅ Filtra por: `deleted = false` y membership en organización

### Código Actual:
- **Archivo**: `src/pages/sales/Quotes.tsx`
- **Estado**: Carga directa en componente (no usa hook `useQuotes`)
- **Query**: `.eq('deleted', false)` - Correcto según schema

---

## 🔧 Cambios Realizados (Sin Resolver)

1. ✅ Rehecho módulo con carga directa en componente
2. ✅ Agregado logging detallado para debugging
3. ✅ Simplificado refetch mechanism
4. ✅ Corregido filtro de `deleted` (usando `.eq('deleted', false)`)
5. ✅ Agregado manejo de `company_id` opcional

---

## 🎯 Diagnóstico Paso a Paso

### Paso 1: Verificar Logs en Consola
**Acción**: Abrir consola del navegador (F12) y buscar estos logs en orden:

```
✅ Debe aparecer:
[Quotes] fetchQuotes started { activeOrganizationId: "...", activeCompanyId: "...", refreshTrigger: 0 }
[Quotes] Building query with: { activeOrganizationId: "...", activeCompanyId: "..." }
[Quotes] Query built, executing...
[Quotes] Query result: { hasError: false, dataLength: X, error: null }
[Quotes] Enriched quotes: X
[Quotes] fetchQuotes completed, loading = false
```

**Si NO aparecen estos logs**:
- El `useEffect` no se está ejecutando
- `activeOrganizationId` es NULL
- El componente no se está montando correctamente

**Si aparece `dataLength: 0`**:
- La query no retorna datos (problema de RLS o filtros)
- Verificar Paso 2

### Paso 2: Verificar RLS y Filtros en Supabase
**Acción**: Ejecutar esta query directamente en Supabase SQL Editor:

```sql
-- Reemplazar con el organization_id real del usuario
SELECT 
  id, 
  quote_no, 
  status, 
  organization_id, 
  company_id,
  deleted,
  created_at
FROM public."Quotes" 
WHERE organization_id = '3acbb64c-c71f-4cb2-9fe3-d3ac513babe2'  -- Reemplazar
  AND deleted = false
ORDER BY created_at DESC;
```

**Resultados esperados**:
- Si retorna 0 filas → Problema de RLS o datos realmente eliminados
- Si retorna filas → Problema en el frontend (ver Paso 3)

### Paso 3: Verificar Filtro de Company ID
**Acción**: Revisar en consola el valor de `activeCompanyId`:

```javascript
// En consola del navegador
console.log('activeCompanyId:', window.__ACTIVE_COMPANY_ID__); // Si está expuesto
```

**Problema potencial**:
- Si `activeCompanyId` tiene valor pero los quotes tienen `company_id = NULL` → 0 resultados
- Si `activeCompanyId` tiene valor incorrecto → 0 resultados

**Solución temporal**: Comentar temporalmente el filtro:
```typescript
// if (activeCompanyId) {
//   query = query.eq('company_id', activeCompanyId);
// }
```

### Paso 4: Verificar Errores de Referencias Circulares
**Problema**: Los errores `[circular]` pueden estar bloqueando el renderizado

**Acción**: Revisar estos hooks:
- `useOrganizationContext()` - puede tener referencias circulares
- `useActiveCompany()` - puede tener referencias circulares

**Solución**: Agregar validación para evitar objetos circulares en logs

---

## 📊 Logs de Debugging (Agregados)

El código ahora incluye logs detallados en cada paso:
- `[Quotes] fetchQuotes started`
- `[Quotes] Building query with: {...}`
- `[Quotes] Query result: {...}`
- `[Quotes] Enriched quotes: X`
- `[Quotes] fetchQuotes completed`

**Acción requerida**: Revisar estos logs en la consola del navegador para identificar dónde se bloquea.

---

## 🚀 Plan de Acción Inmediato

### Prioridad 1: Verificar Datos en DB
```sql
-- Query de diagnóstico completa
SELECT 
  COUNT(*) as total_quotes,
  COUNT(*) FILTER (WHERE deleted = false) as active_quotes,
  COUNT(*) FILTER (WHERE deleted = true) as deleted_quotes,
  COUNT(*) FILTER (WHERE company_id IS NULL) as quotes_sin_company,
  COUNT(*) FILTER (WHERE company_id IS NOT NULL) as quotes_con_company
FROM public."Quotes"
WHERE organization_id = '3acbb64c-c71f-4cb2-9fe3-d3ac513babe2';
```

### Prioridad 2: Verificar RLS Policy
```sql
-- Verificar si el usuario actual puede leer quotes
SELECT 
  ou.user_id,
  ou.organization_id,
  ou.status,
  ou.deleted
FROM public."OrganizationUsers" ou
WHERE ou.organization_id = '3acbb64c-c71f-4cb2-9fe3-d3ac513babe2'
  AND ou.user_id = auth.uid()
  AND ou.deleted = false
  AND ou.status = 'active';
```

### Prioridad 3: Test de Query Directa
```sql
-- Simular exactamente lo que hace el frontend
SELECT q.*
FROM public."Quotes" q
WHERE q.organization_id = '3acbb64c-c71f-4cb2-9fe3-d3ac513babe2'
  AND q.deleted = false
  -- AND q.company_id = '2ccdd701-15b0-4d5e-9c7f-3509d...'  -- Descomentar si aplica
ORDER BY q.created_at DESC;
```

### Prioridad 4: Revisar Código Frontend
1. Abrir consola del navegador
2. Buscar logs `[Quotes]`
3. Verificar qué valor tiene `dataLength` en `Query result`
4. Si es 0 → Problema de query/RLS
5. Si es > 0 pero no se muestra → Problema de renderizado

## 🔧 Soluciones Propuestas

### Solución 1: Deshabilitar Filtro de Company ID Temporalmente
```typescript
// En src/pages/sales/Quotes.tsx línea ~134
// COMENTAR TEMPORALMENTE:
// if (activeCompanyId) {
//   query = query.eq('company_id', activeCompanyId);
// }
```

### Solución 2: Agregar Fallback para Company ID NULL
```typescript
// Si activeCompanyId existe pero es NULL, no filtrar
if (activeCompanyId && activeCompanyId !== null) {
  query = query.eq('company_id', activeCompanyId);
} else {
  // Mostrar todos los quotes sin company_id o con cualquier company_id
  query = query.or('company_id.is.null,company_id.not.is.null');
}
```

### Solución 3: Mejorar Manejo de Errores
```typescript
// Agregar más logging y manejo de errores específicos
if (quotesError) {
  if (quotesError.code === '42501') {
    // RLS error
    setError('No tienes permisos para ver quotes. Verifica tu membership.');
  } else {
    setError(quotesError.message);
  }
}
```

---

## 📝 Archivos Modificados

- `src/pages/sales/Quotes.tsx` - Rehecho con carga directa
- `src/hooks/useQuotes.ts` - Ajustado filtro de `deleted`

---

## 📊 Checklist de Diagnóstico

- [ ] Verificar logs en consola: `[Quotes] fetchQuotes started`
- [ ] Verificar `activeOrganizationId` no es NULL
- [ ] Verificar `activeCompanyId` (puede ser NULL o tener valor)
- [ ] Ejecutar query SQL directa en Supabase
- [ ] Verificar RLS policy permite lectura
- [ ] Verificar que quotes en DB tienen `deleted = false`
- [ ] Verificar que quotes tienen `organization_id` correcto
- [ ] Verificar que quotes tienen `company_id` si se está filtrando
- [ ] Revisar errores `[circular]` en consola
- [ ] Verificar que `useEffect` se ejecuta al montar componente

## 🔍 Código Actual (Resumen)

**Archivo**: `src/pages/sales/Quotes.tsx`
- **Líneas 97-209**: `useEffect` con `fetchQuotes()`
- **Línea 124-128**: Query base con filtros
- **Línea 134-136**: Filtro opcional por `company_id`
- **Línea 138-139**: Ejecución de query
- **Línea 154-159**: Si no hay datos, retorna array vacío
- **Línea 204-208**: Enriquece quotes con customers y lines
- **Línea 213**: `setQuotes(enrichedQuotes)`

**Dependencias del useEffect**:
```typescript
[activeOrganizationId, activeCompanyId, refreshTrigger]
```

**Problema potencial identificado**:
- Si `activeCompanyId` cambia o es NULL cuando no debería, puede filtrar incorrectamente
- Si el `useEffect` no se ejecuta por dependencias incorrectas, no carga datos

---

**Fecha**: 2026-01-23  
**Prioridad**: 🔴 Crítica  
**Estado**: ⚠️ Requiere Diagnóstico Inmediato  
**Asignado**: Equipo de Desarrollo
