/**
 * useTermsTemplates - Fetch DocumentTermsTemplates for a dealer + doc_type.
 * Options for dropdown: organization_id = org, doc_type = docType,
 * (dealer_id IS NULL OR dealer_id = dealerId), is_active = true.
 * List: same filters but include inactive for management.
 */

import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { termsTemplatesListKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import type { DocumentTermsTemplate, DocTypeForTerms } from '../types/terms';

async function fetchTermsTemplates(
  organizationId: string,
  dealerId: string | null,
  docType: DocTypeForTerms
): Promise<DocumentTermsTemplate[]> {
  let query = supabase
    .from('DocumentTermsTemplates')
    .select('id, organization_id, dealer_id, doc_type, title, content, is_active, created_at, updated_at')
    .eq('organization_id', organizationId)
    .eq('doc_type', docType);

  if (dealerId) {
    query = query.or(`dealer_id.is.null,dealer_id.eq.${dealerId}`);
  } else {
    query = query.is('dealer_id', null);
  }

  const { data, error } = await query.order('updated_at', { ascending: false });
  if (error) throw new Error(error.message);
  return (data || []) as DocumentTermsTemplate[];
}

export function useTermsTemplates(
  dealerId: string | null,
  docType: DocTypeForTerms,
  organizationId: string | null
) {
  const enabled = !!organizationId && !!docType;

  const { data = [], isLoading, error, refetch } = useQuery({
    queryKey: termsTemplatesListKey(dealerId, docType),
    queryFn: () => fetchTermsTemplates(organizationId!, dealerId, docType),
    enabled,
    placeholderData: keepPreviousData,
  });

  const activeTemplates = data.filter((t) => t.is_active);
  const allTemplates = data;

  return {
    templates: allTemplates,
    activeTemplates,
    isLoading,
    error: error instanceof Error ? error.message : (error ? String(error) : null),
    refetch,
  };
}
