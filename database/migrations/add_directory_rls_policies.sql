-- RLS Policies for Directory Tables
-- These policies allow organization members to read data from their organization

-- CONTACTS
drop policy if exists "Allow org members to read contacts" on public."DirectoryContacts";

create policy "Allow org members to read contacts"
on public."DirectoryContacts"
for select
using (
  exists (
    select 1
    from public."OrganizationUsers" ou
    where ou.organization_id = "DirectoryContacts".organization_id
      and ou.user_id = auth.uid()
      and ou.deleted = false
  )
);

-- CUSTOMERS
drop policy if exists "Allow org members to read customers" on public."DirectoryCustomers";

create policy "Allow org members to read customers"
on public."DirectoryCustomers"
for select
using (
  exists (
    select 1
    from public."OrganizationUsers" ou
    where ou.organization_id = "DirectoryCustomers".organization_id
      and ou.user_id = auth.uid()
      and ou.deleted = false
  )
);

-- CONTRACTORS
drop policy if exists "Allow org members to read contractors" on public."DirectoryContractors";

create policy "Allow org members to read contractors"
on public."DirectoryContractors"
for select
using (
  exists (
    select 1
    from public."OrganizationUsers" ou
    where ou.organization_id = "DirectoryContractors".organization_id
      and ou.user_id = auth.uid()
      and ou.deleted = false
  )
);

-- VENDORS
drop policy if exists "Allow org members to read vendors" on public."DirectoryVendors";

create policy "Allow org members to read vendors"
on public."DirectoryVendors"
for select
using (
  exists (
    select 1
    from public."OrganizationUsers" ou
    where ou.organization_id = "DirectoryVendors".organization_id
      and ou.user_id = auth.uid()
      and ou.deleted = false
  )
);

-- SITES
drop policy if exists "Allow org members to read sites" on public."DirectorySites";

create policy "Allow org members to read sites"
on public."DirectorySites"
for select
using (
  exists (
    select 1
    from public."OrganizationUsers" ou
    where ou.organization_id = "DirectorySites".organization_id
      and ou.user_id = auth.uid()
      and ou.deleted = false
  )
);
