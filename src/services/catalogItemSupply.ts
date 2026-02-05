import { supabase } from '../lib/supabase/client';

export type SupplyType = 'stock' | 'order';
export type SupplyOrigin = 'local' | 'import';

export type CatalogItemSupplyRow = {
  catalog_item_id: string;
  organization_id: string;
  supply_type: SupplyType;
  supply_origin: SupplyOrigin;
  lead_time_min_days: number;
  lead_time_max_days: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type UpsertCatalogItemSupplyInput = Pick<
  CatalogItemSupplyRow,
  | 'catalog_item_id'
  | 'organization_id'
  | 'supply_type'
  | 'supply_origin'
  | 'lead_time_min_days'
  | 'lead_time_max_days'
  | 'notes'
>;

export async function fetchCatalogItemSupply(
  catalogItemId: string,
  organizationId: string
): Promise<CatalogItemSupplyRow | null> {
  const { data, error } = await supabase
    .from('CatalogItemSupply')
    .select('*')
    .eq('catalog_item_id', catalogItemId)
    .eq('organization_id', organizationId)
    .maybeSingle();

  if (error) throw error;
  return (data as CatalogItemSupplyRow | null) ?? null;
}

export async function upsertCatalogItemSupply(
  input: UpsertCatalogItemSupplyInput
): Promise<CatalogItemSupplyRow> {
  const { data, error } = await supabase
    .from('CatalogItemSupply')
    .upsert(input, { onConflict: 'catalog_item_id' })
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new Error('No data returned from upsert');
  return data as CatalogItemSupplyRow;
}

