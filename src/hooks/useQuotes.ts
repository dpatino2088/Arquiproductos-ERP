import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import { getAppUsersDisplayNames } from '../lib/appUsersDisplayNames';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useDealerScope } from './useDealerScope';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { getEffectiveOrgAndDealer } from '../lib/directoryContext';
import { Quote, QuoteLine } from '../types/catalog';
import type { QuoteStatus } from '../types/catalog';

/** Shape devuelto por useQuotes para la lista (una sola fuente de verdad: dealer + enriquecimiento) */
export interface QuoteListItem {
  id: string;
  quote_no: string;
  status: QuoteStatus;
  customer_id: string | null;
  customer_name: string;
  contact_id: string | null;
  contact_name: string;
  /** Quote header description (optional) */
  description?: string | null;
  /** low | normal | high | urgent | rush */
  priority?: string | null;
  total: number;
  created_at: string;
  organization_id: string;
  dealer_id: string | null;
  /** coalesce(AppUsers.display_name, 'Legacy / Imported') */
  created_by: string;
  archived?: boolean;
  sale_order_id?: string | null;
  total_paid?: number;
  has_payment?: boolean;
  parent_quote_id?: string | null;
  root_quote_id?: string | null;
  version_no?: number | null;
  is_version?: boolean | null;
  [key: string]: unknown;
}

/**
 * Hook principal para obtener quotes
 * IMPORTANTE: Filtra por organization_id Y dealer_id (effectiveDealerId desde useActiveDealer cuando SuperAdmin "acting as dealer")
 *
 * @param dealerId - Opcional: si se proporciona, filtra solo por ese dealer_id específico
 */
export function useQuotes(dealerId?: string | null) {
  const [quotes, setQuotes] = useState<QuoteListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { scopeKey, activeDealerId, effectiveDealerId, hasHydrated } = useDealerScope();
  const { userType } = useAccessContext();
  const selectedDealerId = dealerId ?? effectiveDealerId ?? activeDealerId;
  const fetchQuotesRef = useRef<(signal?: AbortSignal) => Promise<void>>(null!);

  const fetchQuotes = useCallback(async (signal?: AbortSignal) => {
    if (!activeOrganizationId) {
      setLoading(false);
      setQuotes([]);
      setError(null);
      return;
    }
    if (signal?.aborted) return;

    setLoading(true);
    setError(null);

    try {
      let effectiveDealerId: string | null = null;
      if (userType === 'portal') {
        const effective = await getEffectiveOrgAndDealer(supabase, {
          activeOrgId: activeOrganizationId,
          userType,
          activeDealerId: null,
        });
        if (signal?.aborted) return;
        effectiveDealerId = effective.dealerId;
        if (effectiveDealerId == null) {
          setQuotes([]);
          setLoading(false);
          return;
        }
      } else {
        effectiveDealerId = selectedDealerId ?? null;
      }

      let query = supabase
        .from('Quotes')
        .select('id, quote_no, status, priority, created_at, created_by_user_id, customer_id, contact_id, dealer_id, organization_id, description, archived, parent_quote_id, root_quote_id, version_no, is_version')
        .eq('organization_id', activeOrganizationId)
        .or('deleted.is.false,deleted.is.null');

      if (effectiveDealerId) {
        query = query.eq('dealer_id', effectiveDealerId);
      }

      const { data: quotesData, error: quotesError } = await query
        .order('created_at', { ascending: false });

      if (quotesError) throw quotesError;
      if (signal?.aborted) return;

      if (!quotesData || quotesData.length === 0) {
        setQuotes([]);
        setLoading(false);
        return;
      }

      const createdByUserIds = quotesData
        .map((q: any) => q.created_by_user_id)
        .filter((id: any): id is string => !!id);
      const appUsersMap = await getAppUsersDisplayNames(createdByUserIds);
      if (signal?.aborted) return;

      const customerIds = [...new Set(
        quotesData.map((q: any) => q.customer_id).filter((id: any): id is string => !!id)
      )];
      const contactIds = [...new Set(
        quotesData.map((q: any) => q.contact_id).filter((id: any): id is string => !!id)
      )];

      const [customersRes, contactsRes] = await Promise.all([
        customerIds.length > 0
          ? supabase.from('DirectoryCustomers').select('id, customer_name').in('id', customerIds).or('deleted.is.false,deleted.is.null')
          : Promise.resolve({ data: [] }),
        contactIds.length > 0
          ? supabase.from('DirectoryContacts').select('id, contact_name').in('id', contactIds).eq('deleted', false)
          : Promise.resolve({ data: [] }),
      ]);
      if (signal?.aborted) return;

      const customersMap = new Map<string, string>();
      const contactsMap = new Map<string, string>();
      (customersRes.data || []).forEach((c: any) => customersMap.set(c.id, c.customer_name ?? 'Sin nombre'));
      (contactsRes.data || []).forEach((c: any) => contactsMap.set(c.id, (c.contact_name ?? '').toString().trim() || 'Sin nombre'));

      const quoteIds = quotesData.map((q: any) => q.id);
      let quoteLinesMap = new Map<string, Array<{ id: string; msrp: number; dealer_price_total: number; roll_msrp_snapshot: number; bom_msrp_snapshot: number }>>();
      if (quoteIds.length > 0) {
        const { data: linesData } = await supabase
          .from('QuoteLines')
          .select('id, quote_id, msrp, dealer_price_total, roll_msrp_snapshot, bom_msrp_snapshot')
          .in('quote_id', quoteIds);
        if (signal?.aborted) return;
        if (linesData) {
          linesData.forEach((line: any) => {
            if (!quoteLinesMap.has(line.quote_id)) quoteLinesMap.set(line.quote_id, []);
            quoteLinesMap.get(line.quote_id)!.push({
              id: line.id,
              msrp: Number(line.msrp ?? 0),
              dealer_price_total: Number(line.dealer_price_total ?? 0),
              roll_msrp_snapshot: Number(line.roll_msrp_snapshot ?? 0),
              bom_msrp_snapshot: Number(line.bom_msrp_snapshot ?? 0),
            });
          });
        }
      }

      let saleOrderByQuoteId = new Map<string, { id: string; quote_id: string }>();
      if (quoteIds.length > 0) {
        const { data: saleOrdersData } = await supabase
          .from('SalesOrders')
          .select('id, quote_id, created_at')
          .in('quote_id', quoteIds)
          .eq('organization_id', activeOrganizationId)
          .or('deleted.is.false,deleted.is.null')
          .order('created_at', { ascending: false });
        if (signal?.aborted) return;
        (saleOrdersData || []).forEach((so: any) => {
          if (so?.quote_id && so?.id && !saleOrderByQuoteId.has(so.quote_id)) {
            saleOrderByQuoteId.set(so.quote_id, { id: so.id, quote_id: so.quote_id });
          }
        });
      }

      const salesOrderIds = Array.from(new Set(Array.from(saleOrderByQuoteId.values()).map((so) => so.id)));
      const paidBySalesOrderId = new Map<string, number>();
      if (salesOrderIds.length > 0) {
        const { data: financialData } = await supabase
          .from('sales_order_financial_summary')
          .select('sales_order_id, total_paid')
          .in('sales_order_id', salesOrderIds);
        if (signal?.aborted) return;
        (financialData || []).forEach((row: any) => {
          paidBySalesOrderId.set(row.sales_order_id, Number(row.total_paid ?? 0));
        });
      }

      const enrichedQuotes = quotesData.map((quote: any) => {
        const lines = quoteLinesMap.get(quote.id) || [];
        const salesOrder = saleOrderByQuoteId.get(quote.id) ?? null;
        const totalPaid = salesOrder?.id ? (paidBySalesOrderId.get(salesOrder.id) ?? 0) : 0;
        const total = lines.reduce((sum: number, l: any) => {
          const dealerTotal = Number(l.dealer_price_total ?? 0);
          const msrpTotal = Number(l.msrp ?? 0);
          return sum + (dealerTotal > 0 ? dealerTotal : msrpTotal);
        }, 0);
        const createdBy = quote.created_by_user_id
          ? (appUsersMap.get(quote.created_by_user_id) ?? 'Legacy / Imported')
          : 'Legacy / Imported';
        return {
          ...quote,
          DirectoryCustomers: quote.customer_id ? { id: quote.customer_id, customer_name: customersMap.get(quote.customer_id) || 'Cliente no encontrado' } : null,
          QuoteLines: lines,
          customer_name: quote.customer_id ? (customersMap.get(quote.customer_id) || 'Cliente no encontrado') : 'Consumidor Final',
          contact_name: quote.contact_id ? (contactsMap.get(quote.contact_id) || 'Contacto no encontrado') : '-',
          total,
          created_by: createdBy,
          sale_order_id: salesOrder?.id ?? null,
          total_paid: totalPaid,
          has_payment: totalPaid > 0,
        };
      });

      setQuotes(enrichedQuotes as QuoteListItem[]);
    } catch (err: any) {
      if (err?.name === 'AbortError') return;
      const errorMessage = err instanceof Error ? err.message : 'Error loading quotes';
      console.error('[useQuotes] Error:', errorMessage);
      setError(errorMessage);
      setQuotes([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, userType, selectedDealerId]);

  fetchQuotesRef.current = fetchQuotes;

  const refetch = useCallback(() => {
    fetchQuotesRef.current();
  }, []);

  useEffect(() => {
    const ctrl = new AbortController();
    fetchQuotesRef.current(ctrl.signal);

    return () => {
      ctrl.abort();
    };
  }, [scopeKey, userType]);

  return { quotes, loading, error, refetch };
}

/**
 * Hook para obtener quotes aprobadas con progreso
 */
/**
 * Hook para obtener quotes aprobadas con progreso
 * IMPORTANTE: Filtra por organization_id Y dealer_id (si está disponible)
 */
export function useApprovedQuotesWithProgress(dealerId?: string | null) {
  const [quotes, setQuotes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();
  const selectedDealerId = dealerId ?? activeDealerId;

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

      // ✅ NO vaciar quotes — mantener datos previos mientras carga (evita flash)
      setLoading(true);
      setError(null);

      try {
        let effectiveDealerId: string | null = null;
        if (userType === 'portal') {
          const effective = await getEffectiveOrgAndDealer(supabase, {
            activeOrgId: activeOrganizationId,
            userType,
            activeDealerId: null,
          });
          effectiveDealerId = effective.dealerId;
          if (effectiveDealerId == null) {
            setQuotes([]);
            setLoading(false);
            return;
          }
        } else {
          effectiveDealerId = selectedDealerId ?? null;
        }

        // Query: misma regla que Directory — portal = dealer_id obligatorio; org = selectedDealerId o todos
        let query = supabase
          .from('Quotes')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('status', 'approved')
          .or('deleted.is.false,deleted.is.null');

        if (effectiveDealerId) {
          query = query.eq('dealer_id', effectiveDealerId);
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
  }, [activeOrganizationId, selectedDealerId, userType, refreshTrigger, hasHydrated]);

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

        // Query: obtener todos los campos de QuoteLines por quote_id (no filtrar por dealer; las líneas son de la cotización)
        // Note: QuoteLines does NOT have a 'deleted' column in the schema
        const { data, error: queryError } = await supabase
          .from('QuoteLines')
          .select('*')
          .eq('quote_id', quoteId)
          .order('sort_order', { ascending: true, nullsFirst: false })
          .order('created_at', { ascending: true });

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

        // Quote + AppUsers (cached) para quote_created_at, quote_no, quote_created_by (Created by del Quote)
        let quoteCreatedAt: string | null = null;
        let quoteNo: string | null = null;
        let quoteCreatedBy = 'Legacy / Imported';
        const { data: quoteRow } = await supabase
          .from('Quotes')
          .select('created_at, quote_no, created_by_user_id')
          .eq('id', quoteId)
          .maybeSingle();
        if (quoteRow) {
          quoteCreatedAt = quoteRow.created_at ?? null;
          quoteNo = quoteRow.quote_no ?? null;
          if (quoteRow.created_by_user_id) {
            const auMap = await getAppUsersDisplayNames([quoteRow.created_by_user_id]);
            quoteCreatedBy = auMap.get(quoteRow.created_by_user_id) ?? 'Legacy / Imported';
          }
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
            .select('id, name, sku, collection_name, variant_name, color, unit_of_measure, cost_exw, measure_basis, item_role, manufacturer, roll_width_m, roll_length_m, Manufacturers(name)')
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

        // Fetch ConfiguredProducts to get config_snapshot and pricing data
        const configuredProductIds = new Set<string>();
        data.forEach((line: any) => {
          const cpId = line.configured_product_id || line.metadata?.configured_product_id;
          if (cpId) {
            configuredProductIds.add(cpId);
          }
        });

        interface ConfiguredProductData {
          roll_msrp_total: number;
          bom_total: number;
          total_msrp: number;
          bom_preview_snapshot: any;
          config_snapshot: any;
        }
        let configuredProductsMap = new Map<string, ConfiguredProductData>();
        if (configuredProductIds.size > 0) {
          const { data: cpData, error: cpError } = await supabase
            .from('ConfiguredProducts')
            .select('id, roll_msrp_total, bom_total, total_msrp, bom_preview_snapshot, config_snapshot')
            .in('id', Array.from(configuredProductIds))
            .eq('organization_id', activeOrganizationId)
            .or('deleted.eq.false,deleted.is.null');

          if (cpError) {
            console.error('[useQuoteLines] Error fetching ConfiguredProducts:', cpError.message);
          }

          if (cpData) {
            configuredProductsMap = new Map(
              cpData.map((cp: any) => [cp.id, {
                roll_msrp_total: cp.roll_msrp_total || 0,
                bom_total: cp.bom_total || 0,
                total_msrp: cp.total_msrp || 0,
                bom_preview_snapshot: cp.bom_preview_snapshot || null,
                config_snapshot: cp.config_snapshot || null,
              }])
            );
          }
        }

        // 4.7. Accessories desde config_snapshot: recoger catalog_item_id de todos los accesorios y cargar CatalogItems
        const accessoryCatalogItemIds = new Set<string>();
        configuredProductsMap.forEach((cp: ConfiguredProductData) => {
          const accessories = cp.config_snapshot?.accessories;
          if (Array.isArray(accessories)) {
            accessories.forEach((acc: any) => {
              const id = acc.id ?? acc.catalog_item_id;
              if (id) accessoryCatalogItemIds.add(String(id));
            });
          }
        });
        if (accessoryCatalogItemIds.size > 0) {
          const ids = Array.from(accessoryCatalogItemIds);
          const { data: accessoryItems } = await supabase
            .from('CatalogItems')
            .select('id, name, sku, collection_name, variant_name, unit_of_measure, item_role')
            .in('id', ids)
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .eq('is_active', true);
          if (accessoryItems?.length) {
            accessoryItems.forEach((item: any) => catalogItemsMap.set(item.id, item));
          }
        }

        // 4.8. Rellenar components.accessories desde config_snapshot por línea
        data.forEach((line: any) => {
          const cpId = line.configured_product_id || line.metadata?.configured_product_id;
          const cp = cpId ? configuredProductsMap.get(cpId) : null;
          const accessories = cp?.config_snapshot?.accessories;
          const lineComponents = componentsByLineId.get(line.id);
          if (lineComponents && Array.isArray(accessories) && accessories.length > 0) {
            lineComponents.accessories = accessories.map((acc: any, idx: number) => {
              const catalogItemId = acc.id ?? acc.catalog_item_id;
              const catalogItem = catalogItemId ? catalogItemsMap.get(catalogItemId) : null;
              return {
                id: `${line.id}-acc-${idx}`,
                catalog_item_id: catalogItemId ?? null,
                component_role: 'accessory',
                qty: acc.qty ?? 1,
                CatalogItems: catalogItem || null,
                item_name: acc.name ?? catalogItem?.name ?? catalogItem?.sku ?? null,
              };
            });
          }
        });

        // 4.9. Drive system label: collect drive_item_id (manual) and motor_item_id (motorized) from config_snapshot, fetch CatalogItems for manufacturer
        const driveItemIds = new Set<string>();
        data.forEach((line: any) => {
          const id = line.operating_system_drive_id;
          if (id) driveItemIds.add(id);
        });
        configuredProductsMap.forEach((cp: ConfiguredProductData) => {
          const snap = cp.config_snapshot;
          const driveId = snap?.drive_item_id;
          const motorId = snap?.motor_item_id;
          if (driveId) driveItemIds.add(driveId);
          if (motorId) driveItemIds.add(motorId);
        });
        let driveItemsMap = new Map<string, { name?: string; manufacturer_name?: string | null }>();
        if (driveItemIds.size > 0) {
          const { data: driveItemsData, error: driveErr } = await supabase
            .from('CatalogItems')
            .select('id, name, sku, manufacturer_id, manufacturer, Manufacturers(name)')
            .in('id', Array.from(driveItemIds))
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .eq('is_active', true);
          if (driveErr) {
            console.warn('[useQuoteLines] Error fetching drive items:', driveErr.message);
          }
          if (driveItemsData?.length) {
            driveItemsData.forEach((item: any) => {
              const fromJoin = (item.Manufacturers as { name?: string } | null)?.name ?? (item.manufacturers as { name?: string } | null)?.name;
              const fromColumn = item.manufacturer ? String(item.manufacturer).trim() : null;
              const mfrName = fromJoin || fromColumn || null;
              driveItemsMap.set(item.id, {
                name: item.name,
                manufacturer_name: mfrName,
              });
            });
          }
        }

        // 5. Enriquecer líneas con todos los datos
        const enrichedLines = data.map((line: any) => {
          const components = componentsByLineId.get(line.id) || { fabric: [], accessories: [] };
          const fabric = components.fabric[0] || null;
          const fabricItem = fabric?.CatalogItems || null;
          const options = optionsByLineId.get(line.id) || {};
          
          const cpId = line.configured_product_id || line.metadata?.configured_product_id;
          const configuredProduct = cpId ? configuredProductsMap.get(cpId) : null;
          const snapshot = configuredProduct?.bom_preview_snapshot;
          const snapshotTotals = snapshot?.totals ?? null;
          
          const hasLineMsrp = line.msrp != null && Number(line.msrp) > 0;
          let finalMsrp: number;
          let finalUnitMsrp: number | null = line.unit_msrp != null && Number(line.unit_msrp) >= 0 ? Number(line.unit_msrp) : null;
          if (hasLineMsrp) {
            finalMsrp = Number(line.msrp);
            if (finalUnitMsrp == null) {
              const qty = line.quantity ?? line.qty ?? 1;
              finalUnitMsrp = qty > 0 ? finalMsrp / qty : finalMsrp;
            }
          } else {
            const fromSnapshotTotal = snapshotTotals?.total_msrp != null && Number(snapshotTotals.total_msrp) > 0
              ? Number(snapshotTotals.total_msrp)
              : 0;
            const fromSnapshotSum = snapshotTotals
              ? (Number(snapshotTotals.roll_msrp_total) || 0) +
                (Number(snapshotTotals.bom_total) || 0) +
                (Number(snapshotTotals.labor_amount) || 0) +
                (Number(snapshotTotals.accessories_total) || 0)
              : 0;
            const fromCpTotal = configuredProduct?.total_msrp != null && Number(configuredProduct.total_msrp) > 0
              ? Number(configuredProduct.total_msrp)
              : 0;
            const fromCpRollPlusBom = (configuredProduct?.roll_msrp_total != null && configuredProduct?.bom_total != null)
              ? (Number(configuredProduct.roll_msrp_total) || 0) + (Number(configuredProduct.bom_total) || 0)
              : 0;
            const fromLineSnapshots = (Number(line.roll_msrp_snapshot) || 0) + (Number(line.bom_msrp_snapshot) || 0);

            finalMsrp = fromSnapshotTotal || fromSnapshotSum || fromCpTotal || fromCpRollPlusBom || fromLineSnapshots;
            if (finalUnitMsrp == null) {
              const qty = line.quantity ?? line.qty ?? 1;
              finalUnitMsrp = qty > 0 ? finalMsrp / qty : finalMsrp;
            }
          }
          
          const driveType = line.drive_type || options.drive_type || null;
          const snap = configuredProduct?.config_snapshot;
          const driveItemId = line.operating_system_drive_id ?? snap?.drive_item_id ?? (driveType === 'motor' ? snap?.motor_item_id : snap?.drive_item_id);
          const motorItemId = snap?.motor_item_id;
          const systemItemId = driveType === 'motor' ? (motorItemId ?? driveItemId) : (driveItemId ?? motorItemId);
          const driveItem = systemItemId ? driveItemsMap.get(systemItemId) : null;
          const driveTypeLabel = driveType === 'motor' ? 'Motorized' : driveType === 'manual' ? 'Manual' : null;
          const manufacturerName = driveItem?.manufacturer_name ?? null;
          const drive_system_label =
            driveTypeLabel && manufacturerName
              ? `${driveTypeLabel} | ${manufacturerName}`
              : manufacturerName
                ? `${driveTypeLabel ?? 'Drive'} | ${manufacturerName}`
                : driveTypeLabel;

          const enriched = {
            ...line,
            msrp: finalMsrp,
            unit_msrp: finalUnitMsrp,
              total_cost: line.total_cost || ((line.roll_cost_snapshot || 0) + (line.bom_cost_snapshot || 0)),
            area: line.area || options.area || null,
            position: line.position || options.position || null,
            drive_type: line.drive_type || options.drive_type || null,
            drive_system_label: drive_system_label ?? null,
            ProductType: line.product_type_id ? productTypesMap.get(line.product_type_id) || null : null,
            collection_name: line.collection_name || fabricItem?.collection_name || null,
            variant_name: line.variant_name || fabricItem?.variant_name || null,
            Accessories: components.accessories,
            CatalogItems: line.catalog_item_id ? catalogItemsMap.get(line.catalog_item_id) || null : null,
            ConfiguredProduct: configuredProduct || null,
            // Canonical source for line configuration is ConfiguredProducts.config_snapshot.
            // Keep QuoteLines.config_snapshot as fallback only for missing keys.
            config_snapshot: {
              ...(line.config_snapshot || {}),
              ...(configuredProduct?.config_snapshot || {}),
            },
            bom_preview_snapshot: snapshot || null,
            // Created by = del Quote (QuoteLines no tiene created_by_user_id)
            quote_created_at: quoteCreatedAt,
            quote_no: quoteNo,
            quote_created_by: quoteCreatedBy,
          };

          return enriched;
        });

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
  const { userType, internalRole } = useAccessContext();

  const createQuote = async (quoteData: Omit<Quote, 'id' | 'organization_id' | 'dealer_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'> & { dealer_id?: string | null }) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        throw new Error('User not authenticated');
      }

      let finalDealerId = quoteData.dealer_id;

      const { data: portalUser, error: portalError } = await supabase
        .from('DealerUsers')
        .select('id, dealer_id')
        .eq('user_id', user.id)
        .or('deleted.is.false,deleted.is.null')
        .in('status', ['active', 'invited'])
        .maybeSingle();

      if (!portalError && portalUser) {
        if (!finalDealerId && portalUser.dealer_id) {
          finalDealerId = portalUser.dealer_id;
          if (import.meta.env.DEV) {
            console.log('[useCreateQuote] Auto-detected dealer_id from Dealer User:', finalDealerId);
          }
        }
      }

      if (!finalDealerId && quoteData.dealer_id) {
        finalDealerId = quoteData.dealer_id;
      }

      const normalizedInternalRole = (internalRole ?? '').toString().trim().toLowerCase();
      const requiredDealerRoles = new Set(['superadmin', 'admin', 'sales', 'sales_coordinator']);
      let dealerIsRequired = userType === 'internal' && requiredDealerRoles.has(normalizedInternalRole);

      // Fallback for race conditions while access context is still resolving.
      if (userType === 'internal' && !dealerIsRequired && !normalizedInternalRole) {
        const { data: appUserRole } = await supabase
          .from('AppUsers')
          .select('role_code')
          .eq('auth_user_id', user.id)
          .eq('user_type', 'org')
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .limit(1)
          .maybeSingle();
        const roleCode = (appUserRole?.role_code ?? '').toString().trim().toLowerCase();
        dealerIsRequired = requiredDealerRoles.has(roleCode);
      }

      if (dealerIsRequired && !finalDealerId) {
        throw new Error('Dealer Acting As is required to create a Quote for your role.');
      }

      const { data, error } = await supabase
        .from('Quotes')
        .insert({
          ...quoteData,
          organization_id: activeOrganizationId,
          dealer_id: finalDealerId ?? null,
          created_by_user_id: user.id,
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

  // Guardrail in client for clearer UX (DB trigger also enforces this).
  const { count: quoteLineCount, error: countError } = await supabase
    .from('QuoteLines')
    .select('id', { count: 'exact', head: true })
    .eq('quote_id', quoteId);
  if (countError) {
    throw new Error(`Failed to validate quote lines: ${countError.message}`);
  }
  if ((quoteLineCount ?? 0) <= 0) {
    throw new Error('Cannot approve quote without lines. Add at least one quote line before approval.');
  }

  const { data, error } = await supabase
    .from('Quotes')
    .update({
      status: 'approved',
      tracking_status: 'pending_confirmation',
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

  // Crear SO con líneas al aprobar (RPC que no requiere propuesta aceptada)
  try {
    const { data: authData } = await supabase.auth.getUser();
    const userId = authData?.user?.id ?? null;
    const userName = authData?.user?.email ?? authData?.user?.user_metadata?.name ?? null;
    const { error: rpcError } = await supabase.rpc('create_sales_order_on_quote_approve', {
      p_quote_id: quoteId,
      p_user_id: userId,
      p_user_name: userName,
    });
    if (rpcError) {
      console.warn('[approveQuote] create_sales_order_on_quote_approve:', rpcError.message);
    }
  } catch (e) {
    console.warn('[approveQuote] create_sales_order_on_quote_approve error:', e);
  }

  // Esperar a que se cree el SalesOrder (por si el RPC lo creó)
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

/**
 * Duplicate a Quote. Two modes:
 *   - 'copy'    -> brand new QT-XXXXX number (independent quote)
 *   - 'version' -> new _V<N> quote linked to original via parent_quote_id/root_quote_id.
 *                  The previous editable version is marked as 'superseded' automatically.
 *
 * When `recalculate = true`, cloned lines are flagged with pricing_locked=false
 * and last_priced_at=NULL so the UI can prompt a fresh pricing pass.
 *
 * Returns the new Quote id on success.
 */
export async function duplicateQuote(
  quoteId: string,
  mode: 'copy' | 'version',
  recalculate: boolean = true,
): Promise<string> {
  const { data, error } = await supabase.rpc('duplicate_quote', {
    p_quote_id: quoteId,
    p_mode: mode,
    p_recalculate: recalculate,
  });

  if (error) {
    console.error('[duplicateQuote] RPC error:', error);
    throw new Error(error.message || 'Failed to duplicate quote');
  }

  const newId = typeof data === 'string' ? data : (data as any)?.id ?? null;
  if (!newId) {
    throw new Error('duplicate_quote returned no id');
  }
  return newId as string;
}
