import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { Quote, QuoteLine } from '../types/catalog';

export function useQuotes() {
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchQuotes() {
      if (!activeOrganizationId) {
        setLoading(false);
        setQuotes([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('Quotes')
          .select(`
            *,
            DirectoryCustomers:customer_id (
              id,
              customer_name
            ),
            QuoteLines (
              id,
              line_total,
              deleted
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Quotes:', queryError.message);
          }
          throw queryError;
        }

        setQuotes(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quotes';
        if (import.meta.env.DEV) {
          console.error('Error fetching Quotes:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchQuotes();
  }, [activeOrganizationId, refreshTrigger]);

  return { quotes, loading, error, refetch };
}

export function useQuoteLines(quoteId: string | null) {
  const [lines, setLines] = useState<QuoteLine[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchLines() {
      if (!activeOrganizationId || !quoteId) {
        setLoading(false);
        setLines([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Use automatic JOINs with proper aliases to avoid collision
        // Join CatalogItems twice: once for catalog_item_id, once for operating_system_drive_id
        // Note: Collection JOIN may fail if FK doesn't exist, so we'll handle it separately
        let { data, error: queryError } = await supabase
          .from('QuoteLines')
          .select(`
            *,
            Item:catalog_item_id (
              id,
              name,
              sku,
              metadata,
              item_type
            ),
            SystemDriveItem:operating_system_drive_id (
              id,
              name,
              sku
            )
          `)
          .eq('quote_id', quoteId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching QuoteLines:', queryError.message);
          }
          throw queryError;
        }

        // Manually fetch Collection and enrich data (FK may not be configured for automatic JOIN)
        if (data && data.length > 0) {
          const collectionIds = data
            .map((line: any) => line.collection_id)
            .filter((id: string | null) => id)
            .filter((id: string, index: number, self: string[]) => self.indexOf(id) === index);
          
          if (collectionIds.length > 0) {
            const { data: collectionsData } = await supabase
              .from('CatalogCollections')
              .select('id, name')
              .in('id', collectionIds)
              .eq('deleted', false);
            
            if (collectionsData) {
              const collectionsMap = collectionsData.reduce((acc: Record<string, any>, coll: any) => {
                acc[coll.id] = coll;
                return acc;
              }, {});
              
              data = data.map((line: any) => ({
                ...line,
                Collection: line.collection_id ? collectionsMap[line.collection_id] : null,
              }));
            }
          }
        }

        setLines(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quote lines';
        if (import.meta.env.DEV) {
          console.error('Error fetching QuoteLines:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchLines();
  }, [activeOrganizationId, quoteId, refreshTrigger]);

  return { lines, loading, error, refetch };
}

export function useCreateQuote() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createQuote = async (quoteData: Omit<Quote, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('Quotes')
        .insert({
          ...quoteData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) {
        // Provide more user-friendly error messages
        if (error.code === '23505' || error.message?.includes('duplicate key') || error.message?.includes('unique constraint')) {
          if (error.message?.includes('quote_no')) {
            throw new Error(`Quote number "${(quoteData as any).quote_no}" already exists. Please use a different quote number.`);
          }
          throw new Error('This record already exists. Please check your input and try again.');
        }
        throw error;
      }
      return data;
    } finally {
      setIsCreating(false);
    }
  };

  return { createQuote, isCreating };
}

export function useUpdateQuote() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateQuote = async (id: string, quoteData: Partial<Quote>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('Quotes')
        .update(quoteData)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId)
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error updating quote:', error.message);
        }
        // Provide more user-friendly error messages
        if (error.code === '23505' || error.message?.includes('duplicate key') || error.message?.includes('unique constraint')) {
          if (error.message?.includes('quote_no')) {
            throw new Error(`Quote number "${(quoteData as any).quote_no}" already exists. Please use a different quote number.`);
          }
          throw new Error('This record already exists. Please check your input and try again.');
        }
        throw error;
      }
      
      if (!data) {
        throw new Error('Quote not found or you do not have permission to update it');
      }
      
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateQuote, isUpdating };
}

export function useCreateQuoteLine() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createLine = async (lineData: Omit<QuoteLine, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const insertData = {
        ...lineData,
        organization_id: activeOrganizationId,
      };
      
      const { data, error } = await supabase
        .from('QuoteLines')
        .insert(insertData)
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error creating QuoteLine:', error.message);
        }
        throw error;
      }
      
      // Automatically create QuoteLineComponent for import tax calculation
      if (data && data.catalog_item_id) {
        try {
          // Get catalog item cost_exw
          const { data: catalogItem } = await supabase
            .from('CatalogItems')
            .select('id, cost_exw')
            .eq('id', data.catalog_item_id)
            .eq('deleted', false)
            .single();

          // Create component
          await supabase
            .from('QuoteLineComponents')
            .insert({
              organization_id: activeOrganizationId,
              quote_line_id: data.id,
              catalog_item_id: data.catalog_item_id,
              qty: data.computed_qty || data.qty || 1,
              unit_cost_exw: catalogItem?.cost_exw || null,
            });

          // Trigger cost recalculation (which will use the component)
          await supabase.rpc('compute_quote_line_cost', {
            p_quote_line_id: data.id,
            p_options: {}
          });
        } catch (componentError) {
          // Log but don't fail the quote line creation
          if (import.meta.env.DEV) {
            console.warn('Could not create QuoteLineComponent (non-critical):', componentError);
          }
        }
      }
      
      return data;
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error creating QuoteLine:', err instanceof Error ? err.message : String(err));
      }
      throw err;
    } finally {
      setIsCreating(false);
    }
  };

  return { createLine, isCreating };
}

export function useUpdateQuoteLine() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateLine = async (id: string, lineData: Partial<QuoteLine>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('QuoteLines')
        .update(lineData)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;

      // Update or create QuoteLineComponent if catalog_item_id or qty changed
      if (data && (lineData.catalog_item_id !== undefined || lineData.qty !== undefined || lineData.computed_qty !== undefined)) {
        try {
          // Get current component
          const { data: existingComponent } = await supabase
            .from('QuoteLineComponents')
            .select('id, catalog_item_id')
            .eq('quote_line_id', id)
            .eq('deleted', false)
            .maybeSingle();

          const catalogItemId = lineData.catalog_item_id || data.catalog_item_id;
          const qty = lineData.computed_qty || lineData.qty || data.computed_qty || data.qty || 1;

          if (catalogItemId) {
            // Get catalog item cost_exw
            const { data: catalogItem } = await supabase
              .from('CatalogItems')
              .select('id, cost_exw')
              .eq('id', catalogItemId)
              .eq('deleted', false)
              .single();

            if (existingComponent) {
              // Update existing component
              await supabase
                .from('QuoteLineComponents')
                .update({
                  catalog_item_id: catalogItemId,
                  qty,
                  unit_cost_exw: catalogItem?.cost_exw || null,
                })
                .eq('id', existingComponent.id);
            } else {
              // Create new component
              await supabase
                .from('QuoteLineComponents')
                .insert({
                  organization_id: activeOrganizationId!,
                  quote_line_id: id,
                  catalog_item_id: catalogItemId,
                  qty,
                  unit_cost_exw: catalogItem?.cost_exw || null,
                });
            }

            // Trigger cost recalculation
            await supabase.rpc('compute_quote_line_cost', {
              p_quote_line_id: id,
              p_options: {}
            });
          }
        } catch (componentError) {
          // Log but don't fail the quote line update
          if (import.meta.env.DEV) {
            console.warn('Could not update QuoteLineComponent (non-critical):', componentError);
          }
        }
      }

      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateLine, isUpdating };
}

export function useDeleteQuoteLine() {
  const [isDeleting, setIsDeleting] = useState(false);

  const deleteLine = async (id: string) => {
    setIsDeleting(true);
    try {
      const { data, error } = await supabase
        .from('QuoteLines')
        .update({ deleted: true })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsDeleting(false);
    }
  };

  return { deleteLine, isDeleting };
}

