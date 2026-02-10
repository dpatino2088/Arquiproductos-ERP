# Directory INSERT – Debug por consola

Cuando intentas guardar un contacto y falla con *"new row violates row-level security policy for table DirectoryContacts"*, abre la consola del navegador (F12 → Console), vuelve a intentar guardar y copia/pega aquí **los 4 objetos completos** tal cual salen.

---

## Qué pegar (los 4 objetos)

Copia/pega exactamente lo que aparece en consola para:

1. **AUTH USER** – `{ ... }`
2. **DealerUsers rows** – `{ ... }`
3. **RPC current_dealer_id** – `{ ... }`
4. **MATCH CHECK** – `{ ... }`

Con eso se puede ver cuál de los puntos siguientes es el culpable y aplicar el fix indicado.

---

## Diagnóstico y fix por culpable

| Culpable | Qué ves en los logs | Fix |
|----------|---------------------|-----|
| **A) Sesión/auth rota** | `userRes.user` null o `userErr` presente | Sesión o auth mal inicializada. **Fix:** refresh de sesión, volver a hacer login o revisar init de auth (Supabase client, persistencia de sesión). |
| **B) RLS en DealerUsers** | `duErr` (error en la query) o `dealerUsers` vacío cuando sí deberías tener fila | La política SELECT de DealerUsers no te deja ver tu fila. **Fix:** policy SELECT que permita `user_id = auth.uid()` **o** match por email (p. ej. `portal_user_email` = email del JWT). |
| **C) Sin match user_id/email o JWT sin email** | `dealerIdErr` o `dealerIdRes = null` | No hay fila en DealerUsers que coincida con el usuario actual, o el JWT no trae email. **Fix:** asegurar que al hacer login se vincule `DealerUsers.user_id` (p. ej. con RPC `link_portal_user()` o flujo de invitación/aceptación). Revisar que el JWT incluya el email si la policy usa email. |
| **D) Payload desalineado** | `dealerIdRes` trae un UUID válido pero el INSERT sigue fallando | El payload que se envía tiene `dealer_id` u `organization_id` distintos a lo que espera la policy. **Fix:** alinear el payload del frontend con el `organization_id` / `dealer_id` que devuelve el RPC, o permitir `dealer_id IS NULL` en la policy y dejar que un trigger lo rellene. |

---

## Resumen rápido

- **A** → arreglar auth/sesión.
- **B** → arreglar policy SELECT en `DealerUsers`.
- **C** → vincular usuario auth con DealerUser (user_id/email) o asegurar JWT con email.
- **D** → corregir payload (organization_id/dealer_id) o policy/trigger para aceptar NULL.

Pega los 4 objetos de consola y con ellos se puede decir exactamente cuál es **A**, **B**, **C** o **D** y el fix concreto.
