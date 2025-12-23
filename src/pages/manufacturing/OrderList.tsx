import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useManufacturingOrders } from '../../hooks/useManufacturing';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase/client';
import { Search, SortAsc, SortDesc, Plus } from 'lucide-react';
import Input from '../../components/ui/Input';

// ============================================================================
// TYPES
// ============================================================================

interface OrderListItem {
  id: string;
  type: 'sale_order';
  saleOrderId: string;
  status: 'needs_mo' | 'has_mo';
  saleOrderNo: string;
  customerName: string;
  priority: string;
  createdAt: string;
  manufacturingOrderNo?: string | null;
  moStatus?: string | null;
}

// ============================================================================
// UTILITIES
// ============================================================================

const getStatusBadgeColor = (status: 'needs_mo' | 'has_mo') => {
  switch (status) {
    case 'needs_mo':
      return 'bg-yellow-50 text-yellow-700';
    case 'has_mo':
      return 'bg-blue-50 text-blue-700';
    default:
      return 'bg-gray-50 text-gray-700';
  }
};

const getStatusLabel = (status: 'needs_mo' | 'has_mo') => {
  switch (status) {
    case 'needs_mo':
      return 'Needs MO';
    case 'has_mo':
      return 'Has MO';
    default:
      return 'Unknown';
  }
};

// ============================================================================
// COMPONENT
// ============================================================================

export default function OrderList() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  // Note: We don't actually need refetchMO here, but keeping for consistency
  const { refetch: refetchMO } = useManufacturingOrders();
  // IMPORTANT: This state contains ALL Confirmed Sales Orders (with and without MO)
  // The name is misleading but kept for backward compatibility
  const [saleOrdersWithoutMO, setSaleOrdersWithoutMO] = useState<any[]>([]);
  const [loadingSO, setLoadingSO] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  // Default sort: most recently approved first (created_at DESC)
  const [sortBy, setSortBy] = useState<'sale_order_no' | 'customer_name' | 'created_at'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  
  const loading = loadingSO;
  const error = null;
  
  const refetch = async () => {
    // Refetch Sales Orders to ensure data is up to date
    // CRITICAL: This ensures Sales Orders remain visible after MO creation
    // The name "saleOrdersWithoutMO" is misleading - it contains ALL Confirmed Sales Orders
    if (import.meta.env.DEV) {
      console.log('🔄 OrderList: Refetching all data...');
      console.log('   IMPORTANT: This will show ALL Confirmed Sales Orders (with and without MO)');
    }
    // Small delay to ensure any pending database transactions are committed
    await new Promise(resolve => setTimeout(resolve, 300));
    // Call loadSaleOrdersWithoutMO directly - it shows ALL Confirmed Sales Orders
    await loadSaleOrdersWithoutMO();
    // Also refetch MOs for consistency (though we don't strictly need it)
    refetchMO();
  };

  // Register Manufacturing submodules
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

  // Load SaleOrders that are Confirmed (status = 'Confirmed') 
  // and don't have ManufacturingOrders
  // IMPORTANT: OrderList should only show SalesOrders with status = 'Confirmed'
  // SalesOrders created from Quote have status = 'Draft' and should NOT appear here
  const loadSaleOrdersWithoutMO = async () => {
    if (!activeOrganizationId) {
      setLoadingSO(false);
      return;
    }

    try {
      setLoadingSO(true);
      
      if (import.meta.env.DEV) {
        console.log('🔍 OrderList: Loading Confirmed Sales Orders for organization:', activeOrganizationId);
      }
      
      // Get all Sales Orders with status = 'Confirmed'
      // These are Sales Orders that have been manually confirmed (changed from Draft to Confirmed)
      // SalesOrders created from Quote have status = 'Draft' and will NOT appear here
      const { data: allSaleOrders, error: soError } = await supabase
        .from('SalesOrders')
        .select(`
          id,
          sale_order_no,
          customer_id,
          status,
          order_progress_status,
          created_at,
          DirectoryCustomers:customer_id (
            id,
            customer_name
          )
        `)
        .eq('organization_id', activeOrganizationId)
        .eq('status', 'Confirmed')
        .eq('deleted', false)
        .order('created_at', { ascending: false }); // Most recent first

      if (soError) {
        console.error('❌ OrderList: Error loading SaleOrders:', soError);
        setSaleOrdersWithoutMO([]);
        return;
      }

      if (import.meta.env.DEV) {
        console.log('✅ OrderList: Found', allSaleOrders?.length || 0, 'Confirmed Sales Orders');
        if (allSaleOrders && allSaleOrders.length > 0) {
          console.log('📋 OrderList: Sales Orders:', allSaleOrders.map((so: any) => ({
            id: so.id,
            sale_order_no: so.sale_order_no,
            status: so.status,
            customer: so.DirectoryCustomers?.customer_name
          })));
        } else {
          console.log('⚠️ OrderList: No Confirmed Sales Orders found. Checking Draft orders...');
          // Debug: Check if there are Draft orders
          const { data: draftOrders } = await supabase
            .from('SalesOrders')
            .select('id, sale_order_no, status')
            .eq('organization_id', activeOrganizationId)
            .eq('status', 'Draft')
            .eq('deleted', false)
            .limit(5);
          if (draftOrders && draftOrders.length > 0) {
            console.log('ℹ️ OrderList: Found', draftOrders.length, 'Draft Sales Orders. These need to be confirmed to appear in OrderList.');
            console.log('📋 Draft Orders:', draftOrders.map((so: any) => ({
              sale_order_no: so.sale_order_no,
              status: so.status
            })));
          }
        }
      }

      // Get all ManufacturingOrders to show status (but don't filter out SaleOrders)
      // IMPORTANT: This query must include ALL MOs, including newly created ones
      const { data: manufacturingOrders, error: moError } = await supabase
        .from('ManufacturingOrders')
        .select('sale_order_id, status, manufacturing_order_no, created_at')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false }); // Most recent first for debugging

      if (moError) {
        console.error('Error loading ManufacturingOrders:', moError);
        // Continue anyway - we'll show all Sales Orders
      }

      // Create a map of SalesOrder IDs to their Manufacturing Orders
      // IMPORTANT: Use the MOST RECENT MO if there are multiple (shouldn't happen, but just in case)
      const saleOrderToMO = new Map<string, any>();
      if (manufacturingOrders && manufacturingOrders.length > 0) {
        if (import.meta.env.DEV) {
          console.log('📋 OrderList: Found', manufacturingOrders.length, 'ManufacturingOrders');
        }
        manufacturingOrders.forEach((mo: any) => {
          if (mo.sale_order_id) {
            // If multiple MOs exist for same SO, keep the most recent one
            const existingMO = saleOrderToMO.get(mo.sale_order_id);
            if (!existingMO || (mo.created_at && existingMO.created_at && mo.created_at > existingMO.created_at)) {
              saleOrderToMO.set(mo.sale_order_id, mo);
            }
          }
        });
        if (import.meta.env.DEV) {
          console.log('📋 OrderList: Mapped', saleOrderToMO.size, 'Sales Orders to Manufacturing Orders');
        }
      }

      // Show ALL Confirmed Sales Orders (with or without MO)
      // IMPORTANT: NO FILTERING - all confirmed Sales Orders must appear
      // Enrich each Sales Order with its MO info if it exists
      const enrichedSaleOrders = (allSaleOrders || []).map((so: any) => {
        const mo = saleOrderToMO.get(so.id) || null;
        return {
          ...so,
          ManufacturingOrder: mo
        };
      });

      if (import.meta.env.DEV) {
        console.log('✅ OrderList: Setting', enrichedSaleOrders.length, 'enriched Sales Orders');
        console.log('📊 OrderList: Breakdown:', {
          total: enrichedSaleOrders.length,
          withMO: enrichedSaleOrders.filter((so: any) => so.ManufacturingOrder !== null).length,
          withoutMO: enrichedSaleOrders.filter((so: any) => so.ManufacturingOrder === null).length
        });
        // Log each Sales Order to verify they're all there
        enrichedSaleOrders.forEach((so: any) => {
          console.log('  📋', so.sale_order_no, ':', so.ManufacturingOrder ? `Has MO (${so.ManufacturingOrder.manufacturing_order_no})` : 'Needs MO');
        });
      }

      // CRITICAL: Always set ALL enriched Sales Orders, NEVER filter them out
      // This ensures Sales Orders remain visible even after MO creation
      setSaleOrdersWithoutMO(enrichedSaleOrders);
      
      if (import.meta.env.DEV) {
        console.log('✅ OrderList: State updated with', enrichedSaleOrders.length, 'Sales Orders');
      }
    } catch (err) {
      console.error('Error loading SaleOrders without MO:', err);
      setSaleOrdersWithoutMO([]);
    } finally {
      setLoadingSO(false);
    }
  };

  useEffect(() => {
    loadSaleOrdersWithoutMO();
  }, [activeOrganizationId]);

  // Transform to display format: ALL Confirmed SaleOrders (with or without MO)
  // Status changes based on whether they have MO or not, but they all appear
  const displayOrders: OrderListItem[] = useMemo(() => {
    return saleOrdersWithoutMO.map(so => {
      const hasMO = so.ManufacturingOrder !== null;
      return {
        id: so.id,
        type: 'sale_order' as const,
        saleOrderId: so.id,
        status: hasMO ? 'has_mo' as const : 'needs_mo' as const,
        saleOrderNo: so.sale_order_no || 'N/A',
        customerName: so.DirectoryCustomers?.customer_name || 'N/A',
        priority: 'normal',
        createdAt: so.created_at,
        manufacturingOrderNo: so.ManufacturingOrder?.manufacturing_order_no || null,
        moStatus: so.ManufacturingOrder?.status || null,
      };
    });
  }, [saleOrdersWithoutMO]);

  // Filter and sort
  const filteredOrders = useMemo(() => {
    const filtered = displayOrders.filter(order => {
      const searchLower = searchTerm.toLowerCase();
      return !searchTerm || (
        order.saleOrderNo.toLowerCase().includes(searchLower) ||
        order.customerName.toLowerCase().includes(searchLower)
      );
    });

    // Sort orders - default: most recent first (created_at DESC)
    return filtered.sort((a, b) => {
      let aValue: any = a[sortBy];
      let bValue: any = b[sortBy];

      if (sortBy === 'created_at') {
        aValue = new Date(a.createdAt);
        bValue = new Date(b.createdAt);
        // Default: DESC (most recent first)
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else {
        const strA = String(aValue || '').toLowerCase();
        const strB = String(bValue || '').toLowerCase();
        if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
        if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
    });
  }, [displayOrders, searchTerm, sortBy, sortOrder]);

  // Pagination
  const totalPages = Math.ceil(filteredOrders.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedOrders = filteredOrders.slice(startIndex, startIndex + itemsPerPage);

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };


  // Handle create ManufacturingOrder from SaleOrder
  const handleCreateMO = async (saleOrderId: string, saleOrderNo: string, e: React.MouseEvent) => {
    e.stopPropagation();
    
    try {
      // First, generate the manufacturing order number using RPC
      const { data: moNumberData, error: numberError } = await supabase
        .rpc('get_next_document_number', {
          p_organization_id: activeOrganizationId,
          p_document_type: 'MO'
        });

      let manufacturingOrderNo: string;
      
      if (numberError || !moNumberData) {
        // Fallback: try get_next_sequential_number
        const { data: seqData, error: seqError } = await supabase
          .rpc('get_next_sequential_number', {
            p_table_name: 'ManufacturingOrders',
            p_column_name: 'manufacturing_order_no',
            p_prefix: 'MO-'
          });

        if (seqError || !seqData) {
          // Last fallback: manual generation
          const { data: lastMO } = await supabase
            .from('ManufacturingOrders')
            .select('manufacturing_order_no')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .order('created_at', { ascending: false })
            .limit(1)
            .single();

          if (lastMO?.manufacturing_order_no) {
            const match = lastMO.manufacturing_order_no.match(/MO-(\d+)/);
            const nextNum = match ? parseInt(match[1]) + 1 : 1;
            manufacturingOrderNo = `MO-${String(nextNum).padStart(6, '0')}`;
          } else {
            manufacturingOrderNo = 'MO-000001';
          }
        } else {
          manufacturingOrderNo = seqData;
        }
      } else {
        manufacturingOrderNo = moNumberData;
      }

      // Create ManufacturingOrder
      const { data: moData, error: moError } = await supabase
        .from('ManufacturingOrders')
        .insert({
          organization_id: activeOrganizationId,
          sale_order_id: saleOrderId,
          manufacturing_order_no: manufacturingOrderNo,
          status: 'planned',
          priority: 'normal',
        })
        .select()
        .single();

      if (moError) {
        // If MO already exists, that's okay
        if (moError.code === '23505') { // Unique violation
          useUIStore.getState().addNotification({
            type: 'info',
            title: 'Info',
            message: `Manufacturing Order already exists for ${saleOrderNo}`,
          });
        } else {
          throw moError;
        }
      } else {
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: `Manufacturing Order ${manufacturingOrderNo} created for ${saleOrderNo}`,
        });
      }
      
      // IMPORTANT: Refetch to update the list - Sales Order should remain visible with "Has MO" status
      // The Sales Order will NOT disappear, it will just change from "Needs MO" to "Has MO"
      if (import.meta.env.DEV) {
        console.log('🔄 OrderList: Refetching after MO creation to update status');
        console.log('✅ OrderList: Sales Order', saleOrderNo, '(ID:', saleOrderId, ') will remain visible with "Has MO" status');
      }
      
      // Wait for the database to commit the transaction
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Verify MO was created before refetching
      if (moData && moData.id) {
        if (import.meta.env.DEV) {
          console.log('✅ OrderList: MO created successfully:', moData.manufacturing_order_no, '(ID:', moData.id, ')');
        }
      } else {
        // Try to find the MO we just created
        const { data: verifyMO } = await supabase
          .from('ManufacturingOrders')
          .select('id, manufacturing_order_no')
          .eq('sale_order_id', saleOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false })
          .limit(1)
          .single();
        
        if (verifyMO) {
          if (import.meta.env.DEV) {
            console.log('✅ OrderList: Verified MO exists:', verifyMO.manufacturing_order_no);
          }
        } else {
          console.warn('⚠️ OrderList: Could not verify MO creation, but proceeding with refetch');
        }
      }
      
      // CRITICAL: Force reload by calling loadSaleOrdersWithoutMO directly
      // This ensures we get the latest data including the newly created MO
      // IMPORTANT: This function shows ALL Confirmed Sales Orders, with or without MO
      // The Sales Order will NOT disappear - it will just change from "Needs MO" to "Has MO"
      await loadSaleOrdersWithoutMO();
      
      // Double-check: Verify the Sales Order is still in the list after refetch
      if (import.meta.env.DEV) {
        // Wait a bit more to ensure state is fully updated
        await new Promise(resolve => setTimeout(resolve, 300));
        
        // Verify by checking the state
        const currentOrders = saleOrdersWithoutMO;
        const foundOrder = currentOrders.find((so: any) => so.id === saleOrderId);
        
        if (foundOrder) {
          console.log('✅ OrderList: Verified Sales Order', saleOrderNo, 'is still visible in list');
          console.log('   Status:', foundOrder.ManufacturingOrder ? 'Has MO' : 'Needs MO');
        } else {
          console.warn('⚠️ OrderList: Sales Order', saleOrderNo, 'not found in list after refetch. This should not happen!');
          console.warn('   Current orders count:', currentOrders.length);
          // Force another reload as fallback
          await loadSaleOrdersWithoutMO();
        }
      }
      
      // Also refetch MOs for consistency (though not strictly necessary)
      refetchMO();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create manufacturing order';
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage,
      });
    }
  };


  if (loading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading order list...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading order list</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Order List</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredOrders.length} confirmed sales orders${filteredOrders.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                type="text"
                placeholder="Search by Sales Order # or customer..."
                value={searchTerm}
                onChange={(e) => {
                  setSearchTerm(e.target.value);
                  setCurrentPage(1);
                }}
                className="pl-10"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('sale_order_no')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Sales Order #
                    {sortBy === 'sale_order_no' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('customer_name')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Customer
                    {sortBy === 'customer_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('created_at')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Created
                    {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 px-6 text-center">
                    <div className="flex flex-col items-center">
                      <p className="text-gray-600 mb-2">No confirmed sales orders found</p>
                      <p className="text-sm text-gray-500">
                        {displayOrders.length === 0 
                          ? 'Confirmed sales orders will appear here when sales orders are confirmed (changed from Draft to Confirmed)'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedOrders.map((order) => (
                  <tr 
                    key={order.id} 
                    className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                  >
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {order.saleOrderNo}
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {order.customerName}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex flex-col gap-1">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeColor(order.status)}`}>
                          {getStatusLabel(order.status)}
                        </span>
                        {order.status === 'has_mo' && order.manufacturingOrderNo && (
                          <span className="text-xs text-gray-500">
                            {order.manufacturingOrderNo} ({order.moStatus || 'N/A'})
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {new Date(order.createdAt).toLocaleDateString()}
                    </td>
                    <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center gap-1 justify-end">
                        {order.status === 'needs_mo' && (
                          <button 
                            onClick={(e) => handleCreateMO(order.saleOrderId, order.saleOrderNo, e)}
                            className="px-3 py-1.5 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors flex items-center gap-2"
                            aria-label={`Create MO for ${order.saleOrderNo}`}
                            title={`Create Manufacturing Order for ${order.saleOrderNo}`}
                          >
                            <Plus className="w-4 h-4" />
                            Create MO
                          </button>
                        )}
                        {order.status === 'has_mo' && (
                          <span className="text-sm text-gray-500 italic">MO Created</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-700">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
            >
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-sm text-gray-700">
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredOrders.length)} of {filteredOrders.length}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Previous
            </button>
            <span className="text-sm text-gray-700">
              Page {currentPage} of {totalPages || 1}
            </span>
            <button
              onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
              disabled={currentPage >= totalPages}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

