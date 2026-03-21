import { useEffect, useState, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useInventoryMovements } from '../../hooks/useInventoryMovements';
import { usePurchaseOrders, useReceivePurchaseOrder, type PurchaseOrderStatus } from '../../hooks/usePurchaseOrders';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase/client';
import { Search, SortAsc, SortDesc, Plus, ArrowLeft, Package } from 'lucide-react';
import Input from '../../components/ui/Input';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

interface POLineForReceipt {
  id: string;
  catalog_item_id: string | null;
  sku: string;
  name: string;
  description: string;
  is_one_off: boolean;
  ordered_qty: number;
  received_qty: number;
  remaining: number;
  unit: string;
  purchase_unit_snapshot?: string | null;
  units_per_purchase_unit_snapshot?: number | null;
  is_roll_snapshot?: boolean | null;
  roll_length_value_snapshot?: number | null;
  roll_length_uom_snapshot?: string | null;
}

function formatPurchaseSuffix(purchaseUnit: string | null | undefined, unitsPerPurchase: number | null | undefined): string {
  const unit = (purchaseUnit ?? '').trim().toLowerCase();
  const units = Number(unitsPerPurchase ?? 1);
  if (unit === 'roll') return '(roll)';
  if (Number.isFinite(units) && units > 1) return `(${units} unit)`;
  if (unit && unit !== 'each') return `(${unit})`;
  return '';
}

function formatRollPurchaseInfo(length: number | null | undefined, lengthUom: string | null | undefined): string {
  const l = Number(length ?? 0);
  const uom = (lengthUom ?? '').trim();
  if (!(l > 0)) return '(roll)';
  const pretty = Number.isFinite(l) ? l.toFixed(2).replace(/\.00$/, '') : String(length ?? '');
  return `(${pretty} ${uom || 'unit'})`;
}

export default function Receipts() {
  const { registerSubmodules } = useSubmoduleNav();
  const { movements, loading, refetch } = useInventoryMovements({ movementType: 'receipt' });
  const { activeOrganizationId } = useOrganizationContext();
  const addNotification = useUIStore((s) => s.addNotification);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'draft' | 'confirmed' | ''>('');
  const [sortBy, setSortBy] = useState<'movement_no' | 'movement_date'>('movement_date');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 25;

  const [poNumberMap, setPoNumberMap] = useState<Map<string, string>>(new Map());

  const [showNewReceipt, setShowNewReceipt] = useState(false);
  const [selectedPOId, setSelectedPOId] = useState('');
  const [poLines, setPoLines] = useState<POLineForReceipt[]>([]);
  const [receiveQtyMap, setReceiveQtyMap] = useState<Record<string, number>>({});
  const [loadingPOLines, setLoadingPOLines] = useState(false);

  const { purchaseOrders: openPOs, refetch: refetchOpenPOs } = usePurchaseOrders({ status: 'OPEN' as PurchaseOrderStatus });
  const { purchaseOrders: partialPOs, refetch: refetchPartialPOs } = usePurchaseOrders({ status: 'PARTIAL' as PurchaseOrderStatus });
  const refetchPOs = useCallback(() => { refetchOpenPOs(); refetchPartialPOs(); }, [refetchOpenPOs, refetchPartialPOs]);
  const receivablePOs = useMemo(() => [...openPOs, ...partialPOs], [openPOs, partialPOs]);
  const { receivePurchaseOrder, isReceiving } = useReceivePurchaseOrder();

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    const poIds = movements
      .filter(m => m.reference_type === 'purchase_order' && m.reference_id)
      .map(m => m.reference_id!);
    const uniqueIds = [...new Set(poIds)];
    if (uniqueIds.length === 0) { setPoNumberMap(new Map()); return; }
    supabase
      .from('PurchaseOrders')
      .select('id, po_number')
      .in('id', uniqueIds)
      .then((res: { data: { id: string; po_number: string | null }[] | null }) => {
        const map = new Map<string, string>();
        (res.data ?? []).forEach((r) => map.set(r.id, r.po_number ?? '—'));
        setPoNumberMap(map);
      });
  }, [movements]);

  const [poLoadError, setPoLoadError] = useState<string | null>(null);

  const loadPOLines = useCallback(async (poId: string) => {
    setLoadingPOLines(true);
    setPoLoadError(null);
    try {
      const { data: poRow } = await supabase
        .from('PurchaseOrders')
        .select('id, status')
        .eq('id', poId)
        .maybeSingle();
      if (!poRow) {
        setPoLoadError('This purchase order no longer exists. The list will refresh.');
        setPoLines([]);
        refetchPOs();
        return;
      }
      if (poRow.status !== 'OPEN' && poRow.status !== 'PARTIAL') {
        setPoLoadError(`This purchase order is ${poRow.status}. Only OPEN or PARTIAL orders can receive goods.`);
        setPoLines([]);
        refetchPOs();
        return;
      }

      const { data, error } = await supabase
        .from('PurchaseOrderLines')
        .select('*, CatalogItems(sku, name)')
        .eq('purchase_order_id', poId)
        .order('created_at', { ascending: true });
      if (error) throw error;
      const rows = (data ?? []).map((l: any) => {
        const remaining = Math.max(0, (l.ordered_qty ?? 0) - (l.received_qty ?? 0));
        return {
          id: l.id,
          catalog_item_id: l.catalog_item_id,
          sku: l.sku_snapshot ?? l.CatalogItems?.sku ?? '',
          name: l.item_name_snapshot ?? l.CatalogItems?.name ?? '',
          description: l.description ?? '',
          is_one_off: l.is_one_off ?? false,
          ordered_qty: l.ordered_qty ?? 0,
          received_qty: l.received_qty ?? 0,
          remaining,
          unit: l.unit ?? 'ea',
          purchase_unit_snapshot: l.purchase_unit_snapshot ?? l.unit ?? null,
          units_per_purchase_unit_snapshot: Number(l.units_per_purchase_unit_snapshot ?? 1),
          is_roll_snapshot: Boolean(l.is_roll_snapshot),
          roll_length_value_snapshot: l.roll_length_value_snapshot != null ? Number(l.roll_length_value_snapshot) : null,
          roll_length_uom_snapshot: l.roll_length_uom_snapshot ?? null,
        } as POLineForReceipt;
      }).filter((l: POLineForReceipt) => l.remaining > 0);

      if (data && data.length > 0 && rows.length === 0) {
        setPoLoadError(null);
      }

      setPoLines(rows);
      const initial: Record<string, number> = {};
      rows.forEach((l: POLineForReceipt) => { initial[l.id] = l.remaining; });
      setReceiveQtyMap(initial);
    } catch {
      setPoLines([]);
      setPoLoadError('Failed to load PO lines.');
    } finally {
      setLoadingPOLines(false);
    }
  }, [refetchPOs]);

  const handlePOSelect = (poId: string) => {
    setSelectedPOId(poId);
    setPoLoadError(null);
    if (poId) loadPOLines(poId);
    else { setPoLines([]); setReceiveQtyMap({}); }
  };

  const handleConfirmReceipt = async (viewPdf = false) => {
    if (!selectedPOId) return;
    const toReceive = Object.entries(receiveQtyMap)
      .filter(([, qty]) => qty > 0)
      .map(([lineId, qty]) => ({ purchase_order_line_id: lineId, received_qty: qty }));
    if (toReceive.length === 0) {
      addNotification({ type: 'warning', title: 'No quantities', message: 'Enter received quantity for at least one line.' });
      return;
    }
    try {
      const { data: freshPO } = await supabase
        .from('PurchaseOrders')
        .select('id, status')
        .eq('id', selectedPOId)
        .maybeSingle();
      if (!freshPO || (freshPO.status !== 'OPEN' && freshPO.status !== 'PARTIAL')) {
        addNotification({ type: 'error', title: 'Cannot receive', message: `Purchase order is ${freshPO?.status ?? 'missing'}. It may have been received or closed since you opened this page.` });
        refetchPOs();
        setPoLines([]);
        return;
      }
      const selectedPO = receivablePOs.find((po) => po.id === selectedPOId);
      const result = await receivePurchaseOrder(selectedPOId, toReceive);
      addNotification({
        type: 'success',
        title: 'Receipt Created',
        message: `Receipt ${(result as any).movement_no ?? ''} created successfully.`,
      });

      if (viewPdf) {
        const { generateReceiptPDF } = await import('../../lib/pdf/generateReceiptPDF');
        const lineById = new Map(poLines.map((line) => [line.id, line]));
        const pdfLines = toReceive
          .map((entry) => {
            const line = lineById.get(entry.purchase_order_line_id);
            if (!line) return null;
            const suffix = line.is_roll_snapshot
              ? formatRollPurchaseInfo(line.roll_length_value_snapshot, line.roll_length_uom_snapshot)
              : formatPurchaseSuffix(line.purchase_unit_snapshot, line.units_per_purchase_unit_snapshot);
            return {
              sku: line.sku || '—',
              description: line.is_one_off
                ? line.description || 'One-off item'
                : `${line.name}${suffix ? ` ${suffix}` : ''}`,
              qty: entry.received_qty,
              unit: line.purchase_unit_snapshot ?? line.unit ?? 'ea',
            };
          })
          .filter((line): line is { sku: string; description: string; qty: number; unit: string } => Boolean(line));

        const doc = generateReceiptPDF(
          {
            receipt_no: (result as any).movement_no ?? 'DRAFT',
            movement_date: (result as any).movement_date ?? new Date().toISOString(),
            po_number: selectedPO?.po_number ?? selectedPOId.slice(0, 8),
            vendor_name: selectedPO?.DirectoryVendors?.name ?? null,
            warehouse_name: selectedPO?.Warehouses?.name ?? null,
          },
          pdfLines
        );
        const blob = doc.output('blob');
        const url = URL.createObjectURL(blob);
        window.open(url, '_blank');
      }

      setShowNewReceipt(false);
      setSelectedPOId('');
      setPoLines([]);
      setReceiveQtyMap({});
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to create receipt.' });
    }
  };


  const filtered = useMemo(() => {
    let result = [...movements];
    if (searchTerm) {
      const q = searchTerm.toLowerCase();
      result = result.filter(m =>
        (m.movement_no ?? '').toLowerCase().includes(q) ||
        (m.notes ?? '').toLowerCase().includes(q) ||
        (m.Warehouses?.name ?? '').toLowerCase().includes(q)
      );
    }
    if (statusFilter) result = result.filter(m => m.status === statusFilter);

    result.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'movement_no') cmp = (a.movement_no ?? '').localeCompare(b.movement_no ?? '');
      else if (sortBy === 'movement_date') cmp = (a.movement_date ?? '').localeCompare(b.movement_date ?? '');
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return result;
  }, [movements, searchTerm, statusFilter, sortBy, sortOrder]);

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('desc'); }
  };

  const SortIcon = ({ col }: { col: typeof sortBy }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  if (showNewReceipt) {
    const selectedPO = receivablePOs.find(p => p.id === selectedPOId);
    return (
      <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
        <div className="flex justify-center py-4 shrink-0">
          <div className="flex items-center gap-4 w-full max-w-6xl mx-auto px-4 md:px-6">
            <button
              type="button"
              onClick={() => { setShowNewReceipt(false); setSelectedPOId(''); setPoLines([]); }}
              className="p-1 -ml-1 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div className="flex-1 min-w-0">
              <h1 className="text-xl font-bold text-gray-900">New Receipt</h1>
              <p className="text-sm text-gray-500">Record goods received against a purchase order</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => { setShowNewReceipt(false); setSelectedPOId(''); setPoLines([]); }}
                className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => handleConfirmReceipt(false)}
                disabled={isReceiving || !selectedPOId || poLines.length === 0}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
              >
                <Package className="w-4 h-4" />
                {isReceiving ? 'Creating...' : 'Confirm Receipt'}
              </button>
              <button
                type="button"
                onClick={() => handleConfirmReceipt(true)}
                disabled={isReceiving || !selectedPOId || poLines.length === 0}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
              >
                <Package className="w-4 h-4" />
                {isReceiving ? 'Creating...' : 'Confirm & View PDF'}
              </button>
            </div>
          </div>
        </div>

        <div className="flex-1 min-w-0 overflow-auto pb-6">
          <div className="w-full max-w-6xl mx-auto px-4 md:px-6 space-y-6">
            {/* PO Selector card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Select Purchase Order</h3>
              <select
                value={selectedPOId}
                onChange={e => handlePOSelect(e.target.value)}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
              >
                <option value="">Choose a purchase order...</option>
                {receivablePOs.map(po => (
                  <option key={po.id} value={po.id}>
                    {po.po_number ?? po.id.slice(0, 8)} — {po.DirectoryVendors?.name ?? 'No vendor'} ({po.status})
                  </option>
                ))}
              </select>
              {selectedPO && (
                <dl className="mt-3 grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <dt className="text-gray-500">Vendor</dt>
                    <dd className="font-medium text-gray-900">{selectedPO.DirectoryVendors?.name ?? '—'}</dd>
                  </div>
                  <div>
                    <dt className="text-gray-500">Warehouse</dt>
                    <dd className="font-medium text-gray-900">{selectedPO.Warehouses?.name ?? '—'}</dd>
                  </div>
                  <div>
                    <dt className="text-gray-500">Status</dt>
                    <dd>
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        selectedPO.status === 'OPEN' ? 'bg-blue-50 text-blue-700' : 'bg-yellow-50 text-yellow-700'
                      }`}>
                        {selectedPO.status}
                      </span>
                    </dd>
                  </div>
                </dl>
              )}
            </div>

            {/* Lines to receive */}
            {selectedPOId && (
              <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
                <div className="px-4 py-3 bg-gray-50 border-b">
                  <h3 className="text-sm font-semibold text-gray-900">Lines to Receive ({poLines.length})</h3>
                </div>
                {loadingPOLines ? (
                  <div className="px-4 py-8 text-center text-gray-500">Loading PO lines...</div>
                ) : poLoadError ? (
                  <div className="px-4 py-8 text-center">
                    <p className="text-sm text-red-600">{poLoadError}</p>
                  </div>
                ) : poLines.length === 0 ? (
                  <div className="px-4 py-8 text-center text-gray-500">All lines are fully received.</div>
                ) : (
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 border-b">
                      <tr>
                        <th className="px-4 py-3 text-left font-medium text-gray-700">Item</th>
                        <th className="px-4 py-3 text-right font-medium text-gray-700">Ordered</th>
                        <th className="px-4 py-3 text-right font-medium text-gray-700">Already Rcvd</th>
                        <th className="px-4 py-3 text-right font-medium text-gray-700">Remaining</th>
                        <th className="px-4 py-3 text-right font-medium text-gray-700">Receive Qty</th>
                        <th className="px-4 py-3 text-right font-medium text-gray-700">Stock Qty</th>
                      </tr>
                    </thead>
                    <tbody>
                      {poLines.map(l => {
                        const uppu = Number(l.units_per_purchase_unit_snapshot ?? 1);
                        const puNorm = (l.purchase_unit_snapshot ?? l.unit ?? '').toLowerCase();
                        const isPackaged = uppu > 1 && !l.is_roll_snapshot
                          && !['each','ea','unit','units','pc','pcs'].includes(puNorm);
                        const rcvQty = receiveQtyMap[l.id] ?? l.remaining;
                        const stockQty = isPackaged ? rcvQty * uppu : null;
                        return (
                        <tr key={l.id} className="border-t hover:bg-gray-50">
                          <td className="px-4 py-3">
                            {l.is_one_off ? (
                              <span className="text-amber-600 italic">{l.description || 'One-off item'}</span>
                            ) : (
                              <>
                                <span className="font-medium text-gray-900">{l.sku}</span>
                                {l.name && (
                                  <span className="text-gray-500 ml-2 text-xs">
                                    {l.name}
                                    {l.is_roll_snapshot
                                      ? ` ${formatRollPurchaseInfo(l.roll_length_value_snapshot, l.roll_length_uom_snapshot)}`
                                      : formatPurchaseSuffix(l.purchase_unit_snapshot, l.units_per_purchase_unit_snapshot)
                                        ? ` ${formatPurchaseSuffix(l.purchase_unit_snapshot, l.units_per_purchase_unit_snapshot)}`
                                        : ''}
                                  </span>
                                )}
                              </>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right tabular-nums">{Number(l.ordered_qty).toFixed(2)}</td>
                          <td className="px-4 py-3 text-right tabular-nums">{Number(l.received_qty).toFixed(2)}</td>
                          <td className="px-4 py-3 text-right tabular-nums font-medium">{l.remaining.toFixed(2)}</td>
                          <td className="px-4 py-3">
                            <input
                              type="number"
                              min={0}
                              max={l.remaining}
                              step="0.01"
                              value={rcvQty}
                              onChange={e => {
                                const v = Math.min(l.remaining, Math.max(0, parseFloat(e.target.value) || 0));
                                setReceiveQtyMap(prev => ({ ...prev, [l.id]: v }));
                              }}
                              className="w-24 px-2 py-1 border border-gray-200 rounded text-sm text-right focus:outline-none focus:ring-2 focus:ring-primary/20"
                            />
                          </td>
                          <td className="px-4 py-3 text-right tabular-nums">
                            {stockQty != null ? (
                              <span className="text-green-700 font-medium">
                                {stockQty.toFixed(0)} ea
                              </span>
                            ) : (
                              <span className="text-gray-400">—</span>
                            )}
                          </td>
                        </tr>
                        );
                      })}
                    </tbody>
                  </table>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Receipts</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Receipts against purchase orders
          </p>
        </div>
        <button
          type="button"
          onClick={() => { refetchPOs(); setShowNewReceipt(true); }}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700"
        >
          <Plus className="w-4 h-4" />
          New Receipt
        </button>
      </div>

      <div className="mb-4 flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by movement #, notes, warehouse..."
            value={searchTerm}
            onChange={e => { setSearchTerm(e.target.value); setCurrentPage(1); }}
            className="pl-10"
          />
        </div>
        <select
          value={statusFilter}
          onChange={e => { setStatusFilter(e.target.value as 'draft' | 'confirmed' | ''); setCurrentPage(1); }}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value="">All Status</option>
          <option value="draft">Draft</option>
          <option value="confirmed">Confirmed</option>
        </select>
      </div>

      {loading ? (
        <div className="animate-pulse space-y-3">
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('movement_no')}>
                  Movement # <SortIcon col="movement_no" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Reference (PO)</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('movement_date')}>
                  Date <SortIcon col="movement_date" />
                </th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No receipts found</td></tr>
              ) : paginated.map(m => (
                <tr
                  key={m.id}
                  className="border-t hover:bg-gray-50 cursor-pointer"
                  onClick={() => {
                    sessionStorage.setItem('currentTransactionId', m.id);
                    router.navigate(`/inventory/transactions/${m.id}`);
                  }}
                >
                  <td className="px-4 py-3 font-medium text-gray-900">{m.movement_no ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-700">{m.Warehouses?.name ?? '—'}</td>
                  <td className="px-4 py-3 text-xs">
                    {m.reference_type === 'purchase_order' && m.reference_id ? (
                      <button
                        type="button"
                        onClick={(e) => { e.stopPropagation(); router.navigate(`/inventory/purchase-orders/${m.reference_id}`); }}
                        className="text-primary hover:underline font-medium"
                      >
                        {poNumberMap.get(m.reference_id) ?? m.reference_id.slice(0, 8)}
                      </button>
                    ) : '—'}
                  </td>
                  <td className="px-4 py-3 text-gray-700">{formatDate(m.movement_date)}</td>
                  <td className="px-4 py-3 text-center">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${m.status === 'confirmed' ? 'bg-green-50 text-green-700' : 'bg-yellow-50 text-yellow-700'}`}>
                      {m.status === 'confirmed' ? 'Confirmed' : 'Draft'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm text-gray-600">
          <span>Page {currentPage} of {totalPages} ({filtered.length} results)</span>
          <div className="flex gap-2">
            <button disabled={currentPage <= 1} onClick={() => setCurrentPage(p => p - 1)} className="px-3 py-1 border rounded disabled:opacity-50">Prev</button>
            <button disabled={currentPage >= totalPages} onClick={() => setCurrentPage(p => p + 1)} className="px-3 py-1 border rounded disabled:opacity-50">Next</button>
          </div>
        </div>
      )}

    </div>
  );
}
