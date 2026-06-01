-- Promueve los end caps de drapery motor (hoy hijos del 'motor') a componentes
-- top-level que deducen el track directamente. Cada end cap ya trae
-- affects_role='track' y su delta del catalogo (Motor endcap 65 / Return endcap 49).
-- Al quedar top-level se vuelven deductores independientes, se ven explicitamente
-- en el BOM (no enterrados dentro del motor) y el diagrama puede repartir izq/der
-- por placement_section en lugar de heuristicas por nombre.
--
--   * Motor endcap  -> placement_section='drive'   (lado del motor)
--   * Return endcap -> placement_section='passive' (extremo contrario)
--
-- Los accesorios sin delta (hooks CC1007/CC1032, carriers CC1011/CC1026) siguen
-- como hijos del motor. El total de deduccion del track NO cambia (65 + 49 = 114).

WITH motor_ids AS (
  SELECT bc.id AS motor_id
  FROM public."BOMComponents" bc
  JOIN public."BOMTemplates" bt ON bt.id = bc.bom_template_id
  JOIN public."ProductTypes" pt ON pt.id = bt.product_type_id
  WHERE pt.code = 'drapery'
    AND bt.drive_type = 'motor'
    AND bt.deleted = false
    AND bc.parent_component_id IS NULL
    AND bc.component_role = 'motor'
    AND bc.deleted = false
    AND bc.archived = false
)
UPDATE public."BOMComponents" child
SET parent_component_id = NULL,
    component_role = 'end_cap',
    affects_role = 'track',
    placement_section = CASE WHEN ci.name ILIKE '%motor%' THEN 'drive' ELSE 'passive' END,
    sort_order = CASE WHEN ci.name ILIKE '%motor%' THEN 21 ELSE 22 END
FROM public."CatalogItems" ci
WHERE child.component_item_id = ci.id
  AND child.parent_component_id IN (SELECT motor_id FROM motor_ids)
  AND child.deleted = false
  AND child.archived = false
  AND ci.item_role = 'end_cap'
  AND COALESCE(ci.delta_x_mm, 0) > 0;

-- El motor ya no es el deductor del track (lo son los end caps). Quitamos su
-- affects_role para evitar una deduccion 'motor' fantasma de 0 y dejar el modelo claro.
UPDATE public."BOMComponents" bc
SET affects_role = NULL
FROM public."BOMTemplates" bt
JOIN public."ProductTypes" pt ON pt.id = bt.product_type_id
WHERE bc.bom_template_id = bt.id
  AND pt.code = 'drapery'
  AND bt.drive_type = 'motor'
  AND bt.deleted = false
  AND bc.parent_component_id IS NULL
  AND bc.component_role = 'motor'
  AND bc.deleted = false
  AND bc.archived = false;
