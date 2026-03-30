import { supabase } from './supabase/client';

interface TransitionResult {
  ok: boolean;
  from?: string;
  to?: string;
  error?: string;
}

/**
 * Progressively advance MO status when a work order task is started.
 * draft/confirmed/procurement/materials_ready → in_production
 * Also issues materials from default warehouse.
 */
export async function advanceMOOnTaskStart(
  moId: string,
  onError?: (msg: string) => void,
): Promise<void> {
  try {
    const { data: mo } = await supabase
      .from('ManufacturingOrders')
      .select('status, organization_id')
      .eq('id', moId)
      .single();
    if (!mo) return;

    const current = mo.status as string;
    const preProductionStates = ['draft', 'confirmed', 'procurement', 'materials_ready', 'planned'];
    if (!preProductionStates.includes(current)) return;

    // Progressive advance: step through intermediate states to reach in_production
    const stepsToProduction: string[] = [];
    if (current === 'draft') stepsToProduction.push('confirmed', 'materials_ready', 'in_production');
    else if (current === 'confirmed') stepsToProduction.push('materials_ready', 'in_production');
    else if (current === 'procurement') stepsToProduction.push('materials_ready', 'in_production');
    else if (current === 'materials_ready') stepsToProduction.push('in_production');
    else if (current === 'planned') stepsToProduction.push('in_production');

    for (const step of stepsToProduction) {
      const { data, error } = await supabase.rpc('transition_mo_status', {
        p_mo_id: moId,
        p_new_status: step,
        p_user_id: '00000000-0000-0000-0000-000000000000',
        p_user_name: 'System (auto-start)',
      });
      if (error) {
        onError?.(`Failed to advance MO: ${error.message}`);
        return;
      }
      const result = data as TransitionResult;
      if (!result?.ok) {
        onError?.(result?.error ?? `Cannot advance MO to ${step}`);
        return;
      }
    }

    // Issue materials from default warehouse
    if (mo.organization_id) {
      const { data: wh } = await supabase
        .from('Warehouses')
        .select('id')
        .eq('organization_id', mo.organization_id)
        .eq('is_default', true)
        .limit(1)
        .maybeSingle();
      if (wh) {
        await supabase.rpc('issue_materials_for_manufacturing_order', {
          p_manufacturing_order_id: moId,
          p_warehouse_id: wh.id,
        }).catch(() => {});
      }
    }
  } catch (err) {
    onError?.((err as Error).message ?? 'Failed to advance MO status');
  }
}

/**
 * Auto-advance MO to quality_check when all tasks are completed.
 * Validates that MO is currently in_production before transitioning.
 */
export async function advanceMOOnAllTasksComplete(
  moId: string,
  onError?: (msg: string) => void,
): Promise<void> {
  try {
    const { data: mo } = await supabase
      .from('ManufacturingOrders')
      .select('status')
      .eq('id', moId)
      .single();
    if (!mo) return;

    if (mo.status !== 'in_production') {
      // MO is not in production — try to advance it first
      if (['draft', 'confirmed', 'procurement', 'materials_ready', 'planned'].includes(mo.status)) {
        await advanceMOOnTaskStart(moId, onError);
      }
    }

    const { data, error } = await supabase.rpc('transition_mo_status', {
      p_mo_id: moId,
      p_new_status: 'quality_check',
      p_user_id: '00000000-0000-0000-0000-000000000000',
      p_user_name: 'System (all tasks complete)',
    });
    if (error) {
      onError?.(`Failed to advance MO to QC: ${error.message}`);
      return;
    }
    const result = data as TransitionResult;
    if (!result?.ok) {
      onError?.(result?.error ?? 'Cannot advance MO to quality_check');
    }
  } catch (err) {
    onError?.((err as Error).message ?? 'Failed to advance MO to QC');
  }
}
