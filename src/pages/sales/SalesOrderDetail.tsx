import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useAuth } from '../../hooks/useAuth';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import TimelineView from '../../components/shared/TimelineView';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { formatCurrency } from '../../lib/utils';
import { useSOActions } from '../../hooks/useSOActions';
import { ChevronDown, FileText, ShoppingBag, CreditCard, Factory, Package, CheckCircle2, AlertTriangle, XCircle, ArrowLeft, Eye } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useSOFulfillmentSummary } from '../../hooks/useInventoryAllocations';
import { generateInvoicePDF } from '../../lib/pdf/generateInvoicePDF';
import type { InvoicePDFData, InvoicePDFDealer, InvoicePDFLine, GenerateInvoicePDFOptions } from '../../lib/pdf/generateInvoicePDF';

const SALES_SUBMODULES = [
  { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
  { id: 'proposals', label: 'Proposals', href: '/sales/proposals', icon: FileText },
  { id: 'orders', label: 'Orders', href: '/sales/orders', icon: ShoppingBag },
];

interface SalesOrder {
  id: string;
  sales_order_no: string;
  quote_id: string | null;
  Quotes?: { id: string; quote_no: string } | null;
  status: string;
  /** Set when cancelled; used to restore on reactivate (org user). */
  status_before_cancel?: string | null;
  customer_id: string;
  dealer_id: string;
  total_amount: number;
  subtotal: number;
  tax_amount: number;
  discount_amount: number;
  priority: string;
  created_at: string;
  expected_delivery_date: string | null;
  completed_at: string | null;
  closed_at: string | null;
  DirectoryCustomers?: { customer_name: string } | null;
  Dealers?: { dealer_name: string; dealer_no?: string | null } | null;
}

interface FinancialSummary {
  invoice_count: number;
  total_invoiced: number;
  total_paid: number;
  balance_due: number;
  invoice_status: string;
  latest_invoice_id: string | null;
  latest_invoice_number: string | null;
}

interface SalesOrderLine {
  id: string;
  sales_order_id: string;
  line_number: number | null;
  description: string | null;
  collection_name: string | null;
  variant_name: string | null;
  product_type?: string | null;
  width_m?: number | null;
  height_m?: number | null;
  quantity: number;
  unit_price: number | null;
  line_total: number | null;
  CatalogItems?: { name: string; sku: string } | null;
}

interface ManufacturingOrder {
  id: string;
  manufacturing_order_no: string;
  status: string;
  mo_type: string;
  product_name: string | null;
  quantity: number;
  priority: string;
  created_at: string;
}

interface SOInvoice {
  id: string;
  invoice_number: string;
  status: string;
  issue_date: string;
  total: number;
  currency_code: string;
}

interface InvoicePdfDealer {
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

const MFG_STATUS_STEPS = [
  { id: 'draft', label: 'Pending Review' },
  { id: 'planned', label: 'Planned' },
  { id: 'in_production', label: 'In Production' },
  { id: 'quality_check', label: 'Quality Check' },
  { id: 'ready_for_pickup', label: 'Ready for Pickup' },
  { id: 'delivered', label: 'Delivered' },
] as const;

function normalizeMfgStatus(status: string | null | undefined): string {
  const normalized = (status ?? '').trim().toLowerCase();
  if (normalized === 'in_progress') {
    return 'in_production';
  }
  if (normalized === 'completed') {
    return 'delivered';
  }
  return normalized;
}

function formatInvoiceBillingAddress(d: InvoicePdfDealer): string {
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

interface TimelineEvent {
  id: string;
  action: string;
  description: string;
  user_name?: string | null;
  created_at: string;
  metadata?: Record<string, unknown> | null;
}

function getSalesOrderIdFromPath(): string | null {
  const match = window.location.pathname.match(/\/sales\/orders\/([^/]+)/);
  return match ? match[1] : null;
}

export default function SalesOrderDetail() {
  const salesOrderId = getSalesOrderIdFromPath();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { isInternal, isPortal } = useAccessContext();
  const addNotification = useUIStore((s) => s.addNotification);

  const { summary: materialSummary, overallStatus: materialStatus, loading: materialSummaryLoading } = useSOFulfillmentSummary(salesOrderId);

  const [so, setSo] = useState<SalesOrder | null>(null);
  const [lines, setLines] = useState<SalesOrderLine[]>([]);
  const [mos, setMos] = useState<ManufacturingOrder[]>([]);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [financialSummary, setFinancialSummary] = useState<FinancialSummary | null>(null);
  const [linkedInvoices, setLinkedInvoices] = useState<SOInvoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('overview');
  const [actionsOpen, setActionsOpen] = useState(false);
  const actionsRef = useRef<HTMLDivElement>(null);

  const { transitionSOStatus, createMO, isActing } = useSOActions();
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Sales', SALES_SUBMODULES);
  }, [registerSubmodules]);

  const refetch = useCallback(async () => {
    if (!salesOrderId || !activeOrganizationId) return;
    setLoading(true);
    setError(null);
    try {
      const [soRes, linesRes, mosRes, timelineRes, financialRes, invoicesRes] = await Promise.all([
        supabase
          .from('SalesOrders')
          .select(`
            id, sales_order_no, quote_id, status, status_before_cancel, customer_id, dealer_id,
            total_amount, subtotal, tax_amount, discount_amount,
            priority, created_at, expected_delivery_date, completed_at, closed_at,
            DirectoryCustomers:customer_id (customer_name),
            Dealers:dealer_id (dealer_name, dealer_no),
            Quotes:quote_id (id, quote_no)
          `)
          .eq('id', salesOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .single(),
        supabase
          .from('SaleOrderLines')
          .select(`
            id, sales_order_id, line_number, description, collection_name, variant_name,
            product_type, width_m, height_m,
            quantity, unit_price, line_total,
            CatalogItems:catalog_item_id (name, sku)
          `)
          .eq('sales_order_id', salesOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('line_number', { ascending: true, nullsFirst: false }),
        supabase
          .from('ManufacturingOrders')
          .select('id, manufacturing_order_no, status, mo_type, product_name, quantity, priority, created_at')
          .eq('sales_order_id', salesOrderId)
          .eq('deleted', false)
          .order('created_at', { ascending: false }),
        supabase
          .from('ActivityTimeline')
          .select('id, action, description, user_name, created_at, metadata')
          .eq('entity_type', 'sales_order')
          .eq('entity_id', salesOrderId)
          .order('created_at', { ascending: false }),
        supabase
          .from('sales_order_financial_summary')
          .select('invoice_count, total_invoiced, total_paid, balance_due, invoice_status, latest_invoice_id, latest_invoice_number')
          .eq('sales_order_id', salesOrderId)
          .maybeSingle(),
        supabase
          .from('DealerInvoices')
          .select('id, invoice_number, status, issue_date, total, currency_code')
          .eq('sales_order_id', salesOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('issue_date', { ascending: false }),
      ]);

      if (soRes.error) throw soRes.error;

      setSo(soRes.data as SalesOrder);

      if (linesRes.error) {
        if (import.meta.env.DEV) console.warn('[SalesOrderDetail] SaleOrderLines error:', linesRes.error);
        // Fallback: fetch lines without embed (e.g. if FK CatalogItems not yet applied), then resolve name/sku
        const fallback = await supabase
          .from('SaleOrderLines')
          .select('id, sales_order_id, line_number, description, collection_name, variant_name, product_type, width_m, height_m, quantity, unit_price, line_total, catalog_item_id')
          .eq('sales_order_id', salesOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('line_number', { ascending: true, nullsFirst: false });
        if (fallback.error) {
          setLines([]);
        } else {
          const rows = (fallback.data ?? []) as (SalesOrderLine & { catalog_item_id?: string | null })[];
          const itemIds = [...new Set(rows.map((r) => r.catalog_item_id).filter(Boolean))] as string[];
          const itemMap = new Map<string, { name: string; sku: string }>();
          if (itemIds.length > 0) {
            const { data: items } = await supabase.from('CatalogItems').select('id, name, sku').in('id', itemIds);
            (items ?? []).forEach((i: { id: string; name: string; sku: string }) => itemMap.set(i.id, { name: i.name, sku: i.sku }));
          }
          const merged: SalesOrderLine[] = rows.map((r) => ({
            ...r,
            CatalogItems: r.catalog_item_id ? itemMap.get(r.catalog_item_id) ?? null : null,
          }));
          setLines(merged);
        }
      } else {
        setLines((linesRes.data ?? []) as SalesOrderLine[]);
      }
      if (mosRes.error) {
        if (import.meta.env.DEV) console.warn('[SalesOrderDetail] ManufacturingOrders error:', mosRes.error);
      } else {
        setMos((mosRes.data ?? []) as ManufacturingOrder[]);
      }
      if (timelineRes.error) {
        if (import.meta.env.DEV) console.warn('[SalesOrderDetail] Timeline error:', timelineRes.error);
      } else {
        setTimeline((timelineRes.data ?? []) as TimelineEvent[]);
      }
      setFinancialSummary((financialRes.data as FinancialSummary | null) ?? null);
      if (invoicesRes.error) {
        if (import.meta.env.DEV) console.warn('[SalesOrderDetail] DealerInvoices error:', invoicesRes.error);
        setLinkedInvoices([]);
      } else {
        setLinkedInvoices((invoicesRes.data ?? []) as SOInvoice[]);
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Failed to load sales order';
      setError(msg);
      setSo(null);
    } finally {
      setLoading(false);
    }
  }, [salesOrderId, activeOrganizationId]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (actionsRef.current && !actionsRef.current.contains(e.target as Node)) {
        setActionsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleTransition = useCallback(
    async (newStatus: string) => {
      if (!salesOrderId || !user?.id) return;
      setActionsOpen(false);
      try {
        await transitionSOStatus(salesOrderId, newStatus, user.id, user.name);
        refetch();
      } catch {
        // useSOActions already shows notification
      }
    },
    [salesOrderId, user, transitionSOStatus, refetch]
  );

  const handleCreateMO = useCallback(async () => {
    if (!salesOrderId || !user?.id) return;
    setActionsOpen(false);
    try {
      const result = await createMO(salesOrderId, user.id, undefined, user.name);
      if (result?.mo_id) {
        router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${result.mo_id}`));
      } else {
        refetch();
      }
    } catch {
      // useSOActions already shows notification
    }
  }, [salesOrderId, user, createMO, refetch]);


  const actionButtons = useMemo(() => {
    if (!so) return [];
    const status = (so.status || 'draft').toLowerCase();
    const btns: { label: string; onClick: () => void; status?: string }[] = [];
    if (status === 'confirmed') {
      btns.push({ label: 'Put On Hold', onClick: () => handleTransition('on_hold'), status: 'on_hold' });
      btns.push({ label: 'Mark Completed', onClick: () => handleTransition('delivered'), status: 'delivered' });
    }
    if (status === 'on_hold') {
      btns.push({ label: 'Resume', onClick: () => handleTransition('confirmed'), status: 'confirmed' });
    }
    if (status === 'delivered') {
      btns.push({ label: 'Close Order', onClick: () => handleTransition('closed'), status: 'closed' });
    }
    if (isInternal) {
      if (['draft', 'confirmed', 'on_hold'].includes(status)) {
        btns.push({ label: 'Cancel', onClick: () => handleTransition('cancelled'), status: 'cancelled' });
      }
      if (status === 'cancelled') {
        const restoreStatus = (so.status_before_cancel && ['draft', 'confirmed', 'on_hold'].includes(so.status_before_cancel.trim().toLowerCase()))
          ? so.status_before_cancel.trim().toLowerCase()
          : 'draft';
        btns.push({ label: 'Reactivate', onClick: () => handleTransition(restoreStatus), status: restoreStatus });
      }
    }
    return btns;
  }, [so, isInternal, handleTransition, handleCreateMO]);

  const currentMfgStepIndex = useMemo(() => {
    if (mos.length === 0) return -1;
    const ranked = mos
      .map((m) => MFG_STATUS_STEPS.findIndex((s) => s.id === normalizeMfgStatus(m.status)))
      .filter((idx) => idx >= 0);
    if (ranked.length === 0) return -1;
    // Show the most delayed MO status to avoid hiding bottlenecks.
    return Math.min(...ranked);
  }, [mos]);

  const currency = 'USD';
  const orderTotal = Math.max(0, Number(so?.total_amount ?? 0));
  const totalInvoiced = Math.max(0, Number(financialSummary?.total_invoiced ?? 0));
  const totalPaid = financialSummary?.total_paid ?? 0;
  const receivableBalance = Math.max(0, Number(financialSummary?.balance_due ?? orderTotal - totalPaid));
  const billableRemaining = Math.max(0, orderTotal - totalInvoiced);
  const collectionStatus =
    totalPaid <= 0.005
      ? 'collection_unpaid'
      : totalPaid >= orderTotal + 0.005
        ? (totalPaid > orderTotal + 0.005 ? 'collection_overpaid' : 'collection_paid')
        : 'collection_partial';
  const canCreateInvoice = isInternal && billableRemaining > 0.005;

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

  const handlePreviewInvoicePdf = useCallback(
    async (invoiceId: string) => {
      const previewWindow = window.open('', '_blank');
      if (!previewWindow) {
        addNotification({
          type: 'error',
          title: 'Pop-up blocked',
          message: 'Please allow pop-ups to preview the invoice PDF.',
        });
        return;
      }

      previewWindow.document.write('<html><body style="font-family: sans-serif; padding: 16px;">Generating invoice PDF...</body></html>');
      previewWindow.document.close();

      try {
        const [invoiceRes, linesRes, applicationsRes] = await Promise.all([
          supabase
            .from('DealerInvoices')
            .select(`
              id, invoice_number, status, issue_date, due_date, currency_code, subtotal, tax_total, total, notes, sales_order_id,
              Dealers:dealer_id (
                dealer_name, dealer_no, dealer_email, dealer_phone, identification_number,
                billing_same_as_location,
                street_address_line_1, street_address_line_2, city, state, zip_code, country,
                billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country
              ),
              SalesOrders:sales_order_id (sales_order_no)
            `)
            .eq('id', invoiceId)
            .eq('deleted', false)
            .maybeSingle(),
          supabase
            .from('DealerInvoiceLines')
            .select('description, qty, unit_price, line_subtotal')
            .eq('invoice_id', invoiceId)
            .order('sort_order', { ascending: true }),
          supabase
            .from('PaymentApplications')
            .select('applied_amount')
            .eq('invoice_id', invoiceId),
        ]);

        if (invoiceRes.error || !invoiceRes.data) {
          throw new Error(invoiceRes.error?.message || 'Invoice not found');
        }
        if (linesRes.error) throw linesRes.error;
        if (applicationsRes.error) throw applicationsRes.error;

        const invoice = invoiceRes.data as any;
        const lines = (linesRes.data ?? []) as Array<{ description: string; qty: number; unit_price: number; line_subtotal: number }>;
        const applications = (applicationsRes.data ?? []) as Array<{ applied_amount: number }>;

        const totalApplied = applications.reduce((sum, app) => sum + Number(app.applied_amount ?? 0), 0);
        const pdfData: InvoicePDFData = {
          invoice_number: invoice.invoice_number,
          status: invoice.status,
          issue_date: invoice.issue_date,
          due_date: invoice.due_date,
          currency_code: invoice.currency_code || 'USD',
          subtotal: Number(invoice.subtotal ?? 0),
          tax_total: Number(invoice.tax_total ?? 0),
          total: Number(invoice.total ?? 0),
          total_paid: totalApplied,
          balance_due: Math.max(Number(invoice.total ?? 0) - totalApplied, 0),
          notes: invoice.notes ?? null,
          sales_order_no: invoice.SalesOrders?.sales_order_no ?? null,
        };

        const dealer = invoice.Dealers as InvoicePdfDealer | null;
        const pdfDealer: InvoicePDFDealer | null = dealer
          ? {
              dealer_name: dealer.dealer_name,
              dealer_no: dealer.dealer_no ?? null,
              identification_number: dealer.identification_number ?? null,
              billing_address: formatInvoiceBillingAddress(dealer),
              email: dealer.dealer_email ?? null,
              phone: dealer.dealer_phone ?? null,
            }
          : null;

        const pdfLines: InvoicePDFLine[] = lines.map((line) => ({
          description: line.description ?? '',
          qty: Number(line.qty ?? 0),
          unit_price: Number(line.unit_price ?? 0),
          line_subtotal: Number(line.line_subtotal ?? 0),
        }));

        const logoOptions = await loadOrganizationLogoOptions();
        const doc = generateInvoicePDF(pdfData, pdfDealer, pdfLines, logoOptions);
        const blob = doc.output('blob');
        const url = URL.createObjectURL(blob);
        previewWindow.location.replace(url);
      } catch (error: any) {
        previewWindow.close();
        addNotification({
          type: 'error',
          title: 'PDF preview failed',
          message: error?.message || 'Could not generate invoice PDF.',
        });
      }
    },
    [addNotification, loadOrganizationLogoOptions]
  );

  const listPath = '/sales/orders';
  const queryReturnTo = getReturnToFromCurrentQuery();
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack =
    !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);
  const onBack = () => router.navigate(listPath);
  const onBackContextual = () =>
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });

  if (!salesOrderId) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium">Invalid URL</p>
          <p className="text-sm text-red-700">Sales order ID is required.</p>
        </div>
        <button
          onClick={onBack}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          Back to Orders
        </button>
      </div>
    );
  }

  if (loading && !so) {
    return (
      <div className="p-6">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
        <p className="mt-4 text-sm text-gray-600">Loading sales order...</p>
      </div>
    );
  }

  if (error || !so) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium">Error</p>
          <p className="text-sm text-red-700">{error || 'Sales order not found'}</p>
        </div>
        <button
          onClick={onBack}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          Back to Orders
        </button>
      </div>
    );
  }

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'lines', label: 'Lines' },
    { id: 'manufacturing', label: 'Manufacturing' },
    { id: 'payments', label: 'Payments' },
    { id: 'timeline', label: 'Timeline' },
  ];

  const soStatus = (so.status || 'draft').toLowerCase();
  const hasPaidAmount = totalPaid > 0;
  const manufacturingProgressCard = (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
      <h3 className="text-sm font-medium text-gray-500 mb-4">Manufacturing Status</h3>
      {mos.length === 0 ? (
        <p className="text-sm text-gray-500">No manufacturing orders yet.</p>
      ) : (
        <div className="space-y-3">
          <div className="relative px-3">
            <div className="absolute left-3 right-3 top-2 border-t border-dashed border-gray-300" />
            <div className="relative flex items-center justify-between">
              {MFG_STATUS_STEPS.map((step, idx) => {
                const isReached = currentMfgStepIndex >= 0 && idx <= currentMfgStepIndex;
                const isCurrent = currentMfgStepIndex === idx;
                return (
                  <div key={step.id} className="flex flex-col items-center gap-2 w-24">
                    <span
                      className={[
                        'w-4 h-4 rounded-full border-2 bg-white',
                        isReached ? 'border-primary' : 'border-gray-300',
                        isCurrent ? 'ring-2 ring-primary/20' : '',
                      ].join(' ')}
                    />
                    <span className={`text-[11px] text-center ${isCurrent ? 'text-primary font-semibold' : 'text-gray-600'}`}>
                      {step.label}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
          <p className="text-xs text-gray-500">
            Current: {currentMfgStepIndex >= 0 ? MFG_STATUS_STEPS[currentMfgStepIndex].label : 'Unknown'}
          </p>
        </div>
      )}
    </div>
  );

  return (
    <DetailPageLayout
      title={so.sales_order_no}
      subtitle="Order Detail"
      status={<StatusBadge status={so.status} type="salesOrder" />}
      paymentStatus={<StatusBadge status={collectionStatus} type="payment" />}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
      contentClassName="pt-2 pb-6"
      actions={
        hasRedirectBack || actionButtons.length > 0 ? (
          <div className="flex items-center gap-2">
            {hasRedirectBack && (
              <button
                type="button"
                onClick={onBackContextual}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                title="Back"
              >
                <ArrowLeft className="w-4 h-4" />
                Back
              </button>
            )}
            {actionButtons.length > 0 && (
              <div className="relative" ref={actionsRef}>
                <button
                  type="button"
                  onClick={() => setActionsOpen(!actionsOpen)}
                  disabled={isActing}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
                >
                  Actions
                  <ChevronDown className="w-4 h-4 text-gray-500" />
                </button>
                {actionsOpen && (
                  <div className="absolute right-0 mt-1 w-48 rounded-md border border-gray-200 bg-white shadow-lg z-10">
                    {actionButtons.map((btn) => (
                      <button
                        key={btn.label}
                        type="button"
                        onClick={btn.onClick}
                        className="block w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 first:rounded-t-md last:rounded-b-md"
                      >
                        {btn.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        ) : undefined
      }
    >
      {activeTab === 'overview' && (
        <div className="space-y-6">
          {/* Row 1: Order Details + Financial Summary */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Order Details</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Quote</dt>
                  <dd>
                    {so.Quotes?.id && so.Quotes?.quote_no ? (
                      <button onClick={() => router.navigate(withReturnTo(`/sales/quotes/${so.Quotes!.id}`))} className="text-primary hover:underline font-medium">
                        {so.Quotes.quote_no}
                      </button>
                    ) : '—'}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Customer</dt>
                  <dd className="font-medium text-gray-900">{so.DirectoryCustomers?.customer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer</dt>
                  <dd className="text-gray-900">{so.Dealers?.dealer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer #</dt>
                  <dd className="font-mono text-gray-900">{so.Dealers?.dealer_no ?? '—'}</dd>
                </div>
                <div className="flex justify-between items-center">
                  <dt className="text-gray-500">Priority</dt>
                  <dd>
                    {so.priority ? (
                      <div className="flex justify-end">
                        <StatusBadge status={so.priority} type="priority" size="sm" />
                      </div>
                    ) : '—'}
                  </dd>
                </div>
              </dl>
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Financial Summary</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Subtotal</dt>
                  <dd className="font-mono">{formatCurrency(so.subtotal ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Tax</dt>
                  <dd className="font-mono">{formatCurrency(so.tax_amount ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Total</dt>
                  <dd className="font-semibold">{formatCurrency(so.total_amount ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-gray-500">Invoiced</dt>
                  <dd className="font-mono">{formatCurrency(financialSummary?.total_invoiced ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Paid</dt>
                  <dd className="font-mono text-green-600">{formatCurrency(totalPaid, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Balance Due</dt>
                  <dd className="font-mono font-semibold">{formatCurrency(receivableBalance, currency)}</dd>
                </div>
              </dl>
            </div>
          </div>

          {/* Row 2: Key Dates */}
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Key Dates</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
              <div>
                <dt className="text-gray-500">Order Date</dt>
                <dd className="font-medium text-gray-900 mt-0.5">{new Date(so.created_at).toLocaleDateString()}</dd>
              </div>
              <div>
                <dt className="text-gray-500">Expected Delivery</dt>
                <dd className="font-medium text-gray-900 mt-0.5">{so.expected_delivery_date ? new Date(so.expected_delivery_date).toLocaleDateString() : '—'}</dd>
              </div>
              <div>
                <dt className="text-gray-500">Completed</dt>
                <dd className="font-medium text-gray-900 mt-0.5">{so.completed_at ? new Date(so.completed_at).toLocaleDateString() : '—'}</dd>
              </div>
              <div>
                <dt className="text-gray-500">Closed</dt>
                <dd className="font-medium text-gray-900 mt-0.5">{so.closed_at ? new Date(so.closed_at).toLocaleDateString() : '—'}</dd>
              </div>
            </div>
          </div>

          {/* Row 3: Materials Status */}
          {isInternal && materialSummary.total > 0 && (
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
                  <Package className="w-4 h-4 text-gray-500" />
                  Materials
                </h3>
              </div>
              {materialSummaryLoading ? (
                <div className="animate-pulse h-8 bg-gray-100 rounded" />
              ) : (
                <div className="flex items-center gap-4">
                  <div className="flex items-center gap-1.5">
                    {materialStatus === 'fulfilled' ? (
                      <CheckCircle2 className="w-4 h-4 text-green-500" />
                    ) : materialStatus === 'partial' ? (
                      <AlertTriangle className="w-4 h-4 text-yellow-500" />
                    ) : (
                      <XCircle className="w-4 h-4 text-red-500" />
                    )}
                    <span className={`text-sm font-medium ${
                      materialStatus === 'fulfilled' ? 'text-green-700' :
                      materialStatus === 'partial' ? 'text-yellow-700' : 'text-red-700'
                    }`}>
                      {materialStatus === 'fulfilled' ? 'All materials covered' :
                       materialStatus === 'partial' ? 'Partially covered' : 'Materials needed'}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-gray-500">
                    <span className="flex items-center gap-1">
                      <span className="inline-block w-2 h-2 rounded-full bg-green-400" />
                      {materialSummary.fulfilled} fulfilled
                    </span>
                    {materialSummary.partial > 0 && (
                      <span className="flex items-center gap-1">
                        <span className="inline-block w-2 h-2 rounded-full bg-yellow-400" />
                        {materialSummary.partial} partial
                      </span>
                    )}
                    {materialSummary.shortage > 0 && (
                      <span className="flex items-center gap-1">
                        <span className="inline-block w-2 h-2 rounded-full bg-red-400" />
                        {materialSummary.shortage} shortage
                      </span>
                    )}
                    <span className="text-gray-400">|</span>
                    <span>{materialSummary.totalAllocated}/{materialSummary.totalRequired} allocated</span>
                    {materialSummary.totalOnOrder > 0 && (
                      <span>{materialSummary.totalOnOrder} on order</span>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Row 4: Manufacturing Status Timeline */}
          {manufacturingProgressCard}
        </div>
      )}

      {activeTab === 'lines' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">#</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Name / SKU</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Product Type</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Width x Height</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Unit Price</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
              </tr>
            </thead>
            <tbody>
              {lines.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                    No lines
                  </td>
                </tr>
              ) : (
                lines.map((line, idx) => {
                  const name =
                    line.description ??
                    (line.collection_name && line.variant_name
                      ? `${line.collection_name} - ${line.variant_name}`
                      : line.collection_name || line.variant_name || line.CatalogItems?.name) ??
                    '—';
                  const dims = [line.width_m, line.height_m].filter((v) => v != null);
                  return (
                    <tr key={line.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-4 text-gray-500 tabular-nums">{line.line_number ?? idx + 1}</td>
                      <td className="px-4 py-4">
                        <div className="text-gray-900">{name}</div>
                        {line.CatalogItems?.sku && (
                          <div className="text-xs text-gray-500">{line.CatalogItems.sku}</div>
                        )}
                      </td>
                      <td className="px-4 py-4 text-gray-700">{line.product_type ?? '—'}</td>
                      <td className="px-4 py-4 text-gray-700">{dims.length === 2 ? `${line.width_m} x ${line.height_m}` : '—'}</td>
                      <td className="px-4 py-4 text-right text-gray-900 tabular-nums">{line.quantity}</td>
                      <td className="px-4 py-4 text-right font-mono text-gray-900">{formatCurrency(line.unit_price ?? 0, currency)}</td>
                      <td className="px-4 py-4 text-right font-mono font-medium text-gray-900">{formatCurrency(line.line_total ?? 0, currency)}</td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'manufacturing' && (
        <div className="space-y-6">
          {/* Row 1: two cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Order Info card — same as Overview and Payments */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Order Info</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Quote</dt>
                  <dd>
                    {so.Quotes?.id && so.Quotes?.quote_no ? (
                      <button type="button" onClick={() => router.navigate(withReturnTo(`/sales/quotes/${so.Quotes!.id}`))}
                        className="text-primary hover:underline font-medium">{so.Quotes.quote_no}</button>
                    ) : '—'}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Customer</dt>
                  <dd className="font-medium text-gray-900">{so.DirectoryCustomers?.customer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer</dt>
                  <dd className="text-gray-900">{so.Dealers?.dealer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer #</dt>
                  <dd className="font-mono text-gray-900">{so.Dealers?.dealer_no ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Order Date</dt>
                  <dd className="font-medium text-gray-900">{new Date(so.created_at).toLocaleDateString()}</dd>
                </div>
                <div className="flex justify-between items-center border-t pt-2">
                  <dt className="text-gray-500">Priority</dt>
                  <dd>{so.priority ? <StatusBadge status={so.priority} type="priority" size="sm" /> : '—'}</dd>
                </div>
              </dl>
            </div>

            {/* Production Summary card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Production Summary</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Total MOs</dt>
                  <dd className="font-medium text-gray-900">{mos.length}</dd>
                </div>
                {(['draft','confirmed','in_progress','delivered','cancelled'] as const).map((s) => {
                  const count = mos.filter((m) => m.status === s).length;
                  if (count === 0) return null;
                  return (
                    <div key={s} className="flex justify-between">
                      <dt className="text-gray-500 capitalize">{s.replace('_', ' ')}</dt>
                      <dd><StatusBadge status={s} type="manufacturing" size="sm" /></dd>
                    </div>
                  );
                })}
                {mos.length === 0 && (
                  <div className="py-2 text-gray-400 text-xs">No manufacturing orders yet</div>
                )}
              </dl>
              {isInternal && ['confirmed', 'draft', 'on_hold'].includes(soStatus) && (
                <div className="mt-4 pt-3 border-t border-gray-100">
                  {!hasPaidAmount && (
                    <p className="text-xs text-amber-600 mb-2">A payment must be recorded in Financials before creating a Manufacturing Order.</p>
                  )}
                  <button
                    type="button"
                    onClick={handleCreateMO}
                    disabled={isActing || !hasPaidAmount}
                    className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    <Factory className="w-4 h-4" />
                    Create Manufacturing Order
                  </button>
                </div>
              )}
            </div>
          </div>

          {manufacturingProgressCard}

          {/* MO Table */}
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">MO #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Type</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Status</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Product</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Priority</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Date</th>
              </tr>
            </thead>
            <tbody>
              {mos.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                    No manufacturing orders
                  </td>
                </tr>
              ) : (
                mos.map((mo) => (
                  <tr
                    key={mo.id}
                    className="border-t hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${mo.id}`))}
                  >
                    <td className="px-4 py-4 font-medium text-primary">{mo.manufacturing_order_no}</td>
                    <td className="px-4 py-4">
                      {mo.mo_type && <StatusBadge status={mo.mo_type} type="moType" size="sm" />}
                    </td>
                    <td className="px-4 py-4"><StatusBadge status={mo.status} type="manufacturing" size="sm" /></td>
                    <td className="px-4 py-4">{mo.product_name ?? '—'}</td>
                    <td className="px-4 py-4 text-right">{mo.quantity}</td>
                    <td className="px-4 py-4">
                      {mo.priority && mo.priority !== 'normal' && (
                        <StatusBadge status={mo.priority} type="priority" size="sm" />
                      )}
                    </td>
                    <td className="px-4 py-4 text-gray-500 text-right">{new Date(mo.created_at).toLocaleDateString()}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          </div>
        </div>
      )}

      {activeTab === 'payments' && (
        <div className="space-y-6">
          {/* Row 1: two cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Order Info card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Order Info</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Quote</dt>
                  <dd>
                    {so.Quotes?.id && so.Quotes?.quote_no ? (
                      <button
                        type="button"
                        onClick={() => router.navigate(withReturnTo(`/sales/quotes/${so.Quotes!.id}`))}
                        className="text-primary hover:underline font-medium"
                      >
                        {so.Quotes.quote_no}
                      </button>
                    ) : '—'}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Customer</dt>
                  <dd className="font-medium text-gray-900">{so.DirectoryCustomers?.customer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer</dt>
                  <dd className="text-gray-900">{so.Dealers?.dealer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer #</dt>
                  <dd className="font-mono text-gray-900">{so.Dealers?.dealer_no ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Order Date</dt>
                  <dd className="font-medium text-gray-900">{new Date(so.created_at).toLocaleDateString()}</dd>
                </div>
                <div className="flex justify-between items-center border-t pt-2">
                  <dt className="text-gray-500">Payment Status</dt>
                  <dd><StatusBadge status={collectionStatus} type="payment" /></dd>
                </div>
              </dl>
            </div>

            {/* Financial Summary card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Financial Summary</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Subtotal</dt>
                  <dd className="font-mono text-gray-900">{formatCurrency(so.subtotal ?? 0, currency)}</dd>
                </div>
                {(so.discount_amount ?? 0) > 0 && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Discount</dt>
                    <dd className="font-mono text-gray-900">−{formatCurrency(so.discount_amount ?? 0, currency)}</dd>
                  </div>
                )}
                <div className="flex justify-between">
                  <dt className="text-gray-500">Tax</dt>
                  <dd className="font-mono text-gray-900">{formatCurrency(so.tax_amount ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <dt className="font-medium text-gray-700">Order Total</dt>
                  <dd className="font-semibold font-mono text-gray-900">{formatCurrency(so.total_amount ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Total Invoiced</dt>
                  <dd className="font-mono text-gray-900">{formatCurrency(financialSummary?.total_invoiced ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Total Paid</dt>
                  <dd className={`font-mono font-medium ${totalPaid > 0 ? 'text-green-600' : 'text-gray-500'}`}>
                    {formatCurrency(totalPaid, currency)}
                  </dd>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <dt className="font-medium text-gray-700">Billable Remaining</dt>
                  <dd className={`font-semibold font-mono ${billableRemaining > 0 ? 'text-red-600' : 'text-green-600'}`}>
                    {formatCurrency(billableRemaining, currency)}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="font-medium text-gray-700">Receivable Balance</dt>
                  <dd className={`font-semibold font-mono ${receivableBalance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                    {formatCurrency(receivableBalance, currency)}
                  </dd>
                </div>
              </dl>
              <div className="mt-4 pt-3 border-t border-gray-100 space-y-2">
                {canCreateInvoice ? (
                  <button
                    type="button"
                    onClick={() => router.navigate(withReturnTo(`/financials/invoices/new?sales_order_id=${so.id}`))}
                    className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                  >
                    <FileText className="w-4 h-4" />
                    Create Invoice
                  </button>
                ) : (
                  <div className="w-full px-3 py-2 text-xs text-green-700 bg-green-50 border border-green-200 rounded-lg text-center">
                    Fully invoiced / No billable remaining
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Invoices list */}
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
            <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
              <h3 className="text-sm font-semibold text-gray-900">Invoice List</h3>
            </div>
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Invoice #</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Issue Date</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
                  <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
                  <th className="px-4 py-3 text-center font-medium text-gray-700">View</th>
                </tr>
              </thead>
              <tbody>
                {linkedInvoices.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-gray-500">No invoices for this order</td>
                  </tr>
                ) : (
                  linkedInvoices.map((inv) => (
                    <tr key={inv.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-4">
                        {isInternal ? (
                          <button
                            type="button"
                            onClick={() => router.navigate(withReturnTo(`/financials/invoices/${inv.id}`))}
                            className="text-primary hover:underline font-medium"
                          >
                            {inv.invoice_number}
                          </button>
                        ) : (
                          <span className="font-medium text-gray-700">{inv.invoice_number}</span>
                        )}
                      </td>
                      <td className="px-4 py-4 text-gray-700">{new Date(inv.issue_date).toLocaleDateString()}</td>
                      <td className="px-4 py-4 text-right font-mono text-gray-900">{formatCurrency(inv.total, inv.currency_code || currency)}</td>
                      <td className="px-4 py-4 text-center">
                        <StatusBadge status={inv.status} type="invoice" size="sm" />
                      </td>
                      <td className="px-4 py-4 text-center">
                        {isInternal ? (
                          <button
                            type="button"
                            onClick={() => {
                              void handlePreviewInvoicePdf(inv.id);
                            }}
                            className="inline-flex items-center justify-center p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                            title="View invoice PDF"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

        </div>
      )}

      {activeTab === 'timeline' && (
        <TimelineView events={timeline} loading={loading && timeline.length === 0} emptyMessage="No activity yet" />
      )}
    </DetailPageLayout>
  );
}
