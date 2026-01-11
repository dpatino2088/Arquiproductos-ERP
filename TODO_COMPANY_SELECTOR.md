# TODO: Company Selector en UI

## Contexto

El sistema ahora requiere que todas las entidades operacionales tengan:
- `organization_id` (dueño del sistema)
- `company_id` (contexto de negocio / quién vende)

## Problema Actual

Los hooks están actualizados para filtrar por `company_id`, pero **NO hay un selector de company en la UI**.

Actualmente:
- `useActiveCompany` auto-selecciona el primer company disponible
- No hay forma para el usuario de cambiar de company
- No hay persistencia del company seleccionado (similar a `activeOrganizationId`)

## Solución Requerida

### 1. Agregar Company Selector en Layout/Header

Similar al selector de Organization, agregar un selector de Company que:
- Muestre el company activo
- Permita cambiar entre companies disponibles
- Persista la selección en localStorage

### 2. Crear CompanyContext (opcional)

Si se quiere un contexto global similar a `OrganizationContext`:
- `CompanyContext` que exponga `activeCompanyId`, `activeCompany`, `setActiveCompanyId`
- Integrar con `useCompanies` para cargar companies disponibles
- Persistir en localStorage con key `activeCompanyId`

### 3. Actualizar Layout.tsx

En `src/components/Layout.tsx`:
- Agregar selector de company en el header (junto al selector de organization)
- Usar `useActiveCompany` o `CompanyContext`
- Mostrar solo si hay más de un company disponible

### 4. Verificar que todos los hooks usen company_id

Hooks actualizados:
- ✅ `useCompanyPortalUsers` - acepta `companyId` opcional
- ✅ `useQuotes` - filtra por `company_id`
- ✅ `useManufacturingOrders` - filtra por `company_id` (a través de SalesOrders -> Quotes)
- ⚠️ `useSalesOrders` - **FALTA CREAR/ACTUALIZAR**
- ⚠️ `useOrderList` - **FALTA CREAR**

## Impacto

Sin el selector de company:
- Los usuarios solo verán datos del primer company disponible
- No podrán cambiar entre companies
- La experiencia de usuario será limitada

## Prioridad

**ALTA** - Necesario para que el sistema funcione correctamente con múltiples companies.
