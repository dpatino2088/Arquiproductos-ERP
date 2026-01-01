import { useState, useEffect, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Search, Download, FileText } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';

interface ApprovedBOMItem {
  sale_order_id: string;
  sale_order_no: string;
  quote_line_id: string;
  product_type_name: string;
  component_sku: string;
  component_name: string;
  qty: number;
  uom: string;
  unit_cost: number;
  total_cost: number;
  customer_name: string;
  created_at: string;
}

interface SaleOrderGroup {
  sale_order_id: string;
  sale_order_no: string;
  customer_name: string;
  created_at: string;
  components: ApprovedBOMItem[];
  total_qty: number;
  total_cost: number;
}

export default function ApprovedBOMList() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const [saleOrderGroups, setSaleOrderGroups] = useState<SaleOrderGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10); // Show 10 SOs per page
  const [sortBy, setSortBy] = useState<'sale_order_no' | 'customer_name' | 'created_at'>('sale_order_no');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  // Register Manufacturing submodules when in Material tab
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) {
      // Always register submodules to ensure tabs are visible
      registerSubmodules('Manufacturing', [
        { id: 'order-list', label: 'Order List', href: '/manufacturing/order-list' },
        { id: 'manufacturing-orders', label: 'Manufacturing Orders', href: '/manufacturing/manufacturing-orders' },
        { id: 'material', label: 'Material', href: '/manufacturing/material' },
      ]);
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  // Load approved BOM items grouped by Sale Order
  useEffect(() => {
    const loadApprovedBOM = async () => {
      if (!activeOrganizationId) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 ApprovedBOMList: Loading approved BOM for organization:', activeOrganizationId);
        }

        // Step 1: Get all ManufacturingOrders first, then get their SalesOrders
        const { data: manufacturingOrders, error: moError } = await supabase
          .from('ManufacturingOrders')
          .select(`
            id,
            sale_order_id,
            status,
            organization_id
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (moError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching ManufacturingOrders:', moError);
          }
          throw moError;
        }

        if (!manufacturingOrders || manufacturingOrders.length === 0) {
          if (import.meta.env.DEV) {
            console.log('⚠️ ApprovedBOMList: No ManufacturingOrders found');
          }
          setSaleOrderGroups([]);
          setLoading(false);
          return;
        }
        
        // Filter to only include active MOs (deleted = false)
        const activeMOs = manufacturingOrders.filter((mo: any) => !mo.organization_id || mo.organization_id === activeOrganizationId);

        if (import.meta.env.DEV) {
          console.log('✅ ApprovedBOMList: Found', manufacturingOrders.length, 'ManufacturingOrders');
        }

        // Get unique sale_order_ids from active MOs
        const saleOrderIds = [...new Set(activeMOs.map((mo: any) => mo.sale_order_id).filter(Boolean))];

        // Step 2: Get SalesOrders for these ManufacturingOrders
        const { data: saleOrders, error: soError } = await supabase
          .from('SalesOrders')
          .select(`
            id,
            sale_order_no,
            customer_id,
            created_at,
            organization_id
          `)
          .in('id', saleOrderIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (soError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching SalesOrders:', soError);
          }
          throw soError;
        }

        if (!saleOrders || saleOrders.length === 0) {
          if (import.meta.env.DEV) {
            console.log('⚠️ ApprovedBOMList: No SalesOrders found for ManufacturingOrders');
          }
          // Don't return - continue to show empty state
        }

        if (import.meta.env.DEV) {
          console.log('✅ ApprovedBOMList: Found', saleOrders.length, 'SalesOrders');
        }

        // Create a map of sale_order_id -> ManufacturingOrder
        const moBySaleOrderId = new Map();
        manufacturingOrders.forEach((mo: any) => {
          if (mo.sale_order_id) {
            if (!moBySaleOrderId.has(mo.sale_order_id)) {
              moBySaleOrderId.set(mo.sale_order_id, []);
            }
            moBySaleOrderId.get(mo.sale_order_id).push(mo);
          }
        });

        if (!saleOrders || saleOrders.length === 0) {
          setSaleOrderGroups([]);
          setLoading(false);
          return;
        }

        // Step 2: Get SalesOrderLines for these Sales Orders
        // Reuse saleOrderIds from Step 1 (already contains the IDs we need)
        if (import.meta.env.DEV) {
          console.log('🔍 ApprovedBOMList: Fetching SalesOrderLines for saleOrderIds:', saleOrderIds);
        }
        
        const { data: allSalesOrderLines, error: solError } = await supabase
          .from('SalesOrderLines')
          .select('id, sale_order_id, organization_id')
          .in('sale_order_id', saleOrderIds)
          .eq('deleted', false);

        if (solError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching SalesOrderLines:', solError);
          }
          throw solError;
        }

        if (!allSalesOrderLines || allSalesOrderLines.length === 0) {
          if (import.meta.env.DEV) {
            console.log('⚠️ ApprovedBOMList: No SalesOrderLines found');
          }
          // Don't return - continue to show available data
        }

        const saleOrderLineIds = allSalesOrderLines.map((sol: any) => sol.id);
        const saleOrderLineToSO = new Map<string, string>();
        allSalesOrderLines.forEach((sol: any) => {
          saleOrderLineToSO.set(sol.id, sol.sale_order_id);
        });

        if (import.meta.env.DEV) {
          console.log('✅ ApprovedBOMList: Found', saleOrderLineIds.length, 'SalesOrderLines');
        }

        // STEP 1: Fetch BomInstances (no embedded joins)
        let materialList: any[] = [];
        let bomInstances: any[] = [];
        let queryErrors: string[] = [];
        
        if (saleOrderLineIds.length > 0) {
          if (import.meta.env.DEV) {
            console.log('🔍 ApprovedBOMList: Step 1 - Fetching BomInstances for saleOrderLineIds:', saleOrderLineIds.length);
          }
          
          const { data: bomInstancesData, error: bomError } = await supabase
            .from('BomInstances')
            .select('id, sale_order_line_id, quote_line_id, organization_id')
            .in('sale_order_line_id', saleOrderLineIds)
            .eq('deleted', false)
            .eq('organization_id', activeOrganizationId);
          
          if (bomError) {
            console.error('ApprovedBOMList query failed', { step: '1 - BomInstances', error: bomError });
            queryErrors.push('Failed to fetch BomInstances');
          } else {
            bomInstances = bomInstancesData || [];
            if (import.meta.env.DEV) {
              console.log('✅ ApprovedBOMList: Step 1 - Found', bomInstances.length, 'BomInstances');
            }
          }

          if (bomInstances.length > 0) {
            const bomInstanceIds = bomInstances.map((bi: any) => bi.id);

            // STEP 2: Fetch BomInstanceLines (flat fields only, no joins)
            if (import.meta.env.DEV) {
              console.log('🔍 ApprovedBOMList: Step 2 - Fetching BomInstanceLines for bomInstanceIds:', bomInstanceIds.length);
            }
            
            const { data: bomLines, error: linesError } = await supabase
              .from('BomInstanceLines')
              .select('id, bom_instance_id, resolved_part_id, resolved_sku, part_role, category_code, qty, uom, unit_cost_exw, total_cost_exw, organization_id, description')
              .in('bom_instance_id', bomInstanceIds)
              .eq('deleted', false)
              .eq('organization_id', activeOrganizationId);

            if (linesError) {
              console.error('ApprovedBOMList query failed', { step: '2 - BomInstanceLines', error: linesError });
              queryErrors.push('Failed to fetch BomInstanceLines');
            } else if (bomLines && bomLines.length > 0) {
              if (import.meta.env.DEV) {
                console.log('✅ ApprovedBOMList: Step 2 - Found', bomLines.length, 'BomInstanceLines');
                console.log('null resolved_part_id lines', bomLines.filter((l: any) => !l.resolved_part_id).length);
              }

              // STEP 3: Build unique set of resolved_part_id and fetch CatalogItems
              // Filter to valid UUIDs only to avoid PostgREST 400 errors
              const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
              const catalogItemIds = [...new Set(
                bomLines
                  .map((bil: any) => bil.resolved_part_id)
                  .filter((id: any) => typeof id === 'string' && UUID_RE.test(id))
              )];
              
              let catalogItemById = new Map<string, any>();
              if (catalogItemIds.length > 0) {
                if (import.meta.env.DEV) {
                  console.log('🔍 ApprovedBOMList: Step 3 - Fetching CatalogItems for', catalogItemIds.length, 'valid UUIDs');
                }
                
                // Chunk queries to avoid URL length issues (max 200 IDs per chunk)
                const chunks = [];
                for (let i = 0; i < catalogItemIds.length; i += 200) {
                  chunks.push(catalogItemIds.slice(i, i + 200));
                }
                
                let allCatalogItems: any[] = [];
                let catalogError: any = null;
                
                for (const chunk of chunks) {
                  const { data: chunkItems, error: chunkError } = await supabase
                    .from('CatalogItems')
                    .select('id, sku, item_name, description, item_type, measure_basis, collection_name, variant_name')
                    .in('id', chunk);
                  
                  if (chunkError) {
                    catalogError = chunkError;
                    break; // Stop on first error
                  } else if (chunkItems) {
                    allCatalogItems = allCatalogItems.concat(chunkItems);
                  }
                }

                if (catalogError) {
                  console.error('ApprovedBOMList step 3 CatalogItems failed', {
                    message: catalogError?.message,
                    details: catalogError?.details,
                    hint: catalogError?.hint,
                    code: catalogError?.code,
                    partIdsSample: catalogItemIds.slice(0, 10),
                    partIdsCount: catalogItemIds.length
                  });
                  queryErrors.push('Failed to fetch CatalogItems');
                } else if (allCatalogItems.length > 0) {
                  allCatalogItems.forEach((ci: any) => {
                    if (ci.id) {
                      catalogItemById.set(ci.id, ci);
                    }
                  });
                  if (import.meta.env.DEV) {
                    console.log('✅ ApprovedBOMList: Step 3 - Found', allCatalogItems.length, 'CatalogItems');
                    console.log('CatalogItems sample', allCatalogItems?.[0]);
                  }
                }
              } else {
                if (import.meta.env.DEV) {
                  console.warn('⚠️ ApprovedBOMList: Step 3 - No valid UUIDs found in resolved_part_id, skipping CatalogItems fetch');
                }
              }

              // STEP 4: Build unique set of quote_line_id and fetch QuoteLines + ProductTypes
              const quoteLineIds = [...new Set(bomInstances.map((bi: any) => bi.quote_line_id).filter(Boolean))];
              
              let quoteLineToProductTypeName = new Map<string, string>();
              if (quoteLineIds.length > 0) {
                if (import.meta.env.DEV) {
                  console.log('🔍 ApprovedBOMList: Step 4a - Fetching QuoteLines for', quoteLineIds.length, 'quote lines');
                }
                
                const { data: quoteLines, error: quoteLinesError } = await supabase
                  .from('QuoteLines')
                  .select('id, product_type_id')
                  .in('id', quoteLineIds)
                  .eq('deleted', false);

                if (quoteLinesError) {
                  console.error('ApprovedBOMList query failed', { step: '4a - QuoteLines', error: quoteLinesError });
                  queryErrors.push('Failed to fetch QuoteLines');
                } else if (quoteLines) {
                  const productTypeIds = [...new Set(quoteLines.map((ql: any) => ql.product_type_id).filter(Boolean))];
                  
                  if (productTypeIds.length > 0) {
                    if (import.meta.env.DEV) {
                      console.log('🔍 ApprovedBOMList: Step 4b - Fetching ProductTypes for', productTypeIds.length, 'product types');
                    }
                    
                    const { data: productTypes, error: productTypesError } = await supabase
                      .from('ProductTypes')
                      .select('id, name')
                      .in('id', productTypeIds)
                      .eq('deleted', false);

                    if (productTypesError) {
                      console.error('ApprovedBOMList query failed', { step: '4b - ProductTypes', error: productTypesError });
                      queryErrors.push('Failed to fetch ProductTypes');
                    } else if (productTypes) {
                      const productTypeById = new Map<string, string>();
                      productTypes.forEach((pt: any) => {
                        if (pt.id && pt.name) {
                          productTypeById.set(pt.id, pt.name);
                        }
                      });
                      
                      // Build quoteLineToProductTypeName map
                      quoteLines.forEach((ql: any) => {
                        if (ql.id && ql.product_type_id) {
                          const productTypeName = productTypeById.get(ql.product_type_id);
                          if (productTypeName) {
                            quoteLineToProductTypeName.set(ql.id, productTypeName);
                          }
                        }
                      });
                      
                      if (import.meta.env.DEV) {
                        console.log('✅ ApprovedBOMList: Step 4b - Found', productTypes.length, 'ProductTypes');
                        console.log('✅ ApprovedBOMList: Step 4c - Built quoteLineToProductTypeName map with', quoteLineToProductTypeName.size, 'entries');
                      }
                    }
                  }
                }
              }

              // STEP 5: Map BomInstanceLines to material list format using the maps
              if (import.meta.env.DEV) {
                console.log('🔍 ApprovedBOMList: Step 5 - Mapping data using catalogItemById and quoteLineToProductTypeName maps');
              }
              
              bomLines.forEach((bil: any) => {
                const bomInstance = bomInstances.find((bi: any) => bi.id === bil.bom_instance_id);
                if (bomInstance) {
                  const saleOrderId = saleOrderLineToSO.get(bomInstance.sale_order_line_id);
                  if (saleOrderId) {
                    // component_name: Fabric names come from collection + variant, not item_name
                    // Detect fabric using part_role first, then fallback to CatalogItems fields
                    const catalogItem = catalogItemById.get(bil.resolved_part_id);
                    const isFabric = bil.part_role === 'fabric' || 
                                   (catalogItem && ((catalogItem.item_type === 'fabric') || (catalogItem.measure_basis === 'fabric')));
                    
                    let component_name = 'N/A';
                    if (isFabric && catalogItem) {
                      // Fabric: use collection_name - variant_name (never show SKU as first choice)
                      const fabricName = [catalogItem.collection_name, catalogItem.variant_name].filter(Boolean).join(' - ');
                      component_name = fabricName || catalogItem.item_name || catalogItem.description || bil.resolved_sku || 'N/A';
                    } else if (catalogItem) {
                      // Non-fabric: use item_name -> description -> resolved_sku
                      component_name = catalogItem.item_name ?? catalogItem.description ?? bil.resolved_sku ?? 'N/A';
                    } else {
                      // No catalog item found: fallback to resolved_sku
                      component_name = bil.resolved_sku ?? bil.description ?? 'N/A';
                    }
                    
                    // product_type_name: from ProductTypes via QuoteLines (from map)
                    const productTypeName = bomInstance.quote_line_id 
                      ? (quoteLineToProductTypeName.get(bomInstance.quote_line_id) || 'Product')
                      : 'Product';
                    
                    materialList.push({
                      sale_order_id: saleOrderId,
                      sku: bil.resolved_sku || 'N/A',
                      item_name: component_name,
                      product_type_name: productTypeName,
                      total_qty: Number(bil.qty) || 0,
                      uom: bil.uom || 'ea',
                      avg_unit_cost_exw: bil.unit_cost_exw ? Number(bil.unit_cost_exw) : 0,
                      total_cost_exw: Number(bil.total_cost_exw) || 0,
                      category_code: bil.category_code || bil.part_role || 'accessory',
                    });
                  }
                }
              });
              
              if (import.meta.env.DEV) {
                console.log('✅ ApprovedBOMList: Step 5 - Mapped', materialList.length, 'materials');
              }
            } else {
              if (import.meta.env.DEV) {
                console.warn('⚠️ ApprovedBOMList: Step 2 - No BomInstanceLines found for', bomInstanceIds.length, 'BomInstances');
              }
            }
          }
        }
        
        // Show non-blocking UI alert if any query failed
        if (queryErrors.length > 0) {
          useUIStore.getState().addNotification({
            type: 'warning',
            title: 'Data Loading Warning',
            message: `Some data could not be loaded: ${queryErrors.join(', ')}. The list may be incomplete.`,
          });
        }

        if (import.meta.env.DEV) {
          console.log('✅ ApprovedBOMList: Found', materialList.length, 'BOM materials');
          if (materialList.length === 0 && bomInstances && bomInstances.length > 0) {
            console.warn('⚠️ ApprovedBOMList: Found BomInstances but no BomInstanceLines. This suggests the trigger may not have copied QuoteLineComponents to BomInstanceLines.');
            console.warn('   BomInstances found:', bomInstances.length);
            console.warn('   This may require running VERIFY_AND_FIX_BOM_TRIGGER_ROBUST.sql');
          } else if (materialList.length === 0 && (!bomInstances || bomInstances.length === 0)) {
            console.warn('⚠️ ApprovedBOMList: No BomInstances found for ManufacturingOrders.');
            console.warn('   This suggests the BOM generation trigger may not have fired when the MO was created.');
            console.warn('   ManufacturingOrders found:', manufacturingOrders.length);
            console.warn('   SalesOrders found:', saleOrders.length);
            console.warn('   SalesOrderLines found:', allSalesOrderLines.length);
          }
        }

        // Get customer names (with organization_id filter)
        const customerIds = [...new Set(saleOrders.map((so: any) => so.customer_id).filter(Boolean))];
        let customersMap = new Map();
        if (customerIds.length > 0) {
          const { data: customers } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name, organization_id')
            .in('id', customerIds)
            .eq('organization_id', activeOrganizationId);
          
          if (customers) {
            customersMap = new Map(customers.map(c => [c.id, c.customer_name]));
          }
        }

        // Step 4: Group materials by Sale Order
        // IMPORTANTE: Mostrar TODOS los Sale Orders, incluso si no tienen materiales
        const groupsMap = new Map<string, SaleOrderGroup>();

        saleOrders.forEach((so: any) => {
          const soMaterials = materialList?.filter((m: any) => m.sale_order_id === so.id) || [];
          const soLines = allSalesOrderLines.filter((sol: any) => sol.sale_order_id === so.id);
          
          // NO saltar Sale Orders sin materiales - mostrar todos
          const customerName = customersMap.get(so.customer_id) || 'N/A';
          
          // Si no hay materiales, crear un array vacío
          const components: ApprovedBOMItem[] = soMaterials.length > 0
            ? soMaterials.map((m: any) => {
                return {
                  sale_order_id: so.id,
                  sale_order_no: so.sale_order_no,
                  quote_line_id: soLines[0]?.id || '',
                  // product_type_name: from ProductTypes via QuoteLines (already fetched in query)
                  product_type_name: m.product_type_name || 'Product',
                  component_sku: m.sku || 'N/A',
                  // component_name: from CatalogItems (already fetched in query with fallback order)
                  component_name: m.item_name || 'N/A',
                  qty: Number(m.total_qty) || 0,
                  uom: m.uom || 'ea',
                  unit_cost: m.avg_unit_cost_exw ? Number(m.avg_unit_cost_exw) : 0,
                  total_cost: Number(m.total_cost_exw) || 0,
                  customer_name: customerName,
                  created_at: so.created_at || new Date().toISOString(),
                };
              })
            : []; // Array vacío si no hay materiales

          const total_qty = components.reduce((sum, c) => sum + c.qty, 0);
          const total_cost = components.reduce((sum, c) => sum + c.total_cost, 0);

          groupsMap.set(so.id, {
            sale_order_id: so.id,
            sale_order_no: so.sale_order_no,
            customer_name: customerName,
            created_at: so.created_at || new Date().toISOString(),
            components,
            total_qty,
            total_cost,
          });
        });

        const finalGroups = Array.from(groupsMap.values());
        
        if (import.meta.env.DEV) {
          console.log('✅ ApprovedBOMList: Created', finalGroups.length, 'Sale Order groups');
          console.log('   Total components:', finalGroups.reduce((sum, g) => sum + g.components.length, 0));
        }

        setSaleOrderGroups(finalGroups);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading approved BOM';
        if (import.meta.env.DEV) {
          console.error('❌ ApprovedBOMList error:', err);
        }
        setError(errorMessage);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: errorMessage,
        });
      } finally {
        setLoading(false);
      }
    };

    loadApprovedBOM();
  }, [activeOrganizationId]);

  // Filter and sort Sale Order groups
  const filteredAndSortedGroups = useMemo(() => {
    let filtered = saleOrderGroups;
    
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      filtered = saleOrderGroups.filter(group =>
        group.sale_order_no.toLowerCase().includes(searchLower) ||
        group.customer_name.toLowerCase().includes(searchLower) ||
        group.components.some(c =>
          c.component_name.toLowerCase().includes(searchLower) ||
          c.component_sku.toLowerCase().includes(searchLower) ||
          c.product_type_name.toLowerCase().includes(searchLower)
        )
      );
    }

    // Sort
    return [...filtered].sort((a, b) => {
      let aValue: any;
      let bValue: any;

      switch (sortBy) {
        case 'sale_order_no':
          aValue = a.sale_order_no;
          bValue = b.sale_order_no;
          break;
        case 'customer_name':
          aValue = a.customer_name;
          bValue = b.customer_name;
          break;
        case 'created_at':
          aValue = new Date(a.created_at).getTime();
          bValue = new Date(b.created_at).getTime();
          break;
        default:
          return 0;
      }

      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [saleOrderGroups, searchTerm, sortBy, sortOrder]);

  // Pagination
  const totalPages = Math.ceil(filteredAndSortedGroups.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedGroups = filteredAndSortedGroups.slice(startIndex, startIndex + itemsPerPage);

  // Calculate totals
  const totals = useMemo(() => {
    return filteredAndSortedGroups.reduce((acc, group) => ({
      totalQty: acc.totalQty + group.total_qty,
      totalCost: acc.totalCost + group.total_cost,
      totalItems: acc.totalItems + group.components.length,
    }), { totalQty: 0, totalCost: 0, totalItems: 0 });
  }, [filteredAndSortedGroups]);

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Flatten all components for item count
  const allComponents = useMemo(() => {
    return filteredAndSortedGroups.flatMap(g => g.components);
  }, [filteredAndSortedGroups]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Approved BOM List</h2>
          <p className="text-sm text-gray-500">Bill of Materials from approved quotes</p>
        </div>
        {filteredAndSortedGroups.length > 0 && (
          <button
            onClick={() => {
              // TODO: Implement CSV/PDF export
              useUIStore.getState().addNotification({
                type: 'info',
                title: 'Export',
                message: 'Export functionality will be implemented soon',
              });
            }}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50"
          >
            <Download className="w-4 h-4" />
            Export
          </button>
        )}
      </div>

      {/* Search */}
      <div className="mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by quote #, component, SKU, product type, or customer..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {/* Summary */}
      {filteredAndSortedGroups.length > 0 && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-blue-900">
                Sale Orders: {filteredAndSortedGroups.length} | Total Items: {totals.totalItems}
              </p>
              <p className="text-xs text-blue-700">
                Total Quantity: {totals.totalQty.toFixed(2)} | Total Cost: ${totals.totalCost.toFixed(2)}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Table */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-sm text-gray-600">Loading approved BOM...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">Error: {error}</p>
        </div>
      ) : filteredAndSortedGroups.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <FileText className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 mb-2">No approved BOM items found</p>
          <p className="text-sm text-gray-500">
            {saleOrderGroups.length === 0 
              ? 'No sale orders have been created from approved quotes yet. Approved quotes will create sale orders with BOM components.'
              : 'Try adjusting your search criteria'}
          </p>
        </div>
      ) : (
        <>
          {/* Sale Order Groups */}
          <div className="space-y-6">
            {paginatedGroups.map((group) => (
              <div key={group.sale_order_id} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                {/* Sale Order Header */}
                <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">{group.sale_order_no}</h3>
                      <p className="text-sm text-gray-600">{group.customer_name}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium text-gray-900">
                        {group.components.length} {group.components.length === 1 ? 'component' : 'components'}
                      </p>
                      {group.components.length > 0 ? (
                        <p className="text-xs text-gray-600">
                          Total: ${group.total_cost.toFixed(2)}
                        </p>
                      ) : (
                        <p className="text-xs text-gray-400 italic">
                          No BOM available
                        </p>
                      )}
                    </div>
                  </div>
                </div>

                {/* Components Table */}
                {group.components.length > 0 ? (
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead className="bg-gray-50 border-b border-gray-200">
                        <tr>
                          <th className="text-left py-3 px-6 text-xs font-medium text-gray-700">Product Type</th>
                          <th className="text-left py-3 px-6 text-xs font-medium text-gray-700">SKU</th>
                          <th className="text-left py-3 px-6 text-xs font-medium text-gray-700">Component Name</th>
                          <th className="text-right py-3 px-6 text-xs font-medium text-gray-700">Qty</th>
                          <th className="text-right py-3 px-6 text-xs font-medium text-gray-700">UOM</th>
                          <th className="text-right py-3 px-6 text-xs font-medium text-gray-700">Unit Cost</th>
                          <th className="text-right py-3 px-6 text-xs font-medium text-gray-700">Total Cost</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-200">
                        {group.components.map((item, idx) => (
                          <tr key={`${item.sale_order_id}-${item.component_sku}-${idx}`} className="hover:bg-gray-50">
                            <td className="py-3 px-6 text-sm text-gray-700">{item.product_type_name}</td>
                            <td className="py-3 px-6 text-sm text-gray-700 font-mono">{item.component_sku}</td>
                            <td className="py-3 px-6 text-sm text-gray-700">{item.component_name}</td>
                            <td className="py-3 px-6 text-sm text-gray-900 text-right">
                              {item.uom === 'mts' || item.uom === 'm2' || item.uom === 'yd' || item.uom === 'yd2'
                                ? item.qty.toFixed(2)
                                : item.qty.toFixed(0)}
                            </td>
                            <td className="py-3 px-6 text-sm text-gray-700 text-right">{item.uom}</td>
                            <td className="py-3 px-6 text-sm text-gray-700 text-right">${item.unit_cost.toFixed(2)}</td>
                            <td className="py-3 px-6 text-sm text-gray-900 font-medium text-right">${item.total_cost.toFixed(2)}</td>
                          </tr>
                        ))}
                      </tbody>
                      <tfoot className="bg-gray-50 border-t border-gray-200">
                        <tr>
                          <td colSpan={3} className="py-3 px-6 text-sm font-semibold text-gray-900 text-right">
                            Subtotal:
                          </td>
                          <td className="py-3 px-6 text-sm font-semibold text-gray-900 text-right">
                            {group.total_qty.toFixed(2)}
                          </td>
                          <td colSpan={2}></td>
                          <td className="py-3 px-6 text-sm font-semibold text-gray-900 text-right">
                            ${group.total_cost.toFixed(2)}
                          </td>
                        </tr>
                      </tfoot>
                    </table>
                  </div>
                ) : (
                  <div className="px-6 py-8 text-center">
                    <p className="text-sm text-gray-500 mb-2">No BOM materials available</p>
                    <p className="text-xs text-gray-400">BOM has not been generated for this Sale Order yet.</p>
                  </div>
                )}
              </div>
            ))}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="bg-white border border-gray-200 rounded-lg py-4 px-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <span className="text-sm text-gray-700">Show:</span>
                  <select
                    value={itemsPerPage}
                    onChange={(e) => {
                      setItemsPerPage(Number(e.target.value));
                      setCurrentPage(1);
                    }}
                    className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm"
                  >
                    <option value={10}>10</option>
                    <option value={25}>25</option>
                    <option value={50}>50</option>
                    <option value={100}>100</option>
                  </select>
                  <span className="text-sm text-gray-700">
                    Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredAndSortedGroups.length)} of {filteredAndSortedGroups.length} Sale Orders
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                    disabled={currentPage === 1}
                    className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50"
                  >
                    Previous
                  </button>
                  <span className="text-sm text-gray-700">
                    Page {currentPage} of {totalPages}
                  </span>
                  <button
                    onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                    disabled={currentPage >= totalPages}
                    className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

