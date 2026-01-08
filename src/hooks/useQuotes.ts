import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { Quote, QuoteLine } from '../types/catalog';

/**
 * Hook principal para obtener quotes
 * Query simplificada para evitar problemas con funciones de DB
 */
export function useQuotes() {
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

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

        // Query simplificada: solo campos básicos de Quotes
        // Los JOINs se hacen después para evitar problemas con funciones de DB
        const { data: quotesData, error: quotesError } = await supabase
          .from('Quotes')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('updated_at', { ascending: false, nullsFirst: false })
          .order('created_at', { ascending: false });

        if (quotesError) {
          console.error('[useQuotes] Error fetching Quotes:', quotesError);
          throw quotesError;
        }

        if (!quotesData || quotesData.length === 0) {
          setQuotes([]);
          return;
        }

        // Obtener customer names por separado
        const customerIds = [...new Set(
          quotesData
            .map(q => q.customer_id)
            .filter((id): id is string => !!id)
        )];

        let customersMap = new Map<string, { id: string; customer_name: string }>();
        if (customerIds.length > 0) {
          const { data: customersData } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name')
            .in('id', customerIds)
            .eq('deleted', false);

          if (customersData) {
            customersMap = new Map(
              customersData.map(c => [c.id, { id: c.id, customer_name: c.customer_name }])
            );
          }
        }

        // Obtener QuoteLines por separado
        const quoteIds = quotesData.map(q => q.id);
        let quoteLinesMap = new Map<string, Array<{ id: string; line_total: number; deleted: boolean }>>();
        
        if (quoteIds.length > 0) {
          const { data: linesData } = await supabase
            .from('QuoteLines')
            .select('id, quote_id, line_total, deleted')
            .in('quote_id', quoteIds)
            .eq('deleted', false);

          if (linesData) {
            linesData.forEach(line => {
              if (!quoteLinesMap.has(line.quote_id)) {
                quoteLinesMap.set(line.quote_id, []);
              }
              quoteLinesMap.get(line.quote_id)!.push({
                id: line.id,
                line_total: line.line_total,
                deleted: line.deleted
              });
            });
          }
        }

        // Enriquecer quotes con datos relacionados
        const enrichedQuotes = quotesData.map(quote => ({
          ...quote,
          DirectoryCustomers: quote.customer_id ? customersMap.get(quote.customer_id) || null : null,
          QuoteLines: quoteLinesMap.get(quote.id) || []
        }));

        setQuotes(enrichedQuotes as Quote[]);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quotes';
        console.error('[useQuotes] Error:', errorMessage);
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchQuotes();
  }, [activeOrganizationId, refreshTrigger]);

  return { quotes, loading, error, refetch };
}

/**
 * Hook para obtener quotes aprobadas con progreso
 */
export function useApprovedQuotesWithProgress() {
  const [quotes, setQuotes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

  useEffect(() => {
    async function fetchApprovedQuotes() {
      if (!activeOrganizationId) {
        setLoading(false);
        setQuotes([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Query simplificada: solo quotes aprobadas
        const { data: quotesData, error: quotesError } = await supabase
          .from('Quotes')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('status', 'approved')
          .eq('deleted', false)
          .order('updated_at', { ascending: false, nullsFirst: false })
          .order('created_at', { ascending: false });

        if (quotesError) {
          console.error('[useApprovedQuotesWithProgress] Error fetching Quotes:', quotesError);
          throw quotesError;
        }

        if (!quotesData || quotesData.length === 0) {
          setQuotes([]);
          return;
        }

        // Obtener customer names
        const customerIds = [...new Set(
          quotesData
            .map(q => q.customer_id)
            .filter((id): id is string => !!id)
        )];

        let customersMap = new Map<string, { id: string; customer_name: string }>();
        if (customerIds.length > 0) {
          const { data: customersData } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name')
            .in('id', customerIds)
            .eq('deleted', false);

          if (customersData) {
            customersMap = new Map(
              customersData.map(c => [c.id, { id: c.id, customer_name: c.customer_name }])
            );
          }
        }

        // Obtener QuoteLines
        const quoteIds = quotesData.map(q => q.id);
        let quoteLinesMap = new Map<string, Array<{ id: string; line_total: number; deleted: boolean }>>();
        
        if (quoteIds.length > 0) {
          const { data: linesData } = await supabase
            .from('QuoteLines')
            .select('id, quote_id, line_total, deleted')
            .in('quote_id', quoteIds)
            .eq('deleted', false);

          if (linesData) {
            linesData.forEach(line => {
              if (!quoteLinesMap.has(line.quote_id)) {
                quoteLinesMap.set(line.quote_id, []);
              }
              quoteLinesMap.get(line.quote_id)!.push({
                id: line.id,
                line_total: line.line_total,
                deleted: line.deleted
              });
            });
          }
        }

        // Obtener SalesOrders
        const quoteIdsForSO = quotesData.map(q => q.id);
        let saleOrdersMap = new Map<string, any[]>();
        
        if (quoteIdsForSO.length > 0) {
          const { data: saleOrdersData } = await supabase
            .from('SalesOrders')
            .select('id, quote_id, sale_order_no, order_progress_status, status, organization_id')
            .in('quote_id', quoteIdsForSO)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          if (saleOrdersData) {
            saleOrdersData.forEach(so => {
              if (so.quote_id) {
                if (!saleOrdersMap.has(so.quote_id)) {
                  saleOrdersMap.set(so.quote_id, []);
                }
                saleOrdersMap.get(so.quote_id)!.push(so);
              }
            });
          }
        }

        // Enriquecer quotes
        const enrichedQuotes = quotesData.map(quote => {
          const saleOrders = saleOrdersMap.get(quote.id) || [];
          const firstSO = saleOrders.length > 0 ? saleOrders[0] : null;

          return {
            ...quote,
            DirectoryCustomers: quote.customer_id ? customersMap.get(quote.customer_id) || null : null,
            QuoteLines: quoteLinesMap.get(quote.id) || [],
            SaleOrders: saleOrders,
            saleOrderNo: firstSO?.sale_order_no || null,
            saleOrderStatus: firstSO?.status || null,
            orderProgressStatus: firstSO?.order_progress_status || null,
            saleOrderId: firstSO?.id || null,
          };
        });

        setQuotes(enrichedQuotes);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading approved quotes';
        console.error('[useApprovedQuotesWithProgress] Error:', errorMessage);
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchApprovedQuotes();
  }, [activeOrganizationId, refreshTrigger]);

  return { quotes, loading, error, refetch };
}

/**
 * Hook para obtener líneas de una quote específica
 */
export function useQuoteLines(quoteId: string | null) {
  const [lines, setLines] = useState<QuoteLine[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

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

        // Query simplificada: solo QuoteLines básicos
        const { data, error: queryError } = await supabase
          .from('QuoteLines')
          .select('*')
          .eq('quote_id', quoteId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        if (queryError) {
          console.error('[useQuoteLines] Error fetching QuoteLines:', queryError);
          throw queryError;
        }

        // Enriquecer con CatalogItems si es necesario (query separada)
        if (data && data.length > 0) {
          const catalogItemIds = [...new Set(
            data
              .map(line => line.catalog_item_id)
              .filter((id): id is string => !!id)
          )];

          let catalogItemsMap = new Map<string, any>();
          if (catalogItemIds.length > 0) {
            const { data: catalogItemsData } = await supabase
              .from('CatalogItems')
              .select('id, item_name, sku, uom, cost_exw, default_margin_pct, msrp, measure_basis, item_type, metadata')
              .in('id', catalogItemIds)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);

            if (catalogItemsData) {
              catalogItemsMap = new Map(
                catalogItemsData.map(item => [item.id, item])
              );
            }
          }

          // Enriquecer líneas con CatalogItems
          const enrichedLines = data.map(line => ({
            ...line,
            CatalogItems: line.catalog_item_id ? catalogItemsMap.get(line.catalog_item_id) || null : null
          }));

          setLines(enrichedLines as QuoteLine[]);
        } else {
          setLines([]);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quote lines';
        console.error('[useQuoteLines] Error:', errorMessage);
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchLines();
  }, [activeOrganizationId, quoteId, refreshTrigger]);

  return { lines, loading, error, refetch };
}

/**
 * Hook para crear una nueva quote
 */
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
        if (error.code === '23505' || error.message?.includes('duplicate key')) {
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

/**
 * Hook para actualizar una quote
 */
export function useUpdateQuote() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateQuote = async (id: string, quoteData: Partial<Quote>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      // Verificar duplicados de quote_no si se está cambiando
      if (quoteData.quote_no) {
        const { data: existingQuote } = await supabase
          .from('Quotes')
          .select('id, quote_no')
          .eq('id', id)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();

        if (existingQuote && existingQuote.quote_no !== quoteData.quote_no) {
          const { data: conflictingQuote } = await supabase
            .from('Quotes')
            .select('id')
            .eq('quote_no', quoteData.quote_no)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .neq('id', id)
            .maybeSingle();

          if (conflictingQuote) {
            throw new Error(`Quote number "${quoteData.quote_no}" already exists. Please use a different quote number.`);
          }
        }
      }

      const { data, error } = await supabase
        .from('Quotes')
        .update(quoteData)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId)
        .select()
        .single();

      if (error) {
        if (error.code === '23505' || error.message?.includes('duplicate key')) {
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

/**
 * Hook para crear una línea de quote
 */
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
        console.error('[useCreateQuoteLine] Error:', error);
        throw error;
      }

      return data;
    } catch (err) {
      console.error('[useCreateQuoteLine] Error:', err);
      throw err;
    } finally {
      setIsCreating(false);
    }
  };

  return { createLine, isCreating };
}

/**
 * Hook para actualizar una línea de quote
 */
export function useUpdateQuoteLine() {
  const [isUpdating, setIsUpdating] = useState(false);

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
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateLine, isUpdating };
}

/**
 * Hook para eliminar una línea de quote
 */
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

/**
 * Normaliza el status para comparación consistente
 */
export function normalizeStatus(status?: string): string {
  return status?.trim().toLowerCase() ?? '';
}

/**
 * Espera a que se cree un SalesOrder usando polling
 */
export async function waitForSalesOrder(
  quoteId: string,
  organizationId: string,
  opts?: { timeoutMs?: number; intervalMs?: number }
): Promise<{ id: string; sale_order_no: string } | null> {
  const timeoutMs = opts?.timeoutMs ?? 8000;
  const intervalMs = opts?.intervalMs ?? 250;
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    const { data, error } = await supabase
      .from('SalesOrders')
      .select('id, sale_order_no')
      .eq('quote_id', quoteId)
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .maybeSingle();

    if (error) {
      console.warn('[waitForSalesOrder] Error querying SalesOrders:', error);
    } else if (data?.id) {
      return data;
    }

    await new Promise(r => setTimeout(r, intervalMs));
  }

  console.warn('[waitForSalesOrder] Timeout reached, SalesOrder not found', { quoteId });
  return null;
}

/**
 * Aprueba una quote actualizando su status a 'approved'
 */
export async function approveQuote(quoteId: string, organizationId: string): Promise<Quote> {
  if (!organizationId) {
    throw new Error('Organization ID is required');
  }

  console.log('[approveQuote] Approving quote', { quoteId, organizationId });

  const { data, error } = await supabase
    .from('Quotes')
    .update({
      status: 'approved',
      updated_at: new Date().toISOString(),
    })
    .eq('id', quoteId)
    .eq('organization_id', organizationId)
    .select('id, status, updated_at')
    .single();

  if (error) {
    console.error('[approveQuote] Error updating Quotes.status:', error);
    throw new Error(`Failed to approve quote: ${error.message}`);
  }

  if (!data) {
    throw new Error('Quote not found or you do not have permission to update it');
  }

  console.log('[approveQuote] Quote approved successfully', {
    quoteId: data.id,
    status: data.status,
    updated_at: data.updated_at,
  });

  // Esperar a que se cree el SalesOrder
  const salesOrder = await waitForSalesOrder(quoteId, organizationId);

  if (salesOrder) {
    console.log('[approveQuote] SalesOrder created by trigger', {
      salesOrderId: salesOrder.id,
      saleOrderNo: salesOrder.sale_order_no,
    });
  } else {
    console.warn('[approveQuote] SalesOrder not found after polling timeout');
  }

  // Retornar quote completa
  const { data: fullQuote, error: fetchError } = await supabase
    .from('Quotes')
    .select('*')
    .eq('id', quoteId)
    .single();

  if (fetchError) {
    console.error('[approveQuote] Error fetching full quote:', fetchError);
    throw new Error(`Failed to fetch updated quote: ${fetchError.message}`);
  }

  return fullQuote as Quote;
}
