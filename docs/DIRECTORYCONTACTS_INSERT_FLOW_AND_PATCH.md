# DirectoryContacts INSERT — Lugares, flujo y patch

## 1. Lugares donde se hace INSERT a DirectoryContacts

En todo el repo hay **un único sitio** que ejecuta `.from('DirectoryContacts').insert(...)`:

| Archivo | Función / contexto | Uso |
|---------|--------------------|-----|
| **src/hooks/useDirectoryContacts.ts** | `createContact` (callback del hook) | Único INSERT a DirectoryContacts. Construye el payload con `organization_id`, `dealer_id` y el resto de columnas explícitas y llama a `supabase.from('DirectoryContacts').insert(payload)`. |

El resto de apariciones de `DirectoryContacts` en el repo son:
- **SELECT**: `useDirectoryContacts` (listado, getById), `Contacts.tsx` (archived), `useQuotes.ts`, `useProposals.ts`, `QuoteNew.tsx`, `Customers.tsx`, `DealerProfileForm.tsx`, `CustomerNew.tsx`, `useDirectory.ts`, `SaleOrderNew.tsx`.
- **UPDATE**: `useDirectoryContacts` (updateContact, softDeleteContact), `Contacts.tsx` (archived = true).

No hay otro servicio, hook ni página que haga INSERT en `DirectoryContacts`.

---

## 2. Flujo usado por ContactNew (/directory/contacts/new)

1. **ContactNew.tsx**  
   - Usa `const { createContact, updateContact, getContactById } = useDirectoryContacts();` (línea 60).  
   - No usa ningún otro hook ni `supabase` directo para crear contactos.

2. **Al guardar (create)**  
   - `handleSave` obtiene los datos del formulario con `form.getValues()`.  
   - Construye `contactInput` solo con campos del formulario (sin `organization_id` ni `dealer_id`).  
   - Llama a `await createContact(contactInput)` (línea 231).

3. **useDirectoryContacts.createContact**  
   - Recibe `contactInput` (sin org/dealer).  
   - Obtiene usuario y, si existe, fila en DealerUsers (`id`, `dealer_id`, `organization_id`).  
   - Calcula `effectiveOrgId = activeOrganizationId ?? portalUserOrganizationId` y lanza si es null.  
   - Calcula `effectiveDealerId` (portal o acting-as).  
   - Construye `payload` con **organization_id** y **dealer_id** (y el resto de columnas).  
   - Fuerza de nuevo `payload.organization_id` y `payload.dealer_id` justo antes del insert.  
   - Hace `console.log('[DirectoryContacts][REAL_INSERT_PAYLOAD]', JSON.stringify(payload))`.  
   - Llama a `supabase.from('DirectoryContacts').insert(payload)`.  
   - Si hay error, hace `console.error('[DirectoryContacts][INSERT_ERROR]', { message, code, details, hint, full })`.

**Conclusión:** La pantalla ContactNew usa **solo** el hook `useDirectoryContacts` y el único INSERT a DirectoryContacts es el de `createContact` en ese hook.

---

## 3. Sanitizers / mappers que pudieran quitar organization_id

- Búsqueda en el repo: **no** hay funciones tipo `cleanUndefined`, `stripNulls`, `pickAllowedColumns`, `toDbRow`, `mapFormToInsert` ni uso de `omit()` sobre el payload de contactos.
- En **ContactNew** el esquema Zod (`contactSchema`) solo valida campos del formulario; **no** incluye `organization_id` ni `dealer_id` y no se aplica al objeto que se envía al backend. El objeto que llega a `createContact` es `contactInput` (solo campos de formulario); quien añade `organization_id` y `dealer_id` es el hook al construir `payload`.
- No hay capa intermedia que rearme el payload entre el hook y `supabase.from('DirectoryContacts').insert(payload)`: el mismo objeto `payload` se pasa al `.insert()`.

---

## 4. Patch aplicado en useDirectoryContacts

1. **Payload tipado y orden**  
   - `payload` se construye como `Record<string, unknown>` con **organization_id** y **dealer_id** como primeras claves (junto a created_by_*).

2. **Garantía justo antes del insert**  
   - Se asigna de nuevo `payload.organization_id = effectiveOrgId` y `payload.dealer_id = effectiveDealerId` para que no queden undefined ni se pierdan por mutaciones.

3. **Log del body real**  
   - `console.log('[DirectoryContacts][REAL_INSERT_PAYLOAD]', JSON.stringify(payload))`  
   - Ese string es el JSON que el cliente envía en el body del POST (salvo lo que añada el cliente de Supabase por su cuenta). Si aquí aparece `"organization_id":"<uuid>"`, el frontend está enviando bien; si no, el fallo está en la construcción del payload.

4. **Log del error de insert**  
   - `console.error('[DirectoryContacts][INSERT_ERROR]', { message, code, details, hint, full: insertError })`  
   - Permite ver en consola el mensaje, código, detalles y hint que devuelve el backend (p. ej. RLS).

5. **Sin sanitizer que quite columnas**  
   - El objeto que se pasa a `.insert()` es exactamente `payload`; no se pasa por ningún filtro ni omit.

---

## 5. Cómo comprobar en el navegador

1. Abrir **Consola** y **Network** (pestaña que muestra el request al guardar).
2. Crear un contacto en `/directory/contacts/new` y guardar.
3. En consola:
   - Buscar **`[DirectoryContacts][REAL_INSERT_PAYLOAD]`**: debe mostrarse un JSON con `"organization_id":"<uuid>"` y, si aplica, `"dealer_id":"<uuid>"`.
   - Si aparece error, buscar **`[DirectoryContacts][INSERT_ERROR]`**: ahí estarán `message`, `code`, `details`, `hint`.
4. En Network, localizar el request a `rest/v1/DirectoryContacts` (método POST) y abrir el **Request payload** o **Request body**.
5. Comparar: el JSON del body del request debe coincidir (o ser muy parecido) al string logueado en `[DirectoryContacts][REAL_INSERT_PAYLOAD]`. Si en el log sí está `organization_id` y en el body no, entonces algo entre el código y el cliente HTTP (p. ej. una versión antigua del bundle o un proxy) está alterando el body.

---

## 6. Resumen

- **Único INSERT a DirectoryContacts:** `src/hooks/useDirectoryContacts.ts`, función `createContact`.
- **Único uso desde ContactNew:** `createContact(contactInput)`; no hay otro camino de creación.
- **Sin sanitizers que quiten organization_id:** el payload se arma en el hook y se pasa directo a `.insert()`.
- **Patch:** payload con `organization_id`/`dealer_id` forzados antes del insert, log `[DirectoryContacts][REAL_INSERT_PAYLOAD]` con `JSON.stringify(payload)` y log `[DirectoryContacts][INSERT_ERROR]` con el error completo para contrastar con el Request body en Network y con el error RLS.
