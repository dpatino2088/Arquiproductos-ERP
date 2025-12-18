-- ====================================================
-- Migration: Create calculate_quote_totals Function
-- ====================================================
-- Calculates and updates Quote totals (subtotal, discount_total, tax, total)
-- Automatically triggered when QuoteLines change
-- ====================================================

CREATE OR REPLACE FUNCTION public.calculate_quote_totals(
    p_quote_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_subtotal numeric(12,4) := 0;
    v_discount_total numeric(12,4) := 0;
    v_tax numeric(12,4) := 0;
    v_total numeric(12,4) := 0;
    v_quote_record RECORD;
BEGIN
    -- Step 1: Verify Quote exists
    SELECT 
        id,
        organization_id,
        currency
    INTO v_quote_record
    FROM "Quotes"
    WHERE id = p_quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'Quote % not found or deleted', p_quote_id;
        RETURN p_quote_id;
    END IF;
    
    -- Step 2: Calculate subtotal (sum of all line_total from QuoteLines)
    SELECT 
        COALESCE(SUM(line_total), 0)
    INTO v_subtotal
    FROM "QuoteLines"
    WHERE quote_id = p_quote_id
    AND deleted = false;
    
    -- Step 3: Calculate discount_total (sum of all discount_amount from QuoteLines)
    SELECT 
        COALESCE(SUM(discount_amount), 0)
    INTO v_discount_total
    FROM "QuoteLines"
    WHERE quote_id = p_quote_id
    AND deleted = false;
    
    -- Step 4: Calculate tax (for now, set to 0 - can be extended later)
    -- TODO: Add tax calculation logic if needed (e.g., based on QuoteLineCosts.import_tax_cost)
    v_tax := 0;
    
    -- Step 5: Calculate total = subtotal - discount_total + tax
    v_total := v_subtotal - v_discount_total + v_tax;
    
    -- Ensure total is not negative
    IF v_total < 0 THEN
        v_total := 0;
    END IF;
    
    -- Step 6: Update Quote totals
    UPDATE "Quotes"
    SET 
        totals = jsonb_build_object(
            'subtotal', v_subtotal,
            'discount_total', v_discount_total,
            'tax', v_tax,
            'total', v_total
        ),
        updated_at = now()
    WHERE id = p_quote_id;
    
    RETURN p_quote_id;
END;
$$;

-- ====================================================
-- Create Trigger Function
-- ====================================================

-- Create trigger function first
CREATE OR REPLACE FUNCTION public.calculate_quote_totals_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_id uuid;
BEGIN
    -- Determine quote_id based on operation
    IF TG_OP = 'DELETE' THEN
        v_quote_id := OLD.quote_id;
    ELSE
        v_quote_id := NEW.quote_id;
    END IF;
    
    -- Only recalculate if quote_id is not null
    IF v_quote_id IS NOT NULL THEN
        PERFORM public.calculate_quote_totals(v_quote_id);
    END IF;
    
    -- Return appropriate record
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- ====================================================
-- Create Trigger to Auto-Calculate Totals
-- ====================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_recalculate_quote_totals ON "QuoteLines";

-- Create trigger that calls calculate_quote_totals when QuoteLines change
CREATE TRIGGER trg_recalculate_quote_totals
    AFTER INSERT OR UPDATE OR DELETE ON "QuoteLines"
    FOR EACH ROW
    EXECUTE FUNCTION public.calculate_quote_totals_trigger();

-- ====================================================
-- Add comment
-- ====================================================

COMMENT ON FUNCTION public.calculate_quote_totals(uuid) IS 
'Calculates and updates Quote totals (subtotal, discount_total, tax, total) based on QuoteLines';

COMMENT ON FUNCTION public.calculate_quote_totals_trigger() IS 
'Trigger function that automatically recalculates Quote totals when QuoteLines change';

