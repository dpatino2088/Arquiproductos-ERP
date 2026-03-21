import { useState, useEffect, useCallback } from 'react';
import { supabase, initSessionContext } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';
import { useVendorPaymentDetail, useVendorPaymentMutations } from '../../hooks/useVendorPayments';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { formatCurrency, formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { ArrowLeft, ChevronDown } from 'lucide-react';
import { useGranularAccess } from '../../hooks/usePermissions';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

interface OpenBillOption {
  id: string;
  bill_number: string;
  total: number;
  balance_due: number;
}

export default function VendorPaymentDetail() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const addNotification = useUIStore(s => s.addNotification);
  const { canVoid: canVoidFin } = useGranularAccess('financials');

  const paymentId = window.location.pathname.split('/').pop() ?? '';
  const { payment, applications, isLoading, refetch } = useVendorPaymentDetail(paymentId || null);
  const { applyToBill, unapplyFromBill, voidPayment, isSaving } = useVendorPaymentMutations();

  const [showVoidDialog, setShowVoidDialog] = useState(false);
  const [voidReason, setVoidReason] = useState('');
  const [showApplyDialog, setShowApplyDialog] = useState(false);
  const [openBills, setOpenBills] = useState<OpenBillOption[]>([]);
  const [applyBillId, setApplyBillId] = useState('');
  const [applyAmount, setApplyAmount] = useState('');
  const [showUnapplyDialog, setShowUnapplyDialog] = useState(false);
  const [unapplyAppId, setUnapplyAppId] = useState('');
  const [unapplyBillId, setUnapplyBillId] = useState('');
  const [showActionsMenu, setShowActionsMenu] = useState(false);
  const queryReturnTo = getReturnToFromCurrentQuery();

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const totalApplied = applications.reduce((s, a) => s + a.applied_amount, 0);
  const available = Math.max(0, (payment?.amount ?? 0) - totalApplied);

  const loadOpenBills = useCallback(async () => {
    if (!activeOrganizationId || !payment?.vendor_id) return;
    await initSessionContext();
    const { data } = await supabase
      .from('vendor_bill_balances_v1')
      .select('bill_id, bill_number, bill_total, balance_due')
      .eq('organization_id', activeOrganizationId)
      .eq('vendor_id', payment.vendor_id)
      .gt('balance_due', 0.005);
    setOpenBills(((data ?? []) as Array<{ bill_id: string; bill_number: string; bill_total: number; balance_due: number }>).map(b => ({
      id: b.bill_id, bill_number: b.bill_number, total: Number(b.bill_total), balance_due: Number(b.balance_due),
    })));
  }, [activeOrganizationId, payment?.vendor_id]);

  useEffect(() => { loadOpenBills(); }, [loadOpenBills]);

  const handleVoid = async () => {
    if (!voidReason.trim()) { addNotification({ type: 'error', title: 'Error', message: 'Provide a reason.' }); return; }
    await voidPayment(paymentId, voidReason.trim(), user?.id ?? '');
    setShowVoidDialog(false);
    setVoidReason('');
    await refetch();
  };

  const handleApply = async () => {
    const amt = parseFloat(applyAmount);
    if (!applyBillId || !amt || amt <= 0) return;
    await applyToBill(paymentId, applyBillId, amt);
    setShowApplyDialog(false);
    setApplyBillId('');
    setApplyAmount('');
    await refetch();
    await loadOpenBills();
  };

  const handleUnapply = async () => {
    if (!unapplyAppId) return;
    await unapplyFromBill(unapplyAppId, unapplyBillId, user?.id ?? '');
    setShowUnapplyDialog(false);
    setUnapplyAppId('');
    setUnapplyBillId('');
    await refetch();
    await loadOpenBills();
  };

  if (isLoading || !payment) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[300px]">
          <div className="h-8 w-8 animate-spin rounded-full border-b-2 border-primary" />
        </div>
      </div>
    );
  }

  const isVoid = payment.status === 'void';
  const derivedStatus = isVoid ? 'void' : totalApplied >= (payment.amount - 0.005) ? 'applied' : totalApplied > 0.005 ? 'partial' : 'active';

  return (
    <div className="py-6 px-6 max-w-4xl mx-auto">
      <button onClick={() => navigateBackContextual(router, { queryReturnTo, fallback: '/financials/vendor-payments' })} className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="h-4 w-4" /> Back to Payments Made
      </button>

      {isVoid && (
        <div className="mb-4 bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm font-medium text-red-800">This payment has been voided.</p>
          {payment.void_reason && <p className="mt-1 text-sm text-red-700">Reason: {payment.void_reason}</p>}
        </div>
      )}

      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Vendor Payment</h1>
          <p className="text-sm text-gray-500 mt-0.5">{payment.vendor_name}</p>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge status={derivedStatus} type="vendorPayment" size="md" />
          {!isVoid && (
            <div className="relative">
              <button onClick={() => setShowActionsMenu(!showActionsMenu)} className="flex items-center gap-1 px-3 py-2 border border-gray-200 rounded-lg text-sm hover:bg-gray-50">
                Actions <ChevronDown className="h-4 w-4" />
              </button>
              {showActionsMenu && (
                <div className="absolute right-0 mt-1 w-48 bg-white border border-gray-200 rounded-lg shadow-lg z-20">
                  {available > 0.005 && <button onClick={() => { setShowActionsMenu(false); setShowApplyDialog(true); }} className="w-full text-left px-4 py-2 text-sm hover:bg-gray-50">Apply to Bill</button>}
                  {canVoidFin && <>
                  <div className="border-t border-gray-100" />
                  <button onClick={() => { setShowActionsMenu(false); setShowVoidDialog(true); }} className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50">Void Payment</button>
                  </>}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Payment Info */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="grid grid-cols-3 gap-4 text-sm">
          <div><span className="text-gray-500">Amount</span><p className="text-lg font-bold">{formatCurrency(payment.amount)}</p></div>
          <div><span className="text-gray-500">Applied</span><p className="text-lg font-bold text-green-600">{formatCurrency(totalApplied)}</p></div>
          <div><span className="text-gray-500">Available</span><p className="text-lg font-bold text-blue-600">{formatCurrency(available)}</p></div>
        </div>
        <div className="grid grid-cols-4 gap-4 text-sm mt-4 pt-4 border-t border-gray-100">
          <div><span className="text-gray-500">Date</span><p className="font-medium">{formatDate(payment.payment_date)}</p></div>
          <div><span className="text-gray-500">Method</span><p className="font-medium">{payment.payment_method || '—'}</p></div>
          <div><span className="text-gray-500">Reference</span><p className="font-medium">{payment.reference_number || '—'}</p></div>
          <div><span className="text-gray-500">Bank</span><p className="font-medium">{payment.bank_name || '—'}</p></div>
        </div>
        {payment.notes && <p className="mt-3 text-sm text-gray-600 border-t border-gray-100 pt-3">{payment.notes}</p>}
        <div className="mt-3 text-xs text-gray-400">Recorded by: {payment.recorded_by_name || '—'}</div>
      </div>

      {/* Applied Bills */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
        <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
          <h3 className="text-sm font-semibold text-gray-700">Applied Bills</h3>
        </div>
        {applications.length === 0 ? (
          <div className="py-8 text-center text-sm text-gray-400">No bills applied yet</div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Bill #</th>
                <th className="py-2 px-4 text-right text-xs font-medium text-gray-600">Bill Total</th>
                <th className="py-2 px-4 text-right text-xs font-medium text-gray-600">Applied</th>
                <th className="py-2 px-4 text-center text-xs font-medium text-gray-600">Date</th>
                <th className="py-2 px-4 text-right text-xs font-medium text-gray-600"></th>
              </tr>
            </thead>
            <tbody>
              {applications.map(app => (
                <tr key={app.id} className="border-b border-gray-100">
                  <td className="py-2 px-4">
                    <button onClick={() => router.navigate(withReturnTo(`/financials/bills/${app.bill_id}`, `/financials/vendor-payments/${paymentId}`))} className="text-primary hover:underline">
                      {app.bill_number}
                    </button>
                  </td>
                  <td className="py-2 px-4 text-right">{formatCurrency(app.bill_total ?? 0)}</td>
                  <td className="py-2 px-4 text-right font-medium">{formatCurrency(app.applied_amount)}</td>
                  <td className="py-2 px-4 text-center text-gray-500">{formatDate(app.created_at)}</td>
                  <td className="py-2 px-4 text-right">
                    {!isVoid && (
                      <button
                        onClick={() => { setUnapplyAppId(app.id); setUnapplyBillId(app.bill_id); setShowUnapplyDialog(true); }}
                        className="text-xs text-red-600 hover:text-red-800"
                      >
                        Unapply
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Void Dialog */}
      {showVoidDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-96 max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Void Payment</h3>
            <p className="text-sm text-gray-600 mb-3">This action cannot be undone. Provide a reason:</p>
            <textarea value={voidReason} onChange={e => setVoidReason(e.target.value)} rows={3} className="w-full px-3 py-2 border border-gray-200 rounded text-sm mb-4" placeholder="Reason for voiding..." autoFocus />
            <div className="flex justify-end gap-2">
              <button onClick={() => { setShowVoidDialog(false); setVoidReason(''); }} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              <button onClick={handleVoid} disabled={isSaving} className="px-3 py-2 bg-red-600 text-white rounded text-sm disabled:opacity-50">Void</button>
            </div>
          </div>
        </div>
      )}

      {/* Apply to Bill Dialog */}
      {showApplyDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-[28rem] max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Apply to Bill</h3>
            {openBills.length === 0 ? (
              <p className="text-sm text-gray-600 mb-4">No open bills for this vendor.</p>
            ) : (
              <>
                <div className="mb-3">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Select Bill</label>
                  <select value={applyBillId} onChange={e => { setApplyBillId(e.target.value); const b = openBills.find(x => x.id === e.target.value); if (b) setApplyAmount(Math.min(b.balance_due, available).toFixed(2)); }} className="w-full px-3 py-2 border border-gray-200 rounded text-sm">
                    <option value="">Select...</option>
                    {openBills.map(b => <option key={b.id} value={b.id}>{b.bill_number} — {formatCurrency(b.balance_due)} due</option>)}
                  </select>
                </div>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Amount</label>
                  <input type="number" value={applyAmount} onChange={e => setApplyAmount(e.target.value)} min={0} step="0.01" className="w-full px-3 py-2 border border-gray-200 rounded text-sm" />
                  <p className="text-xs text-gray-400 mt-1">Available: {formatCurrency(available)}</p>
                </div>
              </>
            )}
            <div className="flex justify-end gap-2">
              <button onClick={() => { setShowApplyDialog(false); setApplyBillId(''); setApplyAmount(''); }} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              {openBills.length > 0 && <button onClick={handleApply} disabled={isSaving || !applyBillId} className="px-3 py-2 bg-primary text-white rounded text-sm disabled:opacity-50">Apply</button>}
            </div>
          </div>
        </div>
      )}

      {/* Unapply Confirmation */}
      {showUnapplyDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-96 max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Unapply Payment</h3>
            <p className="text-sm text-gray-600 mb-4">Are you sure you want to remove this payment application?</p>
            <div className="flex justify-end gap-2">
              <button onClick={() => { setShowUnapplyDialog(false); setUnapplyAppId(''); setUnapplyBillId(''); }} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              <button onClick={handleUnapply} disabled={isSaving} className="px-3 py-2 bg-red-600 text-white rounded text-sm disabled:opacity-50">Unapply</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
