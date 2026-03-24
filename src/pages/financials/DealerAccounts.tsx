import { useEffect, useState } from 'react';
import { Search } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useDealerFinancialAccounts, type DealerFinancialRisk } from '../../hooks/useDealerFinancialAccounts';
import StatusTabs from '../../components/shared/StatusTabs';
import { formatCurrency, formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import FinancialSubTabs from './FinancialSubTabs';
import { useAccessContext } from '../../hooks/useAccessContext';
import { isMyFinancialsPath } from './myFinancialsRoute';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

const RISK_TABS: Array<{ value: DealerFinancialRisk; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'healthy', label: 'Healthy' },
  { value: 'warning', label: 'Warning' },
  { value: 'critical', label: 'Critical' },
];

const SORT_OPTIONS = [
  { value: 'open_ar:desc', label: 'Open AR (High to Low)' },
  { value: 'past_due:desc', label: 'Past Due (High to Low)' },
  { value: 'dealer:asc', label: 'Dealer (A-Z)' },
  { value: 'last_payment:desc', label: 'Last Payment (Recent)' },
];

export default function DealerAccounts() {
  const { registerSubmodules } = useSubmoduleNav();
  const { isPortal } = useAccessContext();
  const pathname = window.location.pathname;
  const myFinancialsMode = isMyFinancialsPath(pathname);
  const viewerMode = isPortal || myFinancialsMode;
  const [q, setQ] = useState('');
  const [risk, setRisk] = useState<DealerFinancialRisk>('all');
  const [sortKey, setSortKey] = useState('open_ar:desc');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);

  useEffect(() => {
    if (viewerMode) {
      // Viewer (dealer-facing) context is always served from /my-financials.
      router.navigate('/my-financials/statement', false);
      return;
    }
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules, viewerMode]);

  const { rows, total, isInitialLoading, error } = useDealerFinancialAccounts({
    q,
    risk,
    sortKey,
    page,
    pageSize,
    enabled: !viewerMode,
  });

  if (viewerMode) return null;

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const tabs = RISK_TABS.map((tab) => ({ label: tab.label, value: tab.value, count: 0 }));

  return (
    <div className="py-6 px-6">
      <FinancialSubTabs />
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Accounts</h1>
          <p className="text-sm text-gray-500 mt-0.5">Dealer receivables cockpit (AR)</p>
        </div>
      </div>

      <StatusTabs tabs={tabs} activeTab={risk} onChange={(value) => { setRisk(value as DealerFinancialRisk); setPage(1); }} />

      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="relative flex-1 min-w-[240px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={q}
              onChange={(e) => { setQ(e.target.value); setPage(1); }}
              placeholder="Search dealer name or number..."
              className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
            />
            </div>
            <div className="w-[220px] shrink-0">
              <Select value={sortKey} onValueChange={setSortKey}>
                <SelectTrigger className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px]">
                  <SelectValue placeholder="Sort by" />
                </SelectTrigger>
                <SelectContent>
                  {SORT_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
      </div>

      <div className="mt-4 bg-white border border-gray-200 rounded-lg overflow-hidden">
        {isInitialLoading ? (
          <div className="p-10 text-center text-sm text-gray-500">Loading accounts...</div>
        ) : error ? (
          <div className="p-6 text-sm text-red-600">{error}</div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Dealer</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Open AR</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Past Due</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Unapplied</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Open Invoices</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Last Payment</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Aging 90+</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-gray-500">
                    No dealer accounts found
                  </td>
                </tr>
              ) : rows.map((row) => (
                <tr
                  key={row.dealer_id}
                  className="border-t hover:bg-gray-50 cursor-pointer"
                  onClick={() => router.navigate(withReturnTo(`/financials/accounts/${row.dealer_id}`))}
                >
                  <td className="px-4 py-4">
                    <div className="font-medium text-primary">{row.dealer_name}</div>
                    <div className="text-xs text-gray-500">{row.dealer_no ?? '—'}</div>
                  </td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(row.open_ar, 'USD')}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(row.past_due_amount, 'USD')}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(row.unapplied_amount, 'USD')}</td>
                  <td className="px-4 py-4 text-center">{row.open_invoices_count}</td>
                  <td className="px-4 py-4 text-right">
                    {formatDate(row.last_payment_date)}
                  </td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(row.aging_90_plus, 'USD')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {!isInitialLoading && !error && (
        <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-700">Show:</span>
              <div className="w-[90px]">
                <Select value={String(pageSize)} onValueChange={(v) => { setPageSize(Number(v)); setPage(1); }}>
                  <SelectTrigger className="px-3 py-1 border border-gray-200 rounded-lg text-sm bg-white min-h-[32px]">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="10">10</SelectItem>
                    <SelectItem value="25">25</SelectItem>
                    <SelectItem value="50">50</SelectItem>
                    <SelectItem value="100">100</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <span className="text-sm text-gray-700">Total {total}</span>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setPage((prev) => Math.max(1, prev - 1))}
                disabled={page === 1}
                className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50"
              >
                Previous
              </button>
              <span className="text-sm text-gray-700">Page {page} of {totalPages}</span>
              <button
                type="button"
                onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
                disabled={page >= totalPages}
                className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
