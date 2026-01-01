import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useManufacturingOrders, ManufacturingOrderStatus } from '../../hooks/useManufacturing';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { Search, Eye, Trash2, SortAsc, SortDesc } from 'lucide-react';
import Input from '../../components/ui/Input';

// ============================================================================
// TYPES
// ============================================================================

interface ManufacturingOrderItem {
  id: string;
  manufacturingOrderNo: string;
  status: ManufacturingOrderStatus;
  saleOrderNo: string;
  customerName: string;
  scheduledStartDate?: string | null;
  scheduledEndDate?: string | null;
  priority: string;
  createdAt: string;
}

// ============================================================================
// UTILITIES
// ============================================================================

const getStatusBadgeColor = (status: ManufacturingOrderStatus) => {
  switch (status) {
    case 'draft':
      return 'bg-gray-50 text-gray-700';
    case 'planned':
      return 'bg-blue-50 text-blue-700';
    case 'in_production':
      return 'bg-yellow-50 text-yellow-700';
    case 'completed':
      return 'bg-green-50 text-green-700';
    case 'cancelled':
      return 'bg-red-50 text-red-700';
    default:
      return 'bg-gray-50 text-gray-700';
  }
};

const getPriorityBadgeColor = (priority: string) => {
  switch (priority) {
    case 'urgent':
      return 'bg-red-50 text-red-700';
    case 'high':
      return 'bg-orange-50 text-orange-700';
    case 'low':
      return 'bg-gray-50 text-gray-700';
    default:
      return 'bg-blue-50 text-blue-700';
  }
};

// ============================================================================
// COMPONENT
// ============================================================================

export default function ManufacturingOrders() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();
  const { manufacturingOrders, loading, error, refetch } = useManufacturingOrders();
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'manufacturing_order_no' | 'status' | 'sale_order_no' | 'scheduled_start_date' | 'priority'>('manufacturing_order_no');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedStatus, setSelectedStatus] = useState<ManufacturingOrderStatus[]>([]);

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

  // Transform manufacturing orders to display format - INCLUDE all statuses including 'planned'
  const displayOrders: ManufacturingOrderItem[] = useMemo(() => {
    if (import.meta.env.DEV) {
      console.log('🔍 ManufacturingOrders: Total MOs fetched:', manufacturingOrders.length);
      console.log('   Statuses:', manufacturingOrders.map(mo => mo.status));
    }

    return manufacturingOrders
      .map(mo => ({
        id: mo.id,
        manufacturingOrderNo: mo.manufacturing_order_no,
        status: mo.status,
        saleOrderNo: mo.SalesOrders?.sale_order_no || 'N/A',
        customerName: mo.SalesOrders?.DirectoryCustomers?.customer_name || 'N/A',
        scheduledStartDate: mo.scheduled_start_date,
        scheduledEndDate: mo.scheduled_end_date,
        priority: mo.priority,
        createdAt: mo.created_at,
      }));
  }, [manufacturingOrders]);

  // Filter and sort
  const filteredAndSorted = useMemo(() => {
    let filtered = displayOrders;

    // Search filter
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      filtered = filtered.filter(mo =>
        mo.manufacturingOrderNo.toLowerCase().includes(searchLower) ||
        mo.saleOrderNo.toLowerCase().includes(searchLower) ||
        mo.customerName.toLowerCase().includes(searchLower)
      );
    }

    // Status filter
    if (selectedStatus.length > 0) {
      filtered = filtered.filter(mo => selectedStatus.includes(mo.status));
    }

    // Sort
    filtered = [...filtered].sort((a, b) => {
      let aVal: any = a[sortBy];
      let bVal: any = b[sortBy];

      if (sortBy === 'scheduled_start_date') {
        aVal = aVal ? new Date(aVal).getTime() : 0;
        bVal = bVal ? new Date(bVal).getTime() : 0;
      }

      if (typeof aVal === 'string') {
        aVal = aVal.toLowerCase();
        bVal = bVal.toLowerCase();
      }

      if (sortOrder === 'asc') {
        return aVal > bVal ? 1 : aVal < bVal ? -1 : 0;
      } else {
        return aVal < bVal ? 1 : aVal > bVal ? -1 : 0;
      }
    });

    return filtered;
  }, [displayOrders, searchTerm, selectedStatus, sortBy, sortOrder]);

  // Pagination
  const paginated = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredAndSorted.slice(start, start + itemsPerPage);
  }, [filteredAndSorted, currentPage, itemsPerPage]);

  const totalPages = Math.ceil(filteredAndSorted.length / itemsPerPage);

  // Handlers
  const handleView = (id: string) => {
    router.navigate(`/manufacturing/manufacturing-orders/${id}`);
  };

  const handleDelete = async (id: string, orderNo: string) => {
    const confirmed = await showConfirm({
      title: 'Delete Manufacturing Order',
      message: `Are you sure you want to delete Manufacturing Order "${orderNo}"? This action cannot be undone.`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setDialogLoading(true);
      const { error: deleteError } = await supabase
        .from('ManufacturingOrders')
        .update({ deleted: true })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      if (deleteError) throw deleteError;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: `Manufacturing Order "${orderNo}" deleted successfully`,
      });

      refetch();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to delete manufacturing order',
      });
    } finally {
      setDialogLoading(false);
      closeDialog();
    }
  };

  const handleSort = (column: typeof sortBy) => {
    if (sortBy === column) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(column);
      setSortOrder('desc');
    }
  };

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Manufacturing Orders</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage your {manufacturingOrders.length} manufacturing {manufacturingOrders.length === 1 ? 'order' : 'orders'}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by MO #, Sale Order #, or customer name..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {/* Status Filters */}
      <div className="mb-4 flex items-center gap-2 flex-wrap">
        <span className="text-sm text-gray-700">Filter by status:</span>
        {(['draft', 'planned', 'in_production', 'completed', 'cancelled'] as ManufacturingOrderStatus[]).map(status => (
          <button
            key={status}
            onClick={() => {
              setSelectedStatus(prev =>
                prev.includes(status)
                  ? prev.filter(s => s !== status)
                  : [...prev, status]
              );
            }}
            className={`px-3 py-1 text-xs rounded-full transition-colors ${
              selectedStatus.includes(status)
                ? getStatusBadgeColor(status)
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {status.replace('_', ' ').toUpperCase()}
          </button>
        ))}
        {selectedStatus.length > 0 && (
          <button
            onClick={() => setSelectedStatus([])}
            className="px-3 py-1 text-xs text-gray-600 hover:text-gray-900"
          >
            Clear
          </button>
        )}
      </div>

      {/* Error State */}
      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-sm text-red-800">{error}</p>
        </div>
      )}

      {/* Table */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-pulse space-y-4">
            <div className="h-4 bg-gray-200 rounded w-1/4 mx-auto"></div>
            <div className="h-4 bg-gray-200 rounded w-1/2 mx-auto"></div>
          </div>
        </div>
      ) : paginated.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <p className="text-gray-500 mb-2">No manufacturing orders found</p>
          <p className="text-sm text-gray-400">
            {searchTerm || selectedStatus.length > 0
              ? 'Try adjusting your search or filters'
              : 'Create your first manufacturing order to get started'}
          </p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="py-3 px-6 text-left">
                    <button
                      onClick={() => handleSort('manufacturing_order_no')}
                      className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900"
                    >
                      MO No
                      {sortBy === 'manufacturing_order_no' && (
                        sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />
                      )}
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left">
                    <button
                      onClick={() => handleSort('status')}
                      className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900"
                    >
                      Status
                      {sortBy === 'status' && (
                        sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />
                      )}
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Sale Order</th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Customer</th>
                  <th className="py-3 px-6 text-left">
                    <button
                      onClick={() => handleSort('scheduled_start_date')}
                      className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900"
                    >
                      Scheduled Start
                      {sortBy === 'scheduled_start_date' && (
                        sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />
                      )}
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left">
                    <button
                      onClick={() => handleSort('priority')}
                      className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900"
                    >
                      Priority
                      {sortBy === 'priority' && (
                        sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />
                      )}
                    </button>
                  </th>
                  <th className="py-3 px-6 text-right text-xs font-medium text-gray-700">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {paginated.map((mo) => (
                  <tr
                    key={mo.id}
                    className="hover:bg-gray-50 cursor-pointer transition-colors"
                    onClick={() => handleView(mo.id)}
                  >
                    <td className="py-4 px-6 text-sm font-medium text-gray-900">
                      {mo.manufacturingOrderNo}
                    </td>
                    <td className="py-4 px-6">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusBadgeColor(mo.status)}`}>
                        {mo.status.replace('_', ' ').toUpperCase()}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-sm text-gray-700">{mo.saleOrderNo}</td>
                    <td className="py-4 px-6 text-sm text-gray-700">{mo.customerName}</td>
                    <td className="py-4 px-6 text-sm text-gray-700">
                      {mo.scheduledStartDate
                        ? new Date(mo.scheduledStartDate).toLocaleDateString()
                        : 'Not scheduled'}
                    </td>
                    <td className="py-4 px-6">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getPriorityBadgeColor(mo.priority)}`}>
                        {mo.priority.toUpperCase()}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-right">
                      <div className="flex items-center justify-end gap-2" onClick={(e) => e.stopPropagation()}>
                        <button
                          onClick={() => handleView(mo.id)}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors"
                          title="View"
                        >
                          <Eye className="w-4 h-4 text-gray-600" />
                        </button>
                        <button
                          onClick={() => handleDelete(mo.id, mo.manufacturingOrderNo)}
                          className="p-1.5 hover:bg-red-50 rounded transition-colors"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4 text-red-600" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="px-6 py-4 border-t border-gray-200 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="text-sm text-gray-700">Show:</span>
                <select
                  value={itemsPerPage}
                  onChange={(e) => {
                    setItemsPerPage(Number(e.target.value));
                    setCurrentPage(1);
                  }}
                  className="px-2 py-1 border border-gray-300 rounded text-sm"
                >
                  <option value={10}>10</option>
                  <option value={25}>25</option>
                  <option value={50}>50</option>
                  <option value={100}>100</option>
                </select>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-sm text-gray-700">
                  Showing {(currentPage - 1) * itemsPerPage + 1}-
                  {Math.min(currentPage * itemsPerPage, filteredAndSorted.length)} of {filteredAndSorted.length}
                </span>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                    disabled={currentPage === 1}
                    className="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Previous
                  </button>
                  <span className="px-3 py-1 text-sm text-gray-700">
                    Page {currentPage} of {totalPages}
                  </span>
                  <button
                    onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                    disabled={currentPage === totalPages}
                    className="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Next
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Create Modal */}
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
