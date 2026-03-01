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
import { usePayments } from '../../hooks/usePayments';
import { ChevronDown, Plus, FileText, ShoppingBag, CreditCard, Factory, Package, CheckCircle2, AlertTriangle, XCircle, ArrowLeft } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useSOFulfillmentSummary } from '../../hooks/useInventoryAllocations';

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

interface Payment {
  id: string;
  amount: number;
  payment_method: string;
  reference_number: string | null;
  payment_date: string;
  recorded_by: string | null;
  created_at: string;
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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('overview');
  const [actionsOpen, setActionsOpen] = useState(false);
  const actionsRef = useRef<HTMLDivElement>(null);

  const { payments, loading: paymentsLoading, refetch: refetchPayments } = usePayments(salesOrderId);
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
      const [soRes, linesRes, mosRes, timelineRes, financialRes] = await Promise.all([
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
    refetchPayments();
  }, [refetchPayments, salesOrderId]);

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
  const totalPaid = financialSummary?.total_paid ?? payments.reduce((sum, p) => sum + Number(p.amount), 0);
  const balance = financialSummary?.balance_due ?? (so?.total_amount ?? 0) - totalPaid;

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
  const invoiceStatus = financialSummary?.invoice_status ?? 'none';
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
      paymentStatus={invoiceStatus !== 'none' ? <StatusBadge status={invoiceStatus} type="payment" /> : undefined}
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
                  <dd className="font-mono font-semibold">{formatCurrency(balance, currency)}</dd>
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
                  <dt className="text-gray-500">Invoice Status</dt>
                  <dd>
                    {invoiceStatus !== 'none'
                      ? <StatusBadge status={invoiceStatus} type="payment" />
                      : <span className="text-gray-400 text-xs">No invoice</span>}
                  </dd>
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
                  <dt className="font-medium text-gray-700">Balance Due</dt>
                  <dd className={`font-semibold font-mono ${balance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                    {formatCurrency(balance, currency)}
                  </dd>
                </div>
              </dl>
              <div className="mt-4 pt-3 border-t border-gray-100 space-y-2">
                {financialSummary?.latest_invoice_id && (
                  <button
                    type="button"
                    onClick={() => router.navigate(withReturnTo(`/financials/invoices/${financialSummary.latest_invoice_id}`))}
                    className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                  >
                    View Invoice {financialSummary.latest_invoice_number}
                  </button>
                )}
                <a
                  href="/financials/payments?new=1"
                  onClick={(e) => {
                    e.preventDefault();
                    sessionStorage.setItem(
                      'financials_payment_prefill',
                      JSON.stringify({
                        source: 'sales_order',
                        sales_order_id: so.id,
                        sales_order_no: so.sales_order_no,
                        dealer_id: so.dealer_id ?? null,
                      })
                    );
                    router.navigate(withReturnTo('/financials/payments?new=1'));
                  }}
                  className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                >
                  <Plus className="w-4 h-4" />
                  Add Payment
                </a>
              </div>
            </div>
          </div>

          {/* Payments table */}
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700">Amount</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Method</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Reference</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Bank</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Description</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Recorded By</th>
                </tr>
              </thead>
              <tbody>
                {paymentsLoading ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-gray-500">Loading...</td>
                  </tr>
                ) : payments.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-gray-500">No payments recorded</td>
                  </tr>
                ) : (
                  payments.map((p) => (
                    <tr key={p.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-4">{new Date(p.payment_date || p.created_at).toLocaleDateString()}</td>
                      <td className="px-4 py-4 text-right font-mono">{formatCurrency(p.amount, currency)}</td>
                      <td className="px-4 py-4">{p.payment_method ?? '—'}</td>
                      <td className="px-4 py-4">{p.reference_number ?? '—'}</td>
                      <td className="px-4 py-4">{p.bank_name ?? '—'}</td>
                      <td className="px-4 py-4 max-w-[12rem] truncate" title={p.description ?? undefined}>{p.description ?? '—'}</td>
                      <td className="px-4 py-4">—</td>
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
