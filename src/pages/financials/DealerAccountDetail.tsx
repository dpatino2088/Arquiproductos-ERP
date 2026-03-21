import { useCallback, useEffect, useMemo, useState } from 'react';
import { ArrowLeft, FileDown } from 'lucide-react';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useDealerFinancialDetail } from '../../hooks/useDealerFinancialDetail';
import { useDealerFinancialTimeline } from '../../hooks/useDealerFinancialTimeline';
import { supabase } from '../../lib/supabase/client';
import { formatCurrency, formatDate } from '../../lib/utils';
import TimelineView from '../../components/shared/TimelineView';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { generateAccountStatementPDF } from '../../lib/pdf/generateAccountStatementPDF';
import type {
  StatementPDFDealer,
  StatementPDFSummary,
  StatementPDFLine,
  GenerateStatementPDFOptions,
} from '../../lib/pdf/generateAccountStatementPDF';
import type { DealerFinancialTimelineEvent } from '../../hooks/useDealerFinancialTimeline';
import { useUIStore } from '../../stores/ui-store';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

interface DealerInvoiceRow {
  invoice_id: string;
  invoice_number: string;
  invoice_status: string;
  issue_date: string;
  due_date: string | null;
  invoice_total: number;
  applied_total: number;
  balance_due: number;
}

interface DealerPaymentRow {
  id: string;
  payment_date: string;
  amount: number;
  payment_method: string | null;
  reference_number: string | null;
}

interface DealerApplicationRow {
  id: string;
  created_at: string;
  payment_id: string;
  invoice_id: string;
  applied_amount: number;
}

interface DealerBillingRow {
  billing_same_as_location?: boolean | null;
  street_address_line_1?: string | null;
  street_address_line_2?: string | null;
  city?: string | null;
  state?: string | null;
  zip_code?: string | null;
  country?: string | null;
  billing_street_address_line_1?: string | null;
  billing_street_address_line_2?: string | null;
  billing_city?: string | null;
  billing_state?: string | null;
  billing_zip_code?: string | null;
  billing_country?: string | null;
  identification_number?: string | null;
}

function formatBillingAddress(d: DealerBillingRow): string {
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

function getDealerIdFromPath(): string | null {
  const match = window.location.pathname.match(/\/financials\/accounts\/([^/]+)/);
  return match ? match[1] : null;
}

export default function DealerAccountDetail() {
  const dealerId = getDealerIdFromPath();
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const [activeTab, setActiveTab] = useState('overview');
  const [invoices, setInvoices] = useState<DealerInvoiceRow[]>([]);
  const [payments, setPayments] = useState<DealerPaymentRow[]>([]);
  const [applications, setApplications] = useState<DealerApplicationRow[]>([]);
  const [loadingRows, setLoadingRows] = useState(true);
  const [rowsError, setRowsError] = useState<string | null>(null);
  const [statementPdfLoading, setStatementPdfLoading] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const listPath = '/financials/accounts';
  const queryReturnTo = getReturnToFromCurrentQuery();
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack = !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const { detail, isInitialLoading, error: detailError } = useDealerFinancialDetail(dealerId);
  const { events, isInitialLoading: timelineLoading } = useDealerFinancialTimeline(dealerId);

  const loadRows = useCallback(async () => {
    if (!activeOrganizationId || !dealerId) {
      setLoadingRows(false);
      return;
    }
    setLoadingRows(true);
    setRowsError(null);
    try {
      const [{ data: invRows, error: invErr }, { data: payRows, error: payErr }] = await Promise.all([
        supabase
          .from('dealer_invoice_balances_v1')
          .select('invoice_id, invoice_number, invoice_status, issue_date, due_date, invoice_total, applied_total, balance_due')
          .eq('organization_id', activeOrganizationId)
          .eq('dealer_id', dealerId)
          .order('issue_date', { ascending: false }),
        supabase
          .from('Payments')
          .select('id, payment_date, amount, payment_method, reference_number')
          .eq('organization_id', activeOrganizationId)
          .eq('dealer_id', dealerId)
          .eq('deleted', false)
          .order('payment_date', { ascending: false }),
      ]);

      if (invErr) throw invErr;
      if (payErr) throw payErr;

      const invoiceRows = ((invRows ?? []) as Array<Record<string, unknown>>).map((row) => ({
        invoice_id: String(row.invoice_id),
        invoice_number: String(row.invoice_number ?? ''),
        invoice_status: String(row.invoice_status ?? ''),
        issue_date: String(row.issue_date ?? ''),
        due_date: row.due_date ? String(row.due_date) : null,
        invoice_total: Number(row.invoice_total ?? 0),
        applied_total: Number(row.applied_total ?? 0),
        balance_due: Number(row.balance_due ?? 0),
      }));
      setInvoices(invoiceRows);

      const paymentRows = ((payRows ?? []) as Array<Record<string, unknown>>).map((row) => ({
        id: String(row.id),
        payment_date: String(row.payment_date ?? ''),
        amount: Number(row.amount ?? 0),
        payment_method: row.payment_method ? String(row.payment_method) : null,
        reference_number: row.reference_number ? String(row.reference_number) : null,
      }));
      setPayments(paymentRows);

      const invoiceIds = invoiceRows.map((row) => row.invoice_id);
      if (invoiceIds.length === 0) {
        setApplications([]);
      } else {
        const { data: appRows, error: appErr } = await supabase
          .from('PaymentApplications')
          .select('id, created_at, payment_id, invoice_id, applied_amount')
          .in('invoice_id', invoiceIds)
          .order('created_at', { ascending: false });
        if (appErr) throw appErr;
        setApplications(((appRows ?? []) as Array<Record<string, unknown>>).map((row) => ({
          id: String(row.id),
          created_at: String(row.created_at ?? ''),
          payment_id: String(row.payment_id ?? ''),
          invoice_id: String(row.invoice_id ?? ''),
          applied_amount: Number(row.applied_amount ?? 0),
        })));
      }
    } catch (error: unknown) {
      setRowsError(error instanceof Error ? error.message : 'Failed to load dealer movements');
    } finally {
      setLoadingRows(false);
    }
  }, [activeOrganizationId, dealerId]);

  useEffect(() => {
    void loadRows();
  }, [loadRows]);

  const onBack = () => router.navigate(listPath);
  const onBackContextual = () =>
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });

  const applicationMap = useMemo(() => {
    const invoiceById = new Map(invoices.map((inv) => [inv.invoice_id, inv]));
    const paymentById = new Map(payments.map((pay) => [pay.id, pay]));
    return applications.map((app) => ({
      ...app,
      invoice_number: invoiceById.get(app.invoice_id)?.invoice_number ?? '—',
      payment_reference: paymentById.get(app.payment_id)?.reference_number ?? paymentById.get(app.payment_id)?.id ?? '—',
    }));
  }, [applications, invoices, payments]);

  const loadOrganizationLogoOptions = useCallback(async (): Promise<GenerateStatementPDFOptions> => {
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
    const logoPaths = ['/images/Arquiproductos.png', '/images/arquiproductos.png', '/images/Arquiproductos.jpg', '/images/arquiproductos.jpg'];
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
    return { organizationName, logoPngBase64, logoWidthPx, logoHeightPx };
  }, [activeOrganizationId]);

  const mapTimelineToStatementLines = useCallback((evs: DealerFinancialTimelineEvent[]): StatementPDFLine[] => {
    const sorted = [...evs].sort((a, b) => new Date(a.event_at).getTime() - new Date(b.event_at).getTime());
    const limit = 200;
    return sorted.slice(0, limit).map((e) => {
      let type = 'Other';
      let debit = 0;
      let credit = 0;
      if (e.entity_type === 'sales_order') {
        type = 'Order';
      } else if (e.entity_type === 'invoice') {
        type = 'Invoice';
        debit = e.amount;
      } else if (e.entity_type === 'payment') {
        type = 'Payment';
        credit = e.amount;
      } else if (e.entity_type === 'credit_note') {
        type = 'Credit note';
        credit = e.amount;
      } else if (e.entity_type === 'payment_application') {
        type = 'Payment applied';
        credit = e.amount;
      }
      return {
        date: e.event_at,
        type,
        reference_no: e.reference_no ?? '—',
        debit,
        credit,
      };
    });
  }, []);

  const buildStatementPDFDoc = useCallback(async () => {
    if (!detail || !dealerId || !activeOrganizationId) return null;
    const { data: dealerRow } = await supabase
      .from('Dealers')
      .select('dealer_name, dealer_no, dealer_email, dealer_phone, identification_number, billing_same_as_location, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country')
      .eq('organization_id', activeOrganizationId)
      .eq('id', dealerId)
      .eq('deleted', false)
      .maybeSingle();
    const billingRow = dealerRow as DealerBillingRow | null;
    const pdfDealer: StatementPDFDealer | null = dealerRow
      ? {
          dealer_name: (dealerRow as { dealer_name?: string }).dealer_name ?? detail.dealer_name,
          dealer_no: (dealerRow as { dealer_no?: string | null }).dealer_no ?? detail.dealer_no,
          identification_number: billingRow?.identification_number ?? null,
          billing_address: billingRow ? formatBillingAddress(billingRow) : '—',
          email: (dealerRow as { dealer_email?: string | null }).dealer_email ?? detail.dealer_email,
          phone: (dealerRow as { dealer_phone?: string | null }).dealer_phone ?? detail.dealer_phone,
        }
      : {
          dealer_name: detail.dealer_name,
          dealer_no: detail.dealer_no,
          identification_number: null,
          billing_address: '—',
          email: detail.dealer_email,
          phone: detail.dealer_phone,
        };
    const summary: StatementPDFSummary = {
      total_invoiced_lifetime: detail.total_invoiced_lifetime,
      total_paid_lifetime: detail.total_paid_lifetime,
      open_ar: detail.open_ar,
      past_due_amount: detail.past_due_amount,
      aging_current: detail.aging_current,
      aging_1_30: detail.aging_1_30,
      aging_31_60: detail.aging_31_60,
      aging_61_90: detail.aging_61_90,
      aging_90_plus: detail.aging_90_plus,
      currency_code: 'USD',
    };
    const lines = mapTimelineToStatementLines(events);
    const statementDate = new Date().toISOString().split('T')[0];
    const logoOptions = await loadOrganizationLogoOptions();
    return generateAccountStatementPDF(pdfDealer, statementDate, summary, lines, logoOptions);
  }, [detail, dealerId, activeOrganizationId, events, mapTimelineToStatementLines, loadOrganizationLogoOptions]);

  const handlePreviewStatementPDF = useCallback(async () => {
    setStatementPdfLoading(true);
    try {
      const doc = await buildStatementPDFDoc();
      if (!doc) return;
      const blob = doc.output('blob');
      const url = URL.createObjectURL(blob);
      window.open(url, '_blank');
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Statement PDF',
        message: err instanceof Error ? err.message : 'Failed to generate statement PDF.',
      });
    } finally {
      setStatementPdfLoading(false);
    }
  }, [buildStatementPDFDoc, addNotification]);

  const handleDownloadStatementPDF = useCallback(async () => {
    setStatementPdfLoading(true);
    try {
      const doc = await buildStatementPDFDoc();
      if (!doc || !detail) return;
      const safeName = (detail.dealer_name ?? 'Dealer').replace(/[^a-zA-Z0-9-_]/g, '_');
      const dateStr = new Date().toISOString().split('T')[0];
      doc.save(`AccountStatement_${safeName}_${dateStr}.pdf`);
      addNotification({ type: 'success', title: 'Statement PDF', message: 'Download started.' });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Statement PDF',
        message: err instanceof Error ? err.message : 'Failed to generate statement PDF.',
      });
    } finally {
      setStatementPdfLoading(false);
    }
  }, [buildStatementPDFDoc, detail, addNotification]);

  if (!dealerId) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-sm text-red-700">Invalid dealer route.</div>
      </div>
    );
  }

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'invoices', label: `Invoices (${invoices.length})` },
    { id: 'payments', label: `Payments (${payments.length})` },
    { id: 'applications', label: `Applications (${applications.length})` },
    { id: 'timeline', label: 'Timeline' },
  ];

  return (
    <DetailPageLayout
      title={detail?.dealer_name ?? 'Dealer Account'}
      subtitle={detail?.dealer_no ? `Dealer #${detail.dealer_no}` : 'Financial account detail'}
      status={null}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
      actions={
        <div className="inline-flex items-center gap-2">
          {hasRedirectBack && (
            <button
              type="button"
              onClick={onBackContextual}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              <ArrowLeft className="w-4 h-4" />
              Back
            </button>
          )}
          <button
            type="button"
            onClick={handlePreviewStatementPDF}
            disabled={statementPdfLoading || !detail}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
            title="Open statement PDF in new tab"
          >
            <FileDown className="w-4 h-4" />
            {statementPdfLoading ? 'Generating…' : 'Preview PDF'}
          </button>
          <button
            type="button"
            onClick={handleDownloadStatementPDF}
            disabled={statementPdfLoading || !detail}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary border border-primary rounded-lg hover:opacity-90 disabled:opacity-50"
            title="Download account statement PDF"
          >
            <FileDown className="w-4 h-4" />
            {statementPdfLoading ? 'Generating…' : 'Download Statement (PDF)'}
          </button>
        </div>
      }
      contentClassName="pt-2 pb-6"
    >
      {(isInitialLoading || loadingRows) && (
        <div className="rounded-lg border border-gray-200 bg-white p-6 text-sm text-gray-500">Loading dealer account...</div>
      )}
      {(detailError || rowsError) && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {detailError || rowsError}
        </div>
      )}

      {activeTab === 'overview' && detail && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Dealer</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-gray-500">Name</dt><dd className="font-medium">{detail.dealer_name}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Dealer #</dt><dd>{detail.dealer_no ?? '—'}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Email</dt><dd>{detail.dealer_email ?? '—'}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Phone</dt><dd>{detail.dealer_phone ?? '—'}</dd></div>
            </dl>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">AR Summary</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-gray-500">Total Invoiced</dt><dd className="font-mono">{formatCurrency(detail.total_invoiced_lifetime, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Total Paid</dt><dd className="font-mono">{formatCurrency(detail.total_paid_lifetime, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Open AR</dt><dd className="font-mono">{formatCurrency(detail.open_ar, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Past Due</dt><dd className="font-mono">{formatCurrency(detail.past_due_amount, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Unapplied</dt><dd className="font-mono">{formatCurrency(detail.unapplied_amount, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Open Invoices</dt><dd>{detail.open_invoices_count}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Open SO</dt><dd>{detail.open_so_count}</dd></div>
            </dl>
          </div>
          <div className="md:col-span-2 rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Aging</h3>
            <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
              <div><p className="text-gray-500">Current</p><p className="font-mono">{formatCurrency(detail.aging_current, 'USD')}</p></div>
              <div><p className="text-gray-500">1-30</p><p className="font-mono">{formatCurrency(detail.aging_1_30, 'USD')}</p></div>
              <div><p className="text-gray-500">31-60</p><p className="font-mono">{formatCurrency(detail.aging_31_60, 'USD')}</p></div>
              <div><p className="text-gray-500">61-90</p><p className="font-mono">{formatCurrency(detail.aging_61_90, 'USD')}</p></div>
              <div><p className="text-gray-500">90+</p><p className="font-mono">{formatCurrency(detail.aging_90_plus, 'USD')}</p></div>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'invoices' && (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Invoice #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Issue Date</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Due Date</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Applied</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Balance</th>
              </tr>
            </thead>
            <tbody>
              {invoices.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-500">No invoices</td></tr>
              ) : invoices.map((inv) => (
                <tr key={inv.invoice_id} className="border-t hover:bg-gray-50 cursor-pointer" onClick={() => router.navigate(withReturnTo(`/financials/invoices/${inv.invoice_id}`))}>
                  <td className="px-4 py-4 font-medium text-primary">{inv.invoice_number}</td>
                  <td className="px-4 py-4">{formatDate(inv.issue_date)}</td>
                  <td className="px-4 py-4">{formatDate(inv.due_date)}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(inv.invoice_total, 'USD')}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(inv.applied_total, 'USD')}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(inv.balance_due, 'USD')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'payments' && (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Method</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Reference</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Amount</th>
              </tr>
            </thead>
            <tbody>
              {payments.length === 0 ? (
                <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-500">No payments</td></tr>
              ) : payments.map((pay) => (
                <tr key={pay.id} className="border-t hover:bg-gray-50 cursor-pointer" onClick={() => router.navigate(withReturnTo(`/financials/payments/${pay.id}`))}>
                  <td className="px-4 py-4">{formatDate(pay.payment_date)}</td>
                  <td className="px-4 py-4">{pay.payment_method ?? '—'}</td>
                  <td className="px-4 py-4">{pay.reference_number ?? '—'}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(pay.amount, 'USD')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'applications' && (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Invoice</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Payment Ref</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Applied</th>
              </tr>
            </thead>
            <tbody>
              {applicationMap.length === 0 ? (
                <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-500">No applications</td></tr>
              ) : applicationMap.map((app) => (
                <tr key={app.id} className="border-t hover:bg-gray-50">
                  <td className="px-4 py-4">{formatDate(app.created_at)}</td>
                  <td className="px-4 py-4">{app.invoice_number}</td>
                  <td className="px-4 py-4">{app.payment_reference}</td>
                  <td className="px-4 py-4 text-right font-mono">{formatCurrency(app.applied_amount, 'USD')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'timeline' && (
        <TimelineView
          events={events.map((event) => ({
            id: `${event.entity_type}-${event.entity_id}-${event.event_type}`,
            action: event.event_type,
            description: `${event.reference_no ?? 'Movement'} ${formatCurrency(event.amount, 'USD')}`,
            user_name: null,
            created_at: event.event_at,
            metadata: null,
          }))}
          loading={timelineLoading}
          emptyMessage="No timeline activity yet"
        />
      )}
    </DetailPageLayout>
  );
}
