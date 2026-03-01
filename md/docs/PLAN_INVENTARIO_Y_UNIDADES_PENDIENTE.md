# Plan: Inventario y modelo de unidades — pendiente

Plan actualizado restando lo ya hecho. Solo se listan fases y tareas pendientes.

---

## Ya hecho (no repetir)

- **Estabilidad**
  - CSS: `body` con `background-color: hsl(var(--background))`; sin `@apply bg-background` en `global.css`.
  - Tabs: `Layout` llama `clearSubmoduleNav()` cuando cambia el módulo (path); no quedan tabs de otro módulo.
  - HMR: `useSubmoduleNav` solo exporta Provider y hook.
- **Adjustments**
  - Rutas propias: `/inventory/adjustments`, `/inventory/adjustments/new`, `/inventory/adjustments/:id`.
  - `Transactions.tsx` y `TransactionDetail.tsx` usan `newPath`, `detailBasePath`, `listPath` según pathname; tipo fijo "adjustment" en contexto adjustments; "Back" vuelve a la lista correcta.
- **Modelo V2 en BD**
  - Migración `20260301010000`: columnas `purchase_mode`, `stock_basis`, `purchase_uom` en `CatalogItems` y snapshots en `PurchaseOrderLines`; backfill aplicado.
  - `CatalogItemNew`: formulario ya incluye y persiste `purchase_mode`, `stock_basis`, `purchase_uom`.
  - `useCatalog` y `usePurchaseOrders` ya leen/escriben estos campos.

---

## Fase 2 — Modelo de unidades y compra ✅ (hecho)

1. **Snapshots de PO al crear/editar líneas** ✅
   - `PurchaseOrderDetail.tsx` rellena snapshots desde catálogo al añadir/editar líneas; `usePurchaseOrders.ts` persiste `purchase_mode_snapshot`, `stock_basis_snapshot`, `purchase_uom_snapshot` (y roll snapshots) en update e insert.
   - Migración `20260301020000` aplica checks de consistencia y normaliza `purchase_uom_snapshot` en líneas.

2. **UI de compra en CatalogItemNew (lineales y rollos)** ✅
   - Formulario incluye `purchase_mode`, `stock_basis`, `purchase_uom`; `resolveInventoryUnitModel` se usa en useEffect al cambiar `is_roll` / `measure_basis` / `purchase_unit`.

3. **PurchaseOrderDetail y recepción** ✅
   - PO detalle usa snapshots para mostrar cantidades y equivalente en metros (`convertPurchaseQtyToInternal` en UI).
   - RPC `receive_purchase_order` (migración `20260301100000`) convierte por `purchase_mode_snapshot` (roll / linear_direct / unit_packaged) y escribe en `InventoryBalances`/movimientos en la unidad correcta.

---

## Fase 3 — Visibilidad en Warehouse e ítem ✅ (hecho)

1. **Warehouse (lista por ítem/almacén)** ✅
   - `Warehouse.tsx`: `onHandM`, `estimatedRolls`, `m2Reference` calculados cuando `stock_basis === 'linear_m'` y roll_length/width disponibles.

2. **InventoryItemDetail** ✅
   - Misma lógica: `onHandM`, `estimatedRolls`, `m2Reference` según `stock_basis` y datos de rollo.

---

## Fase 4 — QA funcional (pendiente)

1. **Flujos a validar**
   - Tubo lineal: compra en ft, conversión a m, stock en linear_m.
   - Unitario (box/pack): compra en cajas, stock en ea (o según units_per_purchase_unit).
   - Tela en rollo: compra por rollo, roll_length en m, stock en linear_m; m² solo referencia.
2. **Navegación**
   - Inventory → Edit ítem: no deben verse tabs de Warehouse/Inventory.
   - Adjustments: list/new/detail sin redirigir a Transactions; buscador de ítems en New Adjustment estable.

---

## Orden sugerido (estado actual)

- Fases 2 y 3: **hechas**.  
- **Siguiente:** Fase 4 — QA funcional (ver abajo).

Referencia de modelo: `md/docs/INVENTORY_UNIT_MODEL_V2.md` y `src/lib/inventoryUnitModel.ts`.

---

## Próximos pasos para continuar

1. **Fase 4 (Inventario)** — QA funcional:
   - Probar flujos: tubo lineal (compra ft → m), unitario (box/pack → ea), tela en rollo (rollo → linear_m).
   - Revisar navegación: Inventory → Edit ítem sin tabs Warehouse/Inventory; Adjustments list/new/detail estable.

2. **Categories Phase 1** — Si aplica, ejecutar el checklist en `md/docs/CATEGORIES_SUBCATEGORIES_PHASE1_QA_CHECKLIST.md` (contrato BD, UI Categories/Subcategories, ítem con subcategoría, regresiones).
