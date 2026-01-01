-- ====================================================
-- Migration: Fix Side Channel Type Constraint
-- ====================================================
-- Updates the check_side_channel_type_valid constraint to allow
-- 'side_only' and 'side_and_bottom' values instead of 'left', 'right', 'both'
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '🔧 Updating side_channel_type constraint...';
    
    -- Drop existing constraint
    ALTER TABLE public."QuoteLines"
    DROP CONSTRAINT IF EXISTS check_side_channel_type_valid;
    
    -- Add new constraint with correct values
    ALTER TABLE public."QuoteLines"
    ADD CONSTRAINT check_side_channel_type_valid 
    CHECK (
      side_channel_type IS NULL 
      OR side_channel_type IN ('side_only', 'side_and_bottom')
    );
    
    RAISE NOTICE '  ✅ Updated check_side_channel_type_valid constraint';
    RAISE NOTICE '     Allowed values: NULL, side_only, side_and_bottom';
    
    -- Update comment
    COMMENT ON COLUMN public."QuoteLines".side_channel_type IS 
      'Type of side channel when side_channel = true: side_only (2 side profiles × height) or side_and_bottom (2 side profiles × height + 1 bottom profile × width)';
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration completed successfully!';
END $$;









