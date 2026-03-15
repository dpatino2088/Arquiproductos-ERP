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
import { resolveCascade, CascadeComponent } from './cascadeResolver';
import { getCascadeOrder, getDefaultDependsOn, getCascadeAxis } from './cascadePriority';

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

  // ── Phase 1: Resolve all slots to catalog items ──
  interface ResolvedSlot {
    slotId: string;
    catalogItemId: string;
    role: string;
    qty: number;
    costExw: number | null;
    measureBasis: string | null;
    isRoll: boolean;
    deltaXMm: number | null;
    deltaYMm: number | null;
    dependsOnRole: string | null;
    affectsRole: string | null;
    cutDeltaMm: number;
    cutDeltaScope: string | null;
  }
  const resolvedSlots: ResolvedSlot[] = [];

  for (const slot of template.slots) {
    let finalCatalogItemId: string | null = null;
    if (slot.catalog_item_id) {
      finalCatalogItemId = slot.catalog_item_id;
    } else {
      const normalizedRole = normalizeRole(slot.item_role);
      const userSelection = getSelectionForRole(normalizedRole, metadata.selections);
      if (userSelection) {
        finalCatalogItemId = userSelection;
      } else {
        if (import.meta.env.DEV) {
          console.warn(`[generateBomInstance] No selection for role ${normalizedRole}, skipping slot ${slot.id}`);
        }
        continue;
      }
    }

    const normalizedSlotRole = normalizeRole(slot.item_role) || slot.item_role;

    const { data: catalogItem } = await supabase
      .from('CatalogItems')
      .select('cost_exw, measure_basis, is_roll, delta_x_mm, delta_y_mm')
      .eq('id', finalCatalogItemId)
      .maybeSingle();

    resolvedSlots.push({
      slotId: slot.id,
      catalogItemId: finalCatalogItemId,
      role: normalizedSlotRole,
      qty: slot.qty,
      costExw: catalogItem?.cost_exw ?? null,
      measureBasis: catalogItem?.measure_basis ?? null,
      isRoll: catalogItem?.is_roll ?? false,
      deltaXMm: catalogItem?.delta_x_mm != null ? Number(catalogItem.delta_x_mm) : null,
      deltaYMm: catalogItem?.delta_y_mm != null ? Number(catalogItem.delta_y_mm) : null,
      dependsOnRole: getDefaultDependsOn(normalizedSlotRole),
      affectsRole: null,
      cutDeltaMm: 0,
      cutDeltaScope: null,
    });
  }

  // ── Phase 2: Load BOMComponents engineering rules for this template ──
  const { data: bomComps } = await supabase
    .from('BOMComponents')
    .select('id, component_role, component_item_id, depends_on_role, affects_role, cut_delta_mm, cut_delta_scope, cut_axis, sort_order, qty_value')
    .eq('bom_template_id', template.id)
    .eq('deleted', false)
    .eq('archived', false)
    .is('parent_component_id', null)
    .order('sort_order');

  if (bomComps && bomComps.length > 0) {
    for (const rs of resolvedSlots) {
      const matchingComp = bomComps.find(
        (bc: any) => bc.component_role === rs.role || bc.component_item_id === rs.catalogItemId,
      );
      if (matchingComp) {
        rs.dependsOnRole = matchingComp.depends_on_role ?? rs.dependsOnRole;
        rs.affectsRole = matchingComp.affects_role ?? null;
        rs.cutDeltaMm = Number(matchingComp.cut_delta_mm ?? 0);
        rs.cutDeltaScope = matchingComp.cut_delta_scope ?? null;
      }
    }
  }

  // ── Phase 3: Run cascade resolver ──
  const cascadeComponents: CascadeComponent[] = resolvedSlots.map(rs => ({
    id: rs.slotId,
    role: rs.role,
    depends_on_role: rs.dependsOnRole,
    affects_role: rs.affectsRole,
    cut_delta_mm: rs.cutDeltaMm,
    cut_delta_scope: rs.cutDeltaScope,
    qty: rs.qty,
    measure_basis: rs.measureBasis,
    is_roll: rs.isRoll,
    cut_axis: getCascadeAxis(rs.role) === 'y' ? 'height' : getCascadeAxis(rs.role) === 'x' ? 'width' : null,
    cascade_order: getCascadeOrder(rs.role),
    catalog_delta_x_mm: rs.deltaXMm,
    catalog_delta_y_mm: rs.deltaYMm,
  }));

  const cascadeResult = resolveCascade({
    width_mm: configState.width_mm || 0,
    height_mm: configState.height_mm || 0,
    components: cascadeComponents,
  });

  if (import.meta.env.DEV) {
    console.log('[generateBomInstance] Cascade resolution:', {
      order: cascadeResult.order,
      resolved: Object.fromEntries(
        Array.from(cascadeResult.resolved.entries()).map(([k, v]) => [k, { base: `${v.base_source}=${v.base_value_mm}`, deltas: v.deltas.length, result: v.resolved_mm }]),
      ),
    });
  }

  // ── Phase 4: Build BOM instance lines using cascade results ──
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

  for (const rs of resolvedSlots) {
    const isFabric = rs.role === 'fabric' || rs.isRoll;
    const isLinear = rs.measureBasis === 'linear' && !rs.isRoll;

    let lineUom = 'ea';
    let lineQty = rs.qty;
    let cutLengthMm: number | null = null;
    let cutWidthMm: number | null = null;
    let cutHeightMm: number | null = null;

    const cascadeCut = cascadeResult.resolved.get(rs.role);

    if (isFabric && configState.width_mm && configState.height_mm) {
      lineUom = 'm';
      const fabricWidthMm = cascadeCut ? cascadeCut.resolved_mm : configState.width_mm;
      const fabricM = calculateFabricLinearM({
        width_m: fabricWidthMm / 1000,
        height_m: configState.height_mm / 1000,
        roll_width_m: 2.8,
      });
      lineQty = Math.round(fabricM * 1000) / 1000;
      cutWidthMm = fabricWidthMm;
      cutHeightMm = configState.height_mm;
    } else if (isLinear) {
      lineUom = 'm';
      if (cascadeCut) {
        cutLengthMm = cascadeCut.resolved_mm;
        const isYAxis = getCascadeAxis(rs.role) === 'y';
        cutWidthMm = isYAxis ? (configState.width_mm || null) : cascadeCut.resolved_mm;
        cutHeightMm = isYAxis ? cascadeCut.resolved_mm : (configState.height_mm || null);
      } else {
        cutLengthMm = configState.width_mm;
        cutWidthMm = configState.width_mm;
        cutHeightMm = configState.height_mm || null;
      }
    } else {
      cutWidthMm = configState.width_mm || null;
      cutHeightMm = configState.height_mm || null;
    }

    const unitCost = rs.costExw;
    const totalCost = unitCost && lineQty ? unitCost * lineQty : null;

    linesToInsert.push({
      bom_instance_id: instanceId,
      bom_component_id: null,
      resolved_part_id: rs.catalogItemId,
      part_role: rs.role,
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
