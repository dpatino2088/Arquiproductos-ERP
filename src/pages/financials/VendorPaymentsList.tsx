import { useState, useEffect, useCallback, useMemo } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';
import { useVendorPaymentsList, useVendorPaymentMutations } from '../../hooks/useVendorPayments';
import StatusTabs from '../../components/shared/StatusTabs';
import StatusBadge from '../../components/shared/StatusBadge';
import { formatCurrency, formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { Search, Plus } from 'lucide-react';
import { supabase, initSessionContext } from '../../lib/supabase/client';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import FinancialSubTabs from './FinancialSubTabs';

const STATUS_VALUES = ['all', 'active', 'void'] as const;
const STATUS_LABELS: Record<string, string> = { all: 'All', active: 'Active', void: 'Void' };

const SORT_OPTIONS = [
  { value: 'payment_date:desc', label: 'Date (Recent)' },
  { value: 'payment_date:asc', label: 'Date (Oldest)' },
  { value: 'amount:desc', label: 'Amount (High to Low)' },
  { value: 'amount:asc', label: 'Amount (Low to High)' },
  { value: 'vendor:asc', label: 'Vendor (A-Z)' },
];

const PAYMENT_METHODS = [
  { value: 'check', label: 'Check' },
  { value: 'wire_transfer', label: 'Wire Transfer' },
  { value: 'ach', label: 'ACH' },
  { value: 'credit_card', label: 'Credit Card' },
  { value: 'cash', label: 'Cash' },
  { value: 'other', label: 'Other' },
];

interface VendorOption { id: string; name: string; }

interface UnpaidBillRow {
  bill_id: string;
  bill_number: string;
  bill_date: string;
  due_date: string | null;
  bill_total: number;
  balance_due: number;
  selected: boolean;
  payAmount: string;
  payPct: string;
}

interface UnbilledPORow {
  id: string;
  po_number: string;
  total: number;
  status: string;
  received: string;
}

export default function VendorPaymentsList() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const addNotification = useUIStore(s => s.addNotification);

  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [sortKey, setSortKey] = useState('payment_date:desc');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);

  const [formOpen, setFormOpen] = useState(false);
  const [vendors, setVendors] = useState<VendorOption[]>([]);
  const [formVendorId, setFormVendorId] = useState('');
  const [formMethod, setFormMethod] = useState('check');
  const [formReference, setFormReference] = useState('');
  const [formDate, setFormDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [formBankName, setFormBankName] = useState('');
  const [formNotes, setFormNotes] = useState('');
  const [unpaidBills, setUnpaidBills] = useState<UnpaidBillRow[]>([]);
  const [unbilledPOs, setUnbilledPOs] = useState<UnbilledPORow[]>([]);
  const [loadingBills, setLoadingBills] = useState(false);
  const [excessAmount, setExcessAmount] = useState('');

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const { rows, total, isInitialLoading, isFetching, error, refetch } = useVendorPaymentsList({
    q, status, sortKey, page, pageSize,
  });
  const { recordPayment, applyToBill, isSaving } = useVendorPaymentMutations();

  useEffect(() => {
    if (!activeOrganizationId) return;
    (async () => {
      await initSessionContext();
      const { data } = await supabase
        .from('DirectoryVendors')
        .select('id, name')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('name', { ascending: true });
      if (data) setVendors(data as VendorOption[]);
    })();
  }, [activeOrganizationId]);

  const fetchUnpaidBills = useCallback(async (vendorId: string) => {
    if (!activeOrganizationId || !vendorId) {
      setUnpaidBills([]);
      setUnbilledPOs([]);
      return;
    }
    setLoadingBills(true);
    try {
      await initSessionContext();
      const [billsRes, posRes] = await Promise.all([
        supabase
          .from('vendor_bill_balances_v1')
          .select('bill_id, bill_number, bill_date, due_date, bill_total, balance_due')
          .eq('organization_id', activeOrganizationId)
          .eq('vendor_id', vendorId)
          .gt('balance_due', 0.005)
          .order('due_date', { ascending: true, nullsFirst: false }),
        supabase
          .from('PurchaseOrders')
          .select('id, po_number, total, status, billing_status, VendorBills!purchase_order_id(id, deleted, status)')
          .eq('vendor_id', vendorId)
          .not('status', 'in', '(void,CANCELLED)')
          .order('created_at', { ascending: false }),
      ]);

      const allPOs = (posRes.data ?? []) as Array<{
        id: string; po_number: string; total: number | string;
        status: string; billing_status: string | null; VendorBills: { id: string; deleted: boolean; status: string }[] | null;
      }>;
      const unbilled = allPOs
        .filter(po => {
          const activeBills = (po.VendorBills ?? []).filter(b => !b.deleted && b.status !== 'void');
          return activeBills.length === 0;
        })
        .map(po => ({
          id: po.id,
          po_number: po.po_number,
          total: Number(po.total) || 0,
          status: po.status,
          received: po.billing_status ?? 'not_billed',
        }));
      setUnbilledPOs(unbilled);

      const data = billsRes.data;
      setUnpaidBills(((data ?? []) as Array<{
        bill_id: string; bill_number: string; bill_date: string;
        due_date: string | null; bill_total: number; balance_due: number;
      }>).map(b => ({
        bill_id: b.bill_id,
        bill_number: b.bill_number,
        bill_date: b.bill_date,
        due_date: b.due_date,
        bill_total: Number(b.bill_total) || 0,
        balance_due: Number(b.balance_due) || 0,
        selected: false,
        payAmount: '',
        payPct: '',
      })));
    } finally {
      setLoadingBills(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => {
    if (formVendorId) {
      fetchUnpaidBills(formVendorId);
    } else {
      setUnpaidBills([]);
      setUnbilledPOs([]);
    }
    setExcessAmount('');
  }, [formVendorId, fetchUnpaidBills]);

  const toggleBillSelection = (billId: string) => {
    setUnpaidBills(prev => prev.map(b => {
      if (b.bill_id !== billId) return b;
      const nowSelected = !b.selected;
      return {
        ...b,
        selected: nowSelected,
        payAmount: nowSelected ? b.balance_due.toFixed(2) : '',
        payPct: nowSelected ? '100' : '',
      };
    }));
  };

  const toggleSelectAll = () => {
    const allSelected = unpaidBills.every(b => b.selected);
    setUnpaidBills(prev => prev.map(b => ({
      ...b,
      selected: !allSelected,
      payAmount: !allSelected ? b.balance_due.toFixed(2) : '',
      payPct: !allSelected ? '100' : '',
    })));
  };

  const updateBillPayAmount = (billId: string, value: string) => {
    setUnpaidBills(prev => prev.map(b => {
      if (b.bill_id !== billId) return b;
      const amt = parseFloat(value);
      const pct = b.balance_due > 0 && !isNaN(amt) ? ((amt / b.balance_due) * 100) : 0;
      return { ...b, payAmount: value, payPct: !isNaN(amt) && amt > 0 ? pct.toFixed(2) : '', selected: true };
    }));
  };

  const updateBillPayPct = (billId: string, value: string) => {
    setUnpaidBills(prev => prev.map(b => {
      if (b.bill_id !== billId) return b;
      const pct = parseFloat(value);
      const clampedPct = Math.min(100, Math.max(0, isNaN(pct) ? 0 : pct));
      const amt = b.balance_due > 0 && !isNaN(pct) ? (b.balance_due * clampedPct / 100) : 0;
      return { ...b, payPct: value, payAmount: !isNaN(pct) && pct > 0 ? amt.toFixed(2) : '', selected: true };
    }));
  };

  const billsPayTotal = useMemo(() =>
    unpaidBills.reduce((sum, b) => sum + (b.selected ? (parseFloat(b.payAmount) || 0) : 0), 0),
    [unpaidBills]
  );

  const totalPaymentAmount = useMemo(() =>
    billsPayTotal + (parseFloat(excessAmount) || 0),
    [billsPayTotal, excessAmount]
  );

  const statusCounts = useMemo(() => {
    const active = rows.filter(p => p.status !== 'void').length;
    const voided = rows.filter(p => p.status === 'void').length;
    return { all: rows.length, active, void: voided };
  }, [rows]);

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const tabs = STATUS_VALUES.map(v => ({ label: STATUS_LABELS[v], value: v, count: statusCounts[v] ?? 0 }));
  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  const activeTotal = rows.filter(p => p.status !== 'void').reduce((s, p) => s + p.amount, 0);

  const resetForm = useCallback(() => {
    setFormVendorId('');
    setFormMethod('check');
    setFormReference('');
    setFormDate(new Date().toISOString().slice(0, 10));
    setFormBankName('');
    setFormNotes('');
    setUnpaidBills([]);
    setUnbilledPOs([]);
    setExcessAmount('');
  }, []);

  const handleRecordPayment = async () => {
    if (!activeOrganizationId || !formVendorId) {
      addNotification({ type: 'error', title: 'Validation', message: 'Select a vendor.' });
      return;
    }
    if (totalPaymentAmount <= 0) {
      addNotification({ type: 'error', title: 'Validation', message: 'Payment amount must be greater than 0. Select bills or enter an advance amount.' });
      return;
    }

    const selectedBills = unpaidBills
      .filter(b => b.selected && parseFloat(b.payAmount) > 0)
      .map(b => ({ billId: b.bill_id, amount: parseFloat(b.payAmount) }));

    for (const sb of selectedBills) {
      const bill = unpaidBills.find(b => b.bill_id === sb.billId);
      if (bill && sb.amount > bill.balance_due + 0.005) {
        addNotification({ type: 'error', title: 'Validation', message: `Pay amount for ${bill.bill_number} exceeds balance due (${formatCurrency(bill.balance_due)}).` });
        return;
      }
    }

    try {
      const paymentId = await recordPayment({
        vendor_id: formVendorId,
        amount: +totalPaymentAmount.toFixed(2),
        payment_method: formMethod,
        reference_number: formReference || undefined,
        bank_name: formBankName || undefined,
        payment_date: formDate,
        notes: formNotes || null,
        userId: user?.id ?? null,
        userName: user?.name ?? user?.email ?? null,
      });

      for (const sb of selectedBills) {
        await applyToBill(paymentId, sb.billId, +sb.amount.toFixed(2));
      }

      setFormOpen(false);
      resetForm();
      await refetch();
      router.navigate(withReturnTo(`/financials/vendor-payments/${paymentId}`, '/financials/vendor-payments'));
    } catch {
      // notifications handled by hooks
    }
  };

  const selectedVendorName = vendors.find(v => v.id === formVendorId)?.name;

  return (
    <div className="py-6 px-6">
      <FinancialSubTabs />
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Payments Made</h1>
          <p className="text-sm text-gray-500 mt-0.5">Vendor payments (AP)</p>
        </div>
        <div className="flex items-center gap-4">
          {activeTotal > 0 && (
            <div className="text-right">
              <p className="text-xs text-gray-500">Total (this page)</p>
              <p className="text-lg font-semibold">{formatCurrency(activeTotal)}</p>
            </div>
          )}
          <button
            onClick={() => setFormOpen(true)}
            className="flex items-center gap-1.5 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Plus className="h-4 w-4" />
            Record Payment
          </button>
        </div>
      </div>

      <StatusTabs
        tabs={tabs}
        activeValue={status}
        onChange={v => { setStatus(v); setPage(1); }}
      />

      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by vendor or reference..."
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
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Date</th>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Vendor</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Amount</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Method</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Reference</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && !isInitialLoading && (
                <tr>
                  <td colSpan={6} className="py-12 px-4 text-center">
                    <p className="text-gray-600 mb-2">No vendor payments found</p>
                    <p className="text-sm text-gray-400 mb-4">Record payments to vendors here or from bill detail pages</p>
                    <button
                      onClick={() => setFormOpen(true)}
                      className="inline-flex items-center gap-1.5 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary/90"
                    >
                      <Plus className="h-4 w-4" />
                      Record Payment
                    </button>
                  </td>
                </tr>
              )}
              {rows.map(pmt => (
                <tr
                  key={pmt.id}
                  className={`hover:bg-gray-50 cursor-pointer border-b border-gray-100 ${pmt.status === 'void' ? 'opacity-60' : ''}`}
                  onClick={() => router.navigate(withReturnTo(`/financials/vendor-payments/${pmt.id}`, '/financials/vendor-payments'))}
                >
                  <td className="py-4 px-4 text-sm">{formatDate(pmt.payment_date)}</td>
                  <td className="py-4 px-4 text-sm font-medium">{pmt.vendor_name}</td>
                  <td className={`py-4 px-4 text-sm text-right font-medium ${pmt.status === 'void' ? 'line-through' : ''}`}>{formatCurrency(pmt.amount)}</td>
                  <td className="py-4 px-4 text-sm text-center capitalize">{pmt.payment_method?.replace('_', ' ') || '—'}</td>
                  <td className="py-4 px-4 text-sm text-center text-gray-500">{pmt.reference_number || '—'}</td>
                  <td className="py-4 px-4 text-center">
                    <div className="flex justify-center">
                      <StatusBadge status={pmt.status} type="vendorPayment" size="sm" />
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

      {/* Record Payment Dialog */}
      {formOpen && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-[44rem] max-w-[95vw] max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-semibold mb-4">Record Vendor Payment</h3>

            {/* Vendor + Payment Details */}
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Vendor *</label>
                  <select
                    value={formVendorId}
                    onChange={e => setFormVendorId(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  >
                    <option value="">Select vendor...</option>
                    {vendors.map(v => <option key={v.id} value={v.id}>{v.name}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Date *</label>
                  <input
                    type="date"
                    value={formDate}
                    onChange={e => setFormDate(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Payment Method</label>
                  <select
                    value={formMethod}
                    onChange={e => setFormMethod(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  >
                    {PAYMENT_METHODS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Reference #</label>
                  <input
                    type="text"
                    value={formReference}
                    onChange={e => setFormReference(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                    placeholder="Check #, wire ref, etc."
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Bank Name</label>
                  <input
                    type="text"
                    value={formBankName}
                    onChange={e => setFormBankName(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                    placeholder="Optional"
                  />
                </div>
              </div>
            </div>

            {/* Unpaid Bills Section */}
            {formVendorId && (
              <div className="mt-5">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-semibold text-gray-700">
                    Unpaid Bills — {selectedVendorName}
                  </h4>
                  {unpaidBills.length > 0 && (
                    <button
                      onClick={toggleSelectAll}
                      className="text-xs text-primary hover:text-primary/80 font-medium"
                    >
                      {unpaidBills.every(b => b.selected) ? 'Deselect All' : 'Select All'}
                    </button>
                  )}
                </div>

                {loadingBills ? (
                  <div className="py-6 text-center text-sm text-gray-400">Loading bills...</div>
                ) : unpaidBills.length === 0 ? (
                  <div className="py-4 text-center text-sm text-gray-400 border border-gray-100 rounded bg-gray-50">
                    No unpaid bills for this vendor
                    {unbilledPOs.length > 0 && (
                      <div className="mt-1 text-xs text-amber-600">
                        {unbilledPOs.length} PO{unbilledPOs.length !== 1 ? 's' : ''} pending bill creation ({unbilledPOs.map(p => p.po_number).join(', ')})
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="border border-gray-200 rounded overflow-hidden">
                    <table className="w-full text-sm">
                      <thead className="bg-gray-50 border-b border-gray-200">
                        <tr>
                          <th className="py-2 px-3 text-center w-10"></th>
                          <th className="py-2 px-3 text-left text-xs font-medium text-gray-600">Bill #</th>
                          <th className="py-2 px-3 text-center text-xs font-medium text-gray-600">Due Date</th>
                          <th className="py-2 px-3 text-right text-xs font-medium text-gray-600">Balance Due</th>
                          <th className="py-2 px-3 text-right text-xs font-medium text-gray-600 w-24">%</th>
                          <th className="py-2 px-3 text-right text-xs font-medium text-gray-600 w-32">Pay Amount</th>
                        </tr>
                      </thead>
                      <tbody>
                        {unpaidBills.map(bill => (
                          <tr
                            key={bill.bill_id}
                            className={`border-b border-gray-100 hover:bg-gray-50 cursor-pointer ${bill.selected ? 'bg-blue-50/50' : ''}`}
                            onClick={() => toggleBillSelection(bill.bill_id)}
                          >
                            <td className="py-2 px-3 text-center">
                              <input
                                type="checkbox"
                                checked={bill.selected}
                                readOnly
                                className="rounded border-gray-300 text-primary focus:ring-primary/20 cursor-pointer"
                              />
                            </td>
                            <td className="py-2 px-3 font-medium text-gray-700">{bill.bill_number}</td>
                            <td className="py-2 px-3 text-center text-gray-500">{formatDate(bill.due_date)}</td>
                            <td className="py-2 px-3 text-right font-medium">{formatCurrency(bill.balance_due)}</td>
                            <td className="py-2 px-3 text-right" onClick={e => e.stopPropagation()}>
                              <div className="relative">
                                <input
                                  type="number"
                                  value={bill.payPct}
                                  onChange={e => updateBillPayPct(bill.bill_id, e.target.value)}
                                  min={0}
                                  max={100}
                                  step="1"
                                  className="w-full px-2 py-1 pr-6 border border-gray-200 rounded text-sm text-right disabled:bg-gray-50 disabled:text-gray-400"
                                  disabled={!bill.selected}
                                  placeholder="0"
                                />
                                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400 pointer-events-none">%</span>
                              </div>
                            </td>
                            <td className="py-2 px-3 text-right" onClick={e => e.stopPropagation()}>
                              <input
                                type="number"
                                value={bill.payAmount}
                                onChange={e => updateBillPayAmount(bill.bill_id, e.target.value)}
                                min={0}
                                max={bill.balance_due}
                                step="0.01"
                                className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-right disabled:bg-gray-50 disabled:text-gray-400"
                                disabled={!bill.selected}
                                placeholder="0.00"
                              />
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}

                {/* Unbilled POs warning */}
                {!loadingBills && unbilledPOs.length > 0 && (
                  <div className="mt-4 border border-amber-200 rounded bg-amber-50 p-3">
                    <h5 className="text-xs font-semibold text-amber-700 mb-2 flex items-center gap-1">
                      <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                      Purchase Orders without Bill ({unbilledPOs.length})
                    </h5>
                    <p className="text-xs text-amber-600 mb-2">
                      These POs need a Vendor Bill before payment can be applied.
                    </p>
                    <div className="space-y-1">
                      {unbilledPOs.map(po => (
                        <div key={po.id} className="flex items-center justify-between text-xs">
                          <span className="font-medium text-amber-800">{po.po_number}</span>
                          <div className="flex items-center gap-3">
                            <span className="text-amber-600">{formatCurrency(po.total)}</span>
                            <span className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${
                              po.status === 'CLOSED' ? 'bg-green-100 text-green-700'
                              : po.status === 'SENT' ? 'bg-blue-100 text-blue-700'
                              : 'bg-gray-100 text-gray-600'
                            }`}>{po.status}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Advance / Excess Amount */}
                <div className="mt-3 flex items-center gap-3">
                  <label className="text-sm text-gray-600 whitespace-nowrap">Advance (unapplied) amount:</label>
                  <input
                    type="number"
                    value={excessAmount}
                    onChange={e => setExcessAmount(e.target.value)}
                    min={0}
                    step="0.01"
                    className="w-32 px-2 py-1 border border-gray-200 rounded text-sm text-right"
                    placeholder="0.00"
                  />
                  <span className="text-xs text-gray-400">Optional — funds not applied to any bill</span>
                </div>
              </div>
            )}

            {/* Notes */}
            <div className="mt-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
              <textarea
                value={formNotes}
                onChange={e => setFormNotes(e.target.value)}
                rows={2}
                className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                placeholder="Internal notes (optional)"
              />
            </div>

            {/* Summary + Actions */}
            <div className="mt-5 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between">
                <div className="text-sm space-y-1">
                  {billsPayTotal > 0 && (
                    <div className="flex items-center gap-2">
                      <span className="text-gray-500">Bills:</span>
                      <span className="font-medium">{formatCurrency(billsPayTotal)}</span>
                      <span className="text-xs text-gray-400">
                        ({unpaidBills.filter(b => b.selected).length} bill{unpaidBills.filter(b => b.selected).length !== 1 ? 's' : ''})
                      </span>
                    </div>
                  )}
                  {parseFloat(excessAmount) > 0 && (
                    <div className="flex items-center gap-2">
                      <span className="text-gray-500">Advance:</span>
                      <span className="font-medium">{formatCurrency(parseFloat(excessAmount))}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-2 text-base">
                    <span className="font-semibold text-gray-700">Total Payment:</span>
                    <span className="font-bold text-lg">{formatCurrency(totalPaymentAmount)}</span>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button onClick={() => { setFormOpen(false); resetForm(); }} className="px-4 py-2 border border-gray-200 rounded-lg text-sm">Cancel</button>
                  <button
                    onClick={handleRecordPayment}
                    disabled={isSaving || !formVendorId || totalPaymentAmount <= 0}
                    className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium disabled:opacity-50 hover:bg-primary/90"
                  >
                    {isSaving ? 'Processing...' : 'Record Payment'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
