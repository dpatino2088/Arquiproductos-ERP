-- Fix is_org_member: OrganizationUsers has no archived column
CREATE OR REPLACE FUNCTION "public"."is_org_member"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND (ou.deleted IS NULL OR ou.deleted = false)
  );
END;
$$;
