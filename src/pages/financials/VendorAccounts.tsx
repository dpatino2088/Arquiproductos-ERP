import { useState, useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useVendorFinancialAccounts, type VendorFinancialRisk } from '../../hooks/useVendorFinancialAccounts';
import StatusTabs from '../../components/shared/StatusTabs';
import { formatCurrency } from '../../lib/utils';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { Search } from 'lucide-react';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import FinancialSubTabs from './FinancialSubTabs';

const RISK_TABS: Array<{ value: VendorFinancialRisk; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'healthy', label: 'Healthy' },
  { value: 'warning', label: 'Warning' },
  { value: 'critical', label: 'Critical' },
];

const SORT_OPTIONS = [
  { value: 'open_ap:desc', label: 'Open AP (High to Low)' },
  { value: 'past_due:desc', label: 'Past Due (High to Low)' },
  { value: 'vendor:asc', label: 'Vendor (A-Z)' },
  { value: 'last_payment:desc', label: 'Last Payment (Recent)' },
];

export default function VendorAccounts() {
  const { registerSubmodules } = useSubmoduleNav();
  const [q, setQ] = useState('');
  const [risk, setRisk] = useState<VendorFinancialRisk>('all');
  const [sortKey, setSortKey] = useState('open_ap:desc');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const { rows, total, isInitialLoading, isFetching, error } = useVendorFinancialAccounts({
    q, risk, sortKey, page, pageSize,
  });

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const tabs = RISK_TABS.map(tab => ({ label: tab.label, value: tab.value, count: 0 }));
  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  return (
    <div className="py-6 px-6">
      <FinancialSubTabs />
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Vendor Accounts</h1>
          <p className="text-sm text-gray-500 mt-0.5">Vendor payables cockpit (AP)</p>
        </div>
      </div>

      <StatusTabs
        tabs={tabs}
        activeValue={risk}
        onChange={v => { setRisk(v as VendorFinancialRisk); setPage(1); }}
      />

      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by vendor name..."
                value={q}
                onChange={e => { setQ(e.target.value); setPage(1); }}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <select value={sortKey} onChange={e => setSortKey(e.target.value)} className="px-3 py-1 border border-gray-200 rounded text-sm bg-white">
              {SORT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
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
        {error && <div className="p-4 text-sm text-red-600 bg-red-50 border-b border-red-200">Error: {error}</div>}

        <div className="table-fit-wrapper">
          <table className="table-fit">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Vendor</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Open AP</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Past Due</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Unapplied</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Open Bills</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Open POs</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Last Payment</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Risk</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && !isInitialLoading && (
                <tr>
                  <td colSpan={8} className="py-12 px-4 text-center">
                    <p className="text-gray-600 mb-2">No vendor accounts found</p>
                    <p className="text-sm text-gray-400">Create bills to see vendor balances here</p>
                  </td>
                </tr>
              )}
              {rows.map(row => {
                const riskColors: Record<string, string> = { healthy: 'bg-green-100 text-green-700', warning: 'bg-amber-100 text-amber-700', critical: 'bg-red-100 text-red-700' };
                return (
                  <tr
                    key={row.vendor_id}
                    className="hover:bg-gray-50 cursor-pointer border-b border-gray-100"
                    onClick={() => router.navigate(withReturnTo(`/financials/vendor-accounts/${row.vendor_id}`, '/financials/vendor-accounts'))}
                  >
                    <td className="py-4 px-4 text-sm font-medium text-primary">{row.vendor_name}</td>
                    <td className="py-4 px-4 text-sm text-right font-medium">{formatCurrency(row.open_ap)}</td>
                    <td className={`py-4 px-4 text-sm text-right ${row.past_due_amount > 0 ? 'text-red-600 font-medium' : ''}`}>{formatCurrency(row.past_due_amount)}</td>
                    <td className={`py-4 px-4 text-sm text-right ${row.unapplied_amount > 0 ? 'text-blue-600' : ''}`}>{formatCurrency(row.unapplied_amount)}</td>
                    <td className="py-4 px-4 text-sm text-center">{row.open_bills_count}</td>
                    <td className="py-4 px-4 text-sm text-center">{row.open_po_count}</td>
                    <td className="py-4 px-4 text-sm text-center text-gray-500">{row.last_payment_date || '—'}</td>
                    <td className="py-4 px-4 text-center">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${riskColors[row.risk_band] ?? 'bg-gray-100 text-gray-700'}`}>
                        {row.risk_band.charAt(0).toUpperCase() + row.risk_band.slice(1)}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-700">Show:</span>
            <select value={pageSize} onChange={e => { setPageSize(Number(e.target.value)); setPage(1); }} className="px-3 py-1 border border-gray-200 rounded-lg text-sm">
              {[10, 25, 50, 100].map(n => <option key={n} value={n}>{n}</option>)}
            </select>
            <span className="text-sm text-gray-700">Showing {total > 0 ? start : 0}–{end} of {total}</span>
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
