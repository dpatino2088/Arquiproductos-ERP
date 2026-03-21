import { useEffect, useState, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useManufacturingOrders, ManufacturingOrderStatus } from '../../hooks/useManufacturing';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { usePermissions, useGranularAccess, useManufacturingAccess } from '../../hooks/usePermissions';
import { Search, Eye, Archive, RotateCcw, SortAsc, SortDesc } from 'lucide-react';
import Input from '../../components/ui/Input';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';

// ============================================================================
// TYPES
// ============================================================================

interface ManufacturingOrderItem {
  id: string;
  manufacturingOrderNo: string;
  status: ManufacturingOrderStatus | string | undefined;
  saleOrderNo: string;
  customerName: string;
  archived?: boolean;
  scheduledStartDate?: string | null;
  scheduledEndDate?: string | null;
  priority: string;
  createdAt: string;
}

// ============================================================================
// UTILITIES
// ============================================================================

const getPriorityBadgeColor = (priority: string) => {
  const p = (priority || '').toLowerCase();
  if (p === 'urgent' || p === 'rush') return 'bg-red-50 text-red-700';
  if (p === 'high') return 'bg-orange-50 text-orange-700';
  if (p === 'low') return 'bg-gray-50 text-gray-700';
  return 'bg-blue-50 text-blue-700';
};

// ============================================================================
// COMPONENT
// ============================================================================

export default function ManufacturingOrders() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();
  const { manufacturingOrders, loading, error, refetch } = useManufacturingOrders();
  const { can } = usePermissions();
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'manufacturing_order_no' | 'status' | 'sale_order_no' | 'planned_start_at' | 'priority'>('manufacturing_order_no');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [statusTab, setStatusTab] = useState('all');
  const [materialReadinessMap, setMaterialReadinessMap] = useState<Record<string, { status: string; has_shortage: boolean }>>({});

  const nonArchivedOrders = useMemo(
    () => manufacturingOrders.filter((mo) => !mo.archived),
    [manufacturingOrders]
  );
  const archivedOrders = useMemo(
    () => manufacturingOrders.filter((mo) => !!mo.archived),
    [manufacturingOrders]
  );

  const moStatusCounts = useMemo(() => {
    const c: Record<string, number> = {
      all: nonArchivedOrders.length,
      archived: archivedOrders.length,
    };
    nonArchivedOrders.forEach(mo => {
      const s = mo.status || 'draft';
      c[s] = (c[s] || 0) + 1;
    });
    return c;
  }, [nonArchivedOrders, archivedOrders]);

  const moStatusTabs = useMemo(() => [
    { label: 'All', value: 'all', count: moStatusCounts.all || 0 },
    { label: 'Draft', value: 'draft', count: moStatusCounts.draft || 0 },
    { label: 'Reviewed', value: 'confirmed', count: moStatusCounts.confirmed || 0 },
    { label: 'Planned', value: 'procurement', count: moStatusCounts.procurement || 0 },
    { label: 'Material Ready', value: 'materials_ready', count: moStatusCounts.materials_ready || 0 },
    { label: 'In Production', value: 'in_production', count: moStatusCounts.in_production || 0 },
    { label: 'Quality Check', value: 'quality_check', count: moStatusCounts.quality_check || 0 },
    { label: 'Ready for Delivery', value: 'ready_for_pickup', count: moStatusCounts.ready_for_pickup || 0 },
    { label: 'Delivered', value: 'delivered', count: (moStatusCounts.delivered || 0) + (moStatusCounts.completed || 0) },
    { label: 'Cancelled', value: 'cancelled', count: moStatusCounts.cancelled || 0 },
    { label: 'Archived', value: 'archived', count: moStatusCounts.archived || 0 },
  ], [moStatusCounts]);

  // Permission checks
  const { canViewMOs, canViewCosts } = useManufacturingAccess();
  const canRead = canViewMOs;
  const canWrite = can('manufacturing.write');
  const { canCreate: canCreateMO, canArchive: canArchiveMO, canDelete: canDeleteMO } = useGranularAccess('manufacturing');

  // Register Manufacturing submodules
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) {
      // Always register submodules to ensure tabs are visible
      registerSubmodules('Manufacturing', filteredSubmodules);
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

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
        saleOrderNo: mo.SalesOrders?.sales_order_no ?? 'N/A',
        customerName: mo.SalesOrders?.DirectoryCustomers?.customer_name ?? 'N/A',
        archived: !!mo.archived,
        scheduledStartDate: mo.planned_start_at ?? null,
        scheduledEndDate: mo.planned_end_at ?? null,
        priority: mo.priority ?? 'normal',
        createdAt: mo.created_at,
      }));
  }, [manufacturingOrders]);

  // Filter and sort
  const filteredAndSorted = useMemo(() => {
    let filtered = displayOrders;

    if (statusTab === 'archived') {
      filtered = filtered.filter((mo) => !!mo.archived);
    } else {
      filtered = filtered.filter((mo) => !mo.archived);
    }

    // StatusTabs filter (non-archived tabs only)
    if (statusTab !== 'all' && statusTab !== 'archived') {
      if (statusTab === 'delivered') {
        filtered = filtered.filter(mo => {
          const s = String(mo.status || '').toLowerCase();
          return s === 'delivered' || s === 'completed';
        });
      } else {
        filtered = filtered.filter(mo => {
          const s = (mo.status || '').toLowerCase().replace(/\s+/g, '_');
          return s === statusTab;
        });
      }
    }

    // Search filter
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      filtered = filtered.filter(mo =>
        mo.manufacturingOrderNo.toLowerCase().includes(searchLower) ||
        mo.saleOrderNo.toLowerCase().includes(searchLower) ||
        mo.customerName.toLowerCase().includes(searchLower)
      );
    }

    // Sort
    filtered = [...filtered].sort((a, b) => {
      let aVal: any = sortBy === 'sale_order_no' ? a.saleOrderNo : sortBy === 'manufacturing_order_no' ? a.manufacturingOrderNo : (a as unknown as Record<string, unknown>)[sortBy];
      let bVal: any = sortBy === 'sale_order_no' ? b.saleOrderNo : sortBy === 'manufacturing_order_no' ? b.manufacturingOrderNo : (b as unknown as Record<string, unknown>)[sortBy];

      if (sortBy === 'planned_start_at') {
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
  }, [displayOrders, searchTerm, sortBy, sortOrder, statusTab]);

  // Pagination
  const paginated = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredAndSorted.slice(start, start + itemsPerPage);
  }, [filteredAndSorted, currentPage, itemsPerPage]);

  const totalPages = Math.ceil(filteredAndSorted.length / itemsPerPage);

  const paginatedIds = useMemo(() => paginated.map((mo) => mo.id).join(','), [paginated]);

  // Fetch material readiness for current page (batch)
  useEffect(() => {
    if (!activeOrganizationId || paginated.length === 0) {
      setMaterialReadinessMap({});
      return;
    }
    const moIds = paginated.map((mo) => mo.id);
    supabase.rpc('get_mo_material_readiness_batch', { p_mo_ids: moIds }).then(({ data, error: err }: { data: unknown; error: unknown }) => {
      if (err || !Array.isArray(data)) {
        setMaterialReadinessMap({});
        return;
      }
      const map: Record<string, { status: string; has_shortage: boolean }> = {};
      for (const row of data as { mo_id: string; status: string; has_shortage: boolean }[]) {
        if (row?.mo_id) map[row.mo_id] = { status: row.status ?? 'incomplete', has_shortage: Boolean(row.has_shortage) };
      }
      setMaterialReadinessMap(map);
    });
  }, [activeOrganizationId, paginatedIds, paginated.length]);

  // Handlers
  const handleView = (id: string) => {
    router.navigate(`/manufacturing/manufacturing-orders/${id}`);
  };

  const handleArchive = async (id: string, orderNo: string) => {
    // Check write permission
    if (!canWrite) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No permission',
        message: 'You do not have permission to archive Manufacturing Orders. The "manufacturing.write" permission is required.',
      });
      return;
    }

    const confirmed = await showConfirm({
      title: 'Archive Manufacturing Order',
      message: `Archive Manufacturing Order "${orderNo}"? It will be hidden from active tabs.`,
      variant: 'info',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setDialogLoading(true);
      const { error: archiveError } = await supabase
        .from('ManufacturingOrders')
        .update({ archived: true })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      if (archiveError) throw archiveError;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Archived',
        message: `Manufacturing Order "${orderNo}" archived successfully.`,
      });

      refetch();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to archive manufacturing order',
      });
    } finally {
      setDialogLoading(false);
      closeDialog();
    }
  };

  const handleRestore = async (id: string, orderNo: string) => {
    if (!canWrite) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No permission',
        message: 'You do not have permission to restore Manufacturing Orders. The "manufacturing.write" permission is required.',
      });
      return;
    }

    const confirmed = await showConfirm({
      title: 'Restore Manufacturing Order',
      message: `Restore Manufacturing Order "${orderNo}"? It will return to active tabs.`,
      variant: 'info',
      confirmText: 'Restore',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setDialogLoading(true);
      const { error: restoreError } = await supabase
        .from('ManufacturingOrders')
        .update({ archived: false })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      if (restoreError) throw restoreError;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Restored',
        message: `Manufacturing Order "${orderNo}" restored successfully.`,
      });

      refetch();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to restore manufacturing order',
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

  // Check read permission
  if (!canRead) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No permission</p>
          <p className="text-sm text-yellow-700 mt-1">
            You do not have permission to view Manufacturing Orders.
            Contact an administrator to request the 'manufacturing.read' permission.
          </p>
        </div>
      </div>
    );
  }

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

      <StatusTabs tabs={moStatusTabs} activeTab={statusTab} onChange={setStatusTab} />

      {/* Search */}
      <div className="mb-4 mt-4">
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
            {searchTerm
              ? 'Try adjusting your search'
              : 'Create your first manufacturing order to get started'}
          </p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="table-fit-wrapper">
            <table className="table-fit">
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
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Materials</th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Sale Order</th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Customer</th>
                  <th className="py-3 px-6 text-left">
                    <button
                      onClick={() => handleSort('planned_start_at')}
                      className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900"
                    >
                      Scheduled Start
                      {sortBy === 'planned_start_at' && (
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
                      <StatusBadge status={(mo.status || 'draft').toString()} type="manufacturing" size="sm" />
                    </td>
                    <td className="py-4 px-6">
                      {materialReadinessMap[mo.id] ? (
                        materialReadinessMap[mo.id].has_shortage ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-amber-50 text-amber-800" title="Material demand not fully covered">Incomplete</span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-50 text-green-700">OK</span>
                        )
                      ) : (
                        <span className="text-gray-400 text-xs">—</span>
                      )}
                    </td>
                    <td className="py-4 px-6 text-sm text-gray-700">{mo.saleOrderNo}</td>
                    <td className="py-4 px-6 text-sm text-gray-700">{mo.customerName}</td>
                    <td className="py-4 px-6 text-sm text-gray-700">
                      {mo.scheduledStartDate
                        ? formatDate(mo.scheduledStartDate)
                        : 'Not scheduled'}
                    </td>
                    <td className="py-4 px-6">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getPriorityBadgeColor(mo.priority)}`}>
                        {(mo.priority ?? 'Normal').toString()}
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
                        {canWrite && canArchiveMO && (
                          <button
                            onClick={() => mo.archived
                              ? handleRestore(mo.id, mo.manufacturingOrderNo)
                              : handleArchive(mo.id, mo.manufacturingOrderNo)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors"
                            title={mo.archived ? 'Restore' : 'Archive'}
                          >
                            {mo.archived
                              ? <RotateCcw className="w-4 h-4 text-gray-600" />
                              : <Archive className="w-4 h-4 text-gray-600" />}
                          </button>
                        )}
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
