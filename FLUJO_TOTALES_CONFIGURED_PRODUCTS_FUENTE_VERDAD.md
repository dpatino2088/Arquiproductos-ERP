# Flujo de totales en ConfiguredProducts – fuente de verdad

## Resumen

**La única fuente de verdad para los totales y el breakdown es `bom_preview_snapshot` (JSONB).**  
Las columnas escalares de totales son una **copia de conveniencia** de `bom_preview_snapshot.totals` y deben leerse desde el snapshot cuando se necesite el valor “real”.

---

## 1. Estructura en ConfiguredProducts (dump V2)

### Columna fuente de verdad: `bom_preview_snapshot` (jsonb)

Contiene:

- **`version`**: `"1"`
- **`totals`**: objeto con los totales calculados desde el breakdown:
  - `roll_msrp_total`, `bom_total`, `roll_plus_bom_total` (implícito: roll + bom)
  - `labor_pct`, `labor_amount`, `accessories_total`
  - `total_msrp` = roll_msrp_total + bom_total + labor_amount + accessories_total
  - `roll_total_cost`, `bom_total_cost`
- **`items`**: array del **breakdown** (cada ítem con `kind`, `line_total`, `children`, etc.)

Quien calcula y rellena esto es **`build_bom_preview_snapshot`**: construye los ítems (roll + BOM padres/hijos) con precios por línea y luego suma para armar `totals`.

### Columnas escalares (redundantes)

Todas son **réplica** de `bom_preview_snapshot.totals`:

| Columna                | Equivale a                    | Redundante con        |
|------------------------|-------------------------------|------------------------|
| `roll_msrp_total`      | Suma MSRP del roll            | `snapshot.totals.roll_msrp_total` |
| `bom_total`            | Suma MSRP BOM (padres+hijos)  | `snapshot.totals.bom_total` |
| `roll_plus_bom_total`  | roll_msrp_total + bom_total   | Derivable; también en snapshot |
| `total_msrp`           | Total MSRP final              | `snapshot.totals.total_msrp` |
| `roll_total_cost`      | Costo total roll              | `snapshot.totals.roll_total_cost` |
| `bom_total_cost`       | Costo total BOM               | `snapshot.totals.bom_total_cost` |
| `labor_amount`         | Monto labor                   | `snapshot.totals.labor_amount` |
| `accessories_total`    | Total accesorios              | `snapshot.totals.accessories_total` |

Cuando ves **0.0000** en estas columnas suele ser porque:

1. El registro es anterior a la migración que hace el `UPDATE` desde el snapshot, o  
2. El snapshot está vacío (`{}`) y nunca se llegó a llamar a `build_bom_preview_snapshot` / no se persistió bien.

---

## 2. Flujo en base de datos (según dump y migraciones)

```
Usuario "Add to Quote"
        │
        ▼
create_configured_product_and_bom_preview(...)
        │
        ├─ INSERT ConfiguredProducts (sin totales; solo config_snapshot, roll_*, medidas)
        │
        ├─ calculate_configured_product_totals(cp_id)   ← opcional; en dump escribe columnas
        │     (calcula desde BOMComponents + CatalogItemsMSRP; no construye breakdown ítem a ítem)
        │
        ├─ build_bom_preview_snapshot(org_id, cp_id, bom_template_id)   ← FUENTE DE VERDAD
        │     • Construye items[] (roll + cada componente BOM con line_total)
        │     • Suma items → roll_msrp_total, bom_total
        │     • labor_amount, accessories_total, total_msrp
        │     • Devuelve JSONB { version, totals, items }
        │
        └─ UPDATE ConfiguredProducts
              SET bom_preview_snapshot = v_preview_snapshot,
                  roll_msrp_total = (v_totals_json->>'roll_msrp_total')::numeric,
                  bom_total = (v_totals_json->>'bom_total')::numeric,
                  ...
              (todas las columnas de totales desde snapshot.totals)
```

Conclusión: **el valor “real” de los totales es el que sale de `build_bom_preview_snapshot`** (breakdown). Las columnas se rellenan desde `bom_preview_snapshot.totals` en ese mismo `UPDATE`.

---

## 3. Dónde tomar el total “real” en código

- **Backend (RPC, triggers, reportes)**  
  - Preferir siempre: **`bom_preview_snapshot->'totals'->>'total_msrp'`** (y el resto de totales en `totals`).  
  - Si el snapshot está vacío o no tiene `totals`, usar las columnas como fallback: `total_msrp`, `roll_msrp_total`, etc.

- **Frontend (Review, QuoteLine, listados)**  
  - Preferir: **`config.bom_preview_snapshot?.totals?.total_msrp`** (y breakdown en `config.bom_preview_snapshot?.items`).  
  - Si no hay snapshot válido, fallback a las columnas del ConfiguredProduct/QuoteLine según corresponda.

- **commit_configured_product_to_quote_line**  
  - Ya prioriza `bom_preview_snapshot` (items para roll/bom, luego `totals`) y solo usa columnas de ConfiguredProducts cuando el snapshot no tiene datos.

---

## 4. Redundancia y qué hacer con las columnas

- **No es obligatorio eliminar** las columnas de totales: sirven para consultas simples, índices y para el fallback cuando el snapshot está vacío.
- **Sí es obligatorio** considerar **siempre** el breakdown como real:
  - Valor a mostrar y a usar para commit a QuoteLine: **`bom_preview_snapshot.totals`** (y para detalle, **`bom_preview_snapshot.items`**).
  - Las columnas son **copia**; si difieren, gana el snapshot.

Para filas con totales en cero y snapshot `{}`, la migración **20260204_configured_products_drop_motor_sku_backfill_totals.sql** intenta rellenar columnas desde snapshot cuando existe; si el snapshot está vacío, no hay forma de recuperar el total “real” sin volver a ejecutar `build_bom_preview_snapshot` (por ejemplo vía RPC o job).

---

## 5. Resumen de validación

| Pregunta | Respuesta |
|----------|-----------|
| ¿Cuál es la fuente de verdad para el total MSRP? | **`bom_preview_snapshot.totals.total_msrp`** (y el breakdown en `bom_preview_snapshot.items`). |
| ¿Las columnas roll_msrp_total, bom_total, total_msrp, etc.? | Redundantes; copia de `snapshot.totals` para conveniencia y fallback. |
| ¿Por qué hay columnas en cero? | Registros antiguos o snapshot no persistido (`{}`). |
| ¿Qué usar en UI y en commit a QuoteLine? | Leer de **`bom_preview_snapshot`**; si no hay snapshot válido, usar columnas. |
