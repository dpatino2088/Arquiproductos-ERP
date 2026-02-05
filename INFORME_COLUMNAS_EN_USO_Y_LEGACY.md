# Informe: Columnas en uso vs Legacy (DUMP v8)

Fuente: `backups/2026-02_02_v8_full.sql` y búsqueda en `src/` y `database/migrations/`.  
Objetivo: identificar qué columnas se usan en el flujo actual (ConfiguredProducts → QuoteLines → BOM) y cuáles son legacy o sin uso.

---

## 1) ConfiguredProducts

| Columna | En uso | Dónde | Notas |
|--------|--------|-------|--------|
| **id** | ✅ | PK, RPC, frontend | |
| **organization_id** | ✅ | RPC, RLS, frontend | |
| **quote_id** | ✅ | RPC insert/read, commit flow | Opcional (puede ser NULL hasta commit) |
| **bom_template_id** | ✅ | RPC, create_configured_product_and_bom_preview, commit | Requerido para commit |
| **product_type_id** | ✅ | RPC, configurator, commit | |
| **width_mm**, **height_mm** | ✅ | RPC, configurator, commit (→ width_m, height_m en QuoteLine) | |
| **quantity** | ✅ | RPC, configurator, commit | |
| **hardware_color** | ✅ | RPC, HardwareStep, template matching | |
| **config_snapshot** | ✅ | RPC insert (origen de todos los mirror), frontend | Fuente de verdad de la configuración |
| **roll_catalog_item_id** | ✅ | RPC, create_configured_product_and_bom_preview, commit (→ catalog_item_id en QuoteLine) | |
| **roll_sku** | ✅ | RPC insert, commit (lee desde CatalogItems si no) | Mirror; también se puede derivar de roll_catalog_item_id |
| **roll_collection_name**, **roll_variant_name** | ✅ | RPC insert, commit (snapshot a QuoteLine) | Mirror |
| **roll_width** | ✅ | RPC, commit (roll_width_m en QuoteLine) | |
| **bottom_bar_item_id**, **bottom_bar_sku** | ✅ | RPC insert desde config_snapshot, tipo TS | Mirror de config |
| **headbox_***, **side_channel_***, **bottom_channel_*** | ✅ | Idem | Mirror de config |
| **motor_item_id**, **motor_sku**, **drive_item_id**, **drive_sku**, **tube_item_id**, **tube_sku** | ✅ | RPC insert, OperatingSystemStep, commit (drive_type) | Mirror de config |
| **operating_type** | ✅ | RPC, commit (→ drive_type en QuoteLine) | |
| **roll_msrp_total**, **bom_total**, **roll_plus_bom_total** | ✅ | calculate_configured_product_totals (UPDATE), frontend, commit | Totales MSRP |
| **accessories_total**, **labor_pct**, **labor_amount**, **total_msrp** | ✅ | calculate_configured_product_totals, commit, tipos | |
| **roll_total_cost**, **bom_total_cost** | ✅ | calculate_configured_product_totals, commit | Totales cost |
| **created_at**, **updated_at**, **deleted** | ✅ | Auditoría, RLS, soft delete | |
| **metadata** | ⚠️ Legacy / bajo uso | Solo en tipo TS y filtrado en createQuoteLineFromConfiguredProduct (se excluye del insert) | El RPC **no** escribe `metadata`; default `{}` en DB. Puede considerarse legacy o reserva. |

**Resumen ConfiguredProducts:** Casi todas las columnas están en uso. La única claramente “de sobra” o solo reserva es **metadata** (no la escribe el flujo actual; el frontend la excluye al armar payloads).

---

## 2) QuoteLines

| Columna | En uso | Dónde | Notas |
|--------|--------|-------|--------|
| **id**, **organization_id**, **quote_id**, **company_id** | ✅ | Siempre | |
| **product_type_id**, **product_type** | ✅ | Commit RPC, listados, filtros | |
| **configured_product_id** | ✅ | Commit flow, trigger (skip BOM si está presente) | |
| **bom_template_id** | ✅ | Commit, BOM generation, listados | |
| **catalog_item_id** (roll/fabric) | ✅ | Commit (desde ConfiguredProduct.roll_catalog_item_id), fallback legacy | |
| **sku**, **name**, **manufacturer_id**, **manufacturer** | ✅ | Commit (desde CatalogItems/CP), UI | |
| **collection_name**, **variant_name** | ✅ | Commit (desde CP o CatalogItems), UI | |
| **roll_width_m** | ✅ | Commit, pricing | |
| **width_m**, **height_m**, **quantity** | ✅ | Commit, mediciones, pricing | |
| **hardware_color**, **drive_type** | ✅ | Commit, BOM/configurator | |
| **position**, **area** | ✅ | Commit, UI | |
| **roll_cost_snapshot**, **bom_cost_snapshot**, **roll_msrp_snapshot**, **bom_msrp_snapshot** | ✅ | Commit, useQuotes, totales | |
| **total_cost**, **msrp**, **net_price** | ✅ | Commit, listados, totales | |
| **pricing_locked**, **last_priced_at**, **pricing_version** | ✅ | Commit, repricing | |
| **collection_id**, **variant_id** | ⚠️ Legacy / riesgo | Tipo UUID en DB; el commit RPC **no** los escribe (evita SKU→UUID). Casi no se leen en frontend. | **Legacy**: si en algún flujo antiguo se rellenaban con IDs; ahora se evita. Podrían deprecarse o usarse solo cuando haya UUID real. |
| **pricing_basis**, **unit_of_measure** | ⚠️ Bajo uso | Aparecen en tipos/pricing; no los escribe el commit RPC. | Legacy para líneas “no configuradas” o pricing antiguo. |
| **is_roll**, **roll_type** | ✅ | Commit (derivado de roll_catalog_item_id) | |
| **fabric_pricing_mode**, **drop_m**, **sqm** | ⚠️ Bajo uso | Catalog/pricing; no los escribe el commit RPC. | Legacy para flujos por rollo/fabric antiguos. |
| **cost_exw**, **labor_pct**, **shipping_pct**, **import_tax_pct**, **default_margin_pct**, **minimum_margin_pct**, **discount_pct** | ⚠️ Parcial | useQuotes / QuoteLineCostsSection / repricing; no todos los escribe commit. | Algunas son de flujo “reprice” o legacy. |
| **material_cost**, **labor_cost**, **shipping_cost**, **import_tax_cost**, **applied_margin_pct** | ⚠️ Bajo uso en commit | Cost engine / UI de costes; no los escribe commit. | Legacy o flujo de “reprice”/cost breakdown. |
| **cassette**, **side_channel** | ✅ | UI, BOM (block_condition); commit no los escribe explícitamente | Se pueden derivar de config_snapshot si se quisiera. |

**Resumen QuoteLines:** En uso activo: IDs, snapshots de precio (roll_*, bom_*, total_cost, msrp), medidas, hardware_color, drive_type, position, area, catalog_item_id, sku, name, collection_name, variant_name. **Legacy o bajo uso:** collection_id, variant_id (UUID que causaban error con SKU), y varias columnas de pricing detallado (cost_exw, margin_pct, material_cost, etc.) que usa el cost engine o flujos antiguos pero no el commit desde ConfiguredProducts.

---

## 3) BOMTemplates

| Columna | En uso | Dónde | Notas |
|--------|--------|-------|--------|
| **id**, **organization_id**, **product_type_id** | ✅ | Filtrado, commit, BOM generation | |
| **code**, **name** | ✅ | UI, listados | |
| **is_active**, **archived**, **deleted** | ✅ | Filtros en hooks y RPC | |
| **hardware_color** | ✅ | useBOMTemplateOptionsSimple, createConfiguredProductPreview, matching | Clave para “2 templates” (filtrar por color exacto). |
| **sort_order** | ✅ | UI ordenación | |
| **description**, **metadata** | ⚠️ Bajo uso | Comentarios en DB; metadata en migraciones/reglas. | Opcionales; pueden considerarse extensión, no legacy. |

**Resumen BOMTemplates:** Todo lo esencial está en uso. description/metadata son opcionales.

---

## 4) BOMComponents

| Columna | En uso | Dónde | Notas |
|--------|--------|-------|--------|
| **id**, **organization_id**, **bom_template_id** | ✅ | generate_bom, hooks, BOMInstanceLines (bom_component_id) | |
| **component_item_id**, **component_role** | ✅ | Filtrado por rol, resolución SKU, BOMInstanceLines | |
| **parent_component_id** | ✅ | Padres/hijos, generate_bom_from_slots, BOMInstanceLinesOrdered | |
| **qty_type**, **qty_value**, **uom** | ✅ | Cálculo de cantidades y UOM en BOM | |
| **auto_select**, **component_mode** | ✅ | Resolución automática de SKU (color, rol) | |
| **sort_order** | ✅ | Orden en listados/vistas | |
| **deleted**, **archived** | ✅ | Filtros | |
| **slot_id** | ✅ | useBOMTemplateSlots, relación con BOMTemplateSlots | |
| **depends_on_role**, **cut_axis**, **cut_delta_mm**, **qty_delta_mm** | ✅ | Migraciones (engineering rules, fórmulas de corte/cantidad) | Usados en lógica de generación BOM. |
| **waste_pct**, **sku_resolution_rule** | ✅ | Migraciones (costes, resolución por color/rol) | |
| **component_scope**, **component_sub_role**, **type_per_unit** | ⚠️ Bajo uso en frontend | DB y algunas migraciones; frontend usa sobre todo component_role. | Más bien “extensión” que legacy. |
| **qty_spacing_mm**, **qty_min** | ⚠️ Bajo uso | Migraciones puntuales. | Opcionales. |
| **metadata** | ⚠️ Bajo uso | Comentario en DB. | Reserva. |

**Resumen BOMComponents:** La mayoría de columnas se usan en generación BOM o en migraciones. Las menos referenciadas en frontend son component_scope, component_sub_role, type_per_unit, qty_spacing_mm, qty_min, metadata (pero no son “legacy” sin uso en DB).

---

## 5) BOMInstances

Todas las columnas están en uso: **id**, **organization_id**, **quote_line_id**, **bom_template_id**, **configured_product_id**, **deleted**, **archived**, **created_at**, **updated_at** (commit RPC, triggers, manufacturing, listados).

---

## 6) BOMInstanceLines

| Columna | En uso | Dónde | Notas |
|--------|--------|-------|--------|
| **id**, **bom_instance_id**, **organization_id** | ✅ | Siempre | |
| **bom_component_id**, **resolved_part_id**, **part_role** | ✅ | generate_bom, MaterialsTab, CutListTab, costes | |
| **qty**, **uom** | ✅ | Cálculo, manufacturing, cortes | |
| **cut_length_mm**, **cut_width_mm**, **cut_height_mm** | ✅ | Migraciones, CutListTab, engineering rules | |
| **unit_cost_exw**, **total_cost_exw** | ✅ | Cost engine, MaterialsTab, ApprovedBOMList | |
| **deleted**, **archived** | ✅ | Filtros | |

**Resumen BOMInstanceLines:** Todo en uso.

---

## 7) BOMTemplateSlots

Usado en **useBOMTemplateSlots**, **BOMTemplates** UI y en lógica de generación (slots por rol). Columnas: **item_role**, **required**, **catalog_item_id**, **fixed_catalog_item_id**, **selection_mode**, **qty**, **slot_sku**, **notes**, **deleted**, **archived**. No se ha detectado como legacy; es parte del modelo “template + slots” junto a BOMComponents.

---

## 8) QuoteLineBOMSelections

Tabla **legacy** para persistir selecciones de componentes por quote_line (motor, drive, tube, etc.) cuando el flujo era “editar línea y elegir SKUs”.  
En el flujo actual **ConfiguredProducts → commit_configured_product_to_quote_line** no se usa: la configuración va en **ConfiguredProducts.config_snapshot** y en **QuoteLine** como snapshot; el BOM se genera desde **create_bom_instance_for_configured_product**.  
Sigue referenciada en **bomSelections.ts** y en algunos puntos de QuoteNew; conviene considerar deprecación o uso solo para flujos “edit line without configurator”.

---

## 9) QuoteLineComponents

**En uso**: guarda opciones y selecciones por línea (fabric, accessories, kind='option'/'selection'). Usado en **QuoteNew** (guardar accesorios, fabric), **useQuotes** (leer componentes), **createQuoteLineFromRollerConfig**, **OrderList** (comprobar si hay componentes antes de BOM).  
Complementa a ConfiguredProducts en flujos donde la línea se edita después de creada (accesorios, reemplazos). No es legacy; es tabla activa junto al flujo configurador.

---

## 10) Resumen ejecutivo

- **ConfiguredProducts:** En uso casi todo. Solo **metadata** está sin escribir por el RPC y se puede tratar como reserva/legacy.
- **QuoteLines:** **Legacy o riesgo:** **collection_id**, **variant_id** (no rellenados por commit para evitar SKU→UUID). **Legacy/bajo uso:** varias columnas de pricing detallado (cost_exw, margin_*, material_cost, labor_cost, etc.) que usa el cost engine o flujos antiguos pero no el commit desde ConfiguredProducts.
- **BOM (Templates, Components, Instances, InstanceLines):** Casi todo en uso; algunas columnas de BOMComponents (component_scope, component_sub_role, qty_spacing_mm, qty_min, metadata) son opcionales o de extensión.
- **QuoteLineBOMSelections:** Legacy para el flujo “configurator → commit”; solo relevante si se mantiene edición manual de BOM por línea.
- **QuoteLineComponents:** En uso; no legacy.

Recomendación: documentar **collection_id** y **variant_id** en QuoteLines como “no usar con valores no-UUID” o deprecarlos si no hay planes de rellenarlos desde CatalogItems con UUID real; y tratar **metadata** en ConfiguredProducts como opcional/reserva si no se va a usar.
