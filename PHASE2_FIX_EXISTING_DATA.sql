-- ====================================================
-- FASE 2: Reparar Datos Existentes (Retroactivo)
-- ====================================================
-- Copiar QuoteLines a SalesOrderLines para los 6 SOs sin líneas
-- ====================================================

DO $$
DECLARE
    v_so RECORD;
    v_quote_line RECORD;
    v_line_number integer;
    v_sale_order_line_id uuid;
    v_total_created integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'FASE 2: Copiando QuoteLines a SalesOrderLines';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Procesar cada Sales Order sin líneas
    FOR v_so IN
        SELECT 
            so.id,
            so.sale_order_no,
            so.quote_id,
            so.organization_id
        FROM "SalesOrders" so
        WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "SalesOrderLines" sol 
            WHERE sol.sale_order_id = so.id 
            AND sol.deleted = false
        )
        ORDER BY so.created_at ASC
    LOOP
        RAISE NOTICE 'Procesando SO: %', v_so.sale_order_no;
        v_line_number := 0;
        
        -- Copiar cada QuoteLine
        FOR v_quote_line IN
            SELECT *
            FROM "QuoteLines"
            WHERE quote_id = v_so.quote_id
            AND deleted = false
            ORDER BY created_at ASC
        LOOP
            v_line_number := v_line_number + 1;
            
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    organization_id,
                    sale_order_id,
                    quote_line_id,
                    catalog_item_id,
                    line_number,
                    qty,
                    unit_price,
                    line_total,
                    width_m,
                    height_m,
                    area,
                    position,
                    collection_name,
                    variant_name,
                    product_type,
                    product_type_id,
                    drive_type,
                    bottom_rail_type,
                    cassette,
                    cassette_type,
                    side_channel,
                    side_channel_type,
                    hardware_color,
                    metadata,
                    created_at,
                    updated_at
                ) VALUES (
                    v_so.organization_id,
                    v_so.id,
                    v_quote_line.id,
                    v_quote_line.catalog_item_id,
                    v_line_number,
                    v_quote_line.qty,
                    v_quote_line.unit_price_snapshot,
                    v_quote_line.line_total,
                    v_quote_line.width_m,
                    v_quote_line.height_m,
                    v_quote_line.area,
                    v_quote_line.position,
                    v_quote_line.collection_name,
                    v_quote_line.variant_name,
                    v_quote_line.product_type,
                    v_quote_line.product_type_id,
                    v_quote_line.drive_type,
                    v_quote_line.bottom_rail_type,
                    v_quote_line.cassette,
                    v_quote_line.cassette_type,
                    v_quote_line.side_channel,
                    v_quote_line.side_channel_type,
                    v_quote_line.hardware_color,
                    v_quote_line.metadata,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                v_total_created := v_total_created + 1;
                RAISE NOTICE '  ✅ Línea % creada', v_line_number;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error: % (%)', SQLERRM, SQLSTATE;
            END;
        END LOOP;
        
        RAISE NOTICE '✅ SO % completado (%líneas)', v_so.sale_order_no, v_line_number;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FASE 2 COMPLETADA';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Total SalesOrderLines creados: %', v_total_created;
    RAISE NOTICE '';
END;
$$;

-- Verificar resultado
SELECT 
    'Verificación Fase 2' as paso,
    so.sale_order_no,
    COUNT(sol.id) as sales_order_lines
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no
ORDER BY so.created_at DESC
LIMIT 10;






