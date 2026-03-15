-- Add status column to ProductTypes and insert Wood / Roman Shade
-- Honey Comb already exists; all three get status = 'coming_soon'

ALTER TABLE "ProductTypes" ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

-- Ensure existing rows are 'active'
UPDATE "ProductTypes" SET status = 'active' WHERE status IS NULL OR status = '';

-- Set Honey Comb as coming_soon
UPDATE "ProductTypes" SET status = 'coming_soon' WHERE code = 'honey_comb';

-- Wood
INSERT INTO "ProductTypes" (organization_id, code, name, sort_order, status)
SELECT pt.organization_id, 'wood', 'Wood', 90, 'coming_soon'
FROM "ProductTypes" pt
WHERE pt.code = 'roller'  -- borrow same org as first product type
  AND NOT EXISTS (SELECT 1 FROM "ProductTypes" WHERE code = 'wood')
LIMIT 1;

-- Roman Shade
INSERT INTO "ProductTypes" (organization_id, code, name, sort_order, status)
SELECT pt.organization_id, 'roman_shade', 'Roman Shade', 100, 'coming_soon'
FROM "ProductTypes" pt
WHERE pt.code = 'roller'
  AND NOT EXISTS (SELECT 1 FROM "ProductTypes" WHERE code = 'roman_shade')
LIMIT 1;
