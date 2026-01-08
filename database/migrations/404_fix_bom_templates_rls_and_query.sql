-- ====================================================
-- Migration 404: Fix BOMTemplates RLS and Query Issues
-- ====================================================
-- Fixes RLS policies for BOMTemplates to allow authenticated users
-- to read templates for their organization
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Enable RLS on BOMTemplates (if not already enabled)
-- ====================================================
ALTER TABLE "BOMTemplates" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 2: Drop existing policies if they exist
-- ====================================================
DROP POLICY IF EXISTS "bom_templates_select_own_org" ON "BOMTemplates";
DROP POLICY IF EXISTS "bom_templates_insert_own_org" ON "BOMTemplates";
DROP POLICY IF EXISTS "bom_templates_update_own_org" ON "BOMTemplates";
DROP POLICY IF EXISTS "bom_templates_delete_own_org" ON "BOMTemplates";

-- ====================================================
-- STEP 3: Create RLS Policies for BOMTemplates
-- ====================================================

-- SELECT: Users can see BOMTemplates for their organization
-- This allows authenticated users to read templates where organization_id matches
-- their active organization (via OrganizationUsers table)
CREATE POLICY "bom_templates_select_own_org"
    ON "BOMTemplates"
    FOR SELECT
    TO authenticated
    USING (
        -- Allow if organization_id matches user's organization
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
        OR
        -- Allow if organization_id is NULL (shared templates)
        organization_id IS NULL
    );

-- INSERT: Users can create BOMTemplates for their organization
CREATE POLICY "bom_templates_insert_own_org"
    ON "BOMTemplates"
    FOR INSERT
    TO authenticated
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update BOMTemplates for their organization
CREATE POLICY "bom_templates_update_own_org"
    ON "BOMTemplates"
    FOR UPDATE
    TO authenticated
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    )
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- DELETE: Users can soft-delete BOMTemplates for their organization
CREATE POLICY "bom_templates_delete_own_org"
    ON "BOMTemplates"
    FOR DELETE
    TO authenticated
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- ====================================================
-- STEP 4: Create RPC function as fallback (SECURITY DEFINER)
-- ====================================================
-- This function bypasses RLS and can be used if RLS policies don't work
CREATE OR REPLACE FUNCTION public.get_bom_templates(
    p_organization_id uuid,
    p_product_type_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_templates jsonb;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', bt.id,
            'name', bt.name,
            'product_type_id', bt.product_type_id,
            'organization_id', bt.organization_id,
            'active', bt.active,
            'deleted', bt.deleted,
            'created_at', bt.created_at,
            'updated_at', bt.updated_at
        )
    )
    INTO v_templates
    FROM "BOMTemplates" bt
    WHERE bt.organization_id = p_organization_id
    AND bt.deleted = false
    AND bt.active = true
    AND (p_product_type_id IS NULL OR bt.product_type_id = p_product_type_id)
    ORDER BY bt.created_at DESC;
    
    RETURN COALESCE(v_templates, '[]'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.get_bom_templates IS 
    'Returns BOMTemplates for a given organization and optional product_type_id. Bypasses RLS using SECURITY DEFINER.';

GRANT EXECUTE ON FUNCTION public.get_bom_templates(uuid, uuid) TO authenticated;


