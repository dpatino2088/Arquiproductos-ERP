-- ====================================================
-- Migration: Normalizar affects_role para evitar typos
-- ====================================================
-- Esta migración normaliza affects_role para evitar variantes
-- como "tube" vs "tubes", "bracket" vs "brackets"
-- ====================================================
-- NOTA: No urgente. La implementación actual funciona correctamente.
-- Esta migración mejora la robustez pero no es crítica.
-- ====================================================

-- STEP 1: Crear función de normalización de component roles
CREATE OR REPLACE FUNCTION normalize_component_role(p_role text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_role IS NULL THEN
    RETURN NULL;
  END IF;

  -- Normalizar a lowercase y trim
  p_role := lower(trim(p_role));

  -- Si después del trim queda vacío, retornar NULL
  IF p_role = '' THEN
    RETURN NULL;
  END IF;

  -- Mapear variantes comunes a valores canónicos
  -- Esto previene typos como "tubes" vs "tube", "brackets" vs "bracket"
  RETURN CASE p_role
    -- Tube variantes
    WHEN 'tubes' THEN 'tube'
    WHEN 'tubing' THEN 'tube'
    
    -- Bracket variantes
    WHEN 'brackets' THEN 'bracket'
    
    -- Fabric variantes
    WHEN 'fabrics' THEN 'fabric'
    WHEN 'fabric_panels' THEN 'fabric_panel'
    WHEN 'fabricpanel' THEN 'fabric_panel'
    
    -- Rail variantes
    WHEN 'rails' THEN 'rail'
    
    -- Channel variantes
    WHEN 'channels' THEN 'channel'
    
    -- Hardware variantes
    WHEN 'hardwares' THEN 'hardware'
    
    -- Motor/Drive variantes
    WHEN 'motors' THEN 'motor'
    WHEN 'drives' THEN 'drive'
    
    -- Cassette variantes
    WHEN 'cassettes' THEN 'cassette'
    
    -- Side channel variantes
    WHEN 'side_channels' THEN 'side_channel'
    WHEN 'sidechannel' THEN 'side_channel'
    
    -- Bottom rail/channel variantes
    WHEN 'bottom_rails' THEN 'bottom_rail'
    WHEN 'bottom_channels' THEN 'bottom_channel'
    WHEN 'bottomrail' THEN 'bottom_rail'
    WHEN 'bottomchannel' THEN 'bottom_channel'
    
    -- Si no es una variante conocida, retornar el valor normalizado
    ELSE p_role
  END;
END;
$$;

COMMENT ON FUNCTION normalize_component_role IS 
    'Normaliza component roles a valores canónicos. Mapea variantes comunes (tubes→tube, brackets→bracket) para evitar typos.';

-- STEP 2: Crear trigger para normalizar affects_role automáticamente
CREATE OR REPLACE FUNCTION normalize_affects_role_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.affects_role IS NOT NULL THEN
    NEW.affects_role := normalize_component_role(NEW.affects_role);
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION normalize_affects_role_trigger IS 
    'Trigger que normaliza affects_role antes de insertar/actualizar en BOMComponents. Previene typos automáticamente.';

-- Crear trigger
DROP TRIGGER IF EXISTS trg_normalize_affects_role ON "BOMComponents";

CREATE TRIGGER trg_normalize_affects_role
BEFORE INSERT OR UPDATE ON "BOMComponents"
FOR EACH ROW
EXECUTE FUNCTION normalize_affects_role_trigger();

COMMENT ON TRIGGER trg_normalize_affects_role ON "BOMComponents" IS 
    'Normaliza affects_role automáticamente para evitar variantes como "tubes" vs "tube".';

-- STEP 3: Actualizar función apply_engineering_rules_to_bom_instance para usar normalización
-- Esto hace las comparaciones más robustas
CREATE OR REPLACE FUNCTION public.apply_engineering_rules_to_bom_instance(
    p_bom_instance_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_bom_instance RECORD;
    v_sale_order_line RECORD;
    v_target_line RECORD;
    v_rule_line RECORD;
    v_base_length_mm numeric;
    v_base_width_mm numeric;
    v_base_height_mm numeric;
    v_cut_length_mm numeric;
    v_cut_width_mm numeric;
    v_cut_height_mm numeric;
    v_length_delta numeric;
    v_width_delta numeric;
    v_height_delta numeric;
    v_calc_notes text;
    v_rule_applied boolean;
    v_quote_line RECORD;
    v_width_m numeric;
    v_height_m numeric;
    v_normalized_target_role text;
    v_normalized_affects_role text;
BEGIN
    -- Get BOM instance details
    SELECT * INTO v_bom_instance
    FROM "BomInstances"
    WHERE id = p_bom_instance_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'BomInstance % not found', p_bom_instance_id;
        RETURN;
    END IF;
    
    -- Get SaleOrderLine to access quote dimensions
    SELECT * INTO v_sale_order_line
    FROM "SalesOrderLines"
    WHERE id = v_bom_instance.sale_order_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'SaleOrderLine % not found for BomInstance %', v_bom_instance.sale_order_line_id, p_bom_instance_id;
        RETURN;
    END IF;
    
    -- Get QuoteLine for dimensions (width_m, height_m)
    SELECT * INTO v_quote_line
    FROM "QuoteLines"
    WHERE id = v_sale_order_line.quote_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'QuoteLine % not found for SaleOrderLine %', v_sale_order_line.quote_line_id, v_sale_order_line.id;
        RETURN;
    END IF;
    
    -- Extract dimensions from QuoteLine (convert meters to mm)
    v_width_m := COALESCE(v_quote_line.width_m, 0);
    v_height_m := COALESCE(v_quote_line.height_m, 0);
    
    -- Process each BomInstanceLine that might be affected by engineering rules
    FOR v_target_line IN
        SELECT bil.*
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = p_bom_instance_id
        AND bil.deleted = false
        AND bil.part_role IS NOT NULL
    LOOP
        -- Normalize target role for consistent comparison
        v_normalized_target_role := normalize_component_role(v_target_line.part_role);
        
        -- Initialize base dimensions based on role
        v_base_length_mm := NULL;
        v_base_width_mm := NULL;
        v_base_height_mm := NULL;
        
        -- Determine base dimensions based on normalized role
        IF v_normalized_target_role = 'tube' THEN
            -- Tube length is typically the width of the curtain
            v_base_length_mm := COALESCE(v_width_m * 1000, 0);
            v_base_height_mm := COALESCE(v_height_m * 1000, 0);
        ELSIF v_normalized_target_role IN ('fabric', 'fabric_panel') THEN
            -- Fabric dimensions depend on area calculation
            v_base_width_mm := COALESCE(v_width_m * 1000, 0);
            v_base_height_mm := COALESCE(v_height_m * 1000, 0);
        ELSIF v_normalized_target_role = 'bracket' THEN
            -- Brackets are typically fixed size, no base dimension from quote
            v_base_length_mm := NULL;
        END IF;
        
        -- Initialize cut dimensions with base values
        v_cut_length_mm := v_base_length_mm;
        v_cut_width_mm := v_base_width_mm;
        v_cut_height_mm := v_base_height_mm;
        
        -- Reset deltas and notes
        v_length_delta := 0;
        v_width_delta := 0;
        v_height_delta := 0;
        v_calc_notes := '';
        v_rule_applied := false;
        
        -- Find all source components that affect this target role and accumulate deltas per axis
        FOR v_rule_line IN
            SELECT 
                bil.part_role as source_role,
                bc.affects_role,
                bc.cut_axis,
                bc.cut_delta_mm,
                bc.cut_delta_scope,
                bil.qty
            FROM "BomInstanceLines" bil
            INNER JOIN "QuoteLineComponents" qlc ON qlc.id = bil.quote_line_component_id
            INNER JOIN "BOMComponents" bc ON bc.id = qlc.bom_component_id
            WHERE bil.bom_instance_id = p_bom_instance_id
            AND bil.deleted = false
            AND bc.affects_role IS NOT NULL
            AND bc.cut_axis IS NOT NULL
            AND bc.cut_delta_mm IS NOT NULL
        LOOP
            -- Normalize affects_role for comparison (FIX: usar v_rule_line, no bc)
            v_normalized_affects_role := normalize_component_role(v_rule_line.affects_role);
            
            -- Check if this rule affects the target role (using normalized values)
            IF v_normalized_affects_role IS NULL OR v_normalized_affects_role != v_normalized_target_role THEN
                CONTINUE; -- Skip this rule, it doesn't affect the target
            END IF;
            
            v_rule_applied := true;
            
            -- Accumulate deltas per axis based on scope
            IF v_rule_line.cut_axis = 'length' THEN
                IF v_rule_line.cut_delta_scope = 'per_item' THEN
                    v_length_delta := v_length_delta + (v_rule_line.cut_delta_mm * COALESCE(v_rule_line.qty, 1));
                ELSIF v_rule_line.cut_delta_scope = 'per_side' THEN
                    v_length_delta := v_length_delta + (2 * v_rule_line.cut_delta_mm);
                END IF;
            ELSIF v_rule_line.cut_axis = 'width' THEN
                IF v_rule_line.cut_delta_scope = 'per_item' THEN
                    v_width_delta := v_width_delta + (v_rule_line.cut_delta_mm * COALESCE(v_rule_line.qty, 1));
                ELSIF v_rule_line.cut_delta_scope = 'per_side' THEN
                    v_width_delta := v_width_delta + (2 * v_rule_line.cut_delta_mm);
                END IF;
            ELSIF v_rule_line.cut_axis = 'height' THEN
                IF v_rule_line.cut_delta_scope = 'per_item' THEN
                    v_height_delta := v_height_delta + (v_rule_line.cut_delta_mm * COALESCE(v_rule_line.qty, 1));
                ELSIF v_rule_line.cut_delta_scope = 'per_side' THEN
                    v_height_delta := v_height_delta + (2 * v_rule_line.cut_delta_mm);
                END IF;
            END IF;
            
            -- Build calc_notes
            IF v_calc_notes != '' THEN
                v_calc_notes := v_calc_notes || '; ';
            END IF;
            v_calc_notes := v_calc_notes || format('%s (%s) affects %s %s: %s mm (%s)',
                v_rule_line.source_role,
                COALESCE(v_rule_line.qty::text, '1'),
                v_target_line.part_role,
                v_rule_line.cut_axis,
                v_rule_line.cut_delta_mm::text,
                v_rule_line.cut_delta_scope
            );
        END LOOP;
        
        -- Apply deltas to cut dimensions
        IF v_rule_applied THEN
            -- Apply to the appropriate axes
            IF v_length_delta != 0 AND v_cut_length_mm IS NOT NULL THEN
                v_cut_length_mm := v_cut_length_mm + v_length_delta;
            END IF;
            IF v_width_delta != 0 AND v_cut_width_mm IS NOT NULL THEN
                v_cut_width_mm := v_cut_width_mm + v_width_delta;
            END IF;
            IF v_height_delta != 0 AND v_cut_height_mm IS NOT NULL THEN
                v_cut_height_mm := v_cut_height_mm + v_height_delta;
            END IF;
            
            -- Update BomInstanceLine with calculated cut dimensions and notes
            UPDATE "BomInstanceLines"
            SET
                cut_length_mm = COALESCE(v_cut_length_mm, cut_length_mm),
                cut_width_mm = COALESCE(v_cut_width_mm, cut_width_mm),
                cut_height_mm = COALESCE(v_cut_height_mm, cut_height_mm),
                calc_notes = COALESCE(calc_notes, '') || 
                    CASE WHEN COALESCE(calc_notes, '') <> '' THEN '; ' ELSE '' END ||
                    'Engineering rules: ' || v_calc_notes
            WHERE id = v_target_line.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Applied engineering rules to BomInstance %', p_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.apply_engineering_rules_to_bom_instance IS 
    'Applies engineering rules from BOMComponents to compute cut dimensions. Now uses normalize_component_role() for robust role matching, preventing typos like "tube" vs "tubes".';

-- STEP 4: Backfill existing data (normalizar affects_role existentes)
-- FIX: Mover UPDATE dentro del DO block para que GET DIAGNOSTICS funcione correctamente
DO $$
DECLARE
  v_updated_count integer;
BEGIN
  -- Backfill: normalizar affects_role existentes
  UPDATE "BOMComponents"
  SET affects_role = normalize_component_role(affects_role)
  WHERE affects_role IS NOT NULL
    AND trim(affects_role) <> ''
    AND affects_role <> normalize_component_role(affects_role)
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration 206 completed: Normalización de affects_role';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Created/Updated:';
  RAISE NOTICE '   - Function: normalize_component_role()';
  RAISE NOTICE '   - Trigger: trg_normalize_affects_role (normaliza automáticamente)';
  RAISE NOTICE '   - Function: apply_engineering_rules_to_bom_instance() (actualizada para usar normalización)';
  RAISE NOTICE '   - Backfill: % rows updated', v_updated_count;
  RAISE NOTICE '';
  RAISE NOTICE '🛡️ Protection:';
  RAISE NOTICE '   - Variantes como "tubes" → "tube", "brackets" → "bracket" se normalizan automáticamente';
  RAISE NOTICE '   - Comparaciones en engineering rules ahora son más robustas';
  RAISE NOTICE '   - Previene typos comunes';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Nota: Esta migración no es urgente. La implementación actual funciona correctamente.';
  RAISE NOTICE '   Esta mejora aumenta la robustez pero no es crítica.';
  RAISE NOTICE '';
END $$;

