import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase, initSessionContext } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useUIStore } from '../../stores/ui-store';
import { useVendorBillMutations } from '../../hooks/useVendorBills';
import { generateNextBillNumber } from '../../lib/sequential-numbers';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual } from '../../lib/navigation/returnTo';
import { ArrowLeft, Plus, Trash2 } from 'lucide-react';
import { useGranularAccess } from '../../hooks/usePermissions';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import { resolvePurchaseTaxPct } from '../../hooks/usePurchaseOrders';

interface VendorOption { id: string; name: string; }
interface POOption { id: string; po_number: string; vendor_id: string; total: number; billing_status: string | null; billed_total: number; remaining: number; }
interface POLineRow { id: string; description: string | null; ordered_qty: number; unit_cost: number; sku_snapshot: string | null; item_name_snapshot: string | null; catalog_item_id: string | null; }

interface BillLineForm {
  key: string;
  catalog_item_id: string | null;
  purchase_order_line_id: string | null;
  description: string;
  qty: number;
  unit_cost: number;
  tax_pct: number;
}

let lineKeyCounter = 0;
function nextKey() { return `line_${++lineKeyCounter}`; }

export default function BillNew() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const addNotification = useUIStore(s => s.addNotification);
  const { canCreate: canCreateFin } = useGranularAccess('financials');
  const { createBill, isSaving } = useVendorBillMutations();

  const [vendors, setVendors] = useState<VendorOption[]>([]);
  const [vendorId, setVendorId] = useState('');
  const [vendorBillRef, setVendorBillRef] = useState('');
  const [billDate, setBillDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [dueDate, setDueDate] = useState('');
  const [notes, setNotes] = useState('');
  const [lines, setLines] = useState<BillLineForm[]>([{ key: nextKey(), catalog_item_id: null, purchase_order_line_id: null, description: '', qty: 1, unit_cost: 0, tax_pct: 0 }]);

  const [vendorTaxPct, setVendorTaxPct] = useState(0);
  const [purchaseOrders, setPurchaseOrders] = useState<POOption[]>([]);
  const [selectedPOId, setSelectedPOId] = useState('');
  const [poLines, setPOLines] = useState<POLineRow[]>([]);
  const [saveAs, setSaveAs] = useState<'draft' | 'open'>('draft');
  const [showOverBillWarning, setShowOverBillWarning] = useState(false);
  const [pendingSaveAs, setPendingSaveAs] = useState<'draft' | 'open'>('draft');
  const queryReturnTo = getReturnToFromCurrentQuery();

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
  }, [registerSubmodules]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    (async () => {
      await initSessionContext();
      const { data } = await supabase
        .from('DirectoryVendors')
        .select('id, name')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('name');
      setVendors((data ?? []) as VendorOption[]);
    })();
  }, [activeOrganizationId]);

  useEffect(() => {
    if (!activeOrganizationId || !vendorId) { setVendorTaxPct(0); return; }
    (async () => {
      const pct = await resolvePurchaseTaxPct({ organizationId: activeOrganizationId, vendorId });
      const pctDisplay = +(pct * 100).toFixed(4);
      setVendorTaxPct(pctDisplay);
      setLines(prev => prev.map(l => ({ ...l, tax_pct: pctDisplay })));
    })();
  }, [activeOrganizationId, vendorId]);

  useEffect(() => {
    if (!activeOrganizationId || !vendorId) { setPurchaseOrders([]); return; }
    (async () => {
      await initSessionContext();
      const { data } = await supabase
        .from('PurchaseOrders')
        .select('id, po_number, vendor_id, total, billing_status')
        .eq('organization_id', activeOrganizationId)
        .eq('vendor_id', vendorId)
        .in('billing_status', ['unbilled', 'partial'])
        .order('created_at', { ascending: false });

      const poRows = (data ?? []) as Array<{ id: string; po_number: string; vendor_id: string; total: number; billing_status: string | null }>;

      if (poRows.length === 0) { setPurchaseOrders([]); return; }

      const { data: billsData } = await supabase
        .from('VendorBills')
        .select('purchase_order_id, total')
        .in('purchase_order_id', poRows.map(p => p.id))
        .eq('deleted', false)
        .neq('status', 'void');

      const billedByPO = new Map<string, number>();
      ((billsData ?? []) as Array<{ purchase_order_id: string; total: number }>).forEach(b => {
        billedByPO.set(b.purchase_order_id, (billedByPO.get(b.purchase_order_id) ?? 0) + (Number(b.total) || 0));
      });

      setPurchaseOrders(poRows.map(po => {
        const poTotal = Number(po.total) || 0;
        const billed = billedByPO.get(po.id) ?? 0;
        return { ...po, total: poTotal, billed_total: billed, remaining: Math.max(0, poTotal - billed) };
      }));
    })();
  }, [activeOrganizationId, vendorId]);

  useEffect(() => {
    if (!selectedPOId) { setPOLines([]); return; }
    (async () => {
      await initSessionContext();
      const { data } = await supabase
        .from('PurchaseOrderLines')
        .select('id, description, ordered_qty, unit_cost, sku_snapshot, item_name_snapshot, catalog_item_id')
        .eq('purchase_order_id', selectedPOId)
        .order('created_at');
      setPOLines((data ?? []) as POLineRow[]);
    })();
  }, [selectedPOId]);

  const importPOLines = useCallback(() => {
    if (poLines.length === 0) return;
    const newLines: BillLineForm[] = poLines.map(pl => ({
      key: nextKey(),
      catalog_item_id: pl.catalog_item_id,
      purchase_order_line_id: pl.id,
      description: pl.item_name_snapshot || pl.description || pl.sku_snapshot || '',
      qty: Number(pl.ordered_qty) || 0,
      unit_cost: Number(pl.unit_cost) || 0,
      tax_pct: vendorTaxPct,
    }));
    setLines(newLines);
    addNotification({ type: 'success', title: 'PO Lines Imported', message: `${newLines.length} lines imported from PO.` });
  }, [poLines, addNotification, vendorTaxPct]);

  const addLine = () => setLines(prev => [...prev, { key: nextKey(), catalog_item_id: null, purchase_order_line_id: null, description: '', qty: 1, unit_cost: 0, tax_pct: vendorTaxPct }]);
  const removeLine = (key: string) => setLines(prev => prev.filter(l => l.key !== key));
  const updateLine = (key: string, field: keyof BillLineForm, value: string | number) => {
    setLines(prev => prev.map(l => l.key === key ? { ...l, [field]: value } : l));
  };

  const totals = useMemo(() => {
    let subtotal = 0, taxTotal = 0;
    lines.forEach(l => {
      const sub = l.qty * l.unit_cost;
      subtotal += sub;
      taxTotal += sub * l.tax_pct / 100;
    });
    return { subtotal: +subtotal.toFixed(2), taxTotal: +taxTotal.toFixed(2), total: +(subtotal + taxTotal).toFixed(2) };
  }, [lines]);

  const selectedPO = purchaseOrders.find(p => p.id === selectedPOId);
  const exceedsPORemaining = selectedPO ? totals.total > selectedPO.remaining + 0.005 : false;

  const doSave = async (saveDraft: 'draft' | 'open') => {
    if (!activeOrganizationId || !vendorId) {
      addNotification({ type: 'error', title: 'Error', message: 'Select a vendor.' });
      return;
    }
    if (lines.length === 0 || lines.every(l => !l.description.trim())) {
      addNotification({ type: 'error', title: 'Error', message: 'Add at least one line item.' });
      return;
    }
    try {
      const billNumber = await generateNextBillNumber(activeOrganizationId);
      const billId = await createBill({
        vendor_id: vendorId,
        purchase_order_id: selectedPOId || null,
        bill_number: billNumber,
        vendor_bill_ref: vendorBillRef.trim() || null,
        status: saveDraft,
        bill_date: billDate,
        due_date: dueDate || null,
        notes: notes.trim() || null,
        lines: lines.filter(l => l.description.trim()).map((l, i) => ({
          catalog_item_id: l.catalog_item_id,
          purchase_order_line_id: l.purchase_order_line_id,
          sort_order: i,
          description: l.description,
          qty: l.qty,
          unit_cost: l.unit_cost,
          tax_pct: l.tax_pct,
        })),
      });
      router.navigate(`/financials/bills/${billId}`);
    } catch {
      // Error notification handled by hook
    }
  };

  const handleSave = (mode: 'draft' | 'open') => {
    if (exceedsPORemaining && selectedPOId) {
      setPendingSaveAs(mode);
      setShowOverBillWarning(true);
      return;
    }
    doSave(mode);
  };

  const returnTo = getReturnToFromCurrentQuery() || '/financials/bills';

  return (
    <div className="py-6 px-6 max-w-5xl mx-auto">
      <button onClick={() => navigateBackContextual(router, { queryReturnTo, fallback: '/financials/bills' })} className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="h-4 w-4" /> Back to Bills
      </button>

      <h1 className="text-xl font-semibold text-foreground mb-6">New Vendor Bill</h1>

      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Vendor *</label>
            <select
              value={vendorId}
              onChange={e => { setVendorId(e.target.value); setSelectedPOId(''); }}
              className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
            >
              <option value="">Select vendor...</option>
              {vendors.map(v => <option key={v.id} value={v.id}>{v.name}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Vendor Bill Ref</label>
            <input
              type="text"
              value={vendorBillRef}
              onChange={e => setVendorBillRef(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
              placeholder="Vendor's invoice #"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Bill Date *</label>
            <input type="date" value={billDate} onChange={e => setBillDate(e.target.value)} className="w-full px-3 py-2 border border-gray-200 rounded text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Due Date</label>
            <input type="date" value={dueDate} onChange={e => setDueDate(e.target.value)} className="w-full px-3 py-2 border border-gray-200 rounded text-sm" />
          </div>
        </div>

        {vendorId && purchaseOrders.length > 0 && (
          <div className="mt-4 pt-4 border-t border-gray-200">
            <label className="block text-sm font-medium text-gray-700 mb-1">Import from Purchase Order</label>
            <div className="flex items-center gap-2">
              <select
                value={selectedPOId}
                onChange={e => setSelectedPOId(e.target.value)}
                className="flex-1 px-3 py-2 border border-gray-200 rounded text-sm"
              >
                <option value="">Select PO (optional)...</option>
                {purchaseOrders.map(po => (
                  <option key={po.id} value={po.id}>
                    {po.po_number} — ${po.remaining.toFixed(2)} remaining of ${po.total.toFixed(2)}
                  </option>
                ))}
              </select>
              <button
                onClick={importPOLines}
                disabled={!selectedPOId || poLines.length === 0}
                className="px-3 py-2 bg-blue-600 text-white rounded text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Import Lines
              </button>
            </div>
            {exceedsPORemaining && selectedPO && (
              <div className="mt-2 rounded border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
                Bill total (${totals.total.toFixed(2)}) exceeds PO remaining amount (${selectedPO.remaining.toFixed(2)}). You can still save, but a confirmation will be required.
              </div>
            )}
          </div>
        )}

        <div className="mt-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
          <textarea
            value={notes}
            onChange={e => setNotes(e.target.value)}
            rows={2}
            className="w-full px-3 py-2 border border-gray-200 rounded text-sm"
          />
        </div>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-gray-700">Line Items</h2>
          <button onClick={addLine} className="flex items-center gap-1 text-sm text-primary hover:text-primary/80">
            <Plus className="h-4 w-4" /> Add Line
          </button>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="py-2 px-3 text-left text-xs font-medium text-gray-600 w-[40%]">Description</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600 w-[12%]">Qty</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600 w-[15%]">Unit Cost</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600 w-[10%]">Tax %</th>
              <th className="py-2 px-3 text-right text-xs font-medium text-gray-600 w-[15%]">Line Total</th>
              <th className="py-2 px-3 text-center text-xs font-medium text-gray-600 w-[8%]"></th>
            </tr>
          </thead>
          <tbody>
            {lines.map(line => {
              const lineSubtotal = line.qty * line.unit_cost;
              const lineTax = lineSubtotal * line.tax_pct / 100;
              const lineTotal = lineSubtotal + lineTax;
              return (
                <tr key={line.key} className="border-b border-gray-100">
                  <td className="py-2 px-3">
                    <input
                      type="text"
                      value={line.description}
                      onChange={e => updateLine(line.key, 'description', e.target.value)}
                      className="w-full px-2 py-1 border border-gray-200 rounded text-sm"
                      placeholder="Item description"
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="number"
                      value={line.qty}
                      onChange={e => updateLine(line.key, 'qty', parseFloat(e.target.value) || 0)}
                      className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-center"
                      min={0}
                      step="any"
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="number"
                      value={line.unit_cost}
                      onChange={e => updateLine(line.key, 'unit_cost', parseFloat(e.target.value) || 0)}
                      className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-center"
                      min={0}
                      step="any"
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="number"
                      value={line.tax_pct}
                      onChange={e => updateLine(line.key, 'tax_pct', parseFloat(e.target.value) || 0)}
                      className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-center"
                      min={0}
                      step="any"
                    />
                  </td>
                  <td className="py-2 px-3 text-right font-medium">${lineTotal.toFixed(2)}</td>
                  <td className="py-2 px-3 text-center">
                    <button onClick={() => removeLine(line.key)} className="p-1 hover:bg-gray-100 rounded text-gray-400 hover:text-gray-600" disabled={lines.length <= 1}>
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        <div className="mt-4 flex justify-end">
          <div className="w-64 text-sm space-y-1">
            <div className="flex justify-between"><span className="text-gray-500">Subtotal</span><span>${totals.subtotal.toFixed(2)}</span></div>
            <div className="flex justify-between"><span className="text-gray-500">Tax</span><span>${totals.taxTotal.toFixed(2)}</span></div>
            <div className="flex justify-between font-semibold border-t border-gray-200 pt-1"><span>Total</span><span>${totals.total.toFixed(2)}</span></div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-end gap-3">
        <button
          onClick={() => navigateBackContextual(router, { queryReturnTo, fallback: '/financials/bills' })}
          className="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-700 hover:bg-gray-50"
        >
          Cancel
        </button>
        <button
          onClick={() => handleSave('draft')}
          disabled={isSaving || !canCreateFin}
          className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
        >
          Save as Draft
        </button>
        <button
          onClick={() => handleSave('open')}
          disabled={isSaving || !canCreateFin}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50"
        >
          Save & Issue
        </button>
      </div>

      {showOverBillWarning && selectedPO && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 className="text-sm font-semibold text-gray-900 mb-2">Bill Exceeds PO Remaining</h3>
            <p className="text-sm text-gray-600 mb-1">
              This bill total (<span className="font-medium">${totals.total.toFixed(2)}</span>) exceeds the remaining unbilled amount for <span className="font-medium">{selectedPO.po_number}</span>.
            </p>
            <div className="text-xs text-gray-500 mb-4 space-y-0.5">
              <div className="flex justify-between"><span>PO Total:</span><span>${selectedPO.total.toFixed(2)}</span></div>
              <div className="flex justify-between"><span>Already Billed:</span><span>${selectedPO.billed_total.toFixed(2)}</span></div>
              <div className="flex justify-between font-medium text-amber-700"><span>Remaining:</span><span>${selectedPO.remaining.toFixed(2)}</span></div>
              <div className="flex justify-between font-medium text-red-600 pt-1 border-t"><span>This Bill:</span><span>${totals.total.toFixed(2)}</span></div>
            </div>
            <p className="text-xs text-gray-500 mb-4">This may be valid (e.g. price changes or additional charges). Do you want to proceed?</p>
            <div className="flex justify-end gap-2">
              <button onClick={() => setShowOverBillWarning(false)} className="px-4 py-2 border border-gray-200 rounded text-sm text-gray-700 hover:bg-gray-50">Cancel</button>
              <button onClick={() => { setShowOverBillWarning(false); doSave(pendingSaveAs); }} className="px-4 py-2 bg-amber-600 text-white rounded text-sm font-medium hover:bg-amber-700">Proceed Anyway</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
