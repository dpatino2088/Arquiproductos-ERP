# Created By — Verificación manual

Para comprobar que la columna "Created by" en Quotes (y derivados) coincide con los datos de la base.

## Query: Quote → created_by_user_id vs UI

La UI muestra `COALESCE(au.display_name, 'Legacy / Imported')` donde `au` es el AppUser con `au.id = q.created_by_user_id`.

Ejecutar en el SQL Editor (Supabase o cliente SQL); reemplaza `'TU-QUOTE-ID-AQUI'` por un uuid real de `public."Quotes"`:

```sql
-- Verificación: comparar quote.created_by_user_id con lo que la UI muestra como "Created by"
SELECT
  q.id,
  q.quote_no,
  q.created_by_user_id,
  au.display_name AS expected_created_by_ui,
  COALESCE(au.display_name, 'Legacy / Imported') AS label_ui
FROM public."Quotes" q
LEFT JOIN public."AppUsers" au ON au.id = q.created_by_user_id
WHERE q.id = 'TU-QUOTE-ID-AQUI'
  AND COALESCE(q.deleted, false) = false;
```

- Si `created_by_user_id` es NULL o no existe en AppUsers, la UI debe mostrar **Legacy / Imported**.
- Si existe en AppUsers, la UI debe mostrar `display_name` (o **Legacy / Imported** si `display_name` es NULL).

## Misma lógica en listados

- **Quotes list:** cada fila tiene `created_by` = resultado de la expresión anterior para esa quote.
- **QuoteLines (QuoteNew):** cada línea tiene `quote_created_by` = mismo valor que el Quote padre (creador del quote).
- **Proposals list:** `proposal_created_by` = creador del proposal; `quote_created_by` = creador del Quote asociado.
