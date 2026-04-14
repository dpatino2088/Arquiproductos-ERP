-- Consolidar rol Glide en Glider
UPDATE public."CatalogItems" SET item_role = 'glider' WHERE item_role = 'glide';
UPDATE public."BOMComponents" SET component_role = 'glider' WHERE component_role = 'glide';
UPDATE public."BOMInstanceLines" SET part_role = 'glider' WHERE part_role = 'glide';
DELETE FROM public."CatalogItemRoles" WHERE role_code = 'glide';;
