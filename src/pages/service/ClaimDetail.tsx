import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useServiceClaimDetail, useClaimActions, type ClaimStatus, type ClaimResolution } from '../../hooks/useServiceClaims';
import { useUIStore } from '../../stores/ui-store';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import TimelineView from '../../components/shared/TimelineView';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { formatDate, formatDateTime } from '../../lib/utils';
import { Upload, Trash2, Download, FileText, Factory, Wrench, Loader2, ExternalLink, Receipt } from 'lucide-react';

const SERVICE_SUBMODULES = [
  { id: 'claims', label: 'Claims', href: '/service/claims' },
];

const TYPE_LABELS: Record<string, string> = {
  defect: 'Manufacturing Defect',
  damage: 'Shipping / Handling Damage',
  wrong_size: 'Wrong Size',
  wrong_color: 'Wrong Color',
  missing_parts: 'Missing Parts',
  other: 'Other',
};

const PRIORITY_COLORS: Record<string, string> = {
  low: 'bg-gray-100 text-gray-700',
  medium: 'bg-blue-100 text-blue-700',
  high: 'bg-amber-100 text-amber-700',
  urgent: 'bg-red-100 text-red-700',
};

const PRIORITY_OPTIONS = ['low', 'medium', 'high', 'urgent'] as const;

function getClaimIdFromPath(): string {
  const parts = window.location.pathname.split('/');
  return parts[parts.length - 1] || '';
}

export default function ClaimDetail() {
  const claimId = getClaimIdFromPath();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { isInternal } = useAccessContext();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);

  const { claim, lines, attachments, timeline, loading, refetch } = useServiceClaimDetail(claimId);
  const { transitionStatus, updateResolution, createServiceMO, isActing } = useClaimActions();

  const [activeTab, setActiveTab] = useState('overview');
  const [resolutionType, setResolutionType] = useState<ClaimResolution>('none');
  const [resolutionNotes, setResolutionNotes] = useState('');
  const [creatingMO, setCreatingMO] = useState(false);
  const [togglingChargeable, setTogglingChargeable] = useState(false);
  const [claimInvoice, setClaimInvoice] = useState<{ id: string; invoice_number: string; status: string; total: number } | null>(null);
  const [generatingInvoice, setGeneratingInvoice] = useState(false);
  const [priorityOpen, setPriorityOpen] = useState(false);

  const handlePriorityChange = useCallback(async (newPriority: string) => {
    if (!claim || newPriority === claim.priority) { setPriorityOpen(false); return; }
    const { error } = await supabase
      .from('ServiceClaims')
      .update({ priority: newPriority })
      .eq('id', claim.id);
    setPriorityOpen(false);
    if (error) { addNotification({ type: 'error', message: 'Failed to update priority' }); return; }
    refetch();
  }, [claim, addNotification, refetch]);

  useEffect(() => { registerSubmodules('Service', SERVICE_SUBMODULES); }, [registerSubmodules]);

  useEffect(() => {
    if (claim) {
      setResolutionType(claim.resolution_type ?? 'none');
      setResolutionNotes(claim.resolution_notes ?? '');
    }
  }, [claim]);

  useEffect(() => {
    if (!claimId) return;
    supabase
      .from('DealerInvoices')
      .select('id, invoice_number, status, total')
      .eq('claim_id', claimId)
      .eq('deleted', false)
      .neq('status', 'void')
      .limit(1)
      .then(({ data }) => {
        setClaimInvoice(data && data.length > 0 ? data[0] as any : null);
      });
  }, [claimId, claim?.chargeable]);

  const handleToggleChargeable = useCallback(async (value: boolean) => {
    if (!claim) return;
    setTogglingChargeable(true);
    try {
      const { error } = await supabase.from('ServiceClaims').update({ chargeable: value }).eq('id', claim.id);
      if (error) throw error;
      addNotification({ type: 'success', message: value ? 'Claim marked as chargeable' : 'Claim set to warranty (no charge)' });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', message: err.message || 'Failed to update' });
    } finally {
      setTogglingChargeable(false);
    }
  }, [claim, addNotification, refetch]);

  const handleGenerateInvoice = useCallback(async () => {
    if (!claim) return;
    setGeneratingInvoice(true);
    try {
      const { data, error } = await supabase.rpc('create_claim_invoice', { p_claim_id: claim.id });
      if (error) throw error;
      const result = data as any;
      if (!result?.ok) throw new Error(result?.error ?? 'Failed to create invoice');
      addNotification({ type: 'success', message: `Invoice ${result.invoice_number} created — $${result.total}` });
      setClaimInvoice({ id: result.invoice_id, invoice_number: result.invoice_number, status: 'draft', total: result.total });
    } catch (err: any) {
      addNotification({ type: 'error', message: err.message || 'Failed to generate invoice' });
    } finally {
      setGeneratingInvoice(false);
    }
  }, [claim, addNotification]);

  const onBack = useCallback(() => {
    const returnTo = getReturnToFromCurrentQuery();
    if (returnTo) { router.navigate(returnTo); }
    else { router.navigate('/service/claims'); }
  }, []);

  const handleTransition = useCallback(async (newStatus: ClaimStatus) => {
    if (!claim) return;
    try {
      await transitionStatus(claim.id, newStatus);
      addNotification({ type: 'success', message: `Claim status updated to ${newStatus.replace('_', ' ')}` });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', message: err.message || 'Failed to update status' });
    }
  }, [claim, transitionStatus, addNotification, refetch]);

  const handleSaveResolution = useCallback(async () => {
    if (!claim) return;
    try {
      await updateResolution(claim.id, resolutionType, resolutionNotes);
      addNotification({ type: 'success', message: 'Resolution updated' });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', message: err.message || 'Failed to update resolution' });
    }
  }, [claim, resolutionType, resolutionNotes, updateResolution, addNotification, refetch]);

  const handleCreateServiceMO = useCallback(async (moType: 'rework' | 'replacement') => {
    if (!claim) return;
    setCreatingMO(true);
    try {
      const result = await createServiceMO(claim.id, moType);
      if (result) {
        addNotification({ type: 'success', message: `${moType === 'rework' ? 'Rework' : 'Replacement'} MO ${result.mo_number} created` });
        refetch();
      }
    } catch (err: any) {
      addNotification({ type: 'error', message: err.message || 'Failed to create service MO' });
    } finally {
      setCreatingMO(false);
    }
  }, [claim, createServiceMO, addNotification, refetch]);

  // Attachments
  const [uploading, setUploading] = useState(false);
  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !claim || !activeOrganizationId || !user) return;
    setUploading(true);
    for (const file of Array.from(e.target.files)) {
      const path = `${activeOrganizationId}/${claim.id}/${Date.now()}_${file.name}`;
      const { error: upErr } = await supabase.storage.from('service-claim-attachments').upload(path, file);
      if (!upErr) {
        await supabase.from('ServiceClaimAttachments').insert({
          claim_id: claim.id,
          organization_id: activeOrganizationId,
          file_name: file.name,
          file_path: path,
          uploaded_by: user.id,
        });
      }
    }
    setUploading(false);
    refetch();
  };

  const handleDeleteAttachment = async (att: { id: string; file_path: string }) => {
    if (!confirm('Delete this attachment?')) return;
    await supabase.storage.from('service-claim-attachments').remove([att.file_path]);
    await supabase.from('ServiceClaimAttachments').update({ deleted: true }).eq('id', att.id);
    refetch();
  };

  const handleDownloadAttachment = async (att: { file_name: string; file_path: string }) => {
    const { data } = await supabase.storage.from('service-claim-attachments').createSignedUrl(att.file_path, 60);
    if (data?.signedUrl) window.open(data.signedUrl, '_blank');
  };

  const statusActions = useMemo(() => {
    if (!claim) return [];
    const s = claim.status;
    const btns: { label: string; status: ClaimStatus; variant?: string }[] = [];
    if (s === 'draft') {
      btns.push({ label: 'Submit for Review', status: 'under_review' });
      btns.push({ label: 'Cancel', status: 'closed', variant: 'danger' });
    }
    if (isInternal) {
      if (s === 'under_review') {
        btns.push({ label: 'Approve', status: 'approved' });
        btns.push({ label: 'Reject', status: 'rejected', variant: 'danger' });
      }
      if (s === 'approved') btns.push({ label: 'Start Resolution', status: 'in_progress' });
      if (s === 'in_progress') btns.push({ label: 'Mark Resolved', status: 'resolved' });
      if (s === 'resolved' || s === 'rejected') btns.push({ label: 'Close', status: 'closed' });
    }
    return btns;
  }, [claim, isInternal]);

  if (loading && !claim) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="w-5 h-5 animate-spin text-gray-400 mr-2" />
        <span className="text-sm text-gray-500">Loading claim…</span>
      </div>
    );
  }
  if (!claim) {
    return <div className="text-center py-16 text-gray-500">Claim not found</div>;
  }

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'products', label: 'Products', count: lines.length },
    ...(isInternal ? [{ id: 'resolution', label: 'Resolution' }] : []),
    { id: 'attachments', label: 'Attachments', count: attachments.length },
    { id: 'timeline', label: 'Timeline' },
  ];

  return (
    <DetailPageLayout
      title={claim.claim_no}
      subtitle="Claim Detail"
      status={<StatusBadge status={claim.status} type="claim" />}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
      contentClassName="pt-2 pb-6"
      actions={
        statusActions.length > 0 ? (
          <div className="flex items-center gap-2">
            {statusActions.map((a) => (
              <button
                key={a.status}
                onClick={() => handleTransition(a.status)}
                disabled={isActing}
                className={`px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ${
                  a.variant === 'danger'
                    ? 'text-red-600 border border-red-200 hover:bg-red-50'
                    : 'text-white bg-primary hover:bg-primary/90'
                }`}
              >
                {a.label}
              </button>
            ))}
          </div>
        ) : undefined
      }
    >
      {activeTab === 'overview' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Claim Info */}
            <div className="bg-white border border-gray-200 rounded-lg p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4">Claim Information</h3>
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Claim Number</dt>
                  <dd className="font-medium text-gray-900">{claim.claim_no}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Type</dt>
                  <dd className="text-gray-900">{TYPE_LABELS[claim.claim_type] ?? claim.claim_type}</dd>
                </div>
                <div className="flex justify-between items-center">
                  <dt className="text-gray-500">Priority</dt>
                  <dd className="relative">
                    <button
                      type="button"
                      onClick={() => setPriorityOpen((p) => !p)}
                      className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium cursor-pointer hover:ring-1 hover:ring-gray-300 ${PRIORITY_COLORS[claim.priority] ?? ''}`}
                    >
                      {claim.priority.charAt(0).toUpperCase() + claim.priority.slice(1)}
                    </button>
                    {priorityOpen && (
                      <>
                        <div className="fixed inset-0 z-30" onClick={() => setPriorityOpen(false)} />
                        <div className="absolute right-0 top-7 z-40 bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[100px]">
                          {PRIORITY_OPTIONS.map((p) => (
                            <button
                              key={p}
                              type="button"
                              onClick={() => handlePriorityChange(p)}
                              className={`w-full text-left px-3 py-1.5 text-xs hover:bg-gray-50 flex items-center gap-2 ${claim.priority === p ? 'font-semibold' : ''}`}
                            >
                              <span className={`w-2 h-2 rounded-full ${PRIORITY_COLORS[p]?.split(' ')[0] ?? 'bg-gray-200'}`} />
                              {p.charAt(0).toUpperCase() + p.slice(1)}
                            </button>
                          ))}
                        </div>
                      </>
                    )}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Created</dt>
                  <dd className="text-gray-900 tabular-nums">{formatDate(claim.created_at)}</dd>
                </div>
                {claim.resolved_at && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Resolved</dt>
                    <dd className="text-gray-900 tabular-nums">{formatDate(claim.resolved_at)}</dd>
                  </div>
                )}
                {claim.resolution_type && claim.resolution_type !== 'none' && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Resolution</dt>
                    <dd className="text-gray-900 capitalize">{claim.resolution_type}</dd>
                  </div>
                )}
                {isInternal && (
                  <div className="flex justify-between items-center pt-2 border-t border-gray-100">
                    <dt className="text-gray-500">Billing</dt>
                    <dd>
                      <div className="inline-flex rounded-md border border-gray-200 text-xs overflow-hidden">
                        <button
                          type="button"
                          disabled={togglingChargeable}
                          onClick={() => claim.chargeable && handleToggleChargeable(false)}
                          className={`px-3 py-1 font-medium transition-colors ${
                            !claim.chargeable
                              ? 'bg-gray-700 text-white'
                              : 'bg-white text-gray-500 hover:bg-gray-50'
                          }`}
                        >
                          Warranty
                        </button>
                        <button
                          type="button"
                          disabled={togglingChargeable}
                          onClick={() => !claim.chargeable && handleToggleChargeable(true)}
                          className={`px-3 py-1 font-medium transition-colors ${
                            claim.chargeable
                              ? 'bg-amber-600 text-white'
                              : 'bg-white text-gray-500 hover:bg-gray-50'
                          }`}
                        >
                          Chargeable
                        </button>
                      </div>
                    </dd>
                  </div>
                )}
              </dl>
            </div>

            {/* Linked Order */}
            <div className="bg-white border border-gray-200 rounded-lg p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4">Linked Order</h3>
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between items-center">
                  <dt className="text-gray-500">Sales Order</dt>
                  <dd>
                    {claim.SalesOrders ? (
                      <button
                        onClick={() => router.navigate(withReturnTo(`/sales/orders/${claim.SalesOrders!.id}`))}
                        className="text-primary font-medium hover:underline inline-flex items-center gap-1"
                      >
                        {claim.SalesOrders.sales_order_no}
                        <ExternalLink className="w-3 h-3" />
                      </button>
                    ) : '—'}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Dealer</dt>
                  <dd className="text-gray-900">{claim.Dealers?.dealer_name ?? '—'}</dd>
                </div>
                {claim.resolution_mo_id && (
                  <div className="flex justify-between items-center">
                    <dt className="text-gray-500">Replacement MO</dt>
                    <dd>
                      <button
                        onClick={() => router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${claim.resolution_mo_id}`))}
                        className="text-primary font-medium hover:underline inline-flex items-center gap-1"
                      >
                        View MO <ExternalLink className="w-3 h-3" />
                      </button>
                    </dd>
                  </div>
                )}
              </dl>
            </div>
          </div>

          {/* Description */}
          {claim.description && (
            <div className="bg-white border border-gray-200 rounded-lg p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-2">Description</h3>
              <p className="text-sm text-gray-700 whitespace-pre-wrap">{claim.description}</p>
            </div>
          )}

          {/* Billing */}
          {isInternal && (
            <div className="bg-white border border-gray-200 rounded-lg p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Receipt className="w-4 h-4 text-gray-400" />
                Billing
              </h3>
              {!claim.chargeable ? (
                <p className="text-sm text-gray-400">No charge — warranty claim. Cost absorbed internally.</p>
              ) : claimInvoice ? (
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium text-gray-700">{claimInvoice.invoice_number}</span>
                    <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${
                      claimInvoice.status === 'paid' ? 'bg-green-100 text-green-700' :
                      claimInvoice.status === 'issued' ? 'bg-blue-100 text-blue-700' :
                      claimInvoice.status === 'partial' ? 'bg-amber-100 text-amber-700' :
                      'bg-gray-100 text-gray-600'
                    }`}>
                      {claimInvoice.status.charAt(0).toUpperCase() + claimInvoice.status.slice(1)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">Total</span>
                    <span className="font-mono font-medium text-gray-900">${Number(claimInvoice.total).toFixed(2)}</span>
                  </div>
                </div>
              ) : (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-500">No invoice generated yet.</span>
                  <button
                    type="button"
                    disabled={generatingInvoice || !claim.resolution_mo_id}
                    onClick={handleGenerateInvoice}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-amber-600 text-white hover:bg-amber-700 disabled:opacity-50 transition-colors"
                  >
                    {generatingInvoice && <Loader2 className="w-3 h-3 animate-spin" />}
                    Generate Invoice
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {activeTab === 'products' && (
        <div className="bg-white border border-gray-200 rounded-lg p-5">
          <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider mb-4">Affected Products</h3>
          {lines.length === 0 ? (
            <p className="text-sm text-gray-500 py-4 text-center">No product lines recorded.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-200">
                    <th className="text-left py-2 pr-3 font-medium text-gray-500 text-xs uppercase">Product</th>
                    <th className="text-center py-2 px-3 font-medium text-gray-500 text-xs uppercase">Qty Affected</th>
                    <th className="text-left py-2 px-3 font-medium text-gray-500 text-xs uppercase">Dimensions</th>
                    <th className="text-left py-2 pl-3 font-medium text-gray-500 text-xs uppercase">Reason</th>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((l) => {
                    const cs = l.ConfiguredProduct?.config_snapshot;
                    const wMm = l.ConfiguredProduct?.width_mm ?? cs?.width_mm;
                    const hMm = l.ConfiguredProduct?.height_mm ?? cs?.height_mm;
                    return (
                      <tr key={l.id} className="border-b border-gray-100 last:border-0">
                        <td className="py-2.5 pr-3">
                          <div className="text-gray-900 font-medium">{l.description || l.SaleOrderLine?.description || '—'}</div>
                          {l.SaleOrderLine?.product_type && <div className="text-xs text-gray-500">{l.SaleOrderLine.product_type}</div>}
                          {cs?.roll_collection_name && <div className="text-xs text-gray-500">{cs.roll_collection_name} — {cs.roll_variant_name}</div>}
                        </td>
                        <td className="py-2.5 px-3 text-center tabular-nums">{l.qty_affected}</td>
                        <td className="py-2.5 px-3 text-gray-600 tabular-nums">
                          {wMm && hMm ? `${wMm}mm × ${hMm}mm` : '—'}
                        </td>
                        <td className="py-2.5 pl-3 text-gray-600">{l.claim_reason || '—'}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {activeTab === 'resolution' && isInternal && (
        <div className="space-y-6">
          <div className="bg-white border border-gray-200 rounded-lg p-5 space-y-4">
            <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">Resolution</h3>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Resolution Type</label>
              <select
                value={resolutionType}
                onChange={(e) => setResolutionType(e.target.value as ClaimResolution)}
                disabled={!!claim.resolution_mo_id}
                className="w-full max-w-xs px-3 py-2 text-sm border border-gray-200 rounded-lg disabled:bg-gray-50 disabled:text-gray-500"
              >
                <option value="none">None (pending)</option>
                <option value="replace">Replace (new MO)</option>
                <option value="repair">Repair (rework MO)</option>
                <option value="credit">Credit Note</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Resolution Notes</label>
              <textarea
                value={resolutionNotes}
                onChange={(e) => setResolutionNotes(e.target.value)}
                rows={3}
                placeholder="Internal notes about the resolution..."
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg resize-none"
              />
            </div>
            {!claim.resolution_mo_id && resolutionType !== 'none' && (
              <div className="flex items-center gap-3">
                <button
                  onClick={handleSaveResolution}
                  disabled={isActing}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
                >
                  Save Resolution
                </button>
              </div>
            )}
          </div>

          {(resolutionType === 'replace' || resolutionType === 'repair') && !claim.resolution_mo_id && (
            <div className="bg-white border border-gray-200 rounded-lg p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                {resolutionType === 'repair' ? <Wrench className="w-4 h-4" /> : <Factory className="w-4 h-4" />}
                {resolutionType === 'repair' ? 'Create Rework MO' : 'Create Replacement MO'}
              </h3>
              <p className="text-sm text-gray-500 mb-4">
                {resolutionType === 'repair'
                  ? 'This will create a Rework Manufacturing Order for the affected products, using the original configuration from the Sales Order.'
                  : 'This will create a Replacement Manufacturing Order to refabricate the affected products, using the original configuration from the Sales Order.'}
              </p>
              <p className="text-xs text-gray-400 mb-4">
                The new MO will follow the standard production flow (Draft → Confirmed → In Production → ...) and will generate its own BOM, Work Orders, and material demand.
              </p>
              <button
                onClick={() => handleCreateServiceMO(resolutionType === 'repair' ? 'rework' : 'replacement')}
                disabled={creatingMO || !claim.sales_order_id}
                className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
              >
                {creatingMO ? <Loader2 className="w-4 h-4 animate-spin" /> : (resolutionType === 'repair' ? <Wrench className="w-4 h-4" /> : <Factory className="w-4 h-4" />)}
                {resolutionType === 'repair' ? 'Create Rework MO' : 'Create Replacement MO'}
              </button>
            </div>
          )}

          {claim.resolution_mo_id && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-5">
              <h3 className="text-sm font-semibold text-green-900 mb-2 flex items-center gap-2">
                {claim.resolution_type === 'repair' ? <Wrench className="w-4 h-4" /> : <Factory className="w-4 h-4" />}
                {claim.resolution_type === 'repair' ? 'Rework' : 'Replacement'} MO Created
              </h3>
              <button
                onClick={() => router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${claim.resolution_mo_id}`))}
                className="inline-flex items-center gap-1.5 text-sm text-green-700 font-medium hover:underline"
              >
                <Factory className="w-4 h-4" /> View Manufacturing Order <ExternalLink className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      )}

      {activeTab === 'attachments' && (
        <div className="bg-white border border-gray-200 rounded-lg p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">Attachments</h3>
            <label className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
              {uploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Upload className="w-4 h-4 text-gray-400" />}
              <span className="text-gray-600">Upload</span>
              <input type="file" multiple accept="image/*,.pdf" onChange={handleUpload} className="sr-only" disabled={uploading} />
            </label>
          </div>
          {attachments.length === 0 ? (
            <p className="text-sm text-gray-500 py-4 text-center">No attachments yet.</p>
          ) : (
            <div className="space-y-2">
              {attachments.map((att) => (
                <div key={att.id} className="flex items-center justify-between py-2 px-3 border border-gray-100 rounded-lg">
                  <div className="flex items-center gap-2 min-w-0">
                    <FileText className="w-4 h-4 text-gray-400 shrink-0" />
                    <span className="text-sm text-gray-700 truncate">{att.file_name}</span>
                    <span className="text-xs text-gray-400 shrink-0">{formatDateTime(att.created_at)}</span>
                  </div>
                  <div className="flex items-center gap-1 shrink-0">
                    <button onClick={() => handleDownloadAttachment(att)} className="p-1 text-gray-400 hover:text-primary"><Download className="w-4 h-4" /></button>
                    <button onClick={() => handleDeleteAttachment(att)} className="p-1 text-gray-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {activeTab === 'timeline' && (
        <TimelineView events={timeline} loading={loading && timeline.length === 0} emptyMessage="No activity yet" />
      )}
    </DetailPageLayout>
  );
}
