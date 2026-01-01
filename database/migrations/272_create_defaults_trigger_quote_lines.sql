-- ====================================================
-- Migration 272: Create Defaults Trigger for QuoteLines
-- ====================================================
-- BEFORE INSERT/UPDATE trigger to set default tube_type
-- based on operating_system_variant if tube_type is NULL
-- ====================================================

BEGIN;

-- Create trigger function
CREATE OR REPLACE FUNCTION public.set_default_tube_type_for_quote_line()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only apply defaults if tube_type is NULL and operating_system_variant is set
    IF NEW.tube_type IS NULL AND NEW.operating_system_variant IS NOT NULL THEN
        IF NEW.operating_system_variant ILIKE '%standard_m%' OR NEW.operating_system_variant ILIKE '%m%' THEN
            NEW.tube_type := 'RTU-42';
            RAISE NOTICE 'Set default tube_type=RTU-42 for operating_system_variant=%', NEW.operating_system_variant;
        ELSIF NEW.operating_system_variant ILIKE '%standard_l%' OR NEW.operating_system_variant ILIKE '%l%' THEN
            NEW.tube_type := 'RTU-65';
            RAISE NOTICE 'Set default tube_type=RTU-65 for operating_system_variant=%', NEW.operating_system_variant;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS set_default_tube_type_trigger ON public."QuoteLines";

-- Create trigger
CREATE TRIGGER set_default_tube_type_trigger
    BEFORE INSERT OR UPDATE ON public."QuoteLines"
    FOR EACH ROW
    WHEN (NEW.operating_system_variant IS NOT NULL AND NEW.tube_type IS NULL)
    EXECUTE FUNCTION public.set_default_tube_type_for_quote_line();

COMMENT ON FUNCTION public.set_default_tube_type_for_quote_line IS 
    'Sets default tube_type based on operating_system_variant: standard_m -> RTU-42, standard_l -> RTU-65. Only applies if tube_type is NULL.';

COMMIT;


