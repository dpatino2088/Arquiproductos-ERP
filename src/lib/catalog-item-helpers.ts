/**
 * Catalog Item Helpers
 * Utility functions for catalog item operations
 */

import { supabase } from './supabase/client';

/**
 * Get allowed UOM options based on is_fabric and measure_basis
 * 
 * Rules:
 * - If is_fabric=true:
 *   - measure_basis allowed: 'linear_m' or 'area'
 *   - If measure_basis='linear_m' -> uom: ['yd', 'm', 'ft']
 *   - If measure_basis='area' -> uom: ['m2'] (and optionally 'yd2' if exists in conversions)
 * - If is_fabric=false:
 *   - If measure_basis='unit' -> uom: ['ea', 'pcs', 'set', 'pair']
 *   - If measure_basis='linear_m' -> uom: ['m', 'ft', 'yd']
 *   - If measure_basis='area' -> uom: ['m2']
 */
export function getAllowedUoms(params: {
  isFabric: boolean;
  measureBasis: string | null | undefined;
}): string[] {
  const { isFabric, measureBasis } = params;
  
  if (!measureBasis) return [];
  
  const normalized = measureBasis.toLowerCase().trim();
  
  if (isFabric) {
    // Fabrics: only linear_m or area
    if (normalized === 'linear_m' || normalized === 'linear') {
      return ['m', 'yd', 'ft'];
    }
    if (normalized === 'area') {
      return ['m2']; // Could add 'yd2' if needed
    }
    return []; // Invalid measure_basis for fabric
  } else {
    // Non-fabric items
    if (normalized === 'unit') {
      return ['ea', 'pcs', 'set', 'pair'];
    }
    if (normalized === 'linear_m' || normalized === 'linear') {
      return ['m', 'ft', 'yd'];
    }
    if (normalized === 'area') {
      return ['m2'];
    }
    return [];
  }
}

/**
 * Get allowed measure basis options based on is_fabric
 */
export function getAllowedMeasureBasis(isFabric: boolean): Array<{ value: string; label: string }> {
  if (isFabric) {
    return [
      { value: 'linear_m', label: 'Linear (length)' },
      { value: 'area', label: 'Area (m²)' },
    ];
  } else {
    return [
      { value: 'unit', label: 'Unit (each)' },
      { value: 'linear_m', label: 'Linear (length)' },
      { value: 'area', label: 'Area (m²)' },
    ];
  }
}

/**
 * Sync CatalogItemProductTypes relationships
 * 
 * @param catalogItemId - The catalog item ID
 * @param selectedProductTypeIds - Array of product type IDs to associate
 * @param primaryProductTypeId - The primary product type ID (must be in selectedProductTypeIds)
 * @param organizationId - Organization ID
 */
export async function syncCatalogItemProductTypes(
  catalogItemId: string,
  selectedProductTypeIds: string[],
  primaryProductTypeId: string | null,
  organizationId: string
): Promise<void> {
  if (!catalogItemId || !organizationId) {
    throw new Error('catalogItemId and organizationId are required');
  }

  // Validate primary is in selected list
  if (primaryProductTypeId && !selectedProductTypeIds.includes(primaryProductTypeId)) {
    throw new Error('Primary product type must be in selected product types');
  }

  // Get existing relationships
  const { data: existingRelations, error: fetchError } = await supabase
    .from('CatalogItemProductTypes')
    .select('id, product_type_id, is_primary, deleted')
    .eq('catalog_item_id', catalogItemId)
    .eq('organization_id', organizationId);

  if (fetchError) {
    throw new Error(`Error fetching existing relationships: ${fetchError.message}`);
  }

  const existingRelationsMap = new Map(
    (existingRelations || []).map(rel => [rel.product_type_id, rel])
  );

  // Determine what to insert, update, or delete
  const toInsert: string[] = [];
  const toUpdate: Array<{ id: string; is_primary: boolean; deleted: boolean }> = [];
  const toDelete: Array<{ id: string }> = [];

  // Process selected product types
  for (const productTypeId of selectedProductTypeIds) {
    const existing = existingRelationsMap.get(productTypeId);
    const isPrimary = productTypeId === primaryProductTypeId;

    if (existing) {
      // Update existing relationship
      if (existing.deleted || existing.is_primary !== isPrimary) {
        toUpdate.push({
          id: existing.id,
          is_primary: isPrimary,
          deleted: false,
        });
      }
    } else {
      // Insert new relationship
      toInsert.push(productTypeId);
    }
  }

  // Mark as deleted any existing relationships not in selected list
  for (const [productTypeId, existing] of existingRelationsMap.entries()) {
    if (!selectedProductTypeIds.includes(productTypeId) && !existing.deleted) {
      toDelete.push({ id: existing.id });
    }
  }

  // Execute operations
  // 1. Delete (soft delete)
  if (toDelete.length > 0) {
    const { error: deleteError } = await supabase
      .from('CatalogItemProductTypes')
      .update({ deleted: true })
      .in('id', toDelete.map(d => d.id));

    if (deleteError) {
      throw new Error(`Error deleting relationships: ${deleteError.message}`);
    }
  }

  // 2. Update existing
  for (const update of toUpdate) {
    const { error: updateError } = await supabase
      .from('CatalogItemProductTypes')
      .update({
        is_primary: update.is_primary,
        deleted: false,
      })
      .eq('id', update.id);

    if (updateError) {
      throw new Error(`Error updating relationship: ${updateError.message}`);
    }
  }

  // 3. Insert new
  if (toInsert.length > 0) {
    // First, ensure only one primary exists (set all others to false)
    if (primaryProductTypeId) {
      const { error: clearPrimaryError } = await supabase
        .from('CatalogItemProductTypes')
        .update({ is_primary: false })
        .eq('catalog_item_id', catalogItemId)
        .eq('organization_id', organizationId)
        .neq('product_type_id', primaryProductTypeId);

      if (clearPrimaryError) {
        throw new Error(`Error clearing primary flags: ${clearPrimaryError.message}`);
      }
    }

    // Insert new relationships
    const insertData = toInsert.map(productTypeId => ({
      organization_id: organizationId,
      catalog_item_id: catalogItemId,
      product_type_id: productTypeId,
      is_primary: productTypeId === primaryProductTypeId,
      deleted: false,
    }));

    const { error: insertError } = await supabase
      .from('CatalogItemProductTypes')
      .insert(insertData);

    if (insertError) {
      throw new Error(`Error inserting relationships: ${insertError.message}`);
    }
  }

  // Final step: Ensure only one primary exists
  if (primaryProductTypeId) {
    const { error: ensurePrimaryError } = await supabase
      .from('CatalogItemProductTypes')
      .update({ is_primary: false })
      .eq('catalog_item_id', catalogItemId)
      .eq('organization_id', organizationId)
      .neq('product_type_id', primaryProductTypeId);

    if (ensurePrimaryError) {
      throw new Error(`Error ensuring single primary: ${ensurePrimaryError.message}`);
    }

    const { error: setPrimaryError } = await supabase
      .from('CatalogItemProductTypes')
      .update({ is_primary: true })
      .eq('catalog_item_id', catalogItemId)
      .eq('organization_id', organizationId)
      .eq('product_type_id', primaryProductTypeId);

    if (setPrimaryError) {
      throw new Error(`Error setting primary: ${setPrimaryError.message}`);
    }
  }
}

