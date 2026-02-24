import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useAuth } from '../../hooks/useAuth';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import TimelineView from '../../components/shared/TimelineView';
import LifecycleIndicator from '../../components/shared/LifecycleIndicator';
import { router } from '../../lib/router';
import { formatCurrency } from '../../lib/utils';
import { useSOActions } from '../../hooks/useSOActions';
import { usePayments, useRecordPayment } from '../../hooks/usePayments';
import Input from '../../components/ui/Input';
import { ChevronDown, Plus, FileText, ShoppingBag } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

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
  payment_status: string;
  customer_id: string;
  dealer_id: string;
  total_amount: number;
  amount_paid: number;
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

interface SalesOrderLine {
  id: string;
  sales_order_id: string;
  line_number: number | null;
  description: string | null;
  collection_name: string | null;
  variant_name: string | null;
  quantity: number;
  unit_price: number | null;
  line_total: number | null;
  CatalogItems?: { item_name: string; sku: string } | null;
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

  const [so, setSo] = useState<SalesOrder | null>(null);
  const [lines, setLines] = useState<SalesOrderLine[]>([]);
  const [mos, setMos] = useState<ManufacturingOrder[]>([]);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('overview');
  const [actionsOpen, setActionsOpen] = useState(false);
  const [paymentFormOpen, setPaymentFormOpen] = useState(false);
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('check');
  const [paymentReference, setPaymentReference] = useState('');
  const [submittingPayment, setSubmittingPayment] = useState(false);
  const actionsRef = useRef<HTMLDivElement>(null);

  const { payments, loading: paymentsLoading, refetch: refetchPayments } = usePayments(salesOrderId);
  const { transitionSOStatus, createMO, isActing } = useSOActions();
  const { recordPayment, isRecording } = useRecordPayment();
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Sales', SALES_SUBMODULES);
  }, [registerSubmodules]);

  const refetch = useCallback(async () => {
    if (!salesOrderId || !activeOrganizationId) return;
    setLoading(true);
    setError(null);
    try {
      const [soRes, linesRes, mosRes, timelineRes] = await Promise.all([
        supabase
          .from('SalesOrders')
          .select(`
            id, sales_order_no, quote_id, status, status_before_cancel, payment_status, customer_id, dealer_id,
            total_amount, amount_paid, subtotal, tax_amount, discount_amount,
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
            quantity, unit_price, line_total,
            CatalogItems:catalog_item_id (item_name, sku)
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
      ]);

      if (soRes.error) throw soRes.error;

      setSo(soRes.data as SalesOrder);

      if (linesRes.error) {
        if (import.meta.env.DEV) console.warn('[SalesOrderDetail] SaleOrderLines error:', linesRes.error);
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
        router.navigate(`/manufacturing/manufacturing-orders/${result.mo_id}`);
      } else {
        refetch();
      }
    } catch {
      // useSOActions already shows notification
    }
  }, [salesOrderId, user, createMO, refetch]);

  const handleRecordPayment = useCallback(async () => {
    if (!salesOrderId || !user?.id) return;
    const amount = parseFloat(paymentAmount);
    if (isNaN(amount) || amount <= 0) {
      addNotification({ type: 'error', title: 'Invalid amount', message: 'Enter a valid amount.' });
      return;
    }
    setSubmittingPayment(true);
    try {
      await recordPayment(salesOrderId, amount, paymentMethod, paymentReference, user.id, user.name);
      setPaymentAmount('');
      setPaymentReference('');
      setPaymentFormOpen(false);
      refetch();
      refetchPayments();
    } catch {
      // useRecordPayment shows notification
    } finally {
      setSubmittingPayment(false);
    }
  }, [salesOrderId, user, paymentAmount, paymentMethod, paymentReference, recordPayment, refetch, refetchPayments, addNotification]);

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

  const currency = 'USD';
  const balance = (so?.total_amount ?? 0) - (so?.amount_paid ?? 0);
  const totalPaid = payments.reduce((sum, p) => sum + Number(p.amount), 0);

  const onBack = () => router.navigate('/sales/orders');

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
    { id: 'lines', label: 'Lines', count: lines.length },
    { id: 'manufacturing', label: 'Manufacturing', count: mos.length },
    { id: 'payments', label: 'Payments', count: payments.length },
    { id: 'timeline', label: 'Timeline' },
  ];

  const summaryItems = [
    {
      label: 'Quote',
      value: so.Quotes?.id && so.Quotes?.quote_no ? (
        <button onClick={() => router.navigate(`/sales/quotes/${so.Quotes!.id}`)} className="text-primary hover:underline">
          {so.Quotes.quote_no}
        </button>
      ) : (
        '—'
      ),
    },
    { label: 'Dealer', value: so.Dealers?.dealer_name ?? '—' },
    { label: 'Dealer #', value: so.Dealers?.dealer_no ?? '—' },
    { label: 'Total', value: formatCurrency(so.total_amount ?? 0, currency) },
    { label: 'Paid', value: formatCurrency(so.amount_paid ?? 0, currency) },
    { label: 'Balance', value: formatCurrency(balance, currency) },
    { label: 'Priority', value: so.priority ? <StatusBadge status={so.priority} type="priority" size="sm" /> : '—' },
    { label: 'Order Date', value: new Date(so.created_at).toLocaleDateString() },
  ];

  const lifecycleStages = [
    { label: 'Quote', ref: so.Quotes?.quote_no, href: so.Quotes?.id ? `/sales/quotes/${so.Quotes.id}` : undefined },
    { label: 'Proposal', ref: 'Accepted' },
    { label: 'SO', ref: so.sales_order_no },
    { label: 'Manufacturing', ref: mos.length > 0 ? `${mos.length} MO${mos.length > 1 ? 's' : ''}` : undefined, count: mos.length },
  ];

  return (
    <DetailPageLayout
      title={so.sales_order_no}
      subtitle="Sales Order"
      status={<StatusBadge status={so.status} type="salesOrder" />}
      paymentStatus={<StatusBadge status={so.payment_status || 'pending'} type="payment" />}
      summaryItems={summaryItems}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
      actions={
        actionButtons.length > 0 ? (
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
        ) : undefined
      }
    >
      {activeTab === 'overview' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
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
                  <dt className="text-gray-500">Paid</dt>
                  <dd className="font-mono text-green-600">{formatCurrency(so.amount_paid ?? 0, currency)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Balance Due</dt>
                  <dd className="font-mono font-semibold">{formatCurrency(balance, currency)}</dd>
                </div>
              </dl>
            </div>
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Key Dates</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Order Date</dt>
                  <dd>{new Date(so.created_at).toLocaleDateString()}</dd>
                </div>
                {so.expected_delivery_date && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Expected Delivery</dt>
                    <dd>{new Date(so.expected_delivery_date).toLocaleDateString()}</dd>
                  </div>
                )}
                {so.completed_at && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Completed</dt>
                    <dd>{new Date(so.completed_at).toLocaleDateString()}</dd>
                  </div>
                )}
                {so.closed_at && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Closed</dt>
                    <dd>{new Date(so.closed_at).toLocaleDateString()}</dd>
                  </div>
                )}
              </dl>
            </div>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Lifecycle</h3>
            <LifecycleIndicator currentStage="sales_order" stages={lifecycleStages} />
          </div>
        </div>
      )}

      {activeTab === 'lines' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Line #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Description</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">SKU</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Unit Price</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
              </tr>
            </thead>
            <tbody>
              {lines.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                    No lines
                  </td>
                </tr>
              ) : (
                lines.map((line, idx) => (
                  <tr key={line.id} className="border-t hover:bg-gray-50">
                    <td className="px-4 py-3">{line.line_number ?? idx + 1}</td>
                    <td className="px-4 py-3">{line.description ?? line.CatalogItems?.item_name ?? '—'}</td>
                    <td className="px-4 py-3">{line.CatalogItems?.sku ?? '—'}</td>
                    <td className="px-4 py-3 text-right">{line.quantity}</td>
                    <td className="px-4 py-3 text-right font-mono">{formatCurrency(line.unit_price ?? 0, currency)}</td>
                    <td className="px-4 py-3 text-right font-mono">{formatCurrency(line.line_total ?? 0, currency)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'manufacturing' && (
        <div className="space-y-4">
          {(so.status === 'confirmed' || so.status === 'draft') && isInternal && (
            <button
              type="button"
              onClick={handleCreateMO}
              disabled={isActing}
              className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
            >
              <Plus className="w-4 h-4" />
              Create Manufacturing Order
            </button>
          )}
          <div className="rounded-lg border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">MO #</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Type</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Status</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Product</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Priority</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
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
                      onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                    >
                      <td className="px-4 py-3 font-medium text-primary">{mo.manufacturing_order_no}</td>
                      <td className="px-4 py-3">
                        {mo.mo_type && <StatusBadge status={mo.mo_type} type="moType" size="sm" />}
                      </td>
                      <td className="px-4 py-3"><StatusBadge status={mo.status} type="manufacturing" size="sm" /></td>
                      <td className="px-4 py-3">{mo.product_name ?? '—'}</td>
                      <td className="px-4 py-3 text-right">{mo.quantity}</td>
                      <td className="px-4 py-3">
                        {mo.priority && mo.priority !== 'normal' && (
                          <StatusBadge status={mo.priority} type="priority" size="sm" />
                        )}
                      </td>
                      <td className="px-4 py-3 text-gray-500">{new Date(mo.created_at).toLocaleDateString()}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'payments' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="text-sm">
              <span className="text-gray-500">Total Paid: </span>
              <span className="font-semibold">{formatCurrency(totalPaid, currency)}</span>
              <span className="text-gray-500 ml-4">Balance: </span>
              <span className="font-semibold">{formatCurrency(balance, currency)}</span>
            </div>
            {!['closed', 'cancelled'].includes((so.status || '').toLowerCase()) && (
              <button
                type="button"
                onClick={() => setPaymentFormOpen(!paymentFormOpen)}
                className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
              >
                <Plus className="w-4 h-4" />
                Record Payment
              </button>
            )}
          </div>
          {paymentFormOpen && (
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 space-y-3">
              <h4 className="text-sm font-medium text-gray-900">Record Payment</h4>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Amount</label>
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    value={paymentAmount}
                    onChange={(e) => setPaymentAmount(e.target.value)}
                    placeholder="0.00"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Method</label>
                  <select
                    value={paymentMethod}
                    onChange={(e) => setPaymentMethod(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg"
                  >
                    <option value="check">Check</option>
                    <option value="wire">Wire</option>
                    <option value="card">Card</option>
                    <option value="cash">Cash</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Reference</label>
                  <Input
                    value={paymentReference}
                    onChange={(e) => setPaymentReference(e.target.value)}
                    placeholder="Check #, transaction ID..."
                  />
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={handleRecordPayment}
                  disabled={submittingPayment || isRecording}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
                >
                  {submittingPayment || isRecording ? 'Recording...' : 'Submit'}
                </button>
                <button
                  type="button"
                  onClick={() => { setPaymentFormOpen(false); setPaymentAmount(''); setPaymentReference(''); }}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
          <div className="rounded-lg border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Date</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700">Amount</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Method</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Reference</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Recorded By</th>
                </tr>
              </thead>
              <tbody>
                {paymentsLoading ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                      Loading...
                    </td>
                  </tr>
                ) : payments.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                      No payments recorded
                    </td>
                  </tr>
                ) : (
                  payments.map((p) => (
                    <tr key={p.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-3">{new Date(p.payment_date || p.created_at).toLocaleDateString()}</td>
                      <td className="px-4 py-3 text-right font-mono">{formatCurrency(p.amount, currency)}</td>
                      <td className="px-4 py-3">{p.payment_method ?? '—'}</td>
                      <td className="px-4 py-3">{p.reference_number ?? '—'}</td>
                      <td className="px-4 py-3">—</td>
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
