-- ====================================================
-- Fix SO Numbering: Start from SO-100
-- ====================================================
-- Este script actualiza el contador de OrganizationCounters
-- para que los Sales Orders comiencen desde SO-000100
-- ====================================================
-- NOTA: La tabla OrganizationCounters usa:
--   - 'key' (no 'document_type')
--   - 'last_value' (no 'last_number')
--   - El key debe ser 'sale_order' (lowercase con underscore)
-- ====================================================

DO $$
DECLARE
    v_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    v_max_so_num integer;
    v_target_value integer;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Fixing SO Numbering to start from SO-000100';
    RAISE NOTICE '====================================================';
    
    -- Obtener el número más alto de SO existente para esta organización
    SELECT COALESCE((regexp_match(sale_order_no, 'SO-(\d+)'))[1]::integer, 0) INTO v_max_so_num
    FROM "SalesOrders"
    WHERE organization_id = v_org_id
    AND sale_order_no ~ '^SO-\d+$'
    ORDER BY (regexp_match(sale_order_no, 'SO-(\d+)'))[1]::integer DESC
    LIMIT 1;
    
    -- Si hay SOs existentes y el máximo es >= 100, usar max
    -- Si no hay SOs o el máximo es < 100, usar 99 (para que el siguiente sea 100)
    IF v_max_so_num IS NOT NULL AND v_max_so_num >= 100 THEN
        v_target_value := v_max_so_num;
        RAISE NOTICE '   Found existing SOs. Max number: %, setting counter to %', v_max_so_num, v_target_value;
    ELSE
        v_target_value := 99;
        RAISE NOTICE '   No existing SOs or max < 100. Setting counter to 99 (next will be 100)';
    END IF;
    
    -- Insertar o actualizar el contador usando INSERT ... ON CONFLICT
    -- Esto es más simple y evita el problema con GET DIAGNOSTICS
    INSERT INTO "OrganizationCounters" (
        organization_id,
        key,
        last_value,
        updated_at
    ) VALUES (
        v_org_id,
        'sale_order',
        v_target_value,
        now()
    )
    ON CONFLICT (organization_id, key) DO UPDATE SET
        last_value = v_target_value,
        updated_at = now();
    
    RAISE NOTICE '✅ Counter creado/actualizado para SO empezando en %', v_target_value + 1;
END;
$$;

-- Verificar
SELECT 
    'SO Numbering Verification' as check_type,
    organization_id,
    key,
    last_value,
    last_value + 1 as next_number,
    'SO-' || LPAD((last_value + 1)::text, 6, '0') as next_sale_order_no
FROM "OrganizationCounters"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND key = 'sale_order';

