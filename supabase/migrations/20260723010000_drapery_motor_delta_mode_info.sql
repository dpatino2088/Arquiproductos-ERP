-- Drapery curtain motors have no cut delta; they must stay visible as
-- informative hardware while Motor Mounting / motor endcaps (end_cap on
-- placement=drive) remain the subtractors on the track.
--
-- Rule: catalog delta X/Y both null/0 + role=motor → delta_mode=info.

BEGIN;

UPDATE public."BOMComponents" bc
   SET delta_mode = 'info',
       updated_at = now()
  FROM public."CatalogItems" ci
 WHERE bc.component_item_id = ci.id
   AND bc.deleted = false
   AND bc.archived = false
   AND bc.component_role = 'motor'
   AND bc.delta_mode IS DISTINCT FROM 'info'
   AND (ci.delta_x_mm IS NULL OR ci.delta_x_mm = 0)
   AND (ci.delta_y_mm IS NULL OR ci.delta_y_mm = 0);

COMMIT;
