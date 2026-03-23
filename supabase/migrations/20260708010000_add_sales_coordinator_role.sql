-- Add Sales Coordinator to org_role enum.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_type t
    WHERE t.typname = 'org_role'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname = 'org_role' AND e.enumlabel = 'sales_coordinator'
  ) THEN
    ALTER TYPE org_role ADD VALUE 'sales_coordinator';
  END IF;
END
$$;

