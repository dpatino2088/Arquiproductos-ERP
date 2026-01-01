import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useSaleOrders, SaleOrderStatus } from '../../hooks/useSaleOrders';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { 
  Search, 
  Filter,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  Edit,
  Eye,
  Trash2,
  Archive,
  FileText
} from 'lucide-react';

interface SaleOrderItem {
  id: string;
  saleOrderNo: string;
  status: SaleOrderStatus;
  customerName: string;
  quoteNo: string;
  subtotal: number;
  tax: number;
  total: number;
  currency: string;
  orderDate: string;
  createdAt: string;
}

// Function to get status badge color
const getStatusBadgeColor = (status: SaleOrderStatus) => {
  switch (status) {
    case 'Draft':
      return 'bg-gray-50 text-gray-700';
    case 'Confirmed':
      return 'bg-blue-50 text-blue-700';
    case 'Scheduled for Production':
      return 'bg-yellow-50 text-yellow-700';
    case 'In Production':
      return 'bg-orange-50 text-orange-700';
    case 'Ready for Delivery':
      return 'bg-purple-50 text-purple-700';
    case 'Delivered':
      return 'bg-green-50 text-green-700';
    case 'Cancelled':
      return 'bg-red-50 text-red-700';
    default:
      return 'bg-gray-50 text-gray-700';
  }
};

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

export default function SaleOrders() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId, activeOrganization, loading: orgLoading } = useOrganizationContext();
  
  // Debug log for organization
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('🔍 SaleOrders - Organization context:', {
        activeOrganizationId,
        activeOrganization: activeOrganization?.name,
        orgLoading,
        hasOrg: !!activeOrganizationId,
      });
    }
  }, [activeOrganizationId, activeOrganization, orgLoading]);
  
  const { saleOrders, loading, error, refetch } = useSaleOrders();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'saleOrderNo' | 'status' | 'customerName' | 'quoteNo' | 'total' | 'orderDate'>('saleOrderNo');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedStatus, setSelectedStatus] = useState<SaleOrderStatus[]>([]);

  useEffect(() => {
    // Sale Orders is now an independent module, no submodules needed
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/sale-orders')) {
      // Clear any existing submodules since this is now a standalone module
      clearSubmoduleNav();
    }
    
    // Cleanup: clear submodules when component unmounts or path changes
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/sale-orders')) {
        clearSubmoduleNav();
      }
    };
  }, [clearSubmoduleNav]);

  // Transform sale orders to display format
  const saleOrdersData: SaleOrderItem[] = useMemo(() => {
    if (!saleOrders) return [];
    return saleOrders.map(order => ({
      id: order.id,
      saleOrderNo: order.sale_order_no || 'N/A',
      status: order.status,
      customerName: order.DirectoryCustomers?.customer_name || 'N/A',
      quoteNo: order.Quotes?.quote_no || 'N/A',
      subtotal: order.subtotal || 0,
      tax: order.tax || 0,
      total: order.total || 0,
      currency: order.currency || 'USD',
      orderDate: order.order_date || order.created_at,
      createdAt: order.created_at,
    }));
  }, [saleOrders]);

  // Filter and sort sale orders
  const filteredSaleOrders = useMemo(() => {
    const filtered = saleOrdersData.filter(order => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        order.saleOrderNo.toLowerCase().includes(searchLower) ||
        order.customerName.toLowerCase().includes(searchLower) ||
        order.quoteNo.toLowerCase().includes(searchLower) ||
        order.status.toLowerCase().includes(searchLower)
      );

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(order.status);

      return matchesSearch && matchesStatus;
    });

    // Sort
    return filtered.sort((a, b) => {
      let aValue: any = a[sortBy];
      let bValue: any = b[sortBy];

      if (sortBy === 'orderDate' || sortBy === 'saleOrderNo') {
        if (sortBy === 'orderDate') {
          aValue = new Date(a.orderDate);
          bValue = new Date(b.orderDate);
        }
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else if (sortBy === 'total') {
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else {
        const strA = String(aValue).toLowerCase();
        const strB = String(bValue).toLowerCase();
        if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
        if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
    });
  }, [searchTerm, saleOrdersData, sortBy, sortOrder, selectedStatus]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredSaleOrders.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedSaleOrders = filteredSaleOrders.slice(startIndex, startIndex + itemsPerPage);

  // Reset to first page when search changes
  useMemo(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Handle status toggle
  const handleStatusToggle = (status: SaleOrderStatus) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedStatus([]);
    setSearchTerm('');
  };

  // Handlers for actions
  const handleEditSaleOrder = (order: SaleOrderItem, e?: React.MouseEvent) => {
    e?.stopPropagation();
    router.navigate(`/sale-orders/edit/${order.id}`);
  };

  const handleArchiveSaleOrder = async (order: SaleOrderItem, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Archivar Orden de Venta',
      message: `¿Estás seguro de que deseas archivar la orden de venta "${order.saleOrderNo}"?`,
      variant: 'warning',
      confirmText: 'Archivar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      if (!activeOrganizationId) return;
      
      setLoading(true);
      const { error } = await supabase
        .from('SalesOrders')
        .update({ archived: true })
        .eq('id', order.id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Orden archivada',
        message: 'La orden de venta ha sido archivada correctamente.',
      });
      
      refetch();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al archivar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteSaleOrder = async (order: SaleOrderItem, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Eliminar Orden de Venta',
      message: `¿Estás seguro de que deseas eliminar la orden de venta "${order.saleOrderNo}"? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      if (!activeOrganizationId) return;
      
      setLoading(true);
      const { error } = await supabase
        .from('SalesOrders')
        .update({ deleted: true })
        .eq('id', order.id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Orden eliminada',
        message: 'La orden de venta ha sido eliminada correctamente.',
      });
      
      refetch();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al eliminar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
  };

  const statusOptions: SaleOrderStatus[] = ['Draft', 'Confirmed', 'Scheduled for Production', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled'];

  // Show loading state (wait for organization to load first)
  if (orgLoading || loading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">
              {orgLoading ? 'Loading organization...' : 'Loading sales orders...'}
            </p>
          </div>
        </div>
      </div>
    );
  }

  // Show message if no organization is selected
  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium mb-2">No organization selected</p>
          <p className="text-sm text-yellow-700">
            Please select an organization to view sales orders.
          </p>
        </div>
      </div>
    );
  }

  // Show error state
  if (error) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading sales orders</p>
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
          <h1 className="text-xl font-semibold text-foreground mb-1">Sales Orders</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredSaleOrders.length} sales orders${filteredSaleOrders.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${
          showFilters ? 'rounded-t-lg' : 'rounded-lg'
        }`}>
          <div className="flex items-center justify-between gap-3">
            {/* Search Bar */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by order #, customer, quote #, or status..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg border transition-colors ${
                showFilters || selectedStatus.length > 0
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter className="w-4 h-4" />
              Filters
              {selectedStatus.length > 0 && (
                <span className="bg-white text-primary rounded-full px-2 py-0.5 text-xs font-semibold">
                  {selectedStatus.length}
                </span>
              )}
            </button>
            <div className="flex items-center gap-1 border border-gray-200 rounded-lg overflow-hidden">
              <button
                onClick={() => setViewMode('table')}
                className={`p-2 transition-colors ${
                  viewMode === 'table'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                <List className="w-4 h-4" />
              </button>
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 transition-colors ${
                  viewMode === 'grid'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                <Grid3X3 className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Filters Dropdown */}
          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="mb-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-gray-700">Status</span>
                  {selectedStatus.length > 0 && (
                    <button
                      onClick={() => setSelectedStatus([])}
                      className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                    >
                      Clear ({selectedStatus.length})
                    </button>
                  )}
                </div>
                <div className="flex flex-wrap gap-2">
                  {statusOptions.map((status) => (
                    <button
                      key={status}
                      onClick={() => handleStatusToggle(status)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                        selectedStatus.includes(status)
                          ? getStatusBadgeColor(status)
                          : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                      }`}
                    >
                      {status.replace('_', ' ').charAt(0).toUpperCase() + status.replace('_', ' ').slice(1)}
                    </button>
                  ))}
                </div>
              </div>
              <div className="flex justify-between items-center">
                <button 
                  onClick={clearAllFilters}
                  className="text-xs text-gray-500 hover:text-gray-700"
                >
                  Clear all filters
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Table View */}
      {viewMode === 'table' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('saleOrderNo')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Order #
                      {sortBy === 'saleOrderNo' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('status')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Status
                      {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('customerName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Customer
                      {sortBy === 'customerName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('quoteNo')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Quote #
                      {sortBy === 'quoteNo' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('total')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Total
                      {sortBy === 'total' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('orderDate')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Order Date
                      {sortBy === 'orderDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredSaleOrders.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                          <Search className="w-6 h-6 text-gray-400" />
                        </div>
                        <p className="text-gray-600 mb-2">No sales orders found</p>
                        <p className="text-sm text-gray-500">
                          {saleOrdersData.length === 0 
                            ? 'Sales orders will appear here when you approve quotes'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedSaleOrders.map((order) => (
                    <tr 
                      key={order.id} 
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                        {order.saleOrderNo}
                      </td>
                      <td className="py-4 px-6">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeColor(order.status)}`}>
                          {order.status.replace('_', ' ').charAt(0).toUpperCase() + order.status.replace('_', ' ').slice(1)}
                        </span>
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {order.customerName}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {order.quoteNo}
                      </td>
                      <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                        {formatCurrency(order.total, order.currency)}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {new Date(order.orderDate).toLocaleDateString()}
                      </td>
                      <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={(e) => handleEditSaleOrder(order, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Editar ${order.saleOrderNo}`}
                            title={`Editar ${order.saleOrderNo}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleArchiveSaleOrder(order, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Archivar ${order.saleOrderNo}`}
                            title={`Archivar ${order.saleOrderNo}`}
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleDeleteSaleOrder(order, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Eliminar ${order.saleOrderNo}`}
                            title={`Eliminar ${order.saleOrderNo}`}
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

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
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-sm text-gray-700">
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredSaleOrders.length)} of {filteredSaleOrders.length}
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

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
