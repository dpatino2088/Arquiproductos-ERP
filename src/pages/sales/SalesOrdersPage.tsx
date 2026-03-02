import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import { useSalesOrders, type SalesOrder } from '../../hooks/useSalesOrders';
import { useUIStore } from '../../stores/ui-store';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { Search, ShoppingBag, Eye, ExternalLink, Trash2, Archive, RotateCcw } from 'lucide-react';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';

type SalesOrderRow = SalesOrder & {
  DirectoryCustomers?: { customer_name: string } | null;
  Dealers?: { dealer_name: string; dealer_no?: string | null } | null;
};

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

// Homogeneous center alignment and spacing for table columns (header and body match)
const TH_CENTER = 'text-center py-3 px-4 font-medium text-gray-700 text-xs';
const TD_CENTER = 'text-center py-4 px-4';

export default function SalesOrdersPage() {
  const { activeOrganizationId } = useOrganizationContext();
  const { isPortal, isInternal } = useAccessContext();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();
  const addNotification = useUIStore((s) => s.addNotification);
  const { salesOrders, loading, error, refetch } = useSalesOrders();
  const orders: SalesOrderRow[] = (salesOrders ?? []) as SalesOrderRow[];
  const [moCountBySoId, setMoCountBySoId] = useState<Record<string, number>>({});
  const [financialBySoId, setFinancialBySoId] = useState<Record<string, { total_paid: number }>>({});
  const [activeTab, setActiveTab] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);

  const canArchiveOrder = useCallback((order: { status?: string | null }) => {
    const s = (order.status || '').toLowerCase();
    return s === 'cancelled' || s === 'canceled' || s === 'delivered' || s === 'closed' || s === 'completed' || s === 'finished' || s === 'terminated';
  }, []);

  useEffect(() => {
    if (!activeOrganizationId || !orders.length) {
      if (!orders.length) setMoCountBySoId({});
      return;
    }
    const soIds = orders.map((o) => o.id);
    supabase
      .from('ManufacturingOrders')
      .select('sales_order_id')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .in('sales_order_id', soIds)
      .then(({ data }: { data: { sales_order_id: string }[] | null }) => {
        const countBySo: Record<string, number> = {};
        (data || []).forEach((row) => {
          countBySo[row.sales_order_id] = (countBySo[row.sales_order_id] || 0) + 1;
        });
        setMoCountBySoId(countBySo);
      });
  }, [activeOrganizationId, orders]);

  useEffect(() => {
    if (!orders.length) {
      setFinancialBySoId({});
      return;
    }
    const soIds = orders.map((o) => o.id);
    supabase
      .from('sales_order_financial_summary')
      .select('sales_order_id, total_paid')
      .in('sales_order_id', soIds)
      .then(({ data }: { data: { sales_order_id: string; total_paid: number | null }[] | null }) => {
        const nextBySo: Record<string, { total_paid: number }> = {};
        (data || []).forEach((row) => {
          nextBySo[row.sales_order_id] = {
            total_paid: Number(row.total_paid ?? 0),
          };
        });
        setFinancialBySoId(nextBySo);
      });
  }, [orders]);

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
        addNotification({ type: 'success', title: 'Deleted', message: 'Order deleted successfully' });
        await refetch();
      } catch (e: any) {
        addNotification({ type: 'error', title: 'Error', message: e?.message || 'Could not delete order' });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, addNotification, refetch]
  );

  const handleArchive = useCallback(
    async (order: SalesOrderRow, e: React.MouseEvent) => {
      e.stopPropagation();
      if (!canArchiveOrder(order)) {
        addNotification({
          type: 'error',
          title: 'Cannot archive',
          message: 'You can only archive orders that are cancelled or completed.',
        });
        return;
      }
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
        addNotification({ type: 'success', title: 'Archived', message: 'Order archived successfully' });
        await refetch();
      } catch (e: any) {
        addNotification({ type: 'error', title: 'Error', message: e?.message || 'Could not archive order' });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, addNotification, refetch, canArchiveOrder]
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
        addNotification({ type: 'success', title: 'Restored', message: 'Order restored successfully' });
        await refetch();
      } catch (e: any) {
        addNotification({ type: 'error', title: 'Error', message: e?.message || 'Could not restore order' });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, addNotification, refetch]
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

  const filtered = useMemo(() => {
    let list = activeTab === 'archived' ? orders.filter((o) => o.archived) : nonArchivedOrders;
    if (activeTab !== 'archived') {
      if (activeTab !== 'all') {
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
  }, [orders, nonArchivedOrders, activeTab, searchTerm]);

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
          <h1 className="text-xl font-semibold text-foreground">{isPortal ? 'Orders' : 'Sales Orders'}</h1>
        </div>
        <div className="flex items-center gap-3 ml-auto" />
      </div>

      <StatusTabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />

      {/* Search and Filters — mismo formato que Quotes: card py-6 px-6; botones px-2 py-1, icon 14px */}
      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
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
          </div>
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
                <col style={{ width: '11%' }} />
                {isInternal ? (
                  <>
                    <col style={{ width: '10%' }} />
                    <col style={{ width: '7%' }} />
                  </>
                ) : (
                  <col style={{ width: '11%' }} />
                )}
                <col style={{ width: '8%' }} />
                {!isPortal && <col style={{ width: '6%' }} />}
                {!isPortal && <col style={{ width: '6%' }} />}
                <col style={{ width: '8%' }} />
                <col style={{ width: '8%' }} />
                <col style={{ width: '9%' }} />
              </colgroup>
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">SO #</th>
                  {isInternal ? (
                    <>
                      <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Dealer</th>
                      <th className={TH_CENTER}>Dealer No</th>
                    </>
                  ) : (
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Customer</th>
                  )}
                  <th className={TH_CENTER}>Status</th>
                  {!isPortal && <th className={TH_CENTER}>Collection</th>}
                  {!isPortal && <th className={TH_CENTER}>MOs</th>}
                  <th className={TH_CENTER}>Date</th>
                  <th className={TH_CENTER}>Total</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.length === 0 ? (
                  <tr>
                    <td
                      colSpan={5 + (isInternal ? 2 : 1) + (!isPortal ? 2 : 0)}
                      className="py-12 px-4 text-center"
                    >
                      <ShoppingBag className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No sales orders found</p>
                      <p className="text-sm text-gray-500">Sales orders are created from approved quotes</p>
                    </td>
                  </tr>
                ) : (
                  paginatedOrders.map((order) => {
                  return (
                    <tr
                      key={order.id}
                      className="hover:bg-gray-50"
                    >
                      <td className="py-4 px-4 text-gray-900 text-sm font-normal text-left">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            router.navigate(withReturnTo(`/sales/orders/${order.id}`));
                          }}
                          className="grid text-left text-primary hover:underline"
                        >
                          {order.sales_order_no}
                        </button>
                      </td>
                      {isInternal ? (
                        <>
                          <td className="py-4 px-4 text-gray-700 text-sm text-left">
                            <span className="block truncate">{order.Dealers?.dealer_name ?? '—'}</span>
                          </td>
                          <td className={`${TD_CENTER} text-gray-600 text-sm font-mono`}>
                            {order.Dealers?.dealer_no ?? '—'}
                          </td>
                        </>
                      ) : (
                        <td className="py-4 px-4 text-gray-700 text-sm text-left">
                          <span className="block truncate">{order.DirectoryCustomers?.customer_name ?? '—'}</span>
                        </td>
                      )}
                      <td className={TD_CENTER}>
                        <div className="flex justify-center">
                          <StatusBadge status={order.status ?? 'draft'} type="salesOrder" size="sm" />
                        </div>
                      </td>
                      {!isPortal && (
                        <td className={TD_CENTER}>
                          <div className="flex justify-center">
                            {(() => {
                              const total = order.total_amount ?? 0;
                              const paid = financialBySoId[order.id]?.total_paid ?? 0;
                              const status = total <= 0
                                ? 'collection_unpaid'
                                : paid <= 0
                                  ? 'collection_unpaid'
                                  : paid >= total
                                    ? (paid > total ? 'collection_overpaid' : 'collection_paid')
                                    : 'collection_partial';
                              return <StatusBadge status={status} type="payment" size="sm" />;
                            })()}
                          </div>
                        </td>
                      )}
                      {!isPortal && (
                        <td className={`${TD_CENTER} text-gray-700 text-sm whitespace-nowrap`}>
                          {(moCountBySoId[order.id] ?? 0) === 0 ? '—' : moCountBySoId[order.id] === 1 ? '1 MO' : `${moCountBySoId[order.id]} MOs`}
                        </td>
                      )}
                      <td className={`${TD_CENTER} text-gray-600 text-sm`}>
                        {new Date(order.created_at).toLocaleDateString()}
                      </td>
                      <td className={`${TD_CENTER} text-gray-900 text-sm font-medium`}>
                        {formatCurrency(order.total_amount)}
                      </td>
                      <td className="py-4 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end flex-nowrap">
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              router.navigate(withReturnTo(`/sales/orders/${order.id}`));
                            }}
                            className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                            title="View"
                          >
                            <Eye style={{ width: 14, height: 14 }} />
                          </button>
                          {order.quote_id && (
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                router.navigate(withReturnTo(`/sales/quotes/${order.quote_id}`));
                              }}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Go to Quote"
                            >
                              <ExternalLink style={{ width: 14, height: 14 }} />
                            </button>
                          )}
                          {activeTab === 'archived' ? (
                            <button
                              type="button"
                              onClick={(e) => handleRestore(order, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Restore"
                            >
                              <RotateCcw style={{ width: 14, height: 14 }} />
                            </button>
                          ) : (
                            <>
                              <button
                                type="button"
                                onClick={(e) => handleArchive(order, e)}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                title="Archive"
                              >
                                <Archive style={{ width: 14, height: 14 }} />
                              </button>
                              {!isPortal && (
                                <button
                                  type="button"
                                  onClick={(e) => handleDelete(order, e)}
                                  className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                  title="Delete"
                                >
                                  <Trash2 style={{ width: 14, height: 14 }} />
                                </button>
                              )}
                            </>
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
                className="px-3 py-1 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
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
                className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Previous
              </button>
              <span className="text-sm text-gray-700">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
                disabled={currentPage >= totalPages}
                className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
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
