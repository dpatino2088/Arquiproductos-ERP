import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { QuoteLineImportTaxBreakdown } from '../types/pricing';

// ====================================================
// Import Tax Breakdown Hooks
// ====================================================

export function useImportTaxBreakdown(quoteLineId: string | null) {
  const [breakdown, setBreakdown] = useState<QuoteLineImportTaxBreakdown[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchBreakdown() {
      if (!activeOrganizationId || !quoteLineId) {
        setLoading(false);
        setBreakdown([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('QuoteLineImportTaxBreakdown')
          .select('*')
          .eq('quote_line_id', quoteLineId)
          .eq('deleted', false)
          .order('category_name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching ImportTaxBreakdown:', queryError.message);
          }
          throw queryError;
        }

        setBreakdown(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading import tax breakdown';
        if (import.meta.env.DEV) {
          console.error('Error fetching ImportTaxBreakdown:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchBreakdown();
  }, [activeOrganizationId, quoteLineId, refreshTrigger]);

  return { breakdown, loading, error, refetch };
}

