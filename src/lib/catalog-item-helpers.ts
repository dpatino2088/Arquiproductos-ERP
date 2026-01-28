/**
 * Catalog Item Helpers
 * Utility functions for catalog item operations
 */

import { supabase } from './supabase/client';

/**
 * Get allowed UOM options based on is_fabric and measure_basis
 * 
 * Rules:
 * - If is_fabric=true (only for 'roll' items):
 *   - measure_basis allowed: 'linear' or 'area'
 *   - If measure_basis='linear' -> uom: ['yd', 'm', 'ft']
 *   - If measure_basis='area' -> uom: ['m2']
 * - If is_fabric=false:
 *   - If measure_basis='unit' (for 'component') -> uom: ['ea', 'pcs', 'set', 'pair']
 *   - If measure_basis='linear' (for 'linear_component') -> uom: ['m', 'ft', 'yd'] (default: 'm')
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
    // Fabrics (only for 'roll' items): only linear or area
    if (normalized === 'linear' || normalized === 'linear_m') { // Support both for backward compatibility
      return ['m', 'yd', 'ft'];
    }
    if (normalized === 'area') {
      return ['m2']; // Could add 'yd2' if needed
    }
    return []; // Invalid measure_basis for fabric
  } else {
    // Non-fabric items (component or linear_component)
    if (normalized === 'unit') {
      // For 'component' items
      return ['ea', 'pcs', 'set', 'pair'];
    }
    if (normalized === 'linear' || normalized === 'linear_m') {
      // For 'linear_component' items (default UOM: 'm', no conversion)
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
      { value: 'linear', label: 'Linear (length)' }, // NEW SCHEMA: 'linear' (not 'linear_m')
      { value: 'area', label: 'Area (m²)' },
    ];
  } else {
    return [
      { value: 'unit', label: 'Unit (each)' },
      { value: 'linear', label: 'Linear (length)' }, // NEW SCHEMA: 'linear' (not 'linear_m')
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

  // NOTE: CatalogItemProductTypes in DB has simplified structure:
  // - id, organization_id, catalog_item_id, product_type_id, created_at
  // - NO is_primary, NO deleted columns
  // Strategy: delete all existing relations and re-insert selected ones (simpler)

  try {
    // 1. Delete ALL existing relationships for this item
    const { error: deleteError } = await supabase
      .from('CatalogItemProductTypes')
      .delete()
      .eq('catalog_item_id', catalogItemId)
      .eq('organization_id', organizationId);

    if (deleteError) {
      console.warn('⚠️ Could not delete existing ProductTypes relations:', deleteError.message);
      // Continue anyway - maybe there were no existing relations
    }

    // 2. Insert new relationships (if any selected)
    if (selectedProductTypeIds.length > 0) {
      const insertData = selectedProductTypeIds.map(productTypeId => ({
        organization_id: organizationId,
        catalog_item_id: catalogItemId,
        product_type_id: productTypeId,
        // NOTE: is_primary removed (not in DB schema)
      }));

      const { error: insertError } = await supabase
        .from('CatalogItemProductTypes')
        .insert(insertData);

      if (insertError) {
        throw new Error(`Error inserting ProductTypes: ${insertError.message}`);
      }

      if (import.meta.env.DEV) {
        console.log(`✅ Synced ${selectedProductTypeIds.length} ProductType(s) for item ${catalogItemId}`);
      }
    } else {
      if (import.meta.env.DEV) {
        console.log(`✅ Cleared all ProductTypes for item ${catalogItemId}`);
      }
    }
  } catch (err: any) {
    console.error('❌ Error syncing ProductTypes:', err);
    throw err;
  }
}

