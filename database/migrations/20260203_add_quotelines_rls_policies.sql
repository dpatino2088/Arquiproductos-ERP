-- QuoteLines has RLS enabled but (in v7 dump) no policies.
-- This blocks inserts with: "new row violates row-level security policy for table QuoteLines".
--
-- Policies below:
-- - Internal users (OrganizationUsers active) can select/insert/update/delete quote lines within their org.
-- - Insert requires that the referenced Quote belongs to the same organization.

ALTER TABLE public."QuoteLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS quotelines_select ON public."QuoteLines";
DROP POLICY IF EXISTS quotelines_insert ON public."QuoteLines";
DROP POLICY IF EXISTS quotelines_update ON public."QuoteLines";
DROP POLICY IF EXISTS quotelines_delete ON public."QuoteLines";

CREATE POLICY quotelines_select
ON public."QuoteLines"
FOR SELECT
USING (
  public.is_org_user_member(organization_id)
);

CREATE POLICY quotelines_insert
ON public."QuoteLines"
FOR INSERT
WITH CHECK (
  public.is_org_user_member(organization_id)
  AND EXISTS (
    SELECT 1
    FROM public."Quotes" q
    WHERE q.id = quote_id
      AND q.organization_id = "QuoteLines".organization_id
      AND q.deleted = false
  )
);

CREATE POLICY quotelines_update
ON public."QuoteLines"
FOR UPDATE
USING (
  public.is_org_user_member(organization_id)
)
WITH CHECK (
  public.is_org_user_member(organization_id)
);

CREATE POLICY quotelines_delete
ON public."QuoteLines"
FOR DELETE
USING (
  public.is_org_user_member(organization_id)
);

