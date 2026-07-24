import { useState, useEffect, useMemo, useCallback } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual } from '../../lib/navigation/returnTo';
import { useUIStore } from '../../stores/ui-store';
import CutPlanVisualizer from '../../components/manufacturing/CutPlanVisualizer';
import RollCutVisualizer from '../../components/manufacturing/RollCutVisualizer';
import FabricSpecsCard from '../../components/manufacturing/FabricSpecsCard';
import PanelCutDetail from '../../components/manufacturing/PanelCutDetail';
import { advanceMOOnAllTasksComplete } from '../../lib/moLifecycle';
import { optimize1D, type CutPiece } from '../../lib/cutOptimizer';
import { optimize2D, type FabricPiece, type PlacedFabricPiece } from '../../lib/cutOptimizer2D';
import { generateConsolidated1DPDF, generateCutPlanPDF, type ConsolidatedCutGroup } from '../../lib/pdf/generateCutPlanPDF';
import { generateThermalCutStickersPDF, type ThermalCutLabel } from '../../lib/pdf/thermalCutStickerPdf';
import { Scissors, Layers, RefreshCw, Loader2, ChevronDown, ChevronRight, Printer, CheckCircle2, Circle, ArrowLeft, FileDown } from 'lucide-react';
import StatusTabs from '../../components/shared/StatusTabs';

type Mode = 'profiles' | 'fabric';
type CutStatusFilter = 'pending' | 'completed' | 'all';

interface PendingCut {
  wotl_id: string;
  bil_id: string;
  sku: string;
  item_name: string;
  cut_length_mm: number | null;
  cut_height_mm: number | null;
  qty: number;
  mo_id: string;
  mo_number: string;
  sales_order_line_id: string | null;
  line_label: string | null;
  so_number: string | null;
  so_id: string | null;
  dealer_name: string | null;
  part_role: string;
  stock_length_mm: number | null;
  roll_width_m: number | null;
  roll_length_value: number | null;
  roll_length_uom: string | null;
  product_type: string | null;
  product_name: string | null;
  style_label: string | null;
  product_width_m: number | null;
  product_height_m: number | null;
  completed: boolean;
}

interface FabricSpec {
  product_type: string;
  display_name: string;
  top_allowance_mm: number;
  bottom_allowance_mm: number;
  side_allowance_mm: number;
  hem_bar_pocket_mm: number;
  safety_margin_mm: number;
  additional_materials: Array<{ name: string; qty: number; uom: string }>;
  notes: string | null;
}

interface FabricRuleInfo {
  product_type_code: string;
  allow_rotation: boolean;
  heatseal_price_per_m: number;
  heatseal_direction: 'horizontal' | 'vertical' | 'none';
  tube_wrap_mm: number;
  bottom_wrap_mm: number;
  safety_margin_mm: number;
  top_hem_cm: number;
  bottom_hem_cm: number;
  side_hem_cm: number;
  fullness_factor: number;
  panel_multiplier: number;
  waste_pct: number;
  bottom_bar_wrap_pct: number;
}

interface SkuGroup {
  sku: string;
  itemName: string;
  cuts: PendingCut[];
  moNumbers: string[];
  stockLengthMm: number;
  rollWidthMm: number;
  rollLengthMm: number;
  canRotate: boolean;
  canHeatseal: boolean;
}

function formatMoLineRef(cut: Pick<PendingCut, 'mo_number' | 'line_label'>): string {
  return cut.line_label ? `${cut.mo_number} · ${cut.line_label}` : cut.mo_number;
}

function skuAnchorId(sku: string): string {
  return `cut-sku-${encodeURIComponent(sku)}`;
}

// Stable empty reference so effects/memos don't re-run while the query has no data yet.
const EMPTY_CUTS: PendingCut[] = [];

export default function CutOptimization() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { role } = useCurrentOrgRole();
  const isOperator = role === 'operator' || role === 'operator_member';
  const currentUserId = user?.id ?? null;
  const [mode, setMode] = useState<Mode>('profiles');
  const [cutStatus, setCutStatus] = useState<CutStatusFilter>('pending');
  const [markingReady, setMarkingReady] = useState<string | null>(null);
  const [fabricSpecs, setFabricSpecs] = useState<FabricSpec[]>([]);
  const [fabricRules, setFabricRules] = useState<FabricRuleInfo[]>([]);
  const [selectedSkus, setSelectedSkus] = useState<Set<string>>(new Set());
  const [excludedMOs, setExcludedMOs] = useState<Set<string>>(new Set());
  const [expandedSkuMOs, setExpandedSkuMOs] = useState<Set<string>>(new Set());
  const [expandedSpec, setExpandedSpec] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const [selectedFabricPiece, setSelectedFabricPiece] = useState<{ piece: PlacedFabricPiece; skuGroup: SkuGroup } | null>(null);
  const [selectedPieceMaterials, setSelectedPieceMaterials] = useState<Array<{ sku: string; item_name: string; component_role: string; qty: number; uom: string }>>([]);
  const [materialsLoading, setMaterialsLoading] = useState(false);
  const [confirmCut, setConfirmCut] = useState<{ sku: string; markCompleted: boolean } | null>(null);
  const [confirmAllCut, setConfirmAllCut] = useState(false);
  const [markingAll, setMarkingAll] = useState(false);
  const [focusedSku, setFocusedSku] = useState<string | null>(null);
  const addNotification = useUIStore((s) => s.addNotification);
  const returnToWo = getReturnToFromCurrentQuery();
  const backToWoDetail = !!returnToWo?.match(
    /^\/manufacturing\/(work-orders|manufacturing-orders)\/[^/]+/,
  );

  const handleBack = useCallback(() => {
    navigateBackContextual(router, {
      queryReturnTo: getReturnToFromCurrentQuery(),
      fallback: '/manufacturing/workstations',
    });
  }, []);

  useEffect(() => {
    const qp = new URLSearchParams(window.location.search);
    const requestedMode = qp.get('mode');
    if (requestedMode === 'profiles' || requestedMode === 'fabric') {
      setMode(requestedMode);
    }
  }, []);

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  const fetchPendingCuts = useCallback(async (): Promise<{ cuts: PendingCut[]; ineligibleCount: number }> => {
    if (!activeOrganizationId) return { cuts: [], ineligibleCount: 0 };
    {
      const stationCode = mode === 'profiles' ? 'CUT-PROFILE' : 'CUT-ROLL';

      // Only surface work that has actually been STARTED at the station. A task
      // still 'pending' (no Start / Start All pressed) must NOT appear here —
      // otherwise every MO in production would flood Cut Optimization. Completed
      // tasks stay so their cuts remain visible in the Completed/All tabs.
      let taskQuery = supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, work_center_id, status, assigned_to_user_id, planned_start_at, sales_order_line_id')
        .eq('deleted', false)
        .in('status', ['in_progress', 'completed']);

      if (isOperator && currentUserId) {
        taskQuery = taskQuery.eq('assigned_to_user_id', currentUserId);
      }

      const { data: tasks } = await taskQuery;

      if (!tasks || tasks.length === 0) return { cuts: [], ineligibleCount: 0 };

      const { data: wcs } = await supabase
        .from('WorkCenters')
        .select('id')
        .eq('code', stationCode)
        .eq('deleted', false);

      const wcIds = new Set((wcs ?? []).map((w: any) => w.id));
      const matchedTasks = tasks.filter((t: any) => wcIds.has(t.work_center_id));
      if (matchedTasks.length === 0) return { cuts: [], ineligibleCount: 0 };

      const taskIds = matchedTasks.map((t: any) => t.id);
      const moIds = [...new Set(matchedTasks.map((t: any) => t.manufacturing_order_id))];

      // Build stable WOL labels (L1/L2/...) per MO based on MOL creation order
      const lineIndexByMoSol: Record<string, number> = {};
      if (moIds.length > 0) {
        const { data: molRows } = await supabase
          .from('ManufacturingOrderLines')
          .select('manufacturing_order_id, sales_order_line_id, created_at')
          .in('manufacturing_order_id', moIds)
          .eq('deleted', false)
          .order('manufacturing_order_id', { ascending: true })
          .order('created_at', { ascending: true });
        const seenByMo: Record<string, Set<string>> = {};
        const idxByMo: Record<string, number> = {};
        for (const r of (molRows ?? [])) {
          const moId = (r as any).manufacturing_order_id as string;
          const solId = (r as any).sales_order_line_id as string | null;
          if (!solId) continue;
          if (!seenByMo[moId]) { seenByMo[moId] = new Set<string>(); idxByMo[moId] = 0; }
          if (seenByMo[moId].has(solId)) continue;
          seenByMo[moId].add(solId);
          idxByMo[moId] += 1;
          lineIndexByMoSol[`${moId}::${solId}`] = idxByMo[moId];
        }
      }

      const [{ data: lines }, { data: mos }] = await Promise.all([
        supabase
          .from('WorkOrderTaskLines')
          .select('id, task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm, completed')
          .in('task_id', taskIds),
        supabase
          .from('ManufacturingOrders')
          .select('id, manufacturing_order_no, status, sales_order_id')
          .in('id', moIds)
          .not('status', 'in', '("draft","cancelled","delivered","completed")'),
      ]);

      const moMap: Record<string, string> = {};
      const moToSoId: Record<string, string | null> = {};
      (mos ?? []).forEach((m: any) => {
        moMap[m.id] = m.manufacturing_order_no;
        moToSoId[m.id] = m.sales_order_id ?? null;
      });

      const soIds = [...new Set((mos ?? []).map((m: any) => m.sales_order_id).filter(Boolean))];
      const { data: soRows } = soIds.length > 0
        ? await supabase.from('SalesOrders').select('id, sales_order_no, dealer_id').in('id', soIds)
        : { data: [] };
      const soMap: Record<string, string> = {};
      const soDealerIdMap: Record<string, string | null> = {};
      (soRows ?? []).forEach((so: any) => {
        soMap[so.id] = so.sales_order_no ?? null;
        soDealerIdMap[so.id] = so.dealer_id ?? null;
      });
      const dealerIds = [...new Set((soRows ?? []).map((so: any) => so.dealer_id).filter(Boolean))];
      const { data: dealerRows } = dealerIds.length > 0
        ? await supabase.from('Dealers').select('id, dealer_name').in('id', dealerIds)
        : { data: [] };
      const dealerMap: Record<string, string | null> = {};
      (dealerRows ?? []).forEach((d: any) => {
        dealerMap[d.id] = d.dealer_name ?? null;
      });

      // Keep every STARTED/COMPLETED cut-station task whose MO is still live.
      // Do NOT require MO.status === 'in_production': Start can succeed while
      // material gates keep the MO at materials_ready (or similar). Those cuts
      // must still appear in Cut Optimization — the queue source of truth is
      // the WorkOrderTask status at CUT-PROFILE / CUT-ROLL.
      const liveMoIds = new Set((mos ?? []).map((m: any) => m.id as string));
      const taskToMo: Record<string, string> = {};
      const taskToSol: Record<string, string | null> = {};
      const taskToLineLabel: Record<string, string | null> = {};
      matchedTasks.forEach((t: any) => {
        if (!liveMoIds.has(t.manufacturing_order_id)) return;
        taskToMo[t.id] = t.manufacturing_order_id;
        taskToSol[t.id] = t.sales_order_line_id ?? null;
        const idx = t.sales_order_line_id ? lineIndexByMoSol[`${t.manufacturing_order_id}::${t.sales_order_line_id}`] : null;
        taskToLineLabel[t.id] = idx ? `L${idx}` : null;
      });

      const catalogIds = [...new Set((lines ?? []).map((l: any) => l.catalog_item_id).filter(Boolean))];
      const { data: catalogItems } = catalogIds.length > 0
        ? await supabase.from('CatalogItems').select('id, stock_length_mm, roll_width_m, roll_length_value, roll_length_uom').in('id', catalogIds)
        : { data: [] };

      const catMap: Record<string, any> = {};
      (catalogItems ?? []).forEach((ci: any) => { catMap[ci.id] = ci; });

      // Fetch product_type + product dimensions + style via BIL -> BI -> SOL -> CP
      const bilMetaMap: Record<string, { product_type: string | null; product_name: string | null; style_label: string | null; width_m: number | null; height_m: number | null }> = {};
      const bilIds = [...new Set((lines ?? []).map((l: any) => l.bom_instance_line_id).filter(Boolean))] as string[];
      if (bilIds.length > 0) {
        const { data: bilRows } = await supabase
          .from('BOMInstanceLines')
          .select('id, bom_instance_id')
          .in('id', bilIds);

        const biMap: Record<string, string> = {};
        (bilRows ?? []).forEach((r: any) => { biMap[r.id] = r.bom_instance_id; });

        const biIds = [...new Set(Object.values(biMap))];
        const { data: biRows } = await supabase
          .from('BOMInstances')
          .select('id, sales_order_line_id')
          .in('id', biIds);

        const biSolMap: Record<string, string> = {};
        (biRows ?? []).forEach((r: any) => { if (r.sales_order_line_id) biSolMap[r.id] = r.sales_order_line_id; });

        const solIds = [...new Set(Object.values(biSolMap))];
        const { data: solRows } = solIds.length > 0
          ? await supabase.from('SaleOrderLines').select('id, product_type, width_m, height_m, collection_name, description, configured_product_id').in('id', solIds)
          : { data: [] };

        const solMap: Record<string, any> = {};
        (solRows ?? []).forEach((r: any) => { solMap[r.id] = r; });

        // Fetch style_code from ConfiguredProducts.config_snapshot
        const cpIds = [...new Set((solRows ?? []).map((r: any) => r.configured_product_id).filter(Boolean))] as string[];
        const cpStyleMap: Record<string, string> = {};
        if (cpIds.length > 0) {
          const { data: cpRows } = await supabase
            .from('ConfiguredProducts')
            .select('id, config_snapshot')
            .in('id', cpIds);
          (cpRows ?? []).forEach((cp: any) => {
            const snap = cp.config_snapshot;
            if (snap) {
              const code = snap.style_code || snap.styleCode;
              if (code) {
                const label = code.replace(/_/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase());
                cpStyleMap[cp.id] = label;
              }
            }
          });
        }

        bilIds.forEach(bilId => {
          const biId = biMap[bilId];
          const solId = biId ? biSolMap[biId] : null;
          const sol = solId ? solMap[solId] : null;
          const cpId = sol?.configured_product_id;
          bilMetaMap[bilId] = {
            product_type: sol?.product_type ?? null,
            product_name: sol?.collection_name || sol?.description || null,
            style_label: cpId ? (cpStyleMap[cpId] ?? null) : null,
            width_m: sol?.width_m != null ? Number(sol.width_m) : null,
            height_m: sol?.height_m != null ? Number(sol.height_m) : null,
          };
        });
      }

      const isLineEligibleForMode = (l: any): boolean => {
        const role = (l.component_role ?? '').toString().toLowerCase();
        const cutLength = l.cut_length_mm != null ? Number(l.cut_length_mm) : null;
        const cutHeight = l.cut_width_mm != null ? Number(l.cut_width_mm) : null;

        if (mode === 'fabric') {
          // Cut Optimization (fabric) is the roll-cut order: only fabric panels with full 2D cuts.
          return role === 'fabric'
            && cutLength != null && cutLength > 0
            && cutHeight != null && cutHeight > 0;
        }

        // Cut Optimization (profiles) is 1D profile cutting: exclude fabric and require a valid linear cut.
        return role !== 'fabric'
          && cutLength != null && cutLength > 0;
      };

      const modeEligibleLines = (lines ?? []).filter((l: any) => isLineEligibleForMode(l));
      const cuts: PendingCut[] = modeEligibleLines
        .filter((l: any) => Boolean(taskToMo[l.task_id]))
        .map((l: any) => {
        const moId = taskToMo[l.task_id];
        const ci = l.catalog_item_id ? catMap[l.catalog_item_id] : null;
        const bilMeta = l.bom_instance_line_id ? bilMetaMap[l.bom_instance_line_id] : null;
        return {
          wotl_id: l.id,
          bil_id: l.bom_instance_line_id ?? l.id,
          sku: l.sku ?? '',
          item_name: l.item_name ?? '',
          cut_length_mm: l.cut_length_mm != null ? Number(l.cut_length_mm) : null,
          cut_height_mm: l.cut_width_mm != null ? Number(l.cut_width_mm) : null,
          qty: Number(l.qty),
          mo_id: moId,
          mo_number: moMap[moId] ?? '',
          sales_order_line_id: taskToSol[l.task_id] ?? null,
          line_label: taskToLineLabel[l.task_id] ?? null,
          so_number: moToSoId[moId] ? soMap[moToSoId[moId] as string] ?? null : null,
          so_id: moToSoId[moId] ?? null,
          dealer_name: moToSoId[moId] ? dealerMap[soDealerIdMap[moToSoId[moId] as string] ?? ''] ?? null : null,
          part_role: l.component_role ?? '',
          stock_length_mm: ci?.stock_length_mm != null ? Number(ci.stock_length_mm) : null,
          roll_width_m: ci?.roll_width_m != null ? Number(ci.roll_width_m) : null,
          roll_length_value: ci?.roll_length_value != null ? Number(ci.roll_length_value) : null,
          roll_length_uom: ci?.roll_length_uom ?? null,
          product_type: bilMeta?.product_type ?? null,
          product_name: bilMeta?.product_name ?? null,
          style_label: bilMeta?.style_label ?? null,
          product_width_m: bilMeta?.width_m ?? null,
          product_height_m: bilMeta?.height_m ?? null,
          completed: l.completed === true,
        };
      });

      return { cuts, ineligibleCount: Math.max(0, modeEligibleLines.length - cuts.length) };
    }
  }, [activeOrganizationId, mode, isOperator, currentUserId]);

  const cutsQueryKey = useMemo(
    () => ['cut-pending', activeOrganizationId, mode, isOperator, currentUserId] as const,
    [activeOrganizationId, mode, isOperator, currentUserId],
  );

  const {
    data: cutData,
    isLoading: loading,
    refetch: refetchCutsQuery,
  } = useQuery({
    queryKey: cutsQueryKey,
    queryFn: fetchPendingCuts,
    enabled: !!activeOrganizationId,
  });

  const pendingCuts = cutData?.cuts ?? EMPTY_CUTS;
  const ineligibleCutCount = cutData?.ineligibleCount ?? 0;

  const refetchCuts = useCallback(async () => {
    await refetchCutsQuery();
  }, [refetchCutsQuery]);

  // Reset SKU selection whenever a fresh set of cuts arrives (mount / mode change / refetch).
  useEffect(() => {
    setSelectedSkus(new Set(pendingCuts.map(c => c.sku)));
  }, [cutData]); // eslint-disable-line react-hooks/exhaustive-deps

  // Fetch FabricRules for rotation/heatseal info
  useEffect(() => {
    if (!activeOrganizationId) return;
    (async () => {
      const [{ data: frData }, { data: ptData }] = await Promise.all([
        supabase
          .from('FabricRules')
          .select('product_type_id, allow_rotation, heatseal_price_per_m, heatseal_direction, tube_wrap_mm, bottom_wrap_mm, safety_margin_mm, top_hem_cm, bottom_hem_cm, side_hem_cm, fullness_factor, panel_multiplier, waste_pct, bottom_bar_wrap_pct')
          .eq('is_active', true),
        supabase
          .from('ProductTypes')
          .select('id, code'),
      ]);
      if (!frData || !ptData) return;
      const ptMap: Record<string, string> = {};
      ptData.forEach((pt: any) => { ptMap[pt.id] = pt.code; });

      const rules: FabricRuleInfo[] = frData.map((r: any) => ({
        product_type_code: ptMap[r.product_type_id] ?? '',
        allow_rotation: r.allow_rotation ?? true,
        heatseal_price_per_m: Number(r.heatseal_price_per_m ?? 0),
        heatseal_direction: (r.heatseal_direction as FabricRuleInfo['heatseal_direction']) ?? 'none',
        tube_wrap_mm: Number(r.tube_wrap_mm ?? 0),
        bottom_wrap_mm: Number(r.bottom_wrap_mm ?? 0),
        safety_margin_mm: Number(r.safety_margin_mm ?? 0),
        top_hem_cm: Number(r.top_hem_cm ?? 0),
        bottom_hem_cm: Number(r.bottom_hem_cm ?? 0),
        side_hem_cm: Number(r.side_hem_cm ?? 0),
        fullness_factor: Number(r.fullness_factor ?? 1),
        panel_multiplier: Number(r.panel_multiplier ?? 1),
        waste_pct: Number(r.waste_pct ?? 0),
        bottom_bar_wrap_pct: Number(r.bottom_bar_wrap_pct ?? 0),
      }));
      setFabricRules(rules);
    })();
  }, [activeOrganizationId]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    supabase
      .from('FabricConstructionSpecs')
      .select('*')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .order('sort_order')
      .then(({ data }: { data: FabricSpec[] | null }) => {
        if (data) setFabricSpecs(data);
      });
  }, [activeOrganizationId]);

  // Build a lookup: product_type code → FabricRuleInfo
  const fabricRuleMap = useMemo(() => {
    const map: Record<string, FabricRuleInfo> = {};
    fabricRules.forEach(r => { map[r.product_type_code] = r; });
    return map;
  }, [fabricRules]);

  // Fetch children of the fabric component for the selected piece (consumables for sewing)
  useEffect(() => {
    if (!selectedFabricPiece) { setSelectedPieceMaterials([]); return; }
    const p = selectedFabricPiece.piece;
    const bilId = p.id.replace(/-d\d+$/, '');
    const cut = selectedFabricPiece.skuGroup.cuts.find(c => c.bil_id === bilId);
    if (!cut) { setSelectedPieceMaterials([]); return; }

    let cancelled = false;
    setMaterialsLoading(true);
    (async () => {
      // 1. Get the fabric BOMInstanceLine to find its bom_component_id and bom_instance_id
      const { data: fabricBil } = await supabase
        .from('BOMInstanceLines')
        .select('id, bom_component_id, bom_instance_id')
        .eq('id', cut.bil_id)
        .single();

      if (cancelled || !fabricBil?.bom_component_id) { setMaterialsLoading(false); return; }

      // 2. Find BOMComponents that are children of the fabric component
      const { data: childComponents } = await supabase
        .from('BOMComponents')
        .select('id')
        .eq('parent_component_id', fabricBil.bom_component_id)
        .eq('deleted', false);

      if (cancelled || !childComponents || childComponents.length === 0) {
        setSelectedPieceMaterials([]);
        setMaterialsLoading(false);
        return;
      }

      // 3. Find BOMInstanceLines that reference those child components
      const childCompIds = childComponents.map((c: any) => c.id);
      const { data: childLines } = await supabase
        .from('BOMInstanceLines')
        .select('resolved_part_id, part_role, qty, uom')
        .eq('bom_instance_id', fabricBil.bom_instance_id)
        .in('bom_component_id', childCompIds)
        .eq('deleted', false);

      if (cancelled) return;

      if (!childLines || childLines.length === 0) {
        setSelectedPieceMaterials([]);
        setMaterialsLoading(false);
        return;
      }

      // 4. Fetch catalog info for the resolved parts
      const partIds = [...new Set(childLines.map((l: any) => l.resolved_part_id).filter(Boolean))];
      let catMap: Record<string, { sku: string; name: string }> = {};
      if (partIds.length > 0) {
        const { data: catItems } = await supabase
          .from('CatalogItems')
          .select('id, sku, name')
          .in('id', partIds);
        (catItems ?? []).forEach((ci: any) => { catMap[ci.id] = { sku: ci.sku, name: ci.name }; });
      }

      if (!cancelled) {
        setSelectedPieceMaterials(
          childLines.map((l: any) => {
            const cat = l.resolved_part_id ? catMap[l.resolved_part_id] : null;
            return {
              sku: cat?.sku ?? '',
              item_name: cat?.name ?? '',
              component_role: l.part_role ?? '',
              qty: Number(l.qty),
              uom: l.uom ?? 'ea',
            };
          }),
        );
        setMaterialsLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [selectedFabricPiece]);

  // Filter cuts by status tab
  const statusFilteredCuts = useMemo(() => {
    if (cutStatus === 'all') return pendingCuts;
    if (cutStatus === 'completed') return pendingCuts.filter(c => c.completed);
    return pendingCuts.filter(c => !c.completed);
  }, [pendingCuts, cutStatus]);

  const pendingCount = useMemo(() => pendingCuts.filter(c => !c.completed).length, [pendingCuts]);
  const completedCount = useMemo(() => pendingCuts.filter(c => c.completed).length, [pendingCuts]);

  const requestMarkCut = useCallback(async (sku: string, markCompleted: boolean) => {
    if (!markCompleted) {
      // Undo: no gate needed
      setConfirmCut({ sku, markCompleted });
      return;
    }

    const groupCuts = pendingCuts.filter(c => c.sku === sku);
    const wotlIds = groupCuts.map(c => c.wotl_id);
    if (wotlIds.length === 0) return;

    // Validate: all parent tasks must be in_progress and their MO in in_production
    const { data: taskRows } = await supabase
      .from('WorkOrderTaskLines')
      .select('task_id')
      .in('id', wotlIds);
    const taskIds = [...new Set((taskRows ?? []).map((r: any) => r.task_id))];

    if (taskIds.length > 0) {
      const { data: tasks } = await supabase
        .from('WorkOrderTasks')
        .select('id, status, assigned_to_user_id, assigned_to, manufacturing_order_id')
        .in('id', taskIds);

      const notStarted = (tasks ?? []).filter((t: any) => t.status === 'pending');
      const moIds = [...new Set((tasks ?? []).map((t: any) => t.manufacturing_order_id).filter(Boolean))];
      let moDraftCount = 0;
      if (moIds.length > 0) {
        const { data: mos } = await supabase
          .from('ManufacturingOrders')
          .select('id, status')
          .in('id', moIds);
        moDraftCount = (mos ?? []).filter((m: any) => m.status !== 'in_production').length;
      }

      // Operator is optional and no longer blocks marking as cut.
      if (moDraftCount > 0) {
        addNotification({
          type: 'warning',
          title: 'MO Not In Production',
          message: 'This Work Order is still draft/planned. Move the MO to In Production before marking materials as cut.',
        });
        return;
      }
      // Auto-start any pending cut tasks instead of blocking: cutting implies the
      // task is underway, so we move it to in_progress transparently.
      if (notStarted.length > 0) {
        const now = new Date().toISOString();
        await supabase
          .from('WorkOrderTasks')
          .update({ status: 'in_progress', started_at: now, updated_at: now })
          .in('id', notStarted.map((t: any) => t.id));
      }
    }

    setConfirmCut({ sku, markCompleted });
  }, [pendingCuts, addNotification]);

  // A cutting/pick task is "done" for downstream (Assembly) readiness once ALL
  // its lines are completed. Cutting in this screen only flips line flags, so we
  // reconcile the parent task status here: complete it when fully cut, and
  // re-open it (in_progress) if a line is later un-cut.
  const syncTaskCompletionForLines = useCallback(async (wotlIds: string[]) => {
    if (wotlIds.length === 0) return;
    const { data: taskRows } = await supabase
      .from('WorkOrderTaskLines')
      .select('task_id')
      .in('id', wotlIds);
    const taskIds = [...new Set((taskRows ?? []).map((r: any) => r.task_id).filter(Boolean))] as string[];
    if (taskIds.length === 0) return;

    const [{ data: allLines }, { data: tasks }] = await Promise.all([
      supabase.from('WorkOrderTaskLines').select('task_id, completed').in('task_id', taskIds),
      supabase.from('WorkOrderTasks').select('id, status, manufacturing_order_id').in('id', taskIds),
    ]);

    const agg = new Map<string, { total: number; done: number }>();
    for (const l of allLines ?? []) {
      const tid = (l as any).task_id as string;
      const e = agg.get(tid) ?? { total: 0, done: 0 };
      e.total += 1;
      if ((l as any).completed) e.done += 1;
      agg.set(tid, e);
    }
    const statusById = new Map<string, string>((tasks ?? []).map((t: any) => [t.id, t.status]));
    const moByTask = new Map<string, string>((tasks ?? []).map((t: any) => [t.id, t.manufacturing_order_id]));
    const now = new Date().toISOString();
    const toComplete: string[] = [];
    const toReopen: string[] = [];
    for (const [tid, v] of agg) {
      const allDone = v.total > 0 && v.done === v.total;
      const st = statusById.get(tid);
      if (allDone && st !== 'completed') toComplete.push(tid);
      else if (!allDone && st === 'completed') toReopen.push(tid);
    }
    if (toComplete.length > 0) {
      await supabase.from('WorkOrderTasks')
        .update({ status: 'completed', completed_at: now, updated_at: now })
        .in('id', toComplete);
    }
    if (toReopen.length > 0) {
      await supabase.from('WorkOrderTasks')
        .update({ status: 'in_progress', completed_at: null, updated_at: now })
        .in('id', toReopen);
    }

    // If completing these cut tasks finishes ALL of an MO's tasks, advance it to QC.
    if (toComplete.length > 0) {
      const affectedMoIds = [...new Set(toComplete.map((tid) => moByTask.get(tid)).filter(Boolean))] as string[];
      for (const moId of affectedMoIds) {
        const { data: moTasks } = await supabase
          .from('WorkOrderTasks')
          .select('status')
          .eq('manufacturing_order_id', moId)
          .eq('deleted', false);
        const allDone = (moTasks ?? []).length > 0 && (moTasks ?? []).every((t: any) => t.status === 'completed');
        if (allDone) {
          await advanceMOOnAllTasksComplete(moId);
        }
      }
    }
  }, []);

  const executeMarkCut = useCallback(async () => {
    if (!confirmCut) return;
    const { sku, markCompleted } = confirmCut;
    setConfirmCut(null);

    const groupCuts = pendingCuts.filter(c => c.sku === sku);
    const allWotlIds = groupCuts.map(c => c.wotl_id);
    if (allWotlIds.length === 0) return;

    const wotlIdsToUpdate = groupCuts
      .filter(c => Boolean(c.completed) !== markCompleted)
      .map(c => c.wotl_id);

    if (wotlIdsToUpdate.length === 0) {
      queryClient.setQueryData<{ cuts: PendingCut[]; ineligibleCount: number }>(cutsQueryKey, (old) =>
        old ? { ...old, cuts: old.cuts.map(c => (c.sku === sku ? { ...c, completed: markCompleted } : c)) } : old,
      );
      return;
    }

    setMarkingReady(sku);
    try {
      const { error } = await supabase
        .from('WorkOrderTaskLines')
        .update({ completed: markCompleted, completed_at: markCompleted ? new Date().toISOString() : null })
        .in('id', wotlIdsToUpdate);

      if (error) {
        addNotification({ type: 'error', title: 'Update Failed', message: error.message });
        return;
      }

      // Complete/reopen the parent task so Assembly readiness reflects it.
      await syncTaskCompletionForLines(wotlIdsToUpdate);

      queryClient.setQueryData<{ cuts: PendingCut[]; ineligibleCount: number }>(cutsQueryKey, (old) =>
        old ? { ...old, cuts: old.cuts.map(c => (c.sku === sku ? { ...c, completed: markCompleted } : c)) } : old,
      );

      // Keep the Workstation view in sync: its part counts and (auto-started)
      // task statuses depend on these same WorkOrderTaskLines. removeQueries (not
      // invalidate) is required because refetchOnMount is disabled globally, so a
      // merely-stale cache would not refetch when Workstation is next opened.
      queryClient.removeQueries({ queryKey: ['workstation-tasks'] });

      addNotification({
        type: 'success',
        title: markCompleted ? 'Marked as Cut' : 'Reverted',
        message: `${sku}: ${wotlIdsToUpdate.length} line(s) ${markCompleted ? 'marked as cut' : 'reverted to pending'}.`,
      });
    } finally {
      setMarkingReady(null);
    }
  }, [confirmCut, pendingCuts, addNotification, queryClient, cutsQueryKey, syncTaskCompletionForLines]);

  // All SKU groups (unfiltered) for the sidebar
  const allSkuGroups: SkuGroup[] = useMemo(() => {
    const map = new Map<string, PendingCut[]>();
    statusFilteredCuts.forEach(c => {
      if (!map.has(c.sku)) map.set(c.sku, []);
      map.get(c.sku)!.push(c);
    });
    return Array.from(map.entries())
      .sort((a, b) => b[1].length - a[1].length)
      .map(([sku, cuts]) => {
        const first = cuts[0];
        let rollLengthMm = 27400;
        if (first.roll_length_value && first.roll_length_uom) {
          const v = first.roll_length_value;
          if (first.roll_length_uom === 'yd') rollLengthMm = v * 914.4;
          else if (first.roll_length_uom === 'm') rollLengthMm = v * 1000;
          else if (first.roll_length_uom === 'ft') rollLengthMm = v * 304.8;
        }

        // Determine rotation/heatseal from the dominant product_type in this group
        const productTypes = new Set(cuts.map(c => c.product_type).filter(Boolean));
        let canRotate = true;
        let canHeatseal = false;

        for (const pt of productTypes) {
          const rule = fabricRuleMap[pt!];
          if (rule) {
            if (!rule.allow_rotation) canRotate = false;
            if (rule.heatseal_price_per_m > 0) canHeatseal = true;
          }
        }

        return {
          sku,
          itemName: first.item_name,
          cuts,
          moNumbers: [...new Set(cuts.map(c => c.mo_number))],
          stockLengthMm: first.stock_length_mm ?? 5800,
          rollWidthMm: (first.roll_width_m ?? 2.8) * 1000,
          rollLengthMm,
          canRotate,
          canHeatseal,
        };
      });
  }, [statusFilteredCuts, fabricRuleMap]);

  // Filtered groups: exclude deselected MOs, recalculate moNumbers/cuts
  const skuGroups: SkuGroup[] = useMemo(() => {
    if (excludedMOs.size === 0) return allSkuGroups;
    return allSkuGroups.map(g => {
      const filteredCuts = g.cuts.filter(c => !excludedMOs.has(c.mo_id));
      if (filteredCuts.length === 0) return null;
      return {
        ...g,
        cuts: filteredCuts,
        moNumbers: [...new Set(filteredCuts.map(c => c.mo_number))],
      };
    }).filter(Boolean) as SkuGroup[];
  }, [allSkuGroups, excludedMOs]);

  const selectedGroups = useMemo(
    () => skuGroups.filter(g => selectedSkus.has(g.sku)),
    [skuGroups, selectedSkus],
  );

  // Count of not-yet-cut lines across all visible SKUs (drives the "Mark All" button).
  const uncutLineCount = useMemo(
    () => skuGroups.reduce((sum, g) => sum + g.cuts.filter(c => !c.completed).length, 0),
    [skuGroups],
  );

  const executeMarkAllCut = useCallback(async () => {
    setConfirmAllCut(false);
    const allCuts = skuGroups.flatMap(g => g.cuts).filter(c => !c.completed);
    const wotlIds = [...new Set(allCuts.map(c => c.wotl_id))];
    if (wotlIds.length === 0) return;

    setMarkingAll(true);
    try {
      // Resolve parent tasks: block only if the MO is not in production; otherwise
      // auto-start any pending tasks so cutting is never blocked by "Start".
      const { data: taskRows } = await supabase
        .from('WorkOrderTaskLines')
        .select('task_id')
        .in('id', wotlIds);
      const taskIds = [...new Set((taskRows ?? []).map((r: any) => r.task_id))];

      if (taskIds.length > 0) {
        const { data: tasks } = await supabase
          .from('WorkOrderTasks')
          .select('id, status, manufacturing_order_id')
          .in('id', taskIds);

        const moIds = [...new Set((tasks ?? []).map((t: any) => t.manufacturing_order_id).filter(Boolean))];
        if (moIds.length > 0) {
          const { data: mos } = await supabase
            .from('ManufacturingOrders')
            .select('id, status')
            .in('id', moIds);
          const draft = (mos ?? []).filter((m: any) => m.status !== 'in_production');
          if (draft.length > 0) {
            addNotification({
              type: 'warning',
              title: 'MO Not In Production',
              message: 'Some Work Orders are still draft/planned. Move them to In Production before marking materials as cut.',
            });
            return;
          }
        }

        const now = new Date().toISOString();
        const notStartedIds = (tasks ?? []).filter((t: any) => t.status === 'pending').map((t: any) => t.id);
        if (notStartedIds.length > 0) {
          await supabase
            .from('WorkOrderTasks')
            .update({ status: 'in_progress', started_at: now, updated_at: now })
            .in('id', notStartedIds);
        }
      }

      const nowIso = new Date().toISOString();
      const { error } = await supabase
        .from('WorkOrderTaskLines')
        .update({ completed: true, completed_at: nowIso })
        .in('id', wotlIds);

      if (error) {
        addNotification({ type: 'error', title: 'Update Failed', message: error.message });
        return;
      }

      // Complete parent tasks that are now fully cut (Assembly readiness).
      await syncTaskCompletionForLines(wotlIds);

      queryClient.setQueryData<{ cuts: PendingCut[]; ineligibleCount: number }>(cutsQueryKey, (old) =>
        old ? { ...old, cuts: old.cuts.map(c => (wotlIds.includes(c.wotl_id) ? { ...c, completed: true } : c)) } : old,
      );

      queryClient.removeQueries({ queryKey: ['workstation-tasks'] });

      addNotification({
        type: 'success',
        title: 'All Marked as Cut',
        message: `${wotlIds.length} line(s) across ${skuGroups.length} material(s) marked as cut.`,
      });
      await refetchCuts();
    } finally {
      setMarkingAll(false);
    }
  }, [skuGroups, addNotification, queryClient, cutsQueryKey, refetchCuts, syncTaskCompletionForLines]);

  const toggleSku = (sku: string) => {
    setSelectedSkus(prev => {
      const next = new Set(prev);
      if (next.has(sku)) next.delete(sku);
      else next.add(sku);
      return next;
    });
  };

  // Re-select all SKUs when switching status tabs
  useEffect(() => {
    const filtered = cutStatus === 'all' ? pendingCuts
      : cutStatus === 'completed' ? pendingCuts.filter(c => c.completed)
      : pendingCuts.filter(c => !c.completed);
    setSelectedSkus(new Set(filtered.map(c => c.sku)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cutStatus]);

  const selectAll = () => setSelectedSkus(new Set(statusFilteredCuts.map(c => c.sku)));
  const selectNone = () => setSelectedSkus(new Set());

  const locateSkuPlan = useCallback((sku: string) => {
    // Ensure the material is visible on the right panel before scrolling.
    setSelectedSkus((prev) => {
      if (prev.has(sku)) return prev;
      const next = new Set(prev);
      next.add(sku);
      return next;
    });

    requestAnimationFrame(() => {
      const el = document.getElementById(skuAnchorId(sku));
      if (!el) {
        addNotification({
          type: 'warning',
          title: 'Plan not visible',
          message: `Enable material ${sku} to locate its cut order.`,
        });
        return;
      }
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      setFocusedSku(sku);
      window.setTimeout(() => {
        setFocusedSku((prev) => (prev === sku ? null : prev));
      }, 2200);
    });
  }, [addNotification]);

  const MO_HEX_COLORS = [
    '#60a5fa', '#34d399', '#fbbf24', '#fb7185',
    '#a78bfa', '#22d3ee', '#fb923c', '#818cf8',
  ];

  const loadLogo = useCallback(async (): Promise<{ base64?: string; w: number; h: number }> => {
    const logoPaths = ['/images/Arquiproductos.png', '/images/arquiproductos.png', '/images/Arquiproductos.jpg'];
    let logoBase64: string | undefined;
    for (const path of logoPaths) {
      try {
        const res = await fetch(path, { cache: 'no-store' });
        if (!res.ok) continue;
        const blob = await res.blob();
        logoBase64 = await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
        if (logoBase64) break;
      } catch { /* ignore */ }
    }
    let w = 100, h = 100;
    if (logoBase64) {
      const dims = await new Promise<{ w: number; h: number }>(resolve => {
        const img = new Image();
        img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
        img.onerror = () => resolve({ w: 100, h: 100 });
        img.src = logoBase64!;
      });
      w = dims.w;
      h = dims.h;
    }
    return { base64: logoBase64, w, h };
  }, []);

  const handlePrintAllProfiles = useCallback(async (groupsArg?: SkuGroup[]) => {
    const source = groupsArg ?? selectedGroups;
    const profileGroups = source.filter(g => {
      return g.cuts.some(c => c.cut_length_mm != null && c.cut_length_mm > 0);
    });
    if (profileGroups.length === 0) return;

    const logo = await loadLogo();

    const allMoIds = [...new Set(profileGroups.flatMap(g => g.cuts.map(c => c.mo_id)))];
    const globalMoHexMap: Record<string, string> = {};
    allMoIds.forEach((id, i) => { globalMoHexMap[id] = MO_HEX_COLORS[i % MO_HEX_COLORS.length]; });

    const groups: ConsolidatedCutGroup[] = profileGroups.map(g => {
      const pieces: CutPiece[] = g.cuts
        .filter(c => c.cut_length_mm != null && c.cut_length_mm > 0)
        .map(c => ({
          id: c.bil_id,
          lengthMm: c.cut_length_mm!,
          moId: c.mo_id,
          moNumber: c.mo_number,
          sku: c.sku,
          label: formatMoLineRef(c),
        }));

      return {
        sku: g.sku,
        itemName: g.itemName,
        stockLengthMm: g.stockLengthMm,
        kerfMm: 3,
        result: optimize1D(pieces, g.stockLengthMm, 3),
        moHexColorMap: globalMoHexMap,
        moNumbers: g.moNumbers,
      };
    });

    const doc = generateConsolidated1DPDF(groups, {
      logoPngBase64: logo.base64,
      logoWidthPx: logo.w,
      logoHeightPx: logo.h,
    });
    doc.save(`CutOrder-Profiles-${new Date().toISOString().slice(0, 10)}.pdf`);
  }, [selectedGroups, loadLogo]);

  const handlePrintAllFabric = useCallback(async (groupsArg?: SkuGroup[]) => {
    const source = groupsArg ?? selectedGroups;
    if (source.length === 0) return;
    const logo = await loadLogo();

    const allMoIds = [...new Set(source.flatMap(g => g.cuts.map(c => c.mo_id)))];
    const moHexMap: Record<string, string> = {};
    allMoIds.forEach((id, i) => { moHexMap[id] = MO_HEX_COLORS[i % MO_HEX_COLORS.length]; });
    const moNumberMap: Record<string, string> = {};
    source.forEach(g => g.cuts.forEach(c => { moNumberMap[c.mo_id] = c.mo_number; }));

    for (const group of source) {
      const fabricPieces: FabricPiece[] = group.cuts.flatMap(c =>
        decomposePanelIntoDrops(c, group.rollWidthMm),
      );
      if (fabricPieces.length === 0) continue;

      const result = optimize2D(fabricPieces, group.rollWidthMm, group.rollLengthMm, group.canRotate);

      const doc = generateCutPlanPDF({
        type: '2d',
        title: `${group.sku} — ${group.itemName}`,
        subtitle: `${group.cuts.length} panel(s) · Roll: ${(group.rollWidthMm / 1000).toFixed(2)}m × ${(group.rollLengthMm / 1000).toFixed(1)}m · MOs: ${group.moNumbers.join(', ')}`,
        sku: group.sku,
        moNumbers: group.moNumbers,
        rollWidthMm: group.rollWidthMm,
        rollLengthMm: group.rollLengthMm,
        result2D: result,
        moHexColorMap: moHexMap,
        logoPngBase64: logo.base64,
        logoWidthPx: logo.w,
        logoHeightPx: logo.h,
      });
      doc.save(`CutOrder-Fabric-${group.sku}-${new Date().toISOString().slice(0, 10)}.pdf`);
    }
  }, [selectedGroups, loadLogo]);

  const printThermalStickers = useCallback(async () => {
    const labels: ThermalCutLabel[] = [];
    if (mode === 'profiles') {
      selectedGroups.forEach((group) => {
        group.cuts
          .filter((c) => c.cut_length_mm != null && c.cut_length_mm > 0)
          .forEach((c) => {
            labels.push({
              soNumber: c.so_number,
              salesOrderId: c.so_id,
              moNumber: c.mo_number,
              stationCode: 'CUT-PROFILE',
              lineLabel: c.line_label,
              dealerName: c.dealer_name,
              sku: c.sku,
              itemName: c.item_name,
              cutWidthMm: c.cut_length_mm,
              cutHeightMm: null,
              curtainWidthMm: c.product_width_m != null ? c.product_width_m * 1000 : null,
              curtainHeightMm: c.product_height_m != null ? c.product_height_m * 1000 : null,
              refId: c.bil_id,
            });
          });
      });
    } else {
      selectedGroups.forEach((group) => {
        group.cuts.forEach((c) => {
          const drops = decomposePanelIntoDrops(c, group.rollWidthMm);
          if (drops.length === 0) {
            labels.push({
              soNumber: c.so_number,
              salesOrderId: c.so_id,
              moNumber: c.mo_number,
              stationCode: 'CUT-ROLL',
              lineLabel: c.line_label,
              dealerName: c.dealer_name,
              sku: c.sku,
              itemName: c.item_name,
              cutWidthMm: c.cut_length_mm,
              cutHeightMm: c.cut_height_mm,
              curtainWidthMm: c.product_width_m != null ? c.product_width_m * 1000 : null,
              curtainHeightMm: c.product_height_m != null ? c.product_height_m * 1000 : null,
              refId: c.bil_id,
            });
            return;
          }
          drops.forEach((d, idx) => {
            labels.push({
              soNumber: c.so_number,
              salesOrderId: c.so_id,
              moNumber: c.mo_number,
              stationCode: 'CUT-ROLL',
              lineLabel: c.line_label,
              dealerName: c.dealer_name,
              sku: c.sku,
              itemName: c.item_name,
              cutWidthMm: d.widthMm,
              cutHeightMm: d.heightMm,
              curtainWidthMm: c.product_width_m != null ? c.product_width_m * 1000 : null,
              curtainHeightMm: c.product_height_m != null ? c.product_height_m * 1000 : null,
              refId: `${c.bil_id}-d${idx + 1}`,
            });
          });
        });
      });
    }

    if (labels.length === 0) return;

    const doc = await generateThermalCutStickersPDF(labels);
    doc.save(`Stickers-${mode === 'profiles' ? 'Profiles' : 'Fabric'}-${new Date().toISOString().slice(0, 10)}.pdf`);
  }, [mode, selectedGroups]);

  /**
   * Decompose a fabric panel into actual drops for roll placement.
   * Each drop is a rectangle that fits within the roll's fixed width.
   *
   * - panelWidthMm (cut_length_mm) = effective width of the finished panel
   * - dropHeightMm (cut_height_mm) = the drop/height including wraps + safety
   * - rollWidthMm = fixed width of the fabric roll
   *
   * For ROLLER_DROPS: each drop uses the full roll width.
   * If panelWidth ≤ rollWidth → 1 piece at panelWidth × dropHeight
   * If panelWidth > rollWidth → primary drops at rollWidth + last drop at remainder.
   *   The last (smallest) drop is the secondary piece that goes on top (next to tube),
   *   the primary drops are full roll-width pieces.
   *   Each piece has its REAL dimensions so the optimizer can reuse leftover space.
   */
  function decomposePanelIntoDrops(
    cut: PendingCut,
    rollWidthMm: number,
  ): FabricPiece[] {
    const panelWidthMm = cut.cut_length_mm;
    const dropHeightMm = cut.cut_height_mm;

    const prodW = cut.product_width_m ? Math.round(cut.product_width_m * 1000) : null;
    const prodH = cut.product_height_m ? Math.round(cut.product_height_m * 1000) : null;

    if (!panelWidthMm || panelWidthMm <= 0 || !dropHeightMm || dropHeightMm <= 0) {
      const w = prodW ?? null;
      const h = prodH ?? null;
      if (!w || !h) return [];

      return [{
        id: `${cut.bil_id}-d1`,
        widthMm: Math.min(w, rollWidthMm),
        heightMm: h,
        moId: cut.mo_id,
        moNumber: cut.mo_number,
        label: `${cut.mo_number} · ${w}×${h}mm`,
      }];
    }

    if (panelWidthMm <= rollWidthMm) {
      return [{
        id: `${cut.bil_id}-d1`,
        widthMm: panelWidthMm,
        heightMm: dropHeightMm,
        moId: cut.mo_id,
        moNumber: cut.mo_number,
        label: `${cut.mo_number} · ${Math.round(panelWidthMm)}×${Math.round(dropHeightMm)}mm`,
      }];
    }

    const numDrops = Math.ceil(panelWidthMm / rollWidthMm);
    const remainder = panelWidthMm - (numDrops - 1) * rollWidthMm;
    const pieces: FabricPiece[] = [];

    for (let i = 0; i < numDrops; i++) {
      const isLastDrop = i === numDrops - 1;
      const dropW = isLastDrop ? remainder : rollWidthMm;
      const posLabel = isLastDrop ? 'Top (secondary)' : `Main${numDrops > 2 ? ` ${i + 1}` : ''}`;
      pieces.push({
        id: `${cut.bil_id}-d${i + 1}`,
        widthMm: dropW,
        heightMm: dropHeightMm,
        moId: cut.mo_id,
        moNumber: cut.mo_number,
        label: `${cut.mo_number} · ${posLabel} · ${Math.round(dropW)}×${Math.round(dropHeightMm)}mm`,
      });
    }
    return pieces;
  }

  return (
    <div className="py-6 px-6 space-y-6">
      <button onClick={handleBack} className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700">
        <ArrowLeft className="w-4 h-4" /> {backToWoDetail ? 'Back to Work Order' : 'Back to Work Orders'}
      </button>

      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Scissors className="w-5 h-5 text-gray-500" />
          <h1 className="text-xl font-semibold text-gray-900">Cut Optimization</h1>
        </div>
        <div className="flex items-center gap-2">
          {/* Mode toggle */}
          <div className="inline-flex rounded-lg border border-gray-300 bg-white p-0.5">
            <button
              type="button"
              onClick={() => setMode('profiles')}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
                mode === 'profiles' ? 'bg-gray-700 text-white' : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Layers className="w-3.5 h-3.5" /> Profiles (1D)
            </button>
            <button
              type="button"
              onClick={() => setMode('fabric')}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
                mode === 'fabric' ? 'bg-gray-700 text-white' : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Scissors className="w-3.5 h-3.5" /> Fabric (2D)
            </button>
          </div>

          {/* Refresh */}
          <button
            type="button"
            onClick={() => { void refetchCuts(); }}
            className="inline-flex items-center justify-center w-8 h-8 text-gray-500 hover:text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            title="Refresh"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </button>

          {/* Download all SKUs of the current cutting station in one PDF */}
          {skuGroups.length > 0 && (
            <button
              type="button"
              onClick={() => { void (mode === 'profiles' ? handlePrintAllProfiles(skuGroups) : handlePrintAllFabric(skuGroups)); }}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-500 transition-colors"
              title={mode === 'profiles'
                ? 'Download all SKUs of this station in one consolidated cut-order PDF (grouped by SKU)'
                : 'Download a cut-order PDF for every SKU of this station'}
            >
              <FileDown className="w-3.5 h-3.5" />
              All SKU PDF{mode === 'profiles' ? '' : ` (${skuGroups.length})`}
            </button>
          )}

          {/* Mark every visible cut as cut at once */}
          {uncutLineCount > 0 && (
            <button
              type="button"
              disabled={markingAll}
              onClick={() => setConfirmAllCut(true)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-60 transition-colors"
              title="Mark all pending cuts of this station as cut (auto-starts tasks)"
            >
              {markingAll ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
              Mark All Cut ({uncutLineCount})
            </button>
          )}

          {/* Thermal stickers (All SKU PDF lives in its own toolbar button) */}
          {selectedGroups.length > 0 && (
            <button
              type="button"
              onClick={() => printThermalStickers()}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-gray-700 rounded-lg hover:bg-gray-600 transition-colors"
            >
              <Printer className="w-3.5 h-3.5" /> PDF Stickers (4×1″)
            </button>
          )}
        </div>
      </div>

      <StatusTabs
        tabs={[
          { label: 'Pending', value: 'pending', count: pendingCount },
          { label: 'Completed', value: 'completed', count: completedCount },
          { label: 'All', value: 'all', count: pendingCuts.length },
        ]}
        activeTab={cutStatus}
        onChange={(v) => setCutStatus(v as CutStatusFilter)}
      />

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="w-6 h-6 animate-spin text-gray-400" />
        </div>
      ) : statusFilteredCuts.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <Scissors className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-sm text-gray-500">
            {cutStatus === 'pending' && pendingCuts.length > 0
              ? 'All cuts are marked as ready!'
              : cutStatus === 'completed'
              ? 'No completed cuts yet.'
              : `No cuts found for ${mode === 'profiles' ? 'Profile Cut' : 'Roll Cut'} stations.`}
          </p>
          {cutStatus === 'pending' && pendingCuts.length > 0 && (
            <button type="button" onClick={() => setCutStatus('completed')} className="text-xs text-primary hover:underline mt-2">
              View completed cuts
            </button>
          )}
          {pendingCuts.length === 0 && (
            <p className="text-xs text-gray-400 mt-1">Generate work orders from a Manufacturing Order first.</p>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-12 gap-6">
          {/* Left sidebar: material selection */}
          <div className="col-span-3">
            <div className="bg-white border border-gray-200 rounded-lg overflow-hidden sticky top-4">
              <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
                <h3 className="text-xs font-semibold text-gray-700 uppercase tracking-wider">Materials ({skuGroups.length})</h3>
                <div className="flex gap-2 mt-2">
                  <button type="button" onClick={selectAll} className="text-[10px] text-primary hover:underline">Select All</button>
                  <button type="button" onClick={selectNone} className="text-[10px] text-gray-400 hover:underline">None</button>
                </div>
              </div>
              <div className="max-h-[60vh] overflow-y-auto divide-y divide-gray-100">
                {allSkuGroups.map(group => {
                  const moIds = [...new Set(group.cuts.map(c => c.mo_id))];
                  const moEntryMap = new Map<string, { id: string; number: string; lineLabels: Set<string>; pieceCount: number }>();
                  group.cuts.forEach((c) => {
                    if (!moEntryMap.has(c.mo_id)) {
                      moEntryMap.set(c.mo_id, { id: c.mo_id, number: c.mo_number, lineLabels: new Set<string>(), pieceCount: 0 });
                    }
                    const entry = moEntryMap.get(c.mo_id)!;
                    if (c.line_label) entry.lineLabels.add(c.line_label);
                    entry.pieceCount += 1;
                  });
                  const moEntries = [...moEntryMap.values()].map((e) => ({
                    id: e.id,
                    number: e.number,
                    lineLabel: e.lineLabels.size > 0 ? [...e.lineLabels].sort().join(', ') : null,
                    pieceCount: e.pieceCount,
                  }));
                  const isExpanded = expandedSkuMOs.has(group.sku);
                  const activeMoCount = moEntries.filter(m => !excludedMOs.has(m.id)).length;

                  const isGroupCompleted = pendingCuts.filter(c => c.sku === group.sku).every(c => c.completed);
                  const isMarking = markingReady === group.sku;

                  return (
                    <div key={group.sku} className={isGroupCompleted && cutStatus === 'all' ? 'opacity-60' : ''}>
                      <div className={`flex items-start gap-2.5 px-4 py-2.5 hover:bg-gray-50 border-l-[3px] ${isGroupCompleted ? 'border-l-green-500 bg-green-50/30' : 'border-l-transparent'}`}>
                        <input
                          type="checkbox"
                          checked={selectedSkus.has(group.sku)}
                          onChange={() => toggleSku(group.sku)}
                          className="rounded border-gray-300 mt-0.5 cursor-pointer"
                        />
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-1.5">
                            <p className={`text-xs font-mono truncate ${isGroupCompleted ? 'text-gray-400 line-through' : 'text-gray-800'}`}>{group.sku}</p>
                            {isGroupCompleted && <CheckCircle2 className="w-3.5 h-3.5 text-green-500 flex-shrink-0" />}
                          </div>
                          <p className="text-[10px] text-gray-400 truncate">{group.itemName}</p>
                          <p className="text-[10px] text-gray-400">
                            {group.cuts.filter(c => !excludedMOs.has(c.mo_id)).length} piece{group.cuts.filter(c => !excludedMOs.has(c.mo_id)).length !== 1 ? 's' : ''} &middot; {activeMoCount}/{moEntries.length} MO{moEntries.length !== 1 ? 's' : ''}
                          </p>
                          {mode === 'fabric' && (
                            <div className="flex items-center gap-1.5 mt-0.5">
                              {group.canRotate && (
                                <span className="text-[9px] bg-blue-50 text-blue-600 px-1 py-0.5 rounded">Rotation OK</span>
                              )}
                              {group.canHeatseal && (
                                <span className="text-[9px] bg-amber-50 text-amber-600 px-1 py-0.5 rounded">Heatseal</span>
                              )}
                              {!group.canRotate && (
                                <span className="text-[9px] bg-red-50 text-red-600 px-1 py-0.5 rounded">No Rotation</span>
                              )}
                            </div>
                          )}
                          <div className="flex items-center gap-2 mt-1">
                            <button
                              type="button"
                              onClick={() => locateSkuPlan(group.sku)}
                              className="text-[10px] text-blue-700 bg-blue-50 border border-blue-200 px-2 py-0.5 rounded hover:bg-blue-100"
                            >
                              Locate
                            </button>
                            {moEntries.length > 1 && (
                              <button
                                type="button"
                                onClick={() => setExpandedSkuMOs(prev => {
                                  const next = new Set(prev);
                                  if (next.has(group.sku)) next.delete(group.sku); else next.add(group.sku);
                                  return next;
                                })}
                                className="text-[10px] text-primary hover:underline flex items-center gap-0.5"
                              >
                                {isExpanded ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
                                {isExpanded ? 'Hide MOs' : 'Filter MOs'}
                              </button>
                            )}
                            <button
                              type="button"
                              disabled={isMarking}
                              onClick={() => requestMarkCut(group.sku, !isGroupCompleted)}
                              className={`text-[10px] font-medium flex items-center gap-1 ml-auto px-2.5 py-1 rounded border transition-colors ${
                                isGroupCompleted
                                  ? 'text-green-700 bg-green-50 border-green-200 hover:bg-green-100'
                                  : 'text-gray-600 bg-gray-50 border-gray-200 hover:bg-gray-100'
                              }`}
                            >
                              {isMarking ? (
                                <Loader2 className="w-3 h-3 animate-spin" />
                              ) : isGroupCompleted ? (
                                <><CheckCircle2 className="w-3 h-3" /> Cut</>
                              ) : (
                                <><Circle className="w-3 h-3" /> Mark Cut</>
                              )}
                            </button>
                          </div>
                        </div>
                      </div>
                      {isExpanded && (
                        <div className="pl-10 pr-4 pb-2 space-y-1 bg-gray-50/50">
                          {moEntries.map(mo => (
                            <label key={mo.id} className="flex items-center gap-2 cursor-pointer group">
                              <input
                                type="checkbox"
                                checked={!excludedMOs.has(mo.id)}
                                onChange={() => setExcludedMOs(prev => {
                                  const next = new Set(prev);
                                  if (next.has(mo.id)) next.delete(mo.id); else next.add(mo.id);
                                  return next;
                                })}
                                className="rounded border-gray-300 w-3.5 h-3.5"
                              />
                              <span className="text-[10px] font-mono text-gray-600 group-hover:text-gray-900">
                                {mo.number}{mo.lineLabel ? ` · ${mo.lineLabel}` : ''}
                              </span>
                              <span className="text-[9px] text-gray-400 ml-auto">{mo.pieceCount} pc</span>
                            </label>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Right: optimization results — one card PER SKU */}
          <div className="col-span-9 space-y-6">
            {selectedGroups.length === 0 && (
              <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
                <p className="text-sm text-gray-500">Select materials to see cut optimization.</p>
              </div>
            )}

            {mode === 'profiles' && selectedGroups.map(group => {
              const pieces: CutPiece[] = group.cuts
                .filter(c => c.cut_length_mm != null && c.cut_length_mm > 0)
                .map(c => ({
                  id: c.bil_id,
                  lengthMm: c.cut_length_mm!,
                  moId: c.mo_id,
                  moNumber: c.mo_number,
                  sku: c.sku,
                  label: formatMoLineRef(c),
                }));
              if (pieces.length === 0) return null;
              return (
                <div
                  id={skuAnchorId(group.sku)}
                  key={group.sku}
                  className={`rounded-lg transition-all ${focusedSku === group.sku ? 'ring-2 ring-blue-400 ring-offset-2' : ''}`}
                >
                  <CutPlanVisualizer
                    pieces={pieces}
                    stockLengthMm={group.stockLengthMm}
                    title={`${group.sku} — ${group.itemName}`}
                    subtitle={`${pieces.length} pieces · MOs: ${group.moNumbers.join(', ')}`}
                    onPrintStickers={async () => {
                      const labels: ThermalCutLabel[] = group.cuts
                        .filter(c => c.cut_length_mm != null && c.cut_length_mm > 0)
                        .map(c => ({
                          soNumber: c.so_number,
                          salesOrderId: c.so_id,
                          moNumber: c.mo_number,
                          stationCode: 'CUT-PROFILE' as const,
                          lineLabel: c.line_label,
                          dealerName: c.dealer_name,
                          sku: c.sku,
                          itemName: c.item_name,
                          cutWidthMm: c.cut_length_mm,
                          cutHeightMm: null,
                          curtainWidthMm: c.product_width_m != null ? c.product_width_m * 1000 : null,
                          curtainHeightMm: c.product_height_m != null ? c.product_height_m * 1000 : null,
                          refId: c.bil_id,
                        }));
                      if (labels.length === 0) return;
                      const doc = await generateThermalCutStickersPDF(labels);
                      doc.save(`Stickers-${group.sku}-${new Date().toISOString().slice(0, 10)}.pdf`);
                    }}
                  />
                </div>
              );
            })}

            {mode === 'fabric' && selectedGroups.map(group => {
              const fabricPieces: FabricPiece[] = group.cuts.flatMap(c =>
                decomposePanelIntoDrops(c, group.rollWidthMm),
              );
              if (fabricPieces.length === 0) return null;

              const totalDrops = fabricPieces.length;
              const totalPanels = group.cuts.length;

              return (
                <div
                  id={skuAnchorId(group.sku)}
                  key={group.sku}
                  className={`space-y-3 rounded-lg transition-all ${focusedSku === group.sku ? 'ring-2 ring-blue-400 ring-offset-2' : ''}`}
                >
                  <RollCutVisualizer
                    pieces={fabricPieces}
                    rollWidthMm={group.rollWidthMm}
                    rollLengthMm={group.rollLengthMm}
                    title={`${group.sku} — ${group.itemName}`}
                    subtitle={`${totalPanels} panel${totalPanels !== 1 ? 's' : ''} → ${totalDrops} drop${totalDrops !== 1 ? 's' : ''} · Roll: ${(group.rollWidthMm / 1000).toFixed(2)}m wide × ${(group.rollLengthMm / 1000).toFixed(1)}m long · MOs: ${group.moNumbers.join(', ')}`}
                    canRotate={group.canRotate}
                    onPieceClick={(piece) => setSelectedFabricPiece({ piece, skuGroup: group })}
                    onPrintPDF={async () => {
                      const logo = await loadLogo();
                      const allMoIds = [...new Set(group.cuts.map(c => c.mo_id))];
                      const moHexMap: Record<string, string> = {};
                      allMoIds.forEach((id, i) => { moHexMap[id] = MO_HEX_COLORS[i % MO_HEX_COLORS.length]; });
                      const r2d = optimize2D(fabricPieces, group.rollWidthMm, group.rollLengthMm, group.canRotate);
                      const doc = generateCutPlanPDF({
                        type: '2d',
                        title: `${group.sku} — ${group.itemName}`,
                        subtitle: `${totalPanels} panel(s) · Roll: ${(group.rollWidthMm / 1000).toFixed(2)}m × ${(group.rollLengthMm / 1000).toFixed(1)}m · MOs: ${group.moNumbers.join(', ')}`,
                        sku: group.sku,
                        moNumbers: group.moNumbers,
                        rollWidthMm: group.rollWidthMm,
                        rollLengthMm: group.rollLengthMm,
                        result2D: r2d,
                        moHexColorMap: moHexMap,
                        logoPngBase64: logo.base64,
                        logoWidthPx: logo.w,
                        logoHeightPx: logo.h,
                      });
                      doc.save(`CutOrder-Fabric-${group.sku}-${new Date().toISOString().slice(0, 10)}.pdf`);
                    }}
                    onPrintStickers={async () => {
                      const labels: ThermalCutLabel[] = [];
                      group.cuts.forEach(c => {
                        const drops = decomposePanelIntoDrops(c, group.rollWidthMm);
                        if (drops.length === 0) {
                          labels.push({
                            soNumber: c.so_number,
                            salesOrderId: c.so_id,
                            moNumber: c.mo_number,
                            stationCode: 'CUT-ROLL',
                            lineLabel: c.line_label,
                            dealerName: c.dealer_name,
                            sku: c.sku,
                            itemName: c.item_name,
                            cutWidthMm: c.cut_length_mm,
                            cutHeightMm: c.cut_height_mm,
                            curtainWidthMm: c.product_width_m != null ? c.product_width_m * 1000 : null,
                            curtainHeightMm: c.product_height_m != null ? c.product_height_m * 1000 : null,
                            refId: c.bil_id,
                          });
                          return;
                        }
                        drops.forEach((d, idx) => {
                          labels.push({
                            soNumber: c.so_number,
                            salesOrderId: c.so_id,
                            moNumber: c.mo_number,
                            stationCode: 'CUT-ROLL',
                            lineLabel: c.line_label,
                            dealerName: c.dealer_name,
                            sku: c.sku,
                            itemName: c.item_name,
                            cutWidthMm: d.widthMm,
                            cutHeightMm: d.heightMm,
                            curtainWidthMm: c.product_width_m != null ? c.product_width_m * 1000 : null,
                            curtainHeightMm: c.product_height_m != null ? c.product_height_m * 1000 : null,
                            refId: `${c.bil_id}-d${idx + 1}`,
                          });
                        });
                      });
                      if (labels.length === 0) return;
                      const doc = await generateThermalCutStickersPDF(labels);
                      doc.save(`Stickers-${group.sku}-${new Date().toISOString().slice(0, 10)}.pdf`);
                    }}
                  />

                  {/* PanelCutDetail — shown when a piece from THIS group is clicked */}
                  {selectedFabricPiece && selectedFabricPiece.skuGroup.sku === group.sku && (() => {
                    const p = selectedFabricPiece.piece;
                    const bilId = p.id.replace(/-d\d+$/, '');
                    const cut = group.cuts.find(c => c.bil_id === bilId);
                    const productTypes = new Set(group.cuts.map(c => c.product_type).filter(Boolean));
                    const dominantPt = [...productTypes][0] ?? 'roller';
                    const rule = fabricRuleMap[dominantPt];
                    if (!rule) return null;

                    return (
                      <PanelCutDetail
                        moNumber={p.moNumber ?? ''}
                        sku={group.sku}
                        itemName={group.itemName}
                        productType={dominantPt}
                        productWidthMm={cut?.product_width_m != null ? Math.round(cut.product_width_m * 1000) : (cut?.cut_length_mm ?? p.widthMm)}
                        productHeightMm={cut?.product_height_m != null ? Math.round(cut.product_height_m * 1000) : (cut?.cut_height_mm ?? p.heightMm)}
                        cutWidthMm={cut?.cut_length_mm ?? p.widthMm}
                        cutHeightMm={cut?.cut_height_mm ?? p.heightMm}
                        rollWidthMm={group.rollWidthMm}
                        heatsealDirection={rule.heatseal_direction}
                        soNumber={cut?.so_number ?? undefined}
                        productName={[cut?.style_label, cut?.product_name].filter(Boolean).join(' · ') || undefined}
                        materials={selectedPieceMaterials}
                        materialsLoading={materialsLoading}
                        rule={{
                          tube_wrap_mm: rule.tube_wrap_mm,
                          bottom_wrap_mm: rule.bottom_wrap_mm,
                          safety_margin_mm: rule.safety_margin_mm,
                          top_hem_mm: rule.top_hem_cm * 10,
                          bottom_hem_mm: rule.bottom_hem_cm * 10,
                          side_hem_mm: rule.side_hem_cm * 10,
                          panel_multiplier: rule.panel_multiplier,
                          fullness_factor: rule.fullness_factor,
                          heatseal_price_per_m: rule.heatseal_price_per_m,
                          waste_pct: rule.waste_pct,
                          bottom_bar_wrap_pct: rule.bottom_bar_wrap_pct,
                        }}
                        onClose={() => setSelectedFabricPiece(null)}
                      />
                    );
                  })()}
                </div>
              );
            })}

            {/* Fabric construction specs */}
            {mode === 'fabric' && fabricSpecs.length > 0 && (
              <div className="space-y-3">
                <h3 className="text-sm font-semibold text-gray-700">Construction Specifications</h3>
                {fabricSpecs.map(spec => (
                  <div key={spec.product_type}>
                    <button
                      type="button"
                      onClick={() => setExpandedSpec(expandedSpec === spec.product_type ? null : spec.product_type)}
                      className="w-full flex items-center gap-2 px-3 py-2 text-xs font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50"
                    >
                      {expandedSpec === spec.product_type
                        ? <ChevronDown className="w-3.5 h-3.5" />
                        : <ChevronRight className="w-3.5 h-3.5" />}
                      {spec.display_name}
                      <span className="text-[10px] text-gray-400 ml-auto">
                        +{spec.top_allowance_mm + spec.bottom_allowance_mm + spec.hem_bar_pocket_mm + spec.safety_margin_mm}mm allowances
                      </span>
                    </button>
                    {expandedSpec === spec.product_type && (
                      <div className="mt-2">
                        <FabricSpecsCard spec={spec} orderedHeightMm={2000} orderedWidthMm={1500} />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
      {/* Confirm Cut Dialog */}
      {confirmCut && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-sm p-6">
            <h3 className="text-sm font-semibold text-gray-900 mb-2">
              {confirmCut.markCompleted ? 'Confirm Cut Completed' : 'Revert Cut Status'}
            </h3>
            <p className="text-sm text-gray-600 mb-1">
              {confirmCut.markCompleted
                ? <>Are you sure <span className="font-mono font-semibold">{confirmCut.sku}</span> has been cut?</>
                : <>Revert <span className="font-mono font-semibold">{confirmCut.sku}</span> back to pending?</>
              }
            </p>
            <p className="text-xs text-gray-400 mb-5">
              {confirmCut.markCompleted
                ? 'This will mark all pieces for this material as completed. The material will move to the Completed tab.'
                : 'This will mark all pieces as not cut. The material will return to the Pending tab.'
              }
            </p>
            <div className="flex items-center justify-end gap-2">
              <button type="button" onClick={() => setConfirmCut(null)} className="px-3 py-1.5 text-xs font-medium text-gray-600 bg-gray-100 rounded hover:bg-gray-200">Cancel</button>
              <button type="button" onClick={executeMarkCut} className={`px-3 py-1.5 text-xs font-medium text-white rounded ${confirmCut.markCompleted ? 'bg-green-600 hover:bg-green-700' : 'bg-amber-600 hover:bg-amber-700'}`}>
                {confirmCut.markCompleted ? 'Yes, Mark as Cut' : 'Yes, Revert'}
              </button>
            </div>
          </div>
        </div>
      )}
      {/* Confirm Mark All Cut Dialog */}
      {confirmAllCut && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-sm p-6">
            <h3 className="text-sm font-semibold text-gray-900 mb-2">Mark All as Cut</h3>
            <p className="text-sm text-gray-600 mb-1">
              Mark <span className="font-semibold">{uncutLineCount}</span> pending line(s) across{' '}
              <span className="font-semibold">{skuGroups.length}</span> material(s) as cut?
            </p>
            <p className="text-xs text-gray-400 mb-5">
              Any not-yet-started cut tasks will be started automatically. Materials will move to the Completed tab.
            </p>
            <div className="flex items-center justify-end gap-2">
              <button type="button" onClick={() => setConfirmAllCut(false)} className="px-3 py-1.5 text-xs font-medium text-gray-600 bg-gray-100 rounded hover:bg-gray-200">Cancel</button>
              <button type="button" onClick={executeMarkAllCut} className="px-3 py-1.5 text-xs font-medium text-white rounded bg-green-600 hover:bg-green-700">Yes, Mark All as Cut</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
