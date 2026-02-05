import { supabase } from './supabase/client';

export interface QuoteLineBOMSelectionParams {
  organizationId: string;
  quoteLineId: string;
  componentRole: string;
  catalogItemId: string;
}

export interface QuoteLineBOMSelectionKey {
  organizationId: string;
  quoteLineId: string;
  componentRole: string;
}

function isMissingConstraintError(error: any): boolean {
  const message = String(error?.message || '').toLowerCase();
  return message.includes('no unique') || message.includes('no unique or exclusion constraint');
}

function isUuid(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  const v = value.trim();
  // Accept any RFC4122 UUID version (1-5)
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
}

export async function upsertQuoteLineBOMSelection(params: QuoteLineBOMSelectionParams) {
  const { organizationId, quoteLineId, componentRole, catalogItemId } = params;

  console.log('[BOM] saveSelection called', {
    organization_id: organizationId,
    quote_line_id: quoteLineId,
    component_role: componentRole,
    catalog_item_id: catalogItemId,
  });

  if (!quoteLineId) {
    throw new Error('BOM selection blocked: quote_line_id is missing');
  }

  if (!isUuid(quoteLineId)) {
    throw new Error(`BOM selection blocked: quote_line_id is not a UUID (${quoteLineId})`);
  }
  if (!isUuid(catalogItemId)) {
    throw new Error(`BOM selection blocked: catalog_item_id is not a UUID (${catalogItemId})`);
  }

  if (import.meta.env.DEV) {
    console.debug('[QuoteLineBOMSelections] UPSERT', {
      organizationId,
      quoteLineId,
      componentRole,
      catalogItemId,
    });
  }

  const { error } = await supabase
    .from('QuoteLineBOMSelections')
    .upsert(
      {
        organization_id: organizationId,
        quote_line_id: quoteLineId,
        component_role: componentRole,
        catalog_item_id: catalogItemId,
      },
      { onConflict: 'quote_line_id,component_role' }
    );

  // Tabla eliminada: no fallar
  if (error?.message?.includes('does not exist') || error?.code === '42P01') {
    if (import.meta.env.DEV) console.warn('[QuoteLineBOMSelections] Table dropped, skipping upsert');
    return;
  }

  if (!error) {
    // DEV-only verification: makes "silent no-row" issues obvious.
    if (import.meta.env.DEV) {
      const { data: verify, error: verifyError } = await supabase
        .from('QuoteLineBOMSelections')
        .select('id, quote_line_id, component_role, catalog_item_id')
        .eq('organization_id', organizationId)
        .eq('quote_line_id', quoteLineId)
        .eq('component_role', componentRole)
        .maybeSingle();
      if (verifyError) {
        console.warn('[QuoteLineBOMSelections] verify failed', verifyError);
      } else if (!verify?.id) {
        console.warn('[QuoteLineBOMSelections] verify: no row returned after upsert', {
          organizationId,
          quoteLineId,
          componentRole,
          catalogItemId,
        });
      } else {
        console.debug('[QuoteLineBOMSelections] verify ok', verify);
      }
    }
    return;
  }

  if (!isMissingConstraintError(error)) {
    throw error;
  }

  // Manual upsert fallback if unique constraint isn't available.
  const { data: existing, error: selectError } = await supabase
    .from('QuoteLineBOMSelections')
    .select('id')
    .eq('organization_id', organizationId)
    .eq('quote_line_id', quoteLineId)
    .eq('component_role', componentRole)
    .maybeSingle();

  if (selectError) throw selectError;

  if (existing?.id) {
    const { error: updateError } = await supabase
      .from('QuoteLineBOMSelections')
      .update({ catalog_item_id: catalogItemId })
      .eq('id', existing.id);
    if (updateError) throw updateError;
    return;
  }

  const { error: insertError } = await supabase
    .from('QuoteLineBOMSelections')
    .insert({
      organization_id: organizationId,
      quote_line_id: quoteLineId,
      component_role: componentRole,
      catalog_item_id: catalogItemId,
    });

  if (insertError) throw insertError;
}

export async function deleteQuoteLineBOMSelection(params: QuoteLineBOMSelectionKey) {
  const { organizationId, quoteLineId, componentRole } = params;

  if (!quoteLineId) {
    throw new Error('BOM selection delete blocked: quote_line_id is missing');
  }
  if (!isUuid(quoteLineId)) {
    throw new Error(`BOM selection delete blocked: quote_line_id is not a UUID (${quoteLineId})`);
  }

  if (import.meta.env.DEV) {
    console.debug('[QuoteLineBOMSelections] DELETE', {
      organizationId,
      quoteLineId,
      componentRole,
    });
  }

  const { error } = await supabase
    .from('QuoteLineBOMSelections')
    .delete()
    .eq('organization_id', organizationId)
    .eq('quote_line_id', quoteLineId)
    .eq('component_role', componentRole);

  if (error?.message?.includes('does not exist') || error?.code === '42P01') return;
  if (error) throw error;
}

export async function listQuoteLineBOMSelections(params: {
  organizationId: string;
  quoteLineId: string;
}) {
  const { organizationId, quoteLineId } = params;

  const { data, error } = await supabase
    .from('QuoteLineBOMSelections')
    .select('component_role, catalog_item_id')
    .eq('organization_id', organizationId)
    .eq('quote_line_id', quoteLineId);

  if (error?.message?.includes('does not exist') || error?.code === '42P01') return [];
  if (error) throw error;
  return data || [];
}
