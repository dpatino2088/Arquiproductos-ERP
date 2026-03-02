import type { SupabaseClient } from '@supabase/supabase-js';
import type { CatalogItem } from '../types/catalog';

const MSRP_BATCH = 100;
const MAX_LIST_SIZE = 2500;

type MsrpRow = { dealer_price: number; msrp: number; total_cost: number; shipping_cost: number; import_tax_cost: number };

function enrichItems(d: Record<string, unknown>[], msrpMap: Map<string, MsrpRow>): CatalogItem[] {
  return (d || []).map((item: Record<string, unknown>) => {
    const msrpRow = msrpMap.get(item.id as string);
    const finalMsrp = (msrpRow?.msrp != null && !isNaN(msrpRow.msrp)) ? msrpRow.msrp : null;
    let salePrice = 0;
    if (finalMsrp != null) salePrice = finalMsrp;
    else if (item.cost_exw && item.default_margin_pct) salePrice = Number(item.cost_exw) * (1 + Number(item.default_margin_pct) / 100);
    else if (item.cost_exw) salePrice = Number(item.cost_exw) * 1.5;
    const itemName = (item.name || item.item_name || item.sku || `Item-${String(item.id).slice(0, 8)}`) as string;
    const normalizedMeasureBasis = item.measure_basis === 'linear_m' ? 'linear' : (item.measure_basis || 'unit');
    const unitOfMeasure = (item.unit_of_measure || item.uom || 'unit') as string;
    return {
      id: item.id as string,
      organization_id: item.organization_id as string,
      sku: (item.sku as string) || '',
      name: itemName,
      item_name: (item.item_name ?? item.name) as string | null,
      description: (item.description as string) ?? null,
      manufacturer_id: (item.manufacturer_id as string) ?? null,
      manufacturer: ((item.manufacturer as string) ?? (item.metadata as Record<string, unknown>)?.manufacturer as string) ?? null,
      category_id: (item.category_id as string) ?? null,
      item_category_id: (item.item_category_id as string) ?? null,
      measure_basis: normalizedMeasureBasis as CatalogItem['measure_basis'],
      unit_of_measure: unitOfMeasure,
      uom: unitOfMeasure,
      is_fabric: Boolean(item.is_fabric),
      roll_type: item.roll_type as CatalogItem['roll_type'],
      collection_name: (item.collection_name as string) ?? null,
      variant_name: (item.variant_name as string) ?? null,
      roll_width: (item.roll_width ?? item.roll_width_m) as number | null,
      roll_width_m: (item.roll_width_m ?? item.roll_width) as number | null,
      fabric_pricing_mode: item.fabric_pricing_mode as CatalogItem['fabric_pricing_mode'],
      color: (item.color as string) ?? null,
      item_role: (item.item_role as string) ?? null,
      cost_exw: (item.cost_exw as number) ?? null,
      default_margin_pct: (item.default_margin_pct as number) ?? null,
      msrp: finalMsrp,
      cost_price: Number(item.cost_exw ?? item.cost_price ?? 0),
      unit_price: salePrice,
      is_active: item.is_active !== undefined && item.is_active !== null ? Boolean(item.is_active) : Boolean(item.active ?? true),
      active: item.active !== undefined && item.active !== null ? Boolean(item.active) : Boolean(item.is_active ?? true),
      discontinued: Boolean(item.discontinued),
      image_url: (item.image_url as string) ?? null,
      deleted: Boolean(item.deleted),
      archived: Boolean(item.archived),
      created_at: (item.created_at as string) || new Date().toISOString(),
      updated_at: (item.updated_at as string) ?? null,
      metadata: (item.metadata as Record<string, unknown>) || {},
      created_by: (item.created_by as string) ?? null,
      updated_by: (item.updated_by as string) ?? null,
    } as CatalogItem;
  });
}

/**
 * Fetch catalog items list for list view. Light: one CatalogItems query + batched CatalogItemsMSRP (no N+1).
 * Used by useCatalogItemsList. Optional filters (primitives) for future server-side filter.
 */
export async function fetchCatalogItemsList(
  supabase: SupabaseClient,
  params: {
    orgId: string;
    filters?: {
      q?: string;
      categoryId?: string;
      status?: string;
      sortKey?: string;
      page?: number;
      pageSize?: number;
    };
  }
): Promise<CatalogItem[]> {
  const { orgId, filters } = params;
  const pageSize = Math.min(filters?.pageSize ?? 500, MAX_LIST_SIZE);
  const from = ((filters?.page ?? 1) - 1) * pageSize;

  let q = supabase
    .from('CatalogItems')
    .select('*')
    .eq('organization_id', orgId)
    .eq('is_active', true)
    .order('sku', { ascending: true })
    .range(from, from + pageSize - 1);

  if (filters?.categoryId) {
    q = q.eq('category_id', filters.categoryId);
  }
  if (filters?.q && filters.q.trim().length >= 2) {
    const term = `%${filters.q.trim()}%`;
    q = q.or(`sku.ilike.${term},name.ilike.${term}`);
  }

  const { data: rows, error } = await q;
  if (error) throw error;
  const list = (rows || []) as Record<string, unknown>[];

  const ids = list.map((r) => r.id as string).filter(Boolean);
  const msrpMap = new Map<string, MsrpRow>();
  if (ids.length > 0) {
    for (let i = 0; i < ids.length; i += MSRP_BATCH) {
      const batch = ids.slice(i, i + MSRP_BATCH);
      const { data: msrpData } = await supabase
        .from('CatalogItemsMSRP')
        .select('catalog_item_id, dealer_price, msrp, total_cost, shipping_cost, import_tax_cost')
        .eq('organization_id', orgId)
        .in('catalog_item_id', batch);
      (msrpData || []).forEach((row: Record<string, unknown>) => {
        if (row?.catalog_item_id) {
          msrpMap.set(row.catalog_item_id as string, {
            dealer_price: Number(row.dealer_price ?? 0),
            msrp: Number(row.msrp ?? 0),
            total_cost: Number(row.total_cost ?? 0),
            shipping_cost: Number(row.shipping_cost ?? 0),
            import_tax_cost: Number(row.import_tax_cost ?? 0),
          });
        }
      });
    }
  }

  const items = enrichItems(list, msrpMap).filter((it) => it?.id && (it.sku || it.name || it.item_name));
  return items;
}

/**
 * Fetch a single catalog item by id (detail view). Same shape as list items (CatalogItem).
 * Used by useCatalogItemDetail. When opening from list, use list cache as initialData for instant open.
 */
export async function fetchCatalogItemDetail(
  supabase: SupabaseClient,
  params: { orgId: string; itemId: string }
): Promise<CatalogItem> {
  const { orgId, itemId } = params;
  const { data: row, error } = await supabase
    .from('CatalogItems')
    .select('*')
    .eq('id', itemId)
    .eq('organization_id', orgId)
    .maybeSingle();

  if (error) throw error;
  if (!row) {
    throw new Error('Item not found');
  }

  const list = [row] as Record<string, unknown>[];
  const { data: msrpData } = await supabase
    .from('CatalogItemsMSRP')
    .select('catalog_item_id, dealer_price, msrp, total_cost, shipping_cost, import_tax_cost')
    .eq('organization_id', orgId)
    .eq('catalog_item_id', itemId)
    .maybeSingle();

  const msrpMap = new Map<string, MsrpRow>();
  if (msrpData && (msrpData as Record<string, unknown>).catalog_item_id) {
    const r = msrpData as Record<string, unknown>;
    msrpMap.set(r.catalog_item_id as string, {
      dealer_price: Number(r.dealer_price ?? 0),
      msrp: Number(r.msrp ?? 0),
      total_cost: Number(r.total_cost ?? 0),
      shipping_cost: Number(r.shipping_cost ?? 0),
      import_tax_cost: Number(r.import_tax_cost ?? 0),
    });
  }

  const items = enrichItems(list, msrpMap);
  const item = items[0];
  if (!item?.id) throw new Error('Item not found');
  return item;
}
