-- ====================================================
-- Migration 294: Check user organization access for RLS
-- ====================================================
-- Verifies if the current user has access to the organization
-- ====================================================

-- Check current user and their organization memberships
SELECT 
    'Current User' as step,
    auth.uid() as current_user_id,
    (SELECT email FROM auth.users WHERE id = auth.uid()) as user_email;

-- Check organization memberships for current user
SELECT 
    'User Organizations' as step,
    ou.organization_id,
    o.display_name as organization_name,
    ou.is_owner,
    ou.is_admin,
    ou.is_viewer
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.user_id = auth.uid()
AND ou.deleted = false
AND o.deleted = false;

-- Check SalesOrder organization
SELECT 
    'SalesOrder Org' as step,
    so.sale_order_no,
    so.organization_id,
    o.display_name as organization_name
FROM "SalesOrders" so
LEFT JOIN "Organizations" o ON o.id = so.organization_id
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false;

-- Check if user can see SalesOrderLines (simulating RLS)
DO $$
DECLARE
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_user_id uuid;
    v_user_has_access boolean := false;
    v_sol_count integer;
    rec RECORD;
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    RAISE NOTICE 'Current User ID: %', v_user_id;
    RAISE NOTICE '';
    
    -- Get SalesOrder details
    SELECT so.id, so.organization_id 
    INTO v_sale_order_id, v_organization_id
    FROM "SalesOrders" so
    WHERE so.sale_order_no = 'SO-090154'
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ SalesOrder not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'SalesOrder ID: %', v_sale_order_id;
    RAISE NOTICE 'SalesOrder Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Check if user has access to this organization
    SELECT EXISTS (
        SELECT 1 
        FROM "OrganizationUsers" ou
        WHERE ou.user_id = v_user_id
        AND ou.organization_id = v_organization_id
        AND ou.deleted = false
        AND (ou.is_owner = true OR ou.is_admin = true)
    ) INTO v_user_has_access;
    
    IF v_user_has_access THEN
        RAISE NOTICE '✅ User HAS access to organization %', v_organization_id;
    ELSE
        RAISE NOTICE '❌ User DOES NOT have access to organization %', v_organization_id;
        RAISE NOTICE '';
        RAISE NOTICE 'Checking user memberships:';
        FOR rec IN
            SELECT ou.organization_id, ou.is_owner, ou.is_admin, ou.is_viewer
            FROM "OrganizationUsers" ou
            WHERE ou.user_id = v_user_id
            AND ou.deleted = false
        LOOP
            RAISE NOTICE '  Org: %, Owner: %, Admin: %, Viewer: %', 
                rec.organization_id, rec.is_owner, rec.is_admin, rec.is_viewer;
        END LOOP;
    END IF;
    
    RAISE NOTICE '';
    
    -- Count SalesOrderLines (this will respect RLS)
    SELECT COUNT(*) INTO v_sol_count
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_sale_order_id
    AND deleted = false;
    
    RAISE NOTICE 'SalesOrderLines visible to current user (with RLS): %', v_sol_count;
    
    -- Also check without RLS (as superuser)
    RAISE NOTICE '';
    RAISE NOTICE 'SalesOrderLines in database (total, ignoring RLS):';
    FOR rec IN
        SELECT id, sale_order_id, organization_id, line_number
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND deleted = false
    LOOP
        RAISE NOTICE '  SOL ID: %, Org ID: %, Line: %', rec.id, rec.organization_id, rec.line_number;
    END LOOP;
    
END $$;


