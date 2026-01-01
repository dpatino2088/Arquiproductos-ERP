-- ====================================================
-- Migration 252: Add Unique Constraint to QuoteLineComponents
-- ====================================================
-- Adds unique constraint for (quote_line_id, catalog_item_id, component_role, source)
-- to support ON CONFLICT in generate_configured_bom_for_quote_line()
-- ====================================================

DO $$
BEGIN
    -- Drop existing constraint if it exists
    DROP INDEX IF EXISTS uq_quote_line_components_quote_item_role_source;
    
    -- Create unique constraint/index
    -- Only enforce uniqueness when deleted = false
    CREATE UNIQUE INDEX uq_quote_line_components_quote_item_role_source
    ON "QuoteLineComponents" (quote_line_id, catalog_item_id, component_role, source)
    WHERE deleted = false;
    
    RAISE NOTICE '✅ Created unique constraint on QuoteLineComponents (quote_line_id, catalog_item_id, component_role, source) WHERE deleted = false';
    
END $$;


