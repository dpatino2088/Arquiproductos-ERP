import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { usePurchaseOrders } from '../../hooks/usePurchaseOrders';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import { formatCurrency, formatDate } from '../../lib/utils';
import { Search } from 'lucide-react';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import FinancialSubTabs from './FinancialSubTabs';

const BILLING_TABS = [
  { value: 'all', label: 'All' },
  { value: 'unbilled', label: 'Unbilled' },
  { value: 'partial', label: 'Partial' },
  { value: 'billed', label: 'Billed' },
];

const SORT_OPTIONS = [
  { value: 'created_at:desc', label: 'Date (Recent)' },
  { value: 'po_number:asc', label: 'PO # (A-Z)' },
  { value: 'total:desc', label: 'Total (High to Low)' },
  { value: 'vendor:asc', label: 'Vendor (A-Z)' },
  { value: 'status:asc', label: 'Status' },
];

function getBillingStatus(po: { billing_status?: string | null }): string {
  return po.billing_status || 'unbilled';
}

export default function PurchaseOrdersAP() {
  const { registerSubmodules } = useSubmoduleNav();
  const [q, setQ] = useState('');
  const [billingFilter, setBillingFilter] = useState('all');
  const [sortKey, setSortKey] = useState('created_at:desc');
  const [page, setPage] = useState(1);
  const pageSize = 25;

  const { purchaseOrders, loading, error } = usePurchaseOrders({
    search: q || undefined,
  });

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const billingCounts = useMemo(() => {
    const counts: Record<string, number> = { all: purchaseOrders.length };
    purchaseOrders.forEach(po => {
      const bs = getBillingStatus(po);
      counts[bs] = (counts[bs] ?? 0) + 1;
    });
    return counts;
  }, [purchaseOrders]);

  const filtered = useMemo(() => {
    if (billingFilter === 'all') return purchaseOrders;
    return purchaseOrders.filter(po => getBillingStatus(po) === billingFilter);
  }, [purchaseOrders, billingFilter]);

  const sorted = useMemo(() => {
    const [field, dir] = sortKey.split(':');
    const asc = dir === 'asc';
    const result = [...filtered];
    result.sort((a, b) => {
      let cmp = 0;
      if (field === 'po_number') cmp = (a.po_number ?? '').localeCompare(b.po_number ?? '');
      else if (field === 'total') cmp = (a.total ?? 0) - (b.total ?? 0);
      else if (field === 'vendor') cmp = (a.DirectoryVendors?.name ?? '').localeCompare(b.DirectoryVendors?.name ?? '');
      else if (field === 'status') cmp = a.status.localeCompare(b.status);
      else cmp = a.created_at.localeCompare(b.created_at);
      return asc ? cmp : -cmp;
    });
    return result;
  }, [filtered, sortKey]);

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const paginated = sorted.slice((page - 1) * pageSize, page * pageSize);

  const pageTotal = paginated.reduce((s, po) => s + (po.total ?? 0), 0);

  const lineCount = (po: { PurchaseOrderLines?: { id: string }[] }) =>
    po.PurchaseOrderLines?.length ?? 0;

  return (
    <div className="py-6 px-6">
      <FinancialSubTabs />
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Purchase Orders</h1>
          <p className="text-sm text-gray-500 mt-0.5">Vendor purchase orders (AP)</p>
        </div>
        <div className="text-right">
          <p className="text-xs text-gray-500">Total (this page)</p>
          <p className="text-lg font-bold text-foreground">{formatCurrency(pageTotal)}</p>
        </div>
      </div>

      <StatusTabs
        tabs={BILLING_TABS.map(t => ({ label: t.label, value: t.value, count: billingCounts[t.value] ?? 0 }))}
        activeTab={billingFilter}
        onChange={v => { setBillingFilter(v); setPage(1); }}
      />

      <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-4">
        <div className="flex items-center gap-3">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={q}
              onChange={e => { setQ(e.target.value); setPage(1); }}
              placeholder="Search by PO number or vendor..."
              className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
          </div>
          <select
            value={sortKey}
            onChange={e => setSortKey(e.target.value)}
            className="px-3 py-1 border border-gray-200 rounded text-sm bg-white"
          >
            {SORT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>

        {error && (
          <div className="mt-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        <table className="w-full text-sm mt-4">
          <thead>
            <tr className="border-b border-gray-200">
              <th className="py-2 px-3 text-left text-xs font-medium text-gray-600">PO #</th>
              <th className="py-2 px-3 text-left text-xs font-medium text-gray-600">Vendor</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600">Date</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600">Expected</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600">Items</th>
              <th className="py-2 px-3 text-right text-xs font-medium text-gray-600">Total</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600">Status</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600">Billing</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              Array.from({ length: 3 }).map((_, i) => (
                <tr key={i} className="border-b border-gray-100"><td colSpan={8} className="py-3 px-3"><div className="h-4 bg-gray-100 rounded animate-pulse" /></td></tr>
              ))
            ) : paginated.length === 0 ? (
              <tr><td colSpan={8} className="py-8 text-center text-sm text-gray-400">No purchase orders found</td></tr>
            ) : paginated.map(po => (
              <tr
                key={po.id}
                className="border-b border-gray-100 hover:bg-gray-50 cursor-pointer"
                onClick={() => router.navigate(withReturnTo(`/inventory/purchase-orders/${po.id}`, '/financials/purchase-orders'))}
              >
                <td className="py-3 px-3 font-medium text-primary">{po.po_number ?? '—'}</td>
                <td className="py-3 px-3">{po.DirectoryVendors?.name ?? '—'}</td>
                <td className="py-3 px-3 text-center">{formatDate(po.created_at)}</td>
                <td className="py-3 px-3 text-center">{formatDate(po.expected_date)}</td>
                <td className="py-3 px-3 text-center">{lineCount(po)}</td>
                <td className="py-3 px-3 text-right font-medium">{formatCurrency(po.total ?? 0)}</td>
                <td className="py-3 px-3 text-center"><StatusBadge status={po.status.toLowerCase()} type="purchaseOrder" size="sm" /></td>
                <td className="py-3 px-3 text-center">
                  {(() => {
                    const bs = getBillingStatus(po);
                    if (bs === 'unbilled') return <span className="text-xs text-gray-400">Unbilled</span>;
                    const colors: Record<string, string> = { partial: 'bg-amber-100 text-amber-700', billed: 'bg-green-100 text-green-700' };
                    return <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${colors[bs] ?? 'bg-gray-100 text-gray-700'}`}>{bs.charAt(0).toUpperCase() + bs.slice(1)}</span>;
                  })()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex items-center justify-between mt-3 text-xs text-gray-500">
        <div className="flex items-center gap-3">
          <span>Show:</span>
          <span>{pageSize}</span>
          <span>Showing {sorted.length === 0 ? 0 : (page - 1) * pageSize + 1}–{Math.min(page * pageSize, sorted.length)} of {sorted.length}</span>
        </div>
        <div className="flex items-center gap-2">
          <button disabled={page <= 1} onClick={() => setPage(p => p - 1)} className="text-gray-500 disabled:opacity-40">Previous</button>
          <span className="font-medium">Page {page} of {totalPages}</span>
          <button disabled={page >= totalPages} onClick={() => setPage(p => p + 1)} className="text-gray-500 disabled:opacity-40">Next</button>
        </div>
      </div>
    </div>
  );
}
