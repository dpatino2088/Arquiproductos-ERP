import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import { useUIStore } from '../../stores/ui-store';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { Search, ShoppingBag, Eye, Trash2, RefreshCw, Filter, Archive, RotateCcw } from 'lucide-react';
import { router } from '../../lib/router';

interface SalesOrderRow {
  id: string;
  sales_order_no: string;
  status: string;
  tracking_status?: string;
  payment_status: string;
  priority: string;
  dealer_id?: string;
  customer_id?: string;
  quote_id?: string | null;
  total_amount?: number;
  amount_paid?: number;
  notes?: string;
  created_at: string;
  updated_at: string;
  archived?: boolean;
  DirectoryCustomers?: { customer_name: string } | null;
  Dealers?: { dealer_name: string; dealer_no?: string | null } | null;
}

const STATUS_VALUES = ['all', 'draft', 'confirmed', 'on_hold', 'delivered', 'closed', 'cancelled'] as const;
const STATUS_LABELS: Record<string, string> = {
  all: 'All',
  draft: 'Draft',
  confirmed: 'Open',
  on_hold: 'On Hold',
  delivered: 'Completed',
  closed: 'Closed',
  cancelled: 'Cancelled',
};

export default function SalesOrdersPage() {
  const { activeOrganizationId } = useOrganizationContext();
  const { isPortal, isInternal } = useAccessContext();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();
  const addNotification = useUIStore((s) => s.addNotification);
  const [orders, setOrders] = useState<SalesOrderRow[]>([]);
  const [moCountBySoId, setMoCountBySoId] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);

  const load = useCallback(async () => {
    if (!activeOrganizationId) return;
      try {
        setLoading(true);
        setError(null);
        const { data, error: err } = await supabase
          .from('SalesOrders')
          .select(`
            id, sales_order_no, dealer_id, status, payment_status, priority, quote_id, customer_id,
            total_amount, amount_paid, notes, created_at, updated_at, archived,
            DirectoryCustomers:customer_id (customer_name),
            Dealers:dealer_id (dealer_name, dealer_no)
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });
        if (err) throw err;
        const orderList = data || [];
        setOrders(orderList);

        if (orderList.length === 0) {
          setMoCountBySoId({});
          return;
        }
        const soIds = orderList.map((o: SalesOrderRow) => o.id);
        const { data: moData } = await supabase
          .from('ManufacturingOrders')
          .select('sales_order_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .in('sales_order_id', soIds);
        const countBySo: Record<string, number> = {};
        (moData || []).forEach((row: { sales_order_id: string }) => {
          countBySo[row.sales_order_id] = (countBySo[row.sales_order_id] || 0) + 1;
        });
        setMoCountBySoId(countBySo);
      } catch (e: any) {
        setError(e?.message || 'Error loading sales orders');
      } finally {
        setLoading(false);
      }
  }, [activeOrganizationId]);

  useEffect(() => {
    if (!activeOrganizationId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    load();
  }, [activeOrganizationId, load]);

  const handleDelete = useCallback(
    async (order: SalesOrderRow, e: React.MouseEvent) => {
      e.stopPropagation();
      const confirmed = await showConfirm({
        title: 'Delete order',
        message: `Delete order ${order.sales_order_no}?`,
        variant: 'danger',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase
          .from('SalesOrders')
          .update({ deleted: true })
          .eq('id', order.id);
        if (err) throw err;
        setOrders((prev) => prev.filter((o) => o.id !== order.id));
        addNotification({ type: 'success', title: 'Deleted', message: 'Order deleted successfully' });
        await load();
      } catch (e: any) {
        addNotification({ type: 'error', title: 'Error', message: e?.message || 'Could not delete order' });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, addNotification, load]
  );

  const handleArchive = useCallback(
    async (order: SalesOrderRow, e: React.MouseEvent) => {
      e.stopPropagation();
      const confirmed = await showConfirm({
        title: 'Archive order',
        message: `Archive order ${order.sales_order_no}? It will be hidden from the list, not deleted.`,
        variant: 'info',
        confirmText: 'Archive',
        cancelText: 'Cancel',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase
          .from('SalesOrders')
          .update({ archived: true })
          .eq('id', order.id);
        if (err) throw err;
        setOrders((prev) => prev.filter((o) => o.id !== order.id));
        addNotification({ type: 'success', title: 'Archived', message: 'Order archived successfully' });
        await load();
      } catch (e: any) {
        addNotification({ type: 'error', title: 'Error', message: e?.message || 'Could not archive order' });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, addNotification, load]
  );

  const handleRestore = useCallback(
    async (order: SalesOrderRow, e: React.MouseEvent) => {
      e.stopPropagation();
      const confirmed = await showConfirm({
        title: 'Restore order',
        message: `Restore order ${order.sales_order_no}? It will appear again in the active list.`,
        variant: 'info',
        confirmText: 'Restore',
        cancelText: 'Cancel',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase
          .from('SalesOrders')
          .update({ archived: false })
          .eq('id', order.id);
        if (err) throw err;
        setOrders((prev) => prev.filter((o) => o.id !== order.id));
        addNotification({ type: 'success', title: 'Restored', message: 'Order restored successfully' });
        await load();
      } catch (e: any) {
        addNotification({ type: 'error', title: 'Error', message: e?.message || 'Could not restore order' });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, addNotification, load]
  );

  const nonArchivedOrders = useMemo(() => orders.filter((o) => !o.archived), [orders]);
  const archivedOrdersCount = useMemo(() => orders.filter((o) => o.archived).length, [orders]);

  const statusCounts = useMemo(() => {
    const counts: Record<string, number> = { all: nonArchivedOrders.length };
    nonArchivedOrders.forEach((o) => {
      const s = o.status || 'draft';
      counts[s] = (counts[s] || 0) + 1;
    });
    return counts;
  }, [nonArchivedOrders]);

  const tabs = useMemo(
    () => [
      ...STATUS_VALUES.map((v) => ({
        label: STATUS_LABELS[v] || v,
        value: v,
        count: statusCounts[v] || 0,
      })),
      { label: 'Archived', value: 'archived', count: archivedOrdersCount },
    ],
    [statusCounts, archivedOrdersCount]
  );

  const statusFilterValues = useMemo(() => STATUS_VALUES.filter((v) => v !== 'all'), []);

  const handleStatusToggle = useCallback((status: string) => {
    setSelectedStatus((prev) =>
      prev.includes(status) ? prev.filter((s) => s !== status) : [...prev, status]
    );
  }, []);

  const filtered = useMemo(() => {
    let list = activeTab === 'archived' ? orders.filter((o) => o.archived) : nonArchivedOrders;
    if (activeTab !== 'archived') {
      if (selectedStatus.length > 0) {
        list = list.filter((o) => selectedStatus.includes(o.status || 'draft'));
      } else if (activeTab !== 'all') {
        list = list.filter((o) => o.status === activeTab);
      }
    }
    if (searchTerm.trim()) {
      const s = searchTerm.toLowerCase();
      list = list.filter(
        (o) =>
          o.sales_order_no?.toLowerCase().includes(s) ||
          o.DirectoryCustomers?.customer_name?.toLowerCase().includes(s) ||
          o.Dealers?.dealer_name?.toLowerCase().includes(s) ||
          (o.Dealers?.dealer_no && String(o.Dealers.dealer_no).toLowerCase().includes(s)) ||
          o.notes?.toLowerCase().includes(s)
      );
    }
    return list;
  }, [orders, nonArchivedOrders, activeTab, searchTerm, selectedStatus]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / itemsPerPage));
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedOrders = useMemo(
    () => filtered.slice(startIndex, startIndex + itemsPerPage),
    [filtered, startIndex, itemsPerPage]
  );

  const formatCurrency = (v?: number | null) => {
    if (v == null) return '—';
    return '$' + Number(v).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  return (
    <div className="py-6 px-6">
      {/* Header: design system — title + subtitle left; actions right (ml-auto). Same structure as Quotes/Proposals. */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">{isPortal ? 'Orders' : 'Sales Orders'}</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {isPortal ? 'Track your orders and payments' : 'Manage confirmed orders and track payments'}
          </p>
        </div>
        <div className="flex items-center gap-3 ml-auto" />
      </div>

      <StatusTabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />

      {/* Search and Filters — mismo formato que Quotes: card py-6 px-6; botones px-2 py-1, icon 14px */}
      <div className="mb-4 mt-4">
        <div
          className={`bg-white border border-gray-200 py-6 px-6 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}
        >
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by SO # or customer..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-2 py-1 text-sm font-medium rounded border transition-colors ${
                showFilters || selectedStatus.length > 0
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter style={{ width: 14, height: 14 }} />
              Filters
              {selectedStatus.length > 0 && (
                <span className="bg-white text-blue-600 rounded-full px-2 py-0.5 text-xs font-semibold">
                  {selectedStatus.length}
                </span>
              )}
            </button>
            <button
              onClick={() => load()}
              className="flex items-center justify-center p-2 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors"
              title="Refresh"
            >
              <RefreshCw style={{ width: 14, height: 14 }} />
            </button>
          </div>

          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-gray-700">Status</span>
                {selectedStatus.length > 0 && (
                  <button
                    onClick={() => setSelectedStatus([])}
                    className="text-xs text-gray-500 hover:text-gray-700"
                  >
                    Clear
                  </button>
                )}
              </div>
              <div className="flex flex-wrap gap-2">
                {statusFilterValues.map((status) => (
                  <button
                    key={status}
                    onClick={() => handleStatusToggle(status)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                      selectedStatus.includes(status)
                        ? 'bg-blue-50 text-blue-700 border border-blue-200'
                        : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                    }`}
                  >
                    {STATUS_LABELS[status] || status}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {loading ? (
        <div className="bg-white border rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
          <p className="text-sm text-gray-600">Loading sales orders...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">{error}</p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4 min-h-[300px]">
          <div className="table-fit-wrapper">
            <table className="table-fit w-full text-sm">
              <colgroup>
                <col style={{ width: '15%' }} />
                {isInternal ? (
                  <>
                    <col style={{ width: '11%' }} />
                    <col style={{ width: '7%' }} />
                  </>
                ) : (
                  <col style={{ width: '12%' }} />
                )}
                <col style={{ width: '8%' }} />
                <col style={{ width: '8%' }} />
                {!isPortal && <col style={{ width: '6%' }} />}
                {!isPortal && <col style={{ width: '6%' }} />}
                {!isPortal && <col style={{ width: '6%' }} />}
                {!isPortal && <col style={{ width: '4%' }} />}
                <col style={{ width: '9%' }} />
                <col style={{ width: '9%' }} />
                <col style={{ width: '9%' }} />
              </colgroup>
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">SO #</th>
                  {isInternal ? (
                    <>
                      <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Dealer</th>
                      <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Dealer No</th>
                    </>
                  ) : (
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Customer</th>
                  )}
                  <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Status</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Payment</th>
                  {!isPortal && <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Priority</th>}
                  {!isPortal && <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Paid</th>}
                  {!isPortal && <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Balance</th>}
                  {!isPortal && <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">MOs</th>}
                  <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Date</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Total</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.length === 0 ? (
                  <tr>
                    <td
                      colSpan={7 + (isInternal ? 2 : 1) + (!isPortal ? 4 : 0)}
                      className="py-12 px-4 text-center"
                    >
                      <ShoppingBag className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No sales orders found</p>
                      <p className="text-sm text-gray-500">Sales orders are created from approved quotes</p>
                    </td>
                  </tr>
                ) : (
                  paginatedOrders.map((order) => {
                  const balance = (order.total_amount || 0) - (order.amount_paid || 0);
                  return (
                    <tr
                      key={order.id}
                      className="hover:bg-gray-50"
                    >
                      <td className="py-4 px-4 text-gray-900 text-sm font-medium text-left">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            router.navigate(`/sales/orders/${order.id}`);
                          }}
                          className="text-primary hover:underline"
                        >
                          {order.sales_order_no}
                        </button>
                      </td>
                      {isInternal ? (
                        <>
                          <td className="py-4 px-4 text-gray-700 text-sm text-center">
                            <span className="block truncate">{order.Dealers?.dealer_name ?? '—'}</span>
                          </td>
                          <td className="py-4 px-4 text-gray-600 text-sm text-center font-mono">
                            {order.Dealers?.dealer_no ?? '—'}
                          </td>
                        </>
                      ) : (
                        <td className="py-4 px-4 text-gray-700 text-sm text-center">
                          <span className="block truncate">{order.DirectoryCustomers?.customer_name ?? '—'}</span>
                        </td>
                      )}
                      <td className="py-4 px-4 text-center">
                        <StatusBadge status={order.status} type="salesOrder" size="sm" />
                      </td>
                      <td className="py-4 px-4 text-center">
                        <StatusBadge status={order.payment_status || 'pending'} type="payment" size="sm" />
                      </td>
                      {!isPortal && (
                        <td className="py-4 px-4 text-center">
                          {order.priority && order.priority !== 'normal' ? (
                            <StatusBadge status={order.priority} type="priority" size="sm" />
                          ) : (
                            '—'
                          )}
                        </td>
                      )}
                      {!isPortal && (
                        <td className="py-4 px-4 text-gray-600 text-sm text-center font-mono">
                          {formatCurrency(order.amount_paid)}
                        </td>
                      )}
                      {!isPortal && (
                        <td className="py-4 px-4 text-gray-600 text-sm text-center font-mono">{formatCurrency(balance)}</td>
                      )}
                      {!isPortal && (
                        <td className="py-4 px-4 text-gray-700 text-sm text-center">
                          {(moCountBySoId[order.id] ?? 0) === 0 ? '—' : moCountBySoId[order.id] === 1 ? '1 MO' : `${moCountBySoId[order.id]} MOs`}
                        </td>
                      )}
                      <td className="py-4 px-4 text-gray-600 text-sm text-center">
                        {new Date(order.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-4 px-4 text-gray-900 text-sm font-medium text-center">
                        {formatCurrency(order.total_amount)}
                      </td>
                      <td className="py-4 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end flex-nowrap">
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              router.navigate(`/sales/orders/${order.id}`);
                            }}
                            className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                            title="View"
                          >
                            <Eye style={{ width: 14, height: 14 }} />
                          </button>
                          {activeTab === 'archived' ? (
                            <button
                              type="button"
                              onClick={(e) => handleRestore(order, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Restore"
                            >
                              <RotateCcw style={{ width: 14, height: 14 }} />
                            </button>
                          ) : isPortal ? (
                            <button
                              type="button"
                              onClick={(e) => handleArchive(order, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Archive"
                            >
                              <Archive style={{ width: 14, height: 14 }} />
                            </button>
                          ) : (
                            <button
                              type="button"
                              onClick={(e) => handleDelete(order, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Delete"
                            >
                              <Trash2 style={{ width: 14, height: 14 }} />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Pagination — mismo formato que Quotes y Proposals; mt-4 = space between container and footer */}
      {!loading && !error && (
        <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-700">Show:</span>
              <select
                value={itemsPerPage}
                onChange={(e) => {
                  setItemsPerPage(Number(e.target.value));
                  setCurrentPage(1);
                }}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              >
                <option value={10}>10</option>
                <option value={25}>25</option>
                <option value={50}>50</option>
                <option value={100}>100</option>
              </select>
              <span className="text-sm text-gray-700">
                Showing {filtered.length === 0 ? 0 : startIndex + 1}-
                {Math.min(startIndex + itemsPerPage, filtered.length)} of {filtered.length}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                className="px-3 py-1 border border-gray-200 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Previous
              </button>
              <span className="text-sm text-gray-700">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
                disabled={currentPage >= totalPages}
                className="px-3 py-1 border border-gray-200 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        variant={dialogState.variant}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
