/**
 * Terms & Conditions - RPC and helpers.
 * Backend: set_dealer_default_terms_template, resolve_default_terms_template_id
 */

import { supabase } from './supabase/client';
import type { DocTypeForTerms } from '../types/terms';
import type { DocumentTermsTemplate } from '../types/terms';

export async function setDealerDefaultTermsTemplate(
  dealerId: string,
  docType: DocTypeForTerms,
  templateId: string | null
): Promise<{ error: string | null }> {
  const { error } = await supabase.rpc('set_dealer_default_terms_template', {
    p_dealer_id: dealerId,
    p_doc_type: docType,
    p_template_id: templateId,
  });
  return { error: error?.message ?? null };
}

export async function resolveDefaultTermsTemplateId(
  orgId: string,
  dealerId: string,
  docType: DocTypeForTerms
): Promise<string | null> {
  // Direct query to DealerDocumentTermsDefaults (avoids RPC permission issues for org users)
  const { data, error } = await supabase
    .from('DealerDocumentTermsDefaults')
    .select('template_id')
    .eq('organization_id', orgId)
    .eq('dealer_id', dealerId)
    .eq('doc_type', docType)
    .maybeSingle();
  if (error) {
    console.error('[resolveDefaultTermsTemplateId]', error);
    return null;
  }
  if (data?.template_id) return data.template_id as string;

  // Fallback: try RPC (in case DealerDocumentTermsDefaults is behind RLS for some users)
  const { data: rpcData, error: rpcError } = await supabase.rpc('resolve_default_terms_template_id', {
    p_organization_id: orgId,
    p_dealer_id: dealerId,
    p_doc_type: docType,
  });
  if (!rpcError && rpcData) return rpcData as string;

  return null;
}

export async function fetchTermsTemplateById(templateId: string): Promise<DocumentTermsTemplate | null> {
  const { data, error } = await supabase
    .from('DocumentTermsTemplates')
    .select('id, organization_id, dealer_id, doc_type, title, content, is_active, created_at, updated_at')
    .eq('id', templateId)
    .maybeSingle();

  if (error) {
    console.error('[fetchTermsTemplateById]', error);
    return null;
  }
  return data as DocumentTermsTemplate | null;
}

export async function upsertTermsTemplate(payload: {
  id?: string;
  organization_id: string;
  dealer_id: string | null;
  doc_type: DocTypeForTerms;
  title: string;
  content: string;
  is_active: boolean;
}): Promise<{ id: string; error: string | null }> {
  if (payload.id) {
    const { data, error } = await supabase
      .from('DocumentTermsTemplates')
      .update({
        title: payload.title,
        content: payload.content,
        is_active: payload.is_active,
        dealer_id: payload.dealer_id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', payload.id)
      .select('id')
      .single();
    if (error) return { id: '', error: error.message };
    return { id: (data as { id: string }).id, error: null };
  } else {
    const { data, error } = await supabase
      .from('DocumentTermsTemplates')
      .insert({
        organization_id: payload.organization_id,
        dealer_id: payload.dealer_id,
        doc_type: payload.doc_type,
        title: payload.title,
        content: payload.content,
        is_active: payload.is_active,
      })
      .select('id')
      .single();
    if (error) return { id: '', error: error.message };
    return { id: (data as { id: string }).id, error: null };
  }
}
