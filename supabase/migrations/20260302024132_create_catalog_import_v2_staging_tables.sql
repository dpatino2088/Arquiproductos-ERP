do $$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='_stg_catalog_items'
  ) then
    create table public."_stg_catalog_items" (
      sku text,
      item_name text,
      item_description text,
      category text,
      subcategory text,
      measure_basis text,
      unit_of_measure text,
      uom text,
      cost_exw text,
      is_roll text,
      is_fabric text,
      collection_name text,
      variant_name text,
      roll_width_m text,
      roll_width text,
      purchase_unit text,
      units_per_purchase_unit text,
      is_active text,
      active text
    );
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='_stg_catalog_update'
  ) then
    create table public."_stg_catalog_update" (
      sku text,
      item_name text,
      item_description text,
      category text,
      subcategory text,
      measure_basis text,
      unit_of_measure text,
      uom text,
      cost_exw text,
      is_roll text,
      is_fabric text,
      collection_name text,
      variant_name text,
      roll_width_m text,
      roll_width text,
      purchase_unit text,
      units_per_purchase_unit text,
      is_active text,
      active text
    );
  end if;

  create index if not exists idx_stg_catalog_items_sku on public."_stg_catalog_items"(sku);
  create index if not exists idx_stg_catalog_update_sku on public."_stg_catalog_update"(sku);
end $$;;
