-- Migration: Fix Cost Engine Schema
-- Ensures all required columns exist in CostSettings, ImportTaxRules, and CategoryMargins
-- Idempotent: safe to run multiple times

begin;

-- ====================================================
-- 1) CostSettings: Ensure all columns exist
-- ====================================================

-- Add default_margin_pct if it doesn't exist
alter table public."CostSettings"
  add column if not exists default_margin_pct numeric(7,4) not null default 0.3500;

-- Verify other columns exist (will fail silently if they already exist)
alter table public."CostSettings"
  add column if not exists labor_pct numeric(7,4) not null default 0.1000;

alter table public."CostSettings"
  add column if not exists shipping_pct numeric(7,4) not null default 0.1500;

alter table public."CostSettings"
  add column if not exists global_import_tax_pct numeric(7,4) not null default 0.0000;

alter table public."CostSettings"
  add column if not exists reseller_discount_pct numeric(7,4) not null default 0.0000;

alter table public."CostSettings"
  add column if not exists distributor_discount_pct numeric(7,4) not null default 0.0000;

alter table public."CostSettings"
  add column if not exists partner_discount_pct numeric(7,4) not null default 0.0000;

alter table public."CostSettings"
  add column if not exists vip_discount_pct numeric(7,4) not null default 0.0000;

alter table public."CostSettings"
  add column if not exists minimum_margin_pct numeric(7,4) not null default 0.3500;

alter table public."CostSettings"
  add column if not exists is_active boolean not null default true;

-- Remove deleted column if it exists (we use is_active instead)
-- This is commented out to avoid data loss - run manually if needed
-- alter table public."CostSettings" drop column if exists deleted;

-- ====================================================
-- 2) ImportTaxRules: Ensure correct column names
-- ====================================================

-- Add import_tax_pct if it doesn't exist
alter table public."ImportTaxRules"
  add column if not exists import_tax_pct numeric(7,4) not null default 0.0000;

alter table public."ImportTaxRules"
  add column if not exists is_active boolean not null default true;

-- Ensure unique constraint on (organization_id, category_id)
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'importtaxrules_org_category_unique'
  ) then
    alter table public."ImportTaxRules"
      add constraint importtaxrules_org_category_unique
      unique (organization_id, category_id);
  end if;
end$$;

-- ====================================================
-- 3) CategoryMargins: Ensure correct column names
-- ====================================================

-- Add default_margin_pct if it doesn't exist
alter table public."CategoryMargins"
  add column if not exists default_margin_pct numeric(7,4) not null default 0.3500;

alter table public."CategoryMargins"
  add column if not exists is_active boolean not null default true;

-- Ensure unique constraint on (organization_id, category_id)
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'categorymargins_org_category_unique'
  ) then
    alter table public."CategoryMargins"
      add constraint categorymargins_org_category_unique
      unique (organization_id, category_id);
  end if;
end$$;

-- ====================================================
-- 4) Reload schema cache (critical for avoiding errors)
-- ====================================================

select pg_notify('pgrst', 'reload schema');

commit;

-- ====================================================
-- VERIFICATION QUERIES (run separately to check)
-- ====================================================

-- Check CostSettings columns
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'CostSettings'
-- ORDER BY ordinal_position;

-- Check ImportTaxRules columns
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'ImportTaxRules'
-- ORDER BY ordinal_position;

-- Check CategoryMargins columns
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'CategoryMargins'
-- ORDER BY ordinal_position;
