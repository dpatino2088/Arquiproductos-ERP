# Logo del Dealer en Proposal y PDF – Diagnóstico y soluciones

El logo no se muestra en la **vista Proposal** (detalle/impresión) ni en el **PDF**. Este documento resume el flujo actual, causas probables y soluciones.

---

## 0. Causa principal ya corregida (fix aplicado)

**Problema**: El logo se guarda como **URL pública completa** (`https://.../storage/v1/object/public/catalog-images/dealer-logos/...`), que ya debería verse en `<img src="...">` sin más. Pero **`useResolvedStorageUrl`** la convertía en **signed URL** con `createSignedUrl()`. Esa operación suele fallar para roles como `dealer_member` o `portal` por políticas de Storage (no tienen permiso de “create signed url”). Resultado: el `<img>` recibía una URL que fallaba o vacía → placeholder.

**Fix aplicado**:
- **`useResolvedStorageUrl`**: Si la URL ya es de Supabase public storage (`/storage/v1/object/public/...`), se devuelve **tal cual**, sin firmar. Si el valor es solo un path (`dealer-logos/...`), se construye `getPublicUrl(path)` con bucket `catalog-images`. **No se usa `createSignedUrl`** para bucket público.
- **PDF (ProposalDetail)**: Solo se usa `getPublicUrl(cleanPath)` + `fetch(publicUrl)`; se eliminó el fallback a `createSignedUrl`. Si el bucket es público, la URL pública debe responder; si falla, el problema es path incorrecto o archivo inexistente.

---

## 1. Flujo actual (después del fix)

### 1.1 Vista Proposal (ProposalDetail / ProposalPrint)

1. **Origen del dato**: `useProposalDetail(proposalId)` hace `Dealers.select('logo_url').eq('id', proposal.dealer_id)` → `dealerLogoUrl`.
2. **URL usable**: `useResolvedStorageUrl(dealerLogoUrl)`:
   - Si es URL pública de Supabase (`/storage/v1/object/public/...`) → **se devuelve tal cual** (no se firma).
   - Si es solo path (ej. `dealer-logos/...`) → se construye `getPublicUrl(path)` con bucket `catalog-images`.
3. **Render**: `<img src={resolvedLogoUrl}>` o placeholder "Dealer logo" si no hay URL o hay error de carga.

### 1.2 PDF

1. **Origen**: `dealerLogoUrl` del hook; si vacío, fetch extra a `Dealers.select('logo_url').eq('id', proposal.dealer_id)`.
2. **Path**: `getLogoPathFromUrl(logoUrlForPdf)` extrae el path (o null si la URL no contiene `/catalog-images/`).
3. **Carga**: Solo `getPublicUrl(cleanPath)` + `fetch(publicUrl)`; opcionalmente fallback con `new Image()` y la misma public URL. **No se usan signed URLs.** El resultado se convierte a base64 → `generateProposalPDF(..., logoPngBase64)`.

### 1.3 Dónde se guarda el logo (DealerProfileForm)

- **Bucket**: `catalog-images`.
- **Path**: `dealer-logos/{organizationId}/{dealerId}/{timestamp}-{random}.{ext}`.
- **Qué se guarda en BD**: `ImageUpload` llama `onImageUploaded(urlData.publicUrl)`, es decir, la **URL pública completa** (ej.: `https://...supabase.co/storage/v1/object/public/catalog-images/dealer-logos/...`).

---

## 2. Causas probables (por qué no se muestra el logo)

### A. Base de datos

| Causa | Efecto | Cómo comprobar |
|-------|--------|-----------------|
| Columna `logo_url` no existe en `Dealers` | El select falla o no devuelve la columna; `dealerLogoUrl` queda null. | En Supabase: Table Editor → `Dealers` → ver si existe la columna `logo_url`. |
| Migración no aplicada | Igual que arriba. | Ejecutar en SQL Editor: `database/migrations/20260208_dealers_logo_url.sql`. |
| `logo_url` está NULL para ese dealer | No hay URL que mostrar. | `SELECT id, dealer_name, logo_url FROM "Dealers" WHERE id = '<dealer_id_de_la_proposal>';` |
| `logo_url` guardado solo como path (ej. `dealer-logos/...`) | En la UI, `useResolvedStorageUrl` no reconoce el formato y devuelve el path tal cual; el `<img src="dealer-logos/...">` es una URL relativa y falla. En PDF, `getLogoPathFromUrl` sí devuelve el path (por la rama “no empieza por http”), pero si hay otro fallo después (RLS, bucket), el PDF tampoco lo muestra. | Revisar en BD el valor de `logo_url`: si no empieza por `http`, está guardado como path. |

### B. Permisos y RLS

| Causa | Efecto | Cómo comprobar |
|-------|--------|-----------------|
| RLS en `Dealers` no permite leer esa fila (o la columna) | El `select('logo_url')` no devuelve datos o falla; `dealerLogoUrl` null. **Muy común si el usuario es Dealer Manager o Dealer Member**: la política antigua usaba `is_org_member`, que puede excluirlos. | Aplicar `database/migrations/20260210_dealers_rls_allow_dealer_manager_member.sql` (cambia SELECT a `is_org_user_member`). Probar el mismo select con el usuario/rol que usa la app. |
| Storage: bucket no público o RLS bloquea lectura | La URL pública devuelve 403/401; la imagen no carga en UI ni en el fetch del PDF. | En el navegador: abrir la URL que está en `logo_url` en una pestaña; ver si carga o 403. Probar también con una signed URL generada desde la app (o desde Supabase Dashboard). |

### C. Formato de URL y bucket

| Causa | Efecto | Cómo comprobar |
|-------|--------|-----------------|
| Bucket distinto de `catalog-images` (ej. `dealer-logo`) | En `getLogoPathFromUrl` se busca `/catalog-images/` en el pathname. Si la URL es `.../public/dealer-logo/...`, no coincide y la función devuelve **null** → el PDF no tiene path para cargar el logo. La UI puede seguir fallando si la signed URL no se genera para ese bucket. | Ver la URL en `Dealers.logo_url`: el segmento después de `/public/` es el nombre del bucket. |
| URL mal formada o recortada en BD | Path incorrecto o null en `getLogoPathFromUrl`; en UI, `useResolvedStorageUrl` no extrae bucket/path. | Inspeccionar el string exacto en `logo_url`. |

### D. Guardado del logo al editar dealer

| Causa | Efecto | Cómo comprobar |
|-------|--------|-----------------|
| Al guardar el perfil del dealer no se envía `logo_url` | El valor en BD no se actualiza. | Revisar que `updateDealer` en `useDealers.ts` incluya `logo_url` en el payload (ya corregido en código). Ver en Redux/Network que el PATCH a Dealers envíe `logo_url`. |

---

## 3. Comprobaciones rápidas

1. **En Supabase (SQL)**  
   ```sql
   -- ¿Existe la columna?
   SELECT column_name FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'Dealers' AND column_name = 'logo_url';

   -- ¿Qué hay guardado para un dealer concreto?
   SELECT id, dealer_name, logo_url FROM public."Dealers" WHERE id = '<dealer_id>';
   ```

2. **En la app (Proposal abierta)**  
   - DevTools → pestaña Network: filtrar por “Dealers” o “storage”; ver si la petición que trae `logo_url` devuelve datos.  
   - Console: si hay `console.error`/`console.warn` del logo (por ejemplo “Dealer logo failed to load”), anotar la URL que falla.

3. **URL en navegador**  
   - Copiar el valor de `logo_url` de la BD (o la URL que usa el `<img>` en Proposal) y abrirlo en una pestaña. Si da 403, el problema es de permisos de storage.

---

## 4. Soluciones recomendadas

### 4.1 Asegurar columna y migraciones

- Ejecutar en Supabase → SQL Editor el contenido de **`database/migrations/20260208_dealers_logo_url.sql`** (añade `logo_url` a `Dealers` si no existe).
- **Para Dealer Manager / Dealer Member:** ejecutar **`database/migrations/20260210_dealers_rls_allow_dealer_manager_member.sql`** para que la política SELECT de `Dealers` use `is_org_user_member(organization_id)` y esos roles (y portal) puedan leer `logo_url`.

### 4.2 Si `logo_url` está guardado solo como path (sin `https://`)

- **UI**: Antes de pasar a `useResolvedStorageUrl`, si `dealerLogoUrl` no empieza por `http://` ni `https://`, construir la URL pública con el bucket que uses (por ejemplo `catalog-images`) y pasar esa URL a `useResolvedStorageUrl` (o directamente al `src` del `<img>` si el bucket es público y no usas signed URL).
- **PDF**: En este caso `getLogoPathFromUrl` ya devuelve el path; el fallo suele ser entonces de storage (RLS/CORS) o de bucket. Asegurar que el path se use con el bucket correcto (`catalog-images` en el código actual).

### 4.3 Si el bucket es `dealer-logo` (u otro) y no `catalog-images`

- **Opción A**: En **DealerProfileForm** (y en el componente de upload del logo), usar el bucket `catalog-images` y el path `dealer-logos/...` como hasta ahora, para que la URL guardada en BD contenga `catalog-images` y todo el flujo siga igual.
- **Opción B**: Si quieres seguir usando el bucket `dealer-logo`:
  - En **`getLogoPathFromUrl`** (`src/lib/dealerLogo.ts`), aceptar también el segmento `/dealer-logo/` (o el nombre de tu bucket) y devolver el path que va después.
  - En **ProposalDetail** (bloque del PDF), al obtener la URL para cargar el logo, usar ese mismo bucket en `supabase.storage.from('dealer-logo')` (o el que sea) con el path extraído.
  - En **useResolvedStorageUrl** no hace falta cambiar nada si la URL completa ya tiene el bucket en el path; el regex actual extrae cualquier bucket.

### 4.4 Políticas de Storage para que se vea el logo

- Asegurar una política de **lectura** (SELECT/read) sobre el bucket donde están los logos (`catalog-images` o `dealer-logo`) para los roles que usa la app (por ejemplo `authenticated` o `anon` si el bucket es público).
- Ejemplo de política “permiso de lectura para paths de logos” (ajustar bucket y condiciones a tu RLS):
  - En Storage → tu bucket → Policies: permitir `read` para objetos cuyo path empiece por `dealer-logos/` (o el path que uses).

### 4.5 Logo en PDF: comprobar fallo de fetch

- En **ProposalDetail**, el código que construye el PDF solo se usa la URL pública (sin signed URL). Revisar en consola (en DEV) si aparecen los `console.warn` “Proposal PDF: logo fetch failed” o “Proposal PDF: logo failed to load”: ahí se ve la URL y el status. Si falla, el problema es path incorrecto, archivo inexistente o bucket no público/CORS, no permisos de firma.

### 4.6 Resumen de archivos implicados

| Área | Archivo | Qué revisar |
|------|---------|-------------|
| **Hook URL** | `src/hooks/useResolvedStorageUrl.ts` | No debe llamar `createSignedUrl`. URLs públicas se devuelven tal cual; paths se convierten con `getPublicUrl` (bucket `catalog-images`). |
| BD | `database/migrations/20260208_dealers_logo_url.sql` | Que esté aplicada. |
| Logo path/URL | `src/lib/dealerLogo.ts` | Que acepte la URL (o path) que guardas; bucket en la URL = `catalog-images` para `getLogoPathFromUrl`. |
| UI Proposal | `src/pages/sales/ProposalDetail.tsx`, `ProposalPrint.tsx` | Usan `dealerLogoUrl` y `useResolvedStorageUrl`; PDF solo usa public URL (no signed). |
| Hook datos | `src/hooks/useProposals.ts` | `useProposalDetail` hace `Dealers.select('logo_url').eq('id', proposal.dealer_id)`. |
| Guardado dealer | `src/hooks/useDealers.ts` | `updateDealer`/`createDealer` incluyen `logo_url` en el payload. |
| Upload logo | `src/pages/settings/DealerProfileForm.tsx`, `ImageUpload.tsx` | Bucket `catalog-images`, path `dealer-logos/...`. |

---

## 5. Checklist rápido

- [ ] Migración `20260208_dealers_logo_url.sql` aplicada en Supabase.
- [ ] Si usas Dealer Manager o Dealer Member: migración `20260210_dealers_rls_allow_dealer_manager_member.sql` aplicada (permite SELECT en Dealers para esos roles).
- [ ] Para el dealer de la proposal, `SELECT logo_url FROM "Dealers" WHERE id = ?` devuelve una URL (o path) no vacía.
- [ ] Esa URL (o la pública construida desde el path) abre en el navegador y muestra la imagen (no 403).
- [ ] Al guardar el perfil del dealer con un logo nuevo, la petición PATCH incluye `logo_url` y en BD se actualiza.
- [ ] En la UI de Proposal, el `<img>` del logo tiene un `src` que es una URL absoluta (http/https), no un path relativo.
- [ ] Si el bucket no es `catalog-images`, `getLogoPathFromUrl` y el código del PDF usan el bucket correcto para ese path.

Si tras estas comprobaciones el logo sigue sin verse, el siguiente paso es anotar: valor exacto de `logo_url` en BD, URL que recibe el `<img>` en Proposal, y mensaje/status de cualquier error en consola o en el fetch del PDF, para afinar la causa (path, bucket o RLS).
