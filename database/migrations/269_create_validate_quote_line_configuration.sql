-- ====================================================
-- Migration 269: Create validate_quote_line_configuration Function
-- ====================================================
-- Validates QuoteLine configuration fields and checks
-- MotorTubeCompatibility for capacity rules
-- ====================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.validate_quote_line_configuration(
    p_quote_line_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line RECORD;
    v_product_type RECORD;
    v_errors text[] := ARRAY[]::text[];
    v_warnings text[] := ARRAY[]::text[];
    v_compatibility RECORD;
    v_width_mm numeric;
    v_height_mm numeric;
    v_area_m2 numeric;
BEGIN
    -- Load QuoteLine
    SELECT 
        ql.id,
        ql.organization_id,
        ql.product_type_id,
        ql.operating_system_variant,
        ql.tube_type,
        ql.width_m,
        ql.height_m,
        ql.width_mm,
        ql.height_mm,
        pt.code as product_type_code,
        pt.name as product_type_name
    INTO v_quote_line
    FROM "QuoteLines" ql
    LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'errors', ARRAY['QuoteLine not found or deleted'],
            'warnings', ARRAY[]::text[]
        );
    END IF;
    
    -- Validation 1: operating_system_variant required for Roller Shade
    IF v_quote_line.product_type_code = 'ROLLER' OR v_quote_line.product_type_name ILIKE '%roller%shade%' THEN
        IF v_quote_line.operating_system_variant IS NULL OR v_quote_line.operating_system_variant = '' THEN
            v_errors := v_errors || ARRAY['operating_system_variant is required for Roller Shade'];
        END IF;
    END IF;
    
    -- Validation 2: tube_type required for Roller Shade
    IF v_quote_line.product_type_code = 'ROLLER' OR v_quote_line.product_type_name ILIKE '%roller%shade%' THEN
        IF v_quote_line.tube_type IS NULL OR v_quote_line.tube_type = '' THEN
            v_errors := v_errors || ARRAY['tube_type is required for Roller Shade'];
        END IF;
    END IF;
    
    -- Validation 3: Check MotorTubeCompatibility
    IF v_quote_line.operating_system_variant IS NOT NULL 
       AND v_quote_line.tube_type IS NOT NULL 
       AND v_quote_line.product_type_id IS NOT NULL THEN
        
        SELECT * INTO v_compatibility
        FROM "MotorTubeCompatibility"
        WHERE product_type_id = v_quote_line.product_type_id
            AND operating_system_variant = v_quote_line.operating_system_variant
            AND tube_type = v_quote_line.tube_type
            AND (organization_id = v_quote_line.organization_id OR organization_id IS NULL)
            AND deleted = false
            AND active = true
        ORDER BY 
            CASE WHEN organization_id IS NOT NULL THEN 0 ELSE 1 END
        LIMIT 1;
        
        IF NOT FOUND THEN
            v_errors := v_errors || ARRAY[format(
                'Tube type %s is not compatible with operating system variant %s for product type %s',
                v_quote_line.tube_type,
                v_quote_line.operating_system_variant,
                v_quote_line.product_type_name
            )];
        ELSE
            -- Validation 4: Check capacity limits if dimensions exist
            v_width_mm := COALESCE(v_quote_line.width_mm, v_quote_line.width_m * 1000);
            v_height_mm := COALESCE(v_quote_line.height_mm, v_quote_line.height_m * 1000);
            v_area_m2 := COALESCE(v_quote_line.width_m * v_quote_line.height_m, NULL);
            
            IF v_width_mm IS NOT NULL AND v_compatibility.max_width_mm IS NOT NULL THEN
                IF v_width_mm > v_compatibility.max_width_mm THEN
                    v_errors := v_errors || ARRAY[format(
                        'Width %.2f mm exceeds maximum capacity %.2f mm for tube %s with operating system %s',
                        v_width_mm,
                        v_compatibility.max_width_mm,
                        v_quote_line.tube_type,
                        v_quote_line.operating_system_variant
                    )];
                END IF;
            END IF;
            
            IF v_height_mm IS NOT NULL AND v_compatibility.max_drop_mm IS NOT NULL THEN
                IF v_height_mm > v_compatibility.max_drop_mm THEN
                    v_errors := v_errors || ARRAY[format(
                        'Height %.2f mm exceeds maximum capacity %.2f mm for tube %s with operating system %s',
                        v_height_mm,
                        v_compatibility.max_drop_mm,
                        v_quote_line.tube_type,
                        v_quote_line.operating_system_variant
                    )];
                END IF;
            END IF;
            
            IF v_area_m2 IS NOT NULL AND v_compatibility.max_area_m2 IS NOT NULL THEN
                IF v_area_m2 > v_compatibility.max_area_m2 THEN
                    v_errors := v_errors || ARRAY[format(
                        'Area %.2f m² exceeds maximum capacity %.2f m² for tube %s with operating system %s',
                        v_area_m2,
                        v_compatibility.max_area_m2,
                        v_quote_line.tube_type,
                        v_quote_line.operating_system_variant
                    )];
                END IF;
            END IF;
        END IF;
    END IF;
    
    -- Return result
    RETURN jsonb_build_object(
        'ok', array_length(v_errors, 1) IS NULL,
        'errors', v_errors,
        'warnings', v_warnings
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'ok', false,
            'errors', ARRAY[format('Validation error: %s', SQLERRM)],
            'warnings', ARRAY[]::text[]
        );
END;
$$;

COMMENT ON FUNCTION public.validate_quote_line_configuration IS 
    'Validates QuoteLine configuration fields and checks MotorTubeCompatibility for capacity rules. Returns JSONB with ok, errors, and warnings arrays.';

COMMIT;


