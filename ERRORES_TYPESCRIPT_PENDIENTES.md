# Errores TypeScript Pendientes - Resumen para Revisión

## 📊 Estadísticas
- **Total de errores iniciales**: ~50
- **Errores corregidos**: ~20
- **Errores pendientes**: 51 (algunos archivos tienen múltiples errores)

---

## 🔴 Errores por Archivo

### 1. `src/pages/catalog/CatalogItemNew.tsx` (3 errores)

#### Error 1: Línea 846
```typescript
setPrimaryProductTypeId(remaining[0]); // remaining[0] puede ser undefined
```
**Problema**: `remaining[0]` es `string | undefined`, pero `setPrimaryProductTypeId` espera `string | null`
**Solución sugerida**: 
```typescript
setPrimaryProductTypeId(remaining[0] ?? null);
```

#### Error 2: Línea 933
```typescript
setValue('measure_basis', normalized as MeasureBasis, ...);
```
**Problema**: `MeasureBasis` incluye `"fabric"`, pero el tipo esperado solo acepta `"area" | "unit" | "linear_m"`
**Solución sugerida**: Filtrar o mapear `"fabric"` a un valor válido, o actualizar el tipo

#### Error 3: Línea 984
```typescript
setValue('measure_basis', nextBasis as MeasureBasis, ...);
```
**Mismo problema que Error 2**

---

### 2. `src/pages/directory/Customers.tsx` (8 errores)

#### Errores 1-4: Líneas 143, 145, 150, 153
**Problema**: Los objetos mapeados tienen `dateAdded: string | undefined`, pero `CustomerItem` requiere `dateAdded: string`
**Solución sugerida**: Asegurar que `dateAdded` siempre tenga un valor:
```typescript
dateAdded: item.dateAdded || item.created_at || new Date().toISOString()
```

#### Error 5: Línea 148
```typescript
.catch(err => { ... })
```
**Problema**: `PromiseLike<void>` no tiene método `catch`
**Solución sugerida**: Verificar el tipo de retorno de la promesa o usar `.then().catch()`

#### Errores 6-7: Líneas 257, 258, 925, 926
**Problema**: `CustomerItem` no tiene propiedades `country` ni `city`
**Solución sugerida**: Agregar estas propiedades a la interfaz `CustomerItem` o usar un tipo extendido

---

### 3. `src/pages/manufacturing/ManufacturingOrders.tsx` (2 errores)

#### Errores: Líneas 147-148
**Problema**: Intento de acceder a `a[sortBy]` donde `sortBy` puede ser `'manufacturing_order_no'`, pero la propiedad correcta es `manufacturingOrderNo`
**Solución sugerida**: Ya corregido parcialmente, pero falta manejar `'manufacturing_order_no'` en el mapeo

---

### 4. `src/pages/sales/curtain-config/_debug/ConfigDebugPanel.tsx` (1 error)

#### Error: Línea 7
```typescript
import { ... } from '../../../hooks/useBOMTemplateQuestions';
```
**Problema**: El módulo no existe
**Solución sugerida**: 
- Crear el hook faltante, o
- Eliminar el import si no se usa, o
- Cambiar la ruta si el archivo está en otro lugar

---

### 5. `src/pages/sales/curtain-config/ProductStep.tsx` (2 errores)

#### Error 1: Línea 240
**Problema**: `product_type_id` no existe en `ProductConfig | CurtainConfiguration`
**Solución sugerida**: Usar `productType` o `productTypeId` en su lugar

#### Error 2: Línea 326
**Problema**: Objeto posiblemente `undefined`
**Solución sugerida**: Agregar verificación de null/undefined

---

### 6. `src/pages/sales/CurtainConfigurator.tsx` (1 error)

#### Error: Línea 219
**Problema**: `CurtainConfiguration` no es asignable a `ProductConfig`
**Solución sugerida**: Crear un adaptador o extender los tipos para que sean compatibles

---

### 7. `src/pages/sales/ProductConfigurator.tsx` (4 errores)

#### Errores: Líneas 106, 174, 297, 514
**Problemas**: 
- Objetos posiblemente `undefined`
- Incompatibilidades de tipos entre diferentes configuraciones de productos
**Solución sugerida**: Agregar verificaciones de null/undefined y unificar los tipos de configuración

---

### 8. `src/pages/sales/QuoteNew.tsx` (4 errores)

#### Error 1: Líneas 234-235
**Problema**: Intento de acceder a propiedades de un array en lugar de un objeto
**Solución sugerida**: Verificar si es un array y acceder al primer elemento, o corregir el tipo

#### Error 2: Línea 541
**Problema**: `"linear_m"` no es asignable a `"linear" | "area"`
**Solución sugerida**: Mapear `"linear_m"` a `"linear"` o actualizar el tipo

#### Errores 3-4: Líneas 1209-1210
**Problema**: `ProductConfig` no tiene `collectionName` ni `variantName`
**Solución sugerida**: Agregar estas propiedades opcionales a `ProductConfig` o usar un tipo extendido

---

### 9. `src/pages/settings/CompaniesSettings.tsx` (6 errores)

#### Errores 1-4: Línea 50
**Problema**: `colors` posiblemente `undefined`
**Solución sugerida**: Agregar verificación: `colors?.primary` o `colors?.primary ?? 'default'`

#### Error 5: Línea 107
**Problema**: Comparación entre tipos incompatibles (`"active" | "disabled"` vs `"archived"`)
**Solución sugerida**: Revisar la lógica de comparación o actualizar los tipos

#### Error 6: Líneas 535
**Problema**: Propiedad `loading` no existe, debería ser `isLoading`
**Solución sugerida**: Cambiar `loading` por `isLoading`

---

### 10. `src/pages/settings/CompanyPortalUsers.tsx` (8 errores)

#### Errores 1-4: Líneas 47-48, 1192
**Problema**: `colors` posiblemente `undefined` (mismo que CompaniesSettings)

#### Errores 5-8: Líneas 434, 436, 586, 625, 626, 1292
**Problema**: Propiedades faltantes en `CompanyPortalUser`:
- `role` (debería ser `portal_user_role`?)
- `status` (debería ser `portal_user_status`?)
**Solución sugerida**: Revisar la interfaz `CompanyPortalUser` y mapear correctamente las propiedades de la base de datos

---

### 11. `src/pages/settings/CustomerPortalUsers.tsx` (3 errores)

#### Errores 1-2: Línea 47
**Problema**: `colors` posiblemente `undefined`

#### Error 3: Línea 1244
**Problema**: Incompatibilidad de tipos entre `PortalUser` y `CompanyPortalUser`
**Solución sugerida**: Usar el tipo correcto o crear un tipo unificado

---

## 🎯 Prioridades Sugeridas

### Alta Prioridad (Bloquean el build)
1. ✅ **useBOMTemplateQuestions** - Módulo faltante (fácil de crear/eliminar)
2. ✅ **Customers.tsx dateAdded** - Error común, fácil de corregir
3. ✅ **ManufacturingOrders.tsx** - Ya parcialmente corregido

### Media Prioridad (Requieren revisión de tipos)
4. **ProductConfig types** - Necesita unificación de tipos
5. **MeasureBasis "fabric"** - Decidir si mantener o eliminar
6. **CustomerItem properties** - Agregar `country` y `city`

### Baja Prioridad (Verificaciones de null)
7. **colors possibly undefined** - Agregar verificaciones simples
8. **Object possibly undefined** - Agregar checks de null/undefined

---

## 📝 Notas Importantes

1. **Variables de entorno**: Ya están configuradas en Vercel ✅
2. **Errores corregidos**: Los errores más críticos de tipos básicos ya están resueltos
3. **Patrones comunes**: Muchos errores siguen el mismo patrón (undefined checks, tipos incompatibles)

---

## 🔧 Comandos Útiles

```bash
# Ver todos los errores
npm run build 2>&1 | grep "error TS"

# Ver errores de un archivo específico
npm run build 2>&1 | grep "CatalogItemNew.tsx"

# Contar errores restantes
npm run build 2>&1 | grep "error TS" | wc -l
```
