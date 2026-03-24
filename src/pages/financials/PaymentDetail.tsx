import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useUIStore } from '../../stores/ui-store';
import { useAuth } from '../../hooks/useAuth';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { getSupabaseErrorMessageDetailed } from '../../lib/supabase-error-utils';
import { formatDate } from '../../lib/utils';
import { getAppUsersDisplayNames } from '../../lib/appUsersDisplayNames';
import { useGranularAccess } from '../../hooks/usePermissions';
import { FINANCIAL_GROUP_TABS, getVisiblePortalFinancialSubTabs } from './financialSubmodules';
import { useAccessContext } from '../../hooks/useAccessContext';
import { usePermissions } from '../../hooks/usePermissions';
import { getFinancialBasePath, isMyFinancialsPath } from './myFinancialsRoute';

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
  recorded_by: string | null;
  recorded_by_name: string | null;
  status: string;
  dealer_id: string | null;
  sales_order_id: string | null;
  created_at: string;
  bank_name?: string | null;
  description?: string | null;
  void_reason?: string | null;
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

interface AvailableInvoiceOption {
  id: string;
  invoice_number: string;
  issue_date: string;
  total: number;
  status: string;
  sales_order_id: string | null;
  sales_order_no: string | null;
  applied_amount: number;
  balance_due: number;
}

function getErrorMessage(err: unknown): string {
  if (err && typeof err === 'object' && 'message' in err && typeof (err as { message: unknown }).message === 'string') {
    return (err as { message: string }).message;
  }
  if (err instanceof Error) return err.message;
  return 'Failed to load payment';
}

function getPaymentId(): string | null {
  const match = window.location.pathname.match(/\/(?:financials|my-financials)\/payments\/([^/]+)/);
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
  const { isInternal, isPortal, portalRole } = useAccessContext();
  const { can } = usePermissions();
  const pathname = window.location.pathname;
  const myFinancialsMode = isMyFinancialsPath(pathname);
  const viewerMode = isPortal || myFinancialsMode;
  const basePath = getFinancialBasePath(pathname);

  const addNotification = useUIStore((s) => s.addNotification);
  const { user } = useAuth();
  const { canVoid: canVoidFin } = useGranularAccess('financials');

  const [payment, setPayment] = useState<PaymentHeader | null>(null);
  const [applications, setApplications] = useState<InvoiceApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('invoices');
  const [dealersList, setDealersList] = useState<{ id: string; dealer_name: string; dealer_no: string | null }[]>([]);
  const [assignDealerId, setAssignDealerId] = useState('');
  const [assigning, setAssigning] = useState(false);
  const [applyFormOpen, setApplyFormOpen] = useState(false);
  const [availableInvoices, setAvailableInvoices] = useState<AvailableInvoiceOption[]>([]);
  const [loadingAvailableInvoices, setLoadingAvailableInvoices] = useState(false);
  const [selectedInvoiceId, setSelectedInvoiceId] = useState('');
  const [applyAmount, setApplyAmount] = useState('');
  const [applying, setApplying] = useState(false);
  const [voidDialogOpen, setVoidDialogOpen] = useState(false);
  const [voidReason, setVoidReason] = useState('');
  const [voidingPayment, setVoidingPayment] = useState(false);
  const [unapplyTarget, setUnapplyTarget] = useState<InvoiceApplication | null>(null);
  const listPath = `${basePath}/payments`;
  const queryReturnTo = getReturnToFromCurrentQuery();
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack =
    !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);
  const onBack = useCallback(() => {
    router.navigate(listPath);
  }, [listPath]);
  const onBackContextual = useCallback(() => {
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });
  }, [queryReturnTo, listPath]);

  useEffect(() => {
    if (viewerMode) {
      const portalTabs = getVisiblePortalFinancialSubTabs(can, portalRole, basePath);
      registerSubmodules('My Financials', portalTabs.map((tab) => ({ id: tab.id, label: tab.label, href: tab.href })));
      return;
    }
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules, viewerMode, can, portalRole, basePath]);

  const fmt = (v: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(v);

  const refetch = useCallback(async () => {
    if (!paymentId || !activeOrganizationId) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const baseSelect = 'id, amount, payment_method, reference_number, payment_date, notes, recorded_by, recorded_by_name, dealer_id, sales_order_id, created_at, status, void_reason';
      const extendedSelect = `${baseSelect}, bank_name, description`;

      let pay: PaymentHeader;
      const primary = await supabase
        .from('Payments')
        .select(extendedSelect)
        .eq('id', paymentId)
        .eq('organization_id', activeOrganizationId)
        .single();

      if (!primary.error) {
        pay = primary.data as PaymentHeader;
      } else {
        const msg = getErrorMessage(primary.error).toLowerCase();
        const isMissingOptionalColumn =
          msg.includes('column') && (msg.includes('bank_name') || msg.includes('description') || msg.includes('void_reason'));
        if (!isMissingOptionalColumn) throw primary.error;

        const fallback = await supabase
          .from('Payments')
          .select('id, amount, payment_method, reference_number, payment_date, notes, recorded_by, recorded_by_name, dealer_id, sales_order_id, created_at, status, void_reason')
          .eq('id', paymentId)
          .eq('organization_id', activeOrganizationId)
          .single();
        if (fallback.error) throw fallback.error;
        pay = { ...(fallback.data as PaymentHeader), bank_name: null, description: null };
      }

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
      // If payment is void, preserve that status; otherwise derive from applications
      if (pay.status !== 'void') {
        const totalApplied = (appsRes.data ?? []).reduce((s: number, a: any) => s + Number(a.applied_amount), 0);
        if (totalApplied >= pay.amount) pay.status = 'applied';
        else if (totalApplied > 0) pay.status = 'partial';
        else pay.status = 'unapplied';
      }
      if (pay.recorded_by) {
        const nameMap = await getAppUsersDisplayNames([pay.recorded_by]);
        const resolved = nameMap.get(pay.recorded_by);
        if (resolved && resolved !== 'Legacy / Imported') pay.recorded_by_name = resolved;
      }
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
      setError(getErrorMessage(e));
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
    if (!isInternal) return;
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

  const loadAvailableInvoices = useCallback(async () => {
    if (!activeOrganizationId || !payment?.dealer_id) {
      setAvailableInvoices([]);
      return;
    }
    setLoadingAvailableInvoices(true);
    try {
      const { data: invoicesData, error: invoicesErr } = await supabase
        .from('DealerInvoices')
        .select('id, invoice_number, issue_date, total, status, sales_order_id')
        .eq('organization_id', activeOrganizationId)
        .eq('dealer_id', payment.dealer_id)
        .eq('deleted', false)
        .order('issue_date', { ascending: false });
      if (invoicesErr) throw invoicesErr;

      const invoiceRows = (invoicesData ?? []) as Array<{
        id: string;
        invoice_number: string;
        issue_date: string;
        total: number;
        status: string;
        sales_order_id: string | null;
      }>;
      if (invoiceRows.length === 0) {
        setAvailableInvoices([]);
        return;
      }

      const invoiceIds = invoiceRows.map((row) => row.id);
      const soIds = [...new Set(invoiceRows.map((row) => row.sales_order_id).filter(Boolean))] as string[];

      const [appsRes, salesOrdersRes] = await Promise.all([
        supabase
          .from('PaymentApplications')
          .select('invoice_id, applied_amount')
          .in('invoice_id', invoiceIds),
        soIds.length > 0
          ? supabase
              .from('SalesOrders')
              .select('id, sales_order_no')
              .in('id', soIds)
          : Promise.resolve({ data: [] as Array<{ id: string; sales_order_no: string }>, error: null }),
      ]);

      if (appsRes.error) throw appsRes.error;
      if (salesOrdersRes.error) throw salesOrdersRes.error;

      const appliedByInvoiceId = new Map<string, number>();
      ((appsRes.data ?? []) as Array<{ invoice_id: string; applied_amount: number | null }>).forEach((app) => {
        const current = appliedByInvoiceId.get(app.invoice_id) ?? 0;
        appliedByInvoiceId.set(app.invoice_id, current + Number(app.applied_amount ?? 0));
      });

      const soNumberById = new Map<string, string>(
        ((salesOrdersRes.data ?? []) as Array<{ id: string; sales_order_no: string }>).map((so) => [so.id, so.sales_order_no])
      );

      const options = invoiceRows
        .map((row) => {
          const appliedAmount = appliedByInvoiceId.get(row.id) ?? 0;
          const balanceDue = Math.max(0, Number(row.total ?? 0) - appliedAmount);
          return {
            id: row.id,
            invoice_number: row.invoice_number,
            issue_date: row.issue_date,
            total: Number(row.total ?? 0),
            status: row.status,
            sales_order_id: row.sales_order_id,
            sales_order_no: row.sales_order_id ? soNumberById.get(row.sales_order_id) ?? null : null,
            applied_amount: appliedAmount,
            balance_due: balanceDue,
          } satisfies AvailableInvoiceOption;
        })
        .filter((row) => row.status !== 'void' && row.balance_due > 0.005);

      setAvailableInvoices(options);
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getErrorMessage(e) });
      setAvailableInvoices([]);
    } finally {
      setLoadingAvailableInvoices(false);
    }
  }, [activeOrganizationId, payment?.dealer_id, addNotification]);

  const handleOpenApplyForm = async () => {
    if (!isInternal) return;
    if (!payment?.dealer_id) {
      addNotification({ type: 'error', title: 'Dealer required', message: 'Assign a dealer before applying this payment.' });
      return;
    }
    setApplyFormOpen(true);
    setSelectedInvoiceId('');
    setApplyAmount('');
    await loadAvailableInvoices();
  };

  const handleApplyToInvoice = async () => {
    if (!isInternal) return;
    if (!paymentId || !selectedInvoiceId || !applyAmount) return;
    const amount = Number(applyAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      addNotification({ type: 'error', title: 'Validation', message: 'Amount must be greater than 0.' });
      return;
    }

    const selectedInvoice = availableInvoices.find((inv) => inv.id === selectedInvoiceId);
    if (!selectedInvoice) {
      addNotification({ type: 'error', title: 'Validation', message: 'Select a valid invoice.' });
      return;
    }

    const maxAssignable = Math.max(0, Math.min(unapplied, selectedInvoice.balance_due));
    if (amount > maxAssignable + 0.0001) {
      addNotification({
        type: 'error',
        title: 'Validation',
        message: `Amount exceeds available balance (${fmt(maxAssignable)}).`,
      });
      return;
    }

    setApplying(true);
    try {
      const { error: applyErr } = await supabase.rpc('apply_payment', {
        p_payment_id: paymentId,
        p_invoice_id: selectedInvoiceId,
        p_amount: amount,
      });
      if (applyErr) throw applyErr;

      addNotification({
        type: 'success',
        title: 'Payment Applied',
        message: `${fmt(amount)} applied to invoice ${selectedInvoice.invoice_number}.`,
      });
      setApplyFormOpen(false);
      setSelectedInvoiceId('');
      setApplyAmount('');
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getErrorMessage(e) });
    } finally {
      setApplying(false);
    }
  };

  const confirmUnapply = async () => {
    if (!isInternal) return;
    if (!unapplyTarget || !paymentId || !activeOrganizationId) return;
    try {
      const { error: delErr } = await supabase
        .from('PaymentApplications')
        .delete()
        .eq('id', unapplyTarget.id);
      if (delErr) throw delErr;

      await supabase.from('FinancialAuditLog').insert({
        organization_id: activeOrganizationId,
        action: 'unapply_payment',
        entity_type: 'payment',
        entity_id: paymentId,
        related_entity_type: 'invoice',
        related_entity_id: unapplyTarget.invoice_id,
        amount: unapplyTarget.applied_amount,
        performed_by: user?.id ?? null,
        performed_by_name: user?.name ?? user?.email ?? null,
      });

      setUnapplyTarget(null);
      addNotification({ type: 'success', title: 'Unapplied', message: 'Application removed successfully.' });
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    }
  };

  const handleVoidPayment = async () => {
    if (!isInternal) return;
    if (!paymentId || !payment) return;
    if (voidReason.trim().length < 3) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please provide a void reason.' });
      return;
    }
    if (totalApplied > 0.005) {
      addNotification({
        type: 'error',
        title: 'Validation',
        message: 'Payment has applied amounts. Unapply all applications before voiding.',
      });
      return;
    }
    setVoidingPayment(true);
    try {
      const now = new Date().toISOString();
      const { error: updErr } = await supabase
        .from('Payments')
        .update({
          status: 'void',
          void_reason: voidReason.trim(),
          voided_by: user?.id ?? null,
          voided_at: now,
          updated_at: now,
        })
        .eq('id', paymentId);
      if (updErr) throw updErr;

      if (activeOrganizationId) {
        await supabase.from('FinancialAuditLog').insert({
          organization_id: activeOrganizationId,
          action: 'void_payment',
          entity_type: 'payment',
          entity_id: paymentId,
          amount: payment.amount,
          reason: voidReason.trim(),
          performed_by: user?.id ?? null,
          performed_by_name: user?.name ?? user?.email ?? null,
        });
      }

      setVoidDialogOpen(false);
      setVoidReason('');
      addNotification({ type: 'success', title: 'Payment Voided', message: 'Payment has been voided and remains on record.' });
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    } finally {
      setVoidingPayment(false);
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
        <button onClick={onBack}
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
      onBack={onBack}
      contentClassName="pt-2 pb-6"
      actions={(
        <div className="flex items-center gap-2">
          {hasRedirectBack && (
            <button
              type="button"
              onClick={onBackContextual}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
              title="Back"
            >
              Back
            </button>
          )}
          {isInternal && payment.status !== 'void' && unapplied >= payment.amount - 0.005 && canVoidFin && (
            <button
              type="button"
              onClick={() => setVoidDialogOpen(true)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-red-700 bg-white border border-red-300 rounded-lg hover:bg-red-50"
            >
              Void Payment
            </button>
          )}
        </div>
      )}
    >
      {/* Void banner */}
      {payment.status === 'void' && (() => {
        const reason = payment.void_reason
          || (payment.notes?.match(/VOID REASON:\s*(.+)/)?.[1]?.trim())
          || null;
        return (
          <div className="mb-4 rounded-lg border border-red-300 bg-red-50 p-4">
            <p className="text-sm font-semibold text-red-800">This payment has been voided</p>
            {reason && (
              <p className="mt-1 text-sm text-red-700">Reason: {reason}</p>
            )}
          </div>
        );
      })()}

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
              <dd className="text-gray-900">{formatDate(payment.payment_date)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Recorded By</dt>
              <dd className="text-gray-900">{payment.recorded_by_name ?? '—'}</dd>
            </div>
            {payment.bank_name && (
              <div className="flex justify-between">
                <dt className="text-gray-500">Bank Name</dt>
                <dd className="text-gray-900">{payment.bank_name}</dd>
              </div>
            )}
            {payment.description && (
              <div className="flex justify-between">
                <dt className="text-gray-500">Description</dt>
                <dd className="text-gray-900">{payment.description}</dd>
              </div>
            )}
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
                    onClick={() => router.navigate(withReturnTo(`/sales/orders/${payment.SalesOrder!.id}`))}
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
          ) : isInternal ? (
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
          ) : (
            <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-xs text-gray-600">
              Dealer information is unavailable for this payment.
            </div>
          )}
        </div>
      </div>

      {activeTab === 'invoices' && (
        <div className="space-y-4">
          {isInternal && unapplied > 0.005 && payment.dealer_id && payment.status !== 'void' && !applyFormOpen && (
            <div className="flex justify-end">
              <button
                type="button"
                onClick={() => { void handleOpenApplyForm(); }}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
              >
                Apply to Invoice
              </button>
            </div>
          )}
          {isInternal && applyFormOpen && (
            <div className="rounded-lg border border-gray-200 bg-white p-4 space-y-3">
              <h4 className="text-sm font-semibold text-gray-800">Apply Payment to Dealer Invoice</h4>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Invoice</label>
                  <select
                    value={selectedInvoiceId}
                    onChange={(e) => {
                      setSelectedInvoiceId(e.target.value);
                      const inv = availableInvoices.find((row) => row.id === e.target.value);
                      if (inv) setApplyAmount(String(Math.min(unapplied, inv.balance_due).toFixed(2)));
                    }}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                  >
                    <option value="">-- Select --</option>
                    {availableInvoices.map((inv) => (
                      <option key={inv.id} value={inv.id}>
                        {inv.invoice_number}
                        {inv.sales_order_no ? ` (${inv.sales_order_no})` : ''}
                        {` - Balance ${fmt(inv.balance_due)}`}
                      </option>
                    ))}
                  </select>
                  {!loadingAvailableInvoices && availableInvoices.length === 0 && (
                    <p className="text-xs text-amber-600 mt-1">No open invoices with balance for this dealer.</p>
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
                    onClick={() => { void handleApplyToInvoice(); }}
                    disabled={applying || !selectedInvoiceId || !applyAmount}
                    className="flex-1 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
                  >
                    {applying ? 'Applying...' : 'Apply'}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setApplyFormOpen(false);
                      setSelectedInvoiceId('');
                      setApplyAmount('');
                    }}
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
                <th className="px-4 py-3 text-left font-medium text-gray-700">Invoice #</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Invoice Total</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Applied</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Invoice Status</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody>
              {applications.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-500">No invoices linked to this payment</td></tr>
              ) : (
                applications.map((a) => (
                  <tr
                    key={a.id}
                    className="border-t hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(`${basePath}/invoices/${a.invoice_id}`)}
                  >
                    <td className="px-4 py-4 font-medium text-primary">{a.Invoice?.invoice_number ?? '—'}</td>
                    <td className="px-4 py-4 text-right font-mono text-gray-900">{a.Invoice ? fmt(a.Invoice.total) : '—'}</td>
                    <td className="px-4 py-4 text-right font-mono font-medium text-green-700">{fmt(a.applied_amount)}</td>
                    <td className="px-4 py-4 text-center">
                      {a.Invoice ? <StatusBadge status={a.Invoice.status} type="invoice" size="sm" /> : '—'}
                    </td>
                    <td className="px-4 py-4 text-gray-500">{formatDate(a.created_at)}</td>
                    <td className="px-4 py-4 text-right">
                      {isInternal && payment.status !== 'void' && (
                        <button
                          type="button"
                          onClick={(e) => { e.stopPropagation(); setUnapplyTarget(a); }}
                          className="px-2 py-1 text-xs font-medium text-red-700 border border-red-200 rounded hover:bg-red-50"
                        >
                          Unapply
                        </button>
                      )}
                    </td>
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
                  <td colSpan={3} />
                </tr>
              </tfoot>
            )}
            </table>
          </div>
        </div>
      )}

      {isInternal && voidDialogOpen && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Void Payment</h4>
            <p className="text-xs text-gray-600 mb-3">
              This operation preserves audit trail. Payment must be fully unapplied first.
            </p>
            <textarea
              value={voidReason}
              onChange={(e) => setVoidReason(e.target.value)}
              placeholder="Reason for void..."
              rows={3}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
            />
            <div className="flex justify-end gap-2 mt-3">
              <button
                type="button"
                onClick={() => { setVoidDialogOpen(false); setVoidReason(''); }}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => { void handleVoidPayment(); }}
                disabled={voidingPayment}
                className="px-3 py-1.5 text-sm text-white bg-red-600 rounded-lg disabled:opacity-50"
              >
                {voidingPayment ? 'Voiding...' : 'Void Payment'}
              </button>
            </div>
          </div>
        </div>
      )}

      {isInternal && unapplyTarget && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Unapply Payment</h4>
            <p className="text-sm text-gray-600 mb-3">
              Remove <span className="font-semibold">{fmt(unapplyTarget.applied_amount)}</span> from invoice{' '}
              <span className="font-semibold">{unapplyTarget.Invoice?.invoice_number ?? '—'}</span>?
            </p>
            <p className="text-xs text-gray-500 mb-3">
              The payment will return to unapplied status and can be re-applied to another invoice.
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setUnapplyTarget(null)}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => { void confirmUnapply(); }}
                className="px-3 py-1.5 text-sm text-white bg-red-600 rounded-lg"
              >
                Confirm Unapply
              </button>
            </div>
          </div>
        </div>
      )}
    </DetailPageLayout>
  );
}
