import { useEffect, useState, useCallback } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useManufacturingOrder, useManufacturingMaterials, useTransitionMOStatus, useMoMaterialReadiness } from '../../hooks/useManufacturing';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useUIStore } from '../../stores/ui-store';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useModuleAccess, usePermissions } from '../../hooks/usePermissions';
import { useAuth } from '../../hooks/useAuth';
import { useIssueMaterials } from '../../hooks/useInventoryMovements';
import { useWarehouses } from '../../hooks/useWarehouses';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import MaterialsTab from '../../components/manufacturing/tabs/MaterialsTab';
import { CheckCircle, Circle, Clock } from 'lucide-react';
import ScheduleTab from '../../components/manufacturing/tabs/ScheduleTab';
import NotesTab from '../../components/manufacturing/tabs/NotesTab';
import AttachmentsTab from '../../components/manufacturing/tabs/AttachmentsTab';
import WorkOrdersTab from './WorkOrdersTab';
import TimelineView from '../../components/shared/TimelineView';
import { ChevronDown } from 'lucide-react';
import { normalizeUUID } from '../../utils/uuid';
import { formatCurrency, formatDate } from '../../lib/utils';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';

interface ManufacturingOrderDetailProps {
  moId?: string;
}

interface TimelineEvent {
  id: string;
  action: string;
  description: string;
  user_name: string | null;
  created_at: string;
  metadata?: Record<string, any> | null;
}

interface MOLine {
  id: string;
  sales_order_line_id: string | null;
  status: string;
  quantity: number;
  SaleOrderLine?: {
    description: string | null;
    collection_name: string | null;
    variant_name: string | null;
    product_type: string | null;
    hardware_color: string | null;
    area: string | null;
    position: string | null;
    quantity: number;
    unit_price: number | null;
    CatalogItems?: { name: string; sku: string; manufacturer: string | null } | null;
  } | null;
}

export default function ManufacturingOrderDetail({ moId: propMoId }: ManufacturingOrderDetailProps) {
  const normalizedPropMoId = propMoId ? normalizeUUID(propMoId) : null;
  const [moId, setMoId] = useState<string | null>(normalizedPropMoId);
  const { manufacturingOrder: mo, loading, error, refetch } = useManufacturingOrder(moId);
  const { materials } = useManufacturingMaterials(moId ?? '');
  const { readiness: materialReadiness } = useMoMaterialReadiness(moId);
  const { transitionStatus, isTransitioning } = useTransitionMOStatus();
  const { issueMaterials } = useIssueMaterials();
  const { defaultWarehouse } = useWarehouses(mo?.organization_id ?? null);
  const mfgSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);
  const { isInternal } = useAccessContext();
  const { canEdit: canEditInventory } = useModuleAccess('inventory');
  const { can } = usePermissions();
  const { user } = useAuth();

  const [activeTab, setActiveTab] = useState('overview');
  const [actionsOpen, setActionsOpen] = useState(false);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [moLines, setMoLines] = useState<MOLine[]>([]);
  const [cancelReason, setCancelReason] = useState('');
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [taskProgress, setTaskProgress] = useState<{ total: number; completed: number; inProgress: number }>({ total: 0, completed: 0, inProgress: 0 });
  const [financialSummary, setFinancialSummary] = useState<{
    total_invoiced: number;
    total_paid: number;
    balance_due: number;
    invoice_status: string;
    has_delivery_override: boolean;
  } | null>(null);
  const listPath = '/manufacturing/manufacturing-orders';
  const canReadOverview = can('manufacturing.mo.overview.read');
  const canReadLines = can('manufacturing.mo.lines.read');
  const canReadMaterials = can('manufacturing.mo.materials.read');
  const canReadWorkOrders = can('manufacturing.mo.work_orders.read');
  const canReadSchedule = can('manufacturing.mo.schedule.read');
  const canReadNotes = can('manufacturing.mo.notes.read');
  const canReadTimeline = can('manufacturing.mo.timeline.read');
  const canReadAttachments = can('manufacturing.mo.attachments.read');
  const canWriteOverview = can('manufacturing.mo.overview.write');
  const canWriteSchedule = can('manufacturing.mo.schedule.write');
  const canWriteNotes = can('manufacturing.mo.notes.write');
  const canWriteAttachments = can('manufacturing.mo.attachments.write');
  const tabs = [
    canReadOverview ? { id: 'overview', label: 'Overview' } : null,
    canReadLines ? { id: 'lines', label: 'Lines', count: moLines.length } : null,
    canReadMaterials ? { id: 'materials', label: 'Materials', count: materials.length } : null,
    canReadWorkOrders ? { id: 'work-orders', label: 'Work Orders' } : null,
    canReadSchedule ? { id: 'schedule', label: 'Schedule' } : null,
    canReadNotes ? { id: 'notes', label: 'Notes' } : null,
    canReadTimeline ? { id: 'timeline', label: 'Timeline', count: timeline.length } : null,
    canReadAttachments ? { id: 'attachments', label: 'Attachments' } : null,
  ].filter(Boolean) as Array<{ id: string; label: string; count?: number }>;
  const queryReturnTo = getReturnToFromCurrentQuery();
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack =
    !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);
  const onBack = useCallback(() => {
    router.navigate(listPath);
  }, []);
  const onBackContextual = useCallback(() => {
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });
  }, [queryReturnTo]);

  useEffect(() => { registerSubmodules('Manufacturing', mfgSubmodules); }, [registerSubmodules, mfgSubmodules]);
  useEffect(() => {
    if (tabs.length === 0) return;
    if (!tabs.some((tab) => tab.id === activeTab)) {
      setActiveTab(tabs[0].id);
    }
  }, [tabs, activeTab]);

  useEffect(() => {
    if (!moId) {
      const path = window.location.pathname;
      const match = path.match(/\/manufacturing\/manufacturing-orders\/([^/]+)/);
      if (match) {
        const normalized = normalizeUUID(match[1]);
        if (normalized) { setMoId(normalized); sessionStorage.setItem('currentManufacturingOrderId', normalized); }
      } else {
        const stored = sessionStorage.getItem('currentManufacturingOrderId');
        if (stored) { const n = normalizeUUID(stored); if (n) setMoId(n); }
      }
    }
  }, [moId]);

  const fetchTimeline = useCallback(async () => {
    if (!moId) return;
    const { data } = await supabase
      .from('ActivityTimeline')
      .select('id, action, description, user_name, created_at, metadata')
      .eq('entity_type', 'manufacturing_order')
      .eq('entity_id', moId)
      .order('created_at', { ascending: false });
    setTimeline((data ?? []) as TimelineEvent[]);
  }, [moId]);

  const fetchMOLines = useCallback(async () => {
    if (!moId) return;
    const { data: molData } = await supabase
      .from('ManufacturingOrderLines')
      .select('id, sales_order_line_id, status, quantity')
      .eq('manufacturing_order_id', moId)
      .eq('deleted', false)
      .order('created_at', { ascending: true });
    if (!molData || molData.length === 0) { setMoLines([]); return; }

    const solIds = [...new Set(molData.map((m: any) => m.sales_order_line_id).filter(Boolean))];
    let solMap = new Map<string, any>();
    if (solIds.length > 0) {
      const { data: solData } = await supabase
        .from('SaleOrderLines')
        .select('id, description, collection_name, variant_name, product_type, hardware_color, area, position, quantity, unit_price, catalog_item_id')
        .in('id', solIds);
      if (solData) {
        const catIds = [...new Set(solData.map((s: any) => s.catalog_item_id).filter(Boolean))];
        let catMap = new Map<string, any>();
        if (catIds.length > 0) {
          const { data: catData } = await supabase.from('CatalogItems').select('id, name, sku, manufacturer').in('id', catIds);
          if (catData) catMap = new Map(catData.map((c: any) => [c.id, c]));
        }
        solMap = new Map(solData.map((s: any) => [s.id, { ...s, CatalogItems: s.catalog_item_id ? catMap.get(s.catalog_item_id) ?? null : null }]));
      }
    }

    setMoLines(molData.map((m: any) => ({
      ...m,
      SaleOrderLine: solMap.get(m.sales_order_line_id) ?? null,
    })));
  }, [moId]);

  const fetchTaskProgress = useCallback(async () => {
    if (!moId) return;
    const { data } = await supabase
      .from('WorkOrderTasks')
      .select('status')
      .eq('manufacturing_order_id', moId)
      .eq('deleted', false);
    if (data) {
      setTaskProgress({
        total: data.length,
        completed: data.filter((t: any) => t.status === 'completed').length,
        inProgress: data.filter((t: any) => t.status === 'in_progress').length,
      });
    }
  }, [moId]);

  const fetchFinancialSummary = useCallback(async () => {
    if (!mo?.sales_order_id) { setFinancialSummary(null); return; }
    const [summaryRes, soRes, overrideRes] = await Promise.all([
      supabase
        .from('sales_order_financial_summary')
        .select('total_invoiced, total_paid, balance_due, invoice_status')
        .eq('sales_order_id', mo.sales_order_id)
        .maybeSingle(),
      supabase
        .from('SalesOrders')
        .select('total_amount')
        .eq('id', mo.sales_order_id)
        .maybeSingle(),
      supabase
        .from('SalesOrderDeliveryOverrides')
        .select('id')
        .eq('sales_order_id', mo.sales_order_id)
        .eq('status', 'active')
        .eq('deleted', false)
        .limit(1),
    ]);

    const summaryData = (summaryRes.data ?? null) as {
      total_invoiced?: number | null;
      total_paid?: number | null;
      balance_due?: number | null;
      invoice_status?: string | null;
    } | null;
    const soTotal = Number((soRes.data as { total_amount?: number | null } | null)?.total_amount ?? 0);
    const fallbackBalance = Math.max(soTotal, 0);

    setFinancialSummary({
      total_invoiced: Number(summaryData?.total_invoiced ?? soTotal),
      total_paid: Number(summaryData?.total_paid ?? 0),
      balance_due: Number(summaryData?.balance_due ?? fallbackBalance),
      invoice_status: summaryData?.invoice_status ?? (soTotal > 0 ? 'issued' : 'none'),
      has_delivery_override: (overrideRes.data ?? []).length > 0,
    });
  }, [mo?.sales_order_id]);

  useEffect(() => { fetchTimeline(); fetchMOLines(); fetchTaskProgress(); }, [fetchTimeline, fetchMOLines, fetchTaskProgress]);
  useEffect(() => { fetchFinancialSummary(); }, [fetchFinancialSummary]);

  const handleTransition = useCallback(async (newStatus: string) => {
    if (!moId || !user?.id) return;
    setActionsOpen(false);
    try {
      await transitionStatus(moId, newStatus, user.id, user.name);
      addNotification({ type: 'success', title: 'Status Updated', message: `MO moved to ${newStatus.replace(/_/g, ' ')}.` });

      if (newStatus === 'in_production') {
        if (defaultWarehouse) {
          try {
            const result = await issueMaterials(moId, defaultWarehouse.id);
            if (result?.skipped) {
              addNotification({ type: 'info', title: 'Materials', message: 'Materials were already issued for this MO.' });
            } else if (result?.lines_count > 0) {
              addNotification({ type: 'success', title: 'Materials Issued', message: `${result.lines_count} material(s) issued to production (${result.movement_no}).` });
            }
          } catch (issueErr: unknown) {
            addNotification({ type: 'warning', title: 'Materials Issue Warning', message: issueErr instanceof Error ? issueErr.message : 'Could not auto-issue materials.' });
          }
        }

        try {
          const { data: woTasks } = await supabase
            .from('WorkOrderTasks')
            .select('id, status, depends_on_task_ids, assigned_to_user_id')
            .eq('manufacturing_order_id', moId)
            .eq('deleted', false)
            .eq('status', 'pending');

          if (woTasks && woTasks.length > 0) {
            const now = new Date().toISOString();
            const firstTasks = woTasks.filter((t: any) => {
              const deps = t.depends_on_task_ids ?? [];
              return deps.length === 0 && Boolean(t.assigned_to_user_id);
            });
            if (firstTasks.length > 0) {
              const ids = firstTasks.map((t: any) => t.id);
              await supabase
                .from('WorkOrderTasks')
                .update({ status: 'in_progress', started_at: now, updated_at: now })
                .in('id', ids);
              addNotification({ type: 'info', title: 'Work Orders', message: `${firstTasks.length} task(s) auto-started.` });
            }
          }
        } catch {
          // non-critical
        }
      }

      refetch();
      fetchTimeline();
    } catch (e: unknown) {
      const rawMessage = e instanceof Error ? e.message : 'Failed to update status';
      const normalized = rawMessage.toLowerCase();

      // Compatibility fallback for environments where "confirmed" is not yet available in DB enum/policy.
      if (
        newStatus === 'confirmed' &&
        (normalized.includes('invalid input value for enum') ||
          normalized.includes('invalid transition'))
      ) {
        try {
          await transitionStatus(moId, 'planned', user.id, user.name);
          addNotification({
            type: 'success',
            title: 'Status Updated',
            message: 'MO moved to planned (reviewed).',
          });
          refetch();
          fetchTimeline();
          return;
        } catch (fallbackError: unknown) {
          const fallbackMessage = fallbackError instanceof Error ? fallbackError.message : rawMessage;
          addNotification({ type: 'error', title: 'Error', message: fallbackMessage });
          return;
        }
      }

      addNotification({ type: 'error', title: 'Error', message: rawMessage });
    }
  }, [moId, user, transitionStatus, refetch, fetchTimeline, addNotification, issueMaterials, defaultWarehouse]);

  const handleCancel = useCallback(async () => {
    if (!moId || !user?.id) return;
    setShowCancelDialog(false);
    try {
      await transitionStatus(moId, 'cancelled', user.id, user.name);
      addNotification({ type: 'success', title: 'MO Cancelled', message: 'Manufacturing order has been cancelled.' });
      refetch();
      fetchTimeline();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to cancel MO' });
    }
  }, [moId, user, transitionStatus, refetch, fetchTimeline, addNotification]);

  if (!moId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-700">Manufacturing order ID is required</p>
        </div>
        <button onClick={onBack}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Manufacturing Orders
        </button>
      </div>
    );
  }

  if (loading && !mo) {
    return <div className="p-6"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" /></div>;
  }

  if (error || !mo) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-700">{error || 'Manufacturing order not found'}</p>
        </div>
        <button onClick={onBack}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Manufacturing Orders
        </button>
      </div>
    );
  }

  const status = mo.status;
  const so = mo.SalesOrders;
  const customer = so?.DirectoryCustomers?.customer_name ?? '—';

  const materialsIncomplete = materialReadiness?.hasShortage === true;
  const paymentComplete = financialSummary ? financialSummary.balance_due <= 0 : false;
  const hasDeliveryOverride = financialSummary?.has_delivery_override === true;
  const deliveryBlocked = !!financialSummary && financialSummary.balance_due > 0 && !hasDeliveryOverride;
  const paymentStatus: 'not_invoiced' | 'unpaid' | 'partial' | 'paid' =
    !financialSummary || financialSummary.invoice_status === 'none' ? 'not_invoiced' :
    financialSummary.total_paid <= 0 ? 'unpaid' :
    financialSummary.balance_due > 0 ? 'partial' : 'paid';

  const actionItems: { label: string; onClick: () => void; danger?: boolean; disabled?: boolean; title?: string }[] = [];
  if (isInternal && canWriteOverview && status !== 'cancelled' && status !== 'delivered' && status !== 'completed') {
    if (status === 'draft') {
      actionItems.push({
        label: 'Mark as Reviewed',
        onClick: () => handleTransition('confirmed'),
      });
    }
    if (status === 'confirmed') {
      actionItems.push({
        label: 'Buy Materials',
        onClick: () => router.navigate(`/inventory/material-demand?mo_id=${moId}`),
      });
    }
    if (status === 'procurement') {
      actionItems.push({
        label: 'Check Material Readiness',
        onClick: () => handleTransition('materials_ready'),
        disabled: materialsIncomplete,
        title: materialsIncomplete ? 'Materials still incomplete. Receive pending Purchase Orders first.' : undefined,
      });
    }
    if (status === 'materials_ready' || status === 'planned') {
      actionItems.push({
        label: 'Start Production',
        onClick: () => handleTransition('in_production'),
        disabled: materialsIncomplete,
        title: materialsIncomplete ? 'Materials incomplete. Cannot start production.' : undefined,
      });
    }
    if (status === 'in_production') actionItems.push({ label: 'Send to QC', onClick: () => handleTransition('quality_check') });
    if (status === 'quality_check') {
      actionItems.push({
        label: 'Ready for Pickup',
        onClick: () => handleTransition('ready_for_pickup'),
      });
    }
    if (status === 'ready_for_pickup') {
      actionItems.push({
        label: 'Mark Delivered',
        onClick: () => handleTransition('delivered'),
        disabled: deliveryBlocked,
        title: deliveryBlocked ? `Delivery blocked: balance due is $${financialSummary?.balance_due?.toFixed(2) ?? '?'} (must be 0.00) unless Financials issues an override.` : undefined,
      });
    }
    if (['draft', 'confirmed', 'procurement', 'materials_ready', 'planned', 'in_production'].includes(status) && materials.length > 0 && canEditInventory) {
      if (status !== 'confirmed') {
        actionItems.push({ label: 'Buy Materials', onClick: () => router.navigate(`/inventory/material-demand?mo_id=${moId}`) });
      }
    }
    if (['draft', 'confirmed', 'procurement', 'materials_ready', 'planned', 'in_production'].includes(status)) {
      actionItems.push({ label: 'Cancel MO', onClick: () => setShowCancelDialog(true), danger: true });
    }
  }

  if (tabs.length === 0) {
    return (
      <div className="py-6 px-6">
        <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-4">
          <p className="text-sm font-medium text-yellow-800">No permission</p>
          <p className="text-sm text-yellow-700 mt-1">
            You can access Manufacturing Orders, but you do not have access to any detail sub-tab.
          </p>
        </div>
      </div>
    );
  }

  return (
    <DetailPageLayout
      title={mo.manufacturing_order_no}
      subtitle="Manufacturing Order"
      status={
        <div className="flex items-center gap-2">
          <StatusBadge status={status} type="manufacturing" />
          {mo.sales_order_id && paymentStatus !== 'not_invoiced' && (
            <>
              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                paymentStatus === 'paid' ? 'bg-green-100 text-green-800' :
                paymentStatus === 'partial' ? 'bg-amber-100 text-amber-800' :
                'bg-red-100 text-red-800'
              }`}>
                {paymentStatus === 'paid' ? 'Paid' : paymentStatus === 'partial' ? 'Partial Payment' : 'Unpaid'}
              </span>
              {hasDeliveryOverride && !paymentComplete && (
                <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                  Financial Override
                </span>
              )}
            </>
          )}
        </div>
      }
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
      contentClassName="pt-2 pb-6"
      actions={hasRedirectBack || actionItems.length > 0 ? (
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
          {actionItems.length > 0 && (
            <div className="relative">
              <button
                type="button"
                onClick={() => setActionsOpen(!actionsOpen)}
                disabled={isTransitioning}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
              >
                Actions <ChevronDown className="w-4 h-4" />
              </button>
              {actionsOpen && (
                <>
                  <div className="fixed inset-0 z-30" onClick={() => setActionsOpen(false)} />
                    <div className="absolute right-0 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-40 min-w-[180px] py-1">
                    {actionItems.map((item, i) => (
                      <button key={i} type="button" onClick={item.disabled ? undefined : item.onClick}
                        title={item.title}
                        disabled={item.disabled}
                        className={`w-full text-left px-3 py-2 text-sm ${item.disabled ? 'opacity-50 cursor-not-allowed text-gray-500' : 'hover:bg-gray-50'} ${item.danger ? 'text-red-600' : 'text-gray-700'}`}>
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
      {/* Cancel confirmation */}
      {showCancelDialog && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 mb-4">
          <h4 className="text-sm font-semibold text-red-800 mb-2">Cancel Manufacturing Order?</h4>
          <p className="text-xs text-red-700 mb-3">The Sales Order will keep its current status. You can create a new MO from the Sales Order if needed.</p>
          <textarea
            value={cancelReason}
            onChange={(e) => setCancelReason(e.target.value)}
            placeholder="Reason for cancellation (optional)..."
            rows={2}
            className="w-full px-3 py-2 border border-red-200 rounded-lg text-sm mb-3 focus:outline-none focus:ring-2 focus:ring-red-200 resize-none"
          />
          <div className="flex gap-2">
            <button type="button" onClick={handleCancel} disabled={isTransitioning}
              className="px-3 py-1.5 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 disabled:opacity-50">
              {isTransitioning ? 'Cancelling...' : 'Confirm Cancel'}
            </button>
            <button type="button" onClick={() => { setShowCancelDialog(false); setCancelReason(''); }}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
              Go Back
            </button>
          </div>
        </div>
      )}

      {/* Cancelled banner */}
      {status === 'cancelled' && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 mb-4">
          <p className="text-sm font-medium text-red-800">This manufacturing order has been cancelled.</p>
        </div>
      )}

      {/* Materials incomplete — subtle inline notice */}
      {materialsIncomplete && status !== 'cancelled' && ['draft', 'confirmed', 'procurement', 'planned'].includes(status) && (
        <div className="flex items-center gap-2 mb-3 px-3 py-2 rounded-md bg-amber-50 border border-amber-200 w-full">
          <span className="inline-block w-2 h-2 rounded-full bg-amber-400 flex-shrink-0" />
          <span className="text-xs text-amber-700 flex-1">
            Material shortage detected — purchase materials to advance this order.
          </span>
          <button
            className="text-xs font-medium text-amber-800 hover:text-amber-900 underline underline-offset-2"
            onClick={() => router.navigate(`/inventory/material-demand?mo_id=${moId}`)}
          >
            View Material Demand
          </button>
        </div>
      )}

      {status === 'ready_for_pickup' && deliveryBlocked && (
        <div className="flex items-center gap-2 mb-3 px-3 py-2 rounded-md bg-red-50 border border-red-200 w-full">
          <span className="inline-block w-2 h-2 rounded-full bg-red-500 flex-shrink-0" />
          <span className="text-xs text-red-700 flex-1">
            Delivery blocked: balance due is ${financialSummary?.balance_due?.toFixed(2) ?? '0.00'}. Financials must settle to 0.00 or issue an override.
          </span>
        </div>
      )}

      {/* Overview tab */}
      {activeTab === 'overview' && (
        <div className="space-y-6">
        {/* Production Progress Bar */}
        {(() => {
          const STEPS = [
            { key: 'draft', label: 'Draft' },
            { key: 'confirmed', label: 'Reviewed' },
            { key: 'procurement', label: 'Planned' },
            { key: 'materials_ready', label: 'Material Ready' },
            { key: 'in_production', label: 'In Production' },
            { key: 'quality_check', label: 'QC' },
            { key: 'ready_for_pickup', label: 'Ready' },
            { key: 'delivered', label: 'Delivered' },
          ];
          const currentIdx = STEPS.findIndex((s) => s.key === status);
          const isCancelled = status === 'cancelled';
          const pct = taskProgress.total > 0 ? Math.round((taskProgress.completed / taskProgress.total) * 100) : 0;
          return (
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              {isCancelled ? (
                <div className="flex items-center gap-2 text-sm text-red-600 font-medium">
                  <Circle className="w-4 h-4" /> Cancelled
                </div>
              ) : (
                <>
                  <div className="flex items-center gap-1">
                    {STEPS.map((step, idx) => {
                      const isCompleted = idx < currentIdx;
                      const isCurrent = idx === currentIdx;
                      return (
                        <div key={step.key} className="flex items-center flex-1 min-w-0">
                          <div className="flex flex-col items-center flex-1 min-w-0">
                            <div className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 ${
                              isCompleted ? 'bg-green-500 text-white' :
                              isCurrent ? 'bg-blue-500 text-white' :
                              'bg-gray-200 text-gray-400'
                            }`}>
                              {isCompleted ? <CheckCircle className="w-4 h-4" /> :
                               isCurrent ? <Clock className="w-4 h-4" /> :
                               <Circle className="w-3 h-3" />}
                            </div>
                            <span className={`text-[10px] mt-1 text-center truncate w-full ${
                              isCurrent ? 'font-semibold text-blue-700' :
                              isCompleted ? 'text-green-700' :
                              'text-gray-400'
                            }`}>{step.label}</span>
                          </div>
                          {idx < STEPS.length - 1 && (
                            <div className={`h-0.5 flex-1 mx-1 mt-[-14px] ${
                              idx < currentIdx ? 'bg-green-400' : 'bg-gray-200'
                            }`} />
                          )}
                        </div>
                      );
                    })}
                  </div>
                  {taskProgress.total > 0 && status !== 'draft' && status !== 'delivered' && (
                    <div className="mt-3 flex items-center gap-3">
                      <div className="flex-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : 'bg-blue-500'}`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                      <span className="text-xs text-gray-500 shrink-0 tabular-nums">
                        {taskProgress.completed}/{taskProgress.total} tasks
                        {taskProgress.inProgress > 0 && ` · ${taskProgress.inProgress} active`}
                      </span>
                    </div>
                  )}
                </>
              )}
            </div>
          );
        })()}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Order Info</h3>
            <dl className="space-y-2 text-sm">
              {so && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Sales Order</dt>
                  <dd>
                    <button type="button" onClick={() => router.navigate(withReturnTo(`/sales/orders/${so.id}`))}
                      className="text-primary hover:underline font-medium">{so.sales_order_no}</button>
                  </dd>
                </div>
              )}
              <div className="flex justify-between">
                <dt className="text-gray-500">Customer</dt>
                <dd className="font-medium text-gray-900">{customer}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">MO Type</dt>
                <dd>{mo.mo_type ? <StatusBadge status={mo.mo_type} type="moType" size="sm" /> : '—'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Priority</dt>
                <dd><StatusBadge status={mo.priority ?? 'normal'} type="priority" size="sm" /></dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Product</dt>
                <dd className="text-gray-900">{mo.product_name ?? '—'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Quantity</dt>
                <dd className="text-gray-900">{mo.quantity ?? '—'}</dd>
              </div>
              {so?.total_amount != null && (
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-gray-500">SO Total</dt>
                  <dd className="font-mono font-medium text-gray-900">{formatCurrency(so.total_amount, 'USD')}</dd>
                </div>
              )}
            </dl>
          </div>

          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Schedule & Status</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-gray-500">Status</dt>
                <dd><StatusBadge status={status} type="manufacturing" size="sm" /></dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Created</dt>
                <dd className="text-gray-900">{formatDate(mo.created_at)}</dd>
              </div>
              {mo.released_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Released (Planned)</dt>
                  <dd className="text-gray-900">{formatDate(mo.released_at)}</dd>
                </div>
              )}
              {mo.planned_start_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Planned Start</dt>
                  <dd className="text-gray-900">{formatDate(mo.planned_start_at)}</dd>
                </div>
              )}
              {mo.planned_end_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Planned End</dt>
                  <dd className="text-gray-900">{formatDate(mo.planned_end_at)}</dd>
                </div>
              )}
              {mo.production_started_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Production Started</dt>
                  <dd className="text-gray-900">{formatDate(mo.production_started_at)}</dd>
                </div>
              )}
              {mo.completed_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Completed</dt>
                  <dd className="text-gray-900">{formatDate(mo.completed_at)}</dd>
                </div>
              )}
              {mo.delivered_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Delivered</dt>
                  <dd className="text-gray-900">{formatDate(mo.delivered_at)}</dd>
                </div>
              )}
              <div className="flex justify-between border-t pt-2">
                <dt className="text-gray-500">BOM Lines</dt>
                <dd className="font-medium text-gray-900">{materials.length}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">MO Lines</dt>
                <dd className="font-medium text-gray-900">{moLines.length}</dd>
              </div>
            </dl>
          </div>
        </div>
        </div>
      )}

      {/* Lines tab */}
      {activeTab === 'lines' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700 w-10">#</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Product</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Location</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {moLines.length === 0 ? (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No manufacturing order lines</td></tr>
              ) : (
                moLines.map((line, idx) => {
                  const sol = line.SaleOrderLine;
                  const ptLabels: Record<string, string> = { roller: 'Roller Shade', drapery: 'Drapery', catalog: 'Catalog', blind: 'Blind', curtain: 'Curtain' };
                  const ptRaw = (sol?.product_type || '').toLowerCase();
                  const ptLabel = ptLabels[ptRaw] || (ptRaw ? ptRaw.charAt(0).toUpperCase() + ptRaw.slice(1) : '');
                  const fabricName = sol?.description || sol?.CatalogItems?.name || sol?.variant_name || 'Item';
                  const manufacturer = sol?.CatalogItems?.manufacturer;
                  const sku = sol?.CatalogItems?.sku;
                  const hwColor = sol?.hardware_color;
                  const area = sol?.area;
                  const position = sol?.position;

                  return (
                    <tr key={line.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-3 text-gray-400 tabular-nums">{idx + 1}</td>
                      <td className="px-4 py-3">
                        <div className="font-medium text-gray-900">
                          {ptLabel}{ptLabel && ' — '}{fabricName}
                          {manufacturer && <span className="text-gray-500 font-normal"> | {manufacturer}</span>}
                        </div>
                        <div className="flex items-center gap-2 mt-0.5">
                          {sku && <span className="text-xs text-gray-500 font-mono">{sku}</span>}
                          {hwColor && (
                            <span className="text-xs text-gray-400">
                              · {hwColor}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-600">
                        {area || position ? (
                          <div>
                            {area && <div className="text-sm">{area}</div>}
                            {position && <div className="text-xs text-gray-400">{position}</div>}
                          </div>
                        ) : '—'}
                      </td>
                      <td className="px-4 py-3 text-right tabular-nums">{line.quantity ?? sol?.quantity ?? '—'}</td>
                      <td className="px-4 py-3 text-center">
                        <StatusBadge status={line.status ?? 'planned'} type="moLineStatus" size="sm" />
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Materials tab */}
      {activeTab === 'materials' && (
        <MaterialsTab
          moId={moId}
          saleOrderId={mo.sales_order_id || null}
          moStatus={status}
          currency="USD"
        />
      )}

      {activeTab === 'schedule' && (
        <ScheduleTab moId={moId} canEdit={canWriteSchedule} />
      )}

      {activeTab === 'work-orders' && moId && (
        <WorkOrdersTab
          moId={moId}
          moNumber={mo.manufacturing_order_no}
          customerName={customer}
          productName={mo.product_name ?? ''}
          salesOrderNo={so?.sales_order_no}
        />
      )}

      {/* Notes tab */}
      {activeTab === 'notes' && (
        <NotesTab moId={moId} canEdit={canWriteNotes} />
      )}

      {/* Timeline tab */}
      {activeTab === 'timeline' && (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          {timeline.length === 0 ? (
            <div className="px-4 py-8 text-center text-gray-500">No activity yet</div>
          ) : (
            <TimelineView events={timeline} />
          )}
        </div>
      )}

      {/* Attachments tab */}
      {activeTab === 'attachments' && moId && (
        <AttachmentsTab moId={moId} organizationId={mo.organization_id} canEdit={canWriteAttachments} />
      )}
    </DetailPageLayout>
  );
}
