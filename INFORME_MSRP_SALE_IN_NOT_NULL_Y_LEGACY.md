# Informe: Error `msrp_sale_in` NOT NULL en CatalogItemsMSRP y columnas Legacy vs Existentes

**Fecha:** 2026-01-25  
**Error:** `null value in column "msrp_sale_in" of relation "CatalogItemsMSRP" violates not-null constraint`  
**Síntoma:** Edit Item no guarda al hacer Update en CatalogItems.

---

## 1. Descripción del problema

Al guardar un ítem en **Edit Item** (Catalog → Items → Edit), el `UPDATE` sobre `CatalogItems` devuelve el error anterior. La restricción `NOT NULL` de `msrp_sale_in` en `CatalogItemsMSRP` se incumple en algún `INSERT` o `UPDATE` sobre esa tabla.

- El frontend **solo** escribe en `CatalogItems` (`useCatalog.updateItem` → `supabase.from('CatalogItems').update(payload)`).
- `CatalogItemsMSRP` se rellena/actualiza por **triggers y funciones en la base de datos**, no por la app.
- Por tanto, el `NULL` en `msrp_sale_in` viene de alguna función o trigger que escribe en `CatalogItemsMSRP` sin asignar ese campo.

---

## 2. Flujo actual (resumido)

### 2.1 Escritura en CatalogItems (frontend)

**CatalogItemNew.tsx** envía un `payload` solo con columnas de `CatalogItems`:

- `sku`, `name`, `description`, `unit_of_measure`, `measure_basis`, `category_id`, `image_url`
- `is_fabric`, `is_roll`, `roll_type`, `collection_name`, `variant_name`, `roll_width`, `fabric_pricing_mode`
- `color`, `cost_exw`, `is_active`

No se envía nada a `CatalogItemsMSRP` desde el frontend.

### 2.2 Triggers sobre CatalogItems que afectan a CatalogItemsMSRP

| Trigger | Tabla | Evento | Función | Efecto |
|--------|--------|--------|---------|--------|
| `trg_recompute_msrp_on_catalog_item_change` | CatalogItems | `AFTER INSERT OR UPDATE OF cost_exw, category_id` | `trig_recompute_msrp_on_catalog_item_change()` | Llama a `msrp_compute_for_item(NEW.id)` |
| `trg_sync_catalogitems_to_msrp` | CatalogItems | `AFTER UPDATE OF sku, name, collection_name, variant_name, unit_of_measure` | `sync_catalogitems_to_msrp()` | Sincroniza identidad (y en 20260135: upsert) a CatalogItemsMSRP |

### 2.3 Quién escribe en CatalogItemsMSRP

1. **`msrp_compute_for_item(item_id)`**  
   - `INSERT ... ON CONFLICT (catalog_item_id) DO UPDATE` en `CatalogItemsMSRP`.  
   - En todas las versiones revisadas (20260116, 20260125, 20260130–34) incluye explícitamente `msrp_sale_in` y `msrp_sale_out` (con `COALESCE(..., 0)`).  
   - Solo se invoca desde `trig_recompute_msrp_on_catalog_item_change`.

2. **`sync_catalogitems_to_msrp()`**  
   - Antes de 20260135: solo `UPDATE ... SET sku, name, collection_name, variant_name, unit_of_measure WHERE catalog_item_id = NEW.id`. No hace `INSERT` ni toca `msrp_sale_in`/`msrp_sale_out`.  
   - En 20260135: se cambia a **upsert** (INSERT si no existe fila, con `msrp_sale_in=0`, `msrp_sale_out=0`) y `ON CONFLICT DO UPDATE` solo de identidad.

3. **Triggers en CatalogItemsMSRP (backup 2026-01-23)**  
   - `trg_fill_msrp_item_identity`: `BEFORE INSERT OR UPDATE OF catalog_item_id, sku, name, collection_name, variant_name`; rellena `sku`, `name`, `collection_name`, `variant_name`, `unit_of_measure` desde `CatalogItems` cuando vienen NULL. **No asigna `msrp_sale_in` ni `msrp_sale_out`.**  
   - `trg_fill_msrp_sku_name`: `BEFORE INSERT OR UPDATE OF catalog_item_id, sku, name`; rellena `sku`/`name`. Tampoco toca MSRP.  
   - `trg_catalogitemsmsrp_updated_at`: `BEFORE UPDATE`; solo `updated_at`.

Ninguno de estos triggers rellena `msrp_sale_in` si el `INSERT` que llega no lo trae.

---

## 3. Hipótesis sobre el origen del NULL en `msrp_sale_in`

### 3.1 (Principal) Trigger `trg_recompute_msrp_on_catalog_item_change` no se ejecutaba cuando `cost_exw` era 0 o NULL

- Definición en **20260125_fix_cost_engine_complete** (y variantes):
  - `WHEN (NEW.cost_exw > 0 AND NEW.organization_id IS NOT NULL)`.
- Consecuencia: para ítems con `cost_exw = 0` o `NULL`, `msrp_compute_for_item` **nunca** se ejecuta.
- Para esos ítems:
  - No se crea fila en `CatalogItemsMSRP` al insertar el ítem.
  - No se actualiza `CatalogItemsMSRP` al hacer `UPDATE` solo de `cost_exw`/`category_id` (p. ej. de 0 a 0, o de NULL a NULL).

Si en algún otro punto (otro trigger, función o RPC) se hiciera un `INSERT` en `CatalogItemsMSRP` “solo identidad” (sin `msrp_sale_in`/`msrp_sale_out`), se violaría `NOT NULL`. No se ha encontrado ese `INSERT` en el código revisado; la hipótesis es que el fallo se da cuando **sí** se intenta escribir en `CatalogItemsMSRP` por alguna vía que no pasa por la versión actual de `msrp_compute_for_item` o que asume que la fila ya existe y en cambio hace un `INSERT` incompleto.

### 3.2 `sync_catalogitems_to_msrp` solo hacía UPDATE

- Si no existía fila en `CatalogItemsMSRP` (p. ej. ítem con `cost_exw=0` que nunca pasó por `msrp_compute_for_item`), el `UPDATE` no tocaba ninguna fila. Eso no produce por sí solo el error de `msrp_sale_in`.
- La hipótesis aquí: si en algún arreglo o migración se cambió `sync` a un “INSERT cuando no hay fila” **sin** incluir `msrp_sale_in`/`msrp_sale_out`, ese `INSERT` sí causaría el error. En el código actual (pre-20260135) `sync` solo hacía `UPDATE`; en 20260135 se corrige el upsert para incluir siempre `msrp_sale_in` y `msrp_sale_out`.

### 3.3 Triggers BEFORE en CatalogItemsMSRP

- `fill_msrp_item_identity` y `fill_msrp_sku_name` solo rellenan campos de identidad. No tocan `msrp_sale_in`/`msrp_sale_out`.
- Si un `INSERT` llega sin `msrp_sale_in`, el BEFORE no lo arregla y el `NOT NULL` falla.

### 3.4 Orden de ejecución de migraciones o versión de funciones en BD

- Si en la base está una versión antigua de `msrp_compute_for_item` que no escribe `msrp_sale_in`/`msrp_sale_out`, o una versión de `sync` que hace `INSERT` sin ellos, el error encaja.
- Si no se han aplicado 20260129–20260134, pueden faltar columnas o pasos de backfill y aparecer errores distintos o derivados.

### 3.5 ON CONFLICT y约束 únicos

- `msrp_compute_for_item` usa `ON CONFLICT (catalog_item_id)`.
- En **20260125_finalize_pricing_flow** se añade `catalogitemsmsrp_org_item_unique` sobre `(organization_id, catalog_item_id)`.
- El backup indica `CatalogItemsMSRP_pkey` en `catalog_item_id`, por lo que `ON CONFLICT (catalog_item_id)` es coherente con el PK. Si en tu BD el único constraint es `(organization_id, catalog_item_id)` y no `(catalog_item_id)`, el `ON CONFLICT` podría no coincidir; en ese caso el `INSERT` iría como inserción nueva y, si esa variante de `INSERT` no trajera `msrp_sale_in`, también se explicaría el `NOT NULL`.

---

## 4. Qué se ha hecho hasta ahora

### 4.1 Migración **20260135_fix_catalogitemsmsrp_not_null_on_save.sql**

Objetivo: que nunca se intente escribir en `CatalogItemsMSRP` sin `msrp_sale_in`/`msrp_sale_out`.

1. **Trigger `trg_recompute_msrp_on_catalog_item_change`**
   - Se elimina la condición `cost_exw > 0`.
   - Se deja: `WHEN (NEW.organization_id IS NOT NULL)`.
   - Efecto: `msrp_compute_for_item` se ejecuta también con `cost_exw = 0` o `NULL`; la función ya calcula `msrp_sale_in`/`msrp_sale_out` (en esos casos, 0) y los escribe.

2. **Función `trig_recompute_msrp_on_catalog_item_change`**
   - Se quita la comprobación interna `IF NEW.cost_exw > 0`; se llama siempre `msrp_compute_for_item(NEW.id)` cuando corre el trigger.

3. **Función `sync_catalogitems_to_msrp`**
   - Se convierte en **upsert**:
     - `INSERT` con:  
       `catalog_item_id`, `organization_id`, `category_id`, `cost_exw`, `import_tax_cost`, `shipping_cost`, `total_cost`,  
       `msrp_sale_in`, `msrp_sale_out` (en 0),  
       `shipping_pct`, `import_tax_pct`, `minimum_margin_pct`, `msrp_pct_sale_out`, `material_cost`,  
       `sku`, `name`, `collection_name`, `variant_name`, `unit_of_measure`.
     - `ON CONFLICT (catalog_item_id) DO UPDATE SET` solo:  
       `sku`, `name`, `collection_name`, `variant_name`, `unit_of_measure`.
   - Así, si no existía fila (p. ej. ítem con `cost_exw=0` que nunca pasó por `msrp_compute`), el `INSERT` crea la fila con `msrp_sale_in=0` y `msrp_sale_out=0`, evitando `NOT NULL`.

### 4.2 Otras correcciones previas (contexto)

- **20260116_fix_msrp_not_null_constraints**: se asegura que `msrp_compute_for_item` use `COALESCE(..., 0)` en costes y en `msrp_sale_in`/`msrp_sale_out` antes del `INSERT`.
- **20260129–20260134**: se añaden columnas a `CatalogItemsMSRP` (`unit_of_measure`, `shipping_pct`, `import_tax_pct`, `minimum_margin_pct`, `msrp_pct_sale_out`, `material_cost`) y se mantiene `msrp_compute_for_item` escribiendo `msrp_sale_in`/`msrp_sale_out`.

### 4.3 Comprobar que 20260135 se ha aplicado

- La migración **debe estar aplicada** en la misma base donde ocurre el error. Si el error persiste después de 20260135, hay que verificar:
  - Que el orden de migraciones sea: 20260129 → 20260130 → 20260131 → 20260132 → 20260133 → 20260134 → **20260135**.
  - Que no falle la parte de `sync` (p. ej. por `ON CONFLICT (catalog_item_id)` si en tu BD el único unique es `(organization_id, catalog_item_id)`).

---

## 5. Columnas que necesito para distinguir Legacy vs Existentes

Para afinar el informe y las migraciones (incluido el upsert de `sync`), hace falta saber **qué hay realmente en tu BD**, no solo en backups o en código.

### 5.1 CatalogItemsMSRP

Ejecuta en la base donde falla:

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP'
ORDER BY ordinal_position;
```

Necesito sobre todo:

- Qué columnas existen (para no hacer `INSERT`/`UPDATE` de columnas que no estén).
- Cuáles son `is_nullable = 'NO'` (NOT NULL), para que el upsert de `sync` y `msrp_compute_for_item` las rellenen siempre.

Resumen según **backup 2026-01-23** y migraciones 20260129–34:

| Columna | NOT NULL (backup) | Añadida en migración | Uso |
|---------|--------------------|-----------------------|-----|
| catalog_item_id | Sí (PK) | — | Siempre |
| organization_id | Sí | — | Siempre |
| category_id | No | — | Opcional |
| cost_exw | Sí | — | Siempre |
| import_tax_cost | Sí | — | Siempre |
| shipping_cost | Sí | — | Siempre |
| total_cost | Sí | — | Siempre |
| msrp_sale_in | Sí | — | **La que falla** |
| msrp_sale_out | Sí | — | Siempre |
| sku | No | — | Identidad |
| name | No | — | Identidad |
| collection_name | No | — | Identidad |
| variant_name | No | — | Identidad |
| updated_at | Sí (default now()) | — | — |
| unit_of_measure | — | 20260129 | Identidad |
| shipping_pct | — | 20260130 | % |
| import_tax_pct | — | 20260131 | % |
| minimum_margin_pct | — | 20260132 | % |
| msrp_pct_sale_out | — | 20260133 | % |
| material_cost | — | 20260134 | = cost_exw |

Además, para el `ON CONFLICT`:

```sql
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public."CatalogItemsMSRP"'::regclass;
```

Necesito: qué `UNIQUE` o `PRIMARY KEY` hay (`catalog_item_id` solo, `(organization_id, catalog_item_id)`, o ambos) para validar `ON CONFLICT (catalog_item_id)` o si hay que usar `(organization_id, catalog_item_id)`.

### 5.2 CatalogItems (Legacy vs utilizado en Edit Item)

Para un informe de “legacy vs existentes” en CatalogItems:

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'CatalogItems'
ORDER BY ordinal_position;
```

En el código de **CatalogItemNew** (formulario Edit Item) se usan:

- En payload de guardado:  
  `sku`, `name`, `description`, `unit_of_measure`, `measure_basis`, `category_id`, `image_url`,  
  `is_fabric`, `is_roll`, `roll_type`, `collection_name`, `variant_name`, `roll_width`, `fabric_pricing_mode`,  
  `color`, `cost_exw`, `is_active`.

En comentarios del propio `CatalogItemNew` se marcan como **legacy (existen en DB pero no en formulario)**:

- `manufacturer`, `manufacturer_id`

Del backup 2026-01-23, CatalogItems incluye también (entre otras):

- `id`, `organization_id`, `name`, `sku`, `unit_of_measure`, `description`, `category_id`, `image_url`
- `measure_basis`, `is_fabric`, `collection_name`, `variant_name`, `roll_width`, `fabric_pricing_mode`, `color`, `is_active`, `created_at`, `updated_at`
- `cost_exw`, `manufacturer`, `manufacturer_id`, `is_roll`, `roll_collection_id`, `roll_type`, `item_role`

Para “legacy vs existentes” en CatalogItems necesito:

- La salida de `information_schema.columns` para `CatalogItems` (y, si puedes, para `CatalogItemsMSRP`).
- Opcional: qué columnas se siguen usando en:
  - `useCatalog` (create/update/select),
  - `msrp_compute_for_item` (solo usa `organization_id`, `category_id`, `cost_exw` de CatalogItems),
  - `sync_catalogitems_to_msrp` (usa `id`, `organization_id`, `category_id`, `cost_exw`, `sku`, `name`, `collection_name`, `variant_name`, `unit_of_measure`).

Con eso se puede armar una tabla fiable: “existe en DB”, “se usa en Edit Item”, “se usa en MSRP/sync”, “legacy (no se usa en Edit Item)”.

### 5.3 Triggers en CatalogItemsMSRP

Para descartar que algún BEFORE INSERT/UPDATE esté borrando o no rellenando `msrp_sale_in`:

```sql
SELECT tgname, tgtype, tgenabled, pg_get_triggerdef(oid)
FROM pg_trigger
WHERE tgrelid = 'public."CatalogItemsMSRP"'::regclass
  AND NOT tgisinternal;
```

Necesito: nombres y definiciones de los triggers (sobre todo los `BEFORE INSERT`/`UPDATE`) para comprobar que ninguno toca `msrp_sale_in`/`msrp_sale_out`.

---

## 6. Resumen de hipótesis (prioridad)

| # | Hipótesis | Acción |
|---|-----------|--------|
| 1 | El trigger `trg_recompute_msrp_on_catalog_item_change` no corría con `cost_exw=0`/NULL, y alguna vía acaba escribiendo en CatalogItemsMSRP sin `msrp_sale_in`. | 20260135: quitar `cost_exw > 0` del `WHEN` y de la función. |
| 2 | `sync` en algún momento hace (o hizo) INSERT sin `msrp_sale_in`/`msrp_sale_out`. | 20260135: upsert en `sync` que siempre inserta `msrp_sale_in=0`, `msrp_sale_out=0` si no hay fila. |
| 3 | En BD hay versión antigua de `msrp_compute_for_item` o de `sync` sin esos campos. | Aplicar 20260129–20260135 en orden y comprobar que no hay errores al aplicarlas. |
| 4 | `ON CONFLICT (catalog_item_id)` no coincide con los constraints reales de `CatalogItemsMSRP`. | Ajustar `ON CONFLICT` según el resultado de `pg_constraint` (ver 5.1). |
| 5 | Un BEFORE en `CatalogItemsMSRP` modifica o deja de rellenar `msrp_sale_in`. | Revisar `pg_trigger` (ver 5.3) y definiciones de `fill_msrp_item_identity` y `fill_msrp_sku_name`. |

---

## 7. Próximos pasos recomendados

1. **Aplicar 20260135** en la base donde ocurre el error (tras 20260129–34) y repetir “Edit Item → Save”.
2. **Ejecutar las consultas de 5.1, 5.2 y 5.3** y compartir resultados (o al menos: columnas `CatalogItemsMSRP` con `is_nullable`, constraints únicos/PK de `CatalogItemsMSRP`, y lista de triggers en `CatalogItemsMSRP`).
3. Si el error sigue:
   - Revisar si `sync` falla por `ON CONFLICT` (p. ej. si solo existe `(organization_id, catalog_item_id)`): en ese caso, cambiar a `ON CONFLICT (organization_id, catalog_item_id)` en 20260135.
   - Comprobar que en BD está la versión de `msrp_compute_for_item` que incluye `msrp_sale_in`/`msrp_sale_out` en el `INSERT` y en el `DO UPDATE` (por ejemplo, la de 20260134 o 20260135, si se reemplazó ahí).

Con las columnas y constraints reales de `CatalogItemsMSRP` y `CatalogItems` se puede cerrar el informe “legacy vs existentes” y asegurar que todas las escrituras en `CatalogItemsMSRP` cumplan `NOT NULL` en `msrp_sale_in` y `msrp_sale_out`.
