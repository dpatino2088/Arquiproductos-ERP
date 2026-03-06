/**
 * Generate BOM Instance
 * 
 * Creates or updates a BOMInstance and its BOMInstanceLines based on
 * the resolved template, slots, and user selections.
 */

import { supabase } from '../supabase/client';
import { BOMInstanceMetadata, RollerBOMConfigState } from './types';
import { ResolvedBOMTemplate } from './resolveBomTemplate';
import { normalizeRole } from './roles';
import { calculateFabricLinearM } from './fabric-calculations';

export interface GenerateBOMInstanceParams {
  organizationId: string;
  quoteLineId: string;
  template: ResolvedBOMTemplate;
  configState: RollerBOMConfigState;
}

export interface GenerateBOMInstanceResult {
  instanceId: string;
  linesCreated: number;
}

/**
 * Generate BOM Instance from template and config
 * 
 * @param params - Generation parameters
 * @returns Created/updated instance ID and line count
 */
export async function generateBomInstance(
  params: GenerateBOMInstanceParams
): Promise<GenerateBOMInstanceResult> {
  const { organizationId, quoteLineId, template, configState } = params;

  if (!organizationId || !quoteLineId || !template) {
    throw new Error('organizationId, quoteLineId, and template are required');
  }

  // Build metadata
  const metadata: BOMInstanceMetadata = {
    measurements: {
      width_mm: configState.width_mm || 0,
      height_mm: configState.height_mm || 0,
      mount_type: configState.mount_type || null,
      location: configState.location || null,
    },
    bottom_bar_wrapped: configState.bottom_bar_wrapped,
    selections: {
      motor_item_id: configState.motor_item_id || null,
      drive_item_id: configState.drive_item_id || null,
      headbox_item_id: configState.headbox_item_id || null,
      bottom_bar_item_id: configState.bottom_bar_item_id || null,
      side_channel_item_id: configState.side_channel_item_id || null,
      bottom_channel_item_id: configState.bottom_channel_item_id || null,
      tube_item_id: configState.tube_item_id || null,
      fabric_item_id: configState.fabric_item_id || null,
    },
  };

  // Check if instance already exists (soft-delete previous if exists)
  const { data: existingInstance } = await supabase
    .from('BOMInstances')
    .select('id')
    .eq('organization_id', organizationId)
    .eq('quote_line_id', quoteLineId)
    .eq('deleted', false)
    .maybeSingle();

  let instanceId: string;

  if (existingInstance) {
    // Soft-delete existing instance and its lines
    await supabase
      .from('BOMInstances')
      .update({ deleted: true })
      .eq('id', existingInstance.id);

    // Create new instance
    const { data: newInstance, error: createError } = await supabase
      .from('BOMInstances')
      .insert({
        organization_id: organizationId,
        quote_line_id: quoteLineId,
        bom_template_id: template.id,
      })
      .select('id')
      .single();

    if (createError) {
      const errorDetails = {
        message: createError.message,
        code: createError.code,
        details: createError.details,
      };
      console.error('[generateBomInstance] Error creating instance:', errorDetails);
      throw new Error(createError.message || 'Error creating BOM instance');
    }

    instanceId = newInstance.id;
  } else {
    // Create new instance
    const { data: newInstance, error: createError } = await supabase
      .from('BOMInstances')
      .insert({
        organization_id: organizationId,
        quote_line_id: quoteLineId,
        bom_template_id: template.id,
      })
      .select('id')
      .single();

    if (createError) {
      const errorDetails = {
        message: createError.message,
        code: createError.code,
        details: createError.details,
      };
      console.error('[generateBomInstance] Error creating instance:', errorDetails);
      throw new Error(createError.message || 'Error creating BOM instance');
    }

    instanceId = newInstance.id;
  }

  // Note: BOMInstances doesn't have metadata column in current schema
  // Metadata will be stored in BOMInstanceLines or handled separately if needed

  // Process slots and create lines
  const linesToInsert: Array<{
    bom_instance_id: string;
    bom_component_id: string | null;
    resolved_part_id: string;
    part_role: string;
    qty: number;
    uom: string;
    cut_length_mm: number | null;
    cut_width_mm: number | null;
    cut_height_mm: number | null;
    unit_cost_exw: number | null;
    total_cost_exw: number | null;
  }> = [];

  for (const slot of template.slots) {
    // Determine final catalog_item_id
    let finalCatalogItemId: string | null = null;

    // a) If slot has fixed catalog_item_id, use it
    if (slot.catalog_item_id) {
      finalCatalogItemId = slot.catalog_item_id;
    } else {
      // b) Check if user selected this role
      const normalizedRole = normalizeRole(slot.item_role);
      const userSelection = getSelectionForRole(normalizedRole, metadata.selections);

      if (userSelection) {
        finalCatalogItemId = userSelection;
      } else {
        if (import.meta.env.DEV) {
          console.warn(
            `[generateBomInstance] No selection for role ${normalizedRole}, skipping slot ${slot.id}`
          );
        }
        continue;
      }
    }

    const normalizedSlotRole = normalizeRole(slot.item_role) || slot.item_role;

    // Get item details for cost and measure_basis
    const { data: catalogItem } = await supabase
      .from('CatalogItems')
      .select('cost_exw, measure_basis, is_roll')
      .eq('id', finalCatalogItemId)
      .maybeSingle();

    const isFabric = normalizedSlotRole === 'fabric' || catalogItem?.is_roll === true;
    const isLinear = catalogItem?.measure_basis === 'linear' && !catalogItem?.is_roll;

    let lineUom = 'ea';
    let lineQty = slot.qty;
    let cutLengthMm: number | null = null;
    let cutWidthMm: number | null = null;
    let cutHeightMm: number | null = null;

    if (isFabric && configState.width_mm && configState.height_mm) {
      // Fabric: UOM = m, qty = calculated linear meters, cut_width = product width
      lineUom = 'm';
      const fabricM = calculateFabricLinearM({
        width_m: configState.width_mm / 1000,
        height_m: configState.height_mm / 1000,
        roll_width_m: 2.8,
      });
      lineQty = Math.round(fabricM * 1000) / 1000;
      cutWidthMm = configState.width_mm;
      cutHeightMm = configState.height_mm;
    } else if (isLinear && configState.width_mm) {
      // Linear profiles (tube, headbox, etc.): UOM = m, cut_length = product width
      lineUom = 'm';
      cutLengthMm = configState.width_mm;
      cutWidthMm = configState.width_mm;
      cutHeightMm = configState.height_mm || null;
    } else {
      // Unit items (ea): use product dimensions as reference
      cutWidthMm = configState.width_mm || null;
      cutHeightMm = configState.height_mm || null;
    }

    const unitCost = catalogItem?.cost_exw || null;
    const totalCost = unitCost && lineQty ? unitCost * lineQty : null;

    linesToInsert.push({
      bom_instance_id: instanceId,
      bom_component_id: null,
      resolved_part_id: finalCatalogItemId,
      part_role: normalizedSlotRole,
      qty: lineQty,
      uom: lineUom,
      cut_length_mm: cutLengthMm,
      cut_width_mm: cutWidthMm,
      cut_height_mm: cutHeightMm,
      unit_cost_exw: unitCost,
      total_cost_exw: totalCost,
    });
  }

  // Insert all lines in batch
  if (linesToInsert.length > 0) {
    const { error: linesError } = await supabase
      .from('BOMInstanceLines')
      .insert(linesToInsert);

    if (linesError) {
      const errorDetails = {
        message: linesError.message,
        code: linesError.code,
        details: linesError.details,
      };
      console.error('[generateBomInstance] Error inserting lines:', errorDetails);
      throw new Error(linesError.message || 'Error creating BOM instance lines');
    }
  }

  return {
    instanceId,
    linesCreated: linesToInsert.length,
  };
}

/**
 * Helper: Get user selection for a role
 */
function getSelectionForRole(
  role: string | null,
  selections: BOMInstanceMetadata['selections']
): string | null {
  if (!role) return null;

  const roleMap: Record<string, keyof BOMInstanceMetadata['selections']> = {
    motor: 'motor_item_id',
    drive: 'drive_item_id',
    headbox: 'headbox_item_id',
    bottom_bar: 'bottom_bar_item_id',
    side_channel: 'side_channel_item_id',
    bottom_channel: 'bottom_channel_item_id',
    tube: 'tube_item_id',
    fabric: 'fabric_item_id',
  };

  const selectionKey = roleMap[role];
  if (!selectionKey) return null;

  return selections[selectionKey] || null;
}
