
-- Soft-delete duplicate MOs for SO-00102 (keep only MO-000004, the latest)
UPDATE "ManufacturingOrders" 
SET deleted = true, updated_at = now()
WHERE id IN ('ee325a0a-671a-4ddd-a2c1-6c894f72996f', '5c292cc8-d019-447d-9688-2d58f135d5bd')
AND deleted = false;
;
