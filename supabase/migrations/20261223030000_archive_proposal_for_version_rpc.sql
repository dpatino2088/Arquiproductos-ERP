-- RPC to archive the predecessor proposal during versioning.
-- SECURITY DEFINER so a Dealer Member can supersede (archive) a proposal in their dealer
-- scope even when it was created by another dealer user (normal RLS only lets a member
-- update/archive their own). Without this, versioning someone else's proposal would create
-- the new version but leave the old one active.
create or replace function public.archive_proposal_for_version(p_proposal_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_dealer uuid;
begin
  select organization_id, dealer_id into v_org, v_dealer
  from "Proposals"
  where id = p_proposal_id and deleted is not true;

  if v_org is null then
    return false; -- not found / already deleted
  end if;

  -- Authorization: caller must belong to the proposal's dealer (portal) or be an org user
  -- with sales update rights (internal). Scoped to avoid cross-dealer archiving.
  if not (
    (v_dealer is not null and session_is_dealer_portal(v_dealer))
    or (session_is_org_user(v_org) and can_update_sales_org(v_org))
  ) then
    raise exception 'Not authorized to archive proposal %', p_proposal_id
      using errcode = '42501';
  end if;

  update "Proposals" set archived = true where id = p_proposal_id;
  return true;
end;
$$;

grant execute on function public.archive_proposal_for_version(uuid) to authenticated;
