/**
 * BOM Instance Service
 * 
 * Servicio centralizado para gestionar BOMInstances y BOMInstanceLines.
 * Modelo A: BOMInstances SIEMPRE se crea desde QuoteLine (quote_line_id es NOT NULL).
 */

import { supabase } from '../supabase/client';
import type {
  BOMInstance,
  BOMInstanceLine,
  GetOrCreateBomInstanceParams,
  UpsertBomLineParams,
  UpsertBomLinesParams,
} from '../../types/bom';

/**
 * Get or Create BOMInstance for QuoteLine
 * 
 * Lógica:
 * 1) Validar organizationId y quoteLineId (throw si faltan)
 * 2) Buscar BOMInstances donde quote_line_id=quoteLineId AND deleted=false LIMIT 1
 * 3) Si existe, retornar
 * 4) Si no existe, insertar BOMInstances y retornar
 */
export async function getOrCreateBomInstanceForQuoteLine(
  params: GetOrCreateBomInstanceParams
): Promise<BOMInstance> {
  const { organizationId, quoteLineId, bomTemplateId } = params;

  // Validación
  if (!organizationId) {
    throw new Error('organizationId is required');
  }
  if (!quoteLineId) {
    throw new Error('quoteLineId is required');
  }

  // 1. Buscar BOMInstance existente
  const { data: existingInstance, error: findError } = await supabase
    .from('BOMInstances')
    .select('*')
    .eq('organization_id', organizationId)
    .eq('quote_line_id', quoteLineId)
    .eq('deleted', false)
    .maybeSingle();

  if (findError) {
    console.error('[getOrCreateBomInstanceForQuoteLine] Error finding instance:', findError);
    throw new Error(findError.message || 'Error finding BOM instance');
  }

  // 2. Si existe, retornar
  if (existingInstance) {
    if (import.meta.env.DEV) {
      console.log('[getOrCreateBomInstanceForQuoteLine] Found existing instance:', existingInstance.id);
    }
    return existingInstance as BOMInstance;
  }

  // 3. Si no existe, crear nuevo
  // Validar que bomTemplateId existe si se proporciona
  if (bomTemplateId) {
    const { data: template, error: templateError } = await supabase
      .from('BOMTemplates')
      .select('id')
      .eq('id', bomTemplateId)
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .maybeSingle();

    if (templateError) {
      console.error('[getOrCreateBomInstanceForQuoteLine] Error validating template:', templateError);
      throw new Error(templateError.message || 'Error validating BOM template');
    }

    if (!template) {
      throw new Error(`BOM template ${bomTemplateId} not found or is deleted`);
    }
  }

  // Insertar nuevo BOMInstance
  const { data: newInstance, error: insertError } = await supabase
    .from('BOMInstances')
    .insert({
      organization_id: organizationId,
      quote_line_id: quoteLineId,
      bom_template_id: bomTemplateId || null, // Puede ser NULL si no se proporciona
      deleted: false,
    })
    .select()
    .single();

  if (insertError) {
    console.error('[getOrCreateBomInstanceForQuoteLine] Error creating instance:', insertError);
    throw new Error(insertError.message || 'Error creating BOM instance');
  }

  if (import.meta.env.DEV) {
    console.log('[getOrCreateBomInstanceForQuoteLine] Created new instance:', newInstance.id);
  }

  return newInstance as BOMInstance;
}

/**
 * Upsert BOM Instance Line
 * 
 * Insert or update a line in BOMInstanceLines.
 * Si id viene, actualiza; si no, inserta nuevo.
 */
export async function upsertBomLine(
  params: UpsertBomLineParams
): Promise<BOMInstanceLine> {
  const { bomInstanceId, organizationId, line } = params;

  // Validación
  if (!bomInstanceId) {
    throw new Error('bomInstanceId is required');
  }
  if (!organizationId) {
    throw new Error('organizationId is required');
  }
  if (!line.part_role) {
    throw new Error('part_role is required');
  }
  if (line.qty === undefined || line.qty === null) {
    throw new Error('qty is required');
  }
  if (!line.uom) {
    throw new Error('uom is required');
  }

  // Verificar que BOMInstance existe
  const { data: bomInstance, error: bomError } = await supabase
    .from('BOMInstances')
    .select('id')
    .eq('id', bomInstanceId)
    .eq('organization_id', organizationId)
    .eq('deleted', false)
    .maybeSingle();

  if (bomError) {
    console.error('[upsertBomLine] Error verifying BOMInstance:', bomError);
    throw new Error(bomError.message || 'Error verifying BOM instance');
  }

  if (!bomInstance) {
    throw new Error(`BOMInstance ${bomInstanceId} not found or is deleted`);
  }

  // Preparar payload
  const payload = {
    organization_id: organizationId,
    bom_instance_id: bomInstanceId,
    part_role: line.part_role,
    resolved_part_id: line.resolved_part_id || null,
    bom_component_id: line.bom_component_id || null,
    qty: line.qty,
    uom: line.uom,
    cut_length_mm: line.cut_length_mm || null,
    cut_width_mm: line.cut_width_mm || null,
    cut_height_mm: line.cut_height_mm || null,
    unit_cost_exw: line.unit_cost_exw || null,
    total_cost_exw: line.total_cost_exw || null,
    deleted: false,
  };

  if (line.id) {
    // Update existing line
    const { data: updatedLine, error: updateError } = await supabase
      .from('BOMInstanceLines')
      .update(payload)
      .eq('id', line.id)
      .eq('organization_id', organizationId)
      .eq('bom_instance_id', bomInstanceId)
      .select()
      .single();

    if (updateError) {
      console.error('[upsertBomLine] Error updating line:', updateError);
      throw new Error(updateError.message || 'Error updating BOM line');
    }

    return updatedLine as BOMInstanceLine;
  } else {
    // Insert new line
    const { data: newLine, error: insertError } = await supabase
      .from('BOMInstanceLines')
      .insert(payload)
      .select()
      .single();

    if (insertError) {
      console.error('[upsertBomLine] Error inserting line:', insertError);
      throw new Error(insertError.message || 'Error inserting BOM line');
    }

    return newLine as BOMInstanceLine;
  }
}

/**
 * Upsert Multiple BOM Lines
 * 
 * Insert or update multiple lines in BOMInstanceLines.
 */
export async function upsertBomLines(
  params: UpsertBomLinesParams
): Promise<BOMInstanceLine[]> {
  const { bomInstanceId, organizationId, lines } = params;

  if (!lines || lines.length === 0) {
    return [];
  }

  // Verificar que BOMInstance existe
  const { data: bomInstance, error: bomError } = await supabase
    .from('BOMInstances')
    .select('id')
    .eq('id', bomInstanceId)
    .eq('organization_id', organizationId)
    .eq('deleted', false)
    .maybeSingle();

  if (bomError) {
    console.error('[upsertBomLines] Error verifying BOMInstance:', bomError);
    throw new Error(bomError.message || 'Error verifying BOM instance');
  }

  if (!bomInstance) {
    throw new Error(`BOMInstance ${bomInstanceId} not found or is deleted`);
  }

  // Separar líneas para insertar y actualizar
  const linesToInsert = lines.filter((line) => !line.id);
  const linesToUpdate = lines.filter((line) => line.id);

  const results: BOMInstanceLine[] = [];

  // Insertar nuevas líneas
  if (linesToInsert.length > 0) {
    const insertPayload = linesToInsert.map((line) => ({
      organization_id: organizationId,
      bom_instance_id: bomInstanceId,
      part_role: line.part_role,
      resolved_part_id: line.resolved_part_id || null,
      bom_component_id: line.bom_component_id || null,
      qty: line.qty,
      uom: line.uom,
      cut_length_mm: line.cut_length_mm || null,
      cut_width_mm: line.cut_width_mm || null,
      cut_height_mm: line.cut_height_mm || null,
      unit_cost_exw: line.unit_cost_exw || null,
      total_cost_exw: line.total_cost_exw || null,
      deleted: false,
    }));

    const { data: insertedLines, error: insertError } = await supabase
      .from('BOMInstanceLines')
      .insert(insertPayload)
      .select();

    if (insertError) {
      console.error('[upsertBomLines] Error inserting lines:', insertError);
      throw new Error(insertError.message || 'Error inserting BOM lines');
    }

    if (insertedLines) {
      results.push(...(insertedLines as BOMInstanceLine[]));
    }
  }

  // Actualizar líneas existentes
  for (const line of linesToUpdate) {
    const updatePayload = {
      part_role: line.part_role,
      resolved_part_id: line.resolved_part_id || null,
      bom_component_id: line.bom_component_id || null,
      qty: line.qty,
      uom: line.uom,
      cut_length_mm: line.cut_length_mm || null,
      cut_width_mm: line.cut_width_mm || null,
      cut_height_mm: line.cut_height_mm || null,
      unit_cost_exw: line.unit_cost_exw || null,
      total_cost_exw: line.total_cost_exw || null,
    };

    const { data: updatedLine, error: updateError } = await supabase
      .from('BOMInstanceLines')
      .update(updatePayload)
      .eq('id', line.id!)
      .eq('organization_id', organizationId)
      .eq('bom_instance_id', bomInstanceId)
      .select()
      .single();

    if (updateError) {
      console.error('[upsertBomLines] Error updating line:', updateError);
      throw new Error(updateError.message || `Error updating BOM line ${line.id}`);
    }

    if (updatedLine) {
      results.push(updatedLine as BOMInstanceLine);
    }
  }

  return results;
}

/**
 * Get BOMInstance by QuoteLine ID
 */
export async function getBomInstanceByQuoteLine(
  organizationId: string,
  quoteLineId: string
): Promise<BOMInstance | null> {
  const { data, error } = await supabase
    .from('BOMInstances')
    .select('*')
    .eq('organization_id', organizationId)
    .eq('quote_line_id', quoteLineId)
    .eq('deleted', false)
    .maybeSingle();

  if (error) {
    console.error('[getBomInstanceByQuoteLine] Error:', error);
    throw new Error(error.message || 'Error fetching BOM instance');
  }

  return data as BOMInstance | null;
}

/**
 * Get BOMInstanceLines by BOMInstance ID
 */
export async function getBomInstanceLines(
  organizationId: string,
  bomInstanceId: string
): Promise<BOMInstanceLine[]> {
  const { data, error } = await supabase
    .from('BOMInstanceLines')
    .select('*')
    .eq('organization_id', organizationId)
    .eq('bom_instance_id', bomInstanceId)
    .eq('deleted', false)
    .order('created_at', { ascending: true });

  if (error) {
    console.error('[getBomInstanceLines] Error:', error);
    throw new Error(error.message || 'Error fetching BOM instance lines');
  }

  return (data || []) as BOMInstanceLine[];
}

/**
 * Delete BOMInstance (soft delete)
 */
export async function deleteBomInstance(
  organizationId: string,
  bomInstanceId: string
): Promise<void> {
  const { error } = await supabase
    .from('BOMInstances')
    .update({ deleted: true })
    .eq('id', bomInstanceId)
    .eq('organization_id', organizationId);

  if (error) {
    console.error('[deleteBomInstance] Error:', error);
    throw new Error(error.message || 'Error deleting BOM instance');
  }
}

/**
 * Delete BOMInstanceLine (soft delete)
 */
export async function deleteBomInstanceLine(
  organizationId: string,
  lineId: string
): Promise<void> {
  const { error } = await supabase
    .from('BOMInstanceLines')
    .update({ deleted: true })
    .eq('id', lineId)
    .eq('organization_id', organizationId);

  if (error) {
    console.error('[deleteBomInstanceLine] Error:', error);
    throw new Error(error.message || 'Error deleting BOM instance line');
  }
}
