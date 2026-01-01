-- ============================================================================
-- CORRECCIÓN AUTOMÁTICA: Agregar product_type_id a QuoteLines que no lo tienen
-- Este script busca y corrige QuoteLines sin product_type_id
-- ============================================================================

DO $$
DECLARE
    v_quote_line_record RECORD;
    v_product_type_id UUID;
    v_organization_id UUID;
    v_count INT := 0;
    v_fixed_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔧 CORRIGIENDO product_type_id EN QuoteLines';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    FOR v_quote_line_record IN 
        SELECT 
            ql.id,
            ql.organization_id,
            ql.product_type,
            ql.quote_id,
            q.organization_id as quote_org_id
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id AND q.deleted = false
        WHERE ql.product_type_id IS NULL
            AND ql.deleted = false
        ORDER BY ql.created_at DESC
    LOOP
        v_organization_id := COALESCE(v_quote_line_record.organization_id, v_quote_line_record.quote_org_id);
        v_count := v_count + 1;
        
        -- Intentar encontrar product_type_id por código
        IF v_quote_line_record.product_type IS NOT NULL THEN
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE UPPER(code) = UPPER(v_quote_line_record.product_type)
                AND (organization_id = v_organization_id OR organization_id IS NULL)
                AND deleted = false
            ORDER BY 
                CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Si no se encontró por código, buscar por tipo común (ROLLER SHADE)
        IF v_product_type_id IS NULL THEN
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE UPPER(code) IN ('ROLLER', 'ROLLER_SHADE', 'ROLLER-SHADE')
                AND (organization_id = v_organization_id OR organization_id IS NULL)
                AND deleted = false
            ORDER BY 
                CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Si aún no se encontró, buscar cualquier ProductType activo de la organización
        IF v_product_type_id IS NULL THEN
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE (organization_id = v_organization_id OR organization_id IS NULL)
                AND deleted = false
            ORDER BY 
                CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Si se encontró, actualizar QuoteLine
        IF v_product_type_id IS NOT NULL THEN
            BEGIN
                UPDATE "QuoteLines"
                SET 
                    product_type_id = v_product_type_id,
                    organization_id = v_organization_id,
                    updated_at = NOW()
                WHERE id = v_quote_line_record.id;
                
                v_fixed_count := v_fixed_count + 1;
                
                IF v_count <= 10 THEN
                    RAISE NOTICE '✅ QuoteLine % corregido: product_type_id = %', v_quote_line_record.id, v_product_type_id;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '❌ Error actualizando QuoteLine %: %', v_quote_line_record.id, SQLERRM;
            END;
        ELSE
            IF v_count <= 10 THEN
                RAISE NOTICE '⚠️  QuoteLine % no se pudo corregir: no hay ProductType disponible (org_id: %)', 
                    v_quote_line_record.id, v_organization_id;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CORRECCIÓN COMPLETA';
    RAISE NOTICE '   📊 QuoteLines revisados: %', v_count;
    RAISE NOTICE '   ✅ QuoteLines corregidos: %', v_fixed_count;
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error corrigiendo product_type_id: %', SQLERRM;
END $$;

-- Verificar resultado
SELECT 
    'RESULTADO' as paso,
    COUNT(*) FILTER (WHERE product_type_id IS NULL) as sin_product_type_id,
    COUNT(*) FILTER (WHERE product_type_id IS NOT NULL) as con_product_type_id,
    COUNT(*) as total
FROM "QuoteLines"
WHERE deleted = false;








