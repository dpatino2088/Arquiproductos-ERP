import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { QuoteLineCosts, CostSettings } from '../types/pricing';

// ====================================================
// QuoteLineCosts Hooks
// ====================================================

export function useQuoteLineCosts(quoteLineId: string | null) {
  const [costs, setCosts] = useState<QuoteLineCosts | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCosts() {
      if (!activeOrganizationId || !quoteLineId) {
        setLoading(false);
        setCosts(null);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('QuoteLineCosts')
          .select('*')
          .eq('quote_line_id', quoteLineId)
          .eq('deleted', false)
          .maybeSingle();

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching QuoteLineCosts:', queryError.message);
          }
          throw queryError;
        }

        setCosts(data || null);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quote line costs';
        if (import.meta.env.DEV) {
          console.error('Error fetching QuoteLineCosts:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCosts();
  }, [activeOrganizationId, quoteLineId, refreshTrigger]);

  return { costs, loading, error, refetch };
}

export function useQuoteLineCostsByQuote(quoteId: string | null) {
  const [costs, setCosts] = useState<QuoteLineCosts[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCosts() {
      if (!activeOrganizationId || !quoteId) {
        setLoading(false);
        setCosts([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('QuoteLineCosts')
          .select('*')
          .eq('quote_id', quoteId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching QuoteLineCosts by quote:', queryError.message);
          }
          throw queryError;
        }

        setCosts(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quote line costs';
        if (import.meta.env.DEV) {
          console.error('Error fetching QuoteLineCosts by quote:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCosts();
  }, [activeOrganizationId, quoteId, refreshTrigger]);

  return { costs, loading, error, refetch };
}

export function useUpdateQuoteLineCosts() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateCosts = async (
    quoteLineId: string,
    costData: Partial<Omit<QuoteLineCosts, 'id' | 'organization_id' | 'quote_id' | 'quote_line_id' | 'created_at' | 'calculated_at'>>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      // First, get the existing costs to ensure we have the quote_line_id
      const { data: existingCosts, error: fetchError } = await supabase
        .from('QuoteLineCosts')
        .select('id, quote_line_id')
        .eq('quote_line_id', quoteLineId)
        .eq('deleted', false)
        .maybeSingle();

      if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 = not found
        throw fetchError;
      }

      // Recalculate total_cost if any cost component is being updated
      let finalCostData = { ...costData };
      
      // Check if we need to recalculate total_cost
      const needsRecalc = 
        costData.base_material_cost !== undefined ||
        costData.labor_cost !== undefined ||
        costData.shipping_cost !== undefined ||
        costData.import_tax_cost !== undefined ||
        costData.handling_cost !== undefined ||
        costData.additional_cost !== undefined;
      
      if (needsRecalc) {
        // Get current costs to calculate new total
        const { data: currentCosts } = await supabase
          .from('QuoteLineCosts')
          .select('base_material_cost, labor_cost, shipping_cost, import_tax_cost, handling_cost, additional_cost')
          .eq('quote_line_id', quoteLineId)
          .eq('deleted', false)
          .maybeSingle();

        if (currentCosts) {
          const totalCost = 
            (costData.base_material_cost ?? currentCosts.base_material_cost) +
            (costData.labor_cost ?? currentCosts.labor_cost) +
            (costData.shipping_cost ?? currentCosts.shipping_cost) +
            (costData.import_tax_cost ?? currentCosts.import_tax_cost) +
            (costData.handling_cost ?? currentCosts.handling_cost) +
            (costData.additional_cost ?? currentCosts.additional_cost);
          
          finalCostData.total_cost = totalCost;
        }
      }
      
      if (costData.is_overridden === true) {
        // Get current costs to calculate total from overrides
        const { data: currentCosts } = await supabase
          .from('QuoteLineCosts')
          .select('base_material_cost, labor_cost, shipping_cost, import_tax_cost, handling_cost, additional_cost')
          .eq('quote_line_id', quoteLineId)
          .eq('deleted', false)
          .maybeSingle();

        if (currentCosts) {
          const totalCost = 
            (costData.override_base_material_cost ?? currentCosts.base_material_cost) +
            (costData.override_labor_cost ?? currentCosts.labor_cost) +
            (costData.override_shipping_cost ?? currentCosts.shipping_cost) +
            (costData.override_import_tax_cost ?? currentCosts.import_tax_cost) +
            (costData.override_handling_cost ?? currentCosts.handling_cost) +
            (costData.override_additional_cost ?? currentCosts.additional_cost);
          
          finalCostData.total_cost = totalCost;
        }
      } else if (costData.is_overridden === false) {
        // If disabling overrides, recalculate from base costs
        // The trigger will handle this, but we can also call the function directly
        const { error: computeError } = await supabase.rpc('compute_quote_line_cost', {
          p_quote_line_id: quoteLineId
        });
        
        if (computeError) {
          console.warn('Error recomputing costs:', computeError);
        }
      }

      let result;
      if (existingCosts) {
        // Update existing
        const { data, error } = await supabase
          .from('QuoteLineCosts')
          .update(finalCostData)
          .eq('id', existingCosts.id)
          .eq('organization_id', activeOrganizationId)
          .select()
          .single();

        if (error) throw error;
        result = data;
      } else {
        // This shouldn't happen if the trigger is working, but handle it anyway
        throw new Error('QuoteLineCosts record not found. Costs should be auto-calculated when quote line is created.');
      }

      return result;
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error updating QuoteLineCosts:', err instanceof Error ? err.message : String(err));
      }
      throw err;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateCosts, isUpdating };
}

export function useRecalculateQuoteLineCosts() {
  const [isRecalculating, setIsRecalculating] = useState(false);

  const recalculateCosts = async (
    quoteLineId: string, 
    options?: { reset_labor?: boolean; reset_shipping?: boolean }
  ) => {
    setIsRecalculating(true);
    try {
      const { data, error } = await supabase.rpc('compute_quote_line_cost', {
        p_quote_line_id: quoteLineId,
        p_options: options || {}
      });

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error recalculating costs:', error.message);
        }
        throw error;
      }

      return data;
    } finally {
      setIsRecalculating(false);
    }
  };

  return { recalculateCosts, isRecalculating };
}

// ====================================================
// CostSettings Hooks
// ====================================================

export function useCostSettings() {
  const [settings, setSettings] = useState<CostSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchSettings() {
      if (!activeOrganizationId) {
        setLoading(false);
        setSettings(null);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('CostSettings')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CostSettings:', queryError.message);
          }
          throw queryError;
        }

        setSettings(data || null);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading cost settings';
        if (import.meta.env.DEV) {
          console.error('Error fetching CostSettings:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchSettings();
  }, [activeOrganizationId, refreshTrigger]);

  return { settings, loading, error, refetch };
}

export function useCreateCostSettings() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createSettings = async (
    settingsData: Omit<CostSettings, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('CostSettings')
        .insert({
          ...settingsData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error creating CostSettings:', error.message);
        }
        throw error;
      }

      return data;
    } finally {
      setIsCreating(false);
    }
  };

  return { createSettings, isCreating };
}

export function useUpdateCostSettings() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateSettings = async (
    settingsData: Partial<Omit<CostSettings, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      // CostSettings has unique constraint on organization_id, so we update by organization_id
      const { data, error } = await supabase
        .from('CostSettings')
        .update(settingsData)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .select()
        .maybeSingle();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error updating CostSettings:', error.message);
        }
        throw error;
      }

      if (!data) {
        throw new Error('CostSettings not found. Please create settings first.');
      }

      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateSettings, isUpdating };
}

