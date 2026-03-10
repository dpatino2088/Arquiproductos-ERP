-- Consolidar rol "Glide" en "Glider": reasignar referencias y eliminar el rol Glide.
-- Así puedes eliminar Glide y dejar solo Glider.

BEGIN;

-- 1. CatalogItems: los ítems que tenían rol 'glide' pasan a 'glider'
UPDATE public."CatalogItems"
SET item_role = 'glider'
WHERE item_role = 'glide';

-- 2. BOMComponents: si algún componente usaba component_role 'glide', unificar a 'glider'
UPDATE public."BOMComponents"
SET component_role = 'glider'
WHERE component_role = 'glide';

-- 3. BOMInstanceLines / part_role (por si hubiera datos históricos)
UPDATE public."BOMInstanceLines"
SET part_role = 'glider'
WHERE part_role = 'glide';

-- 4. Eliminar el rol "Glide" de la tabla de roles
DELETE FROM public."CatalogItemRoles"
WHERE role_code = 'glide';

COMMIT;
