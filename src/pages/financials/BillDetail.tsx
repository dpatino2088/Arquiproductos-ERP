import { useState, useEffect, useCallback } from 'react';
import { supabase, initSessionContext } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';
import { useVendorBillDetail, useVendorBillMutations } from '../../hooks/useVendorBills';
import { useVendorPaymentMutations } from '../../hooks/useVendorPayments';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { formatCurrency, formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { ArrowLeft, ChevronDown } from 'lucide-react';
import { generateNextVendorCreditNumber } from '../../lib/sequential-numbers';
import { useGranularAccess } from '../../hooks/usePermissions';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

interface PaymentApp {
  id: string;
  vendor_payment_id: string;
  applied_amount: number;
  created_at: string;
  payment_date?: string;
  payment_method?: string;
  reference_number?: string;
}

interface VendorCredit {
  id: string;
  credit_number: string;
  amount: number;
  reason: string | null;
  status: string;
  issue_date: string;
}

interface OpenPaymentOption {
  id: string;
  amount: number;
  applied_total: number;
  available: number;
  payment_date: string;
  reference_number: string | null;
}

export default function BillDetail() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const addNotification = useUIStore(s => s.addNotification);
  const { canDelete: canDeleteFin, canVoid: canVoidFin } = useGranularAccess('financials');

  const billId = window.location.pathname.split('/').pop() ?? '';
  const { bill, isLoading, refetch } = useVendorBillDetail(billId || null);
  const { voidBill, deleteDraft, issueBill, isSaving: billSaving } = useVendorBillMutations();
  const { recordPayment, applyToBill, isSaving: paymentSaving } = useVendorPaymentMutations();

  const [applications, setApplications] = useState<PaymentApp[]>([]);
  const [credits, setCredits] = useState<VendorCredit[]>([]);
  const [openPayments, setOpenPayments] = useState<OpenPaymentOption[]>([]);

  const [showVoidDialog, setShowVoidDialog] = useState(false);
  const [voidReason, setVoidReason] = useState('');
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showApplyDialog, setShowApplyDialog] = useState(false);
  const [applyPaymentId, setApplyPaymentId] = useState('');
  const [applyAmount, setApplyAmount] = useState('');
  const [showCreditDialog, setShowCreditDialog] = useState(false);
  const [creditAmount, setCreditAmount] = useState('');
  const [creditReason, setCreditReason] = useState('');
  const [showActionsMenu, setShowActionsMenu] = useState(false);
  const [showRecordPaymentDialog, setShowRecordPaymentDialog] = useState(false);
  const [rpAmount, setRpAmount] = useState('');
  const [rpMethod, setRpMethod] = useState('check');
  const [rpReference, setRpReference] = useState('');
  const [rpDate, setRpDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [rpBankName, setRpBankName] = useState('');
  const [rpNotes, setRpNotes] = useState('');
  const [rpSaving, setRpSaving] = useState(false);

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  const loadRelated = useCallback(async () => {
    if (!billId || !activeOrganizationId) return;
    await initSessionContext();

    const { data: apps } = await supabase
      .from('VendorPaymentApplications')
      .select('id, vendor_payment_id, applied_amount, created_at')
      .eq('bill_id', billId);

    const paymentIds = [...new Set(((apps ?? []) as PaymentApp[]).map(a => a.vendor_payment_id).filter(Boolean))];
    let paymentMap = new Map<string, { payment_date: string; payment_method: string | null; reference_number: string | null }>();
    if (paymentIds.length > 0) {
      const { data: payments } = await supabase
        .from('VendorPayments')
        .select('id, payment_date, payment_method, reference_number')
        .in('id', paymentIds);
      paymentMap = new Map(((payments ?? []) as Array<{ id: string; payment_date: string; payment_method: string | null; reference_number: string | null }>).map(p => [p.id, p]));
    }

    setApplications(((apps ?? []) as PaymentApp[]).map(a => ({
      ...a,
      applied_amount: Number(a.applied_amount) || 0,
      payment_date: paymentMap.get(a.vendor_payment_id)?.payment_date,
      payment_method: paymentMap.get(a.vendor_payment_id)?.payment_method ?? undefined,
      reference_number: paymentMap.get(a.vendor_payment_id)?.reference_number ?? undefined,
    })));

    const { data: crs } = await supabase
      .from('VendorCredits')
      .select('id, credit_number, amount, reason, status, issue_date')
      .eq('bill_id', billId)
      .eq('deleted', false);
    setCredits(((crs ?? []) as VendorCredit[]).map(c => ({ ...c, amount: Number(c.amount) || 0 })));
  }, [billId, activeOrganizationId]);

  const loadOpenPayments = useCallback(async () => {
    if (!activeOrganizationId || !bill?.vendor_id) return;
    await initSessionContext();

    const { data: payments } = await supabase
      .from('VendorPayments')
      .select('id, amount, payment_date, reference_number')
      .eq('organization_id', activeOrganizationId)
      .eq('vendor_id', bill.vendor_id)
      .eq('deleted', false)
      .neq('status', 'void');

    if (!payments) { setOpenPayments([]); return; }

    const paymentIds = (payments as Array<{ id: string }>).map(p => p.id);
    const { data: allApps } = paymentIds.length > 0
      ? await supabase.from('VendorPaymentApplications').select('vendor_payment_id, applied_amount').in('vendor_payment_id', paymentIds)
      : { data: [] };

    const appliedByPayment = new Map<string, number>();
    ((allApps ?? []) as Array<{ vendor_payment_id: string; applied_amount: number }>).forEach(a => {
      appliedByPayment.set(a.vendor_payment_id, (appliedByPayment.get(a.vendor_payment_id) || 0) + Number(a.applied_amount));
    });

    const opts = (payments as Array<{ id: string; amount: number; payment_date: string; reference_number: string | null }>)
      .map(p => {
        const amt = Number(p.amount) || 0;
        const applied = appliedByPayment.get(p.id) || 0;
        return { ...p, amount: amt, applied_total: applied, available: +(amt - applied).toFixed(2) };
      })
      .filter(p => p.available > 0.005);

    setOpenPayments(opts);
  }, [activeOrganizationId, bill?.vendor_id]);

  useEffect(() => { loadRelated(); }, [loadRelated]);
  useEffect(() => { loadOpenPayments(); }, [loadOpenPayments]);

  const totalApplied = applications.reduce((s, a) => s + a.applied_amount, 0);
  const totalCredited = credits.filter(c => c.status !== 'void').reduce((s, c) => s + c.amount, 0);
  const balanceDue = Math.max(0, (bill?.total ?? 0) - totalApplied - totalCredited);

  const handleVoid = async () => {
    if (!voidReason.trim()) { addNotification({ type: 'error', title: 'Error', message: 'Provide a reason.' }); return; }
    await voidBill(billId, voidReason.trim(), user?.id ?? '');
    setShowVoidDialog(false);
    setVoidReason('');
    await refetch();
    await loadRelated();
  };

  const queryReturnTo = getReturnToFromCurrentQuery();

  const handleDelete = async () => {
    await deleteDraft(billId);
    setShowDeleteDialog(false);
    navigateBackContextual(router, { queryReturnTo, fallback: '/financials/bills' });
  };

  const handleIssue = async () => {
    await issueBill(billId);
    await refetch();
  };

  const handleApplyPayment = async () => {
    const amt = parseFloat(applyAmount);
    if (!applyPaymentId || !amt || amt <= 0) return;
    await applyToBill(applyPaymentId, billId, amt);
    setShowApplyDialog(false);
    setApplyPaymentId('');
    setApplyAmount('');
    await refetch();
    await loadRelated();
    await loadOpenPayments();
  };

  const handleCreateCredit = async () => {
    const amt = parseFloat(creditAmount);
    if (!amt || amt <= 0 || !activeOrganizationId || !bill) return;
    try {
      await initSessionContext();
      const creditNumber = await generateNextVendorCreditNumber(activeOrganizationId);
      const { error } = await supabase.from('VendorCredits').insert({
        organization_id: activeOrganizationId,
        vendor_id: bill.vendor_id,
        bill_id: billId,
        credit_number: creditNumber,
        amount: amt,
        reason: creditReason.trim() || null,
        status: 'issued',
      });
      if (error) throw error;
      addNotification({ type: 'success', title: 'Credit Created', message: `Credit ${creditNumber} created.` });
      setShowCreditDialog(false);
      setCreditAmount('');
      setCreditReason('');
      await refetch();
      await loadRelated();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to create credit' });
    }
  };

  const handleRecordPayment = async () => {
    const amt = parseFloat(rpAmount);
    if (!amt || amt <= 0 || !activeOrganizationId || !bill) return;
    setRpSaving(true);
    try {
      const paymentId = await recordPayment({
        vendor_id: bill.vendor_id,
        amount: amt,
        payment_method: rpMethod,
        reference_number: rpReference || undefined,
        bank_name: rpBankName || undefined,
        payment_date: rpDate,
        notes: rpNotes || null,
        userId: user?.id ?? null,
        userName: user?.name ?? user?.email ?? null,
      });
      await applyToBill(paymentId, billId, amt);
      setShowRecordPaymentDialog(false);
      setRpAmount('');
      setRpMethod('check');
      setRpReference('');
      setRpDate(new Date().toISOString().slice(0, 10));
      setRpBankName('');
      setRpNotes('');
      await refetch();
      await loadRelated();
      await loadOpenPayments();
    } catch {
      // notifications handled by hook
    } finally {
      setRpSaving(false);
    }
  };

  const handleVoidCredit = async (creditId: string) => {
    if (!activeOrganizationId) return;
    const reason = prompt('Reason for voiding this credit:');
    if (!reason?.trim()) return;
    await initSessionContext();
    await supabase.from('VendorCredits').update({ status: 'void', void_reason: reason.trim(), voided_by: user?.id ?? null, voided_at: new Date().toISOString() }).eq('id', creditId);
    await supabase.from('FinancialAuditLog').insert({ organization_id: activeOrganizationId, entity_type: 'vendor_credit', entity_id: creditId, action: 'void', performed_by: user?.id ?? '', details: { reason: reason.trim() } });
    addNotification({ type: 'success', title: 'Credit Voided', message: 'Vendor credit voided.' });
    await loadRelated();
  };

  if (isLoading || !bill) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[300px]">
          <div className="h-8 w-8 animate-spin rounded-full border-b-2 border-primary" />
        </div>
      </div>
    );
  }

  const isVoid = bill.status === 'void';
  const isDraft = bill.status === 'draft';

  return (
    <div className="py-6 px-6 max-w-5xl mx-auto">
      <button onClick={() => navigateBackContextual(router, { queryReturnTo, fallback: '/financials/bills' })} className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="h-4 w-4" /> Back to Bills
      </button>

      {isVoid && (
        <div className="mb-4 bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm font-medium text-red-800">This bill has been voided.</p>
          {bill.void_reason && <p className="mt-1 text-sm text-red-700">Reason: {bill.void_reason}</p>}
        </div>
      )}

      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">{bill.bill_number}</h1>
          <p className="text-sm text-gray-500 mt-0.5">{bill.vendor_name}{bill.vendor_bill_ref ? ` — Ref: ${bill.vendor_bill_ref}` : ''}</p>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge status={bill.status} type="bill" size="md" />
          {!isVoid && (
            <div className="relative">
              <button onClick={() => setShowActionsMenu(!showActionsMenu)} className="flex items-center gap-1 px-3 py-2 border border-gray-200 rounded-lg text-sm hover:bg-gray-50">
                Actions <ChevronDown className="h-4 w-4" />
              </button>
              {showActionsMenu && (
                <div className="absolute right-0 mt-1 w-48 bg-white border border-gray-200 rounded-lg shadow-lg z-20">
                  {isDraft && <button onClick={() => { setShowActionsMenu(false); handleIssue(); }} className="w-full text-left px-4 py-2 text-sm hover:bg-gray-50">Issue Bill</button>}
                  {!isDraft && balanceDue > 0.005 && <button onClick={() => { setShowActionsMenu(false); setRpAmount(balanceDue.toFixed(2)); setShowRecordPaymentDialog(true); }} className="w-full text-left px-4 py-2 text-sm hover:bg-gray-50 font-medium">Record Payment</button>}
                  {!isDraft && <button onClick={() => { setShowActionsMenu(false); setShowApplyDialog(true); }} className="w-full text-left px-4 py-2 text-sm hover:bg-gray-50">Apply Existing Payment</button>}
                  {!isDraft && <button onClick={() => { setShowActionsMenu(false); setShowCreditDialog(true); }} className="w-full text-left px-4 py-2 text-sm hover:bg-gray-50">Create Credit</button>}
                  <div className="border-t border-gray-100" />
                  {isDraft && canDeleteFin && <button onClick={() => { setShowActionsMenu(false); setShowDeleteDialog(true); }} className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50">Delete Draft</button>}
                  {!isDraft && canVoidFin && <button onClick={() => { setShowActionsMenu(false); setShowVoidDialog(true); }} className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50">Void Bill</button>}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Bill Info */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="grid grid-cols-4 gap-4 text-sm">
          <div><span className="text-gray-500">Bill Date</span><p className="font-medium">{formatDate(bill.bill_date)}</p></div>
          <div><span className="text-gray-500">Due Date</span><p className="font-medium">{formatDate(bill.due_date)}</p></div>
          <div><span className="text-gray-500">Currency</span><p className="font-medium">{bill.currency_code}</p></div>
          <div><span className="text-gray-500">PO #</span><p className="font-medium">{bill.purchase_order_id ? <button onClick={() => router.navigate(`/inventory/purchase-orders/${bill.purchase_order_id}`)} className="text-primary hover:underline">View PO</button> : '—'}</p></div>
        </div>
        {bill.notes && <p className="mt-3 text-sm text-gray-600 border-t border-gray-100 pt-3">{bill.notes}</p>}
      </div>

      {/* Line Items */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="py-3 px-4 text-left text-xs font-medium text-gray-700">Description</th>
              <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Qty</th>
              <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Unit Cost</th>
              <th className="py-3 px-4 text-center text-xs font-medium text-gray-700">Tax %</th>
              <th className="py-3 px-4 text-right text-xs font-medium text-gray-700">Line Total</th>
            </tr>
          </thead>
          <tbody>
            {(bill.lines ?? []).map(line => (
              <tr key={line.id} className="border-b border-gray-100">
                <td className="py-3 px-4">{line.description || '—'}</td>
                <td className="py-3 px-4 text-center">{line.qty}</td>
                <td className="py-3 px-4 text-right">{formatCurrency(line.unit_cost)}</td>
                <td className="py-3 px-4 text-center">{line.tax_pct}%</td>
                <td className="py-3 px-4 text-right font-medium">{formatCurrency(line.line_total)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="flex justify-end p-4 border-t border-gray-200">
          <div className="w-64 text-sm space-y-1">
            <div className="flex justify-between"><span className="text-gray-500">Subtotal</span><span>{formatCurrency(bill.subtotal)}</span></div>
            <div className="flex justify-between"><span className="text-gray-500">Tax</span><span>{formatCurrency(bill.tax_total)}</span></div>
            <div className="flex justify-between font-semibold border-t border-gray-200 pt-1"><span>Total</span><span>{formatCurrency(bill.total)}</span></div>
            {totalApplied > 0 && <div className="flex justify-between text-green-600"><span>Paid</span><span>-{formatCurrency(totalApplied)}</span></div>}
            {totalCredited > 0 && <div className="flex justify-between text-blue-600"><span>Credits</span><span>-{formatCurrency(totalCredited)}</span></div>}
            <div className="flex justify-between font-bold text-lg border-t border-gray-300 pt-1"><span>Balance Due</span><span>{formatCurrency(balanceDue)}</span></div>
          </div>
        </div>
      </div>

      {/* Payment Applications */}
      {applications.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
          <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
            <h3 className="text-sm font-semibold text-gray-700">Payment Applications</h3>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Date</th>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Method</th>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Reference</th>
                <th className="py-2 px-4 text-right text-xs font-medium text-gray-600">Applied</th>
              </tr>
            </thead>
            <tbody>
              {applications.map(app => (
                <tr key={app.id} className="border-b border-gray-100">
                  <td className="py-2 px-4">{formatDate(app.payment_date ?? app.created_at)}</td>
                  <td className="py-2 px-4">{app.payment_method || '—'}</td>
                  <td className="py-2 px-4">{app.reference_number || '—'}</td>
                  <td className="py-2 px-4 text-right font-medium">{formatCurrency(app.applied_amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Vendor Credits */}
      {credits.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
          <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
            <h3 className="text-sm font-semibold text-gray-700">Vendor Credits</h3>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Credit #</th>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Date</th>
                <th className="py-2 px-4 text-left text-xs font-medium text-gray-600">Reason</th>
                <th className="py-2 px-4 text-right text-xs font-medium text-gray-600">Amount</th>
                <th className="py-2 px-4 text-center text-xs font-medium text-gray-600">Status</th>
                <th className="py-2 px-4 text-right text-xs font-medium text-gray-600"></th>
              </tr>
            </thead>
            <tbody>
              {credits.map(cr => (
                <tr key={cr.id} className={`border-b border-gray-100 ${cr.status === 'void' ? 'opacity-50 line-through' : ''}`}>
                  <td className="py-2 px-4">{cr.credit_number}</td>
                  <td className="py-2 px-4">{cr.issue_date}</td>
                  <td className="py-2 px-4">{cr.reason || '—'}</td>
                  <td className="py-2 px-4 text-right font-medium">{formatCurrency(cr.amount)}</td>
                  <td className="py-2 px-4 text-center"><StatusBadge status={cr.status} type="bill" size="sm" /></td>
                  <td className="py-2 px-4 text-right">
                    {cr.status !== 'void' && canVoidFin && (
                      <button onClick={() => handleVoidCredit(cr.id)} className="text-xs text-red-600 hover:text-red-800">Void</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Void Dialog */}
      {showVoidDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-96 max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Void Bill</h3>
            <p className="text-sm text-gray-600 mb-3">This action cannot be undone. Provide a reason:</p>
            <textarea
              value={voidReason}
              onChange={e => setVoidReason(e.target.value)}
              rows={3}
              className="w-full px-3 py-2 border border-gray-200 rounded text-sm mb-4"
              placeholder="Reason for voiding..."
              autoFocus
            />
            <div className="flex justify-end gap-2">
              <button onClick={() => { setShowVoidDialog(false); setVoidReason(''); }} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              <button onClick={handleVoid} disabled={billSaving} className="px-3 py-2 bg-red-600 text-white rounded text-sm disabled:opacity-50">Void Bill</button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Draft Dialog */}
      {showDeleteDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-96 max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Delete Draft Bill</h3>
            <p className="text-sm text-gray-600 mb-4">Are you sure you want to delete this draft bill?</p>
            <div className="flex justify-end gap-2">
              <button onClick={() => setShowDeleteDialog(false)} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              <button onClick={handleDelete} disabled={billSaving} className="px-3 py-2 bg-red-600 text-white rounded text-sm disabled:opacity-50">Delete</button>
            </div>
          </div>
        </div>
      )}

      {/* Apply Payment Dialog */}
      {showApplyDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-[28rem] max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Apply Payment to Bill</h3>
            {openPayments.length === 0 ? (
              <p className="text-sm text-gray-600 mb-4">No available vendor payments to apply. Record a payment first.</p>
            ) : (
              <>
                <div className="mb-3">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Select Payment</label>
                  <select value={applyPaymentId} onChange={e => { setApplyPaymentId(e.target.value); const p = openPayments.find(x => x.id === e.target.value); if (p) setApplyAmount(Math.min(p.available, balanceDue).toFixed(2)); }} className="w-full px-3 py-2 border border-gray-200 rounded text-sm">
                    <option value="">Select...</option>
                    {openPayments.map(p => (
                      <option key={p.id} value={p.id}>{formatDate(p.payment_date)} — {formatCurrency(p.available)} available{p.reference_number ? ` (${p.reference_number})` : ''}</option>
                    ))}
                  </select>
                </div>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Amount to Apply</label>
                  <input type="number" value={applyAmount} onChange={e => setApplyAmount(e.target.value)} min={0} step="0.01" className="w-full px-3 py-2 border border-gray-200 rounded text-sm" />
                </div>
              </>
            )}
            <div className="flex justify-end gap-2">
              <button onClick={() => { setShowApplyDialog(false); setApplyPaymentId(''); setApplyAmount(''); }} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              {openPayments.length > 0 && <button onClick={handleApplyPayment} disabled={paymentSaving || !applyPaymentId} className="px-3 py-2 bg-primary text-white rounded text-sm disabled:opacity-50">Apply</button>}
            </div>
          </div>
        </div>
      )}

      {/* Record Payment Dialog */}
      {showRecordPaymentDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-[30rem] max-w-[90vw] max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-semibold mb-1">Record Payment</h3>
            <p className="text-sm text-gray-500 mb-4">Pay bill {bill.bill_number} — {bill.vendor_name}</p>
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Amount *</label>
                  <input
                    type="number"
                    value={rpAmount}
                    onChange={e => setRpAmount(e.target.value)}
                    min={0}
                    step="0.01"
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  />
                  <p className="text-xs text-gray-400 mt-1">Balance due: {formatCurrency(balanceDue)}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Date *</label>
                  <input
                    type="date"
                    value={rpDate}
                    onChange={e => setRpDate(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Payment Method</label>
                  <select
                    value={rpMethod}
                    onChange={e => setRpMethod(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  >
                    <option value="check">Check</option>
                    <option value="wire_transfer">Wire Transfer</option>
                    <option value="ach">ACH</option>
                    <option value="credit_card">Credit Card</option>
                    <option value="cash">Cash</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Reference #</label>
                  <input
                    type="text"
                    value={rpReference}
                    onChange={e => setRpReference(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                    placeholder="Check #, wire ref, etc."
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Bank Name</label>
                <input
                  type="text"
                  value={rpBankName}
                  onChange={e => setRpBankName(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  placeholder="Bank name (optional)"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
                <textarea
                  value={rpNotes}
                  onChange={e => setRpNotes(e.target.value)}
                  rows={2}
                  className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
                  placeholder="Internal notes (optional)"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 mt-5">
              <button onClick={() => { setShowRecordPaymentDialog(false); setRpAmount(''); setRpReference(''); setRpBankName(''); setRpNotes(''); }} className="px-4 py-2 border border-gray-200 rounded-lg text-sm">Cancel</button>
              <button onClick={handleRecordPayment} disabled={rpSaving || !rpAmount} className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium disabled:opacity-50 hover:bg-primary/90">{rpSaving ? 'Saving...' : 'Record Payment'}</button>
            </div>
          </div>
        </div>
      )}

      {/* Create Credit Dialog */}
      {showCreditDialog && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 w-96 max-w-[90vw]">
            <h3 className="text-lg font-semibold mb-4">Create Vendor Credit</h3>
            <div className="mb-3">
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount</label>
              <input type="number" value={creditAmount} onChange={e => setCreditAmount(e.target.value)} min={0} step="0.01" className="w-full px-3 py-2 border border-gray-200 rounded text-sm" placeholder={`Max: ${balanceDue.toFixed(2)}`} />
            </div>
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">Reason</label>
              <textarea value={creditReason} onChange={e => setCreditReason(e.target.value)} rows={2} className="w-full px-3 py-2 border border-gray-200 rounded text-sm" placeholder="Reason for credit..." />
            </div>
            <div className="flex justify-end gap-2">
              <button onClick={() => { setShowCreditDialog(false); setCreditAmount(''); setCreditReason(''); }} className="px-3 py-2 border border-gray-200 rounded text-sm">Cancel</button>
              <button onClick={handleCreateCredit} className="px-3 py-2 bg-primary text-white rounded text-sm">Create Credit</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
