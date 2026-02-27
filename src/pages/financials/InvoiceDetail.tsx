import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { FileText, DollarSign, ChevronDown } from 'lucide-react';
import { generateInvoicePDF } from '../../lib/pdf/generateInvoicePDF';
import type { InvoicePDFLine, InvoicePDFData, InvoicePDFDealer, GenerateInvoicePDFOptions } from '../../lib/pdf/generateInvoicePDF';

const FINANCIAL_SUBMODULES = [
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments', href: '/financials/payments', icon: DollarSign },
];

interface DealerBilling {
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

interface InvoiceHeader {
  id: string;
  invoice_number: string;
  status: string;
  issue_date: string;
  due_date: string | null;
  currency_code: string;
  subtotal: number;
  tax_total: number;
  total: number;
  notes: string | null;
  sales_order_id: string | null;
  dealer_id: string | null;
  created_at: string;
  Dealers?: DealerBilling | null;
  SalesOrders?: { id: string; sales_order_no: string } | null;
}

interface InvoiceLine {
  id: string;
  description: string;
  qty: number;
  unit_price: number;
  line_subtotal: number;
}

interface PaymentApplication {
  id: string;
  applied_amount: number;
  payment_id: string;
  created_at: string;
  Payments?: { payment_date: string; method: string; reference: string | null; recorded_by_name: string | null } | null;
}

function getInvoiceId(): string | null {
  const match = window.location.pathname.match(/\/financials\/invoices\/([^/]+)/);
  return match ? match[1] : null;
}

function formatBillingAddress(d: DealerBilling): string {
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

export default function InvoiceDetail() {
  const invoiceId = getInvoiceId();
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);

  const [invoice, setInvoice] = useState<InvoiceHeader | null>(null);
  const [lines, setLines] = useState<InvoiceLine[]>([]);
  const [applications, setApplications] = useState<PaymentApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('lines');
  const [actionsOpen, setActionsOpen] = useState(false);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [applyFormOpen, setApplyFormOpen] = useState(false);
  const [availablePayments, setAvailablePayments] = useState<{ id: string; amount: number; unapplied: number; payment_date: string; reference_number: string | null; payment_method: string }[]>([]);
  const [selectedPaymentId, setSelectedPaymentId] = useState('');
  const [applyAmount, setApplyAmount] = useState('');
  const [applying, setApplying] = useState(false);

  useEffect(() => { registerSubmodules('Financials', FINANCIAL_SUBMODULES); }, [registerSubmodules]);

  const fmt = (v: number, currency = 'USD') =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);

  const refetch = useCallback(async () => {
    if (!invoiceId || !activeOrganizationId) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const [invRes, linesRes, appsRes] = await Promise.all([
        supabase
          .from('DealerInvoices')
          .select('id, invoice_number, status, issue_date, due_date, currency_code, subtotal, tax_total, total, notes, sales_order_id, dealer_id, created_at')
          .eq('id', invoiceId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .single(),
        supabase
          .from('DealerInvoiceLines')
          .select('id, description, qty, unit_price, tax_pct, line_subtotal, line_tax, line_total')
          .eq('invoice_id', invoiceId)
          .order('sort_order', { ascending: true }),
        supabase
          .from('PaymentApplications')
          .select('id, applied_amount, payment_id, created_at')
          .eq('invoice_id', invoiceId)
          .order('created_at', { ascending: false }),
      ]);
      if (invRes.error) throw invRes.error;
      const inv = invRes.data as InvoiceHeader;

      const [dealerRes, soRes] = await Promise.all([
        inv.dealer_id
          ? supabase.from('Dealers').select('dealer_name, dealer_no, dealer_email, dealer_phone, identification_number, billing_same_as_location, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country').eq('id', inv.dealer_id).maybeSingle()
          : { data: null },
        inv.sales_order_id
          ? supabase.from('SalesOrders').select('id, sales_order_no').eq('id', inv.sales_order_id).maybeSingle()
          : { data: null },
      ]);
      inv.Dealers = (dealerRes.data as DealerBilling) ?? null;
      inv.SalesOrders = soRes.data ?? null;
      setInvoice(inv);
      setLines((linesRes.data ?? []) as InvoiceLine[]);

      const apps = (appsRes.data ?? []) as PaymentApplication[];
      if (apps.length > 0) {
        const payIds = [...new Set(apps.map((a) => a.payment_id))];
        const { data: payData } = await supabase
          .from('Payments')
          .select('id, payment_date, payment_method, reference_number, recorded_by_name')
          .in('id', payIds);
        type PayRow = { id: string; payment_date: string; payment_method: string; reference_number: string | null; recorded_by_name: string | null };
        const payMap = new Map<string, PayRow>((payData ?? []).map((p: PayRow) => [p.id, p]));
        setApplications(apps.map((a) => ({
          ...a,
          Payments: (() => { const p = payMap.get(a.payment_id); return p ? { payment_date: p.payment_date, method: p.payment_method, reference: p.reference_number, recorded_by_name: p.recorded_by_name } : null; })(),
        })));
      } else {
        setApplications([]);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load invoice');
    } finally {
      setLoading(false);
    }
  }, [invoiceId, activeOrganizationId]);

  useEffect(() => { void refetch(); }, [refetch]);

  const updateStatus = async (newStatus: string) => {
    if (!invoiceId) return;
    setUpdatingStatus(true);
    try {
      const { error: err } = await supabase
        .from('DealerInvoices')
        .update({ status: newStatus })
        .eq('id', invoiceId);
      if (err) throw err;
      addNotification({ type: 'success', title: 'Status Updated', message: `Invoice marked as ${newStatus}.` });
      setActionsOpen(false);
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to update status' });
    } finally {
      setUpdatingStatus(false);
    }
  };

  const deleteInvoice = async () => {
    if (!invoiceId) return;
    setUpdatingStatus(true);
    try {
      const { error: err } = await supabase
        .from('DealerInvoices')
        .update({ deleted: true })
        .eq('id', invoiceId);
      if (err) throw err;
      addNotification({ type: 'success', title: 'Deleted', message: 'Invoice deleted.' });
      router.navigate('/financials/invoices');
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to delete invoice' });
    } finally {
      setUpdatingStatus(false);
    }
  };

  const loadAvailablePayments = useCallback(async () => {
    if (!invoice?.dealer_id || !activeOrganizationId) return;
    const { data: payments } = await supabase
      .from('Payments')
      .select('id, amount, payment_date, reference_number, payment_method')
      .eq('organization_id', activeOrganizationId)
      .eq('dealer_id', invoice.dealer_id)
      .eq('deleted', false)
      .order('payment_date', { ascending: false });
    if (!payments || payments.length === 0) { setAvailablePayments([]); return; }

    const payIds = payments.map((p: any) => p.id);
    const { data: apps } = await supabase
      .from('PaymentApplications')
      .select('payment_id, applied_amount')
      .in('payment_id', payIds);
    const appliedMap = new Map<string, number>();
    for (const a of (apps ?? []) as { payment_id: string; applied_amount: number }[]) {
      appliedMap.set(a.payment_id, (appliedMap.get(a.payment_id) ?? 0) + Number(a.applied_amount));
    }
    setAvailablePayments(
      (payments as any[])
        .map((p) => ({ ...p, unapplied: p.amount - (appliedMap.get(p.id) ?? 0) }))
        .filter((p) => p.unapplied > 0.005)
    );
  }, [invoice?.dealer_id, activeOrganizationId]);

  const handleOpenApplyForm = () => {
    setApplyFormOpen(true);
    loadAvailablePayments();
  };

  const handleApplyPayment = async () => {
    if (!invoiceId || !selectedPaymentId || !applyAmount) return;
    const amount = parseFloat(applyAmount);
    if (isNaN(amount) || amount <= 0) {
      addNotification({ type: 'error', title: 'Validation', message: 'Amount must be greater than 0.' });
      return;
    }
    setApplying(true);
    try {
      const { error: err } = await supabase.rpc('apply_payment', {
        p_payment_id: selectedPaymentId,
        p_invoice_id: invoiceId,
        p_amount: amount,
      });
      if (err) throw err;

      // Auto-update invoice status
      const newApplied = totalApplied + amount;
      let newStatus = invoice!.status;
      if (newApplied >= invoice!.total) newStatus = 'paid';
      else if (newApplied > 0) newStatus = 'partial';
      if (newStatus !== invoice!.status) {
        await supabase.from('DealerInvoices').update({ status: newStatus }).eq('id', invoiceId);
      }

      addNotification({ type: 'success', title: 'Payment Applied', message: `${fmt(amount, currency)} applied to invoice.` });
      setApplyFormOpen(false);
      setSelectedPaymentId('');
      setApplyAmount('');
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to apply payment' });
    } finally {
      setApplying(false);
    }
  };

  const loadOrganizationLogoOptions = useCallback(async (): Promise<GenerateInvoicePDFOptions> => {
    const tryLogo = async (path: string): Promise<string | undefined> => {
      try {
        const res = await fetch(path, { cache: 'no-store' });
        if (!res.ok) return undefined;
        const blob = await res.blob();
        return await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      } catch {
        return undefined;
      }
    };

    let organizationName = 'Arquiproductos';
    if (activeOrganizationId) {
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', activeOrganizationId)
        .maybeSingle();
      organizationName = (orgData as { name?: string } | null)?.name ?? 'Arquiproductos';
    }

    const logoPaths = [
      '/images/Arquiproductos.png',
      '/images/arquiproductos.png',
      '/images/Arquiproductos.jpg',
      '/images/arquiproductos.jpg',
    ];
    let logoPngBase64: string | undefined;
    for (const path of logoPaths) {
      logoPngBase64 = await tryLogo(path);
      if (logoPngBase64) break;
    }

    let logoWidthPx = 100;
    let logoHeightPx = 100;
    if (logoPngBase64) {
      const dims = await new Promise<{ w: number; h: number }>((resolve) => {
        const img = new Image();
        img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
        img.onerror = () => resolve({ w: 100, h: 100 });
        img.src = logoPngBase64!;
      });
      logoWidthPx = dims.w;
      logoHeightPx = dims.h;
    }

    return {
      organizationName,
      logoPngBase64,
      logoWidthPx,
      logoHeightPx,
    };
  }, [activeOrganizationId]);

  const buildInvoicePDFDoc = useCallback(async () => {
    if (!invoice) return null;
    const pdfData: InvoicePDFData = {
      invoice_number: invoice.invoice_number,
      status: invoice.status,
      issue_date: invoice.issue_date,
      due_date: invoice.due_date,
      currency_code: invoice.currency_code || 'USD',
      subtotal: invoice.subtotal,
      tax_total: invoice.tax_total,
      total: invoice.total,
      total_paid: applications.reduce((s, a) => s + Number(a.applied_amount), 0),
      balance_due: Math.max(invoice.total - applications.reduce((s, a) => s + Number(a.applied_amount), 0), 0),
      notes: invoice.notes,
      sales_order_no: invoice.SalesOrders?.sales_order_no ?? null,
    };
    const pdfDealer: InvoicePDFDealer | null = invoice.Dealers ? {
      dealer_name: invoice.Dealers.dealer_name,
      dealer_no: invoice.Dealers.dealer_no ?? null,
      identification_number: invoice.Dealers.identification_number ?? null,
      billing_address: formatBillingAddress(invoice.Dealers),
      email: invoice.Dealers.dealer_email ?? null,
      phone: invoice.Dealers.dealer_phone ?? null,
    } : null;
    const pdfLines: InvoicePDFLine[] = lines.map((l) => ({
      description: l.description,
      qty: l.qty,
      unit_price: l.unit_price,
      line_subtotal: l.line_subtotal,
    }));

    const logoOptions = await loadOrganizationLogoOptions();
    return generateInvoicePDF(pdfData, pdfDealer, pdfLines, logoOptions);
  }, [invoice, applications, lines, loadOrganizationLogoOptions]);

  const handlePreviewPDF = async () => {
    const doc = await buildInvoicePDFDoc();
    if (!doc) return;
    const blob = doc.output('blob');
    const url = URL.createObjectURL(blob);
    window.open(url, '_blank');
  };

  const handleDownloadPDF = async () => {
    const doc = await buildInvoicePDFDoc();
    if (!doc || !invoice) return;
    doc.save(`${invoice.invoice_number}.pdf`);
  };

  if (!invoiceId) return <div className="p-6 text-red-600">Invalid URL</div>;

  if (loading && !invoice) {
    return (
      <div className="p-6">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  if (error || !invoice) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-700">{error || 'Invoice not found'}</p>
        </div>
        <button onClick={() => router.navigate('/financials/invoices')}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Invoices
        </button>
      </div>
    );
  }

  const currency = invoice.currency_code || 'USD';
  const totalApplied = applications.reduce((s, a) => s + Number(a.applied_amount), 0);
  const balanceDue = Math.max(invoice.total - totalApplied, 0);
  const status = invoice.status;
  const dealer = invoice.Dealers;

  const tabs = [
    { id: 'lines', label: 'Lines', count: lines.length },
    { id: 'payments', label: 'Payments Applied', count: applications.length },
  ];

  const actionItems: { label: string; onClick: () => void; danger?: boolean }[] = [];
  actionItems.push({ label: 'Preview PDF', onClick: handlePreviewPDF });
  actionItems.push({ label: 'Download PDF', onClick: handleDownloadPDF });
  if (status === 'draft') {
    actionItems.push({ label: 'Issue Invoice', onClick: () => updateStatus('issued') });
    actionItems.push({ label: 'Delete', onClick: deleteInvoice, danger: true });
  }
  if (status === 'issued' || status === 'partial') {
    actionItems.push({ label: 'Void Invoice', onClick: () => updateStatus('void'), danger: true });
  }

  return (
    <DetailPageLayout
      title={invoice.invoice_number}
      subtitle="Invoice Detail"
      status={<StatusBadge status={invoice.status} type="invoice" />}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={() => router.navigate('/financials/invoices')}
      contentClassName="pt-2 pb-6"
      actions={actionItems.length > 0 ? (
        <div className="relative">
          <button
            type="button"
            onClick={() => setActionsOpen(!actionsOpen)}
            disabled={updatingStatus}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
          >
            Actions <ChevronDown className="w-4 h-4" />
          </button>
          {actionsOpen && (
            <>
              <div className="fixed inset-0 z-30" onClick={() => setActionsOpen(false)} />
              <div className="absolute right-0 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-40 min-w-[160px] py-1">
                {actionItems.map((item, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={item.onClick}
                    className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-50 ${item.danger ? 'text-red-600' : 'text-gray-700'}`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </>
          )}
        </div>
      ) : undefined}
    >
      {/* Row 1: Bill To + Invoice Details */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        {/* Bill To card */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Bill To</h3>
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
            <p className="text-sm text-gray-400">No dealer information</p>
          )}
        </div>

        {/* Invoice Details card */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Invoice Details</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-gray-500">Status</dt>
              <dd><StatusBadge status={invoice.status} type="invoice" size="sm" /></dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Issue Date</dt>
              <dd className="text-gray-900">{new Date(invoice.issue_date).toLocaleDateString()}</dd>
            </div>
            {invoice.due_date && (
              <div className="flex justify-between">
                <dt className="text-gray-500">Due Date</dt>
                <dd className="text-gray-900">{new Date(invoice.due_date).toLocaleDateString()}</dd>
              </div>
            )}
            {invoice.SalesOrders && (
              <div className="flex justify-between border-t pt-2">
                <dt className="text-gray-500">Sales Order</dt>
                <dd>
                  <button type="button"
                    onClick={() => router.navigate(`/sales/orders/${invoice.SalesOrders!.id}`)}
                    className="text-primary hover:underline font-medium">
                    {invoice.SalesOrders.sales_order_no}
                  </button>
                </dd>
              </div>
            )}
            {invoice.notes && (
              <div className="border-t pt-2">
                <dt className="text-gray-500 text-xs mb-0.5">Notes</dt>
                <dd className="text-gray-700 text-xs">{invoice.notes}</dd>
              </div>
            )}
          </dl>
        </div>
      </div>

      {activeTab === 'lines' && (
        <div className="space-y-4">
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">#</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Description</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Unit Price</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
              </tr>
            </thead>
            <tbody>
              {lines.length === 0 ? (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No lines</td></tr>
              ) : (
                lines.map((l, idx) => (
                  <tr key={l.id} className="border-t hover:bg-gray-50">
                    <td className="px-4 py-4 text-gray-500 tabular-nums">{idx + 1}</td>
                    <td className="px-4 py-4 text-gray-900">{l.description}</td>
                    <td className="px-4 py-4 text-right tabular-nums">{l.qty}</td>
                    <td className="px-4 py-4 text-right font-mono">{fmt(l.unit_price, currency)}</td>
                    <td className="px-4 py-4 text-right font-mono font-medium">{fmt(l.line_subtotal, currency)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        <div className="flex justify-end">
          <div className="w-full lg:w-[22rem] rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Summary</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-gray-500">Subtotal</dt>
                <dd className="font-mono text-gray-900">{fmt(invoice.subtotal, currency)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Tax</dt>
                <dd className="font-mono text-gray-900">{fmt(invoice.tax_total, currency)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Paid</dt>
                <dd className={`font-mono ${totalApplied > 0 ? 'text-green-600' : 'text-gray-500'}`}>
                  {fmt(totalApplied, currency)}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Balance Due</dt>
                <dd className={`font-mono font-semibold ${balanceDue > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {fmt(balanceDue, currency)}
                </dd>
              </div>
              <div className="flex justify-between border-t pt-2">
                <dt className="text-sm font-semibold text-gray-700">Total</dt>
                <dd className="font-mono font-bold text-gray-900">{fmt(invoice.total, currency)}</dd>
              </div>
            </dl>
          </div>
        </div>
        </div>
      )}

      {activeTab === 'payments' && (
        <div className="space-y-4">
          {balanceDue > 0 && (status === 'issued' || status === 'partial') && !applyFormOpen && (
            <div className="mb-4 flex justify-end">
              <button
                type="button"
                onClick={handleOpenApplyForm}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
              >
                <DollarSign className="w-4 h-4" />
                Apply Payment
              </button>
            </div>
          )}
          {status === 'draft' && (
            <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 p-3 text-center">
              <p className="text-xs text-amber-700">Issue this invoice first to apply payments.</p>
            </div>
          )}
          {applyFormOpen && (
            <div className="rounded-lg border border-gray-200 bg-white p-4 space-y-3">
              <h4 className="text-sm font-semibold text-gray-800">Apply Payment to Invoice</h4>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Select Payment</label>
                  <select
                    value={selectedPaymentId}
                    onChange={(e) => {
                      setSelectedPaymentId(e.target.value);
                      const pay = availablePayments.find((p) => p.id === e.target.value);
                      if (pay) setApplyAmount(String(Math.min(pay.unapplied, balanceDue).toFixed(2)));
                    }}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                  >
                    <option value="">-- Select --</option>
                    {availablePayments.map((p) => (
                      <option key={p.id} value={p.id}>
                        {new Date(p.payment_date).toLocaleDateString()} - {p.payment_method} - {fmt(p.unapplied, currency)} available
                        {p.reference_number ? ` (${p.reference_number})` : ''}
                      </option>
                    ))}
                  </select>
                  {availablePayments.length === 0 && (
                    <p className="text-xs text-amber-600 mt-1">No payments with available balance for this dealer.</p>
                  )}
                </div>
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Amount</label>
                  <input
                    type="number"
                    min={0.01}
                    step={0.01}
                    value={applyAmount}
                    onChange={(e) => setApplyAmount(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>
                <div className="flex items-end gap-2">
                  <button
                    type="button"
                    onClick={handleApplyPayment}
                    disabled={applying || !selectedPaymentId || !applyAmount}
                    className="flex-1 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
                  >
                    {applying ? 'Applying...' : 'Apply'}
                  </button>
                  <button
                    type="button"
                    onClick={() => { setApplyFormOpen(false); setSelectedPaymentId(''); setApplyAmount(''); }}
                    className="px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          )}
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Method</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Reference</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Recorded By</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700">Applied</th>
                </tr>
              </thead>
              <tbody>
                {applications.length === 0 ? (
                  <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No payments applied</td></tr>
                ) : (
                  applications.map((a) => (
                    <tr
                      key={a.id}
                      className="border-t hover:bg-gray-50 cursor-pointer"
                      onClick={() => router.navigate(`/financials/payments/${a.payment_id}`)}
                    >
                      <td className="px-4 py-4">{a.Payments?.payment_date ? new Date(a.Payments.payment_date).toLocaleDateString() : '—'}</td>
                      <td className="px-4 py-4 capitalize">{a.Payments?.method ?? '—'}</td>
                      <td className="px-4 py-4 text-gray-500">{a.Payments?.reference ?? '—'}</td>
                      <td className="px-4 py-4 text-gray-500">{a.Payments?.recorded_by_name ?? '—'}</td>
                      <td className="px-4 py-4 text-right font-mono font-medium text-green-700">{fmt(a.applied_amount, currency)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <div className="flex justify-end">
            <div className="w-full lg:w-[22rem] rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Summary</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Subtotal</dt>
                  <dd className="font-mono text-gray-900">{fmt(invoice.subtotal, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Tax</dt>
                  <dd className="font-mono text-gray-900">{fmt(invoice.tax_total, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Paid</dt>
                  <dd className={`font-mono ${totalApplied > 0 ? 'text-green-600' : 'text-gray-500'}`}>
                    {fmt(totalApplied, currency)}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Balance Due</dt>
                  <dd className={`font-mono font-semibold ${balanceDue > 0 ? 'text-red-600' : 'text-green-600'}`}>
                    {fmt(balanceDue, currency)}
                  </dd>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-sm font-semibold text-gray-700">Total</dt>
                  <dd className="font-mono font-bold text-gray-900">{fmt(invoice.total, currency)}</dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      )}
    </DetailPageLayout>
  );
}
