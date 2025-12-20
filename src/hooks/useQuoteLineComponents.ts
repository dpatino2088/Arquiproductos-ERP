import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { QuoteLineComponent } from '../types/pricing';

// ====================================================
// QuoteLineComponents Hooks
// ====================================================

export function useQuoteLineComponents(quoteLineId: string | null) {
  const [components, setComponents] = useState<QuoteLineComponent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchComponents() {
      if (!activeOrganizationId || !quoteLineId) {
        setLoading(false);
        setComponents([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('QuoteLineComponents')
          .select('*')
          .eq('quote_line_id', quoteLineId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching QuoteLineComponents:', queryError.message);
          }
          throw queryError;
        }

        setComponents(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quote line components';
        if (import.meta.env.DEV) {
          console.error('Error fetching QuoteLineComponents:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchComponents();
  }, [activeOrganizationId, quoteLineId, refreshTrigger]);

  return { components, loading, error, refetch };
}

export function useQuoteLineComponentsCRUD() {
  const { activeOrganizationId } = useOrganizationContext();

  const createComponent = async (
    quoteLineId: string,
    catalogItemId: string,
    qty: number = 1,
    unitCostExw?: number | null
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    const { data, error } = await supabase
      .from('QuoteLineComponents')
      .insert({
        organization_id: activeOrganizationId,
        quote_line_id: quoteLineId,
        catalog_item_id: catalogItemId,
        qty,
        unit_cost_exw: unitCostExw || null,
      })
      .select()
      .single();

    if (error) {
      if (import.meta.env.DEV) {
        console.error('Error creating QuoteLineComponent:', error.message);
      }
      throw error;
    }

    return data;
  };

  const createComponentFromQuoteLine = async (quoteLineId: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    // Get the quote line to extract catalog_item_id
    const { data: quoteLine, error: quoteLineError } = await supabase
      .from('QuoteLines')
      .select('id, catalog_item_id, qty, computed_qty, organization_id')
      .eq('id', quoteLineId)
      .eq('deleted', false)
      .single();

    if (quoteLineError || !quoteLine) {
      throw new Error(`QuoteLine not found: ${quoteLineError?.message || 'Not found'}`);
    }

    if (!quoteLine.catalog_item_id) {
      throw new Error('QuoteLine has no catalog_item_id');
    }

    // Get catalog item cost_exw
    const { data: catalogItem, error: catalogError } = await supabase
      .from('CatalogItems')
      .select('id, cost_exw')
      .eq('id', quoteLine.catalog_item_id)
      .eq('deleted', false)
      .single();

    if (catalogError) {
      if (import.meta.env.DEV) {
        console.warn('Could not load catalog item cost_exw, using NULL:', catalogError.message);
      }
    }

    // Check if component already exists
    const { data: existing } = await supabase
      .from('QuoteLineComponents')
      .select('id')
      .eq('quote_line_id', quoteLineId)
      .eq('catalog_item_id', quoteLine.catalog_item_id)
      .eq('deleted', false)
      .maybeSingle();

    if (existing) {
      // Update existing component
      const { data, error } = await supabase
        .from('QuoteLineComponents')
        .update({
          qty: quoteLine.computed_qty || quoteLine.qty || 1,
          unit_cost_exw: catalogItem?.cost_exw || null,
        })
        .eq('id', existing.id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } else {
      // Create new component
      return await createComponent(
        quoteLineId,
        quoteLine.catalog_item_id,
        quoteLine.computed_qty || quoteLine.qty || 1,
        catalogItem?.cost_exw || null
      );
    }
  };

  const updateComponent = async (
    componentId: string,
    data: Partial<Pick<QuoteLineComponent, 'qty' | 'unit_cost_exw'>>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    const { data: result, error } = await supabase
      .from('QuoteLineComponents')
      .update(data)
      .eq('id', componentId)
      .eq('organization_id', activeOrganizationId)
      .select()
      .single();

    if (error) {
      if (import.meta.env.DEV) {
        console.error('Error updating QuoteLineComponent:', error.message);
      }
      throw error;
    }

    return result;
  };

  const deleteComponent = async (componentId: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    // Soft delete
    const { error } = await supabase
      .from('QuoteLineComponents')
      .update({ deleted: true })
      .eq('id', componentId)
      .eq('organization_id', activeOrganizationId);

    if (error) {
      if (import.meta.env.DEV) {
        console.error('Error deleting QuoteLineComponent:', error.message);
      }
      throw error;
    }
  };

  return {
    createComponent,
    createComponentFromQuoteLine,
    updateComponent,
    deleteComponent,
  };
}





