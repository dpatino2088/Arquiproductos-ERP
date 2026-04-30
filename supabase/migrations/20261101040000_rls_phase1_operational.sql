-- RLS Phase 1: enable Row Level Security on operational tables (org-scoped)
-- All tables here have an `organization_id` column, so policies use the existing
-- helpers `is_org_user_member` (read+write for org users) and
-- `is_org_owner_or_admin` (delete and sensitive writes).

-- =========================================================
-- SaleOrderLines
-- =========================================================
ALTER TABLE public."SaleOrderLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sale_order_lines_select ON public."SaleOrderLines";
CREATE POLICY sale_order_lines_select
ON public."SaleOrderLines"
FOR SELECT
USING (
  is_org_user_member(organization_id)
  OR is_portal_user_in_org(organization_id)
);

DROP POLICY IF EXISTS sale_order_lines_insert ON public."SaleOrderLines";
CREATE POLICY sale_order_lines_insert
ON public."SaleOrderLines"
FOR INSERT
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS sale_order_lines_update ON public."SaleOrderLines";
CREATE POLICY sale_order_lines_update
ON public."SaleOrderLines"
FOR UPDATE
USING (is_org_user_member(organization_id))
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS sale_order_lines_delete ON public."SaleOrderLines";
CREATE POLICY sale_order_lines_delete
ON public."SaleOrderLines"
FOR DELETE
USING (is_org_owner_or_admin(organization_id));

-- =========================================================
-- ManufacturingOrderLines
-- =========================================================
ALTER TABLE public."ManufacturingOrderLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mol_select ON public."ManufacturingOrderLines";
CREATE POLICY mol_select
ON public."ManufacturingOrderLines"
FOR SELECT
USING (is_org_user_member(organization_id));

DROP POLICY IF EXISTS mol_insert ON public."ManufacturingOrderLines";
CREATE POLICY mol_insert
ON public."ManufacturingOrderLines"
FOR INSERT
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS mol_update ON public."ManufacturingOrderLines";
CREATE POLICY mol_update
ON public."ManufacturingOrderLines"
FOR UPDATE
USING (is_org_user_member(organization_id))
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS mol_delete ON public."ManufacturingOrderLines";
CREATE POLICY mol_delete
ON public."ManufacturingOrderLines"
FOR DELETE
USING (is_org_owner_or_admin(organization_id));

-- =========================================================
-- BOMInstances
-- =========================================================
ALTER TABLE public."BOMInstances" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bom_instances_select ON public."BOMInstances";
CREATE POLICY bom_instances_select
ON public."BOMInstances"
FOR SELECT
USING (is_org_user_member(organization_id));

DROP POLICY IF EXISTS bom_instances_insert ON public."BOMInstances";
CREATE POLICY bom_instances_insert
ON public."BOMInstances"
FOR INSERT
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS bom_instances_update ON public."BOMInstances";
CREATE POLICY bom_instances_update
ON public."BOMInstances"
FOR UPDATE
USING (is_org_user_member(organization_id))
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS bom_instances_delete ON public."BOMInstances";
CREATE POLICY bom_instances_delete
ON public."BOMInstances"
FOR DELETE
USING (is_org_owner_or_admin(organization_id));

-- =========================================================
-- BOMInstanceLines
-- =========================================================
ALTER TABLE public."BOMInstanceLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bom_instance_lines_select ON public."BOMInstanceLines";
CREATE POLICY bom_instance_lines_select
ON public."BOMInstanceLines"
FOR SELECT
USING (is_org_user_member(organization_id));

DROP POLICY IF EXISTS bom_instance_lines_insert ON public."BOMInstanceLines";
CREATE POLICY bom_instance_lines_insert
ON public."BOMInstanceLines"
FOR INSERT
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS bom_instance_lines_update ON public."BOMInstanceLines";
CREATE POLICY bom_instance_lines_update
ON public."BOMInstanceLines"
FOR UPDATE
USING (is_org_user_member(organization_id))
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS bom_instance_lines_delete ON public."BOMInstanceLines";
CREATE POLICY bom_instance_lines_delete
ON public."BOMInstanceLines"
FOR DELETE
USING (is_org_owner_or_admin(organization_id));

-- =========================================================
-- DealerCreditNotes (org members + dealer portal can read their own)
-- =========================================================
ALTER TABLE public."DealerCreditNotes" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dealer_credit_notes_select ON public."DealerCreditNotes";
CREATE POLICY dealer_credit_notes_select
ON public."DealerCreditNotes"
FOR SELECT
USING (
  is_org_user_member(organization_id)
  OR (dealer_id IS NOT NULL AND is_dealer_member(dealer_id))
);

DROP POLICY IF EXISTS dealer_credit_notes_insert ON public."DealerCreditNotes";
CREATE POLICY dealer_credit_notes_insert
ON public."DealerCreditNotes"
FOR INSERT
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS dealer_credit_notes_update ON public."DealerCreditNotes";
CREATE POLICY dealer_credit_notes_update
ON public."DealerCreditNotes"
FOR UPDATE
USING (is_org_user_member(organization_id))
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS dealer_credit_notes_delete ON public."DealerCreditNotes";
CREATE POLICY dealer_credit_notes_delete
ON public."DealerCreditNotes"
FOR DELETE
USING (is_org_owner_or_admin(organization_id));

-- =========================================================
-- DealerConfiguratorPolicies (org members read; admins write)
-- =========================================================
ALTER TABLE public."DealerConfiguratorPolicies" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dealer_configurator_policies_select ON public."DealerConfiguratorPolicies";
CREATE POLICY dealer_configurator_policies_select
ON public."DealerConfiguratorPolicies"
FOR SELECT
USING (
  is_org_user_member(organization_id)
  OR (dealer_id IS NOT NULL AND is_dealer_member(dealer_id))
);

DROP POLICY IF EXISTS dealer_configurator_policies_insert ON public."DealerConfiguratorPolicies";
CREATE POLICY dealer_configurator_policies_insert
ON public."DealerConfiguratorPolicies"
FOR INSERT
WITH CHECK (is_org_owner_or_admin(organization_id));

DROP POLICY IF EXISTS dealer_configurator_policies_update ON public."DealerConfiguratorPolicies";
CREATE POLICY dealer_configurator_policies_update
ON public."DealerConfiguratorPolicies"
FOR UPDATE
USING (is_org_owner_or_admin(organization_id))
WITH CHECK (is_org_owner_or_admin(organization_id));

DROP POLICY IF EXISTS dealer_configurator_policies_delete ON public."DealerConfiguratorPolicies";
CREATE POLICY dealer_configurator_policies_delete
ON public."DealerConfiguratorPolicies"
FOR DELETE
USING (is_org_owner_or_admin(organization_id));

NOTIFY pgrst, 'reload schema';
