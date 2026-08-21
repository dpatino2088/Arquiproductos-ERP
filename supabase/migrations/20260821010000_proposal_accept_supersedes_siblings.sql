-- Only one valid proposal version per family.
--
-- Business rule: when a proposal version is ACCEPTED, every other version of the
-- same family (same organization + quote + base proposal number, e.g. PR-00247 /
-- PR-00247_V2 / PR-00247_V3) is automatically CANCELLED. Until then, an accepted
-- older version stays valid while a newer draft is being negotiated — acceptance
-- of the new version is the moment the old commitment dies.
--
-- Before this, all versions kept their status forever: PR-00233 had TWO accepted
-- versions at once, and families like PR-00247 showed stale drafts next to the
-- accepted V3 as if they were still valid options.

-- 1) Trigger: cancel sibling versions when a proposal becomes accepted.
CREATE OR REPLACE FUNCTION public.trg_proposal_accept_cancel_siblings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base_no text;
BEGIN
  -- Family is identified by the base proposal number; without one we can't
  -- match siblings safely, so do nothing.
  IF NEW.proposal_no IS NULL THEN
    RETURN NEW;
  END IF;

  v_base_no := regexp_replace(NEW.proposal_no, '_V\d+$', '');

  UPDATE public."Proposals" p
  SET status = 'cancelled',
      updated_at = now()
  WHERE p.id <> NEW.id
    AND p.organization_id = NEW.organization_id
    AND p.quote_id IS NOT DISTINCT FROM NEW.quote_id
    AND p.deleted IS NOT TRUE
    AND p.proposal_no IS NOT NULL
    AND regexp_replace(p.proposal_no, '_V\d+$', '') = v_base_no
    AND p.status <> 'cancelled';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposal_accept_cancel_siblings ON public."Proposals";
CREATE TRIGGER trg_proposal_accept_cancel_siblings
AFTER INSERT OR UPDATE OF status ON public."Proposals"
FOR EACH ROW
WHEN (NEW.status = 'accepted' AND NEW.deleted IS NOT TRUE)
EXECUTE FUNCTION public.trg_proposal_accept_cancel_siblings();

COMMENT ON FUNCTION public.trg_proposal_accept_cancel_siblings() IS
  'When a proposal version is accepted, cancels all other versions of the same family (org + quote + base proposal_no). Guarantees a single valid version per family.';

-- 2) One-time cleanup: cancel versions OLDER than the latest accepted version of
--    each family. Newer drafts (in-flight renegotiations, e.g. accepted V1 with a
--    draft V2) are intentionally left untouched — the trigger will cancel the old
--    version when/if the new one is accepted.
--    Verified preview (5 rows): PR-00229_V2 draft, PR-00233 v1 accepted (dup),
--    PR-00247 + PR-00247_V2 drafts, PR-00284 draft.
WITH fam AS (
  SELECT id,
         organization_id,
         quote_id,
         regexp_replace(proposal_no, '_V\d+$', '') AS base_no,
         COALESCE(version_no, 1) AS vno,
         status::text AS status
  FROM public."Proposals"
  WHERE deleted IS NOT TRUE
    AND proposal_no IS NOT NULL
),
acc AS (
  SELECT organization_id, quote_id, base_no, max(vno) AS max_acc_vno
  FROM fam
  WHERE status = 'accepted'
  GROUP BY 1, 2, 3
)
UPDATE public."Proposals" p
SET status = 'cancelled',
    updated_at = now()
FROM fam f
JOIN acc a
  ON a.organization_id = f.organization_id
 AND a.quote_id IS NOT DISTINCT FROM f.quote_id
 AND a.base_no = f.base_no
WHERE p.id = f.id
  AND f.vno < a.max_acc_vno
  AND f.status <> 'cancelled';
