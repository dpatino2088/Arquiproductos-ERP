-- Allow new operator levels in org_role enum.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname = 'org_role' AND e.enumlabel = 'operator_admin'
  ) THEN
    ALTER TYPE org_role ADD VALUE 'operator_admin';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname = 'org_role' AND e.enumlabel = 'operator_member'
  ) THEN
    ALTER TYPE org_role ADD VALUE 'operator_member';
  END IF;
END
$$;;
