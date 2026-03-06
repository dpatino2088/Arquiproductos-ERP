import { useEffect, useState, useCallback } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useManufacturingOrder, useManufacturingMaterials, useTransitionMOStatus, useMoMaterialReadiness } from '../../hooks/useManufacturing';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { MANUFACTURING_SUBMODULES } from './manufacturingSubmodules';
import { useUIStore } from '../../stores/ui-store';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useModuleAccess } from '../../hooks/usePermissions';
import { useAuth } from '../../hooks/useAuth';
import { useIssueMaterials } from '../../hooks/useInventoryMovements';
import { useWarehouses } from '../../hooks/useWarehouses';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import MaterialsTab from '../../components/manufacturing/tabs/MaterialsTab';
import ProductionStepsTab from '../../components/manufacturing/tabs/ProductionStepsTab';
import ScheduleTab from '../../components/manufacturing/tabs/ScheduleTab';
import NotesTab from '../../components/manufacturing/tabs/NotesTab';
import AttachmentsTab from '../../components/manufacturing/tabs/AttachmentsTab';
import WorkOrdersTab from './WorkOrdersTab';
import TimelineView from '../../components/shared/TimelineView';
import { ChevronDown } from 'lucide-react';
import { normalizeUUID } from '../../utils/uuid';
import { formatCurrency } from '../../lib/utils';
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
    quantity: number;
    unit_price: number | null;
    CatalogItems?: { name: string; sku: string } | null;
  } | null;
}

const MFG_SUBMODULES = MANUFACTURING_SUBMODULES;

export default function ManufacturingOrderDetail({ moId: propMoId }: ManufacturingOrderDetailProps) {
  const normalizedPropMoId = propMoId ? normalizeUUID(propMoId) : null;
  const [moId, setMoId] = useState<string | null>(normalizedPropMoId);
  const { manufacturingOrder: mo, loading, error, refetch } = useManufacturingOrder(moId);
  const { materials } = useManufacturingMaterials(moId ?? '');
  const { readiness: materialReadiness } = useMoMaterialReadiness(moId);
  const { transitionStatus, isTransitioning } = useTransitionMOStatus();
  const { issueMaterials } = useIssueMaterials();
  const { defaultWarehouse } = useWarehouses(mo?.organization_id ?? null);
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);
  const { isInternal } = useAccessContext();
  const { canEdit: canEditInventory } = useModuleAccess('inventory');
  const { canEdit: canEditManufacturing } = useModuleAccess('manufacturing');
  const { user } = useAuth();

  const [activeTab, setActiveTab] = useState('overview');
  const [actionsOpen, setActionsOpen] = useState(false);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [moLines, setMoLines] = useState<MOLine[]>([]);
  const [cancelReason, setCancelReason] = useState('');
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const listPath = '/manufacturing/manufacturing-orders';
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

  useEffect(() => { registerSubmodules('Manufacturing', MFG_SUBMODULES); }, [registerSubmodules]);

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
        .select('id, description, collection_name, variant_name, quantity, unit_price, catalog_item_id')
        .in('id', solIds);
      if (solData) {
        const catIds = [...new Set(solData.map((s: any) => s.catalog_item_id).filter(Boolean))];
        let catMap = new Map<string, any>();
        if (catIds.length > 0) {
          const { data: catData } = await supabase.from('CatalogItems').select('id, name, sku').in('id', catIds);
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

  useEffect(() => { fetchTimeline(); fetchMOLines(); }, [fetchTimeline, fetchMOLines]);

  const handleTransition = useCallback(async (newStatus: string) => {
    if (!moId || !user?.id) return;
    setActionsOpen(false);
    try {
      await transitionStatus(moId, newStatus, user.id, user.name);
      addNotification({ type: 'success', title: 'Status Updated', message: `MO moved to ${newStatus.replace(/_/g, ' ')}.` });

      if (newStatus === 'in_production' && defaultWarehouse) {
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

      refetch();
      fetchTimeline();
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed to update status' });
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

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'lines', label: 'Lines', count: moLines.length },
    { id: 'materials', label: 'Materials', count: materials.length },
    { id: 'schedule', label: 'Schedule' },
    { id: 'steps', label: 'Production Steps' },
    { id: 'work-orders', label: 'Work Orders' },
    { id: 'notes', label: 'Notes' },
    { id: 'timeline', label: 'Timeline', count: timeline.length },
    { id: 'attachments', label: 'Attachments' },
  ];

  const materialsIncomplete = materialReadiness?.hasShortage === true;
  const actionItems: { label: string; onClick: () => void; danger?: boolean; disabled?: boolean; title?: string }[] = [];
  if (isInternal && status !== 'cancelled' && status !== 'delivered') {
    if (status === 'draft') actionItems.push({
      label: 'Advance to Planned',
      onClick: () => handleTransition('planned'),
      disabled: materialsIncomplete,
      title: materialsIncomplete ? 'Materials incomplete. Cover material demand before advancing.' : undefined,
    });
    if (status === 'planned') actionItems.push({
      label: 'Start Production',
      onClick: () => handleTransition('in_production'),
      disabled: materialsIncomplete,
      title: materialsIncomplete ? 'Materials incomplete. Cover material demand before starting production.' : undefined,
    });
    if (status === 'in_production') actionItems.push({ label: 'Send to QC', onClick: () => handleTransition('quality_check') });
    if (status === 'quality_check') actionItems.push({ label: 'Ready for Pickup', onClick: () => handleTransition('ready_for_pickup') });
    if (status === 'ready_for_pickup') actionItems.push({ label: 'Mark Delivered', onClick: () => handleTransition('delivered') });
    if (['draft', 'planned', 'in_production'].includes(status) && materials.length > 0 && canEditInventory) {
      actionItems.push({ label: 'Buy Materials', onClick: () => router.navigate(`/inventory/material-demand?mo_id=${moId}`) });
    }
    if (['draft', 'planned', 'in_production'].includes(status)) {
      actionItems.push({ label: 'Cancel MO', onClick: () => setShowCancelDialog(true), danger: true });
    }
  }

  return (
    <DetailPageLayout
      title={mo.manufacturing_order_no}
      subtitle="Manufacturing Order"
      status={<StatusBadge status={status} type="manufacturing" />}
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
      {materialsIncomplete && status !== 'cancelled' && ['draft', 'planned'].includes(status) && (
        <div className="flex items-center gap-2 mb-3 px-3 py-1.5 rounded-md bg-amber-50 border border-amber-100 w-fit">
          <span className="inline-block w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
          <span className="text-xs text-amber-700">Material shortage — cover demand before advancing.</span>
        </div>
      )}

      {/* Overview tab */}
      {activeTab === 'overview' && (
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
                <dd className="text-gray-900">{new Date(mo.created_at).toLocaleDateString()}</dd>
              </div>
              {mo.released_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Released (Planned)</dt>
                  <dd className="text-gray-900">{new Date(mo.released_at).toLocaleDateString()}</dd>
                </div>
              )}
              {mo.planned_start_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Planned Start</dt>
                  <dd className="text-gray-900">{new Date(mo.planned_start_at).toLocaleDateString()}</dd>
                </div>
              )}
              {mo.planned_end_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Planned End</dt>
                  <dd className="text-gray-900">{new Date(mo.planned_end_at).toLocaleDateString()}</dd>
                </div>
              )}
              {mo.production_started_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Production Started</dt>
                  <dd className="text-gray-900">{new Date(mo.production_started_at).toLocaleDateString()}</dd>
                </div>
              )}
              {mo.completed_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Completed</dt>
                  <dd className="text-gray-900">{new Date(mo.completed_at).toLocaleDateString()}</dd>
                </div>
              )}
              {mo.delivered_at && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Delivered</dt>
                  <dd className="text-gray-900">{new Date(mo.delivered_at).toLocaleDateString()}</dd>
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
      )}

      {/* Lines tab */}
      {activeTab === 'lines' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">#</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Product</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {moLines.length === 0 ? (
                <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-500">No manufacturing order lines</td></tr>
              ) : (
                moLines.map((line, idx) => {
                  const sol = line.SaleOrderLine;
                  const name = sol?.CatalogItems?.name || sol?.description || sol?.collection_name || sol?.variant_name || 'Item';
                  const sku = sol?.CatalogItems?.sku;
                  return (
                    <tr key={line.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-4 text-gray-400 tabular-nums">{idx + 1}</td>
                      <td className="px-4 py-4">
                        <div className="font-medium text-gray-900">{name}</div>
                        {sku && <div className="text-xs text-gray-500">{sku}</div>}
                      </td>
                      <td className="px-4 py-4 text-right tabular-nums">{line.quantity ?? sol?.quantity ?? '—'}</td>
                      <td className="px-4 py-4 text-center">
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
        <ScheduleTab moId={moId} canEdit={canEditManufacturing} />
      )}

      {/* Production Steps tab */}
      {activeTab === 'steps' && (
        <ProductionStepsTab moId={moId} />
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
        <NotesTab moId={moId} />
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
        <AttachmentsTab moId={moId} organizationId={mo.organization_id} />
      )}
    </DetailPageLayout>
  );
}
