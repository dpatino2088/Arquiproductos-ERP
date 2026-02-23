-- Fix: when a user has BOTH org and dealer AppUsers rows,
-- always prefer the org row so SuperAdmin can use acting-as.

-- 1) Fix resolver
create or replace function public.current_dealer_id()
returns uuid
language sql stable
as $$
  select
    case
      when au.user_type = 'dealer' then au.dealer_id
      else pref.active_dealer_id
    end
  from public."AppUsers" au
  left join public."AppUserPreferences" pref on pref.user_id = au.id
  where au.auth_user_id = auth.uid()
  order by case when au.user_type = 'org' then 0 else 1 end
  limit 1
$$;

-- 2) Fix RPC
create or replace function public.set_acting_dealer(p_dealer_id uuid)
returns table(active_dealer_id uuid)
language plpgsql security definer
as $$
declare
  v_app_user_id uuid;
  v_org_id uuid;
  v_user_type text;
  v_ok boolean;
begin
  -- Prefer org row when user has both org and dealer AppUsers entries
  select id, organization_id, user_type
    into v_app_user_id, v_org_id, v_user_type
  from public."AppUsers"
  where auth_user_id = auth.uid()
  order by case when user_type = 'org' then 0 else 1 end
  limit 1;

  if v_app_user_id is null then
    raise exception 'AppUser not found for auth user';
  end if;

  if v_user_type <> 'org' then
    raise exception 'Only org users can use acting-as';
  end if;

  if p_dealer_id is not null then
    select exists(
      select 1 from public."Dealers" d
      where d.id = p_dealer_id
        and d.organization_id = v_org_id
        and (d.deleted is null or d.deleted = false)
    ) into v_ok;

    if not v_ok then
      raise exception 'Dealer not in same organization or does not exist';
    end if;
  end if;

  insert into public."AppUserPreferences"(user_id, active_dealer_id)
  values (v_app_user_id, p_dealer_id)
  on conflict (user_id)
  do update set active_dealer_id = excluded.active_dealer_id;

  return query select p_dealer_id;
end $$;
