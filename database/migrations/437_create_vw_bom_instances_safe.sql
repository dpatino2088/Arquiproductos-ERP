-- ====================================================
-- Migration 437: Create safe view for BOM instances with normalized sales_order_line_id
-- ====================================================
-- OBJETIVO: Crear vista segura que expone sales_order_line_id_safe
-- para uso en frontend, manteniendo compatibilidad con legacy sale_order_line_id
-- ====================================================

SET search_path = public;

BEGIN;

-- ====================================================
-- STEP 1: Create vw_bom_instances_safe view
-- ====================================================

DROP VIEW IF EXISTS public.vw_bom_instances_safe CASCADE;

CREATE VIEW public.vw_bom_instances_safe AS
SELECT 
    bi.id,
    bi.organization_id,
    bi.manufacturing_order_id,
    -- Normalized column: use sales_order_line_id if exists, fallback to sale_order_line_id (legacy)
    COALESCE(bi.sales_order_line_id, bi.sale_order_line_id) AS sales_order_line_id_safe,
    bi.quote_line_id,
    bi.bom_template_id,
    bi.labor_cost,
    bi.total_cost_with_labor,
    bi.total_msrp_sale_out_with_labor,
    bi.created_at,
    bi.updated_at,
    bi.generated_at,
    bi.deleted
FROM "BomInstances" bi
WHERE bi.deleted = false;

-- Note: manufacturing_order_id is included in the view for direct queries by MO

COMMENT ON VIEW public.vw_bom_instances_safe IS 
    'Safe view for BOM instances with normalized sales_order_line_id_safe. Uses COALESCE to handle legacy sale_order_line_id column. Frontend should use this view instead of querying BomInstances directly.';

-- ====================================================
-- STEP 2: Grant Permissions
-- ====================================================

GRANT SELECT ON public.vw_bom_instances_safe TO anon;
GRANT SELECT ON public.vw_bom_instances_safe TO authenticated;

COMMIT;

