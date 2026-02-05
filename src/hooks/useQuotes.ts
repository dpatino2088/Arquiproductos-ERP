import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveCompany } from './useActiveCompany';
import { Quote, QuoteLine } from '../types/catalog';

/**
 * Hook principal para obtener quotes
 * IMPORTANTE: Filtra por organization_id Y company_id (si está disponible)
 * 
 * @param companyId - Opcional: si se proporciona, filtra solo por ese company_id específico
 */
export function useQuotes(companyId?: string | null) {
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeCompanyId } = useActiveCompany();
  
  // Usar companyId proporcionado o el activo del hook
  const effectiveCompanyId = companyId ?? activeCompanyId;

  // ✅ OPTIMIZACIÓN: Refetch simplificado - solo incrementar trigger y dejar que useEffect maneje todo
  const refetch = useCallback(() => {
    if (import.meta.env.DEV) {
      console.log('[useQuotes] refetch called');
    }
    // Solo incrementar trigger - el useEffect manejará loading y limpieza de datos
    setRefreshTrigger(prev => {
      const next = prev + 1;
      if (import.meta.env.DEV) {
        console.log('[useQuotes] refreshTrigger:', prev, '->', next);
      }
      return next;
    });
  }, []);

  useEffect(() => {
    let isMounted = true; // ✅ Flag para evitar actualizaciones de estado si el componente se desmonta
    
    async function fetchQuotes() {
      if (import.meta.env.DEV) {
        console.log('[useQuotes] fetchQuotes triggered', {
          activeOrganizationId,
          effectiveCompanyId,
          refreshTrigger,
        });
      }
      
      if (!activeOrganizationId) {
        if (isMounted) {
          setLoading(false);
          setQuotes([]);
          setError(null);
        }
        return;
      }

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        // Query: filtrar por organization_id Y company_id (si está disponible)
        let query = supabase
          .from('Quotes')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          // ✅ Treat NULL as not deleted (some rows may have deleted = NULL)
          .or('deleted.is.false,deleted.is.null');

        // Filtrar por company_id si está disponible
        if (effectiveCompanyId) {
          query = query.eq('company_id', effectiveCompanyId);
        } else {
          // Warning en DEV si hay quotes sin company_id
          if (import.meta.env.DEV) {
            console.warn('[useQuotes] No company_id provided. Quotes without company_id will be included.');
          }
        }

        const { data: quotesData, error: quotesError } = await query
          .order('updated_at', { ascending: false, nullsFirst: false })
          .order('created_at', { ascending: false });

        if (quotesError) {
          console.error('[useQuotes] Error fetching Quotes:', quotesError);
          throw quotesError;
        }

        if (import.meta.env.DEV) {
          console.log('[useQuotes] Quotes loaded:', quotesData?.length || 0);
        }

        if (!quotesData || quotesData.length === 0) {
          if (import.meta.env.DEV) {
            console.log('[useQuotes] No quotes found, setting empty array');
          }
          setQuotes([]);
          return;
        }

        // Obtener customer names por separado
        const customerIds = [...new Set(
          quotesData
            .map((q: any) => q.customer_id)
            .filter((id: any): id is string => !!id)
        )];

        let customersMap = new Map<string, { id: string; customer_name: string }>();
        if (customerIds.length > 0) {
          const { data: customersData } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name')
            .in('id', customerIds)
            .or('deleted.is.false,deleted.is.null');

          if (customersData) {
            customersMap = new Map(
            customersData.map((c: any) => [c.id, { id: c.id, customer_name: c.customer_name }])
            );
          }
        }

        // Obtener QuoteLines por separado
        // Note: QuoteLines does NOT have a 'deleted' column in the schema
        const quoteIds = quotesData.map((q: any) => q.id);
        let quoteLinesMap = new Map<string, Array<{ id: string; msrp: number; roll_msrp_snapshot: number; bom_msrp_snapshot: number }>>();
        
        if (quoteIds.length > 0) {
          const { data: linesData } = await supabase
            .from('QuoteLines')
            .select('id, quote_id, msrp, roll_msrp_snapshot, bom_msrp_snapshot')
            .in('quote_id', quoteIds);

          if (linesData) {
            linesData.forEach((line: any) => {
              if (!quoteLinesMap.has(line.quote_id)) {
                quoteLinesMap.set(line.quote_id, []);
              }
              quoteLinesMap.get(line.quote_id)!.push({
                id: line.id,
                msrp: Number(line.msrp ?? 0),
                roll_msrp_snapshot: Number(line.roll_msrp_snapshot ?? 0),
                bom_msrp_snapshot: Number(line.bom_msrp_snapshot ?? 0),
              });
            });
          }
        }

        // Enriquecer quotes con datos relacionados
        const enrichedQuotes = quotesData.map((quote: any) => ({
          ...quote,
          DirectoryCustomers: quote.customer_id ? customersMap.get(quote.customer_id) || null : null,
          QuoteLines: quoteLinesMap.get(quote.id) || []
        }));

        if (import.meta.env.DEV) {
          console.log('[useQuotes] Setting enriched quotes:', enrichedQuotes.length);
        }

        if (isMounted) {
          setQuotes(enrichedQuotes as Quote[]);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading quotes';
        console.error('[useQuotes] Error:', errorMessage);
        if (import.meta.env.DEV) {
          console.error('[useQuotes] Full error:', err);
        }
        if (isMounted) {
          setError(errorMessage);
          setQuotes([]); // ✅ Establecer array vacío en caso de error
        }
      } finally {
        if (isMounted) {
          if (import.meta.env.DEV) {
            console.log('[useQuotes] fetchQuotes completed, setting loading = false');
          }
          setLoading(false);
        }
      }
    }

    fetchQuotes();
    
    // ✅ Cleanup: marcar como unmounted para evitar actualizaciones de estado
    return () => {
      isMounted = false;
    };
  }, [activeOrganizationId, effectiveCompanyId, refreshTrigger]);

  return { quotes, loading, error, refetch };
}

/**
 * Hook para obtener quotes aprobadas con progreso
 */
/**
 * Hook para obtener quotes aprobadas con progreso
 * IMPORTANTE: Filtra por organization_id Y company_id (si está disponible)
 */
export function useApprovedQuotesWithProgress(companyId?: string | null) {
  const [quotes, setQuotes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeCompanyId } = useActiveCompany();
  
  // Usar companyId proporcionado o el activo del hook
  const effectiveCompanyId = companyId ?? activeCompanyId;

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

        // Query: filtrar por organization_id, status='approved' Y company_id (si está disponible)
        let query = supabase
          .from('Quotes')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('status', 'approved')
          .or('deleted.is.false,deleted.is.null');

        // Filtrar por company_id si está disponible
        if (effectiveCompanyId) {
          query = query.eq('company_id', effectiveCompanyId);
        }

        const { data: quotesData, error: quotesError } = await query
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
            .map((q: any) => q.customer_id)
            .filter((id: any): id is string => !!id)
        )];

        let customersMap = new Map<string, { id: string; customer_name: string }>();
        if (customerIds.length > 0) {
          const { data: customersData } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name')
            .in('id', customerIds)
            .or('deleted.is.false,deleted.is.null');

          if (customersData) {
            customersMap = new Map(
            customersData.map((c: any) => [c.id, { id: c.id, customer_name: c.customer_name }])
            );
          }
        }

        // Obtener QuoteLines
        // Note: QuoteLines does NOT have a 'deleted' column in the schema
        const quoteIds = quotesData.map((q: any) => q.id);
        let quoteLinesMap = new Map<string, Array<{ id: string; msrp: number; roll_msrp_snapshot: number; bom_msrp_snapshot: number }>>();
        
        if (quoteIds.length > 0) {
          const { data: linesData } = await supabase
            .from('QuoteLines')
            .select('id, quote_id, msrp, roll_msrp_snapshot, bom_msrp_snapshot')
            .in('quote_id', quoteIds);

          if (linesData) {
            linesData.forEach((line: any) => {
              if (!quoteLinesMap.has(line.quote_id)) {
                quoteLinesMap.set(line.quote_id, []);
              }
              quoteLinesMap.get(line.quote_id)!.push({
                id: line.id,
                msrp: Number(line.msrp ?? 0),
                roll_msrp_snapshot: Number(line.roll_msrp_snapshot ?? 0),
                bom_msrp_snapshot: Number(line.bom_msrp_snapshot ?? 0),
              });
            });
          }
        }

        // Obtener SalesOrders
        const quoteIdsForSO = quotesData.map((q: any) => q.id);
        let saleOrdersMap = new Map<string, any[]>();
        
        if (quoteIdsForSO.length > 0) {
          const { data: saleOrdersData } = await supabase
            .from('SalesOrders')
            .select('id, quote_id, sale_order_no, order_progress_status, status, organization_id')
            .in('quote_id', quoteIdsForSO)
            .eq('organization_id', activeOrganizationId)
            .or('deleted.is.false,deleted.is.null');

          if (saleOrdersData) {
            saleOrdersData.forEach((so: any) => {
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
        const enrichedQuotes = quotesData.map((quote: any) => {
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
  }, [activeOrganizationId, effectiveCompanyId, refreshTrigger]);

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

        // Query: obtener todos los campos de QuoteLines
        // Note: QuoteLines does NOT have a 'deleted' column in the schema
        // ✅ OPTIMIZED: Solo seleccionar campos necesarios para reducir carga
        const { data, error: queryError } = await supabase
          .from('QuoteLines')
          .select('*')
          .eq('quote_id', quoteId)
          .order('created_at', { ascending: true });

        // ✅ OPTIMIZED: Solo log resumen, no datos completos
        if (import.meta.env.DEV) {
          console.log('[useQuoteLines] Loaded', data?.length || 0, 'quote lines');
        }

        if (queryError) {
          // Format error to avoid [circular] reference
          const errorMsg = queryError?.message || queryError?.error_description || queryError?.hint || 'Error fetching QuoteLines';
          const errorDetails = queryError?.code ? ` (${queryError.code})` : '';
          console.error('[useQuoteLines] Error fetching QuoteLines:', errorMsg + errorDetails, queryError);
          throw queryError;
        }

        if (!data || data.length === 0) {
          setLines([]);
          return;
        }

        const lineIds = data.map((line: any) => line.id);

        // 1. Obtener ProductTypes para product_type_id
        const productTypeIds = [...new Set(
          data
            .map((line: any) => line.product_type_id)
            .filter((id: any): id is string => !!id)
        )];

        let productTypesMap = new Map<string, any>();
        if (productTypeIds.length > 0) {
          const { data: productTypesData } = await supabase
            .from('ProductTypes')
            .select('id, name, code')
            .in('id', productTypeIds)
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);

          if (productTypesData) {
            productTypesMap = new Map(
              productTypesData.map((pt: any) => [pt.id, pt])
            );
          }
        }

        // 2. ✅ QuoteLineComponents ya no se usa (tabla eliminada). Datos desde QuoteLines + ConfiguredProducts
        const componentsByLineId = new Map<string, { fabric: any[]; accessories: any[] }>();
        lineIds.forEach((lineId: string) => {
          componentsByLineId.set(lineId, { fabric: [], accessories: [] });
        });

        // Opciones (area, position, drive_type) desde columnas directas de QuoteLines
        const optionsByLineId = new Map<string, Record<string, any>>();
        data.forEach((line: any) => {
          optionsByLineId.set(line.id, {
            area: line.area ?? undefined,
            position: line.position ?? undefined,
            drive_type: line.drive_type ?? undefined,
          });
        });

        // CatalogItems solo para catalog_item_id de cada línea (fabric/roll)
        const catalogItemIdsFromLines = [...new Set(data.map((l: any) => l.catalog_item_id).filter(Boolean))];
        let catalogItemsMap = new Map<string, any>();
        if (catalogItemIdsFromLines.length > 0) {
          const { data: catalogItemsData } = await supabase
            .from('CatalogItems')
            .select('id, name, sku, collection_name, variant_name, unit_of_measure, cost_exw, measure_basis, metadata')
            .in('id', catalogItemIdsFromLines)
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .eq('is_active', true);
          if (catalogItemsData) {
            catalogItemsMap = new Map(catalogItemsData.map((item: any) => [item.id, item]));
          }
        }

        // Fabric: una entrada por línea que tenga catalog_item_id (roll)
        data.forEach((line: any) => {
          if (line.catalog_item_id) {
            const lineComponents = componentsByLineId.get(line.id);
            if (lineComponents) {
              lineComponents.fabric.push({
                quote_line_id: line.id,
                catalog_item_id: line.catalog_item_id,
                component_role: 'fabric',
                kind: 'selection',
                CatalogItems: catalogItemsMap.get(line.catalog_item_id) || null,
              });
            }
          }
        });

        // 4.6. ✅ SNAPSHOT SOURCE OF TRUTH: Obtener ConfiguredProducts con bom_preview_snapshot
        // Usar configured_product_id directamente de QuoteLine (no de metadata)
        const configuredProductIds = new Set<string>();
        data.forEach((line: any) => {
          // ✅ Priorizar configured_product_id directo, fallback a metadata
          const cpId = line.configured_product_id || line.metadata?.configured_product_id;
          if (cpId) {
            configuredProductIds.add(cpId);
          }
        });

        interface ConfiguredProductData {
          roll_plus_bom_total: number;
          total_msrp: number;
          bom_preview_snapshot: any;
        }
        let configuredProductsMap = new Map<string, ConfiguredProductData>();
        if (configuredProductIds.size > 0) {
          const { data: cpData } = await supabase
            .from('ConfiguredProducts')
            .select('id, roll_plus_bom_total, total_msrp, bom_preview_snapshot')
            .in('id', Array.from(configuredProductIds))
            .eq('organization_id', activeOrganizationId)
            .or('deleted.is.false,deleted.is.null');

          if (cpData) {
            configuredProductsMap = new Map(
              cpData.map((cp: any) => [cp.id, {
                roll_plus_bom_total: cp.roll_plus_bom_total || 0,
                total_msrp: cp.total_msrp || 0,
                bom_preview_snapshot: cp.bom_preview_snapshot || null,
              }])
            );
          }
        }

        // 5. Enriquecer líneas con todos los datos
        const enrichedLines = data.map((line: any) => {
          const components = componentsByLineId.get(line.id) || { fabric: [], accessories: [] };
          const fabric = components.fabric[0] || null;
          const fabricItem = fabric?.CatalogItems || null;
          const options = optionsByLineId.get(line.id) || {};
          
          // ✅ SNAPSHOT SOURCE OF TRUTH: Prioridad para precios:
          // 1. bom_preview_snapshot.totals.total_msrp (ConfiguredProduct snapshot)
          // 2. QuoteLines.msrp (snapshot guardado)
          // 3. Suma de snapshots individuales (fallback)
          const cpId = line.configured_product_id || line.metadata?.configured_product_id;
          const configuredProduct = cpId ? configuredProductsMap.get(cpId) : null;
          const snapshot = configuredProduct?.bom_preview_snapshot;
          const snapshotTotals = snapshot?.version === '1' ? snapshot?.totals : null;
          
          // ✅ MSRP: prioridad snapshot → ConfiguredProduct → QuoteLine → snapshots
          let finalMsrp = line.msrp || 0;
          if (snapshotTotals?.total_msrp && snapshotTotals.total_msrp > 0) {
            finalMsrp = snapshotTotals.total_msrp;
          } else if (snapshotTotals && (finalMsrp === 0 || !finalMsrp)) {
            // Snapshot existe pero total_msrp es 0 o no persistido: calcular desde totals (igual que el breakdown)
            const fromTotals =
              (Number(snapshotTotals.roll_msrp_total) || 0) +
              (Number(snapshotTotals.bom_total) || 0) +
              (Number(snapshotTotals.labor_amount) || 0) +
              (Number(snapshotTotals.accessories_total) || 0);
            if (fromTotals > 0) finalMsrp = fromTotals;
          }
          if ((!finalMsrp || finalMsrp === 0) && configuredProduct?.total_msrp && configuredProduct.total_msrp > 0) {
            finalMsrp = configuredProduct.total_msrp;
          } else if ((!finalMsrp || finalMsrp === 0) && configuredProduct?.roll_plus_bom_total && configuredProduct.roll_plus_bom_total > 0) {
            finalMsrp = configuredProduct.roll_plus_bom_total;
          }
          if (!finalMsrp || finalMsrp === 0) {
            finalMsrp = (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0);
          }
          
          const enriched = {
            ...line,
            // ✅ MSRP desde snapshot (fuente de verdad)
            msrp: finalMsrp,
            // Usar snapshots de costos si están disponibles
            total_cost: line.total_cost || ((line.roll_cost_snapshot || 0) + (line.bom_cost_snapshot || 0)),
            // Datos de QuoteLines (si existen)
            area: line.area || options.area || null,
            position: line.position || options.position || null,
            drive_type: line.drive_type || options.drive_type || null,
            // Datos relacionados
            ProductType: line.product_type_id ? productTypesMap.get(line.product_type_id) || null : null,
            collection_name: line.collection_name || fabricItem?.collection_name || null,
            variant_name: line.variant_name || fabricItem?.variant_name || null,
            Accessories: components.accessories,
            CatalogItems: line.catalog_item_id ? catalogItemsMap.get(line.catalog_item_id) || null : null,
            // ✅ NEW: Incluir datos del ConfiguredProduct para debug/UI
            ConfiguredProduct: configuredProduct || null,
            bom_preview_snapshot: snapshot || null,
          };

        // ✅ DEBUG: Log snapshot source para verificar prioridad de precios
        if (import.meta.env.DEV) {
          console.log('[useQuoteLines] Pricing source:', {
            id: line.id,
            configured_product_id: cpId,
            hasConfiguredProduct: !!configuredProduct,
            snapshotVersion: snapshot?.version,
            snapshotTotalMsrp: snapshotTotals?.total_msrp,
            cpTotalMsrp: configuredProduct?.total_msrp,
            lineMsrp: line.msrp,
            lineRollSnapshot: line.roll_msrp_snapshot,
            lineBomSnapshot: line.bom_msrp_snapshot,
            finalMsrp: finalMsrp,
          });
        }
        
        // ✅ OPTIMIZED: Solo log en DEV si hay menos de 10 líneas para evitar spam
        if (import.meta.env.DEV && data.length <= 10) {
          console.log('[useQuoteLines] Enriched line:', {
            id: line.id,
            area: enriched.area,
            position: enriched.position,
            drive_type: enriched.drive_type,
            product_type_id: line.product_type_id,
            collection_name: enriched.collection_name,
            variant_name: enriched.variant_name,
            accessoriesCount: components.accessories.length,
          });
        }

          return enriched;
        });

        if (import.meta.env.DEV) {
          console.log('[useQuoteLines] Total lines enriched:', enrichedLines.length);
        }

        setLines(enrichedLines as QuoteLine[]);
      } catch (err: any) {
        // Format error message to avoid [circular] reference
        const errorMessage = err?.message || err?.error_description || err?.hint || 'Error loading quote lines';
        const errorDetails = err?.code ? ` (${err.code})` : '';
        console.error('[useQuoteLines] Error fetching QuoteLines:', errorMessage + errorDetails, err);
        setError(errorMessage + errorDetails);
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

  const createQuote = async (quoteData: Omit<Quote, 'id' | 'organization_id' | 'company_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'> & { company_id?: string | null }) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      let finalCompanyId = quoteData.company_id;

      // If company_id is not provided, get it from the current portal user
      if (!finalCompanyId) {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          throw new Error('User not authenticated');
        }

        // Get portal user's company_id
        const { data: portalUser, error: portalError } = await supabase
          .from('CompanyPortalUsers')
          .select('company_id')
          .eq('user_id', user.id)
          .or('deleted.is.false,deleted.is.null')
          .in('status', ['active', 'invited'])
          .maybeSingle();

        if (portalError) {
          console.error('Error getting portal user company:', portalError);
          throw new Error('Unable to determine company. Please ensure you are logged in as a portal user.');
        }

        if (!portalUser?.company_id) {
          throw new Error('company_id is required. Unable to determine your company. Please contact support.');
        }

        finalCompanyId = portalUser.company_id;
        if (import.meta.env.DEV) {
          console.log('[useCreateQuote] Auto-detected company_id from portal user:', finalCompanyId);
        }
      }

      const { data, error } = await supabase
        .from('Quotes')
        .insert({
          ...quoteData,
          organization_id: activeOrganizationId,
          company_id: finalCompanyId, // Auto-obtained from portal user if not provided
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
            .or('deleted.is.false,deleted.is.null')
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
      .or('deleted.is.false,deleted.is.null')
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
