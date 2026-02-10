# Adaptio — Modelo de Availability (informativo)

## Resumen ejecutivo (1 página)

Adaptio separa de forma clara:

- **Disponibilidad de materiales** (interna, informativa)
- **Promesa de fabricación al cliente** (Manufacturing)

### Availability

- Aplica solo a **telas, rollos y especiales** (materiales críticos).
- Es **informativo** para el dealer: no bloquea ni reordena.
- **No se guarda en QuoteLine** (el snapshot de la línea es estable).

### Manufacturing

- Define los tiempos del producto y es la **única fuente de lead time al cliente**.

### Arquitectura implementada

| Capa | Fuente | Uso |
|------|--------|-----|
| **Inventario** | `InventoryBalances` → vista `inventory_on_hand` | Stock real (ledger) |
| **Compras / PO** | `PurchaseOrders` + `PurchaseOrderLines` | Tránsito (ETA) |
| **Perfil operativo** | `InventoryItemProfiles` | Fallback import (materiales críticos) |
| **Availability** | Vista `inventory_availability` | Informativo interno |
| **Manufacturing** | Tiempos de producto | Promesa real al cliente |
| **QuoteLine** | Snapshot (cost, MSRP, config) | Snapshot estable, sin stock/ETA/availability |

### Reglas (no violar)

1. Availability es solo informativo; no bloquea ni reordena.
2. El lead time del producto final viene **exclusivamente** de Manufacturing.
3. QuoteLine **no** guarda stock, ETA ni availability.
4. Availability se aplica solo a ciertos roles de material (fabric, roll, special).

### Badges en UI

- **Estado principal**: IN_STOCK | IN_TRANSIT | IMPORT | UNKNOWN.
- **Modificador**: **Risk** (no es un estado principal; se muestra como "· Risk" junto al estado, e.g. "In transit · Risk"). Así la realidad (stock/tránsito/import) manda y Risk solo advierte.

Se muestran solo donde se eligen materiales críticos (ej. paso de tela). No se persisten en QuoteLine.

### Plan de ejecución (orden)

1. **Fase 1** — Datos base: `Warehouses`, `PurchaseOrders` (warehouse_id, expected_date, status), `PurchaseOrderLines`, `InventoryItemProfiles`, `InventoryBalances` + RLS.
2. **Fase 2** — Vistas: `inventory_on_hand`, `inventory_on_order`, `inventory_availability`.
3. **Fase 3** — RPC `get_inventory_availability(warehouse_id, catalog_item_ids[])`; RLS vía tablas base.
4. **Fase 4** — Frontend: `useWarehouses`, `useInventoryAvailability`, `AvailabilityBadge`; consumir solo para roles críticos; no persistir en QuoteLine.
5. **Fase 5** — Manufacturing: confirmar como fuente única de lead time (documental/operativo).

Migraciones: `20260216_inventory_availability_phase1_tables.sql`, `phase2_views.sql`, `phase3_rpc.sql`.

### Validaciones de diseño (pre-producción)

1. **PO status vs cálculo**: El status (OPEN/PARTIAL/CLOSED) es informativo; la vista `inventory_on_order` usa `(ordered_qty - received_qty) > 0` como fuente de verdad.
2. **next_eta**: `MIN(expected_date) FILTER (WHERE expected_date IS NOT NULL)` para que POs sin ETA no rompan el agregado.
3. **RPC**: `STABLE` (no escribe); RLS vía tablas base.
4. **Buffers/reglas por material**: Si en el futuro se añaden, hacerlo dentro de Manufacturing, nunca en Availability.
