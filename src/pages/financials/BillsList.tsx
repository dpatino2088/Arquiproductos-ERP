import { useState, useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useVendorBillsList } from '../../hooks/useVendorBills';
import StatusTabs from '../../components/shared/StatusTabs';
import StatusBadge from '../../components/shared/StatusBadge';
import { formatCurrency, formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { Search, Plus } from 'lucide-react';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import FinancialSubTabs from './FinancialSubTabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

const STATUS_VALUES = ['all', 'draft', 'open', 'partial', 'paid', 'void'] as const;
const STATUS_LABELS: Record<string, string> = {
  all: 'All', draft: 'Draft', open: 'Open', partial: 'Partial', paid: 'Paid', void: 'Void',
};

const SORT_OPTIONS = [
  { value: 'bill_date:desc', label: 'Bill Date (Recent)' },
  { value: 'due_date:asc', label: 'Due Date (Soonest)' },
  { value: 'total:desc', label: 'Total (High to Low)' },
  { value: 'vendor:asc', label: 'Vendor (A-Z)' },
];

export default function BillsList() {
  const { registerSubmodules } = useSubmoduleNav();
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [sortKey, setSortKey] = useState('bill_date:desc');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const { rows, total, isInitialLoading, isFetching, error } = useVendorBillsList({
    q, status, sortKey, page, pageSize,
  });

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const tabs = STATUS_VALUES.map(v => ({ label: STATUS_LABELS[v], value: v, count: 0 }));
  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  return (
    <div className="py-6 px-6">
      <FinancialSubTabs />
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Bills</h1>
          <p className="text-sm text-gray-500 mt-0.5">Vendor bills & payables (AP)</p>
        </div>
        <button
          onClick={() => router.navigate(withReturnTo('/financials/bills/new', '/financials/bills'))}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors flex items-center gap-2"
        >
          <Plus className="h-4 w-4" />
          New Bill
        </button>
      </div>

      <StatusTabs
        tabs={tabs}
        activeTab={status}
        onChange={v => { setStatus(v); setPage(1); }}
      />

      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="relative flex-1 min-w-[240px]">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by bill number, vendor or reference..."
                value={q}
                onChange={e => { setQ(e.target.value); setPage(1); }}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <div className="w-[220px] shrink-0">
              <Select value={sortKey} onValueChange={setSortKey}>
                <SelectTrigger className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px]">
                  <SelectValue placeholder="Sort by" />
                </SelectTrigger>
                <SelectContent>
                  {SORT_OPTIONS.map((o) => (
                    <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
      </div>

      <div className="relative bg-white border border-gray-200 rounded-lg overflow-hidden mb-4 min-h-[300px]">
        {isInitialLoading && (
          <div className="absolute inset-0 bg-white/90 z-10 flex items-center justify-center">
            <div className="flex flex-col items-center gap-2">
              <div className="h-8 w-8 animate-spin rounded-full border-b-2 border-primary" />
              <span className="text-sm text-gray-600 font-medium">Loading...</span>
            </div>
          </div>
        )}
        {!isInitialLoading && isFetching && rows.length > 0 && (
          <div className="absolute inset-0 bg-white/60 z-10 flex items-center justify-center">
            <span className="text-sm text-gray-500">Updating...</span>
          </div>
        )}

        {error && (
          <div className="p-4 text-sm text-red-600 bg-red-50 border-b border-red-200">Error: {error}</div>
        )}

        <div className="table-fit-wrapper">
          <table className="table-fit">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Bill #</th>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Vendor</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Vendor Ref</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Bill Date</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Due Date</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Total</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && !isInitialLoading && (
                <tr>
                  <td colSpan={7} className="py-12 px-4 text-center">
                    <p className="text-gray-600 mb-2">No bills found</p>
                    <p className="text-sm text-gray-400">Try adjusting your search or filters</p>
                  </td>
                </tr>
              )}
              {rows.map(bill => (
                <tr
                  key={bill.id}
                  className={`hover:bg-gray-50 cursor-pointer border-b border-gray-100 ${bill.status === 'void' ? 'opacity-60' : ''}`}
                  onClick={() => router.navigate(withReturnTo(`/financials/bills/${bill.id}`, '/financials/bills'))}
                >
                  <td className="py-4 px-4 text-sm font-medium text-primary">{bill.bill_number}</td>
                  <td className="py-4 px-4 text-sm">{bill.vendor_name}</td>
                  <td className="py-4 px-4 text-sm text-center text-gray-500">{bill.vendor_bill_ref || '—'}</td>
                  <td className="py-4 px-4 text-sm text-center">{formatDate(bill.bill_date)}</td>
                  <td className="py-4 px-4 text-sm text-center">{formatDate(bill.due_date)}</td>
                  <td className="py-4 px-4 text-sm text-right font-medium">{formatCurrency(bill.total)}</td>
                  <td className="py-4 px-4 text-center">
                    <div className="flex justify-center">
                      <StatusBadge status={bill.status} type="bill" size="sm" />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-700">Show:</span>
            <div className="w-[90px]">
              <Select value={String(pageSize)} onValueChange={(v) => { setPageSize(Number(v)); setPage(1); }}>
                <SelectTrigger className="px-3 py-1 border border-gray-200 rounded-lg text-sm bg-white min-h-[32px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {[10, 25, 50, 100].map((n) => <SelectItem key={n} value={String(n)}>{n}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <span className="text-sm text-gray-700">
              Showing {total > 0 ? start : 0}–{end} of {total}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page <= 1} className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50">Previous</button>
            <span className="text-sm text-gray-700">Page {page} of {totalPages}</span>
            <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages} className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50">Next</button>
          </div>
        </div>
      </div>
    </div>
  );
}
