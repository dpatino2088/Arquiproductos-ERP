import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ChevronDown, DollarSign, Lock, LockOpen } from 'lucide-react';
import { generateInvoicePDF } from '../../lib/pdf/generateInvoicePDF';
import type { InvoicePDFLine, InvoicePDFData, InvoicePDFDealer, GenerateInvoicePDFOptions } from '../../lib/pdf/generateInvoicePDF';
import { generateNextSequentialNumber } from '../../lib/sequential-numbers';
import { getSupabaseErrorMessageDetailed } from '../../lib/supabase-error-utils';
import { formatDate } from '../../lib/utils';
import { useAuth } from '../../hooks/useAuth';
import { useGranularAccess } from '../../hooks/usePermissions';
import { getAppUsersDisplayNames } from '../../lib/appUsersDisplayNames';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

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
  void_reason?: string | null;
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

interface CreditNote {
  id: string;
  credit_note_number: string;
  issue_date: string;
  amount: number;
  reason: string | null;
  status: string;
  created_at: string;
}

interface DeliveryGate {
  sales_order_id: string;
  balance_due: number;
  payment_complete: boolean;
  has_active_override: boolean;
  active_override_id: string | null;
  delivery_allowed: boolean;
}

interface ActiveDeliveryOverride {
  id: string;
  reason: string;
  authorized_by_name: string | null;
  authorized_at: string;
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
  const { activeOrganizationId, role } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);
  const { user } = useAuth();
  const { canDelete: canDeleteFin, canVoid: canVoidFin } = useGranularAccess('financials');

  const [invoice, setInvoice] = useState<InvoiceHeader | null>(null);
  const [lines, setLines] = useState<InvoiceLine[]>([]);
  const [linesFallbackFromSalesOrder, setLinesFallbackFromSalesOrder] = useState(false);
  const [applications, setApplications] = useState<PaymentApplication[]>([]);
  const [creditNotes, setCreditNotes] = useState<CreditNote[]>([]);
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
  const [voidDialogOpen, setVoidDialogOpen] = useState(false);
  const [voidReason, setVoidReason] = useState('');
  const [creditDialogOpen, setCreditDialogOpen] = useState(false);
  const [creditAmount, setCreditAmount] = useState('');
  const [creditReason, setCreditReason] = useState('');
  const [creatingCredit, setCreatingCredit] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [voidCreditTarget, setVoidCreditTarget] = useState<CreditNote | null>(null);
  const [voidCreditReason, setVoidCreditReason] = useState('');
  const [voidingCredit, setVoidingCredit] = useState(false);
  const [deliveryGate, setDeliveryGate] = useState<DeliveryGate | null>(null);
  const [activeDeliveryOverride, setActiveDeliveryOverride] = useState<ActiveDeliveryOverride | null>(null);
  const [deliveryOverrideReason, setDeliveryOverrideReason] = useState('');
  const [deliveryRevokeReason, setDeliveryRevokeReason] = useState('');
  const [authorizingDeliveryOverride, setAuthorizingDeliveryOverride] = useState(false);
  const [revokingDeliveryOverride, setRevokingDeliveryOverride] = useState(false);
  const [deliveryOverrideDialogOpen, setDeliveryOverrideDialogOpen] = useState(false);
  const [deliveryOverrideMode, setDeliveryOverrideMode] = useState<'authorize' | 'revoke'>('authorize');
  const hasAutoOpenedPdfRef = useRef(false);
  const listPath = '/financials/invoices';
  const queryReturnTo = getReturnToFromCurrentQuery();
  const queryParams = new URLSearchParams(window.location.search);
  const openPdfOnly = queryParams.get('pdf') === '1';
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack =
    !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);
  const canManageDeliveryOverride = role === 'admin' || role === 'superadmin';

  useEffect(() => { registerSubmodules('Financials', FINANCIAL_GROUP_TABS); }, [registerSubmodules]);

  const fmt = (v: number, currency = 'USD') =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);

  const handleBack = useCallback(() => {
    router.navigate(listPath);
  }, []);
  const handleBackContextual = useCallback(() => {
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });
  }, [queryReturnTo]);

  const refetch = useCallback(async () => {
    if (!invoiceId || !activeOrganizationId) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const [invRes, linesRes, appsRes, creditsRes] = await Promise.all([
        supabase
          .from('DealerInvoices')
          .select('id, invoice_number, status, issue_date, due_date, currency_code, subtotal, tax_total, total, notes, void_reason, sales_order_id, dealer_id, created_at')
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
        supabase
          .from('DealerCreditNotes')
          .select('id, credit_note_number, issue_date, amount, reason, status, created_at')
          .eq('invoice_id', invoiceId)
          .eq('deleted', false)
          .order('created_at', { ascending: false }),
      ]);
      if (invRes.error) throw invRes.error;
      if (creditsRes.error) throw creditsRes.error;
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
      const invoiceLines = (linesRes.data ?? []) as InvoiceLine[];
      if (invoiceLines.length > 0) {
        setLines(invoiceLines);
        setLinesFallbackFromSalesOrder(false);
      } else if (inv.sales_order_id) {
        const { data: saleOrderLines } = await supabase
          .from('SaleOrderLines')
          .select('id, line_number, description, quantity, unit_price, line_total')
          .eq('sales_order_id', inv.sales_order_id)
          .eq('deleted', false)
          .order('line_number', { ascending: true });

        const fallbackLines = ((saleOrderLines ?? []) as Array<{
          id: string;
          line_number: number | null;
          description: string | null;
          quantity: number | string | null;
          unit_price: number | string | null;
          line_total: number | string | null;
        }>).map((line, idx) => {
          const qty = Number(line.quantity ?? 0);
          const unitPrice = Number(line.unit_price ?? 0);
          const lineSubtotalRaw = Number(line.line_total ?? qty * unitPrice);
          return {
            id: `so-${line.id}-${idx}`,
            description: (line.description ?? '').trim() || 'Line item',
            qty: Number.isFinite(qty) ? qty : 0,
            unit_price: Number.isFinite(unitPrice) ? unitPrice : 0,
            line_subtotal: Number.isFinite(lineSubtotalRaw) ? lineSubtotalRaw : 0,
          } satisfies InvoiceLine;
        });

        setLines(fallbackLines);
        setLinesFallbackFromSalesOrder(fallbackLines.length > 0);
      } else {
        setLines([]);
        setLinesFallbackFromSalesOrder(false);
      }

      const apps = (appsRes.data ?? []) as PaymentApplication[];
      if (apps.length > 0) {
        const payIds = [...new Set(apps.map((a) => a.payment_id))];
        const { data: payData } = await supabase
          .from('Payments')
          .select('id, payment_date, payment_method, reference_number, recorded_by, recorded_by_name')
          .in('id', payIds);
        type PayRow = { id: string; payment_date: string; payment_method: string; reference_number: string | null; recorded_by: string | null; recorded_by_name: string | null };
        const payRows = (payData ?? []) as PayRow[];
        const recorderIds = payRows.map(p => p.recorded_by).filter(Boolean) as string[];
        const nameMap = await getAppUsersDisplayNames(recorderIds);
        const payMap = new Map<string, PayRow>(payRows.map((p) => [p.id, p]));
        setApplications(apps.map((a) => ({
          ...a,
          Payments: (() => {
            const p = payMap.get(a.payment_id);
            if (!p) return null;
            const resolvedName = (p.recorded_by ? nameMap.get(p.recorded_by) : undefined);
            const displayName = resolvedName && resolvedName !== 'Legacy / Imported' ? resolvedName : p.recorded_by_name;
            return { payment_date: p.payment_date, method: p.payment_method, reference: p.reference_number, recorded_by_name: displayName };
          })(),
        })));
      } else {
        setApplications([]);
      }
      setCreditNotes((creditsRes.data ?? []) as CreditNote[]);

      if (inv.sales_order_id) {
        const [gateRes, overrideRes] = await Promise.all([
          supabase.rpc('get_sales_order_delivery_gate', {
            p_sales_order_id: inv.sales_order_id,
          }),
          supabase
            .from('SalesOrderDeliveryOverrides')
            .select('id, reason, authorized_by_name, authorized_at')
            .eq('sales_order_id', inv.sales_order_id)
            .eq('status', 'active')
            .eq('deleted', false)
            .order('authorized_at', { ascending: false })
            .limit(1)
            .maybeSingle(),
        ]);

        const gateRow = Array.isArray(gateRes.data)
          ? (gateRes.data[0] as DeliveryGate | undefined)
          : undefined;

        setDeliveryGate(gateRow ?? null);
        setActiveDeliveryOverride((overrideRes.data as ActiveDeliveryOverride | null) ?? null);
      } else {
        setDeliveryGate(null);
        setActiveDeliveryOverride(null);
      }
    } catch (e: unknown) {
      setError(getSupabaseErrorMessageDetailed(e));
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

      if (activeOrganizationId) {
        await supabase.from('FinancialAuditLog').insert({
          organization_id: activeOrganizationId,
          action: 'delete_invoice',
          entity_type: 'invoice',
          entity_id: invoiceId,
          amount: invoice?.total ?? null,
          performed_by: user?.id ?? null,
          performed_by_name: user?.name ?? user?.email ?? null,
          metadata: { invoice_number: invoice?.invoice_number },
        });
      }

      setDeleteConfirmOpen(false);
      addNotification({ type: 'success', title: 'Deleted', message: 'Invoice draft deleted.' });
      handleBack();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to delete invoice' });
    } finally {
      setUpdatingStatus(false);
    }
  };

  const voidInvoice = async () => {
    if (!invoiceId || !invoice) return;
    if (voidReason.trim().length < 3) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please provide a void reason.' });
      return;
    }
    setUpdatingStatus(true);
    try {
      const currentApplied = applications.reduce((sum, row) => sum + Number(row.applied_amount), 0);
      if (currentApplied > 0.005) {
        throw new Error('Invoice has applied payments. Unapply payments before voiding.');
      }
      const now = new Date().toISOString();
      const { error: err } = await supabase
        .from('DealerInvoices')
        .update({
          status: 'void',
          void_reason: voidReason.trim(),
          voided_by: user?.id ?? null,
          voided_at: now,
        })
        .eq('id', invoiceId);
      if (err) throw err;

      if (activeOrganizationId) {
        await supabase.from('FinancialAuditLog').insert({
          organization_id: activeOrganizationId,
          action: 'void_invoice',
          entity_type: 'invoice',
          entity_id: invoiceId,
          amount: invoice?.total ?? null,
          reason: voidReason.trim(),
          performed_by: user?.id ?? null,
          performed_by_name: user?.name ?? user?.email ?? null,
          metadata: { invoice_number: invoice?.invoice_number },
        });
      }

      setVoidDialogOpen(false);
      setVoidReason('');
      addNotification({ type: 'success', title: 'Invoice Voided', message: 'Invoice status updated to void.' });
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    } finally {
      setUpdatingStatus(false);
    }
  };

  const createCreditNote = async () => {
    if (!activeOrganizationId || !invoice?.dealer_id || !invoiceId) return;
    const amount = Number(creditAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      addNotification({ type: 'error', title: 'Validation', message: 'Credit amount must be greater than 0.' });
      return;
    }
    if (creditReason.trim().length < 3) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please provide a reason for the credit.' });
      return;
    }
    const creditedSoFar = creditNotes
      .filter((row) => row.status !== 'void')
      .reduce((sum, row) => sum + Number(row.amount), 0);
    const creditableRemaining = Math.max(Number(invoice.total) - creditedSoFar, 0);
    if (amount > creditableRemaining + 0.0001) {
      addNotification({
        type: 'error',
        title: 'Validation',
        message: `Credit exceeds remaining creditable amount (${fmt(creditableRemaining, currency)}).`,
      });
      return;
    }

    setCreatingCredit(true);
    try {
      const creditNo = await generateNextSequentialNumber(
        'CN',
        'DealerCreditNotes',
        'credit_note_number',
        activeOrganizationId
      );
      const { error: insertErr } = await supabase
        .from('DealerCreditNotes')
        .insert({
          organization_id: activeOrganizationId,
          dealer_id: invoice.dealer_id,
          invoice_id: invoiceId,
          credit_note_number: creditNo,
          issue_date: new Date().toISOString().slice(0, 10),
          amount,
          reason: creditReason.trim(),
          status: 'issued',
          deleted: false,
        });
      if (insertErr) throw insertErr;
      setCreditDialogOpen(false);
      setCreditAmount('');
      setCreditReason('');
      addNotification({ type: 'success', title: 'Credit Note Created', message: `${creditNo} created successfully.` });
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    } finally {
      setCreatingCredit(false);
    }
  };

  const handleVoidCreditNote = async () => {
    if (!voidCreditTarget || !invoiceId || !activeOrganizationId) return;
    if (voidCreditReason.trim().length < 3) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please provide a void reason.' });
      return;
    }
    setVoidingCredit(true);
    try {
      const now = new Date().toISOString();
      const { error: err } = await supabase
        .from('DealerCreditNotes')
        .update({
          status: 'void',
          void_reason: voidCreditReason.trim(),
          voided_by: user?.id ?? null,
          voided_at: now,
        })
        .eq('id', voidCreditTarget.id);
      if (err) throw err;

      await supabase.from('FinancialAuditLog').insert({
        organization_id: activeOrganizationId,
        action: 'void_credit_note',
        entity_type: 'credit_note',
        entity_id: voidCreditTarget.id,
        related_entity_type: 'invoice',
        related_entity_id: invoiceId,
        amount: voidCreditTarget.amount,
        reason: voidCreditReason.trim(),
        performed_by: user?.id ?? null,
        performed_by_name: user?.name ?? user?.email ?? null,
        metadata: { credit_note_number: voidCreditTarget.credit_note_number },
      });

      setVoidCreditTarget(null);
      setVoidCreditReason('');
      addNotification({ type: 'success', title: 'Credit Voided', message: 'Credit note has been voided.' });
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    } finally {
      setVoidingCredit(false);
    }
  };

  const loadAvailablePayments = useCallback(async () => {
    if (!invoice?.dealer_id || !activeOrganizationId) return;
    const { data: payments } = await supabase
      .from('Payments')
      .select('id, amount, payment_date, reference_number, payment_method, status')
      .eq('organization_id', activeOrganizationId)
      .eq('dealer_id', invoice.dealer_id)
      .eq('deleted', false)
      .neq('status', 'void')
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

  const handleAuthorizeDeliveryOverride = async () => {
    if (!invoice?.sales_order_id) return;
    if (deliveryOverrideReason.trim().length < 5) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please provide a reason (min 5 characters).' });
      return;
    }
    setAuthorizingDeliveryOverride(true);
    try {
      const { data, error: rpcError } = await supabase.rpc('authorize_sales_order_delivery_release', {
        p_sales_order_id: invoice.sales_order_id,
        p_reason: deliveryOverrideReason.trim(),
      });
      if (rpcError) throw rpcError;
      const result = (data ?? {}) as { ok?: boolean; error?: string };
      if (result.ok === false) throw new Error(result.error || 'Authorization failed');
      addNotification({ type: 'success', title: 'Authorized', message: 'Delivery override authorized from Financials.' });
      setDeliveryOverrideReason('');
      setDeliveryOverrideDialogOpen(false);
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    } finally {
      setAuthorizingDeliveryOverride(false);
    }
  };

  const handleRevokeDeliveryOverride = async () => {
    if (!invoice?.sales_order_id) return;
    if (deliveryRevokeReason.trim().length < 5) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please provide a revoke reason (min 5 characters).' });
      return;
    }
    setRevokingDeliveryOverride(true);
    try {
      const { data, error: rpcError } = await supabase.rpc('revoke_sales_order_delivery_release', {
        p_sales_order_id: invoice.sales_order_id,
        p_reason: deliveryRevokeReason.trim(),
      });
      if (rpcError) throw rpcError;
      const result = (data ?? {}) as { ok?: boolean; error?: string };
      if (result.ok === false) throw new Error(result.error || 'Revoke failed');
      addNotification({ type: 'success', title: 'Revoked', message: 'Delivery override revoked.' });
      setDeliveryRevokeReason('');
      setDeliveryOverrideDialogOpen(false);
      await refetch();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessageDetailed(e) });
    } finally {
      setRevokingDeliveryOverride(false);
    }
  };

  const openAuthorizeDialog = () => {
    setDeliveryOverrideMode('authorize');
    setDeliveryOverrideDialogOpen(true);
  };

  const openRevokeDialog = () => {
    setDeliveryOverrideMode('revoke');
    setDeliveryOverrideDialogOpen(true);
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

  useEffect(() => {
    if (!openPdfOnly) return;
    if (!invoice || lines.length === 0) return;
    if (hasAutoOpenedPdfRef.current) return;
    hasAutoOpenedPdfRef.current = true;
    (async () => {
      const doc = await buildInvoicePDFDoc();
      if (!doc) return;
      const blob = doc.output('blob');
      const url = URL.createObjectURL(blob);
      window.location.replace(url);
    })();
  }, [openPdfOnly, invoice, lines.length, buildInvoicePDFDoc]);

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
        <button onClick={handleBack}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Invoices
        </button>
      </div>
    );
  }

  const currency = invoice.currency_code || 'USD';
  const totalApplied = applications.reduce((s, a) => s + Number(a.applied_amount), 0);
  const totalCredited = creditNotes
    .filter((row) => row.status !== 'void')
    .reduce((s, row) => s + Number(row.amount), 0);
  const balanceDue = Math.max(invoice.total - totalApplied - totalCredited, 0);
  const gateBalanceDue = Number(deliveryGate?.balance_due ?? 0);
  const gatePaymentComplete = deliveryGate?.payment_complete ?? gateBalanceDue <= 0;
  const status = invoice.status;
  const dealer = invoice.Dealers;

  const tabs = [
    { id: 'lines', label: 'Lines', count: lines.length },
    { id: 'payments', label: 'Payments Applied', count: applications.length },
    { id: 'credits', label: 'Credits', count: creditNotes.length },
  ];

  const actionItems: { label: string; onClick: () => void; danger?: boolean }[] = [];
  actionItems.push({ label: 'Preview PDF', onClick: handlePreviewPDF });
  actionItems.push({ label: 'Download PDF', onClick: handleDownloadPDF });
  if (status === 'draft') {
    actionItems.push({ label: 'Issue Invoice', onClick: () => updateStatus('issued') });
    if (totalApplied <= 0.005 && totalCredited <= 0.005 && canDeleteFin) {
      actionItems.push({ label: 'Delete Draft', onClick: () => setDeleteConfirmOpen(true), danger: true });
    }
  }
  if (status === 'issued' || status === 'partial' || status === 'paid') {
    if (canVoidFin) actionItems.push({ label: 'Void Invoice', onClick: () => setVoidDialogOpen(true), danger: true });
    const creditableRemaining = Math.max(Number(invoice.total) - totalCredited, 0);
    if (creditableRemaining > 0.005) {
      actionItems.push({
        label: 'Create Credit',
        onClick: () => {
          setCreditAmount(String(creditableRemaining.toFixed(2)));
          setCreditDialogOpen(true);
        },
      });
    }
  }

  return (
    <DetailPageLayout
      title={invoice.invoice_number}
      subtitle="Invoice Detail"
      status={<StatusBadge status={invoice.status} type="invoice" />}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={handleBack}
      contentClassName="pt-2 pb-6"
      actions={hasRedirectBack || actionItems.length > 0 ? (
        <div className="flex items-center gap-2">
          {hasRedirectBack && (
            <button
              type="button"
              onClick={handleBackContextual}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
              title="Back"
            >
              Back
            </button>
          )}
          {invoice.sales_order_id && canManageDeliveryOverride && !gatePaymentComplete && (
            <button
              type="button"
              onClick={activeDeliveryOverride ? openRevokeDialog : openAuthorizeDialog}
              className="inline-flex h-8 w-8 items-center justify-center rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50"
              title={
                activeDeliveryOverride
                  ? `Revoke override (${activeDeliveryOverride.authorized_by_name ?? 'Unknown'} · ${formatDate(activeDeliveryOverride.authorized_at)})`
                  : 'Authorize delivery override'
              }
            >
              {activeDeliveryOverride ? <LockOpen className="h-4 w-4" /> : <Lock className="h-4 w-4" />}
            </button>
          )}
          {actionItems.length > 0 && (
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
          )}
        </div>
      ) : undefined}
    >
      {/* Void banner */}
      {invoice.status === 'void' && (() => {
        const reason = invoice.void_reason
          || (invoice.notes?.match(/VOID REASON:\s*(.+)/)?.[1]?.trim())
          || null;
        return (
          <div className="mb-4 rounded-lg border border-red-300 bg-red-50 p-4">
            <p className="text-sm font-semibold text-red-800">This invoice has been voided</p>
            {reason && (
              <p className="mt-1 text-sm text-red-700">Reason: {reason}</p>
            )}
          </div>
        );
      })()}

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
              <dd className="text-gray-900">{formatDate(invoice.issue_date)}</dd>
            </div>
            {invoice.due_date && (
              <div className="flex justify-between">
                <dt className="text-gray-500">Due Date</dt>
                <dd className="text-gray-900">{formatDate(invoice.due_date)}</dd>
              </div>
            )}
            {invoice.SalesOrders && (
              <div className="flex justify-between border-t pt-2">
                <dt className="text-gray-500">Sales Order</dt>
                <dd>
                  <button type="button"
                    onClick={() => router.navigate(withReturnTo(`/sales/orders/${invoice.SalesOrders!.id}`))}
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

      {deliveryOverrideDialogOpen && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">
              {deliveryOverrideMode === 'authorize' ? 'Authorize Delivery Override' : 'Revoke Delivery Override'}
            </h4>
            <p className="text-xs text-gray-600 mb-3">
              {deliveryOverrideMode === 'authorize'
                ? 'Provide a reason. This action is audited and allows delivery with pending balance.'
                : 'Provide a reason to remove the current delivery override.'}
            </p>
            <textarea
              value={deliveryOverrideMode === 'authorize' ? deliveryOverrideReason : deliveryRevokeReason}
              onChange={(e) => {
                if (deliveryOverrideMode === 'authorize') setDeliveryOverrideReason(e.target.value);
                else setDeliveryRevokeReason(e.target.value);
              }}
              placeholder={deliveryOverrideMode === 'authorize' ? 'Authorization reason...' : 'Revoke reason...'}
              rows={3}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
            />
            <div className="flex justify-end gap-2 mt-3">
              <button
                type="button"
                onClick={() => setDeliveryOverrideDialogOpen(false)}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => {
                  if (deliveryOverrideMode === 'authorize') {
                    void handleAuthorizeDeliveryOverride();
                  } else {
                    void handleRevokeDeliveryOverride();
                  }
                }}
                disabled={deliveryOverrideMode === 'authorize' ? authorizingDeliveryOverride : revokingDeliveryOverride}
                className={`px-3 py-1.5 text-sm text-white rounded-lg disabled:opacity-50 ${
                  deliveryOverrideMode === 'authorize' ? 'bg-primary' : 'bg-red-600'
                }`}
              >
                {deliveryOverrideMode === 'authorize'
                  ? (authorizingDeliveryOverride ? 'Authorizing...' : 'Authorize')
                  : (revokingDeliveryOverride ? 'Revoking...' : 'Revoke')}
              </button>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'lines' && (
        <div className="space-y-4">
        {linesFallbackFromSalesOrder && (
          <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
            <p className="text-xs text-amber-800">
              Showing line breakdown from Sales Order because invoice lines are missing.
            </p>
          </div>
        )}
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
              <div className="flex justify-between border-t pt-2">
                <dt className="text-sm font-semibold text-gray-700">Invoice Total</dt>
                <dd className="font-mono font-bold text-gray-900">{fmt(invoice.total, currency)}</dd>
              </div>
              {(totalApplied > 0 || totalCredited > 0) && (
                <>
                  <div className="flex justify-between pt-1">
                    <dt className="text-gray-500">Paid</dt>
                    <dd className="font-mono text-green-600">−{fmt(totalApplied, currency)}</dd>
                  </div>
                  {totalCredited > 0 && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Credited</dt>
                      <dd className="font-mono text-amber-600">−{fmt(totalCredited, currency)}</dd>
                    </div>
                  )}
                </>
              )}
              <div className="flex justify-between border-t pt-2">
                <dt className="text-sm font-semibold text-gray-700">Balance Due</dt>
                <dd className={`font-mono font-bold ${balanceDue > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {fmt(balanceDue, currency)}
                </dd>
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
                        {formatDate(p.payment_date)} - {p.payment_method} - {fmt(p.unapplied, currency)} available
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
                      onClick={() => router.navigate(withReturnTo(`/financials/payments/${a.payment_id}`))}
                    >
                      <td className="px-4 py-4">{formatDate(a.Payments?.payment_date)}</td>
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
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-sm font-semibold text-gray-700">Invoice Total</dt>
                  <dd className="font-mono font-bold text-gray-900">{fmt(invoice.total, currency)}</dd>
                </div>
                {(totalApplied > 0 || totalCredited > 0) && (
                  <>
                    <div className="flex justify-between pt-1">
                      <dt className="text-gray-500">Paid</dt>
                      <dd className="font-mono text-green-600">−{fmt(totalApplied, currency)}</dd>
                    </div>
                    {totalCredited > 0 && (
                      <div className="flex justify-between">
                        <dt className="text-gray-500">Credited</dt>
                        <dd className="font-mono text-amber-600">−{fmt(totalCredited, currency)}</dd>
                      </div>
                    )}
                  </>
                )}
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-sm font-semibold text-gray-700">Balance Due</dt>
                  <dd className={`font-mono font-bold ${balanceDue > 0 ? 'text-red-600' : 'text-green-600'}`}>
                    {fmt(balanceDue, currency)}
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'credits' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Credit #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Reason</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Amount</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody>
              {creditNotes.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-500">No credit notes</td></tr>
              ) : (
                creditNotes.map((cn) => (
                  <tr key={cn.id} className={`border-t hover:bg-gray-50 ${cn.status === 'void' ? 'opacity-60' : ''}`}>
                    <td className={`px-4 py-4 font-medium text-primary ${cn.status === 'void' ? 'line-through' : ''}`}>{cn.credit_note_number}</td>
                    <td className="px-4 py-4">{formatDate(cn.issue_date)}</td>
                    <td className="px-4 py-4 text-gray-600">{cn.reason ?? '—'}</td>
                    <td className="px-4 py-4 text-center">
                      <StatusBadge status={cn.status} type="invoice" size="sm" />
                    </td>
                    <td className={`px-4 py-4 text-right font-mono text-amber-700 ${cn.status === 'void' ? 'line-through' : ''}`}>{fmt(cn.amount, currency)}</td>
                    <td className="px-4 py-4 text-right">
                      {cn.status !== 'void' && canVoidFin && (
                        <button
                          type="button"
                          onClick={() => { setVoidCreditTarget(cn); setVoidCreditReason(''); }}
                          className="px-2 py-1 text-xs font-medium text-red-700 border border-red-200 rounded hover:bg-red-50"
                        >
                          Void
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {voidDialogOpen && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Void Invoice</h4>
            {status === 'paid' && (
              <div className="mb-3 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2">
                <p className="text-xs font-semibold text-amber-800">This invoice is fully paid.</p>
                <p className="text-xs text-amber-700">Voiding it will not refund applied payments. Consider creating a Credit Note instead.</p>
              </div>
            )}
            <p className="text-xs text-gray-600 mb-3">
              This keeps the audit trail. If the invoice has payments applied, unapply them first.
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
                onClick={voidInvoice}
                disabled={updatingStatus}
                className="px-3 py-1.5 text-sm text-white bg-red-600 rounded-lg disabled:opacity-50"
              >
                {updatingStatus ? 'Voiding...' : 'Void Invoice'}
              </button>
            </div>
          </div>
        </div>
      )}

      {creditDialogOpen && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Create Credit Note</h4>
            <p className="text-xs text-gray-600 mb-3">
              Creates an audit-safe credit adjustment linked to this invoice.
            </p>
            <div className="space-y-2">
              <input
                type="number"
                min={0.01}
                step={0.01}
                value={creditAmount}
                onChange={(e) => setCreditAmount(e.target.value)}
                placeholder="Amount"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
              />
              <textarea
                value={creditReason}
                onChange={(e) => setCreditReason(e.target.value)}
                placeholder="Reason for credit..."
                rows={3}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
              />
            </div>
            <div className="flex justify-end gap-2 mt-3">
              <button
                type="button"
                onClick={() => { setCreditDialogOpen(false); setCreditAmount(''); setCreditReason(''); }}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={createCreditNote}
                disabled={creatingCredit}
                className="px-3 py-1.5 text-sm text-white bg-primary rounded-lg disabled:opacity-50"
              >
                {creatingCredit ? 'Creating...' : 'Create Credit'}
              </button>
            </div>
          </div>
        </div>
      )}

      {deleteConfirmOpen && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Delete Draft Invoice</h4>
            <p className="text-sm text-gray-600 mb-3">
              Are you sure you want to delete <span className="font-semibold">{invoice?.invoice_number}</span>? This action cannot be undone.
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setDeleteConfirmOpen(false)}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => { void deleteInvoice(); }}
                disabled={updatingStatus}
                className="px-3 py-1.5 text-sm text-white bg-red-600 rounded-lg disabled:opacity-50"
              >
                {updatingStatus ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {voidCreditTarget && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-4 w-full max-w-md">
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Void Credit Note</h4>
            <p className="text-sm text-gray-600 mb-3">
              Void credit <span className="font-semibold">{voidCreditTarget.credit_note_number}</span> ({fmt(voidCreditTarget.amount, currency)})?
              The credit will remain on record but will no longer reduce the invoice balance.
            </p>
            <textarea
              value={voidCreditReason}
              onChange={(e) => setVoidCreditReason(e.target.value)}
              placeholder="Reason for void..."
              rows={3}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
            />
            <div className="flex justify-end gap-2 mt-3">
              <button
                type="button"
                onClick={() => { setVoidCreditTarget(null); setVoidCreditReason(''); }}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => { void handleVoidCreditNote(); }}
                disabled={voidingCredit}
                className="px-3 py-1.5 text-sm text-white bg-red-600 rounded-lg disabled:opacity-50"
              >
                {voidingCredit ? 'Voiding...' : 'Void Credit'}
              </button>
            </div>
          </div>
        </div>
      )}
    </DetailPageLayout>
  );
}
