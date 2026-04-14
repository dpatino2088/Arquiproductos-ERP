import { useEffect, useState, useCallback, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import {
  usePurchaseOrderDetail,
  useCreatePurchaseOrder,
  useUpdatePurchaseOrder,
  useDeletePurchaseOrder,
  useReceivePurchaseOrder,
  useUpdatePurchaseOrderStatus,
  fetchCatalogItemCostInfo,
  type PurchaseOrderLine,
  type PurchaseOrderStatus,
  type CreatePOLineInput,
  type UpdatePOLineInput,
} from '../../hooks/usePurchaseOrders';
import { useGranularAccess } from '../../hooks/usePermissions';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useWarehouses } from '../../hooks/useWarehouses';
import { useDirectoryVendors } from '../../hooks/useDirectoryVendors';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase/client';
import { useCostSettings } from '../../hooks/useCosts';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { convertInternalToPurchaseQty, convertPurchaseQtyToInternal, resolveInventoryUnitModel, type MeasureBasis } from '../../lib/inventoryUnitModel';
import { ArrowLeft, Plus, Trash2, Search, Package, FileDown, Eye, ChevronDown, CheckCircle2, XCircle, Archive } from 'lucide-react';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { normalizeUUID } from '../../utils/uuid';
import { formatDate } from '../../lib/utils';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

const STATUS_COLORS: Record<string, string> = {
  DRAFT: 'bg-gray-100 text-gray-600',
  OPEN: 'bg-blue-50 text-blue-700',
  PARTIAL: 'bg-yellow-50 text-yellow-700',
  CLOSED: 'bg-green-50 text-green-700',
  CANCELLED: 'bg-red-50 text-red-600',
  ARCHIVED: 'bg-slate-100 text-slate-500',
};

interface DraftLine {
  tempId: string;
  catalog_item_id: string | null;
  sku: string;
  name: string;
  ordered_qty: number;
  received_qty: number;
  unit_cost: number;
  unit: string;
  description: string;
  is_one_off: boolean;
  notes: string;
  allocation_type: 'stock' | 'manufacturing_order';
  allocation_mo_id: string | null;
  allocation_mo_label: string | null;
  purchase_unit_snapshot: string | null;
  purchase_mode_snapshot: 'unit_packaged' | 'linear_direct' | 'roll' | null;
  stock_basis_snapshot: 'ea' | 'linear_m' | null;
  purchase_uom_snapshot: string | null;
  units_per_purchase_unit_snapshot: number | null;
  moq_snapshot: number | null;
  unit_of_measure_snapshot: string | null;
  is_roll_snapshot: boolean;
  roll_width_value_snapshot: number | null;
  roll_width_uom_snapshot: string | null;
  roll_length_value_snapshot: number | null;
  roll_length_uom_snapshot: string | null;
}

interface CatalogSearchResult {
  id: string;
  sku: string;
  name: string;
  description: string | null;
  collection_name: string | null;
  variant_name: string | null;
  cost_exw: number | null;
  purchase_unit: string | null;
  units_per_purchase_unit: number | null;
  moq?: number | null;
  manufacturer_id: string | null;
  is_roll: boolean;
  measure_basis: 'unit' | 'linear' | 'area' | null;
  unit_of_measure: string | null;
  roll_width_value: number | null;
  roll_width_uom: string | null;
  roll_length_value: number | null;
  roll_length_uom: string | null;
}

interface MOSearchResult {
  id: string;
  manufacturing_order_no: string;
}

interface PurchaseOrderDetailProps {
  poId?: string;
}

function fmtCurrency(v: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);
}

function formatPurchaseUnitSuffix(line: DraftLine): string | null {
  if (line.is_one_off) return null;
  const pUnit = (line.purchase_unit_snapshot ?? '').trim().toLowerCase();
  const upp = Number(line.units_per_purchase_unit_snapshot ?? 1);
  const uom = (line.unit_of_measure_snapshot ?? line.purchase_uom_snapshot ?? '').trim().toLowerCase();

  if (line.is_roll_snapshot) {
    const info = formatRollPurchaseInfo(
      line.roll_length_value_snapshot,
      line.roll_length_uom_snapshot,
      line.roll_width_value_snapshot,
      line.roll_width_uom_snapshot,
      line.roll_length_uom_snapshot ?? line.unit_of_measure_snapshot
    );
    return info || null;
  }

  if (upp > 1 && pUnit === 'each' && uom) {
    const pretty = upp % 1 === 0 ? String(upp) : upp.toFixed(4).replace(/\.?0+$/, '');
    return `(${pretty} ${uom})`;
  }

  const packagedUnits = new Set(['pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton', 'kit', 'pair']);
  if (packagedUnits.has(pUnit) && upp > 1) {
    return `(${upp} und)`;
  }

  if (pUnit && pUnit !== 'each') return `(${pUnit})`;

  return null;
}

function formatRollDimensions(
  width: number | null | undefined,
  length: number | null | undefined,
  lengthUom: string | null | undefined,
  widthUom: string | null | undefined
): string {
  const w = Number(width ?? 0);
  const l = Number(length ?? 0);
  const luom = (lengthUom ?? '').trim();
  const wuom = (widthUom ?? '').trim();
  if (w > 0 && l > 0) {
    if (wuom && luom && wuom !== luom) return `(${w} ${wuom} x ${l} ${luom})`;
    const uom = luom || wuom || 'unit';
    return `(${w} x ${l} ${uom})`;
  }
  if (w > 0) return `(${w} ${wuom || luom || 'unit'})`;
  if (l > 0) return `(${l} ${luom || wuom || 'unit'})`;
  return '';
}

/** Internal quantity in meters when stock_basis is linear_m; null otherwise. */
function lineInternalQtyM(
  qty: number,
  line: {
    stock_basis_snapshot?: 'ea' | 'linear_m' | null;
    purchase_mode_snapshot?: 'unit_packaged' | 'linear_direct' | 'roll' | null;
    purchase_uom_snapshot?: string | null;
    unit?: string | null;
    units_per_purchase_unit_snapshot?: number | null;
    roll_length_value_snapshot?: number | null;
    roll_length_uom_snapshot?: string | null;
  }
): number | null {
  if (line.stock_basis_snapshot !== 'linear_m' || !(qty > 0)) return null;
  const mode = line.purchase_mode_snapshot ?? 'unit_packaged';
  const internal = convertPurchaseQtyToInternal({
    qtyInPurchaseUnit: qty,
    purchaseMode: mode,
    purchaseUnit: line.purchase_uom_snapshot ?? line.unit ?? 'each',
    unitsPerPurchaseUnit: line.units_per_purchase_unit_snapshot ?? undefined,
    rollLengthValue: line.roll_length_value_snapshot ?? undefined,
    rollLengthUom: line.roll_length_uom_snapshot ?? undefined,
  });
  return internal > 0 ? internal : null;
}

function formatRollPurchaseInfo(
  length: number | null | undefined,
  lengthUom: string | null | undefined,
  width: number | null | undefined,
  widthUom: string | null | undefined,
  purchaseUom: string | null | undefined
): string {
  let l = Number(length ?? 0);
  let luom = (lengthUom ?? '').trim().toLowerCase();
  const preferredUom = (purchaseUom ?? '').trim().toLowerCase();

  const convertFromMeters = (meters: number, toUom: string): number => {
    if (toUom === 'yd' || toUom === 'yard' || toUom === 'yards') return meters / 0.9144;
    if (toUom === 'ft' || toUom === 'foot' || toUom === 'feet') return meters / 0.3048;
    if (toUom === 'in' || toUom === 'inch' || toUom === 'inches') return meters / 0.0254;
    if (toUom === 'cm' || toUom === 'centimeter' || toUom === 'centimeters') return meters * 100;
    if (toUom === 'mm' || toUom === 'millimeter' || toUom === 'millimeters') return meters * 1000;
    return meters;
  };

  // Legacy safeguard: if snapshot length came as meters but purchase UOM is different,
  // convert for operator-facing display in PO.
  if (l > 0 && luom === 'm' && preferredUom && preferredUom !== 'm') {
    l = convertFromMeters(l, preferredUom);
    luom = preferredUom;
  }

  if (l > 0) {
    const pretty = Number.isFinite(l) ? l.toFixed(2).replace(/\.00$/, '') : String(length ?? '');
    return `(${pretty} ${luom || preferredUom || 'unit'})`;
  }
  return formatRollDimensions(width, length, lengthUom, widthUom);
}

function resolveLineUnit(item: {
  is_roll: boolean;
  measure_basis: string | null;
  purchase_unit: string | null;
  unit_of_measure: string | null;
}): string {
  const purchaseUnit = item.purchase_unit ?? 'each';
  if (item.is_roll) return 'roll';
  if (item.measure_basis === 'linear' && purchaseUnit === 'each') {
    return item.unit_of_measure ?? 'm';
  }
  return purchaseUnit;
}

function normalizeSearchText(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '');
}

export default function PurchaseOrderDetail({ poId: propPoId }: PurchaseOrderDetailProps) {
  const normalizedPropPoId = propPoId ? normalizeUUID(propPoId) : null;
  const [poId, setPoId] = useState<string | null>(normalizedPropPoId);
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { warehouses, defaultWarehouse } = useWarehouses(activeOrganizationId);
  const addNotification = useUIStore((s) => s.addNotification);

  const { purchaseOrder, lines, linkedMOs, loading, refetch } = usePurchaseOrderDetail(poId);
  const { createPurchaseOrder, isCreating } = useCreatePurchaseOrder();
  const { updatePurchaseOrder, isUpdating } = useUpdatePurchaseOrder();
  const { deletePurchaseOrder, isDeleting } = useDeletePurchaseOrder();
  const { receivePurchaseOrder, isReceiving } = useReceivePurchaseOrder();
  const { updateStatus, isUpdating: isStatusUpdating } = useUpdatePurchaseOrderStatus();

  const { canDelete: canDeleteInv } = useGranularAccess('inventory');

  const isCreateMode = !poId || window.location.pathname.endsWith('/new');
  const poStatus = purchaseOrder?.status as PurchaseOrderStatus | undefined;
  const isDraft = poStatus === 'DRAFT';
  const isOpen = poStatus === 'OPEN';
  const canEdit = isCreateMode || isDraft || isOpen;
  const canReceive = purchaseOrder && (poStatus === 'OPEN' || poStatus === 'PARTIAL');
  const canApprove = isDraft;
  const canCancel = poStatus === 'DRAFT' || poStatus === 'OPEN' || poStatus === 'PARTIAL';
  const canArchive = poStatus === 'CLOSED';
  const canDeleteBiz = (poStatus === 'DRAFT' || poStatus === 'OPEN') && lines.every(l => (l.received_qty ?? 0) === 0);
  const canDelete = canDeleteBiz && canDeleteInv;
  const isTerminal = poStatus === 'CANCELLED' || poStatus === 'ARCHIVED';

  const [warehouseId, setWarehouseId] = useState('');
  const [vendorId, setVendorId] = useState('');
  const [vendorSearch, setVendorSearch] = useState('');
  const [showVendorDropdown, setShowVendorDropdown] = useState(false);
  const [expectedDate, setExpectedDate] = useState('');
  const [currency, setCurrency] = useState('USD');
  const [poNotes, setPoNotes] = useState('');
  const { vendors } = useDirectoryVendors();
  const { settings: costSettings } = useCostSettings();

  const [draftLines, setDraftLines] = useState<DraftLine[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [itemSearch, setItemSearch] = useState('');
  const [searchResults, setSearchResults] = useState<CatalogSearchResult[]>([]);
  const [showSearch, setShowSearch] = useState(false);
  const [showReceiveModal, setShowReceiveModal] = useState(false);
  const [pdfMenuOpen, setPdfMenuOpen] = useState(false);
  const [receiveQtyMap, setReceiveQtyMap] = useState<Record<string, number>>({});
  const [loadingRef, setLoadingRef] = useState(false);
  const [lineMoSearch, setLineMoSearch] = useState('');
  const [lineMoOptions, setLineMoOptions] = useState<MOSearchResult[]>([]);
  const [lineMoDropdownId, setLineMoDropdownId] = useState<string | null>(null);
  const handleBack = useCallback(() => {
    navigateBackContextual(router, {
      queryReturnTo: getReturnToFromCurrentQuery(),
      fallback: '/inventory/purchase-orders',
    });
  }, []);

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  // Search MO for per-line allocation
  const searchLineMOs = useCallback(async (query: string) => {
    if (!activeOrganizationId || query.length < 2) { setLineMoOptions([]); return; }
    const { data: mos } = await supabase
      .from('ManufacturingOrders')
      .select('id, manufacturing_order_no')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .ilike('manufacturing_order_no', `%${query}%`)
      .limit(10);
    setLineMoOptions((mos ?? []) as MOSearchResult[]);
  }, [activeOrganizationId]);

  useEffect(() => {
    const timer = setTimeout(() => { if (lineMoSearch.length >= 2) searchLineMOs(lineMoSearch); else setLineMoOptions([]); }, 300);
    return () => clearTimeout(timer);
  }, [lineMoSearch, searchLineMOs]);

  useEffect(() => {
    if (!poId && !isCreateMode) {
      const path = window.location.pathname;
      const match = path.match(/\/inventory\/purchase-orders\/([^/]+)/);
      if (match && match[1] !== 'new') {
        const normalized = normalizeUUID(match[1]);
        if (normalized) setPoId(normalized);
      }
    }
  }, [poId, isCreateMode]);

  useEffect(() => {
    if (defaultWarehouse && !warehouseId && isCreateMode) setWarehouseId(defaultWarehouse.id);
  }, [defaultWarehouse, warehouseId, isCreateMode]);

  const mapLineToDraft = useCallback((l: PurchaseOrderLine, moLabelMap?: Map<string, string>): DraftLine => ({
    tempId: l.id,
    catalog_item_id: l.catalog_item_id,
    sku: l.sku_snapshot ?? l.CatalogItems?.sku ?? '',
    name: l.item_name_snapshot ?? l.CatalogItems?.name ?? '',
    ordered_qty: l.ordered_qty,
    received_qty: l.received_qty ?? 0,
    unit_cost: Number(l.unit_cost ?? 0),
    unit: l.unit ?? l.CatalogItems?.unit_of_measure ?? 'ea',
    description: l.description ?? l.CatalogItems?.description ?? '',
    is_one_off: l.is_one_off ?? false,
    notes: l.notes ?? '',
    allocation_type: l.allocation_type ?? 'stock',
    allocation_mo_id: l.allocation_mo_id ?? null,
    allocation_mo_label: l.allocation_mo_id
      ? (moLabelMap?.get(l.allocation_mo_id) ?? l.allocation_mo_id.slice(0, 8))
      : null,
    purchase_unit_snapshot: l.purchase_unit_snapshot ?? l.unit ?? (l.CatalogItems as { purchase_unit?: string } | null)?.purchase_unit ?? null,
    purchase_mode_snapshot: l.purchase_mode_snapshot ?? (l.CatalogItems?.is_roll ? 'roll' : ((l.CatalogItems as { measure_basis?: string } | null)?.measure_basis === 'linear' ? 'linear_direct' : 'unit_packaged')),
    stock_basis_snapshot: l.stock_basis_snapshot ?? ((l.CatalogItems as { measure_basis?: string } | null)?.measure_basis === 'linear' ? 'linear_m' : 'ea'),
    purchase_uom_snapshot: l.purchase_uom_snapshot ?? l.unit ?? (l.CatalogItems as { purchase_unit?: string } | null)?.purchase_unit ?? l.CatalogItems?.unit_of_measure ?? null,
    units_per_purchase_unit_snapshot: Number(l.units_per_purchase_unit_snapshot ?? 1),
    moq_snapshot: Number(l.moq_snapshot ?? (l.CatalogItems as { moq?: number } | null)?.moq ?? 0),
    unit_of_measure_snapshot: l.unit_of_measure_snapshot ?? l.roll_length_uom_snapshot ?? l.CatalogItems?.unit_of_measure ?? null,
    is_roll_snapshot: Boolean(l.is_roll_snapshot),
    roll_width_value_snapshot: l.roll_width_value_snapshot != null ? Number(l.roll_width_value_snapshot) : (l.CatalogItems as { roll_width_value?: number } | null)?.roll_width_value ?? null,
    roll_width_uom_snapshot: l.roll_width_uom_snapshot ?? (l.CatalogItems as { roll_width_uom?: string } | null)?.roll_width_uom ?? null,
    roll_length_value_snapshot: l.roll_length_value_snapshot != null ? Number(l.roll_length_value_snapshot) : (l.CatalogItems as { roll_length_value?: number } | null)?.roll_length_value ?? null,
    roll_length_uom_snapshot: l.roll_length_uom_snapshot ?? (l.CatalogItems as { roll_length_uom?: string } | null)?.roll_length_uom ?? null,
  }), []);

  useEffect(() => {
    if (!purchaseOrder || isCreateMode || lines.length === 0) return;

    setWarehouseId(purchaseOrder.warehouse_id);
    setVendorId(purchaseOrder.vendor_id ?? '');
    setExpectedDate(purchaseOrder.expected_date ?? '');
    setCurrency(purchaseOrder.currency ?? 'USD');
    setPoNotes(purchaseOrder.notes ?? '');

    const moIds = [...new Set(lines.filter(l => l.allocation_mo_id).map(l => l.allocation_mo_id!))];

    if (moIds.length > 0) {
      let cancelled = false;
      (async () => {
        try {
          const { data } = await supabase
            .from('ManufacturingOrders')
            .select('id, manufacturing_order_no')
            .in('id', moIds);
          if (cancelled) return;
          const moLabelMap = new Map<string, string>((data ?? []).map((r: any) => [r.id, r.manufacturing_order_no ?? r.id.slice(0, 8)]));
          setDraftLines(lines.map(l => mapLineToDraft(l, moLabelMap)));
        } catch (err) {
          if (cancelled) return;
          console.error('Failed to load MO labels for PO lines:', err);
          setDraftLines(lines.map(l => mapLineToDraft(l)));
        }
      })();
      return () => { cancelled = true; };
    } else {
      setDraftLines(lines.map(l => mapLineToDraft(l)));
    }
  }, [purchaseOrder, lines, isCreateMode, mapLineToDraft]);

  // Pre-populate from Material Demand (sessionStorage)
  useEffect(() => {
    if (!isCreateMode || !activeOrganizationId) return;

    const prefillRaw = sessionStorage.getItem('po_prefill_lines');
    if (prefillRaw) {
      sessionStorage.removeItem('po_prefill_lines');
      try {
        const prefillItems = JSON.parse(prefillRaw) as { catalog_item_id: string; sku: string; name: string; qty: number; unit: string; units_per_purchase_unit: number; manufacturing_order_id?: string; manufacturing_order_no?: string }[];
        if (prefillItems.length > 0) {
          setLoadingRef(true);
          (async () => {
            try {
              const itemIds = prefillItems.map(p => p.catalog_item_id);
              const { data: costData } = await supabase
                .from('CatalogItems')
                .select('id, cost_exw, purchase_unit, units_per_purchase_unit, moq, is_roll, unit_of_measure, measure_basis, description, roll_width_value, roll_width_uom, roll_length_value, roll_length_uom')
                .in('id', itemIds);
              type CostRow = {
                id: string;
                cost_exw: number | null;
                purchase_unit: string | null;
                units_per_purchase_unit: number | null;
                moq: number | null;
                is_roll: boolean;
                unit_of_measure: string | null;
                measure_basis: string | null;
                description: string | null;
                roll_width_value: number | null;
                roll_width_uom: string | null;
                roll_length_value: number | null;
                roll_length_uom: string | null;
              };
              const costMap = new Map<string, CostRow>((costData ?? []).map((c: any) => [c.id, c as CostRow]));

              const newLines: DraftLine[] = prefillItems.map(p => {
                const ci = costMap.get(p.catalog_item_id);
                const costExw = Number(ci?.cost_exw ?? 0);
                const pUnit = ci?.purchase_unit ?? p.unit ?? 'each';
                const unitsPerPU = Number(ci?.units_per_purchase_unit ?? p.units_per_purchase_unit ?? 1);
                const moq = Number(ci?.moq ?? 0);
                const isRoll = ci?.is_roll ?? false;
                const uom = ci?.unit_of_measure ?? 'ea';
                const rollWidthValue = ci?.roll_width_value != null ? Number(ci.roll_width_value) : null;
                const rollWidthUom = ci?.roll_width_uom ?? null;
                const rollLengthValue = ci?.roll_length_value != null ? Number(ci.roll_length_value) : null;
                const rollLengthUom = ci?.roll_length_uom ?? null;
                const purchaseUom = isRoll ? (rollLengthUom ?? uom) : uom;
                const lineUnit: string = pUnit || (isRoll ? 'roll' : 'each');
                const measureBasis = (ci?.measure_basis ?? 'unit') as MeasureBasis;
                const model = resolveInventoryUnitModel({ isRoll, measureBasis, purchaseUnit: pUnit });
                const purchaseMode = model.purchaseMode;
                const stockBasis = model.stockBasis;
                const purchaseUomSnap = purchaseUom;
                const unitCost = convertInternalToPurchaseQty({
                  internalQty: 1,
                  purchaseMode,
                  purchaseUnit: pUnit || 'each',
                  unitsPerPurchaseUnit: unitsPerPU,
                  rollLengthValue,
                  rollLengthUom,
                }).unitCost(costExw);
                const defaultQty = Math.max(1, Number(p.qty ?? 0), moq > 0 ? moq : 0);
                return {
                  tempId: crypto.randomUUID(),
                  catalog_item_id: p.catalog_item_id,
                  sku: p.sku,
                  name: p.name,
                  ordered_qty: defaultQty,
                  received_qty: 0,
                  unit_cost: unitCost,
                  unit: lineUnit,
                  description: ci?.description ?? '',
                  is_one_off: false,
                  notes: '',
                  allocation_type: p.manufacturing_order_id ? 'manufacturing_order' as const : 'stock' as const,
                  allocation_mo_id: p.manufacturing_order_id ?? null,
                  allocation_mo_label: p.manufacturing_order_no ?? null,
                  purchase_unit_snapshot: pUnit,
                  purchase_mode_snapshot: purchaseMode,
                  stock_basis_snapshot: stockBasis,
                  purchase_uom_snapshot: purchaseUomSnap,
                  units_per_purchase_unit_snapshot: unitsPerPU,
                  moq_snapshot: moq,
                  unit_of_measure_snapshot: purchaseUom,
                  is_roll_snapshot: isRoll,
                  roll_width_value_snapshot: rollWidthValue,
                  roll_width_uom_snapshot: rollWidthUom,
                  roll_length_value_snapshot: rollLengthValue,
                  roll_length_uom_snapshot: rollLengthUom,
                };
              });
              setDraftLines(newLines);
            } catch (err) {
              console.error('Failed to load prefill lines:', err);
            } finally {
              setLoadingRef(false);
            }
          })();
          return;
        }
      } catch { /* ignore parse errors */ }
    }
  }, [isCreateMode, activeOrganizationId]);

  const selectedVendor = useMemo(
    () => vendors.find(v => v.id === vendorId) ?? null,
    [vendors, vendorId]
  );

  const filteredVendors = useMemo(() => {
    if (!vendorSearch.trim()) return vendors;
    const s = vendorSearch.toLowerCase();
    return vendors.filter(v =>
      v.name.toLowerCase().includes(s) || (v.email ?? '').toLowerCase().includes(s)
    );
  }, [vendors, vendorSearch]);

  const { subtotal, taxAmount, total, isVendorTaxable, taxPct } = useMemo(() => {
    let sub = 0;
    for (const l of draftLines) {
      sub += l.ordered_qty * l.unit_cost;
    }
    const taxable = (selectedVendor?.tax_rule ?? 'taxable') !== 'tax_exempt';
    const pct = taxable ? Number(costSettings?.tax_pct ?? 0) : 0;
    const tax = sub * (Number.isFinite(pct) ? pct : 0);
    return {
      subtotal: sub,
      taxAmount: tax,
      total: sub + tax,
      isVendorTaxable: taxable,
      taxPct: pct,
    };
  }, [draftLines, selectedVendor?.tax_rule, costSettings?.tax_pct]);

  const searchCatalogItems = useCallback(async (query: string) => {
    if (!activeOrganizationId || query.length < 2) { setSearchResults([]); return; }
    const trimmed = query.trim();
    const tokens = trimmed.toLowerCase().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) { setSearchResults([]); return; }
    const mfgId = selectedVendor?.manufacturer_id;
    const firstToken = tokens[0];
    let q = supabase
      .from('CatalogItems')
      .select('id, sku, name, description, collection_name, variant_name, cost_exw, purchase_unit, units_per_purchase_unit, moq, manufacturer_id, is_roll, unit_of_measure, roll_width_value, roll_width_uom, roll_length_value, roll_length_uom')
      .eq('organization_id', activeOrganizationId)
      .eq('is_active', true)
      .or(`sku.ilike.%${firstToken}%,name.ilike.%${firstToken}%`);
    if (mfgId) q = q.eq('manufacturer_id', mfgId);
    const { data } = await q.limit(50);
    const rows = (data ?? []) as CatalogSearchResult[];
    const normalizedNeedle = normalizeSearchText(trimmed);

    const filtered = rows.filter((item) => {
      const sku = item.sku ?? '';
      const name = item.name ?? '';
      const description = item.description ?? '';
      const collection = item.collection_name ?? '';
      const variant = item.variant_name ?? '';
      const rollLenValue = item.roll_length_value != null ? String(item.roll_length_value) : '';
      const rollLenUom = item.roll_length_uom ?? '';
      const rollWidthValue = item.roll_width_value != null ? String(item.roll_width_value) : '';
      const rollWidthUom = item.roll_width_uom ?? '';
      const purchaseUnit = item.purchase_unit ?? '';
      const itemUom = item.unit_of_measure ?? '';
      const hay = `${sku} ${name} ${description} ${collection} ${variant} ${rollLenValue} ${rollLenUom} ${rollWidthValue} ${rollWidthUom} ${purchaseUnit} ${itemUom}`.toLowerCase();
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

    setSearchResults(filtered.slice(0, 10));
  }, [activeOrganizationId, selectedVendor]);

  useEffect(() => {
    const timer = setTimeout(() => { if (itemSearch.length >= 2) searchCatalogItems(itemSearch); else setSearchResults([]); }, 300);
    return () => clearTimeout(timer);
  }, [itemSearch, searchCatalogItems]);

  const addCatalogItem = async (item: CatalogSearchResult) => {
    if (draftLines.some(l => l.catalog_item_id === item.id && !l.is_one_off)) {
      addNotification({ type: 'warning', title: 'Duplicate', message: 'Item already added.' });
      return;
    }
    let costExw = item.cost_exw != null ? Number(item.cost_exw) : 0;
    let pUnit = item.purchase_unit ?? 'each';
    let unitsPerPU = Number(item.units_per_purchase_unit ?? 1);
    let moq = Number((item as { moq?: number | null }).moq ?? 0);
    let isRoll = item.is_roll ?? false;
    let uom = item.unit_of_measure ?? 'ea';
    const rollWidthValue = item.roll_width_value != null ? Number(item.roll_width_value) : 0;
    const rollWidthUom = item.roll_width_uom ?? null;
    const rollLengthValue = item.roll_length_value != null ? Number(item.roll_length_value) : 0;
    const rollLengthUom = item.roll_length_uom ?? null;

    let purchaseMode: 'unit_packaged' | 'linear_direct' | 'roll' = 'unit_packaged';
    let stockBasis: 'ea' | 'linear_m' = 'ea';
    let purchaseUomSnap: string = isRoll ? (rollLengthUom ?? uom) : uom;
    const info = await fetchCatalogItemCostInfo(item.id);
    if (costExw === 0) costExw = info.cost_exw;
    if (costExw === 0 || !item.purchase_unit) {
      pUnit = info.purchase_unit;
      unitsPerPU = info.units_per_purchase_unit;
      moq = info.moq;
      uom = info.unit_of_measure;
    }
    purchaseMode = info.purchase_mode;
    stockBasis = info.stock_basis;
    purchaseUomSnap = info.purchase_uom;
    const purchaseUom = isRoll ? (rollLengthUom ?? uom) : uom;

    const lineUnit: string = pUnit || (isRoll ? 'roll' : 'each');
    const unitCost = convertInternalToPurchaseQty({
      internalQty: 1,
      purchaseMode,
      purchaseUnit: pUnit || 'each',
      unitsPerPurchaseUnit: unitsPerPU,
      rollLengthValue,
      rollLengthUom,
    }).unitCost(costExw);
    const defaultQty = Math.max(1, moq > 0 ? moq : 0);

    setDraftLines(prev => [...prev, {
      tempId: crypto.randomUUID(),
      catalog_item_id: item.id,
      sku: item.sku,
      name: item.name,
      ordered_qty: defaultQty,
      received_qty: 0,
      unit_cost: unitCost,
      unit: lineUnit,
      description: item.description ?? '',
      is_one_off: false,
      notes: '',
      allocation_type: 'stock',
      allocation_mo_id: null,
      allocation_mo_label: null,
      purchase_unit_snapshot: pUnit,
      purchase_mode_snapshot: purchaseMode,
      stock_basis_snapshot: stockBasis,
      purchase_uom_snapshot: purchaseUomSnap,
      units_per_purchase_unit_snapshot: unitsPerPU,
      moq_snapshot: moq,
      unit_of_measure_snapshot: purchaseUom,
      is_roll_snapshot: isRoll,
      roll_width_value_snapshot: rollWidthValue > 0 ? rollWidthValue : null,
      roll_width_uom_snapshot: rollWidthUom,
      roll_length_value_snapshot: rollLengthValue > 0 ? rollLengthValue : null,
      roll_length_uom_snapshot: rollLengthUom,
    }]);
    setItemSearch('');
    setSearchResults([]);
    setShowSearch(false);
  };

  const addOneOffItem = () => {
    setDraftLines(prev => [...prev, {
      tempId: crypto.randomUUID(),
      catalog_item_id: null,
      sku: '',
      name: '',
      ordered_qty: 1,
      received_qty: 0,
      unit_cost: 0,
      unit: 'ea',
      description: '',
      is_one_off: true,
      notes: '',
      allocation_type: 'stock',
      allocation_mo_id: null,
      allocation_mo_label: null,
      purchase_unit_snapshot: null,
      purchase_mode_snapshot: null,
      stock_basis_snapshot: null,
      purchase_uom_snapshot: null,
      units_per_purchase_unit_snapshot: null,
      moq_snapshot: null,
      unit_of_measure_snapshot: null,
      is_roll_snapshot: false,
      roll_width_value_snapshot: null,
      roll_width_uom_snapshot: null,
      roll_length_value_snapshot: null,
      roll_length_uom_snapshot: null,
    }]);
  };

  const updateLine = (tempId: string, field: keyof DraftLine, value: string | number | boolean) => {
    setDraftLines(prev => prev.map(l => l.tempId === tempId ? { ...l, [field]: value } : l));
  };

  const removeLine = (tempId: string) => {
    const line = draftLines.find(l => l.tempId === tempId);
    if (line && line.received_qty > 0) {
      addNotification({ type: 'warning', title: 'Cannot remove', message: 'Line has received quantity.' });
      return;
    }
    setDraftLines(prev => prev.filter(l => l.tempId !== tempId));
  };

  const handleSave = async () => {
    if (!warehouseId) { addNotification({ type: 'error', title: 'Error', message: 'Select a warehouse.' }); return; }
    if (draftLines.length === 0) { addNotification({ type: 'error', title: 'Error', message: 'Add at least one line.' }); return; }
    for (const l of draftLines) {
      if (l.is_one_off && !l.description.trim()) {
        addNotification({ type: 'error', title: 'Error', message: 'One-off items need a description.' }); return;
      }
      if (l.allocation_type === 'manufacturing_order' && !l.allocation_mo_id) {
        addNotification({ type: 'error', title: 'Error', message: `Line "${l.sku || l.description || 'One-off'}" is set to MO but no MO is selected.` }); return;
      }
    }
    setIsSaving(true);
    try {
      if (isCreateMode) {
        const poLines: CreatePOLineInput[] = draftLines.map(l => ({
          catalog_item_id: l.catalog_item_id,
          ordered_qty: l.ordered_qty,
          unit_cost: l.unit_cost,
          unit: l.unit,
          description: l.is_one_off ? l.description : null,
          is_one_off: l.is_one_off,
          allocation_type: l.allocation_type,
          allocation_mo_id: l.allocation_mo_id,
          sku_snapshot: l.sku || null,
          item_name_snapshot: l.name || null,
          purchase_unit_snapshot: l.purchase_unit_snapshot,
          purchase_mode_snapshot: l.purchase_mode_snapshot ?? null,
          stock_basis_snapshot: l.stock_basis_snapshot ?? null,
          purchase_uom_snapshot: l.purchase_uom_snapshot ?? null,
          units_per_purchase_unit_snapshot: l.units_per_purchase_unit_snapshot,
          moq_snapshot: l.moq_snapshot,
          unit_of_measure_snapshot: l.unit_of_measure_snapshot,
          is_roll_snapshot: l.is_roll_snapshot,
          roll_width_value_snapshot: l.roll_width_value_snapshot,
          roll_width_uom_snapshot: l.roll_width_uom_snapshot,
          roll_length_value_snapshot: l.roll_length_value_snapshot,
          roll_length_uom_snapshot: l.roll_length_uom_snapshot,
        }));
        const po = await createPurchaseOrder({
          warehouse_id: warehouseId,
          vendor_id: vendorId || null,
          expected_date: expectedDate || null,
          notes: poNotes || null,
          currency,
          lines: poLines,
        });
        addNotification({ type: 'success', title: 'Created', message: 'Purchase order created.' });
        router.navigate(withReturnTo(`/inventory/purchase-orders/${po.id}`));
      } else if (poId) {
        const existingLineIds = new Set(lines.map(l => l.id));
        const updateLines: UpdatePOLineInput[] = draftLines.map(l => ({
          id: existingLineIds.has(l.tempId) ? l.tempId : undefined,
          catalog_item_id: l.catalog_item_id,
          ordered_qty: l.ordered_qty,
          unit_cost: l.unit_cost,
          unit: l.unit,
          description: l.is_one_off ? l.description : null,
          is_one_off: l.is_one_off,
          allocation_type: l.allocation_type,
          allocation_mo_id: l.allocation_mo_id,
          sku_snapshot: l.sku || null,
          item_name_snapshot: l.name || null,
          purchase_unit_snapshot: l.purchase_unit_snapshot,
          purchase_mode_snapshot: l.purchase_mode_snapshot ?? null,
          stock_basis_snapshot: l.stock_basis_snapshot ?? null,
          purchase_uom_snapshot: l.purchase_uom_snapshot ?? null,
          units_per_purchase_unit_snapshot: l.units_per_purchase_unit_snapshot,
          moq_snapshot: l.moq_snapshot,
          unit_of_measure_snapshot: l.unit_of_measure_snapshot,
          is_roll_snapshot: l.is_roll_snapshot,
          roll_width_value_snapshot: l.roll_width_value_snapshot,
          roll_width_uom_snapshot: l.roll_width_uom_snapshot,
          roll_length_value_snapshot: l.roll_length_value_snapshot,
          roll_length_uom_snapshot: l.roll_length_uom_snapshot,
        }));
        await updatePurchaseOrder(poId, {
          warehouse_id: warehouseId,
          vendor_id: vendorId || null,
          expected_date: expectedDate || null,
          notes: poNotes || null,
          currency,
          lines: updateLines,
        });
        addNotification({ type: 'success', title: 'Saved', message: 'Purchase order updated.' });
        refetch();
      }
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message || 'Failed to save.' });
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!poId || !canDelete) return;
    if (!confirm('Delete this purchase order? This cannot be undone.')) return;
    try {
      await deletePurchaseOrder(poId);
      addNotification({ type: 'success', title: 'Deleted', message: 'Purchase order deleted.' });
      handleBack();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message || 'Failed to delete.' });
    }
  };

  const handleReceive = () => {
    if (!poId) return;
    const initial: Record<string, number> = {};
    lines.forEach(l => {
      const remaining = (l.ordered_qty ?? 0) - (l.received_qty ?? 0);
      if (remaining > 0) initial[l.id] = remaining;
    });
    setReceiveQtyMap(initial);
    setShowReceiveModal(true);
  };

  const handleApprove = async () => {
    if (!poId) return;
    try {
      await updateStatus(poId, 'OPEN');
      addNotification({ type: 'success', title: 'Approved', message: 'Purchase order is now Open.' });
      refetch();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message || 'Failed to approve.' });
    }
  };

  const handleCancel = async () => {
    if (!poId) return;
    if (!confirm('Cancel this purchase order? This action cannot be undone.')) return;
    try {
      await updateStatus(poId, 'CANCELLED');
      addNotification({ type: 'success', title: 'Cancelled', message: 'Purchase order cancelled.' });
      refetch();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message || 'Failed to cancel.' });
    }
  };

  const handleArchive = async () => {
    if (!poId) return;
    if (!confirm('Archive this purchase order?')) return;
    try {
      await updateStatus(poId, 'ARCHIVED');
      addNotification({ type: 'success', title: 'Archived', message: 'Purchase order archived.' });
      refetch();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message || 'Failed to archive.' });
    }
  };

  const handleConfirmReceive = async () => {
    if (!poId) return;
    const toReceive = Object.entries(receiveQtyMap)
      .filter(([, qty]) => qty > 0)
      .map(([lineId, qty]) => ({ purchase_order_line_id: lineId, received_qty: qty }));
    if (toReceive.length === 0) {
      addNotification({ type: 'warning', title: 'No quantities', message: 'Enter received quantity for at least one line.' });
      return;
    }
    try {
      const result = await receivePurchaseOrder(poId, toReceive);
      addNotification({ type: 'success', title: 'Received', message: `Receipt ${(result as { movement_no?: string }).movement_no ?? ''} created.` });
      setShowReceiveModal(false);
      refetch();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message || 'Failed to receive.' });
    }
  };

  const setReceiveQty = (lineId: string, qty: number) => {
    setReceiveQtyMap(prev => ({ ...prev, [lineId]: Math.max(0, qty) }));
  };

  const allocationSummary = useMemo(() => {
    const stockCount = draftLines.filter(l => l.allocation_type === 'stock').length;
    const moGroups = new Map<string, { label: string; count: number }>();
    for (const l of draftLines) {
      if (l.allocation_type === 'manufacturing_order' && l.allocation_mo_id) {
        const existing = moGroups.get(l.allocation_mo_id);
        if (existing) existing.count++;
        else moGroups.set(l.allocation_mo_id, { label: l.allocation_mo_label ?? l.allocation_mo_id.slice(0, 8), count: 1 });
      }
    }
    for (const mo of linkedMOs) {
      if (!moGroups.has(mo.id)) {
        moGroups.set(mo.id, { label: mo.manufacturing_order_no, count: 0 });
      }
    }
    const parts: string[] = [];
    if (stockCount > 0) parts.push(`Stock (${stockCount})`);
    for (const [, v] of moGroups) parts.push(v.count > 0 ? `${v.label} (${v.count})` : v.label);
    return parts.join(', ');
  }, [draftLines, linkedMOs]);

  const loadOrganizationLogoOptions = useCallback(async () => {
    const tryLogo = async (path: string): Promise<string | undefined> => {
      try {
        const res = await fetch(path, { cache: 'no-store' });
        if (!res.ok) return undefined;
        const blob = await res.blob();
        return await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      } catch {
        return undefined;
      }
    };

    let organizationName = 'Arquiproductos';
    if (activeOrganizationId) {
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', activeOrganizationId)
        .maybeSingle();
      organizationName = (orgData as { name?: string } | null)?.name ?? 'Arquiproductos';
    }

    const logoPaths = [
      '/images/Arquiproductos.png',
      '/images/arquiproductos.png',
      '/images/Arquiproductos.jpg',
      '/images/arquiproductos.jpg',
    ];
    let logoPngBase64: string | undefined;
    for (const path of logoPaths) {
      logoPngBase64 = await tryLogo(path);
      if (logoPngBase64) break;
    }

    let logoWidthPx = 100;
    let logoHeightPx = 100;
    if (logoPngBase64) {
      const dims = await new Promise<{ w: number; h: number }>((resolve) => {
        const img = new Image();
        img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
        img.onerror = () => resolve({ w: 100, h: 100 });
        img.src = logoPngBase64!;
      });
      logoWidthPx = dims.w;
      logoHeightPx = dims.h;
    }

    return { organizationName, logoPngBase64, logoWidthPx, logoHeightPx };
  }, [activeOrganizationId]);

  const buildPurchaseOrderPDF = async () => {
    const { generatePurchaseOrderPDF } = await import('../../lib/pdf/generatePurchaseOrderPDF');
    const poData = purchaseOrder!;
    const vendor = selectedVendor;
    const pdfLines = (draftLines.length > 0 ? draftLines : lines.map(l => ({
      sku: l.CatalogItems?.sku ?? '',
      name: l.CatalogItems?.name ?? '',
      description: l.description ?? '',
      is_one_off: l.is_one_off,
      ordered_qty: l.ordered_qty,
      unit_cost: Number(l.unit_cost ?? 0),
      unit: l.unit ?? 'ea',
    }))).map(l => ({
      sku: l.sku || '',
      description: l.is_one_off ? l.description : ((l as any).name || l.sku || ''),
      qty: (l as any).ordered_qty,
      unit: (l as any).unit || 'ea',
      unit_cost: l.unit_cost,
      line_total: (l as any).ordered_qty * l.unit_cost,
    }));

    const logoOptions = await loadOrganizationLogoOptions();

    return generatePurchaseOrderPDF(
      {
        po_number: poData.po_number ?? 'DRAFT',
        status: poData.status,
        expected_date: poData.expected_date,
        currency: poData.currency ?? 'USD',
        subtotal,
        total,
        notes: poData.notes,
        allocation_summary: allocationSummary || null,
      },
      vendor ? {
        name: vendor.name,
        email: vendor.email ?? null,
        phone: vendor.work_phone ?? null,
        address: [vendor.street_address_line_1, vendor.street_address_line_2, [vendor.city, vendor.state, vendor.zip_code].filter(Boolean).join(', '), vendor.country].filter(Boolean).join('\n'),
        payment_terms: vendor.payment_terms ?? null,
        delivery_terms: vendor.delivery_terms ?? null,
      } : null,
      pdfLines,
      logoOptions
    );
  };

  const handlePreviewPDF = async () => {
    try {
      const doc = await buildPurchaseOrderPDF();
      const blob = doc.output('blob');
      const url = URL.createObjectURL(blob);
      window.open(url, '_blank');
    } catch {
      addNotification({ type: 'error', title: 'PDF Error', message: 'Failed to generate PDF.' });
    }
  };

  const handleDownloadPDF = async () => {
    try {
      const doc = await buildPurchaseOrderPDF();
      doc.save(`${purchaseOrder?.po_number ?? 'PO-DRAFT'}.pdf`);
    } catch {
      addNotification({ type: 'error', title: 'PDF Error', message: 'Failed to generate PDF.' });
    }
  };

  if (!isCreateMode && loading && !purchaseOrder) {
    return (
      <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 py-6">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-gray-300 rounded w-1/3" />
            <div className="grid grid-cols-2 gap-6">
              <div className="h-48 bg-gray-200 rounded" />
              <div className="h-48 bg-gray-200 rounded" />
            </div>
            <div className="h-60 bg-gray-200 rounded" />
          </div>
        </div>
      </div>
    );
  }

  if (!isCreateMode && poId && !purchaseOrder && !loading) {
    return (
      <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 py-6">
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-sm text-red-700 mb-3">Purchase order not found. It may have been deleted.</p>
            <button
              type="button"
              onClick={handleBack}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-red-700 bg-red-100 rounded-lg hover:bg-red-200 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to Purchase Orders
            </button>
          </div>
        </div>
      </div>
    );
  }

  const displayLines = draftLines;

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
      {/* Header */}
      <div className="flex justify-center py-4 shrink-0">
        <div className="flex items-center gap-4 w-full max-w-6xl mx-auto px-4 md:px-6">
          <button
            type="button"
            onClick={handleBack}
            className="p-1 -ml-1 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-3">
              <h1 className="text-xl font-bold text-gray-900 truncate">
                {isCreateMode ? 'New Purchase Order' : purchaseOrder?.po_number ?? 'Purchase Order'}
              </h1>
              {!isCreateMode && purchaseOrder && (
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[purchaseOrder.status] ?? 'bg-gray-50 text-gray-700'}`}>
                  {purchaseOrder.status}
                </span>
              )}
            </div>
            <p className="text-sm text-gray-500 truncate">
              {isCreateMode ? 'Create a new purchase order' : [
                purchaseOrder?.DirectoryVendors?.name,
                purchaseOrder?.Warehouses?.name,
              ].filter(Boolean).join(' · ')}
            </p>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            {!isCreateMode && purchaseOrder && !isTerminal && (
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
            {canApprove && (
              <button
                type="button"
                onClick={handleApprove}
                disabled={isStatusUpdating}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
              >
                <CheckCircle2 className="w-4 h-4" />
                {isStatusUpdating ? 'Approving...' : 'Approve'}
              </button>
            )}
            {canReceive && (
              <button
                type="button"
                onClick={handleReceive}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 transition-colors"
              >
                <Package className="w-4 h-4" />
                Receive
              </button>
            )}
            {canArchive && (
              <button
                type="button"
                onClick={handleArchive}
                disabled={isStatusUpdating}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 transition-colors"
              >
                <Archive className="w-4 h-4" />
                Archive
              </button>
            )}
            {canCancel && !isCreateMode && (
              <button
                type="button"
                onClick={handleCancel}
                disabled={isStatusUpdating}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-red-600 bg-white border border-red-200 rounded-lg hover:bg-red-50 disabled:opacity-50 transition-colors"
              >
                <XCircle className="w-4 h-4" />
                Cancel PO
              </button>
            )}
            {canDelete && (
              <button
                type="button"
                onClick={handleDelete}
                disabled={isDeleting}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 transition-colors"
              >
                <Trash2 className="w-4 h-4" />
                Delete
              </button>
            )}
            <button
              type="button"
              onClick={handleBack}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Back
            </button>
            {canEdit && (
              <button
                type="button"
                onClick={handleSave}
                disabled={isSaving || isCreating || isUpdating}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
              >
                {isSaving || isCreating || isUpdating ? 'Saving...' : isCreateMode ? 'Create PO' : 'Save'}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 overflow-auto pb-6">
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 space-y-6">
          {loadingRef && (
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary mx-auto mb-2" />
              <p className="text-sm text-blue-700">Loading manufacturing order data...</p>
            </div>
          )}

          {poStatus === 'CANCELLED' && (
            <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-3 flex items-center gap-2">
              <XCircle className="w-4 h-4 text-red-500 shrink-0" />
              <p className="text-sm text-red-700">This purchase order has been cancelled. No further actions are available.</p>
            </div>
          )}
          {poStatus === 'ARCHIVED' && (
            <div className="bg-slate-50 border border-slate-200 rounded-lg px-4 py-3 flex items-center gap-2">
              <Archive className="w-4 h-4 text-slate-500 shrink-0" />
              <p className="text-sm text-slate-600">This purchase order has been archived.</p>
            </div>
          )}
          {/* Two-card header: Vendor Info + PO Details */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Vendor Info card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Vendor Info</h3>

              {canEdit ? (
                <div className="relative mb-4">
                  <label className="block text-xs font-medium text-gray-500 mb-1">Vendor</label>
                  {selectedVendor ? (
                    <div className="flex items-center justify-between px-3 py-2 border border-gray-200 rounded-lg bg-gray-50">
                      <span className="text-sm font-medium text-gray-900">{selectedVendor.name}</span>
                      <button
                        type="button"
                        onClick={() => { setVendorId(''); setVendorSearch(''); }}
                        className="text-xs text-gray-500 hover:text-gray-700"
                      >
                        Change
                      </button>
                    </div>
                  ) : (
                    <>
                      <input
                        type="text"
                        placeholder="Search vendors..."
                        value={vendorSearch}
                        onChange={(e) => { setVendorSearch(e.target.value); setShowVendorDropdown(true); }}
                        onFocus={() => setShowVendorDropdown(true)}
                        className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                      {showVendorDropdown && filteredVendors.length > 0 && (
                        <div className="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                          {filteredVendors.map(v => (
                            <button
                              key={v.id}
                              type="button"
                              onClick={() => { setVendorId(v.id); setShowVendorDropdown(false); setVendorSearch(''); }}
                              className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0"
                            >
                              <span className="font-medium">{v.name}</span>
                              {v.email && <span className="ml-2 text-gray-400 text-xs">{v.email}</span>}
                            </button>
                          ))}
                        </div>
                      )}
                    </>
                  )}
                </div>
              ) : null}

              {selectedVendor ? (
                <dl className="space-y-2 text-sm">
                  {!canEdit && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Vendor</dt>
                      <dd className="font-medium text-gray-900">{selectedVendor.name}</dd>
                    </div>
                  )}
                  {selectedVendor.primary_contact_name && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Contact</dt>
                      <dd className="text-gray-900">{selectedVendor.primary_contact_name}</dd>
                    </div>
                  )}
                  {selectedVendor.email && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Email</dt>
                      <dd className="text-gray-900">{selectedVendor.email}</dd>
                    </div>
                  )}
                  {selectedVendor.work_phone && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Phone</dt>
                      <dd className="text-gray-900">{selectedVendor.work_phone}</dd>
                    </div>
                  )}
                  {selectedVendor.payment_terms && (
                    <div className="flex justify-between border-t pt-2">
                      <dt className="text-gray-500">Payment Terms</dt>
                      <dd className="text-gray-900">{selectedVendor.payment_terms}</dd>
                    </div>
                  )}
                  {selectedVendor.delivery_terms && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Delivery Terms</dt>
                      <dd className="text-gray-900">{selectedVendor.delivery_terms}</dd>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Tax Rule</dt>
                    <dd className={isVendorTaxable ? 'text-green-700 font-medium' : 'text-blue-700 font-medium'}>
                      {isVendorTaxable ? 'Taxable' : 'Tax Exempt'}
                    </dd>
                  </div>
                  {(selectedVendor.street_address_line_1 || selectedVendor.city) && (
                    <div className="border-t pt-2">
                      <dt className="text-gray-500 mb-0.5 text-xs">Address</dt>
                      <dd className="text-gray-900 whitespace-pre-line text-xs leading-relaxed">
                        {[selectedVendor.street_address_line_1, selectedVendor.street_address_line_2, [selectedVendor.city, selectedVendor.state, selectedVendor.zip_code].filter(Boolean).join(', '), selectedVendor.country].filter(Boolean).join('\n')}
                      </dd>
                    </div>
                  )}
                </dl>
              ) : (
                <p className="text-sm text-gray-400">{canEdit ? 'Select a vendor above' : 'No vendor assigned'}</p>
              )}
            </div>

            {/* PO Details card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-3 flex items-start justify-between gap-3">
                <h3 className="text-sm font-semibold text-gray-900">PO Details</h3>
                {isDraft && !isCreateMode && (
                  <span className="inline-flex items-center px-1 text-sm font-bold uppercase tracking-wide text-gray-900">
                    Draft
                  </span>
                )}
              </div>
              {canEdit ? (
                <div className="space-y-3">
                  {!isCreateMode && (
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">PO #</label>
                      <input
                        type="text"
                        value={purchaseOrder?.po_number ?? ''}
                        readOnly
                        className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-600"
                      />
                    </div>
                  )}
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Warehouse *</label>
                    <SelectShadcn
                      value={warehouseId || '__none__'}
                      onValueChange={(value) => setWarehouseId(value === '__none__' ? '' : value)}
                    >
                      <SelectTrigger className="h-10 rounded-lg text-sm">
                        <SelectValue placeholder="Select warehouse..." />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="__none__">Select warehouse...</SelectItem>
                        {warehouses.map((w) => (
                          <SelectItem key={w.id} value={w.id}>
                            {w.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">Expected Date</label>
                      <input
                        type="date"
                        value={expectedDate}
                        onChange={e => setExpectedDate(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">Currency</label>
                      <SelectShadcn value={currency} onValueChange={setCurrency}>
                        <SelectTrigger className="h-10 rounded-lg text-sm">
                          <SelectValue placeholder="Select currency" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="USD">USD</SelectItem>
                          <SelectItem value="EUR">EUR</SelectItem>
                          <SelectItem value="GBP">GBP</SelectItem>
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                  </div>
                  {allocationSummary && (
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">Allocation</label>
                      <div className="flex flex-wrap gap-1.5">
                        {draftLines.some(l => l.allocation_type === 'stock') && (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700">
                            Stock ({draftLines.filter(l => l.allocation_type === 'stock').length})
                          </span>
                        )}
                        {[...new Map(draftLines.filter(l => l.allocation_type === 'manufacturing_order' && l.allocation_mo_id).map(l => [l.allocation_mo_id!, l])).values()].map(l => {
                          const count = draftLines.filter(dl => dl.allocation_mo_id === l.allocation_mo_id).length;
                          return (
                            <span key={l.allocation_mo_id} className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-50 text-purple-700">
                              {l.allocation_mo_label ?? l.allocation_mo_id!.slice(0, 8)} ({count})
                            </span>
                          );
                        })}
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <dl className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Status</dt>
                    <dd>
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[purchaseOrder?.status ?? 'OPEN']}`}>
                        {purchaseOrder?.status}
                      </span>
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Warehouse</dt>
                    <dd className="text-gray-900">{purchaseOrder?.Warehouses?.name ?? '—'}</dd>
                  </div>
                  {purchaseOrder?.expected_date && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Expected Date</dt>
                      <dd className="text-gray-900">{formatDate(purchaseOrder.expected_date)}</dd>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Currency</dt>
                    <dd className="text-gray-900">{purchaseOrder?.currency ?? 'USD'}</dd>
                  </div>
                  {allocationSummary && (
                    <div className="border-t pt-2">
                      <dt className="text-gray-500 text-xs mb-1">Allocation</dt>
                      <dd>
                        <div className="flex flex-wrap gap-1.5">
                          {draftLines.some(l => l.allocation_type === 'stock') && (
                            <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700">
                              Stock ({draftLines.filter(l => l.allocation_type === 'stock').length})
                            </span>
                          )}
                          {[...new Map(draftLines.filter(l => l.allocation_type === 'manufacturing_order' && l.allocation_mo_id).map(l => [l.allocation_mo_id!, l])).values()].map(l => {
                            const count = draftLines.filter(dl => dl.allocation_mo_id === l.allocation_mo_id).length;
                            return (
                              <button
                                key={l.allocation_mo_id}
                                type="button"
                                onClick={() => router.navigate(`/manufacturing/orders/${l.allocation_mo_id}`)}
                                className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-50 text-purple-700 hover:bg-purple-100 transition-colors"
                              >
                                {l.allocation_mo_label ?? l.allocation_mo_id!.slice(0, 8)} ({count})
                              </button>
                            );
                          })}
                        </div>
                      </dd>
                    </div>
                  )}
                </dl>
              )}
            </div>
          </div>

          {/* Lines + Summary */}
          <div className="space-y-4">
            <div className="rounded-lg border border-gray-200 overflow-visible bg-white">
              <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs w-8">#</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs w-32">SKU</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs">Description</th>
                  <th className="px-5 py-3 text-center font-medium text-gray-700 text-xs w-[118px]"><span className="relative left-[35px] inline-block">Ordered</span></th>
                  <th className="px-5 py-3 text-center font-medium text-gray-700 text-xs w-[76px]"><span className="relative left-[35px] inline-block">Unit</span></th>
                  <th className="px-5 py-3 text-center font-medium text-gray-700 text-xs w-[150px]"><span className="relative left-[10px] inline-block">Allocated To</span></th>
                  {!isCreateMode && <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-20">Received</th>}
                  <th className="px-4 py-3 text-center font-medium text-gray-700 text-xs w-[107px]">Unit Cost</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-28">Line Total</th>
                  {canEdit && (
                    <th className="px-4 py-3 text-center font-medium text-gray-700 text-xs w-20">
                      <div className="flex items-center gap-1 justify-center">
                        <button
                          type="button"
                          onClick={() => {
                            if (!vendorId) {
                              addNotification({ type: 'warning', title: 'Select Vendor', message: 'Please select a vendor before adding items.' });
                              return;
                            }
                            setShowSearch(true);
                          }}
                          className={`inline-flex items-center justify-center w-6 h-6 rounded-full transition-colors ${vendorId ? 'bg-primary text-white hover:bg-primary/90' : 'bg-gray-300 text-gray-500 cursor-not-allowed'}`}
                          title={vendorId ? 'Add catalog item' : 'Select a vendor first'}
                        >
                          <Plus className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </th>
                  )}
                </tr>
              </thead>
              <tbody>
                {/* Search row */}
                {showSearch && canEdit && (
                  <tr className="border-t bg-gray-50">
                    <td colSpan={canEdit ? (isCreateMode ? 10 : 11) : (isCreateMode ? 9 : 10)} className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="relative flex-1">
                          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                          <input
                            type="text"
                            placeholder="Search SKU, name, description, or roll measure (e.g. 29.87 yd)"
                            value={itemSearch}
                            onChange={e => setItemSearch(e.target.value)}
                            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                            autoFocus
                          />
                          {searchResults.length > 0 && (
                            <div className="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                              {searchResults.map(item => (
                                <button
                                  key={item.id}
                                  type="button"
                                  onClick={() => addCatalogItem(item)}
                                  className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0 flex justify-between items-center"
                                >
                                  <span className="flex items-center gap-2">
                                    <span className="font-medium text-gray-900">{item.sku}</span>
                                    <span className="text-gray-500">{item.name}</span>
                                    {item.is_roll && (
                                      <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-indigo-50 text-indigo-700">roll</span>
                                    )}
                                  </span>
                                  <span className="flex items-center gap-2 text-xs">
                                    <span className="text-gray-400">{item.purchase_unit ?? item.unit_of_measure ?? 'each'}</span>
                                    <span className="text-gray-500 font-medium">
                                      {item.cost_exw != null ? fmtCurrency(Number(item.cost_exw), currency) : '—'}
                                    </span>
                                  </span>
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                        <button
                          type="button"
                          onClick={() => {
                            if (!vendorId) {
                              addNotification({ type: 'warning', title: 'Select Vendor', message: 'Please select a vendor before adding items.' });
                              return;
                            }
                            addOneOffItem();
                          }}
                          className="px-3 py-2 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 whitespace-nowrap"
                        >
                          + One-Off Item
                        </button>
                        <button
                          type="button"
                          onClick={() => { setShowSearch(false); setItemSearch(''); setSearchResults([]); }}
                          className="text-xs text-gray-500 hover:text-gray-700"
                        >
                          Close
                        </button>
                      </div>
                    </td>
                  </tr>
                )}

                {displayLines.length === 0 ? (
                  <tr>
                    <td colSpan={canEdit ? (isCreateMode ? 10 : 11) : (isCreateMode ? 9 : 10)} className="px-4 py-8 text-center text-gray-500">
                      {canEdit && !vendorId
                        ? 'Select a vendor first, then click "+" to add items.'
                        : canEdit
                          ? 'No lines. Click "+" to add items.'
                          : 'No lines.'}
                    </td>
                  </tr>
                ) : displayLines.map((line, idx) => {
                  const lineTotal = line.ordered_qty * line.unit_cost;
                  const moq = Math.max(0, Number(line.moq_snapshot ?? 0));
                  const belowMoq = moq > 0 && Number(line.ordered_qty) < moq;
                  const internalM = lineInternalQtyM(line.ordered_qty, line);
                  const purchaseSuffix = formatPurchaseUnitSuffix(line);
                  return (
                    <tr key={line.tempId} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-3 text-center text-gray-400 tabular-nums">{idx + 1}</td>
                      <td className="px-4 py-3 font-medium text-gray-900 text-xs whitespace-nowrap">
                        {line.is_one_off ? <span className="text-amber-600 italic">One-off</span> : (line.sku || '—')}
                      </td>
                      <td className="px-4 py-3">
                        {line.is_one_off && canEdit ? (
                          <input
                            type="text"
                            value={line.description}
                            onChange={e => updateLine(line.tempId, 'description', e.target.value)}
                            placeholder="Item description..."
                            className="w-full px-2 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                          />
                        ) : (
                          <span className="text-gray-700">
                            {line.is_one_off ? line.description : (line.description?.trim() || line.name)}
                            {!line.is_one_off && purchaseSuffix && (
                              <span className="text-gray-400 ml-1 text-xs">{purchaseSuffix}</span>
                            )}
                          </span>
                        )}
                        {!line.is_one_off && moq > 0 && (
                          <p className="mt-0.5 text-[11px] text-gray-500">
                            MOQ {moq % 1 === 0 ? moq : moq.toFixed(2)} {line.purchase_unit_snapshot}
                          </p>
                        )}
                      </td>
                      <td className="px-5 py-3 text-center relative w-[118px]">
                        <div className="relative left-[35px]">
                          {belowMoq && (
                            <span className="absolute -left-[74px] top-1/2 -translate-y-1/2 px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-amber-50 text-amber-600 border border-amber-200 leading-tight whitespace-nowrap">
                              Below MOQ
                            </span>
                          )}
                          {canEdit ? (
                            <input
                              type="number"
                              min={line.received_qty}
                              step="0.01"
                              value={line.ordered_qty}
                              onChange={e => updateLine(line.tempId, 'ordered_qty', Math.max(line.received_qty, parseFloat(e.target.value) || 0))}
                              className="w-full min-w-[77px] px-2 py-1 border border-gray-200 rounded text-sm text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none focus:outline-none focus:ring-2 focus:ring-primary/20"
                            />
                          ) : (
                            <span className="tabular-nums inline-block text-center w-full">
                              {Number(line.ordered_qty).toFixed(2)}
                              {internalM != null ? <span className="text-xs text-gray-500 block">→ {internalM.toFixed(2)} m</span> : null}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-5 py-3 text-center w-[76px]">
                        <div className="relative left-[35px]">
                        {canEdit && line.is_roll_snapshot && line.unit_of_measure_snapshot ? (
                          <SelectShadcn
                            value={line.unit}
                            onValueChange={(newUnit) => {
                              const rlv = line.roll_length_value_snapshot ?? 0;
                              const costExw = rlv > 0 && line.unit === 'roll'
                                ? line.unit_cost / rlv
                                : line.unit !== 'roll'
                                  ? line.unit_cost
                                  : line.unit_cost;
                              const newCost = newUnit === 'roll' && rlv > 0
                                ? costExw * rlv
                                : costExw;
                              setDraftLines(prev => prev.map(dl =>
                                dl.tempId === line.tempId
                                  ? { ...dl, unit: newUnit, unit_cost: newCost }
                                  : dl
                              ));
                            }}
                          >
                            <SelectTrigger className="h-6 min-w-[72px] rounded bg-gray-100 border-0 text-xs text-gray-700 px-1.5 py-0">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="roll">roll</SelectItem>
                              <SelectItem value={line.unit_of_measure_snapshot}>{line.unit_of_measure_snapshot}</SelectItem>
                            </SelectContent>
                          </SelectShadcn>
                        ) : canEdit && line.purchase_unit_snapshot && line.purchase_unit_snapshot !== 'each' ? (
                          <SelectShadcn
                            value={line.unit}
                            onValueChange={(newUnit) => {
                              const upp = line.units_per_purchase_unit_snapshot ?? 1;
                              const pkgUnit = line.purchase_unit_snapshot!;
                              const isCurrentlyPkg = line.unit === pkgUnit;
                              let newQty = line.ordered_qty;
                              let newCost = line.unit_cost;
                              if (isCurrentlyPkg && newUnit === 'each') {
                                newQty = line.ordered_qty * upp;
                                newCost = line.unit_cost / upp;
                              } else if (!isCurrentlyPkg && newUnit === pkgUnit) {
                                newQty = Math.max(1, Math.ceil(line.ordered_qty / upp));
                                newCost = line.unit_cost * upp;
                              }
                              setDraftLines(prev => prev.map(dl =>
                                dl.tempId === line.tempId
                                  ? { ...dl, unit: newUnit, unit_cost: newCost, ordered_qty: newQty }
                                  : dl
                              ));
                            }}
                          >
                            <SelectTrigger className="h-6 min-w-[72px] rounded bg-gray-100 border-0 text-xs text-gray-700 px-1.5 py-0">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value={line.purchase_unit_snapshot}>{line.purchase_unit_snapshot}</SelectItem>
                              <SelectItem value="each">each</SelectItem>
                            </SelectContent>
                          </SelectShadcn>
                        ) : (
                          <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600">
                            {line.unit || 'ea'}
                          </span>
                        )}
                        </div>
                      </td>
                      <td className="px-5 py-3 w-[150px] text-center">
                        {canEdit ? (
                          <div className="relative inline-block text-left left-[10px]">
                            {line.allocation_type === 'manufacturing_order' && line.allocation_mo_id ? (
                              <div className="flex items-center gap-1">
                                <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-purple-50 text-purple-700 truncate max-w-[110px]">
                                  {line.allocation_mo_label ?? line.allocation_mo_id.slice(0, 8)}
                                </span>
                                <button
                                  type="button"
                                  onClick={() => {
                                    setDraftLines(prev => prev.map(dl => dl.tempId === line.tempId
                                      ? { ...dl, allocation_type: 'stock', allocation_mo_id: null, allocation_mo_label: null }
                                      : dl));
                                  }}
                                  className="text-gray-400 hover:text-red-500 text-xs"
                                  title="Clear to Stock"
                                >
                                  ×
                                </button>
                              </div>
                            ) : (
                              <button
                                type="button"
                                onClick={() => {
                                  setLineMoDropdownId(lineMoDropdownId === line.tempId ? null : line.tempId);
                                  setLineMoSearch('');
                                  setLineMoOptions([]);
                                }}
                                className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition-colors"
                              >
                                Stock ▾
                              </button>
                            )}
                            {lineMoDropdownId === line.tempId && line.allocation_type !== 'manufacturing_order' && (
                              <div className="absolute z-30 mt-1 left-0 w-52 bg-white border border-gray-200 rounded-lg shadow-lg">
                                <div className="p-1.5 border-b">
                                  <input
                                    type="text"
                                    placeholder="Search MO..."
                                    value={lineMoSearch}
                                    onChange={e => setLineMoSearch(e.target.value)}
                                    className="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-primary/20"
                                    autoFocus
                                  />
                                </div>
                                <div className="max-h-36 overflow-y-auto">
                                  {lineMoOptions.length === 0 && lineMoSearch.length >= 2 && (
                                    <div className="px-2 py-2 text-xs text-gray-400 text-center">No MOs found</div>
                                  )}
                                  {lineMoSearch.length < 2 && (
                                    <div className="px-2 py-2 text-xs text-gray-400 text-center">Type 2+ chars...</div>
                                  )}
                                  {lineMoOptions.map(mo => (
                                    <button
                                      key={mo.id}
                                      type="button"
                                      onClick={() => {
                                        setDraftLines(prev => prev.map(dl => dl.tempId === line.tempId
                                          ? { ...dl, allocation_type: 'manufacturing_order', allocation_mo_id: mo.id, allocation_mo_label: mo.manufacturing_order_no }
                                          : dl));
                                        setLineMoDropdownId(null);
                                        setLineMoSearch('');
                                      }}
                                      className="w-full text-left px-2 py-1.5 text-xs hover:bg-gray-50 border-b border-gray-100 last:border-0"
                                    >
                                      <span className="font-medium">{mo.manufacturing_order_no}</span>
                                    </button>
                                  ))}
                                </div>
                                <div className="border-t p-1">
                                  <button
                                    type="button"
                                    onClick={() => setLineMoDropdownId(null)}
                                    className="w-full text-center text-xs text-gray-400 hover:text-gray-600 py-1"
                                  >
                                    Cancel
                                  </button>
                                </div>
                              </div>
                            )}
                          </div>
                        ) : (
                          line.allocation_type === 'manufacturing_order' && line.allocation_mo_id ? (
                            <button
                              type="button"
                              onClick={() => router.navigate(`/manufacturing/orders/${line.allocation_mo_id}`)}
                              className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-purple-50 text-purple-700 hover:bg-purple-100 transition-colors truncate max-w-[130px]"
                            >
                              {line.allocation_mo_label ?? line.allocation_mo_id.slice(0, 8)}
                            </button>
                          ) : (
                            <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600">
                              Stock
                            </span>
                          )
                        )}
                      </td>
                      {!isCreateMode && (
                        <td className="px-4 py-3 text-right text-gray-600 tabular-nums">{Number(line.received_qty).toFixed(2)}</td>
                      )}
                      <td className="px-4 py-3 text-center">
                        {canEdit ? (
                          <input
                            type="number"
                            min={0}
                            step="0.01"
                            value={line.unit_cost}
                            onChange={e => updateLine(line.tempId, 'unit_cost', Math.max(0, parseFloat(e.target.value) || 0))}
                            className="w-full min-w-[77px] px-2 py-1 border border-gray-200 rounded text-sm text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none focus:outline-none focus:ring-2 focus:ring-primary/20"
                          />
                        ) : (
                          <span className="tabular-nums font-mono inline-block text-center w-full">{fmtCurrency(line.unit_cost, currency)}</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right font-mono font-medium tabular-nums">
                        {fmtCurrency(lineTotal, currency)}
                      </td>
                      {canEdit && (
                        <td className="px-4 py-3 text-center">
                          {line.received_qty === 0 && (
                            <button type="button" onClick={() => removeLine(line.tempId)} className="p-1 text-gray-400 hover:text-red-500 transition-colors">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
              </table>
            </div>

            <div className="flex justify-end">
              <div className="bg-white border border-gray-200 rounded-lg p-6 w-full lg:w-[22rem] shrink-0 self-start">
                <h3 className="text-sm font-semibold text-gray-700 mb-3">Summary</h3>
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Subtotal</span>
                  <span className="font-mono">{fmtCurrency(subtotal, currency)}</span>
                </div>
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Tax {isVendorTaxable ? `(${(taxPct * 100).toFixed(1)}%)` : '(Exempt)'}</span>
                  <span className="font-mono">{fmtCurrency(taxAmount, currency)}</span>
                </div>
                <div className="flex justify-between py-2 mt-2 border-t border-gray-200 font-semibold">
                  <span>Total {currency ? `(${currency})` : ''}</span>
                  <span className="font-mono">{fmtCurrency(total, currency)}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Receive Modal */}
      {showReceiveModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowReceiveModal(false)}>
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-auto" onClick={e => e.stopPropagation()}>
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Receive Goods</h2>
              <p className="text-sm text-gray-600 mb-4">Enter received quantity for each line.</p>
              <div className="rounded-lg border overflow-hidden mb-4">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 border-b">
                    <tr>
                      <th className="px-4 py-2 text-left font-medium text-gray-700">Item</th>
                      <th className="px-4 py-2 text-right font-medium text-gray-700">Ordered</th>
                      <th className="px-4 py-2 text-right font-medium text-gray-700">Already Rcvd</th>
                      <th className="px-4 py-2 text-right font-medium text-gray-700">Remaining</th>
                      <th className="px-4 py-2 text-right font-medium text-gray-700">Receive Qty</th>
                    </tr>
                  </thead>
                  <tbody>
                    {lines.filter(l => ((l.ordered_qty ?? 0) - (l.received_qty ?? 0)) > 0).map(l => {
                      const remaining = (l.ordered_qty ?? 0) - (l.received_qty ?? 0);
                      const label = l.is_one_off ? (l.description ?? 'One-off item') : (l.CatalogItems?.sku ?? '—');
                      return (
                        <tr key={l.id} className="border-t">
                          <td className="px-4 py-2">
                            <span className="font-medium">{label}</span>
                            {!l.is_one_off && l.CatalogItems?.name && (
                              <span className="text-gray-500 text-xs ml-1">{l.CatalogItems.name}</span>
                            )}
                          </td>
                          <td className="px-4 py-2 text-right tabular-nums">
                            {Number(l.ordered_qty).toFixed(2)}
                            {lineInternalQtyM(l.ordered_qty, l) != null && (
                              <span className="text-xs text-gray-500 block">→ {lineInternalQtyM(l.ordered_qty, l)!.toFixed(2)} m</span>
                            )}
                          </td>
                          <td className="px-4 py-2 text-right tabular-nums">{Number(l.received_qty).toFixed(2)}</td>
                          <td className="px-4 py-2 text-right tabular-nums font-medium">
                            {remaining.toFixed(2)}
                            {lineInternalQtyM(remaining, l) != null && (
                              <span className="text-xs text-gray-500 block">→ {lineInternalQtyM(remaining, l)!.toFixed(2)} m</span>
                            )}
                          </td>
                          <td className="px-4 py-2">
                            <Input
                              type="number"
                              min={0}
                              max={remaining}
                              step="0.01"
                              value={receiveQtyMap[l.id] ?? remaining}
                              onChange={e => setReceiveQty(l.id, Math.min(remaining, parseFloat(e.target.value) || 0))}
                              className="w-24 text-right"
                            />
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              {lines.filter(l => ((l.ordered_qty ?? 0) - (l.received_qty ?? 0)) > 0).length === 0 && (
                <p className="text-sm text-gray-500 py-4">All lines are fully received.</p>
              )}
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowReceiveModal(false)}
                  className="px-4 py-2 text-sm font-medium text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleConfirmReceive}
                  disabled={isReceiving}
                  className="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
                >
                  {isReceiving ? 'Receiving...' : 'Confirm Receive'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
