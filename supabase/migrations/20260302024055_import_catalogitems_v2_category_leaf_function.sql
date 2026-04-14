create or replace function public.import_catalogitems_v2(p_organization_id uuid)
returns table (
  raw_rows integer,
  normalized_skus integer,
  upserted_items integer,
  missing_category integer,
  recompute_ok integer,
  recompute_fail integer
)
language plpgsql
as $$
declare
  has_stg_items boolean := false;
  has_stg_update boolean := false;
  v_raw integer := 0;
  v_norm integer := 0;
  v_upsert integer := 0;
  v_missing integer := 0;
  v_recompute_ok integer := 0;
  v_recompute_fail integer := 0;
  _item record;
begin
  select exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='_stg_catalog_items'
  ) into has_stg_items;

  select exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='_stg_catalog_update'
  ) into has_stg_update;

  if not has_stg_items and not has_stg_update then
    raise exception 'No staging tables found: _stg_catalog_items / _stg_catalog_update';
  end if;

  create temp table _imp_v2_raw (
    source_priority integer not null,
    row_num bigserial,
    sku text not null,
    item_name text,
    item_description text,
    category_name text,
    subcategory_name text,
    measure_basis text,
    uom text,
    cost_exw_text text,
    is_roll_text text,
    collection_name text,
    variant_name text,
    roll_width_m_text text,
    purchase_unit text,
    units_per_purchase_unit text,
    is_active_text text
  ) on commit drop;

  if has_stg_items then
    insert into _imp_v2_raw (
      source_priority, sku, item_name, item_description, category_name, subcategory_name,
      measure_basis, uom, cost_exw_text, is_roll_text, collection_name, variant_name,
      roll_width_m_text, purchase_unit, units_per_purchase_unit, is_active_text
    )
    select
      1,
      trim(coalesce(j->>'sku','')),
      nullif(trim(coalesce(j->>'item_name', j->>'name','')),''),
      nullif(trim(coalesce(j->>'item_description', j->>'description','')),''),
      nullif(trim(coalesce(j->>'category','')),''),
      nullif(trim(coalesce(j->>'subcategory', j->>'sub_category','')),''),
      nullif(trim(coalesce(j->>'measure_basis','')),''),
      nullif(trim(coalesce(j->>'unit_of_measure', j->>'uom','')),''),
      nullif(trim(coalesce(j->>'cost_exw', j->>'cost_price_exw','')),''),
      nullif(trim(coalesce(j->>'is_roll', j->>'is_fabric','')),''),
      nullif(trim(coalesce(j->>'collection_name', j->>'collection','')),''),
      nullif(trim(coalesce(j->>'variant_name', j->>'variant','')),''),
      nullif(trim(coalesce(j->>'roll_width_m', j->>'roll_widt', j->>'roll_width','')),''),
      nullif(trim(coalesce(j->>'purchase_unit','')),''),
      nullif(trim(coalesce(j->>'units_per_purchase_unit','')),''),
      nullif(trim(coalesce(j->>'is_active', j->>'active','')), '')
    from public."_stg_catalog_items" s
    cross join lateral to_jsonb(s) j
    where trim(coalesce(j->>'sku','')) <> '';
  end if;

  if has_stg_update then
    insert into _imp_v2_raw (
      source_priority, sku, item_name, item_description, category_name, subcategory_name,
      measure_basis, uom, cost_exw_text, is_roll_text, collection_name, variant_name,
      roll_width_m_text, purchase_unit, units_per_purchase_unit, is_active_text
    )
    select
      2,
      trim(coalesce(j->>'sku','')),
      nullif(trim(coalesce(j->>'item_name', j->>'name','')),''),
      nullif(trim(coalesce(j->>'item_description', j->>'description','')),''),
      nullif(trim(coalesce(j->>'category','')),''),
      nullif(trim(coalesce(j->>'subcategory', j->>'sub_category','')),''),
      nullif(trim(coalesce(j->>'measure_basis','')),''),
      nullif(trim(coalesce(j->>'unit_of_measure', j->>'uom','')),''),
      nullif(trim(coalesce(j->>'cost_exw', j->>'cost_price_exw','')),''),
      nullif(trim(coalesce(j->>'is_roll', j->>'is_fabric','')),''),
      nullif(trim(coalesce(j->>'collection_name', j->>'collection','')),''),
      nullif(trim(coalesce(j->>'variant_name', j->>'variant','')),''),
      nullif(trim(coalesce(j->>'roll_width_m', j->>'roll_widt', j->>'roll_width','')),''),
      nullif(trim(coalesce(j->>'purchase_unit','')),''),
      nullif(trim(coalesce(j->>'units_per_purchase_unit','')),''),
      nullif(trim(coalesce(j->>'is_active', j->>'active','')), '')
    from public."_stg_catalog_update" s
    cross join lateral to_jsonb(s) j
    where trim(coalesce(j->>'sku','')) <> '';
  end if;

  select count(*) into v_raw from _imp_v2_raw;
  if v_raw = 0 then
    raise exception 'No valid staging rows with SKU';
  end if;

  create temp table _imp_v2_norm as
  select distinct on (upper(trim(sku)))
    upper(trim(sku)) as sku,
    item_name,
    item_description,
    category_name,
    subcategory_name,
    measure_basis,
    uom,
    cost_exw_text,
    is_roll_text,
    collection_name,
    variant_name,
    roll_width_m_text,
    purchase_unit,
    units_per_purchase_unit,
    is_active_text,
    null::uuid as category_id
  from _imp_v2_raw
  order by upper(trim(sku)), source_priority asc, row_num desc;

  with leaves as (
    select child.id as leaf_id,
           lower(trim(child.name)) as leaf_name,
           lower(trim(parent.name)) as parent_name
    from public."CatalogCategories" child
    join public."CatalogCategories" parent on parent.id = child.parent_id
    where child.organization_id = p_organization_id
      and child.parent_id is not null
      and coalesce(child.is_group,false) = false
      and coalesce(child.deleted,false) = false
      and coalesce(parent.deleted,false) = false
  ), mapped as (
    select n.sku,
           coalesce(
             (select case when count(*)=1 then min(l.leaf_id) end
              from leaves l
              where n.subcategory_name is not null
                and n.category_name is not null
                and l.leaf_name = lower(n.subcategory_name)
                and l.parent_name = lower(n.category_name)),
             (select case when count(*)=1 then min(l.leaf_id) end
              from leaves l
              where n.subcategory_name is not null
                and l.leaf_name = lower(n.subcategory_name)),
             (select case when count(*)=1 then min(l.leaf_id) end
              from leaves l
              where n.category_name is not null
                and l.leaf_name = lower(n.category_name))
           ) as mapped_leaf
    from _imp_v2_norm n
  )
  update _imp_v2_norm n
  set category_id = m.mapped_leaf
  from mapped m
  where m.sku = n.sku;

  select count(*) into v_norm from _imp_v2_norm;
  select count(*) into v_missing
  from _imp_v2_norm
  where category_id is null
    and (category_name is not null or subcategory_name is not null);

  create temp table _imp_v2_affected(id uuid primary key) on commit drop;

  with prepared as (
    select
      n.sku,
      coalesce(nullif(n.item_name,''), n.sku) as name,
      n.item_description,
      n.category_id,
      n.collection_name,
      n.variant_name,
      case
        when lower(coalesce(n.measure_basis,'')) in ('linear','length','linear_m') then 'linear'
        when lower(coalesce(n.measure_basis,'')) in ('area','m2','sqm') then 'area'
        else 'unit'
      end as measure_basis_norm,
      coalesce(nullif(lower(n.uom),''), 'ea') as uom_norm,
      case when n.cost_exw_text ~ '^[0-9]+(\.[0-9]+)?$' then n.cost_exw_text::numeric else null end as cost_exw_norm,
      case when lower(coalesce(n.is_roll_text,'')) in ('true','1','t','yes','y') then true else false end as is_roll_norm,
      case when n.roll_width_m_text ~ '^[0-9]+(\.[0-9]+)?$' then n.roll_width_m_text::numeric else null end as roll_width_m_norm,
      coalesce(nullif(lower(n.purchase_unit),''), 'each') as purchase_unit_norm,
      case when n.units_per_purchase_unit ~ '^[0-9]+(\.[0-9]+)?$' then greatest(n.units_per_purchase_unit::numeric,1) else 1 end as units_per_purchase_unit_norm,
      case when lower(coalesce(n.is_active_text,'')) in ('false','0','f','no','n') then false else true end as is_active_norm
    from _imp_v2_norm n
  ),
  upserted as (
    insert into public."CatalogItems" (
      organization_id, sku, name, description, category_id,
      collection_name, variant_name, measure_basis, unit_of_measure,
      cost_exw, is_roll, roll_width_m, purchase_unit, units_per_purchase_unit,
      is_active, updated_at
    )
    select
      p_organization_id,
      p.sku,
      p.name,
      p.item_description,
      p.category_id,
      p.collection_name,
      p.variant_name,
      p.measure_basis_norm,
      p.uom_norm,
      p.cost_exw_norm,
      p.is_roll_norm,
      p.roll_width_m_norm,
      p.purchase_unit_norm,
      p.units_per_purchase_unit_norm,
      p.is_active_norm,
      now()
    from prepared p
    on conflict (organization_id, sku)
    do update set
      name = coalesce(excluded.name, public."CatalogItems".name),
      description = coalesce(excluded.description, public."CatalogItems".description),
      category_id = coalesce(excluded.category_id, public."CatalogItems".category_id),
      collection_name = coalesce(excluded.collection_name, public."CatalogItems".collection_name),
      variant_name = coalesce(excluded.variant_name, public."CatalogItems".variant_name),
      measure_basis = coalesce(excluded.measure_basis, public."CatalogItems".measure_basis),
      unit_of_measure = coalesce(excluded.unit_of_measure, public."CatalogItems".unit_of_measure),
      cost_exw = coalesce(excluded.cost_exw, public."CatalogItems".cost_exw),
      is_roll = coalesce(excluded.is_roll, public."CatalogItems".is_roll),
      roll_width_m = coalesce(excluded.roll_width_m, public."CatalogItems".roll_width_m),
      purchase_unit = coalesce(excluded.purchase_unit, public."CatalogItems".purchase_unit),
      units_per_purchase_unit = coalesce(excluded.units_per_purchase_unit, public."CatalogItems".units_per_purchase_unit),
      is_active = coalesce(excluded.is_active, public."CatalogItems".is_active),
      updated_at = now()
    returning id
  )
  insert into _imp_v2_affected(id)
  select distinct id from upserted
  on conflict (id) do nothing;

  select count(*) into v_upsert from _imp_v2_affected;

  for _item in
    select id from _imp_v2_affected
  loop
    begin
      update public."CatalogItems" set cost_exw = cost_exw, updated_at = now() where id = _item.id;
      perform public.msrp_compute_for_item(_item.id);
      v_recompute_ok := v_recompute_ok + 1;
    exception when others then
      v_recompute_fail := v_recompute_fail + 1;
      raise notice 'msrp recompute failed for %: %', _item.id, sqlerrm;
    end;
  end loop;

  return query
  select v_raw, v_norm, v_upsert, v_missing, v_recompute_ok, v_recompute_fail;
end;
$$;;
