
-- Create Payments table
CREATE TABLE IF NOT EXISTS "Payments" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  sales_order_id uuid NOT NULL REFERENCES "SalesOrders"(id),
  amount numeric(12,2) NOT NULL,
  payment_method text,
  reference_number text,
  payment_date timestamptz NOT NULL DEFAULT now(),
  notes text,
  recorded_by uuid,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_so ON "Payments" (sales_order_id);
CREATE INDEX IF NOT EXISTS idx_payments_org ON "Payments" (organization_id);

-- Create ActivityTimeline table
CREATE TABLE IF NOT EXISTS "ActivityTimeline" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  action text NOT NULL,
  description text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  user_id uuid,
  user_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_timeline_entity ON "ActivityTimeline" (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_timeline_created ON "ActivityTimeline" (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_timeline_org ON "ActivityTimeline" (organization_id);

-- RLS for Payments
ALTER TABLE "Payments" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select_own_org" ON "Payments";
CREATE POLICY "payments_select_own_org" ON "Payments"
  FOR SELECT USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "payments_write_own_org" ON "Payments";
CREATE POLICY "payments_write_own_org" ON "Payments"
  FOR ALL USING (is_org_user_superadmin(organization_id))
  WITH CHECK (is_org_user_superadmin(organization_id));

-- RLS for ActivityTimeline
ALTER TABLE "ActivityTimeline" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "timeline_select_own_org" ON "ActivityTimeline";
CREATE POLICY "timeline_select_own_org" ON "ActivityTimeline"
  FOR SELECT USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "timeline_write_own_org" ON "ActivityTimeline";
CREATE POLICY "timeline_write_own_org" ON "ActivityTimeline"
  FOR ALL USING (is_org_user_superadmin(organization_id))
  WITH CHECK (is_org_user_superadmin(organization_id));
;
