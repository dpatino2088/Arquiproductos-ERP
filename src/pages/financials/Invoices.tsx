import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useAccessContext } from '../../hooks/useAccessContext';
import StatusTabs from '../../components/shared/StatusTabs';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { Search, FileText, DollarSign, Plus, Building2 } from 'lucide-react';

const FINANCIAL_SUBMODULES = [
  { id: 'accounts', label: 'Accounts', href: '/financials/accounts', icon: Building2 },
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments', href: '/financials/payments', icon: DollarSign },
];

const STATUS_VALUES = ['all', 'draft', 'issued', 'partial', 'paid', 'void'] as const;
const STATUS_LABELS: Record<string, string> = {
  all: 'All', draft: 'Draft', issued: 'Issued', partial: 'Partial', paid: 'Paid', void: 'Void',
};

interface DealerInvoice {
  id: string;
  invoice_number: string;
  status: string;
  issue_date: string;
  due_date: string | null;
  currency_code: string;
  subtotal: number;
  tax_total: number;
  total: number;
  sales_order_id: string | null;
  created_at: string;
  Dealers?: { dealer_name: string; dealer_no?: string | null } | null;
  SalesOrders?: { sales_order_no: string } | null;
}

function getInvoiceIdFromPath(): string | null {
  const match = window.location.pathname.match(/\/financials\/invoices\/([^/]+)/);
  return match ? match[1] : null;
}

export default function Invoices() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { isInternal } = useAccessContext();

  const [invoices, setInvoices] = useState<DealerInvoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_SUBMODULES);
  }, [registerSubmodules]);

  const fetchInvoices = useCallback(async () => {
    if (!activeOrganizationId) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase
        .from('DealerInvoices')
        .select('id, invoice_number, status, issue_date, due_date, currency_code, subtotal, tax_total, total, sales_order_id, dealer_id, created_at')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });
      if (err) throw err;

      const rows = (data ?? []) as (DealerInvoice & { dealer_id: string })[];
      if (rows.length > 0) {
        const dealerIds = [...new Set(rows.map((r) => r.dealer_id).filter(Boolean))];
        const soIds = [...new Set(rows.map((r) => r.sales_order_id).filter(Boolean))] as string[];

        const [dealersRes, soRes] = await Promise.all([
          dealerIds.length > 0
            ? supabase.from('Dealers').select('id, dealer_name, dealer_no').in('id', dealerIds)
            : { data: [] },
          soIds.length > 0
            ? supabase.from('SalesOrders').select('id, sales_order_no').in('id', soIds)
            : { data: [] },
        ]);
        type DealerRow = { id: string; dealer_name: string; dealer_no: string | null };
        type SORow = { id: string; sales_order_no: string };
        const dealerMap = new Map<string, DealerRow>((dealersRes.data ?? []).map((d: DealerRow) => [d.id, d]));
        const soMap = new Map<string, SORow>((soRes.data ?? []).map((s: SORow) => [s.id, s]));

        setInvoices(rows.map((r) => ({
          ...r,
          Dealers: dealerMap.get(r.dealer_id) ?? null,
          SalesOrders: r.sales_order_id ? soMap.get(r.sales_order_id) ?? null : null,
        })) as DealerInvoice[]);
      } else {
        setInvoices([]);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load invoices');
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => { void fetchInvoices(); }, [fetchInvoices]);

  const tabs = STATUS_VALUES.map((s) => ({
    value: s,
    label: STATUS_LABELS[s],
    count: s === 'all' ? invoices.length : invoices.filter((i) => i.status === s).length,
  }));

  const filtered = useMemo(() => {
    let list = activeTab === 'all' ? invoices : invoices.filter((i) => i.status === activeTab);
    if (searchTerm.trim()) {
      const s = searchTerm.toLowerCase();
      list = list.filter((i) =>
        i.invoice_number.toLowerCase().includes(s) ||
        i.Dealers?.dealer_name?.toLowerCase().includes(s) ||
        i.SalesOrders?.sales_order_no?.toLowerCase().includes(s)
      );
    }
    return list;
  }, [invoices, activeTab, searchTerm]);

  const fmt = (v: number, currency = 'USD') =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Invoices</h1>
          <p className="text-sm text-gray-500 mt-0.5">Dealer invoices (AR)</p>
        </div>
        {isInternal && (
          <button
            type="button"
            onClick={() => router.navigate('/financials/invoices/new')}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
          >
            <Plus className="w-4 h-4" />
            New Invoice
          </button>
        )}
      </div>

      <StatusTabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />

      <div className="mb-4 mt-4 bg-white border border-gray-200 rounded-lg py-4 px-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search by invoice #, dealer or SO..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20"
          />
        </div>
      </div>

      {loading ? (
        <div className="bg-white border rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
          <p className="text-sm text-gray-600">Loading invoices...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">{error}</p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Invoice #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Dealer</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">SO #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Issue Date</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Due Date</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-gray-500">
                    <FileText className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                    No invoices found
                  </td>
                </tr>
              ) : (
                filtered.map((inv) => (
                  <tr
                    key={inv.id}
                    className="border-t hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(withReturnTo(`/financials/invoices/${inv.id}`))}
                  >
                    <td className="px-4 py-4 font-medium text-primary">{inv.invoice_number}</td>
                    <td className="px-4 py-4 text-gray-700">{inv.Dealers?.dealer_name ?? '—'}</td>
                    <td className="px-4 py-4 text-gray-500">
                      {inv.SalesOrders?.sales_order_no
                        ? <button type="button" onClick={(e) => { e.stopPropagation(); router.navigate(withReturnTo(`/sales/orders/${inv.sales_order_id}`)); }}
                            className="text-primary hover:underline">{inv.SalesOrders.sales_order_no}</button>
                        : '—'}
                    </td>
                    <td className="px-4 py-4 text-gray-700">{new Date(inv.issue_date).toLocaleDateString()}</td>
                    <td className="px-4 py-4 text-gray-700">{inv.due_date ? new Date(inv.due_date).toLocaleDateString() : '—'}</td>
                    <td className="px-4 py-4 text-right font-mono text-gray-900">{fmt(inv.total, inv.currency_code)}</td>
                    <td className="px-4 py-4 text-center">
                      <StatusBadge status={inv.status} type="invoice" size="sm" />
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
