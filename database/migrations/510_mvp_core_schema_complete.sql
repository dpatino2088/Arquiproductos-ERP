-- ============================================================
-- MVP Core Schema + Portal Users + ManufacturingOrders
-- Idempotent migration (safe to run multiple times)
-- Based on real schema verified in Supabase
-- ============================================================

BEGIN;

-- 0) Extensions
create extension if not exists pgcrypto;

-- ============================================================
-- 1) ENUMS (create if not exists)
-- ============================================================
do $$
begin
  if not exists (select 1 from pg_type where typname = 'org_role') then
    create type public.org_role as enum ('owner','admin','manager','user');
  end if;

  if not exists (select 1 from pg_type where typname = 'org_user_status') then
    create type public.org_user_status as enum ('active','invited','disabled');
  end if;

  if not exists (select 1 from pg_type where typname = 'portal_user_status') then
    create type public.portal_user_status as enum ('draft','invited','active','disabled');
  end if;

  if not exists (select 1 from pg_type where typname = 'quote_status') then
    create type public.quote_status as enum ('draft','sent','approved','rejected','cancelled');
  end if;

  if not exists (select 1 from pg_type where typname = 'sales_order_status') then
    create type public.sales_order_status as enum ('draft','confirmed','in_production','ready_for_delivery','delivered','cancelled');
  end if;

  if not exists (select 1 from pg_type where typname = 'manufacturing_order_status') then
    create type public.manufacturing_order_status as enum ('draft','planned','in_production','completed','cancelled');
  end if;
end $$;

-- ============================================================
-- 2) updated_at trigger helper (if not exists)
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- 3) Profiles (public."Profiles")
-- ============================================================
create table if not exists public."Profiles" (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_profiles_updated_at'
  ) then
    create trigger trg_profiles_updated_at
    before update on public."Profiles"
    for each row execute function public.set_updated_at();
  end if;
end $$;

alter table public."Profiles" enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='Profiles' and policyname='profiles_select_own') then
    create policy profiles_select_own
      on public."Profiles"
      for select
      using (auth.uid() = user_id and deleted = false);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='Profiles' and policyname='profiles_update_own') then
    create policy profiles_update_own
      on public."Profiles"
      for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

-- ============================================================
-- 4) DirectoryCustomers
-- Usar columnas EXPLÍCITAS: customer_name, customer_email, customer_phone
-- Si existe "name" genérica, agregar explícitas y hacer transición
-- ============================================================
create table if not exists public."DirectoryCustomers" (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public."Organizations"(id) on delete restrict,
  customer_name text not null,
  customer_email text,
  customer_phone text,
  status text,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Si existe columna "name" genérica, agregar explícitas y migrar datos
do $$
begin
  -- Agregar columnas explícitas si no existen
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='DirectoryCustomers' and column_name='customer_name'
  ) then
    alter table public."DirectoryCustomers" add column customer_name text;
    
    -- Migrar datos de "name" a "customer_name" si existe
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='DirectoryCustomers' and column_name='name'
    ) then
      update public."DirectoryCustomers" set customer_name = name where customer_name is null;
      -- NO eliminamos "name" todavía (transición)
    end if;
  end if;
  
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='DirectoryCustomers' and column_name='customer_email'
  ) then
    alter table public."DirectoryCustomers" add column customer_email text;
  end if;
  
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='DirectoryCustomers' and column_name='customer_phone'
  ) then
    alter table public."DirectoryCustomers" add column customer_phone text;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_directorycustomers_updated_at'
  ) then
    create trigger trg_directorycustomers_updated_at
    before update on public."DirectoryCustomers"
    for each row execute function public.set_updated_at();
  end if;
end $$;

create index if not exists idx_directorycustomers_org on public."DirectoryCustomers"(organization_id);

alter table public."DirectoryCustomers" enable row level security;

-- ============================================================
-- 5) DirectoryContacts
-- Usar columnas EXPLÍCITAS: contact_name, contact_email, contact_phone
-- Si existe "name" genérica, agregar explícitas y hacer transición
-- ============================================================
create table if not exists public."DirectoryContacts" (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public."Organizations"(id) on delete restrict,
  customer_id uuid null references public."DirectoryCustomers"(id) on delete set null,
  contact_name text not null,
  contact_email text,
  contact_phone text,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Si existe columna "name" genérica, agregar explícitas y migrar datos
do $$
begin
  -- Agregar columnas explícitas si no existen
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='DirectoryContacts' and column_name='contact_name'
  ) then
    alter table public."DirectoryContacts" add column contact_name text;
    
    -- Migrar datos de "name" a "contact_name" si existe
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='DirectoryContacts' and column_name='name'
    ) then
      update public."DirectoryContacts" set contact_name = name where contact_name is null;
      -- NO eliminamos "name" todavía (transición)
    end if;
  end if;
  
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='DirectoryContacts' and column_name='contact_email'
  ) then
    alter table public."DirectoryContacts" add column contact_email text;
    
    -- Migrar datos de "email" a "contact_email" si existe
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='DirectoryContacts' and column_name='email'
    ) then
      update public."DirectoryContacts" set contact_email = email where contact_email is null;
    end if;
  end if;
  
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='DirectoryContacts' and column_name='contact_phone'
  ) then
    alter table public."DirectoryContacts" add column contact_phone text;
    
    -- Migrar datos de "phone" a "contact_phone" si existe
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='DirectoryContacts' and column_name='phone'
    ) then
      update public."DirectoryContacts" set contact_phone = phone where contact_phone is null;
    end if;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_directorycontacts_updated_at'
  ) then
    create trigger trg_directorycontacts_updated_at
    before update on public."DirectoryContacts"
    for each row execute function public.set_updated_at();
  end if;
end $$;

create index if not exists idx_directorycontacts_org on public."DirectoryContacts"(organization_id);
create index if not exists idx_directorycontacts_customer on public."DirectoryContacts"(customer_id);

alter table public."DirectoryContacts" enable row level security;

-- ============================================================
-- 6) CustomerPortalUsers (externos)
-- Usar columnas EXPLÍCITAS: portal_user_email, portal_user_status
-- Si existe "email" genérica, agregar explícitas y hacer transición
-- ============================================================
create table if not exists public."CustomerPortalUsers" (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public."DirectoryCustomers"(id) on delete cascade,
  user_id uuid null references auth.users(id) on delete set null,
  portal_user_email text not null,
  portal_user_status public.portal_user_status not null default 'draft',
  invited_by_user_id uuid null references auth.users(id) on delete set null,
  invited_at timestamptz null,
  accepted_at timestamptz null,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Si existe columna "email" genérica, agregar explícitas y migrar datos
do $$
begin
  -- Agregar columnas explícitas si no existen
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='CustomerPortalUsers' and column_name='portal_user_email'
  ) then
    alter table public."CustomerPortalUsers" add column portal_user_email text;
    
    -- Migrar datos de "email" a "portal_user_email" si existe
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='CustomerPortalUsers' and column_name='email'
    ) then
      update public."CustomerPortalUsers" set portal_user_email = email where portal_user_email is null;
      -- NO eliminamos "email" todavía (transición)
    end if;
  end if;
  
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='CustomerPortalUsers' and column_name='portal_user_status'
  ) then
    alter table public."CustomerPortalUsers" add column portal_user_status public.portal_user_status;
    
    -- Migrar datos de "status" a "portal_user_status" si existe
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='CustomerPortalUsers' and column_name='status'
    ) then
      update public."CustomerPortalUsers" set portal_user_status = status::public.portal_user_status where portal_user_status is null;
    end if;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_customerportalusers_updated_at'
  ) then
    create trigger trg_customerportalusers_updated_at
    before update on public."CustomerPortalUsers"
    for each row execute function public.set_updated_at();
  end if;
end $$;

create index if not exists idx_portalusers_customer on public."CustomerPortalUsers"(customer_id);
create index if not exists idx_portalusers_user on public."CustomerPortalUsers"(user_id);

-- Unique per customer/portal_user_email when not deleted
-- Durante transición: si portal_user_email existe, usarlo; si no, usar email
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='CustomerPortalUsers' and column_name='portal_user_email'
  ) then
    -- Si portal_user_email existe, usar ese
    if not exists (
      select 1 from pg_indexes where indexname = 'portalusers_customer_email_uniq'
    ) then
      execute 'create unique index portalusers_customer_email_uniq on public."CustomerPortalUsers"(customer_id, lower(portal_user_email)) where deleted = false';
    end if;
  elsif exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='CustomerPortalUsers' and column_name='email'
  ) then
    -- Si solo email existe (transición), usar ese
    if not exists (
      select 1 from pg_indexes where indexname = 'portalusers_customer_email_uniq'
    ) then
      execute 'create unique index portalusers_customer_email_uniq on public."CustomerPortalUsers"(customer_id, lower(email)) where deleted = false';
    end if;
  end if;
end $$;

alter table public."CustomerPortalUsers" enable row level security;

-- ============================================================
-- 7) ManufacturingOrders (si no existe)
-- ============================================================
create table if not exists public."ManufacturingOrders" (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public."Organizations"(id) on delete restrict,
  sales_order_id uuid not null references public."SalesOrders"(id) on delete restrict,
  manufacturing_order_no text,
  status public.manufacturing_order_status not null default 'draft',
  priority text not null default 'normal',
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_manufacturingorders_updated_at'
  ) then
    create trigger trg_manufacturingorders_updated_at
    before update on public."ManufacturingOrders"
    for each row execute function public.set_updated_at();
  end if;
end $$;

create index if not exists idx_mo_org on public."ManufacturingOrders"(organization_id);
create index if not exists idx_mo_so on public."ManufacturingOrders"(sales_order_id);

alter table public."ManufacturingOrders" enable row level security;

-- ============================================================
-- 8) Ensure OrganizationUsers unique (org + email) WITHOUT relying on constraint name
-- ============================================================
create unique index if not exists orgusers_org_email_uniq
on public."OrganizationUsers"(organization_id, lower(user_email))
where deleted = false;

-- ============================================================
-- 9) Patch Quotes / SalesOrders (add minimal columns if missing)
--    (we do NOT drop/rename anything)
-- ============================================================
do $$
begin
  -- Quotes: organization_id
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='organization_id'
  ) then
    alter table public."Quotes" add column organization_id uuid references public."Organizations"(id) on delete restrict;
  end if;

  -- Quotes: quote_no
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='quote_no'
  ) then
    alter table public."Quotes" add column quote_no text;
  end if;

  -- Quotes: status (only if not exists, preserve existing CHECK if present)
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='status'
  ) then
    alter table public."Quotes" add column status public.quote_status not null default 'draft';
  end if;

  -- Quotes: customer_id/contact_id optional
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='customer_id'
  ) then
    alter table public."Quotes" add column customer_id uuid null references public."DirectoryCustomers"(id) on delete set null;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='contact_id'
  ) then
    alter table public."Quotes" add column contact_id uuid null references public."DirectoryContacts"(id) on delete set null;
  end if;

  -- Quotes: created_by_user_id
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='created_by_user_id'
  ) then
    alter table public."Quotes" add column created_by_user_id uuid null references auth.users(id) on delete set null;
  end if;

  -- Quotes: deleted
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='deleted'
  ) then
    alter table public."Quotes" add column deleted boolean not null default false;
  end if;

  -- Quotes: created_at/updated_at if missing
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='created_at'
  ) then
    alter table public."Quotes" add column created_at timestamptz not null default now();
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='Quotes' and column_name='updated_at'
  ) then
    alter table public."Quotes" add column updated_at timestamptz not null default now();
  end if;

  -- SalesOrders: organization_id
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='organization_id'
  ) then
    alter table public."SalesOrders" add column organization_id uuid references public."Organizations"(id) on delete restrict;
  end if;

  -- SalesOrders: quote_id (RULE: ALWAYS from quote)
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='quote_id'
  ) then
    alter table public."SalesOrders" add column quote_id uuid references public."Quotes"(id) on delete restrict;
  end if;

  -- SalesOrders: sales_order_no
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='sales_order_no'
  ) then
    alter table public."SalesOrders" add column sales_order_no text;
  end if;

  -- SalesOrders: status (only if not exists)
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='status'
  ) then
    alter table public."SalesOrders" add column status public.sales_order_status not null default 'draft';
  end if;

  -- SalesOrders: deleted
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='deleted'
  ) then
    alter table public."SalesOrders" add column deleted boolean not null default false;
  end if;

  -- SalesOrders: created_at/updated_at
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='created_at'
  ) then
    alter table public."SalesOrders" add column created_at timestamptz not null default now();
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='SalesOrders' and column_name='updated_at'
  ) then
    alter table public."SalesOrders" add column updated_at timestamptz not null default now();
  end if;
end $$;

-- updated_at triggers for Quotes / SalesOrders if not present
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='Quotes') then
    if not exists (select 1 from pg_trigger where tgname='trg_quotes_updated_at') then
      create trigger trg_quotes_updated_at
      before update on public."Quotes"
      for each row execute function public.set_updated_at();
    end if;
  end if;

  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='SalesOrders') then
    if not exists (select 1 from pg_trigger where tgname='trg_salesorders_updated_at') then
      create trigger trg_salesorders_updated_at
      before update on public."SalesOrders"
      for each row execute function public.set_updated_at();
    end if;
  end if;
end $$;

-- Enable RLS on Quotes/SalesOrders (safe)
alter table public."Quotes" enable row level security;
alter table public."SalesOrders" enable row level security;

-- ============================================================
-- 10) RLS POLICIES (MVP)
-- Membership rule: must exist in OrganizationUsers for that org, active, not deleted
-- Write rule: role owner/admin
-- ============================================================

-- DirectoryCustomers policies
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='DirectoryCustomers' and policyname='dir_customers_select') then
    create policy dir_customers_select
      on public."DirectoryCustomers"
      for select
      using (
        deleted = false
        and exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='DirectoryCustomers' and policyname='dir_customers_write') then
    create policy dir_customers_write
      on public."DirectoryCustomers"
      for all
      using (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      )
      with check (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      );
  end if;
end $$;

-- DirectoryContacts policies
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='DirectoryContacts' and policyname='dir_contacts_select') then
    create policy dir_contacts_select
      on public."DirectoryContacts"
      for select
      using (
        deleted = false
        and exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='DirectoryContacts' and policyname='dir_contacts_write') then
    create policy dir_contacts_write
      on public."DirectoryContacts"
      for all
      using (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      )
      with check (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      );
  end if;
end $$;

-- Quotes policies (complement existing ones if any)
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='Quotes' and policyname='quotes_select') then
    create policy quotes_select
      on public."Quotes"
      for select
      using (
        deleted = false
        and exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='Quotes' and policyname='quotes_write') then
    create policy quotes_write
      on public."Quotes"
      for all
      using (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      )
      with check (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      );
  end if;
end $$;

-- SalesOrders policies (complement existing ones if any)
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='SalesOrders' and policyname='salesorders_select') then
    create policy salesorders_select
      on public."SalesOrders"
      for select
      using (
        deleted = false
        and exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='SalesOrders' and policyname='salesorders_write') then
    create policy salesorders_write
      on public."SalesOrders"
      for all
      using (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      )
      with check (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      );
  end if;
end $$;

-- ManufacturingOrders policies
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ManufacturingOrders' and policyname='mo_select') then
    create policy mo_select
      on public."ManufacturingOrders"
      for select
      using (
        deleted = false
        and exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ManufacturingOrders' and policyname='mo_write') then
    create policy mo_write
      on public."ManufacturingOrders"
      for all
      using (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      )
      with check (
        exists (
          select 1 from public."OrganizationUsers" ou
          where ou.user_id = auth.uid()
            and ou.organization_id = organization_id
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role, 'admin'::public.org_role)
        )
      );
  end if;
end $$;

-- CustomerPortalUsers policies:
-- - portal user can see own row if user_id matches
-- - internal org users can see portal rows for customers belonging to their org
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='CustomerPortalUsers' and policyname='portalusers_select') then
    create policy portalusers_select
      on public."CustomerPortalUsers"
      for select
      using (
        deleted = false
        and (
          (user_id is not null and user_id = auth.uid())
          or exists (
            select 1
            from public."DirectoryCustomers" c
            join public."OrganizationUsers" ou
              on ou.organization_id = c.organization_id
            where c.id = customer_id
              and ou.user_id = auth.uid()
              and ou.deleted = false
              and ou.status = 'active'
          )
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='CustomerPortalUsers' and policyname='portalusers_write_internal') then
    create policy portalusers_write_internal
      on public."CustomerPortalUsers"
      for all
      using (
        exists (
          select 1
          from public."DirectoryCustomers" c
          join public."OrganizationUsers" ou
            on ou.organization_id = c.organization_id
          where c.id = customer_id
            and ou.user_id = auth.uid()
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role,'admin'::public.org_role)
        )
      )
      with check (
        exists (
          select 1
          from public."DirectoryCustomers" c
          join public."OrganizationUsers" ou
            on ou.organization_id = c.organization_id
          where c.id = customer_id
            and ou.user_id = auth.uid()
            and ou.deleted = false
            and ou.status = 'active'
            and ou.role in ('owner'::public.org_role,'admin'::public.org_role)
        )
      );
  end if;
end $$;

-- ============================================================
-- 11) SEED PERMISSIONS (minimum required)
-- ============================================================
insert into public."Permissions" (code, module, description)
values
  ('directory.read', 'directory', 'View directory (customers, contacts)'),
  ('directory.write', 'directory', 'Create/edit directory entries'),
  ('catalog.read', 'catalog', 'View catalog'),
  ('catalog.write', 'catalog', 'Create/edit catalog items'),
  ('sales.read', 'sales', 'View quotes and sales orders'),
  ('sales.write', 'sales', 'Create/edit quotes and sales orders'),
  ('manufacturing.read', 'manufacturing', 'View manufacturing orders'),
  ('manufacturing.write', 'manufacturing', 'Create/edit manufacturing orders'),
  ('finance.read', 'finance', 'View financial data'),
  ('finance.write', 'finance', 'Create/edit financial data'),
  ('settings.read', 'settings', 'View settings'),
  ('settings.write', 'settings', 'Edit settings'),
  ('dashboard.read', 'dashboard', 'View dashboard')
on conflict (code) do nothing;

-- ============================================================
-- 12) ASSIGN ALL PERMISSIONS TO OWNERS AND SUPERADMINS
-- ============================================================
-- Asignar todos los permisos a usuarios con role='owner' o role='superadmin' o role='super_admin'
insert into public."OrganizationUserPermissions" (organization_user_id, permission_code)
select ou.id, p.code
from public."OrganizationUsers" ou
cross join public."Permissions" p
where (ou.role = 'owner' or ou.role = 'superadmin' or ou.role = 'super_admin')
  and ou.deleted = false
on conflict (organization_user_id, permission_code) do nothing;

-- ============================================================
-- 13) VERIFICATION QUERIES (commented out - uncomment to run)
-- ============================================================
/*
-- Organizations + membership
select * from public."Organizations" order by created_at asc;
select id, organization_id, user_id, user_email, role, status, deleted from public."OrganizationUsers";

-- Directory tables counts
select 'DirectoryCustomers' as tbl, count(*) from public."DirectoryCustomers"
union all select 'DirectoryContacts', count(*) from public."DirectoryContacts"
union all select 'CustomerPortalUsers', count(*) from public."CustomerPortalUsers"
union all select 'ManufacturingOrders', count(*) from public."ManufacturingOrders";

-- Permissions for owner
select ou.user_email, ou.role, p.code, p.module
from public."OrganizationUsers" ou
join public."OrganizationUserPermissions" oup on oup.organization_user_id = ou.id
join public."Permissions" p on p.code = oup.permission_code
where ou.role = 'owner' and ou.deleted = false
order by ou.user_email, p.module, p.code;
*/

COMMIT;
