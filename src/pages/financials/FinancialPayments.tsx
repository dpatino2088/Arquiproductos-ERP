import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import StatusTabs from '../../components/shared/StatusTabs';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';
import { Search, FileText, DollarSign, Plus } from 'lucide-react';

const FINANCIAL_SUBMODULES = [
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments', href: '/financials/payments', icon: DollarSign },
];

const STATUS_VALUES = ['all', 'unassigned', 'unapplied', 'partial', 'applied'] as const;
const STATUS_LABELS: Record<string, string> = {
  all: 'All', unassigned: 'Unassigned', unapplied: 'Unapplied', partial: 'Partial', applied: 'Applied',
};

interface Payment {
  id: string;
  amount: number;
  payment_method: string;
  reference_number: string | null;
  payment_date: string;
  notes: string | null;
  recorded_by_name: string | null;
  created_at: string;
  dealer_id: string;
  status: string;
  Dealers?: { dealer_name: string; dealer_no?: string | null } | null;
}

export default function FinancialPayments() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();

  const { user } = useAuth();
  const addNotification = useUIStore((s) => s.addNotification);

  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('all');

  const [formOpen, setFormOpen] = useState(false);
  const [dealers, setDealers] = useState<{ id: string; dealer_name: string; dealer_no: string | null }[]>([]);
  const [formDealerId, setFormDealerId] = useState('');
  const [formAmount, setFormAmount] = useState('');
  const [formMethod, setFormMethod] = useState('check');
  const [formReference, setFormReference] = useState('');
  const [formDate, setFormDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [saving, setSaving] = useState(false);

  useEffect(() => { registerSubmodules('Financials', FINANCIAL_SUBMODULES); }, [registerSubmodules]);

  const fetchPayments = useCallback(async () => {
    if (!activeOrganizationId) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase
        .from('Payments')
        .select('id, amount, payment_method, reference_number, payment_date, notes, recorded_by_name, dealer_id, created_at')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('payment_date', { ascending: false });
      if (err) throw err;

      const rows = (data ?? []) as (Payment & { dealer_id: string })[];

      // Fetch dealer names
      let dealerMap = new Map<string, { dealer_name: string; dealer_no?: string | null }>();
      if (rows.length > 0) {
        const dealerIds = [...new Set(rows.map((r) => r.dealer_id).filter(Boolean))];
        if (dealerIds.length > 0) {
          const { data: dealers } = await supabase.from('Dealers').select('id, dealer_name, dealer_no').in('id', dealerIds);
          dealerMap = new Map((dealers ?? []).map((d: any) => [d.id, d]));
        }
      }

      // Fetch payment applications to derive status
      let appMap = new Map<string, number>();
      if (rows.length > 0) {
        const payIds = rows.map((r) => r.id);
        const { data: apps } = await supabase
          .from('PaymentApplications')
          .select('payment_id, applied_amount')
          .in('payment_id', payIds);
        if (apps) {
          for (const a of apps as { payment_id: string; applied_amount: number }[]) {
            appMap.set(a.payment_id, (appMap.get(a.payment_id) ?? 0) + Number(a.applied_amount));
          }
        }
      }

      setPayments(rows.map((r) => {
        const applied = appMap.get(r.id) ?? 0;
        let status = 'unapplied';
        if (!r.dealer_id) status = 'unassigned';
        else if (applied >= r.amount) status = 'applied';
        else if (applied > 0) status = 'partial';
        return { ...r, status, Dealers: r.dealer_id ? dealerMap.get(r.dealer_id) ?? null : null };
      }));
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load payments');
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => { void fetchPayments(); }, [fetchPayments]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    supabase.from('Dealers').select('id, dealer_name, dealer_no')
      .eq('organization_id', activeOrganizationId).eq('deleted', false).eq('status', 'active')
      .order('dealer_name', { ascending: true })
      .then(({ data }) => { if (data) setDealers(data); });
  }, [activeOrganizationId]);

  const handleRecordPayment = async () => {
    if (!activeOrganizationId || !formAmount) return;
    const amount = parseFloat(formAmount);
    if (isNaN(amount) || amount <= 0) {
      addNotification({ type: 'error', title: 'Validation', message: 'Amount must be greater than 0.' });
      return;
    }
    setSaving(true);
    try {
      const { error: err } = await supabase.from('Payments').insert({
        organization_id: activeOrganizationId,
        dealer_id: formDealerId || null,
        amount,
        payment_method: formMethod,
        reference_number: formReference.trim() || null,
        payment_date: formDate,
        recorded_by: user?.id ?? null,
        recorded_by_name: user?.name ?? user?.email ?? null,
        deleted: false,
      });
      if (err) throw err;
      addNotification({ type: 'success', title: 'Payment Recorded', message: `Payment of ${fmt(amount)} recorded successfully.` });
      setFormOpen(false);
      setFormDealerId(''); setFormAmount(''); setFormMethod('check'); setFormReference(''); setFormDate(new Date().toISOString().slice(0, 10));
      await fetchPayments();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to record payment' });
    } finally {
      setSaving(false);
    }
  };

  const tabs = STATUS_VALUES.map((s) => ({
    value: s,
    label: STATUS_LABELS[s],
    count: s === 'all' ? payments.length : payments.filter((p) => p.status === s).length,
  }));

  const filtered = useMemo(() => {
    let list = activeTab === 'all' ? payments : payments.filter((p) => p.status === activeTab);
    if (searchTerm.trim()) {
      const s = searchTerm.toLowerCase();
      list = list.filter((p) =>
        p.Dealers?.dealer_name?.toLowerCase().includes(s) ||
        p.reference_number?.toLowerCase().includes(s) ||
        p.payment_method?.toLowerCase().includes(s)
      );
    }
    return list;
  }, [payments, activeTab, searchTerm]);

  const fmt = (v: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(v);

  const total = filtered.reduce((s, p) => s + Number(p.amount), 0);

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Payments</h1>
          <p className="text-sm text-gray-500 mt-0.5">Payments received from dealers</p>
        </div>
        <button
          type="button"
          onClick={() => setFormOpen(!formOpen)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
        >
          <Plus className="w-4 h-4" />
          Record Payment
        </button>
      </div>

      {formOpen && (
        <div className="mb-4 rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Record New Payment</h3>
          <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
            <div>
              <label className="block text-xs text-gray-500 mb-1">Dealer</label>
              <select
                value={formDealerId}
                onChange={(e) => setFormDealerId(e.target.value)}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
              >
                <option value="">Unassigned (no dealer)</option>
                {dealers.map((d) => (
                  <option key={d.id} value={d.id}>{d.dealer_name}{d.dealer_no ? ` #${d.dealer_no}` : ''}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Amount *</label>
              <input type="number" min={0.01} step={0.01} value={formAmount}
                onChange={(e) => setFormAmount(e.target.value)}
                placeholder="0.00"
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20" />
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Method</label>
              <select value={formMethod} onChange={(e) => setFormMethod(e.target.value)}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20">
                <option value="check">Check</option>
                <option value="wire">Wire Transfer</option>
                <option value="card">Card</option>
                <option value="cash">Cash</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Reference #</label>
              <input type="text" value={formReference} onChange={(e) => setFormReference(e.target.value)}
                placeholder="Check # or ref"
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20" />
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Date</label>
              <input type="date" value={formDate} onChange={(e) => setFormDate(e.target.value)}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20" />
            </div>
          </div>
          <div className="flex gap-2 mt-3">
            <button type="button" onClick={handleRecordPayment}
              disabled={saving || !formAmount}
              className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors">
              {saving ? 'Saving...' : 'Save Payment'}
            </button>
            <button type="button"
              onClick={() => { setFormOpen(false); setFormDealerId(''); setFormAmount(''); setFormReference(''); }}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
              Cancel
            </button>
          </div>
        </div>
      )}

      <StatusTabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />

      <div className="mb-4 mt-4 bg-white border border-gray-200 rounded-lg py-4 px-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search by dealer, reference or method..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20"
          />
        </div>
      </div>

      {loading ? (
        <div className="bg-white border rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
          <p className="text-sm text-gray-600">Loading payments...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">{error}</p>
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Dealer</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Method</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Reference</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Recorded By</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Amount</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-gray-500">
                    <DollarSign className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                    No payments found
                  </td>
                </tr>
              ) : (
                filtered.map((p) => (
                  <tr
                    key={p.id}
                    className="border-t hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(`/financials/payments/${p.id}`)}
                  >
                    <td className="px-4 py-4">{new Date(p.payment_date).toLocaleDateString()}</td>
                    <td className="px-4 py-4 text-gray-700">{p.Dealers?.dealer_name ?? '—'}</td>
                    <td className="px-4 py-4 capitalize text-gray-700">{p.payment_method ?? '—'}</td>
                    <td className="px-4 py-4 text-gray-500">{p.reference_number || '—'}</td>
                    <td className="px-4 py-4 text-gray-500">{p.recorded_by_name ?? '—'}</td>
                    <td className="px-4 py-4 text-right font-mono font-medium text-gray-900">{fmt(p.amount)}</td>
                    <td className="px-4 py-4 text-center">
                      <StatusBadge status={p.status} type="payment" size="sm" />
                    </td>
                  </tr>
                ))
              )}
            </tbody>
            {filtered.length > 0 && (
              <tfoot className="bg-gray-50 border-t">
                <tr>
                  <td colSpan={5} className="px-4 py-4 text-right font-medium text-gray-700">Total</td>
                  <td className="px-4 py-4 text-right font-semibold font-mono">{fmt(total)}</td>
                  <td />
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      )}
    </div>
  );
}
