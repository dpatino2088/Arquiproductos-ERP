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
            line_total,
            unit_price_snapshot,
            unit_cost_snapshot,
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
              line_total,
              unit_price_snapshot,
              unit_cost_snapshot,
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
          
          // Enrich QuoteLines with CatalogItems, Fabric Variants, ProductTypes, and Operating System Drives
          data = data.map((line: any) => {
            const catalogItem = catalogItemsMap.get(line.catalog_item_id);
            const fabricVariant = line.variant_id ? catalogItemsMap.get(line.variant_id) : null; // Fabric variant for collection_name and variant_name
            const operatingSystemDrive = line.operating_system_drive_id ? catalogItemsMap.get(line.operating_system_drive_id) : null;
            const collection = line.collection_id ? collectionsMap.get(line.collection_id) : null;
            
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
            
            // Debug: Log original line data to see what we're getting from DB
            if (import.meta.env.DEV && line.id) {
              console.log('Raw QuoteLine from DB:', {
                id: line.id,
                area: line.area,
                position: line.position,
                hasArea: 'area' in line,
                hasPosition: 'position' in line,
                allKeys: Object.keys(line),
              });
            }

            return {
              ...line,
              // Explicitly preserve area and position from the original line data
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

