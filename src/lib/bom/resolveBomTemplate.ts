/**
 * Resolve BOM Template by ProductType
 * 
 * Finds the matching BOMTemplate in the database based on ProductType only.
 * Also fetches the associated BOMTemplateSlots.
 */

import { supabase } from '../supabase/client';
import { BomFingerprint, BOMTemplateSlot } from './types';

export interface ResolvedBOMTemplate {
  id: string;
  organization_id: string;
  product_type_id: string;
  code: string;
  name: string;
  description: string | null;
  metadata: Record<string, any>;
  slots: BOMTemplateSlot[];
}

export type { BOMTemplateSlot } from './types';

/**
 * Resolve BOM Template by ProductType and Hardware Color
 * 
 * @param organizationId - Organization ID
 * @param productTypeId - Product Type ID (from ProductTypes)
 * @param fingerprint - Deprecated for matching (kept for compatibility)
 * @param hardwareColor - Required hardware color (White, Black, etc.) to filter templates
 * @returns Resolved template with slots, or null if not found
 */
export async function resolveBomTemplate(
  organizationId: string,
  productTypeId: string,
  _fingerprint: BomFingerprint,
  hardwareColor?: string | null
): Promise<ResolvedBOMTemplate | null> {
  if (!organizationId || !productTypeId) {
    throw new Error('organizationId and productTypeId are required');
  }

  // Normalize hardware color (trim and capitalize first letter)
  const normalizedColor = hardwareColor 
    ? hardwareColor.trim().charAt(0).toUpperCase() + hardwareColor.trim().slice(1).toLowerCase()
    : null;

  // Query BOMTemplates by ProductType and hardware_color (required)
  // Get all matching templates first for debug info
  let templatesQuery = supabase
    .from('BOMTemplates')
    .select('id, code, name, product_type_id, hardware_color')
    .eq('organization_id', organizationId)
    .eq('product_type_id', productTypeId)
    .eq('is_active', true)
    .eq('archived', false);

  // Hardware color is required - filter by it (no longer accepting NULL)
  if (normalizedColor) {
    templatesQuery = templatesQuery.eq('hardware_color', normalizedColor);
  } else {
    // If no color provided, throw error (hardware color is mandatory)
    throw new Error('hardwareColor is required to resolve BOM template');
  }

  const { data: allTemplates, error: allTemplatesError } = await templatesQuery
    .order('updated_at', { ascending: false });

  if (import.meta.env.DEV) {
    console.log('[resolveBomTemplate] Templates search:', {
      productTypeId,
      organizationId,
      hardwareColor: normalizedColor,
      templatesFound: allTemplates?.length ?? 0,
      templateDetails: allTemplates?.map(t => ({ 
        id: t.id, 
        code: t.code, 
        name: t.name,
        hardware_color: (t as any).hardware_color 
      })) || [],
    });
  }

  // Get the single template with full data (hardware color is required)
  let templateQuery = supabase
    .from('BOMTemplates')
    .select('*')
    .eq('organization_id', organizationId)
    .eq('product_type_id', productTypeId)
    .eq('is_active', true)
    .eq('archived', false);

  // Hardware color is required - filter by it
  if (normalizedColor) {
    templateQuery = templateQuery.eq('hardware_color', normalizedColor);
  } else {
    throw new Error('hardwareColor is required to resolve BOM template');
  }

  // Order by most recent
  const { data: template, error: templateError } = await templateQuery
    .order('updated_at', { ascending: false })
    .maybeSingle();

  if (templateError) {
    const errorDetails = {
      message: templateError.message,
      code: templateError.code,
      details: templateError.details,
    };
    console.error('[resolveBomTemplate] Error fetching template:', errorDetails);
    throw new Error(templateError.message || 'Error resolving BOM template');
  }

  if (!template) {
    if (import.meta.env.DEV) {
      console.warn('[resolveBomTemplate] No template found for product type:', {
        productTypeId,
        organizationId,
        templatesFound: allTemplates?.length ?? 0,
        availableTemplateIds: allTemplates?.map(t => t.id) || [],
      });
    }
    return null;
  }

  // Fetch slots for this template
  const { data: slots, error: slotsError } = await supabase
    .from('BOMTemplateSlots')
    .select('*')
    .eq('organization_id', organizationId)
    .eq('bom_template_id', template.id)
    .order('item_role', { ascending: true });

  if (slotsError) {
    const errorDetails = {
      message: slotsError.message,
      code: slotsError.code,
      details: slotsError.details,
    };
    console.error('[resolveBomTemplate] Error fetching slots:', errorDetails);
    throw new Error(slotsError.message || 'Error fetching BOM template slots');
  }

  return {
    id: template.id,
    organization_id: template.organization_id,
    product_type_id: template.product_type_id,
    code: template.code,
    name: template.name,
    description: template.description,
    metadata: template.metadata || {},
    slots: (slots || []) as BOMTemplateSlot[],
  };
}
