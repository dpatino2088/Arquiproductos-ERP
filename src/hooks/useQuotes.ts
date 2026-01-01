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
          .order('updated_at', { ascending: false, nullsFirst: false })
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

export function useApprovedQuotesWithProgress() {
  const [quotes, setQuotes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

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

        // Step 1: Fetch approved quotes (same approach as useSaleOrders - direct query)
        const { data: quotesData, error: quotesError } = await supabase
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
          .eq('status', 'approved')
          .eq('deleted', false)
          .order('updated_at', { ascending: false, nullsFirst: false })
          .order('created_at', { ascending: false });

        if (quotesError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Approved Quotes:', quotesError.message);
          }
          throw quotesError;
        }

        if (!quotesData || quotesData.length === 0) {
          setQuotes([]);
          return;
        }

        // Step 2: Fetch SalesOrders for these quotes (same approach as useSaleOrders)
        const quoteIds = quotesData.map(q => q.id);
        
        if (import.meta.env.DEV) {
          console.log('🔍 useApprovedQuotesWithProgress: Fetching SalesOrders for', quoteIds.length, 'quotes');
        }
        
        // Fetch SalesOrders WITHOUT ManufacturingOrders JOIN (same as useSaleOrders)
        // ManufacturingOrders can be fetched separately if needed
        let saleOrdersData: any[] = [];
        let saleOrdersError: any = null;
        
        // Only fetch if we have quote IDs
        if (quoteIds.length > 0) {
          const { data, error } = await supabase
            .from('SalesOrders')
            .select(`
              id,
              quote_id,
              sale_order_no,
              order_progress_status,
              status,
              organization_id
            `)
            .in('quote_id', quoteIds)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);
          
          saleOrdersData = data || [];
          saleOrdersError = error;
        }

        // Log error but continue (non-critical)
        if (saleOrdersError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching SaleOrders:', saleOrdersError);
          }
        } else {
          if (import.meta.env.DEV) {
            console.log('✅ useApprovedQuotesWithProgress: SalesOrders query successful, found:', saleOrdersData?.length || 0);
          }
        }
        
        // Filter by organization_id after fetching (in case RLS is blocking)
        const filteredSaleOrders = saleOrdersData?.filter((so: any) => 
          so.organization_id === activeOrganizationId
        ) || [];
        
        if (import.meta.env.DEV && filteredSaleOrders.length !== (saleOrdersData?.length || 0)) {
          console.warn(`⚠️ Filtered ${saleOrdersData?.length || 0} SalesOrders to ${filteredSaleOrders.length} by organization_id`);
        }

        // Step 3: Map SalesOrders to quotes (robust mapping with error handling)
        const saleOrdersMap = new Map<string, any[]>();
        if (filteredSaleOrders && Array.isArray(filteredSaleOrders) && filteredSaleOrders.length > 0) {
          if (import.meta.env.DEV) {
            console.log('🔍 useApprovedQuotesWithProgress: Mapping', filteredSaleOrders.length, 'SalesOrders');
          }
          filteredSaleOrders.forEach((so: any) => {
            if (so && so.quote_id) {
              // Store as array to match expected format
              if (!saleOrdersMap.has(so.quote_id)) {
                saleOrdersMap.set(so.quote_id, []);
              }
              saleOrdersMap.get(so.quote_id)!.push(so);
              if (import.meta.env.DEV) {
                console.log(`  ✅ Mapped SO ${so.sale_order_no} to quote ${so.quote_id}`);
              }
            }
          });
        } else {
          if (import.meta.env.DEV) {
            console.warn('⚠️ useApprovedQuotesWithProgress: No SalesOrders found for quotes:', quoteIds);
            console.warn('  Raw saleOrdersData:', saleOrdersData);
            console.warn('  Filtered saleOrdersData:', filteredSaleOrders);
          }
        }

        // Step 4: Enrich quotes with SalesOrders data (robust with convenience fields)
        const enrichedQuotes = quotesData.map((quote: any) => {
          const saleOrders = saleOrdersMap.get(quote.id) || [];
          const firstSO = saleOrders.length > 0 ? saleOrders[0] : null;
          
          if (import.meta.env.DEV) {
            if (saleOrders.length === 0) {
              console.warn(`⚠️ Quote ${quote.quote_no || quote.id} has no Sales Orders`);
            } else {
              console.log(`✅ Quote ${quote.quote_no || quote.id}:`, {
                saleOrderNo: firstSO?.sale_order_no || 'N/A',
                status: firstSO?.status || 'N/A',
                orderProgressStatus: firstSO?.order_progress_status || 'N/A'
              });
            }
          }
          
          return {
            ...quote,
            SaleOrders: saleOrders,
            // Convenience fields for easier access in components
            saleOrderNo: firstSO?.sale_order_no || null,
            saleOrderStatus: firstSO?.status || null,
            orderProgressStatus: firstSO?.order_progress_status || null,
            saleOrderId: firstSO?.id || null,
          };
        });

        if (import.meta.env.DEV) {
          console.log('✅ useApprovedQuotesWithProgress: Enriched', enrichedQuotes.length, 'quotes');
        }

        setQuotes(enrichedQuotes);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading approved quotes';
        if (import.meta.env.DEV) {
          console.error('Error fetching Approved Quotes:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchApprovedQuotes();
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
        // Try to fetch QuoteLines with join first
        // Explicitly select all columns including area and position to ensure they're included
        let { data, error: queryError } = await supabase
          .from('QuoteLines')
          .select(`
            id,
            organization_id,
            quote_id,
            catalog_item_id,
            qty,
            width_m,
            height_m,
            area,
            position,
            collection_id,
            collection_name,
            variant_id,
            variant_name,
            product_type,
            product_type_id,
            drive_type,
            bottom_rail_type,
            cassette,
            cassette_type,
            side_channel,
            side_channel_type,
            hardware_color,
            computed_qty,
            list_unit_price_snapshot,
            unit_price_snapshot,
            unit_cost_snapshot,
            total_unit_cost_snapshot,
            discount_pct_used,
            customer_type_snapshot,
            price_basis,
            margin_pct_used,
            line_total,
            measure_basis_snapshot,
            margin_percentage,
            metadata,
            deleted,
            archived,
            created_at,
            updated_at,
            created_by,
            updated_by
          `)
          .eq('quote_id', quoteId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        // If join fails, try without join (fallback)
        if (queryError && (queryError.message?.includes('relationship') || queryError.message?.includes('schema cache'))) {
          if (import.meta.env.DEV) {
            console.warn('⚠️ Join failed, fetching QuoteLines without join:', queryError.message);
          }
          
          const fallbackQuery = await supabase
            .from('QuoteLines')
            .select(`
              id,
              organization_id,
              quote_id,
              catalog_item_id,
              qty,
              width_m,
              height_m,
              area,
              position,
              collection_id,
              collection_name,
              variant_id,
              variant_name,
              product_type,
              product_type_id,
              drive_type,
              bottom_rail_type,
              cassette,
              cassette_type,
              side_channel,
              side_channel_type,
              hardware_color,
              computed_qty,
              list_unit_price_snapshot,
              unit_price_snapshot,
              unit_cost_snapshot,
              total_unit_cost_snapshot,
              discount_pct_used,
              customer_type_snapshot,
              price_basis,
              margin_pct_used,
              line_total,
              measure_basis_snapshot,
              margin_percentage,
              metadata,
              deleted,
              archived,
              created_at,
              updated_at,
              created_by,
              updated_by
            `)
            .eq('quote_id', quoteId)
            .eq('deleted', false)
            .order('created_at', { ascending: true });
          
          data = fallbackQuery.data;
          queryError = fallbackQuery.error;
        }

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching QuoteLines:', queryError.message);
          }
          throw queryError;
        }

        // Manually fetch CatalogItems and enrich data (FK join may not work)
        if (data && data.length > 0) {
          // Get unique catalog_item_ids (for main product)
          const catalogItemIds = [...new Set(
            data
              .map((line: any) => line.catalog_item_id)
              .filter((id: string | null) => id)
          )];
          
          // Get unique operating_system_drive_ids
          const operatingSystemDriveIds = [...new Set(
            data
              .map((line: any) => line.operating_system_drive_id)
              .filter((id: string | null) => id)
          )];
          
          // Get unique variant_ids (fabric variants for collection_name and variant_name)
          const variantIds = [...new Set(
            data
              .map((line: any) => line.variant_id)
              .filter((id: string | null) => id)
          )];
          
          // Combine all IDs to fetch in one query (catalog items, operating system drives, and fabric variants)
          const allCatalogItemIds = [...new Set([...catalogItemIds, ...operatingSystemDriveIds, ...variantIds])];
          
          // Fetch CatalogItems separately (including fabric variants)
          let catalogItemsMap = new Map<string, any>();
          if (allCatalogItemIds.length > 0) {
            const { data: catalogItemsData } = await supabase
              .from('CatalogItems')
              .select('id, item_name, sku, uom, cost_exw, default_margin_pct, msrp, measure_basis, item_type, metadata, collection_name, variant_name')
              .in('id', allCatalogItemIds)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);
            
            if (catalogItemsData) {
              catalogItemsMap = new Map(catalogItemsData.map((item: any) => [item.id, item]));
            }
          }
          
          // Get unique product_type_ids from QuoteLines (if stored) or find from product_type string
          const productTypeIds = [...new Set(
            data
              .map((line: any) => {
                // Try to get product_type_id if stored, otherwise we'll look it up by product_type string
                return line.product_type_id || null;
              })
              .filter((id: string | null) => id)
          )];
          
          // Also collect product_type strings to look up ProductTypes
          const productTypeStrings = [...new Set(
            data
              .map((line: any) => line.product_type)
              .filter((str: string | null) => str)
          )];
          
          // Fetch ProductTypes
          let productTypesMap = new Map<string, any>();
          if (productTypeIds.length > 0 || productTypeStrings.length > 0) {
            let productTypesQuery = supabase
              .from('ProductTypes')
              .select('id, name, code')
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);
            
            if (productTypeIds.length > 0) {
              productTypesQuery = productTypesQuery.in('id', productTypeIds);
            }
            
            const { data: productTypesData } = await productTypesQuery;
            
            if (productTypesData) {
              // Map by ID
              productTypesData.forEach((pt: any) => {
                productTypesMap.set(pt.id, pt);
              });
              
              // Also map by name (normalized) for lookup by product_type string
              productTypesData.forEach((pt: any) => {
                const normalizedName = pt.name.toLowerCase().replace(/\s+/g, '-');
                productTypesMap.set(normalizedName, pt);
              });
            }
          }
          
          // Get unique collection_ids
          const collectionIds = [...new Set(
            data
              .map((line: any) => line.collection_id)
              .filter((id: string | null) => id)
          )];
          
          // Fetch Collections separately
          let collectionsMap = new Map<string, any>();
          if (collectionIds.length > 0) {
            const { data: collectionsData } = await supabase
              .from('CatalogCollections')
              .select('id, name, code')
              .in('id', collectionIds)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);
            
            if (collectionsData) {
              collectionsMap = new Map(collectionsData.map((coll: any) => [coll.id, coll]));
            }
          }
          
          // Fetch accessories (QuoteLineComponents with source='accessory') for all lines
          const lineIds = data.map((line: any) => line.id);
          let accessoriesMap = new Map<string, any[]>();
          if (lineIds.length > 0) {
            const { data: accessoriesData } = await supabase
              .from('QuoteLineComponents')
              .select(`
                id,
                quote_line_id,
                catalog_item_id,
                qty,
                source,
                component_role,
                CatalogItems:catalog_item_id (
                  id,
                  item_name,
                  sku,
                  name
                )
              `)
              .in('quote_line_id', lineIds)
              .eq('deleted', false)
              .eq('organization_id', activeOrganizationId);
            
            // Filter accessories: source='accessory' OR component_role='accessory'
            // Also ensure CatalogItems relationship is loaded
            const filteredAccessories = (accessoriesData || []).filter((acc: any) => {
              const isAccessory = acc.source === 'accessory' || acc.component_role === 'accessory';
              if (import.meta.env.DEV && isAccessory && !acc.CatalogItems) {
                console.warn('Accessory missing CatalogItems:', acc);
              }
              return isAccessory;
            });
            
            if (filteredAccessories.length > 0) {
              // Group accessories by quote_line_id
              filteredAccessories.forEach((acc: any) => {
                const lineId = acc.quote_line_id;
                if (!accessoriesMap.has(lineId)) {
                  accessoriesMap.set(lineId, []);
                }
                accessoriesMap.get(lineId)!.push(acc);
              });
              
              if (import.meta.env.DEV) {
                console.log('useQuoteLines: Accessories loaded', {
                  totalAccessories: filteredAccessories.length,
                  linesWithAccessories: accessoriesMap.size,
                  accessoriesPerLine: Array.from(accessoriesMap.entries()).map(([lineId, accs]) => ({
                    lineId,
                    count: accs.length,
                    accessories: accs.map((a: any) => ({
                      id: a.id,
                      catalog_item_id: a.catalog_item_id,
                      hasCatalogItem: !!a.CatalogItems,
                      item_name: a.CatalogItems?.item_name || 'N/A',
                      sku: a.CatalogItems?.sku || 'N/A',
                    })),
                  })),
                });
              }
            }
          }

          // Enrich QuoteLines with CatalogItems, Fabric Variants, ProductTypes, and Operating System Drives
          data = data.map((line: any) => {
            const catalogItem = catalogItemsMap.get(line.catalog_item_id);
            const fabricVariant = line.variant_id ? catalogItemsMap.get(line.variant_id) : null; // Fabric variant for collection_name and variant_name
            const operatingSystemDrive = line.operating_system_drive_id ? catalogItemsMap.get(line.operating_system_drive_id) : null;
            const collection = line.collection_id ? collectionsMap.get(line.collection_id) : null;
            const accessories = accessoriesMap.get(line.id) || [];
            
            // Find ProductType by product_type_id or product_type string
            let productType = null;
            if (line.product_type_id) {
              productType = productTypesMap.get(line.product_type_id);
            } else if (line.product_type) {
              // Try to find by normalized product_type string
              const normalizedType = line.product_type.toLowerCase().replace(/\s+/g, '-');
              productType = productTypesMap.get(normalizedType);
              
              // If not found, try direct lookup
              if (!productType) {
                // We'll need to do a separate query if needed, but for now use the string
                productType = { name: line.product_type };
              }
            }
            
            // Calculate unit_price (PRECIO UN Venta) from catalog item
            let unitPrice = 0;
            if (catalogItem) {
              if (catalogItem.msrp) {
                unitPrice = catalogItem.msrp;
              } else if (catalogItem.cost_exw && catalogItem.default_margin_pct) {
                unitPrice = catalogItem.cost_exw * (1 + catalogItem.default_margin_pct / 100);
              } else if (catalogItem.cost_exw) {
                unitPrice = catalogItem.cost_exw * 1.5; // Default 50% margin
              }
            }
            
            // Debug: Log original line data to see what we're getting from DB (only for first line to avoid spam)
            if (import.meta.env.DEV && line.id && data.indexOf(line) === 0) {
              console.log('Raw QuoteLine from DB (sample):', {
                id: line.id,
                area: line.area,
                position: line.position,
                hasAccessories: accessories.length > 0,
                accessoriesCount: accessories.length,
              });
            }

            return {
              ...line,
              // Explicitly preserve area and position from the original line data
              Accessories: accessoriesMap.get(line.id) || [],
              // IMPORTANT: These fields must be preserved exactly as they come from the database
              area: line.area !== undefined ? line.area : null,
              position: line.position !== undefined ? line.position : null,
              CatalogItems: catalogItem ? {
                ...catalogItem,
                name: catalogItem.item_name || catalogItem.sku, // Map item_name to name for compatibility
                unit_price: unitPrice, // Add calculated unit_price
              } : null,
              FabricVariant: fabricVariant ? {
                ...fabricVariant,
                collection_name: fabricVariant.collection_name || null,
                variant_name: fabricVariant.variant_name || null,
              } : null,
              ProductType: productType,
              Collection: collection, // Keep for backward compatibility
              OperatingSystemDrive: operatingSystemDrive ? {
                ...operatingSystemDrive,
                name: operatingSystemDrive.item_name || operatingSystemDrive.sku,
              } : null,
            };
          });
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
      // First, check if quote_no is being changed and if it conflicts with another quote
      if (quoteData.quote_no) {
        const { data: existingQuote } = await supabase
          .from('Quotes')
          .select('id, quote_no')
          .eq('id', id)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();

        // Only check for duplicates if quote_no is actually changing
        if (existingQuote && existingQuote.quote_no !== quoteData.quote_no) {
          const { data: conflictingQuote } = await supabase
            .from('Quotes')
            .select('id')
            .eq('quote_no', quoteData.quote_no)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .neq('id', id) // Exclude the current quote
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

/**
 * Normalize status string for consistent comparison
 * @param status - Status string to normalize
 * @returns Normalized status (trimmed, lowercase) or empty string
 */
export function normalizeStatus(status?: string): string {
  return status?.trim().toLowerCase() ?? '';
}

/**
 * Wait for SalesOrder to be created by trigger using polling
 * @param quoteId - The UUID of the quote
 * @param organizationId - The organization ID
 * @param opts - Options: timeoutMs (default 8000), intervalMs (default 250)
 * @returns SalesOrder data if found, null if timeout
 */
export async function waitForSalesOrder(
  quoteId: string,
  organizationId: string,
  opts?: { timeoutMs?: number; intervalMs?: number }
): Promise<{ id: string; sale_order_no: string } | null> {
  const timeoutMs = opts?.timeoutMs ?? 8000;
  const intervalMs = opts?.intervalMs ?? 250;
  const start = Date.now();

  console.log('🔍 waitForSalesOrder: Starting polling', {
    quoteId,
    organizationId,
    timeoutMs,
    intervalMs,
  });

  while (Date.now() - start < timeoutMs) {
    const { data, error } = await supabase
      .from('SalesOrders')
      .select('id, sale_order_no')
      .eq('quote_id', quoteId)
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .maybeSingle();

    if (error) {
      console.warn('⚠️ waitForSalesOrder: Error querying SalesOrders:', error);
    } else if (data?.id) {
      console.log('✅ waitForSalesOrder: SalesOrder found', {
        salesOrderId: data.id,
        saleOrderNo: data.sale_order_no,
        elapsedMs: Date.now() - start,
      });
      return data;
    }

    // Wait before next poll
    await new Promise(r => setTimeout(r, intervalMs));
  }

  console.warn('⚠️ waitForSalesOrder: Timeout reached, SalesOrder not found', {
    quoteId,
    elapsedMs: Date.now() - start,
  });
  return null;
}

/**
 * Shared function to approve a quote by updating Quotes.status to 'approved'
 * This is the ONLY source of truth for approval - all UI actions must use this function.
 * 
 * NOTE: The enum quote_status in DB has 'approved' (lowercase) and PostgreSQL enum is case-sensitive.
 * We must write 'approved' (lowercase) to match the enum value exactly.
 * The trigger is case-insensitive and will match 'approved' or 'Approved', but the UPDATE must use 'approved'.
 * normalizeStatus() is used only for comparisons (normalizes to lowercase).
 * 
 * @param quoteId - The UUID of the quote to approve
 * @param organizationId - The organization ID (required for RLS)
 * @returns The updated quote record
 */
export async function approveQuote(quoteId: string, organizationId: string): Promise<Quote> {
  if (!organizationId) {
    throw new Error('Organization ID is required');
  }

  // Log the approval action
  console.log('🔔 approveQuote: Approving quote', { quoteId, organizationId });

  // Update Quotes.status to 'approved' (lowercase) - this triggers the DB trigger
  // NOTE: The enum quote_status in DB has 'approved' (lowercase) and PostgreSQL enum is case-sensitive.
  // The trigger is case-insensitive and will match 'approved' or 'Approved', but we must write
  // the exact enum value: 'approved' (lowercase).
  const { data, error } = await supabase
    .from('Quotes')
    .update({
      status: 'approved',  // minúscula para coincidir con el enum (case-sensitive)
      updated_at: new Date().toISOString(),
    })
    .eq('id', quoteId)
    .eq('organization_id', organizationId)
    .select('id, status, updated_at')
    .single();

  if (error) {
    console.error('❌ approveQuote: Error updating Quotes.status:', {
      quoteId,
      error: error.message,
      code: error.code,
    });
    throw new Error(`Failed to approve quote: ${error.message}`);
  }

  if (!data) {
    throw new Error('Quote not found or you do not have permission to update it');
  }

  console.log('✅ approveQuote: Quote approved successfully', {
    quoteId: data.id,
    status: data.status,
    updated_at: data.updated_at,
  });

  // Wait for SalesOrder to be created by trigger using polling
  const salesOrder = await waitForSalesOrder(quoteId, organizationId);

  if (salesOrder) {
    console.log('✅ approveQuote: SalesOrder created by trigger', {
      salesOrderId: salesOrder.id,
      saleOrderNo: salesOrder.sale_order_no,
    });
  } else {
    console.warn('⚠️ approveQuote: SalesOrder not found after polling timeout. Trigger may not have fired or is still processing.');
    // NOTE: We don't throw error here - the quote is approved, even if SalesOrder creation is delayed
  }

  // Return full quote data
  const { data: fullQuote, error: fetchError } = await supabase
    .from('Quotes')
    .select('*')
    .eq('id', quoteId)
    .single();

  if (fetchError) {
    console.error('❌ approveQuote: Error fetching full quote:', fetchError);
    throw new Error(`Failed to fetch updated quote: ${fetchError.message}`);
  }

  return fullQuote as Quote;
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

