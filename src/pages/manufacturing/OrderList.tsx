import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useManufacturingOrders } from '../../hooks/useManufacturing';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
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
  const { user } = useAuth();
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
  // Filter to show/hide completed projects
  const [showCompleted, setShowCompleted] = useState(false);
  
  const loading = loadingSO;
  const error = null;
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const refetch = async () => {
    // Refetch Sales Orders to ensure data is up to date
    // CRITICAL: This ensures Sales Orders remain visible after MO creation
    // The name "saleOrdersWithoutMO" is misleading - it contains ALL Confirmed Sales Orders
    if (import.meta.env.DEV) {
      if (import.meta.env.DEV) {
        console.log('🔄 OrderList: Refetching all data...');
        console.log('   IMPORTANT: This will show ALL Confirmed Sales Orders (with and without MO)');
      }
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

  // Load SaleOrders that are ready for manufacturing
  // Statuses: 'Confirmed', 'Scheduled for Production', 'In Production'
  // IMPORTANT: OrderList shows ALL SalesOrders in these statuses (with or without MO)
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
      
      const statusesToLoad = showCompleted
        ? ['confirmed', 'on_hold', 'delivered', 'closed']
        : ['confirmed', 'on_hold'];

      const { data: allSaleOrders, error: soError } = await supabase
        .from('SalesOrders')
        .select(`
          id, sales_order_no, status, payment_status, created_at, quote_id, customer_id,
          DirectoryCustomers:customer_id (id, customer_name)
        `)
        .eq('organization_id', activeOrganizationId)
        .in('status', statusesToLoad)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (soError) {
        if (import.meta.env.DEV) console.error('OrderList: Error loading SalesOrders:', soError);
        setSaleOrdersWithoutMO([]);
        return;
      }

      const ordersWithCustomers = allSaleOrders || [];

      // Get all ManufacturingOrders to show status (but don't filter out SaleOrders)
      // IMPORTANT: This query must include ALL MOs, including newly created ones
      const { data: manufacturingOrders, error: moError } = await supabase
        .from('ManufacturingOrders')
        .select('sales_order_id, production_status, status, manufacturing_order_no, created_at')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false }); // Most recent first for debugging

      if (moError && import.meta.env.DEV) {
        console.warn('[OrderList] ManufacturingOrders error:', moError);
      }

      const saleOrderToMO = new Map<string, any>();
      if (manufacturingOrders) {
        manufacturingOrders.forEach((mo: any) => {
          if (mo.sales_order_id) {
            const existing = saleOrderToMO.get(mo.sales_order_id);
            if (!existing || (mo.created_at && existing.created_at && mo.created_at > existing.created_at)) {
              saleOrderToMO.set(mo.sales_order_id, mo);
            }
          }
        });
      }

      // Show ALL Confirmed Sales Orders (with or without MO)
      // IMPORTANT: NO FILTERING - all confirmed Sales Orders must appear
      // Enrich each Sales Order with its MO info if it exists
      const enrichedSaleOrders = ordersWithCustomers.map((so: any) => {
        const mo = saleOrderToMO.get(so.id) || null;
        return {
          ...so,
          ManufacturingOrder: mo
        };
      });

      setSaleOrdersWithoutMO(enrichedSaleOrders);
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error loading SaleOrders without MO:', err);
      }
      setSaleOrdersWithoutMO([]);
    } finally {
      setLoadingSO(false);
    }
  };

  useEffect(() => {
    loadSaleOrdersWithoutMO();
  }, [activeOrganizationId, showCompleted]);

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
        saleOrderNo: so.sales_order_no || so.sale_order_no || 'N/A',
        customerName: so.DirectoryCustomers?.customer_name || 'N/A',
        priority: so.priority_code || 'normal',
        createdAt: so.created_at,
        manufacturingOrderNo: so.ManufacturingOrder?.manufacturing_order_no || null,
        moStatus: so.ManufacturingOrder?.production_status || so.ManufacturingOrder?.status || null,
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
      let aValue: any = sortBy === 'created_at' ? a.createdAt : (sortBy === 'sale_order_no' ? a.saleOrderNo : (sortBy === 'customer_name' ? a.customerName : a[sortBy as keyof OrderListItem]));
      let bValue: any = sortBy === 'created_at' ? b.createdAt : (sortBy === 'sale_order_no' ? b.saleOrderNo : (sortBy === 'customer_name' ? b.customerName : b[sortBy as keyof OrderListItem]));

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


  const handleCreateMO = async (saleOrderId: string, saleOrderNo: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!user?.id) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: 'User not authenticated.' });
      return;
    }
    try {
      const { data: rpcResult, error: rpcError } = await supabase
        .rpc('create_manufacturing_order', {
          p_sales_order_id: saleOrderId,
          p_user_id: user.id,
          p_user_name: user.name ?? null,
        });

      if (rpcError) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Cannot Release',
          message: rpcError.message || 'Failed to create manufacturing order.',
        });
        return;
      }

      const moNumber = rpcResult?.mo_number ?? 'MO';

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Released to Manufacturing',
        message: `Created ${moNumber}. You can generate BOM from the MO detail.`,
      });
      refetch();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err?.message || 'Failed to create manufacturing order.',
      });
    }
  };

  if (loading) return <div className="py-6 px-6" />;

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
            {`Manage your ${filteredOrders.length} ${showCompleted ? 'sales orders (including completed)' : 'active sales orders'}${filteredOrders.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
      </div>

      {/* Search and Filters */}
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
            <div className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-md bg-white hover:bg-gray-50 transition-colors">
              <input
                type="checkbox"
                id="show-completed"
                checked={showCompleted}
                onChange={(e) => {
                  setShowCompleted(e.target.checked);
                  setCurrentPage(1);
                }}
                className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary focus:ring-2 cursor-pointer"
              />
              <label 
                htmlFor="show-completed" 
                className="text-sm text-gray-700 cursor-pointer select-none font-medium"
              >
                Show Completed
              </label>
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="table-fit-wrapper">
          <table className="table-fit">
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
                      <p className="text-gray-600 mb-2">
                        {showCompleted 
                          ? 'No sales orders found' 
                          : 'No active sales orders found'}
                      </p>
                      <p className="text-sm text-gray-500">
                        {displayOrders.length === 0 
                          ? (showCompleted 
                              ? 'Sales orders will appear here when they are confirmed or completed'
                              : 'Confirmed sales orders will appear here when sales orders are confirmed (changed from Draft to Confirmed). Enable "Show Completed" to see archived orders.')
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

