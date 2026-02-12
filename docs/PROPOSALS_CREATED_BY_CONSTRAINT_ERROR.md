# Error: Proposals (created_by y dealer_id)

## El problema

Al hacer **"Create Proposal"** desde una Quote pueden aparecer:

1. **`proposals_created_by_exactly_one_chk`** — el constraint de creador.
2. **Fallo por `dealer_id`** — en el dump V11 la tabla `Proposals` tiene `dealer_id uuid NOT NULL`; si no se envía o el Quote no tiene dealer y el usuario interno no tiene "acting as" seleccionado, el insert puede fallar o depender del trigger.

### Causas técnicas

**created_by:** La tabla `Proposals` tiene un CHECK que exige **solo uno** de estos dos rellenado:

- `created_by_user_id` — usuario interno (OrganizationUsers / auth.users)
- `created_by_portal_user_id` — usuario del portal (DealerUsers)

**dealer_id:** En BD (V11) `Proposals.dealer_id` es **NOT NULL**. Debe resolverse en frontend:

- **Quote tiene dealer** → se usa `quote.dealer_id`.
- **Usuario interno "acting as dealer"** → se usa el dealer seleccionado (`actingDealerId`).
- **Usuario portal** → se usa `DealerUsers.dealer_id` del contexto.

Si no se resuelve `dealer_id` (o los dos created_by), el INSERT falla.

Definición del constraint (en `database/migrations/20260207_proposals_mvp.sql`):

```sql
CONSTRAINT proposals_created_by_exactly_one
  CHECK (
    (created_by_user_id IS NOT NULL AND created_by_portal_user_id IS NULL)
    OR (created_by_user_id IS NULL AND created_by_portal_user_id IS NOT NULL)
  )
```

---

## Lo que ya se hizo (en código y migraciones)

### 1. Frontend (`src/hooks/useProposals.ts`)

- **dealer_id (obligatorio):** Se resuelve en este orden: `quote.dealer_id` → `options.actingDealerId` (usuario interno "acting as") → `portalUser.dealer_id`. Si queda null, se devuelve error claro: *"No se puede crear la propuesta sin dealer. Asigna un dealer a la cotización o selecciona 'Actuar como' un dealer..."*.
- **Parámetro `actingDealerId`:** `createProposalFromQuote(quoteId, { actingDealerId })` para que la página pase el dealer seleccionado desde `useActiveDealer().activeDealerId`.
- **Contexto de auth:** Se usa `get_auth_context` para saber si es usuario portal o interno y se asignan `created_by_user_id` o `created_by_portal_user_id` en consecuencia.
- **Try/catch:** Si la RPC `get_auth_context` falla, se trata como usuario interno y se usa `userId` de la sesión.
- **Validación antes del INSERT:** Si tras la lógica anterior ambos created_by quedan en null, se usa fallback desde el Quote (copiar creador del Quote).
- **Payload del insert:** Siempre se envían `dealer_id`, `created_by_user_id` y `created_by_portal_user_id` de forma explícita (uno de los dos created_by no null).

### 2. Migraciones creadas (hay que ejecutarlas en Supabase)

| Archivo | Qué hace |
|--------|----------|
| `database/migrations/20260223_fix_proposals_created_by_constraint.sql` | Corrige **filas ya existentes** en `Proposals` que tienen ambos `created_by` en null, copiando el creador desde el Quote cuando el Quote tiene exactamente uno definido. |
| `database/migrations/20260224_proposals_created_by_trigger.sql` | Crea un **trigger BEFORE INSERT** en `Proposals` que, si llegan ambos en null, asigna `created_by_user_id = auth.uid()` para que el constraint se cumpla aunque el cliente envíe mal los datos. |

### 3. Otro ajuste en frontend

- En `createConfiguredProductPreview.ts`, el `console.error` del RPC ya no imprime el objeto `error` completo (evita el "[circular]" en consola).

---

## Posibles soluciones (qué hacer ahora)

### A. Ejecutar las migraciones en Supabase (recomendado)

1. Abre el **SQL Editor** del proyecto en Supabase.
2. Ejecuta **primero** el trigger (para que los nuevos INSERT no fallen):

   Contenido de `database/migrations/20260224_proposals_created_by_trigger.sql`:

   ```sql
   CREATE OR REPLACE FUNCTION public.proposals_ensure_created_by()
   RETURNS trigger
   LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, auth
   AS $$
   BEGIN
     IF NEW.created_by_user_id IS NULL AND NEW.created_by_portal_user_id IS NULL THEN
       NEW.created_by_user_id := auth.uid();
     END IF;
     RETURN NEW;
   END;
   $$;

   DROP TRIGGER IF EXISTS trg_proposals_ensure_created_by ON public."Proposals";
   CREATE TRIGGER trg_proposals_ensure_created_by
     BEFORE INSERT ON public."Proposals"
     FOR EACH ROW
     EXECUTE FUNCTION public.proposals_ensure_created_by();
   ```

3. Luego ejecuta la corrección de datos existentes:

   Contenido de `database/migrations/20260223_fix_proposals_created_by_constraint.sql`:

   ```sql
   BEGIN;
   UPDATE public."Proposals" p
   SET
     created_by_user_id = q.created_by_user_id,
     created_by_portal_user_id = q.created_by_portal_user_id
   FROM public."Quotes" q
   WHERE p.quote_id = q.id
     AND p.created_by_user_id IS NULL
     AND p.created_by_portal_user_id IS NULL
     AND (
       (q.created_by_user_id IS NOT NULL AND q.created_by_portal_user_id IS NULL)
       OR (q.created_by_user_id IS NULL AND q.created_by_portal_user_id IS NOT NULL)
     );
   COMMIT;
   ```

### B. Rebuild y recargar el frontend

- Asegúrate de tener el código actualizado (incluido el fallback desde el Quote en `useProposals.ts`).
- Haz **build** del proyecto y recarga la app en `localhost:5173` (o el entorno que uses).
- Vuelve a probar **"Create Proposal"** en la quote.

### C. Si el error sigue (diagnóstico)

1. **Comprobar que el trigger existe:**

   En Supabase SQL Editor:

   ```sql
   SELECT tgname FROM pg_trigger
   WHERE tgrelid = 'public."Proposals"'::regclass
     AND tgname = 'trg_proposals_ensure_created_by';
   ```

   Debe devolver una fila. Si no, el trigger no está creado; ejecuta de nuevo la migración del punto A.2.

2. **Comprobar RPC `get_auth_context`:**

   - Que exista la función en la base de datos.
   - Que devuelva correctamente `is_portal_user` y `dealer_id` (o `user_id`) según el usuario actual.

3. **Comprobar columna en DealerUsers:**

   - El código filtra con `.eq('deleted', false)`. En tu esquema la columna debe llamarse `deleted` (no `is_deleted`). Si en tu BD es `is_deleted`, habría que alinear el filtro en `useProposals.ts` con el nombre real de la columna.

---

## Resumen

| Qué | Dónde |
|-----|--------|
| Constraint created_by | Tabla `Proposals`: exactamente uno de `created_by_user_id` o `created_by_portal_user_id` debe estar no null. |
| dealer_id | En V11 `Proposals.dealer_id` es NOT NULL. Se resuelve en frontend: quote → acting dealer → portal dealer. |
| Cambios en código | `src/hooks/useProposals.ts` (dealer_id + created_by + fallback Quote), `src/pages/sales/QuoteNew.tsx` (pasar `actingDealerId` desde `useActiveDealer`), `src/lib/bom/createConfiguredProductPreview.ts` (log sin [circular]). |
| Migraciones a ejecutar en Supabase | `20260224_proposals_created_by_trigger.sql` (trigger) y `20260223_fix_proposals_created_by_constraint.sql` (datos existentes). |
| Checklist para probar | 1) Quote tiene dealer_id o usuario tiene "Actuar como" dealer. 2) Insert incluye dealer_id explícito. 3) created_by exactamente uno. 4) Rebuild front y probar "Create Proposal". |

Si tras esto el error continúa, conviene revisar en consola del navegador y en los logs de Supabase el payload del INSERT y que el trigger y la RPC `get_auth_context` estén aplicados y devolviendo los valores esperados.
