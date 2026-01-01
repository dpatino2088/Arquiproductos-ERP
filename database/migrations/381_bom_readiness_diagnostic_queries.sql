-- ====================================================
-- Migration 381: BOM Readiness Diagnostic Function
-- ====================================================
-- Creates a diagnostic function to understand current state:
-- A) Roles used in templates (by org)
-- B) Templates per ProductType
-- C) Auto-select components with missing fields
-- D) Legacy roles detected
-- E) Roles without mappings
-- F) Auto-select components that can't resolve
-- ====================================================
-- Usage: SELECT * FROM public.bom_readiness_diagnostic('YOUR_ORG_ID_HERE'::uuid);
-- ====================================================

CREATE OR REPLACE FUNCTION public.bom_readiness_diagnostic(
    p_organization_id uuid
)
RETURNS TABLE(
    query_type text,
    product_type_id uuid,
    product_type_name text,
    product_type_code text,
    component_role text,
    component_sub_role text,
    selection_mode text,
    count_components bigint,
    bom_template_id uuid,
    template_name text,
    component_id uuid,
    sku_resolution_rule text,
    qty_type text,
    qty_value numeric,
    item_category_code text,
    catalog_item_count bigint,
    status text
)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
    -- A) LISTA DE ROLES USADOS EN TEMPLATES (por org)
    RETURN QUERY
    SELECT 
        'A_ROLES_USED'::text as query_type,
        bt.product_type_id,
        pt.name as product_type_name,
        pt.code as product_type_code,
        bc.component_role,
        bc.component_sub_role,
        NULL::text as selection_mode,  -- Not available in this query
        COUNT(*)::bigint as count_components,
        NULL::uuid as bom_template_id,
        NULL::text as template_name,
        NULL::uuid as component_id,
        NULL::text as sku_resolution_rule,
        NULL::text as qty_type,
        NULL::numeric as qty_value,
        NULL::text as item_category_code,
        NULL::bigint as catalog_item_count,
        NULL::text as status
    FROM "BOMTemplates" bt
    JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
    JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
    WHERE pt.organization_id = p_organization_id
      AND pt.deleted = false
      AND bt.deleted = false
      AND bt.active = true
      AND bc.deleted = false
    GROUP BY bt.product_type_id, pt.name, pt.code, bc.component_role, bc.component_sub_role
    ORDER BY pt.name, bc.component_role, bc.component_sub_role;
    
    -- B) Templates por ProductType
    RETURN QUERY
    SELECT 
        'B_TEMPLATES_PER_PRODUCT_TYPE'::text as query_type,
        pt.id as product_type_id,
        pt.name as product_type_name,
        pt.code as product_type_code,
        NULL::text as component_role,
        NULL::text as component_sub_role,
        NULL::text as selection_mode,
        COUNT(bt.id) FILTER (WHERE bt.active = true AND bt.deleted = false)::bigint as count_components,
        NULL::uuid as bom_template_id,
        NULL::text as template_name,
        NULL::uuid as component_id,
        NULL::text as sku_resolution_rule,
        NULL::text as qty_type,
        NULL::numeric as qty_value,
        NULL::text as item_category_code,
        NULL::bigint as catalog_item_count,
        NULL::text as status
    FROM "ProductTypes" pt
    LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id AND bt.deleted = false
    WHERE pt.organization_id = p_organization_id
      AND pt.deleted = false
    GROUP BY pt.id, pt.name, pt.code
    ORDER BY pt.name;
    
    -- C) Componentes auto_select incompletos
    RETURN QUERY
    SELECT 
        'C_INCOMPLETE_AUTO_SELECT'::text as query_type,
        pt.id as product_type_id,
        pt.name as product_type_name,
        pt.code as product_type_code,
        bc.component_role,
        bc.component_sub_role,
        CASE WHEN bc.auto_select = true THEN 'auto_select' ELSE 'fixed' END as selection_mode,
        1::bigint as count_components,
        bt.id as bom_template_id,
        bt.name as template_name,
        bc.id as component_id,
        bc.sku_resolution_rule,
        bc.qty_type,
        bc.qty_value,
        NULL::text as item_category_code,
        NULL::bigint as catalog_item_count,
        NULL::text as status
    FROM "BOMComponents" bc
    JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
    JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
    WHERE pt.organization_id = p_organization_id
      AND pt.deleted = false
      AND bt.deleted = false
      AND bt.active = true
      AND bc.deleted = false
      AND (bc.auto_select = true OR bc.component_item_id IS NULL)
      AND (bc.sku_resolution_rule IS NULL OR bc.qty_type IS NULL)
    ORDER BY pt.name, bt.name, bc.component_role;
    
    -- D) Detectar roles legacy (operating_system, etc.)
    RETURN QUERY
    SELECT 
        'D_LEGACY_ROLES'::text as query_type,
        pt.id as product_type_id,
        pt.name as product_type_name,
        pt.code as product_type_code,
        bc.component_role,
        bc.component_sub_role,
        NULL::text as selection_mode,
        COUNT(*)::bigint as count_components,
        NULL::uuid as bom_template_id,
        NULL::text as template_name,
        NULL::uuid as component_id,
        NULL::text as sku_resolution_rule,
        NULL::text as qty_type,
        NULL::numeric as qty_value,
        NULL::text as item_category_code,
        NULL::bigint as catalog_item_count,
        'LEGACY'::text as status
    FROM "BOMComponents" bc
    JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
    JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
    WHERE pt.organization_id = p_organization_id
      AND pt.deleted = false
      AND bt.deleted = false
      AND bt.active = true
      AND bc.deleted = false
      AND bc.component_role IN ('operating_system')
    GROUP BY pt.id, pt.name, pt.code, bc.component_role, bc.component_sub_role
    ORDER BY bc.component_role, pt.name;
    
    -- E) Roles sin mapping en ComponentRoleMap
    RETURN QUERY
    SELECT 
        'E_MISSING_MAPPINGS'::text as query_type,
        pt.id as product_type_id,
        pt.name as product_type_name,
        pt.code as product_type_code,
        bc.component_role,
        bc.component_sub_role,
        NULL::text as selection_mode,
        COUNT(*)::bigint as count_components,
        NULL::uuid as bom_template_id,
        NULL::text as template_name,
        NULL::uuid as component_id,
        NULL::text as sku_resolution_rule,
        NULL::text as qty_type,
        NULL::numeric as qty_value,
        NULL::text as item_category_code,
        NULL::bigint as catalog_item_count,
        'NO_MAPPING'::text as status
    FROM "BOMComponents" bc
    JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
    JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
    LEFT JOIN "ComponentRoleMap" crm ON crm.role = bc.component_role 
      AND (bc.component_sub_role IS NULL OR crm.sub_role = bc.component_sub_role)
    WHERE pt.organization_id = p_organization_id
      AND pt.deleted = false
      AND bt.deleted = false
      AND bt.active = true
      AND bc.deleted = false
      AND bc.component_role IS NOT NULL
      AND bc.component_role NOT IN ('operating_system', 'end_cap')  -- Skip legacy and special case
      AND crm.role IS NULL  -- No mapping found
    GROUP BY pt.id, pt.name, pt.code, bc.component_role, bc.component_sub_role
    ORDER BY bc.component_role, pt.name;
END;
$$;

COMMENT ON FUNCTION public.bom_readiness_diagnostic(uuid) IS 
'Diagnostic function to analyze BOM readiness issues. Returns multiple query results with query_type prefix. Usage: SELECT * FROM public.bom_readiness_diagnostic(organization_id) WHERE query_type = ''A_ROLES_USED'';';

-- ====================================================
-- Example Usage:
-- ====================================================
-- -- Get all roles used:
-- SELECT * FROM public.bom_readiness_diagnostic('YOUR_ORG_ID'::uuid) WHERE query_type = 'A_ROLES_USED';
-- 
-- -- Get incomplete auto-select components:
-- SELECT * FROM public.bom_readiness_diagnostic('YOUR_ORG_ID'::uuid) WHERE query_type = 'C_INCOMPLETE_AUTO_SELECT';
-- 
-- -- Get legacy roles:
-- SELECT * FROM public.bom_readiness_diagnostic('YOUR_ORG_ID'::uuid) WHERE query_type = 'D_LEGACY_ROLES';
-- 
-- -- Get missing mappings:
-- SELECT * FROM public.bom_readiness_diagnostic('YOUR_ORG_ID'::uuid) WHERE query_type = 'E_MISSING_MAPPINGS';

