-- Normaliza affects_role='track' en el componente motor de los templates drapery
-- motorizados donde estaba en NULL, para que los end caps (return + motor) del
-- catalogo descuenten del track igual que los templates que ya funcionaban.
--
-- Contexto: el track de drapery solo recibe deducciones via affects_role explicito
-- (no entra en el fallback por seccion, que cubre tube/bottom_bar/bottom_channel/
-- side_channel). En 9 de 12 templates motor el componente 'motor' tenia
-- affects_role=NULL, por lo que sus hijos (CC1005/CC1006 return endcap delta_x=49 y
-- CC1019 motor endcap delta_x=65 = 114mm) NO se aplicaban y el track salia con el
-- ancho completo.
--
-- Esta migracion NO modifica ningun delta de catalogo; solo conecta el deductor al
-- rol 'track'.

UPDATE public."BOMComponents" bc
SET affects_role = 'track'
FROM public."BOMTemplates" bt
JOIN public."ProductTypes" pt ON pt.id = bt.product_type_id
WHERE bc.bom_template_id = bt.id
  AND pt.code = 'drapery'
  AND bt.drive_type = 'motor'
  AND bt.deleted = false
  AND bc.component_role = 'motor'
  AND bc.parent_component_id IS NULL
  AND bc.deleted = false
  AND bc.archived = false
  AND COALESCE(bc.affects_role, '') <> 'track';
