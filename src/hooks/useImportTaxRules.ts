import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { ImportTaxRule } from '../types/pricing';

// ====================================================
// ImportTaxRules Hooks
// ====================================================

export function useImportTaxRules() {
  const [rules, setRules] = useState<ImportTaxRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchRules() {
      if (!activeOrganizationId) {
        setLoading(false);
        setRules([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('ImportTaxRules')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching ImportTaxRules:', queryError.message);
          }
          throw queryError;
        }

        setRules(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading import tax rules';
        if (import.meta.env.DEV) {
          console.error('Error fetching ImportTaxRules:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchRules();
  }, [activeOrganizationId, refreshTrigger]);

  return { rules, loading, error, refetch };
}

export function useImportTaxRulesCRUD() {
  const { rules, loading, error, refetch } = useImportTaxRules();
  const { activeOrganizationId } = useOrganizationContext();

  const createRule = async (
    data: Omit<ImportTaxRule, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    const { data: result, error: err } = await supabase
      .from('ImportTaxRules')
      .insert({
        ...data,
        organization_id: activeOrganizationId,
      })
      .select()
      .single();

    if (err) {
      if (import.meta.env.DEV) {
        console.error('Error creating ImportTaxRule:', err.message);
      }
      throw err;
    }

    await refetch();
    return result;
  };

  const updateRule = async (id: string, data: Partial<ImportTaxRule>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    const { data: result, error: err } = await supabase
      .from('ImportTaxRules')
      .update(data)
      .eq('id', id)
      .eq('organization_id', activeOrganizationId)
      .select()
      .single();

    if (err) {
      if (import.meta.env.DEV) {
        console.error('Error updating ImportTaxRule:', err.message);
      }
      throw err;
    }

    await refetch();
    return result;
  };

  const deleteRule = async (id: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    // Soft delete
    const { error: err } = await supabase
      .from('ImportTaxRules')
      .update({ deleted: true })
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);

    if (err) {
      if (import.meta.env.DEV) {
        console.error('Error deleting ImportTaxRule:', err.message);
      }
      throw err;
    }

    await refetch();
  };

  return {
    rules,
    loading,
    error,
    refetch,
    createRule,
    updateRule,
    deleteRule,
  };
}













