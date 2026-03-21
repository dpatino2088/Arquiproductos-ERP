import { useState, useEffect, useCallback } from 'react';
import { supabase, initSessionContext } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useVendorFinancialDetail, useVendorFinancialTimeline } from '../../hooks/useVendorFinancialAccounts';
import StatusBadge from '../../components/shared/StatusBadge';
import { formatCurrency, formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { ArrowLeft } from 'lucide-react';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

interface BillRow {
  bill_id: string;
  bill_number: string;
  bill_status: string;
  bill_date: string;
  due_date: string | null;
  bill_total: number;
  applied_total: number;
  balance_due: number;
  po_number?: string | null;
  purchase_order_id?: string | null;
}

interface PaymentRow {
  id: string;
  payment_date: string;
  amount: number;
  payment_method: string | null;
  reference_number: string | null;
  status: string;
  applied_total: number;
  available: number;
  applied_bills: string[];
}

interface ApplicationRow {
  id: string;
  created_at: string;
  vendor_payment_id: string;
  bill_id: string;
  applied_amount: number;
  bill_number?: string;
  payment_method?: string | null;
  payment_reference?: string | null;
  payment_date?: string;
}

function fmtMethod(m: string | null | undefined): string {
  if (!m) return '—';
  return m.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

interface PORow {
  id: string;
  po_number: string | null;
  status: string;
  expected_date: string | null;
  subtotal: number;
  total: number;
  currency: string;
  created_at: string;
  line_count: number;
  received_count: number;
  bill_status: 'not_billed' | 'billed' | 'paid' | 'partial';
  bill_number: string | null;
}

const TABS = ['overview', 'purchase-orders', 'bills', 'payments', 'applications', 'timeline'] as const;
type Tab = typeof TABS[number];

const TAB_LABELS: Record<Tab, string> = {
  'overview': 'Overview',
  'purchase-orders': 'Purchase Orders',
  'bills': 'Bills',
  'payments': 'Payments',
  'applications': 'Applications',
  'timeline': 'Timeline',
};

export default function VendorAccountDetail() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();

  const vendorId = window.location.pathname.split('/').pop() ?? '';
  const { detail, isLoading } = useVendorFinancialDetail(vendorId || null);
  const { entries: timelineEntries } = useVendorFinancialTimeline(vendorId || null);

  const [activeTab, setActiveTab] = useState<Tab>('overview');
  const [bills, setBills] = useState<BillRow[]>([]);
  const [payments, setPayments] = useState<PaymentRow[]>([]);
  const [apps, setApps] = useState<ApplicationRow[]>([]);
  const [purchaseOrders, setPurchaseOrders] = useState<PORow[]>([]);
  const queryReturnTo = getReturnToFromCurrentQuery();

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const loadTabData = useCallback(async () => {
    if (!activeOrganizationId || !vendorId) return;
    await initSessionContext();

    const [{ data: billData }, { data: paymentData }, { data: appData }, { data: poData }] = await Promise.all([
      supabase
        .from('vendor_bill_balances_v1')
        .select('bill_id, bill_number, bill_status, bill_date, due_date, bill_total, applied_total, balance_due')
        .eq('organization_id', activeOrganizationId)
        .eq('vendor_id', vendorId)
        .order('bill_date', { ascending: false }),
      supabase
        .from('VendorPayments')
        .select('id, payment_date, amount, payment_method, reference_number, status')
        .eq('organization_id', activeOrganizationId)
        .eq('vendor_id', vendorId)
        .eq('deleted', false)
        .order('payment_date', { ascending: false }),
      supabase
        .from('VendorPaymentApplications')
        .select('id, created_at, vendor_payment_id, bill_id, applied_amount')
        .order('created_at', { ascending: false }),
      supabase
        .from('PurchaseOrders')
        .select('id, po_number, status, expected_date, subtotal, total, currency, created_at, PurchaseOrderLines(id, ordered_qty, received_qty), VendorBills!purchase_order_id(bill_number, status, deleted)')
        .eq('organization_id', activeOrganizationId)
        .eq('vendor_id', vendorId)
        .order('created_at', { ascending: false }),
    ]);

    const billRows = ((billData ?? []) as BillRow[]).map(b => ({
      ...b, bill_total: Number(b.bill_total), applied_total: Number(b.applied_total), balance_due: Number(b.balance_due),
    }));

    if (billRows.length > 0) {
      const { data: billPOs } = await supabase
        .from('VendorBills')
        .select('id, purchase_order_id')
        .in('id', billRows.map(b => b.bill_id));
      if (billPOs) {
        const poIds = [...new Set((billPOs as Array<{ id: string; purchase_order_id: string | null }>).map(b => b.purchase_order_id).filter(Boolean))] as string[];
        const poNumberMap = new Map<string, string>();
        const billPoMap = new Map((billPOs as Array<{ id: string; purchase_order_id: string | null }>).map(b => [b.id, b.purchase_order_id]));
        if (poIds.length > 0) {
          const { data: poNames } = await supabase.from('PurchaseOrders').select('id, po_number').in('id', poIds);
          (poNames ?? []).forEach((p: { id: string; po_number: string | null }) => { if (p.po_number) poNumberMap.set(p.id, p.po_number); });
        }
        billRows.forEach(b => {
          const poId = billPoMap.get(b.bill_id);
          b.purchase_order_id = poId ?? null;
          b.po_number = poId ? poNumberMap.get(poId) ?? null : null;
        });
      }
    }
    setBills(billRows);

    const billNumberMap = new Map(billRows.map(b => [b.bill_id, b.bill_number]));
    const rawPayments = ((paymentData ?? []) as Array<{ id: string; payment_date: string; amount: number; payment_method: string | null; reference_number: string | null; status: string }>)
      .map(p => ({ ...p, amount: Number(p.amount) }));
    const rawApps = ((appData ?? []) as ApplicationRow[]).map(a => ({ ...a, applied_amount: Number(a.applied_amount) }));

    const appliedByPayment = new Map<string, { total: number; bills: string[] }>();
    rawApps.forEach(a => {
      const entry = appliedByPayment.get(a.vendor_payment_id) ?? { total: 0, bills: [] };
      entry.total += a.applied_amount;
      const bn = billNumberMap.get(a.bill_id);
      if (bn && !entry.bills.includes(bn)) entry.bills.push(bn);
      appliedByPayment.set(a.vendor_payment_id, entry);
    });

    const paymentMethodMap = new Map(rawPayments.map(p => [p.id, { method: p.payment_method, ref: p.reference_number, date: p.payment_date }]));

    setPayments(rawPayments.map(p => {
      const app = appliedByPayment.get(p.id);
      const appliedTotal = app?.total ?? 0;
      return { ...p, applied_total: appliedTotal, available: Math.max(0, p.amount - appliedTotal), applied_bills: app?.bills ?? [] };
    }));

    const rawPOs = (poData ?? []) as Array<{
      id: string; po_number: string | null; status: string; expected_date: string | null;
      subtotal: number; total: number; currency: string; created_at: string;
      PurchaseOrderLines?: Array<{ id: string; ordered_qty: number; received_qty: number }>;
      VendorBills?: Array<{ bill_number: string; status: string; deleted: boolean }>;
    }>;
    setPurchaseOrders(rawPOs.map(po => {
      const activeBills = (po.VendorBills ?? []).filter(b => !b.deleted && b.status !== 'void');
      const firstBill = activeBills[0] ?? null;
      let billStatus: PORow['bill_status'] = 'not_billed';
      if (firstBill) {
        if (firstBill.status === 'paid') billStatus = 'paid';
        else if (firstBill.status === 'partial') billStatus = 'partial';
        else billStatus = 'billed';
      }
      return {
        id: po.id,
        po_number: po.po_number,
        status: po.status,
        expected_date: po.expected_date,
        subtotal: Number(po.subtotal) || 0,
        total: Number(po.total) || 0,
        currency: po.currency ?? 'USD',
        created_at: po.created_at,
        line_count: po.PurchaseOrderLines?.length ?? 0,
        received_count: po.PurchaseOrderLines?.filter(l => (l.received_qty ?? 0) >= (l.ordered_qty ?? 1)).length ?? 0,
        bill_status: billStatus,
        bill_number: firstBill?.bill_number ?? null,
      };
    }));

    const billIds = new Set(billRows.map(b => b.bill_id));
    const paymentIds = new Set(rawPayments.map(p => p.id));

    const enrichedApps = rawApps
      .filter(a => billIds.has(a.bill_id) || paymentIds.has(a.vendor_payment_id))
      .map(a => {
        const pm = paymentMethodMap.get(a.vendor_payment_id);
        return {
          ...a,
          bill_number: billNumberMap.get(a.bill_id),
          payment_method: pm?.method ?? null,
          payment_reference: pm?.ref ?? null,
          payment_date: pm?.date,
        };
      });
    setApps(enrichedApps);
  }, [activeOrganizationId, vendorId]);

  useEffect(() => { loadTabData(); }, [loadTabData]);

  if (isLoading || !detail) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[300px]">
          <div className="h-8 w-8 animate-spin rounded-full border-b-2 border-primary" />
        </div>
      </div>
    );
  }

  const agingTotal = detail.aging.current + detail.aging.days_1_30 + detail.aging.days_31_60 + detail.aging.days_61_90 + detail.aging.days_90_plus;

  return (
    <div className="py-6 px-6 max-w-6xl mx-auto">
      <button onClick={() => navigateBackContextual(router, { queryReturnTo, fallback: '/financials/vendor-accounts' })} className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="h-4 w-4" /> Back to Vendor Accounts
      </button>

      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">{detail.vendor_name}</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {detail.vendor_email && <span>{detail.vendor_email}</span>}
            {detail.vendor_phone && <span className="ml-3">{detail.vendor_phone}</span>}
          </p>
        </div>
      </div>

      {/* Tab Bar */}
      <div className="overflow-x-auto border border-gray-200 border-b-0 rounded-t-lg mb-6 bg-white">
        <nav className="flex min-w-0" role="tablist">
          {TABS.map(tab => {
            const isActive = tab === activeTab;
            return (
              <button
                key={tab}
                type="button"
                role="tab"
                aria-selected={isActive}
                onClick={() => setActiveTab(tab)}
                className={`flex shrink-0 items-center gap-1.5 transition-colors whitespace-nowrap border-r ${
                  isActive ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
                }`}
                style={{
                  fontSize: '12px',
                  padding: '0 16px',
                  height: '40px',
                  color: '#1c1f26',
                  borderColor: 'var(--gray-250)',
                  borderBottom: isActive ? '2px solid var(--sidebar-base)' : '2px solid var(--gray-250)',
                }}
              >
                {TAB_LABELS[tab]}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Overview Tab */}
      <div hidden={activeTab !== 'overview'}>
        <div className="grid grid-cols-4 gap-4 mb-6">
          {[
            { label: 'Total Billed (Lifetime)', value: formatCurrency(detail.total_billed_lifetime) },
            { label: 'Total Paid (Lifetime)', value: formatCurrency(detail.total_paid_lifetime) },
            { label: 'Open AP', value: formatCurrency(detail.open_ap), highlight: detail.open_ap > 0 },
            { label: 'Past Due', value: formatCurrency(detail.past_due_amount), highlight: detail.past_due_amount > 0, red: true },
          ].map(card => (
            <div key={card.label} className="bg-white border border-gray-200 rounded-lg p-4">
              <p className="text-xs text-gray-500">{card.label}</p>
              <p className={`text-lg font-bold mt-1 ${card.red && card.highlight ? 'text-red-600' : card.highlight ? 'text-primary' : ''}`}>{card.value}</p>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="bg-white border border-gray-200 rounded-lg p-4">
            <p className="text-xs text-gray-500">Unapplied Payments</p>
            <p className="text-lg font-bold mt-1 text-blue-600">{formatCurrency(detail.unapplied_amount)}</p>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-4">
            <p className="text-xs text-gray-500">Open Bills</p>
            <p className="text-lg font-bold mt-1">{detail.open_bills_count}</p>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-4 cursor-pointer hover:border-gray-300 transition-colors" onClick={() => setActiveTab('purchase-orders')}>
            <p className="text-xs text-gray-500">Open POs</p>
            <p className="text-lg font-bold mt-1 text-primary">{detail.open_po_count}</p>
          </div>
        </div>

        {/* Aging */}
        {agingTotal > 0 && (
          <div className="bg-white border border-gray-200 rounded-lg p-4 mb-6">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">AP Aging</h3>
            <div className="grid grid-cols-5 gap-4 text-sm">
              {[
                { label: 'Current', value: detail.aging.current },
                { label: '1-30 Days', value: detail.aging.days_1_30 },
                { label: '31-60 Days', value: detail.aging.days_31_60 },
                { label: '61-90 Days', value: detail.aging.days_61_90 },
                { label: '90+ Days', value: detail.aging.days_90_plus },
              ].map(bucket => (
                <div key={bucket.label} className="text-center">
                  <p className="text-xs text-gray-500">{bucket.label}</p>
                  <p className={`font-medium mt-1 ${bucket.value > 0 && bucket.label === '90+ Days' ? 'text-red-600' : ''}`}>{formatCurrency(bucket.value)}</p>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Purchase Orders Tab */}
      <div hidden={activeTab !== 'purchase-orders'}>
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">PO #</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Date</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Expected</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Items</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Total</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Billing</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {purchaseOrders.length === 0 && <tr><td colSpan={7} className="py-8 text-center text-sm text-gray-400">No purchase orders</td></tr>}
              {purchaseOrders.map(po => (
                <tr key={po.id} className="border-b border-gray-100 hover:bg-gray-50 cursor-pointer" onClick={() => router.navigate(withReturnTo(`/inventory/purchase-orders/${po.id}`, `/financials/vendor-accounts/${vendorId}`))}>
                  <td className="py-3 px-4 font-medium text-primary">{po.po_number || '—'}</td>
                  <td className="py-3 px-4 text-center">{formatDate(po.created_at)}</td>
                  <td className="py-3 px-4 text-center">{formatDate(po.expected_date)}</td>
                  <td className="py-3 px-4 text-center">{po.received_count}/{po.line_count} received</td>
                  <td className="py-3 px-4 text-right font-medium">{formatCurrency(po.total)}</td>
                  <td className="py-3 px-4 text-center">
                    {po.bill_status === 'paid' ? (
                      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-50 text-green-700 border border-green-200">Paid</span>
                    ) : po.bill_status === 'partial' ? (
                      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-yellow-700 border border-yellow-200">Partial</span>
                    ) : po.bill_status === 'billed' ? (
                      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-blue-700 border border-blue-200">Billed</span>
                    ) : (
                      <span className="text-xs text-gray-400">—</span>
                    )}
                  </td>
                  <td className="py-3 px-4 text-center"><StatusBadge status={po.status.toLowerCase()} type="purchaseOrder" size="sm" /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Bills Tab */}
      <div hidden={activeTab !== 'bills'}>
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Bill #</th>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">PO #</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Date</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Due Date</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Total</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Paid</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Balance</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {bills.length === 0 && <tr><td colSpan={8} className="py-8 text-center text-sm text-gray-400">No bills</td></tr>}
              {bills.map(b => (
                <tr key={b.bill_id} className="border-b border-gray-100 hover:bg-gray-50 cursor-pointer" onClick={() => router.navigate(withReturnTo(`/financials/bills/${b.bill_id}`, `/financials/vendor-accounts/${vendorId}`))}>
                  <td className="py-3 px-4 font-medium text-primary">{b.bill_number}</td>
                  <td className="py-3 px-4">
                    {b.po_number ? (
                      <button onClick={e => { e.stopPropagation(); router.navigate(withReturnTo(`/inventory/purchase-orders/${b.purchase_order_id}`, `/financials/vendor-accounts/${vendorId}`)); }} className="text-primary hover:underline text-sm">{b.po_number}</button>
                    ) : <span className="text-gray-400">—</span>}
                  </td>
                  <td className="py-3 px-4 text-center">{formatDate(b.bill_date)}</td>
                  <td className="py-3 px-4 text-center">{formatDate(b.due_date)}</td>
                  <td className="py-3 px-4 text-right">{formatCurrency(b.bill_total)}</td>
                  <td className="py-3 px-4 text-right">{formatCurrency(b.applied_total)}</td>
                  <td className="py-3 px-4 text-right font-medium">{formatCurrency(b.balance_due)}</td>
                  <td className="py-3 px-4 text-center"><StatusBadge status={b.bill_status} type="bill" size="sm" /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Payments Tab */}
      <div hidden={activeTab !== 'payments'}>
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Date</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Method</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Reference</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Amount</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Applied</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Available</th>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Applied To</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {payments.length === 0 && <tr><td colSpan={8} className="py-8 text-center text-sm text-gray-400">No payments</td></tr>}
              {payments.map(p => (
                <tr key={p.id} className={`border-b border-gray-100 hover:bg-gray-50 cursor-pointer ${p.status === 'void' ? 'opacity-60' : ''}`} onClick={() => router.navigate(withReturnTo(`/financials/vendor-payments/${p.id}`, `/financials/vendor-accounts/${vendorId}`))}>
                  <td className="py-3 px-4">{formatDate(p.payment_date)}</td>
                  <td className="py-3 px-4 text-center">{fmtMethod(p.payment_method)}</td>
                  <td className="py-3 px-4 text-center text-gray-500">{p.reference_number || '—'}</td>
                  <td className={`py-3 px-4 text-right font-medium ${p.status === 'void' ? 'line-through' : ''}`}>{formatCurrency(p.amount)}</td>
                  <td className="py-3 px-4 text-right">{formatCurrency(p.applied_total)}</td>
                  <td className={`py-3 px-4 text-right font-medium ${p.available > 0 ? 'text-blue-600' : ''}`}>{formatCurrency(p.available)}</td>
                  <td className="py-3 px-4">
                    {p.applied_bills.length > 0 ? (
                      <span className="text-xs text-gray-600">{p.applied_bills.join(', ')}</span>
                    ) : <span className="text-xs text-gray-400">Not applied</span>}
                  </td>
                  <td className="py-3 px-4 text-center"><StatusBadge status={p.status} type="vendorPayment" size="sm" /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Applications Tab */}
      <div hidden={activeTab !== 'applications'}>
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Date</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Payment Method</th>
                <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Reference</th>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Bill #</th>
                <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Applied</th>
              </tr>
            </thead>
            <tbody>
              {apps.length === 0 && <tr><td colSpan={5} className="py-8 text-center text-sm text-gray-400">No applications</td></tr>}
              {apps.map(a => (
                <tr key={a.id} className="border-b border-gray-100">
                  <td className="py-3 px-4">{formatDate(a.payment_date ?? a.created_at)}</td>
                  <td className="py-3 px-4 text-center">{fmtMethod(a.payment_method)}</td>
                  <td className="py-3 px-4 text-center text-gray-500">{a.payment_reference || '—'}</td>
                  <td className="py-3 px-4">
                    <button onClick={() => router.navigate(withReturnTo(`/financials/bills/${a.bill_id}`, `/financials/vendor-accounts/${vendorId}`))} className="text-primary hover:underline">
                      {a.bill_number || '—'}
                    </button>
                  </td>
                  <td className="py-3 px-4 text-right font-medium">{formatCurrency(a.applied_amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Timeline Tab */}
      <div hidden={activeTab !== 'timeline'}>
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          {timelineEntries.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No activity yet</p>
          ) : (
            <div className="space-y-3">
              {timelineEntries.map(entry => {
                const typeLabels: Record<string, string> = {
                  purchase_order_created: 'PO Created',
                  bill_created: 'Bill Created',
                  bill_opened: 'Bill Opened',
                  bill_partially_paid: 'Bill Partially Paid',
                  bill_paid: 'Bill Paid',
                  bill_voided: 'Bill Voided',
                  vendor_credit_created: 'Credit Issued',
                  vendor_credit_voided: 'Credit Voided',
                  vendor_payment_recorded: 'Payment Recorded',
                  vendor_payment_voided: 'Payment Voided',
                  vendor_payment_applied: 'Payment Applied',
                };
                const colorMap: Record<string, string> = {
                  purchase_order_created: 'bg-blue-100 text-blue-700',
                  bill_created: 'bg-gray-100 text-gray-700',
                  bill_opened: 'bg-blue-100 text-blue-700',
                  bill_paid: 'bg-green-100 text-green-700',
                  bill_voided: 'bg-red-100 text-red-700',
                  vendor_payment_recorded: 'bg-green-100 text-green-700',
                  vendor_payment_voided: 'bg-red-100 text-red-700',
                  vendor_payment_applied: 'bg-emerald-100 text-emerald-700',
                  vendor_credit_created: 'bg-purple-100 text-purple-700',
                  vendor_credit_voided: 'bg-red-100 text-red-700',
                };
                return (
                  <div key={`${entry.entity_id}-${entry.event_type}`} className="flex items-center gap-3 py-2 border-b border-gray-50">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${colorMap[entry.event_type] ?? 'bg-gray-100 text-gray-700'}`}>
                      {typeLabels[entry.event_type] ?? entry.event_type}
                    </span>
                    <span className="text-sm text-gray-600 flex-1">{entry.reference_no || '—'}</span>
                    <span className="text-sm font-medium">{formatCurrency(entry.amount)}</span>
                    <span className="text-xs text-gray-400 w-24 text-right">{entry.event_at?.split('T')[0]}</span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
