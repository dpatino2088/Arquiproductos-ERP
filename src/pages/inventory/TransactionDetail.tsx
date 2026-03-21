import { useEffect, useState, useCallback, useMemo } from 'react';
import { router } from '../../lib/router';
import { formatDate, formatDateTime } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import {
  useInventoryMovementDetail,
  useConfirmMovement,
  useCreateMovement,
  MovementType,
  AdjustmentReason,
  ADJUSTMENT_REASON_LABELS,
} from '../../hooks/useInventoryMovements';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useWarehouses } from '../../hooks/useWarehouses';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase/client';
import { ArrowLeft, CheckCircle, Plus, Trash2, Save, Search, FileDown, Eye, ChevronDown, AlertTriangle, MessageSquare } from 'lucide-react';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

const TYPE_LABELS: Record<string, string> = {
  receipt: 'Receipt',
  issue_to_production: 'Issue to Production',
  transfer: 'Transfer',
  adjustment: 'Adjustment',
  return: 'Return',
};

const CREATABLE_TYPES: { value: MovementType; label: string }[] = [
  { value: 'receipt', label: 'Receipt' },
  { value: 'adjustment', label: 'Adjustment' },
  { value: 'transfer', label: 'Transfer' },
  { value: 'return', label: 'Return' },
];

interface DraftLine {
  tempId: string;
  catalog_item_id: string;
  sku: string;
  name: string;
  quantity: number;
  unit: string;
  currentStock: number | null;
  lineNotes: string;
}

interface CatalogSearchResult {
  id: string;
  sku: string;
  name: string;
  measure_basis: string | null;
  stockOnHand: number | null;
}

function normalizeSearchText(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function defaultUnitForBasis(basis: string | null): string {
  if (basis === 'linear') return 'm';
  if (basis === 'area') return 'm2';
  return 'ea';
}

interface TransactionDetailProps {
  transactionId?: string;
}

export default function TransactionDetail({ transactionId }: TransactionDetailProps) {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { warehouses, defaultWarehouse } = useWarehouses(activeOrganizationId);
  const { user } = useAuth();
  const addNotification = useUIStore((s) => s.addNotification);

  const isCreateMode = !transactionId;
  const { movement, lines, loading, refetch } = useInventoryMovementDetail(isCreateMode ? null : transactionId!);
  const { confirmMovement, isConfirming } = useConfirmMovement();
  const { createMovement, isCreating } = useCreateMovement();

  const [warehouseId, setWarehouseId] = useState('');
  const [movementType, setMovementType] = useState<MovementType>('adjustment');
  const [movementDate, setMovementDate] = useState(new Date().toISOString().slice(0, 10));
  const [notes, setNotes] = useState('');
  const [adjustmentReason, setAdjustmentReason] = useState<AdjustmentReason | ''>('');
  const [draftLines, setDraftLines] = useState<DraftLine[]>([]);
  const [isSaving, setIsSaving] = useState(false);

  const [itemSearch, setItemSearch] = useState('');
  const [searchResults, setSearchResults] = useState<CatalogSearchResult[]>([]);
  const [showSearch, setShowSearch] = useState(false);
  const [pdfMenuOpen, setPdfMenuOpen] = useState(false);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);

  const isAdjustmentContext = window.location.pathname.startsWith('/inventory/adjustments');
  const listPath = isAdjustmentContext ? '/inventory/adjustments' : '/inventory/transactions';
  const detailBasePath = isAdjustmentContext ? '/inventory/adjustments' : '/inventory/transactions';
  const effectiveType = isCreateMode ? (isAdjustmentContext ? 'adjustment' : movementType) : (movement?.movement_type ?? movementType);
  const isAdjustmentType = effectiveType === 'adjustment';

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    if (defaultWarehouse && !warehouseId) setWarehouseId(defaultWarehouse.id);
  }, [defaultWarehouse, warehouseId]);

  useEffect(() => {
    if (isCreateMode && isAdjustmentContext && movementType !== 'adjustment') {
      setMovementType('adjustment');
    }
  }, [isCreateMode, isAdjustmentContext, movementType]);

  useEffect(() => {
    if (movement && movement.status === 'draft') {
      setWarehouseId(movement.warehouse_id);
      setMovementType(movement.movement_type);
      setMovementDate(movement.movement_date ?? new Date().toISOString().slice(0, 10));
      setNotes(movement.notes ?? '');
      setAdjustmentReason((movement.adjustment_reason as AdjustmentReason) ?? '');
      setDraftLines(lines.map(l => ({
        tempId: l.id,
        catalog_item_id: l.catalog_item_id,
        sku: l.CatalogItems?.sku ?? '',
        name: l.CatalogItems?.name ?? '',
        quantity: l.quantity,
        unit: l.unit ?? 'ea',
        currentStock: null,
        lineNotes: l.notes ?? '',
      })));
    }
  }, [movement, lines]);

  // Fetch current stock for all draft lines whenever warehouseId or draftLines change
  useEffect(() => {
    if (!activeOrganizationId || !warehouseId || draftLines.length === 0) return;
    const itemIds = draftLines.map(l => l.catalog_item_id);
    supabase
      .from('InventoryBalances')
      .select('catalog_item_id, quantity')
      .eq('organization_id', activeOrganizationId)
      .eq('warehouse_id', warehouseId)
      .in('catalog_item_id', itemIds)
      .then(({ data }: { data: { catalog_item_id: string; quantity: number }[] | null }) => {
        if (!data) return;
        const balanceMap = new Map<string, number>();
        for (const row of data) {
          balanceMap.set(row.catalog_item_id, Number(row.quantity));
        }
        setDraftLines(prev => prev.map(l => ({
          ...l,
          currentStock: balanceMap.get(l.catalog_item_id) ?? 0,
        })));
      });
  }, [activeOrganizationId, warehouseId, draftLines.length]);

  const searchCatalogItems = useCallback(async (query: string) => {
    if (!activeOrganizationId || query.length < 2) { setSearchResults([]); return; }
    const trimmed = query.trim();
    const tokens = trimmed.toLowerCase().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) { setSearchResults([]); return; }

    const firstToken = tokens[0];
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .select('id, sku, name, measure_basis')
        .eq('organization_id', activeOrganizationId)
        .eq('is_active', true)
        .or(`sku.ilike.%${firstToken}%,name.ilike.%${firstToken}%`)
        .limit(50);

      if (error) throw error;

      const rawRows = (data ?? []) as Omit<CatalogSearchResult, 'stockOnHand'>[];
      const normalizedNeedle = normalizeSearchText(trimmed);
      const filtered = rawRows.filter((item) => {
        const sku = (item.sku ?? '').toLowerCase();
        const name = (item.name ?? '').toLowerCase();
        const hay = `${sku} ${name}`;
        const normalizedHay = normalizeSearchText(hay);
        const tokenMatch = tokens.every((t) => hay.includes(t) || normalizedHay.includes(normalizeSearchText(t)));
        const fuzzyMatch = normalizedNeedle.length >= 2 && normalizedHay.includes(normalizedNeedle);
        return tokenMatch || fuzzyMatch;
      });

      filtered.sort((a, b) => {
        const aSku = (a.sku ?? '').toLowerCase();
        const bSku = (b.sku ?? '').toLowerCase();
        const aName = (a.name ?? '').toLowerCase();
        const bName = (b.name ?? '').toLowerCase();
        const startsA = aSku.startsWith(firstToken) || aName.startsWith(firstToken);
        const startsB = bSku.startsWith(firstToken) || bName.startsWith(firstToken);
        if (startsA !== startsB) return startsA ? -1 : 1;
        return aSku.localeCompare(bSku);
      });

      const top = filtered.slice(0, 10);

      // Enrich with on-hand stock from InventoryBalances
      let stockMap = new Map<string, number>();
      if (warehouseId && top.length > 0) {
        const { data: balances } = await supabase
          .from('InventoryBalances')
          .select('catalog_item_id, quantity')
          .eq('organization_id', activeOrganizationId)
          .eq('warehouse_id', warehouseId)
          .in('catalog_item_id', top.map(i => i.id));
        if (balances) {
          for (const b of balances as { catalog_item_id: string; quantity: number }[]) {
            stockMap.set(b.catalog_item_id, Number(b.quantity));
          }
        }
      }

      setSearchResults(top.map(item => ({
        ...item,
        stockOnHand: stockMap.get(item.id) ?? 0,
      })));
    } catch {
      setSearchResults([]);
      addNotification({
        type: 'error',
        title: 'Search error',
        message: 'Could not search catalog items. Please try again.',
      });
    }
  }, [activeOrganizationId, warehouseId, addNotification]);

  useEffect(() => {
    const timer = setTimeout(() => { if (itemSearch.length >= 2) searchCatalogItems(itemSearch); else setSearchResults([]); }, 300);
    return () => clearTimeout(timer);
  }, [itemSearch, searchCatalogItems]);

  const addItem = useCallback(async (item: CatalogSearchResult) => {
    if (draftLines.some(l => l.catalog_item_id === item.id)) {
      addNotification({ type: 'warning', title: 'Duplicate', message: 'Item already added.' });
      return;
    }

    let currentStock: number | null = null;
    if (activeOrganizationId && warehouseId) {
      const { data } = await supabase
        .from('InventoryBalances')
        .select('quantity')
        .eq('organization_id', activeOrganizationId)
        .eq('warehouse_id', warehouseId)
        .eq('catalog_item_id', item.id)
        .maybeSingle();
      currentStock = data ? Number((data as { quantity: number }).quantity) : 0;
    }

    setDraftLines(prev => [...prev, {
      tempId: crypto.randomUUID(),
      catalog_item_id: item.id,
      sku: item.sku,
      name: item.name,
      quantity: 0,
      unit: defaultUnitForBasis(item.measure_basis),
      currentStock,
      lineNotes: '',
    }]);
    setItemSearch('');
    setSearchResults([]);
    setShowSearch(false);
  }, [draftLines, activeOrganizationId, warehouseId, addNotification]);

  const updateLineQty = (tempId: string, qty: number) => {
    setDraftLines(prev => prev.map(l => l.tempId === tempId ? { ...l, quantity: qty } : l));
  };

  const updateLineUnit = (tempId: string, unit: string) => {
    setDraftLines(prev => prev.map(l => l.tempId === tempId ? { ...l, unit } : l));
  };

  const updateLineNotes = (tempId: string, lineNotes: string) => {
    setDraftLines(prev => prev.map(l => l.tempId === tempId ? { ...l, lineNotes } : l));
  };

  const removeLine = (tempId: string) => {
    setDraftLines(prev => prev.filter(l => l.tempId !== tempId));
  };

  const hasNegativeResult = useMemo(() => {
    if (!isAdjustmentType) return false;
    return draftLines.some(l => {
      const current = l.currentStock ?? 0;
      const newQty = current + l.quantity;
      return newQty < 0;
    });
  }, [draftLines, isAdjustmentType]);

  const handleSaveDraft = async () => {
    if (!warehouseId) { addNotification({ type: 'error', title: 'Error', message: 'Select a warehouse.' }); return; }
    if (draftLines.length === 0) { addNotification({ type: 'error', title: 'Error', message: 'Add at least one item.' }); return; }
    if (isAdjustmentType && !adjustmentReason) { addNotification({ type: 'error', title: 'Error', message: 'Select an adjustment reason.' }); return; }

    const zeroLines = draftLines.filter(l => l.quantity === 0);
    if (zeroLines.length > 0) {
      addNotification({ type: 'warning', title: 'Warning', message: `${zeroLines.length} line(s) have zero quantity and will have no effect.` });
    }

    setIsSaving(true);
    try {
      const movId = isCreateMode
        ? (await createMovement({
            warehouse_id: warehouseId,
            movement_type: isAdjustmentContext ? 'adjustment' : movementType,
            movement_date: movementDate,
            notes: notes || undefined,
            adjustment_reason: isAdjustmentType && adjustmentReason ? adjustmentReason as AdjustmentReason : undefined,
            created_by: user?.id,
          })).id
        : transactionId!;

      if (!isCreateMode) {
        await supabase.from('InventoryMovementLines').delete().eq('inventory_movement_id', movId);
        await supabase.from('InventoryMovements').update({
          warehouse_id: warehouseId,
          movement_date: movementDate,
          notes: notes || null,
          adjustment_reason: isAdjustmentType && adjustmentReason ? adjustmentReason : null,
          updated_at: new Date().toISOString(),
        }).eq('id', movId);
      }

      for (const line of draftLines) {
        const mt = isCreateMode
          ? (isAdjustmentContext ? 'adjustment' : movementType)
          : (movement?.movement_type ?? movementType);
        const signedQty = mt === 'adjustment'
          ? line.quantity
          : ['return', 'receipt'].includes(mt) ? Math.abs(line.quantity) : -Math.abs(line.quantity);
        await supabase.from('InventoryMovementLines').insert({
          inventory_movement_id: movId,
          catalog_item_id: line.catalog_item_id,
          quantity: signedQty,
          unit: line.unit,
          notes: line.lineNotes || null,
        });
      }

      addNotification({ type: 'success', title: 'Saved', message: isCreateMode ? 'Transaction saved as draft.' : 'Draft updated.' });
      if (isCreateMode) {
        sessionStorage.setItem('currentTransactionId', movId);
        router.navigate(`${detailBasePath}/${movId}`);
      } else {
        refetch();
      }
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to save.' });
    } finally {
      setIsSaving(false);
    }
  };

  const handleConfirm = async () => {
    if (!transactionId) return;
    setShowConfirmDialog(false);
    try {
      await confirmMovement(transactionId);
      addNotification({ type: 'success', title: 'Confirmed', message: 'Movement confirmed and inventory updated.' });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to confirm.' });
    }
  };

  const buildReceiptPDFDoc = useCallback(async () => {
    if (!movement || movement.movement_type !== 'receipt') return null;
    const { generateReceiptPDF } = await import('../../lib/pdf/generateReceiptPDF');

    let poNumber = movement.reference_id ? movement.reference_id.slice(0, 8) : '—';
    let vendorName: string | null = null;
    if (movement.reference_type === 'purchase_order' && movement.reference_id) {
      const { data: poData } = await supabase
        .from('PurchaseOrders')
        .select('po_number, DirectoryVendors(name)')
        .eq('id', movement.reference_id)
        .maybeSingle();
      poNumber = (poData as { po_number?: string | null } | null)?.po_number ?? poNumber;
      vendorName = (poData as { DirectoryVendors?: { name?: string | null } | null } | null)?.DirectoryVendors?.name ?? null;
    }

    const pdfLines = lines.map((line) => ({
      sku: line.CatalogItems?.sku ?? '—',
      description: line.CatalogItems?.name ?? '—',
      qty: Math.abs(Number(line.quantity ?? 0)),
      unit: line.unit ?? 'ea',
    }));

    return generateReceiptPDF(
      {
        receipt_no: movement.movement_no ?? 'DRAFT',
        movement_date: movement.movement_date ?? new Date().toISOString(),
        po_number: poNumber,
        vendor_name: vendorName,
        warehouse_name: movement.Warehouses?.name ?? null,
      },
      pdfLines
    );
  }, [movement, lines]);

  const handlePreviewPDF = async () => {
    const doc = await buildReceiptPDFDoc();
    if (!doc) return;
    const blob = doc.output('blob');
    const url = URL.createObjectURL(blob);
    window.open(url, '_blank');
  };

  const handleDownloadPDF = async () => {
    const doc = await buildReceiptPDFDoc();
    if (!doc || !movement) return;
    doc.save(`${movement.movement_no ?? 'Receipt'}.pdf`);
  };

  if (!isCreateMode && loading) {
    return (
      <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 py-6">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-gray-300 rounded w-1/3" />
            <div className="grid grid-cols-2 gap-6">
              <div className="h-40 bg-gray-200 rounded" />
              <div className="h-40 bg-gray-200 rounded" />
            </div>
            <div className="h-60 bg-gray-200 rounded" />
          </div>
        </div>
      </div>
    );
  }

  if (!isCreateMode && !movement) {
    return (
      <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 py-6">
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-sm text-red-700">Transaction not found.</p>
          </div>
        </div>
      </div>
    );
  }

  const isConfirmed = movement?.status === 'confirmed';
  const isDraft = isCreateMode || movement?.status === 'draft';
  const displayLines = isDraft ? draftLines.map(l => ({
    id: l.tempId,
    sku: l.sku,
    name: l.name,
    quantity: l.quantity,
    unit: l.unit,
    currentStock: l.currentStock,
    lineNotes: l.lineNotes,
  })) : lines.map(l => ({
    id: l.id,
    sku: l.CatalogItems?.sku ?? '—',
    name: l.CatalogItems?.name ?? '—',
    quantity: l.quantity,
    unit: l.unit ?? 'ea',
    currentStock: null as number | null,
    lineNotes: l.notes ?? '',
  }));

  const referenceLabel = movement?.reference_type === 'manufacturing_order'
    ? `MO (${movement.reference_id?.slice(0, 8)}...)`
    : movement?.reference_type === 'purchase_order'
      ? `PO`
      : movement?.reference_type ?? '—';

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
      {/* Header */}
      <div className="flex justify-center py-4 shrink-0">
        <div className="flex items-center gap-4 w-full max-w-6xl mx-auto px-4 md:px-6">
          <button
            type="button"
            onClick={() => router.navigate(listPath)}
            className="p-1 -ml-1 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-3">
              <h1 className="text-xl font-bold text-gray-900 truncate">
                {isCreateMode ? (isAdjustmentContext ? 'New Adjustment' : 'New Transaction') : movement?.movement_no ?? 'Transaction'}
              </h1>
              {!isCreateMode && (
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${isConfirmed ? 'bg-green-50 text-green-700' : 'bg-yellow-50 text-yellow-700'}`}>
                  {isConfirmed ? 'Confirmed' : 'Draft'}
                </span>
              )}
            </div>
            <p className="text-sm text-gray-500 truncate">
              {isCreateMode
                ? (isAdjustmentContext ? 'Create a new inventory adjustment' : 'Create a new inventory movement')
                : `${TYPE_LABELS[movement!.movement_type] ?? movement!.movement_type} · ${movement!.Warehouses?.name ?? 'Unknown warehouse'}`}
            </p>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            {!isCreateMode && isConfirmed && movement?.movement_type === 'receipt' && (
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setPdfMenuOpen((prev) => !prev)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  <FileDown className="w-4 h-4" />
                  PDF
                  <ChevronDown className="w-4 h-4" />
                </button>
                {pdfMenuOpen && (
                  <>
                    <div className="fixed inset-0 z-30" onClick={() => setPdfMenuOpen(false)} />
                    <div className="absolute right-0 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-40 min-w-[160px] py-1">
                      <button
                        type="button"
                        onClick={() => {
                          setPdfMenuOpen(false);
                          void handlePreviewPDF();
                        }}
                        className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 text-gray-700 inline-flex items-center gap-2"
                      >
                        <Eye className="w-4 h-4" />
                        View PDF
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setPdfMenuOpen(false);
                          void handleDownloadPDF();
                        }}
                        className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 text-gray-700 inline-flex items-center gap-2"
                      >
                        <FileDown className="w-4 h-4" />
                        Download PDF
                      </button>
                    </div>
                  </>
                )}
              </div>
            )}
            {isDraft && (
              <button
                type="button"
                onClick={handleSaveDraft}
                disabled={isSaving || isCreating}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
              >
                <Save className="w-4 h-4" />
                {isSaving ? 'Saving...' : isCreateMode ? 'Save as Draft' : 'Save Changes'}
              </button>
            )}
            {!isCreateMode && isDraft && (
              <button
                type="button"
                onClick={() => setShowConfirmDialog(true)}
                disabled={isConfirming}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors"
              >
                <CheckCircle className="w-4 h-4" />
                {isConfirming ? 'Confirming...' : 'Confirm Movement'}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 overflow-auto pb-6">
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 space-y-6">

          {/* Two-card header */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Movement Details card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Movement Details</h3>
              {isDraft && isCreateMode ? (
                <div className="space-y-3">
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Warehouse *</label>
                    <select
                      value={warehouseId}
                      onChange={e => setWarehouseId(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    >
                      <option value="">Select warehouse...</option>
                      {warehouses.map(w => <option key={w.id} value={w.id}>{w.name}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Type *</label>
                    <select
                      value={movementType}
                      onChange={e => setMovementType(e.target.value as MovementType)}
                      disabled={isAdjustmentContext}
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    >
                      {(isAdjustmentContext
                        ? CREATABLE_TYPES.filter((t) => t.value === 'adjustment')
                        : CREATABLE_TYPES
                      ).map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Date</label>
                    <input
                      type="date"
                      value={movementDate}
                      onChange={e => setMovementDate(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    />
                  </div>
                  {isAdjustmentType && (
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">Reason *</label>
                      <select
                        value={adjustmentReason}
                        onChange={e => setAdjustmentReason(e.target.value as AdjustmentReason | '')}
                        className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        <option value="">Select reason...</option>
                        {(Object.entries(ADJUSTMENT_REASON_LABELS) as [AdjustmentReason, string][]).map(([val, label]) => (
                          <option key={val} value={val}>{label}</option>
                        ))}
                      </select>
                    </div>
                  )}
                </div>
              ) : (
                <dl className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Type</dt>
                    <dd className="font-medium text-gray-900">{TYPE_LABELS[movement!.movement_type] ?? movement!.movement_type}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Warehouse</dt>
                    <dd className="font-medium text-gray-900">{movement!.Warehouses?.name ?? '—'}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Date</dt>
                    <dd className="font-medium text-gray-900">{formatDate(movement!.movement_date)}</dd>
                  </div>
                  {movement!.movement_type === 'adjustment' && movement!.adjustment_reason && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Reason</dt>
                      <dd className="font-medium text-gray-900">
                        {ADJUSTMENT_REASON_LABELS[movement!.adjustment_reason as AdjustmentReason] ?? movement!.adjustment_reason}
                      </dd>
                    </div>
                  )}
                  {isDraft && isAdjustmentType && (
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1 mt-2">Reason *</label>
                      <select
                        value={adjustmentReason}
                        onChange={e => setAdjustmentReason(e.target.value as AdjustmentReason | '')}
                        className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        <option value="">Select reason...</option>
                        {(Object.entries(ADJUSTMENT_REASON_LABELS) as [AdjustmentReason, string][]).map(([val, label]) => (
                          <option key={val} value={val}>{label}</option>
                        ))}
                      </select>
                    </div>
                  )}
                  {movement!.confirmed_at && (
                    <div className="flex justify-between border-t pt-2">
                      <dt className="text-gray-500">Confirmed at</dt>
                      <dd className="font-medium text-gray-900">{formatDateTime(movement!.confirmed_at)}</dd>
                    </div>
                  )}
                </dl>
              )}
            </div>

            {/* Reference & Notes card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Reference & Notes</h3>
              {isDraft ? (
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Notes</label>
                  <textarea
                    value={notes}
                    onChange={e => setNotes(e.target.value)}
                    rows={isAdjustmentType ? 5 : 4}
                    placeholder={isAdjustmentType ? 'Describe the reason for this adjustment...' : 'Optional notes...'}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 resize-none"
                  />
                </div>
              ) : (
                <dl className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Reference</dt>
                    <dd className="font-medium text-gray-900">
                      {movement!.reference_type === 'manufacturing_order' && movement!.reference_id ? (
                        <button
                          type="button"
                          onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${movement!.reference_id}`)}
                          className="text-primary hover:underline"
                        >
                          {referenceLabel}
                        </button>
                      ) : movement!.reference_type === 'purchase_order' && movement!.reference_id ? (
                        <button
                          type="button"
                          onClick={() => router.navigate(`/inventory/purchase-orders/${movement!.reference_id}`)}
                          className="text-primary hover:underline"
                        >
                          Purchase Order
                        </button>
                      ) : (
                        referenceLabel
                      )}
                    </dd>
                  </div>
                  {movement!.notes && (
                    <div className="border-t pt-2">
                      <dt className="text-gray-500 text-xs mb-0.5">Notes</dt>
                      <dd className="text-gray-700 text-xs whitespace-pre-wrap">{movement!.notes}</dd>
                    </div>
                  )}
                </dl>
              )}
            </div>
          </div>

          {/* Warning for negative stock */}
          {isDraft && hasNegativeResult && (
            <div className="flex items-start gap-3 rounded-lg border border-amber-200 bg-amber-50 p-4">
              <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
              <div>
                <p className="text-sm font-medium text-amber-800">Negative stock warning</p>
                <p className="text-xs text-amber-700 mt-0.5">
                  One or more items will have a negative balance after this adjustment. Review the "New Qty" column below.
                </p>
              </div>
            </div>
          )}

          {/* Items table */}
          {isDraft && isAdjustmentType && (
            <p className="text-xs text-gray-500 -mb-4">Positive qty = add stock &middot; Negative qty = remove stock (write-off)</p>
          )}
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
            <div className="px-4 py-3 bg-gray-50 border-b flex items-center justify-between">
              <h3 className="text-sm font-semibold text-gray-900">Items ({displayLines.length})</h3>
              {isDraft && (
                <button
                  type="button"
                  onClick={() => setShowSearch(true)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  <Plus className="w-3.5 h-3.5" /> Add Item
                </button>
              )}
            </div>

            {showSearch && (
              <div className="px-4 py-3 border-b bg-gray-50">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search by SKU or item name..."
                    value={itemSearch}
                    onChange={e => setItemSearch(e.target.value)}
                    className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    autoFocus
                  />
                </div>
                {searchResults.length > 0 && (
                  <div className="mt-2 border border-gray-200 rounded-lg bg-white max-h-48 overflow-y-auto">
                    {searchResults.map(item => (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => void addItem(item)}
                        className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b last:border-b-0 flex items-center justify-between gap-2"
                      >
                        <div className="min-w-0">
                          <span className="font-medium text-gray-900">{item.sku}</span>
                          <span className="text-gray-500 ml-2">{item.name}</span>
                        </div>
                        <span className={`shrink-0 text-xs tabular-nums px-2 py-0.5 rounded-full ${
                          (item.stockOnHand ?? 0) > 0
                            ? 'bg-green-50 text-green-700'
                            : 'bg-gray-100 text-gray-500'
                        }`}>
                          {(item.stockOnHand ?? 0).toFixed(2)} {defaultUnitForBasis(item.measure_basis)}
                        </span>
                      </button>
                    ))}
                  </div>
                )}
                <button
                  type="button"
                  onClick={() => { setShowSearch(false); setItemSearch(''); setSearchResults([]); }}
                  className="mt-2 text-xs text-gray-500 hover:text-gray-700"
                >
                  Cancel
                </button>
              </div>
            )}

            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b">
                  <tr>
                    <th className="px-4 py-3 text-left font-medium text-gray-700">SKU</th>
                    <th className="px-4 py-3 text-left font-medium text-gray-700">Item</th>
                    {isAdjustmentType && <th className="px-4 py-3 text-right font-medium text-gray-700">On Hand</th>}
                    <th className="px-4 py-3 text-right font-medium text-gray-700">{isAdjustmentType ? 'Adj Qty' : 'Qty'}</th>
                    {isAdjustmentType && isDraft && <th className="px-4 py-3 text-right font-medium text-gray-700">New Qty</th>}
                    <th className="px-4 py-3 text-left font-medium text-gray-700">Unit</th>
                    {isDraft && <th className="px-4 py-3 text-center font-medium text-gray-700 w-20">Notes</th>}
                    {isDraft && <th className="px-4 py-3 w-12"></th>}
                  </tr>
                </thead>
                <tbody>
                  {displayLines.length === 0 ? (
                    <tr>
                      <td colSpan={isAdjustmentType ? (isDraft ? 8 : 5) : (isDraft ? 6 : 4)} className="px-4 py-8 text-center text-gray-500">
                        No items{isDraft ? '. Click "Add Item" to start.' : ''}
                      </td>
                    </tr>
                  ) : displayLines.map(line => {
                    const currentStock = line.currentStock ?? 0;
                    const newQty = currentStock + line.quantity;
                    const isNegativeResult = newQty < 0;
                    return (
                      <tr key={line.id} className="border-t hover:bg-gray-50">
                        <td className="px-4 py-3 font-medium text-gray-900">{line.sku}</td>
                        <td className="px-4 py-3 text-gray-700">{line.name}</td>
                        {isAdjustmentType && (
                          <td className="px-4 py-3 text-right tabular-nums text-gray-600">
                            {line.currentStock !== null ? Number(line.currentStock).toFixed(2) : '—'}
                          </td>
                        )}
                        <td className="px-4 py-3 text-right">
                          {isDraft ? (
                            <input
                              type="number"
                              value={line.quantity}
                              onChange={e => updateLineQty(line.id, Number(e.target.value))}
                              className="w-24 px-2 py-1 border border-gray-200 rounded text-sm text-right tabular-nums focus:outline-none focus:ring-2 focus:ring-primary/20"
                              step="any"
                            />
                          ) : (
                            <span className={`tabular-nums font-medium ${line.quantity < 0 ? 'text-red-600' : 'text-green-600'}`}>
                              {line.quantity > 0 ? '+' : ''}{Number(line.quantity).toFixed(2)}
                            </span>
                          )}
                        </td>
                        {isAdjustmentType && isDraft && (
                          <td className={`px-4 py-3 text-right tabular-nums font-medium ${isNegativeResult ? 'text-red-600' : 'text-gray-900'}`}>
                            {line.currentStock !== null ? newQty.toFixed(2) : '—'}
                            {isNegativeResult && <AlertTriangle className="w-3.5 h-3.5 inline ml-1 text-red-500" />}
                          </td>
                        )}
                        <td className="px-4 py-3">
                          {isDraft ? (
                            <select
                              value={line.unit}
                              onChange={e => updateLineUnit(line.id, e.target.value)}
                              className="w-16 px-1 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                            >
                              <option value="ea">ea</option>
                              <option value="m">m</option>
                              <option value="m2">m2</option>
                            </select>
                          ) : (
                            <span className="text-gray-600">{line.unit}</span>
                          )}
                        </td>
                        {isDraft && (
                          <td className="px-4 py-3 text-center">
                            {line.lineNotes ? (
                              <button
                                type="button"
                                title={line.lineNotes}
                                onClick={() => {
                                  const val = prompt('Line note:', line.lineNotes);
                                  if (val !== null) updateLineNotes(line.id, val);
                                }}
                                className="p-1 text-primary hover:text-primary/80 rounded"
                              >
                                <MessageSquare className="w-4 h-4" />
                              </button>
                            ) : (
                              <button
                                type="button"
                                title="Add note"
                                onClick={() => {
                                  const val = prompt('Line note:');
                                  if (val) updateLineNotes(line.id, val);
                                }}
                                className="p-1 text-gray-400 hover:text-gray-600 rounded"
                              >
                                <MessageSquare className="w-4 h-4" />
                              </button>
                            )}
                          </td>
                        )}
                        {isDraft && (
                          <td className="px-4 py-3">
                            <button type="button" onClick={() => removeLine(line.id)} className="p-1 text-gray-400 hover:text-red-600 rounded transition-colors">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </td>
                        )}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Line notes display for confirmed */}
            {isConfirmed && displayLines.some(l => l.lineNotes) && (
              <div className="px-4 py-3 border-t bg-gray-50">
                <h4 className="text-xs font-medium text-gray-500 mb-2">Line Notes</h4>
                <div className="space-y-1">
                  {displayLines.filter(l => l.lineNotes).map(l => (
                    <p key={l.id} className="text-xs text-gray-600">
                      <span className="font-medium">{l.sku}:</span> {l.lineNotes}
                    </p>
                  ))}
                </div>
              </div>
            )}
          </div>

        </div>
      </div>

      {/* Confirm Dialog */}
      {showConfirmDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Confirm Movement</h3>
            <p className="text-sm text-gray-600 mb-1">
              This will apply the {isAdjustmentType ? 'adjustment' : 'movement'} to inventory balances. This action cannot be undone.
            </p>
            {hasNegativeResult && (
              <div className="flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 p-3 my-3">
                <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                <p className="text-xs text-amber-700">
                  Warning: Some items will have negative stock after this adjustment.
                </p>
              </div>
            )}
            <div className="flex justify-end gap-2 mt-4">
              <button
                type="button"
                onClick={() => setShowConfirmDialog(false)}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirm}
                disabled={isConfirming}
                className="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
              >
                {isConfirming ? 'Confirming...' : 'Confirm & Apply'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
