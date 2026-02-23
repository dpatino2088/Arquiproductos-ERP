-- ============================================================
-- Acting-As persistido (dealer activo por usuario)
-- Single source of truth for the effective dealer of the session.
-- ============================================================

-- 1) Preferences table ---------------------------------------------------

create table if not exists public."AppUserPreferences" (
  user_id uuid primary key references public."AppUsers"(id) on delete cascade,
  active_dealer_id uuid null references public."Dealers"(id) on delete set null,
  updated_at timestamptz not null default now()
);

create index if not exists app_user_prefs_active_dealer_idx
  on public."AppUserPreferences"(active_dealer_id);

-- Keep updated_at current
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_app_user_prefs_updated_at on public."AppUserPreferences";
create trigger trg_app_user_prefs_updated_at
before update on public."AppUserPreferences"
for each row execute function public.set_updated_at();

-- 2) RLS on AppUserPreferences -------------------------------------------

alter table public."AppUserPreferences" enable row level security;

drop policy if exists app_user_prefs_select_own on public."AppUserPreferences";
create policy app_user_prefs_select_own
on public."AppUserPreferences" for select to authenticated
using (
  exists (
    select 1 from public."AppUsers" au
    where au.id = "AppUserPreferences".user_id
      and au.auth_user_id = auth.uid()
  )
);

drop policy if exists app_user_prefs_insert_own on public."AppUserPreferences";
create policy app_user_prefs_insert_own
on public."AppUserPreferences" for insert to authenticated
with check (
  exists (
    select 1 from public."AppUsers" au
    where au.id = "AppUserPreferences".user_id
      and au.auth_user_id = auth.uid()
  )
);

drop policy if exists app_user_prefs_update_own on public."AppUserPreferences";
create policy app_user_prefs_update_own
on public."AppUserPreferences" for update to authenticated
using (
  exists (
    select 1 from public."AppUsers" au
    where au.id = "AppUserPreferences".user_id
      and au.auth_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public."AppUsers" au
    where au.id = "AppUserPreferences".user_id
      and au.auth_user_id = auth.uid()
  )
);

-- 3) Resolver: current_dealer_id() (no-arg overload) ---------------------
-- Replaces the old version. Now checks AppUserPreferences for org users.
-- Dealer users  → AppUsers.dealer_id
-- Org users     → AppUserPreferences.active_dealer_id (NULL if not set)

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
  limit 1
$$;

-- 4) RPC: set_acting_dealer(p_dealer_id) ---------------------------------
-- Validates: only org users, dealer must belong to same org (or NULL to clear).

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
  select id, organization_id, user_type
    into v_app_user_id, v_org_id, v_user_type
  from public."AppUsers"
  where auth_user_id = auth.uid()
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

revoke all on function public.set_acting_dealer(uuid) from public;
grant execute on function public.set_acting_dealer(uuid) to authenticated;
