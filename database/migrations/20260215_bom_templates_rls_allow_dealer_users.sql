-- ====================================================
-- BOMTemplates RLS: allow Dealer (portal) users to SELECT
-- ====================================================
-- Portal users (DealerUsers) are not in OrganizationUsers, so they could not
-- read BOMTemplates. This migration extends the SELECT policy so that users
-- who have a DealerUsers row for an organization can also read BOMTemplates
-- for that organization (and organization_id IS NULL).
-- ====================================================

SET search_path = public;

-- Drop existing SELECT policy
DROP POLICY IF EXISTS "bom_templates_select_own_org" ON "BOMTemplates";

-- Recreate SELECT: org users (OrganizationUsers) and portal users (DealerUsers) can read
CREATE POLICY "bom_templates_select_own_org"
    ON "BOMTemplates"
    FOR SELECT
    TO authenticated
    USING (
        -- Internal users: organization_id in OrganizationUsers
        organization_id IN (
            SELECT organization_id
            FROM "OrganizationUsers"
            WHERE user_id = auth.uid()
            AND deleted = false
        )
        OR
        -- Portal/Dealer users: organization_id in DealerUsers
        organization_id IN (
            SELECT organization_id
            FROM "DealerUsers"
            WHERE user_id = auth.uid()
            AND deleted = false
        )
        OR
        -- Shared templates (no org)
        organization_id IS NULL
    );
