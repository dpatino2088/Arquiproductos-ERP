-- Drop empty legacy staging tables left over from one-off CSV imports.
-- Both tables were verified empty before removal.
-- They are NOT referenced by application code (only by historical migrations
-- in database/migrations/*). If a future bulk import is needed, recreate via
-- a fresh migration following the OrganizationAddresses pattern.

DROP TABLE IF EXISTS public._stg_catalog_items;
DROP TABLE IF EXISTS public._stg_catalog_update;

NOTIFY pgrst, 'reload schema';
