import { supabase } from '../lib/supabase/client';

export type CatalogItemRollSpecsRow = {
  catalog_item_id: string;
  organization_id: string;
  can_rotate: boolean;
  is_weldable: boolean;
  raw_material: string | null;
  openness_factor_pct: number | string | null;
  weight_g_m2: number | string | null;
  weight_kg_m2: number | string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type UpsertCatalogItemRollSpecsInput = {
  catalog_item_id: string;
  organization_id: string;
  can_rotate: boolean;
  is_weldable: boolean;
  raw_material: string | null;
  openness_factor_pct: number | null;
  weight_g_m2: number | null;
  weight_kg_m2: number | null;
  notes: string | null;
};

export async function fetchCatalogItemRollSpecs(
  catalogItemId: string
): Promise<CatalogItemRollSpecsRow | null> {
  const { data, error } = await supabase
    .from('CatalogItemRollSpecs')
    .select('*')
    .eq('catalog_item_id', catalogItemId)
    .maybeSingle();

  if (error) throw error;
  return (data as CatalogItemRollSpecsRow | null) ?? null;
}

export async function upsertCatalogItemRollSpecs(
  payload: UpsertCatalogItemRollSpecsInput
): Promise<CatalogItemRollSpecsRow> {
  const { data, error } = await supabase
    .from('CatalogItemRollSpecs')
    .upsert(payload, { onConflict: 'catalog_item_id' })
    .select('*')
    .single();

  if (error) throw error;
  return data as CatalogItemRollSpecsRow;
}

