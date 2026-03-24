-- Consolidate stray permission modules into their proper sidebar module groups.
-- Before: purchasing, quotes, proposals, salesorders, admin, org, reports were separate cards.
-- After: they are grouped under inventory, sales, settings respectively.

UPDATE public."Permissions" SET module = 'inventory' WHERE module = 'purchasing';
UPDATE public."Permissions" SET module = 'sales'     WHERE module IN ('quotes', 'proposals', 'salesorders');
UPDATE public."Permissions" SET module = 'settings'  WHERE module IN ('admin', 'org', 'reports');
