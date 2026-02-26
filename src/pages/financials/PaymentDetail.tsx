import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useUIStore } from '../../stores/ui-store';
import { FileText, DollarSign } from 'lucide-react';

const FINANCIAL_SUBMODULES = [
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments', href: '/financials/payments', icon: DollarSign },
];

interface DealerInfo {
  dealer_name: string;
  dealer_no: string | null;
  dealer_email: string | null;
  dealer_phone: string | null;
  identification_number: string | null;
  billing_same_as_location: boolean;
  street_address_line_1: string | null;
  street_address_line_2: string | null;
  city: string | null;
  state: string | null;
  zip_code: string | null;
  country: string | null;
  billing_street_address_line_1: string | null;
  billing_street_address_line_2: string | null;
  billing_city: string | null;
  billing_state: string | null;
  billing_zip_code: string | null;
  billing_country: string | null;
}

interface PaymentHeader {
  id: string;
  amount: number;
  payment_method: string;
  reference_number: string | null;
  payment_date: string;
  notes: string | null;
  recorded_by_name: string | null;
  status: string;
  dealer_id: string | null;
  sales_order_id: string | null;
  created_at: string;
  Dealer?: DealerInfo | null;
  SalesOrder?: { id: string; sales_order_no: string } | null;
}

interface InvoiceApplication {
  id: string;
  applied_amount: number;
  invoice_id: string;
  created_at: string;
  Invoice?: { invoice_number: string; total: number; status: string } | null;
}

function getPaymentId(): string | null {
  const match = window.location.pathname.match(/\/financials\/payments\/([^/]+)/);
  return match ? match[1] : null;
}

function formatBillingAddress(d: DealerInfo): string {
  const useBilling = !d.billing_same_as_location;
  const street1 = useBilling ? d.billing_street_address_line_1 : d.street_address_line_1;
  const street2 = useBilling ? d.billing_street_address_line_2 : d.street_address_line_2;
  const city = useBilling ? d.billing_city : d.city;
  const state = useBilling ? d.billing_state : d.state;
  const zip = useBilling ? d.billing_zip_code : d.zip_code;
  const country = useBilling ? d.billing_country : d.country;
  const parts: string[] = [];
  if (street1) parts.push(street1);
  if (street2) parts.push(street2);
  const cityLine = [city, state, zip].filter(Boolean).join(', ');
  if (cityLine) parts.push(cityLine);
  if (country) parts.push(country);
  return parts.join('\n') || '—';
}

export default function PaymentDetail() {
  const paymentId = getPaymentId();
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();

  const addNotification = useUIStore((s) => s.addNotification);

  const [payment, setPayment] = useState<PaymentHeader | null>(null);
  const [applications, setApplications] = useState<InvoiceApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('invoices');
  const [dealersList, setDealersList] = useState<{ id: string; dealer_name: string; dealer_no: string | null }[]>([]);
  const [assignDealerId, setAssignDealerId] = useState('');
  const [assigning, setAssigning] = useState(false);

  useEffect(() => { registerSubmodules('Financials', FINANCIAL_SUBMODULES); }, [registerSubmodules]);

  const fmt = (v: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(v);

  const refetch = useCallback(async () => {
    if (!paymentId || !activeOrganizationId) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const { data: payData, error: payErr } = await supabase
        .from('Payments')
        .select('id, amount, payment_method, reference_number, payment_date, notes, recorded_by_name, dealer_id, sales_order_id, created_at')
        .eq('id', paymentId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .single();
      if (payErr) throw payErr;
      const pay = payData as PaymentHeader;

      const [dealerRes, soRes, appsRes] = await Promise.all([
        pay.dealer_id
          ? supabase.from('Dealers').select('dealer_name, dealer_no, dealer_email, dealer_phone, identification_number, billing_same_as_location, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country').eq('id', pay.dealer_id).maybeSingle()
          : { data: null },
        pay.sales_order_id
          ? supabase.from('SalesOrders').select('id, sales_order_no').eq('id', pay.sales_order_id).maybeSingle()
          : { data: null },
        supabase
          .from('PaymentApplications')
          .select('id, applied_amount, invoice_id, created_at')
          .eq('payment_id', paymentId)
          .order('created_at', { ascending: false }),
      ]);

      pay.Dealer = (dealerRes.data as DealerInfo) ?? null;
      pay.SalesOrder = soRes.data ?? null;
      // Derive status from applications
      const totalApplied = (appsRes.data ?? []).reduce((s: number, a: any) => s + Number(a.applied_amount), 0);
      if (totalApplied >= pay.amount) pay.status = 'applied';
      else if (totalApplied > 0) pay.status = 'partial';
      else pay.status = 'unapplied';
      setPayment(pay);

      const apps = (appsRes.data ?? []) as InvoiceApplication[];
      if (apps.length > 0) {
        const invIds = [...new Set(apps.map((a) => a.invoice_id))];
        const { data: invData } = await supabase
          .from('DealerInvoices')
          .select('id, invoice_number, total, status')
          .in('id', invIds);
        type InvRow = { id: string; invoice_number: string; total: number; status: string };
        const invMap = new Map<string, InvRow>((invData ?? []).map((inv: InvRow) => [inv.id, inv]));
        setApplications(apps.map((a) => ({
          ...a,
          Invoice: (() => { const inv = invMap.get(a.invoice_id); return inv ? { invoice_number: inv.invoice_number, total: inv.total, status: inv.status } : null; })(),
        })));
      } else {
        setApplications([]);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load payment');
    } finally {
      setLoading(false);
    }
  }, [paymentId, activeOrganizationId]);

  useEffect(() => { void refetch(); }, [refetch]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    supabase.from('Dealers').select('id, dealer_name, dealer_no')
      .eq('organization_id', activeOrganizationId).eq('deleted', false).eq('status', 'active')
      .order('dealer_name', { ascending: true })
      .then(({ data }: { data: { id: string; dealer_name: string; dealer_no: string | null }[] | null }) => { if (data) setDealersList(data); });
  }, [activeOrganizationId]);

  const handleAssignDealer = async () => {
    if (!paymentId || !assignDealerId) return;
    setAssigning(true);
    try {
      const { error: err } = await supabase.from('Payments').update({ dealer_id: assignDealerId, updated_at: new Date().toISOString() }).eq('id', paymentId);
      if (err) throw err;
      addNotification({ type: 'success', title: 'Dealer Assigned', message: 'Payment assigned to dealer.' });
      setAssignDealerId('');
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to assign dealer' });
    } finally {
      setAssigning(false);
    }
  };

  if (!paymentId) return <div className="p-6 text-red-600">Invalid URL</div>;

  if (loading && !payment) {
    return (
      <div className="p-6">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  if (error || !payment) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-700">{error || 'Payment not found'}</p>
        </div>
        <button onClick={() => router.navigate('/financials/payments')}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Payments
        </button>
      </div>
    );
  }

  const dealer = payment.Dealer;
  const totalApplied = applications.reduce((s, a) => s + Number(a.applied_amount), 0);
  const unapplied = Math.max(payment.amount - totalApplied, 0);

  const tabs = [
    { id: 'invoices', label: 'Applied Invoices', count: applications.length },
  ];

  return (
    <DetailPageLayout
      title={fmt(payment.amount)}
      subtitle={`Payment${payment.reference_number ? ` - ${payment.reference_number}` : ''}`}
      status={<StatusBadge status={payment.status} type="payment" />}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={() => router.navigate('/financials/payments')}
      contentClassName="pt-2 pb-6"
    >
      {/* Summary cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        {/* Payment Info card */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Payment Info</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-gray-500">Amount</dt>
              <dd className="font-semibold font-mono text-gray-900">{fmt(payment.amount)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Method</dt>
              <dd className="capitalize text-gray-900">{payment.payment_method ?? '—'}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Reference #</dt>
              <dd className="font-mono text-gray-900">{payment.reference_number || '—'}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Date</dt>
              <dd className="text-gray-900">{new Date(payment.payment_date).toLocaleDateString()}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Recorded By</dt>
              <dd className="text-gray-900">{payment.recorded_by_name ?? '—'}</dd>
            </div>
            <div className="flex justify-between border-t pt-2">
              <dt className="text-gray-500">Applied</dt>
              <dd className={`font-mono font-medium ${totalApplied > 0 ? 'text-green-600' : 'text-gray-500'}`}>{fmt(totalApplied)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Unapplied</dt>
              <dd className={`font-mono font-medium ${unapplied > 0 ? 'text-amber-600' : 'text-gray-500'}`}>{fmt(unapplied)}</dd>
            </div>
            {payment.SalesOrder && (
              <div className="flex justify-between border-t pt-2">
                <dt className="text-gray-500">Sales Order</dt>
                <dd>
                  <button type="button"
                    onClick={() => router.navigate(`/sales/orders/${payment.SalesOrder!.id}`)}
                    className="text-primary hover:underline font-medium">
                    {payment.SalesOrder.sales_order_no}
                  </button>
                </dd>
              </div>
            )}
            {payment.notes && (
              <div className="border-t pt-2">
                <dt className="text-gray-500 text-xs mb-0.5">Notes</dt>
                <dd className="text-gray-700">{payment.notes}</dd>
              </div>
            )}
          </dl>
        </div>

        {/* Dealer Info card */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Dealer Info</h3>
          {dealer ? (
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-gray-500">Dealer</dt>
                <dd className="font-medium text-gray-900">{dealer.dealer_name}</dd>
              </div>
              {dealer.dealer_no && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer #</dt>
                  <dd className="font-mono text-gray-900">{dealer.dealer_no}</dd>
                </div>
              )}
              {dealer.identification_number && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Tax ID</dt>
                  <dd className="font-mono text-gray-900">{dealer.identification_number}</dd>
                </div>
              )}
              <div className="border-t pt-2">
                <dt className="text-gray-500 mb-0.5 text-xs">Billing Address</dt>
                <dd className="text-gray-900 whitespace-pre-line text-xs leading-relaxed">{formatBillingAddress(dealer)}</dd>
              </div>
              {dealer.dealer_email && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Email</dt>
                  <dd className="text-gray-900">{dealer.dealer_email}</dd>
                </div>
              )}
              {dealer.dealer_phone && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Phone</dt>
                  <dd className="text-gray-900">{dealer.dealer_phone}</dd>
                </div>
              )}
            </dl>
          ) : (
            <div className="space-y-3">
              <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-amber-50 border border-amber-200">
                <span className="text-xs text-amber-700 font-medium">Unassigned</span>
                <span className="text-xs text-amber-600">This payment has no dealer assigned.</span>
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">Assign to Dealer</label>
                <select
                  value={assignDealerId}
                  onChange={(e) => setAssignDealerId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                >
                  <option value="">-- Select Dealer --</option>
                  {dealersList.map((d) => (
                    <option key={d.id} value={d.id}>{d.dealer_name}{d.dealer_no ? ` #${d.dealer_no}` : ''}</option>
                  ))}
                </select>
              </div>
              <button
                type="button"
                onClick={handleAssignDealer}
                disabled={assigning || !assignDealerId}
                className="w-full px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
              >
                {assigning ? 'Assigning...' : 'Assign Dealer'}
              </button>
            </div>
          )}
        </div>
      </div>

      {activeTab === 'invoices' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Invoice #</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Invoice Total</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Applied</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Invoice Status</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
              </tr>
            </thead>
            <tbody>
              {applications.length === 0 ? (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No invoices linked to this payment</td></tr>
              ) : (
                applications.map((a) => (
                  <tr
                    key={a.id}
                    className="border-t hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(`/financials/invoices/${a.invoice_id}`)}
                  >
                    <td className="px-4 py-4 font-medium text-primary">{a.Invoice?.invoice_number ?? '—'}</td>
                    <td className="px-4 py-4 text-right font-mono text-gray-900">{a.Invoice ? fmt(a.Invoice.total) : '—'}</td>
                    <td className="px-4 py-4 text-right font-mono font-medium text-green-700">{fmt(a.applied_amount)}</td>
                    <td className="px-4 py-4 text-center">
                      {a.Invoice ? <StatusBadge status={a.Invoice.status} type="invoice" size="sm" /> : '—'}
                    </td>
                    <td className="px-4 py-4 text-gray-500">{new Date(a.created_at).toLocaleDateString()}</td>
                  </tr>
                ))
              )}
            </tbody>
            {applications.length > 0 && (
              <tfoot className="bg-gray-50 border-t">
                <tr>
                  <td />
                  <td />
                  <td className="px-4 py-4 text-right font-semibold font-mono text-green-700">{fmt(totalApplied)}</td>
                  <td colSpan={2} />
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      )}
    </DetailPageLayout>
  );
}
