/**
 * useDealerTermsDefault - Fetch the default terms template for a dealer + doc_type.
 * Reads from DealerDocumentTermsDefaults.
 * Resolve flow: use resolve_default_terms_template_id(org_id, dealer_id, doc_type) when needed.
 */

import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { dealerTermsDefaultKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import type { DocTypeForTerms } from '../types/terms';

export interface DealerTermsDefaultResult {
  templateId: string | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

async function fetchDealerTermsDefault(
  dealerId: string,
  docType: DocTypeForTerms
): Promise<string | null> {
  const { data, error } = await supabase
    .from('DealerDocumentTermsDefaults')
    .select('template_id')
    .eq('dealer_id', dealerId)
    .eq('doc_type', docType)
    .maybeSingle();

  if (error) throw new Error(error.message);
  return data?.template_id ?? null;
}

export function useDealerTermsDefault(
  dealerId: string | null,
  docType: DocTypeForTerms
): DealerTermsDefaultResult {
  const enabled = !!dealerId && !!docType;

  const { data: templateId = null, isLoading, error, refetch } = useQuery({
    queryKey: dealerTermsDefaultKey(dealerId, docType),
    queryFn: () => fetchDealerTermsDefault(dealerId!, docType),
    enabled,
    placeholderData: keepPreviousData,
  });

  return {
    templateId,
    isLoading,
    error: error instanceof Error ? error.message : (error ? String(error) : null),
    refetch,
  };
}
