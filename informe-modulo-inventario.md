# Informe detallado: Módulo de Inventario — PlanDrive

**Fecha:** Febrero 2026  
**Alcance:** Cómo se está manejando el módulo de inventario en la aplicación PlanDrive (frontend + integración con Supabase).

---

## 1. Resumen ejecutivo

El módulo de inventario en PlanDrive se organiza en **siete submódulos** principales: **Catalog Items**, **Stock**, **Movements**, **Purchase Orders**, **Receipts**, **Credits** y **Adjustments**. La **fuente de verdad** del stock es la combinación de las tablas `inventory_operations` e `inventory_operation_items`; las vistas `inventory_on_hand` e `inventory_on_hand_global` (y opcionalmente `inventory_on_hand_by_location`) calculan el stock disponible por ítem y almacén. Los documentos de captura (receipts, credits, adjustments) y los movements directos (assign, transfer, delivery, return) siguen un patrón **draft → confirm**: solo al **confirmar** se crean o actualizan operaciones en `inventory_operations` y se impacta el inventario. No se introducen nuevas dependencias; se reutilizan componentes UI y patrones de las páginas Info existentes.

---

## 2. Arquitectura del módulo

### 2.1 Navegación y rutas

Todas las rutas de inventario están bajo el prefijo `/inventory/` y se registran en `src/routes/register-routes.ts`. El **Layout** y el hook **useSubmoduleNav** exponen la misma lista de submódulos en todas las páginas del módulo:

| Submódulo        | Ruta lista              | Ruta detalle / crear        | Página lista   | Página Info          |
|------------------|-------------------------|-----------------------------|----------------|----------------------|
| Catalog Items    | `/inventory/catalog-items` | `/new`, `/:id`           | CatalogItems   | CatalogItemInfo      |
| Stock            | `/inventory/stock`      | —                           | Stock          | —                    |
| Movements        | `/inventory/movements`  | `/:id` (incl. `new`)        | Movements      | MovementInfo         |
| Purchase Orders  | `/inventory/purchase-orders` | `/new`, `/:id`        | PurchaseOrders | PurchaseOrderInfo    |
| Receipts         | `/inventory/receipts`   | `/new`, `/:id`              | Receipts       | ReceiptInfo          |
| Credits          | `/inventory/credits`    | `/:id` (sin `/new`)         | Credits        | CreditInfo           |
| Adjustments      | `/inventory/adjustments`| `/:id`                      | Adjustments    | AdjustmentInfo       |

- **Movements**: la lista usa `public_id` para abrir detalle (`/inventory/movements/{public_id}`); también se puede llegar por UUID (p. ej. desde CreditInfo/AdjustmentInfo que enlazan a la operation).
- **Credits** no tiene ruta “new”; los créditos se crean desde ReceiptInfo (asociados a un receipt).

### 2.2 Estructura de archivos relevante

```
src/
├── pages/inventory/
│   ├── CatalogItems.tsx, CatalogItemInfo.tsx
│   ├── Stock.tsx
│   ├── Movements.tsx, MovementInfo.tsx, MovementsInfo.tsx  (alias)
│   ├── PurchaseOrders.tsx, PurchaseOrderInfo.tsx
│   ├── Receipts.tsx, ReceiptInfo.tsx
│   ├── Credits.tsx, CreditInfo.tsx
│   └── Adjustments.tsx, AdjustmentInfo.tsx
├── lib/
│   ├── adjustments.api.ts
│   ├── credits.api.ts
│   ├── receipts.api.ts
│   ├── inventoryUnits.ts
│   └── supabase.ts
├── hooks/
│   ├── useCatalogItems.ts
│   ├── useInventoryStock.ts
│   ├── useInventoryOperations.ts
│   ├── useStockBreakdown.ts
│   ├── useAdjustments.ts, useCredits.ts, useReceipts.ts
│   └── usePurchaseOrders.ts
└── routes/register-routes.ts
```

---

## 3. Modelo de datos (resumen)

### 3.1 Fuente de verdad del stock

- **`public.inventory_operations`**: cabecera de cada operación (tipo, almacenes origen/destino, job, stage, etc.).
- **`public.inventory_operation_items`**: líneas por operación (`catalog_item_id`, `inventory_qty` con signo; sin `warehouse_id` por línea — el almacén viene del header).

El stock “on hand” se obtiene de **vistas** que agregan operaciones confirmadas:

- **`inventory_on_hand`**: `company_id`, `catalog_item_id`, `warehouse_id`, `on_hand_qty`.
- **`inventory_on_hand_global`**: total por company + catalog_item (sin warehouse).
- **`inventory_on_hand_by_location`**: desglose por ubicación dentro del almacén (usado en Stock para el detalle por ítem).

### 3.2 Tipos de operación

En `inventory_operations.operation_type` se usan, entre otros:

- **receipt** — Entrada por recepción (PO).
- **delivery**, **assign**, **transfer**, **return** — Movements gestionados en MovementInfo.
- **credit** — Salida por crédito (vinculado a receipt).
- **adjustment** — Ajustes manuales (incremento/decremento).

En la **lista Movements** se ocultan `receipt`, `credit` y `adjustment` porque tienen pantallas propias (Receipts, Credits, Adjustments).

### 3.3 Documentos de captura vs operations

Varios flujos no escriben directamente en `inventory_operations`; usan tablas “de captura” y solo al **confirmar** se crea la operation:

| Documento      | Tabla cabecera           | Tabla líneas                  | RPC de confirmación              | operation_type creado |
|----------------|--------------------------|-------------------------------|----------------------------------|------------------------|
| Receipt        | inventory_receipts       | inventory_receipt_items       | confirm_inventory_receipt        | receipt                |
| Credit         | inventory_credits        | inventory_credit_items        | confirm_inventory_credit         | credit                 |
| Adjustment     | inventory_adjustments    | inventory_adjustment_items    | confirm_inventory_adjustment     | adjustment             |
| Movement       | inventory_operations     | inventory_operation_items     | confirm_inventory_operation      | assign/transfer/delivery/return |

- **Movements** (assign, transfer, delivery, return): se crean y editan **directamente** en `inventory_operations` + `inventory_operation_items` en estado draft; la RPC `confirm_inventory_operation` valida, normaliza signos y marca `stage = 'confirmed'`.

---

## 4. Submódulos en detalle

### 4.1 Catalog Items

- **Lista:** `CatalogItems.tsx` — listado de ítems del catálogo (nombre, SKU, categoría, unidad, etc.).
- **Detalle/alta:** `CatalogItemInfo.tsx` — crear/editar ítem; se usa `useCatalogItems` y Supabase sobre `catalog_items` (y tablas relacionadas: categorías, marcas, fabricantes, unidades, etc.).
- **Stock:** La página Stock y los hooks de stock usan `catalog_items` para nombre, SKU, `inventory_unit`, etc.

### 4.2 Stock

- **Página:** `Stock.tsx`.
- **Fuente de datos:** Hook `useInventoryStock` (opcionalmente filtrado por `warehouseId`, `locationId`, búsqueda, incluir inactivos). Combina:
  - `inventory_on_hand` / `inventory_on_hand_global` para cantidades.
  - `catalog_items` para atributos de ítem.
  - Consultas adicionales para “credited” (operaciones tipo credit confirmadas).
- **Desglose por almacén/ubicación:** `useStockBreakdown(catalogItemId)` usa `inventory_on_hand` y `inventory_on_hand_by_location` (con caché de 10 s; se invalida tras confirmar credit/adjustment/receipt/movement).
- **Evento de invalidación:** Tras confirmar receipt/credit/adjustment/movement se dispara `INVENTORY_STOCK_INVALIDATE_EVENT` y se llama `invalidateStockBreakdownCache()` para que Stock y desgloses se refresquen.

### 4.3 Movements

- **Lista:** `Movements.tsx` — usa `useInventoryOperations`; muestra solo operaciones de tipo assign, transfer, delivery, return; botón “Add” lleva a `/inventory/movements/new`.
- **Detalle/Crear/Confirmar:** `MovementInfo.tsx` (alias export: `MovementsInfo.tsx`).
  - **Crear:** ruta `.../new`; se elige tipo (assign/transfer/delivery/return), almacén(es), job opcional, notas y líneas (catalog_item + qty positiva). Al guardar se inserta en `inventory_operations` e `inventory_operation_items` (draft).
  - **Editar:** solo en draft; mismo formulario; validaciones: warehouses según tipo, from ≠ to en transfer, al menos una línea con qty > 0, sin duplicados por catalog_item.
  - **Confirmar:** botón “Confirm movement” abre modal de resumen y llama a `confirm_inventory_operation(p_operation_id)`. Tras éxito, la pantalla pasa a solo lectura (stage = confirmed).
- **RPC `confirm_inventory_operation`:** Valida draft, ítems, warehouses según tipo; normaliza signos de `inventory_qty` (p. ej. assign/delivery/transfer con qty negativa; return positiva); actualiza `stage` y `confirmed_at`.

### 4.4 Purchase Orders

- **Lista:** `PurchaseOrders.tsx`; **detalle/crear:** `PurchaseOrderInfo.tsx`.
- Gestionan Órdenes de compra (cabecera + líneas); no se detalla aquí el flujo completo. Relación con inventario: los **Receipts** reciben contra PO (inventory_receipt_items pueden vincularse a purchase_order_item_id).

### 4.5 Receipts

- **Lista:** `Receipts.tsx` (hook `useReceipts`; API `receipts.api.ts`).
- **Crear/Editar:** `ReceiptInfo.tsx` — warehouse, received_at, notas; líneas asociadas a PO (ítem, pack, qty_input, inventory_qty, ubicación opcional). Los ítems vienen de líneas de PO con remaining.
- **Confirmación:** RPC `confirm_inventory_receipt` crea la operation (receipt) y ítems; además se usa `update_po_status_for_receipt` para actualizar estado del PO.
- Tras confirmar, desde ReceiptInfo se puede enlazar a la operation en Movements (`/inventory/movements/{inventory_operation_id}`).

### 4.6 Credits

- **Lista:** `Credits.tsx` (hook `useCredits`; API `credits.api.ts`).
- **Crear:** Desde ReceiptInfo, eligiendo receipt; el crédito hereda warehouse del receipt. **Detalle/Editar:** `CreditInfo.tsx` — líneas con ítems y cantidades; las cantidades no pueden superar lo recibido menos lo ya acreditado por ese receipt.
- **Confirmación:** RPC `confirm_inventory_credit` crea la operation (credit) con `inventory_qty` negativa en ítems.
- En CreditInfo hay enlace a la operation en Movements.

### 4.7 Adjustments

- **Lista:** `Adjustments.tsx` (hook `useAdjustments`; API `adjustments.api.ts`).
- **Crear/Editar:** `AdjustmentInfo.tsx` — warehouse, reason, notas; líneas con ítem, dirección (increase/decrease) y qty; se valida que las disminuciones no superen el stock on-hand del almacén (vía `inventory_on_hand`).
- **Confirmación:** RPC `confirm_inventory_adjustment` crea la operation (adjustment) y copia ítems con qty ya firmada (positiva/negativa).
- En AdjustmentInfo hay enlace a la operation en Movements.

---

## 5. Flujos de confirmación (RPCs)

Resumen de las funciones RPC usadas y su efecto:

| RPC                         | Parámetro principal     | Efecto resumido |
|-----------------------------|-------------------------|------------------|
| confirm_inventory_receipt   | receipt id              | Crea operation (receipt) + items; actualiza PO status. |
| confirm_inventory_credit    | credit id               | Crea operation (credit) + items con qty negativa.       |
| confirm_inventory_adjustment| adjustment id           | Crea operation (adjustment) + items con qty firmada.   |
| confirm_inventory_operation | operation id (uuid)     | Valida draft, ítems y warehouses; normaliza signos; marca confirmed. |

Las migraciones SQL de referencia están en `docs/migrations/` (p. ej. `confirm_inventory_adjustment.sql`, `confirm_inventory_credit_use_type_credit.sql`). El equipo debe asegurarse de que estas RPCs existan y estén alineadas con el esquema actual (inventory_operations, inventory_operation_items, vistas on_hand).

---

## 6. Hooks y APIs

### 6.1 Hooks de listado / datos

- **useCatalogItems** — Catálogo de ítems (para selectores y Stock).
- **useInventoryStock** — Stock por ítem (y opcionalmente warehouse/location); escucha `INVENTORY_STOCK_INVALIDATE_EVENT`.
- **useStockBreakdown** — Desglose por almacén/ubicación para un catalog_item; caché 10 s; `invalidateStockBreakdownCache()` lo limpia.
- **useInventoryOperations** — Lista de operations (para Movements).
- **useAdjustments**, **useCredits**, **useReceipts** — Listas de adjustments, credits, receipts con filtros (stage, warehouse, fechas, etc.).
- **usePurchaseOrders** — Lista de PO (usado en Receipts y PurchaseOrderInfo).

### 6.2 APIs (lib)

- **adjustments.api.ts** — getAdjustments, getAdjustmentById, getAdjustmentItems, createAdjustment, updateAdjustment, upsertAdjustmentItem, deleteAdjustmentItem, confirmInventoryAdjustment.
- **credits.api.ts** — getCredits, getCreditById, getCreditItems, createCredit, updateCredit, upsertCreditItem, deleteCreditItem, getReceiptItemQtys, getTotalCreditedForReceipt, confirmCredit.
- **receipts.api.ts** — getReceipts, getReceiptById, getReceiptItems, createReceipt, updateReceipt, upsertReceiptItem, getNextReceiptItemPublicIds, confirmReceipt, etc.
- **Movements:** No hay un `movements.api.ts` dedicado; la lógica de crear/actualizar/confirmar está en `MovementInfo.tsx` usando Supabase directo y `supabase.rpc('confirm_inventory_operation', …)`.

---

## 7. Invalidación de caché y consistencia

Tras cualquier confirmación que afecte al stock, el frontend:

1. Llama a **invalidateStockBreakdownCache()** (para que useStockBreakdown vuelva a cargar).
2. Dispara **dispatchInventoryStockInvalidation()** (para que las vistas que usan useInventoryStock recarguen al escuchar el evento).

Esto se hace en:

- AdjustmentInfo (tras confirm_inventory_adjustment).
- CreditInfo (tras confirmCredit → confirm_inventory_credit).
- ReceiptInfo (tras confirmación de receipt).
- MovementInfo (tras confirm_inventory_operation).

Así se mantiene la coherencia entre documentos confirmados y la vista de Stock sin recargar toda la app.

---

## 8. Consideraciones para el equipo

1. **Una sola fuente de verdad:** El stock se deriva de `inventory_operations` + `inventory_operation_items` y vistas (`inventory_on_hand*`). Cualquier cambio de lógica de stock debe reflejarse en esas vistas o en las RPCs de confirmación.
2. **Draft vs confirmed:** En todas las pantallas Info (Receipt, Credit, Adjustment, Movement) el estado “draft” es editable; “confirmed” es solo lectura y no debe permitir borrar o editar cabecera/líneas.
3. **Movements y tipos ocultos:** La lista Movements filtra receipt/credit/adjustment; si se abre una operation de ese tipo por URL (p. ej. desde un enlace), MovementInfo la muestra en solo lectura con mensaje indicando que ese tipo se gestiona en su módulo.
4. **Credits atados a Receipt:** Un crédito se crea desde un receipt; las cantidades máximas por ítem dependen de lo recibido menos lo ya acreditado para ese mismo receipt.
5. **Ajustes y stock:** AdjustmentInfo valida que las disminuciones no superen el on-hand del almacén (lectura de `inventory_on_hand`).
6. **Unidades:** Se usa `catalog_items.inventory_unit` y `formatInventoryUnit` (lib/inventoryUnits) para mostrar unidades en tablas y formularios.
7. **RLS:** Todas las consultas están acotadas por `company_id`; el equipo debe asegurar que las políticas RLS en Supabase coincidan con este modelo (usuario en `user_contexts` con company_id correcto).

---

## 9. Documentación adicional

- Migraciones SQL de confirmación: `docs/migrations/` (confirm_inventory_adjustment.sql, confirm_inventory_credit_use_type_credit.sql, create_inventory_receipts.sql, add_inventory_receipt_id_to_credits.sql, etc.).
- Esquema relacional: descrito en el contexto del proyecto (tablas inventory_operations, inventory_operation_items, inventory_adjustments, inventory_credits, inventory_receipts, warehouses, catalog_items, jobs, etc.).

Si necesitan profundizar en un submódulo concreto (p. ej. solo Receipts o solo Stock), se puede extraer un informe por submódulo con capturas de flujo y ejemplos de llamadas API/RPC.
