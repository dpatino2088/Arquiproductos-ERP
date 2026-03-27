import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import CutPlanVisualizer from '../../components/manufacturing/CutPlanVisualizer';
import RollCutVisualizer from '../../components/manufacturing/RollCutVisualizer';
import FabricSpecsCard from '../../components/manufacturing/FabricSpecsCard';
import PanelCutDetail from '../../components/manufacturing/PanelCutDetail';
import { optimize1D, type CutPiece } from '../../lib/cutOptimizer';
import { optimize2D, type FabricPiece, type PlacedFabricPiece } from '../../lib/cutOptimizer2D';
import { generateConsolidated1DPDF, generateCutPlanPDF, type ConsolidatedCutGroup } from '../../lib/pdf/generateCutPlanPDF';
import { generateThermalCutStickersPDF, openThermalStickerPrintWindow, type ThermalCutLabel } from '../../lib/pdf/thermalCutStickerPdf';
import { Scissors, Layers, RefreshCw, Loader2, ChevronDown, ChevronRight, Printer, MoreVertical } from 'lucide-react';

type Mode = 'profiles' | 'fabric';

interface PendingCut {
  bil_id: string;
  sku: string;
  item_name: string;
  cut_length_mm: number | null;   // fabric panel width (fabric_cut_width_mm)
  cut_height_mm: number | null;   // fabric drop (fabric_cut_height_mm)
  qty: number;
  mo_id: string;
  mo_number: string;
  so_number: string | null;
  part_role: string;
  stock_length_mm: number | null;
  roll_width_m: number | null;
  roll_length_value: number | null;
  roll_length_uom: string | null;
  product_type: string | null;
  product_width_m: number | null;
  product_height_m: number | null;
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

export default function CutOptimization() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { role } = useCurrentOrgRole();
  const isOperator = role === 'operator' || role === 'operator_member';
  const currentUserId = user?.id ?? null;
  const [mode, setMode] = useState<Mode>('profiles');
  const [loading, setLoading] = useState(true);
  const [pendingCuts, setPendingCuts] = useState<PendingCut[]>([]);
  const [fabricSpecs, setFabricSpecs] = useState<FabricSpec[]>([]);
  const [fabricRules, setFabricRules] = useState<FabricRuleInfo[]>([]);
  const [selectedSkus, setSelectedSkus] = useState<Set<string>>(new Set());
  const [excludedMOs, setExcludedMOs] = useState<Set<string>>(new Set());
  const [expandedSkuMOs, setExpandedSkuMOs] = useState<Set<string>>(new Set());
  const [expandedSpec, setExpandedSpec] = useState<string | null>(null);
  const [selectedFabricPiece, setSelectedFabricPiece] = useState<{ piece: PlacedFabricPiece; skuGroup: SkuGroup } | null>(null);
  const [actionsOpen, setActionsOpen] = useState(false);

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  const fetchPendingCuts = useCallback(async () => {
    if (!activeOrganizationId) return;
    setLoading(true);
    try {
      const stationCode = mode === 'profiles' ? 'CUT-PROFILE' : 'CUT-ROLL';

      let taskQuery = supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, work_center_id')
        .eq('deleted', false)
        .in('status', ['pending', 'in_progress']);

      if (isOperator && currentUserId) {
        taskQuery = taskQuery.eq('assigned_to_user_id', currentUserId);
      }

      const { data: tasks } = await taskQuery;

      if (!tasks || tasks.length === 0) { setPendingCuts([]); setLoading(false); return; }

      const { data: wcs } = await supabase
        .from('WorkCenters')
        .select('id')
        .eq('code', stationCode)
        .eq('deleted', false);

      const wcIds = new Set((wcs ?? []).map((w: any) => w.id));
      const matchedTasks = tasks.filter((t: any) => wcIds.has(t.work_center_id));
      if (matchedTasks.length === 0) { setPendingCuts([]); setLoading(false); return; }

      const taskIds = matchedTasks.map((t: any) => t.id);
      const moIds = [...new Set(matchedTasks.map((t: any) => t.manufacturing_order_id))];

      const [{ data: lines }, { data: mos }] = await Promise.all([
        supabase
          .from('WorkOrderTaskLines')
          .select('id, task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm')
          .in('task_id', taskIds),
        supabase
          .from('ManufacturingOrders')
          .select('id, manufacturing_order_no, status, sales_order_id')
          .in('id', moIds)
          .not('status', 'in', '("draft","cancelled")'),
      ]);

      const moMap: Record<string, string> = {};
      const moToSoId: Record<string, string | null> = {};
      const activeMoIds = new Set<string>();
      (mos ?? []).forEach((m: any) => {
        moMap[m.id] = m.manufacturing_order_no;
        moToSoId[m.id] = m.sales_order_id ?? null;
        activeMoIds.add(m.id);
      });

      const soIds = [...new Set((mos ?? []).map((m: any) => m.sales_order_id).filter(Boolean))];
      const { data: soRows } = soIds.length > 0
        ? await supabase.from('SalesOrders').select('id, sales_order_no').in('id', soIds)
        : { data: [] };
      const soMap: Record<string, string> = {};
      (soRows ?? []).forEach((so: any) => {
        soMap[so.id] = so.sales_order_no ?? null;
      });

      // Only keep tasks whose MO is active (not draft/planned/completed)
      const taskToMo: Record<string, string> = {};
      matchedTasks.forEach((t: any) => {
        if (activeMoIds.has(t.manufacturing_order_id)) {
          taskToMo[t.id] = t.manufacturing_order_id;
        }
      });

      const catalogIds = [...new Set((lines ?? []).map((l: any) => l.catalog_item_id).filter(Boolean))];
      const { data: catalogItems } = catalogIds.length > 0
        ? await supabase.from('CatalogItems').select('id, stock_length_mm, roll_width_m, roll_length_value, roll_length_uom').in('id', catalogIds)
        : { data: [] };

      const catMap: Record<string, any> = {};
      (catalogItems ?? []).forEach((ci: any) => { catMap[ci.id] = ci; });

      // Fetch product_type + product dimensions via BIL -> BI -> SOL (used by cut stickers too)
      const bilMetaMap: Record<string, { product_type: string | null; width_m: number | null; height_m: number | null }> = {};
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
          ? await supabase.from('SaleOrderLines').select('id, product_type, width_m, height_m').in('id', solIds)
          : { data: [] };

        const solMap: Record<string, any> = {};
        (solRows ?? []).forEach((r: any) => { solMap[r.id] = r; });

        bilIds.forEach(bilId => {
          const biId = biMap[bilId];
          const solId = biId ? biSolMap[biId] : null;
          const sol = solId ? solMap[solId] : null;
          bilMetaMap[bilId] = {
            product_type: sol?.product_type ?? null,
            width_m: sol?.width_m != null ? Number(sol.width_m) : null,
            height_m: sol?.height_m != null ? Number(sol.height_m) : null,
          };
        });
      }

      const cuts: PendingCut[] = (lines ?? []).filter((l: any) => taskToMo[l.task_id]).map((l: any) => {
        const moId = taskToMo[l.task_id];
        const ci = l.catalog_item_id ? catMap[l.catalog_item_id] : null;
        const bilMeta = l.bom_instance_line_id ? bilMetaMap[l.bom_instance_line_id] : null;
        return {
          bil_id: l.bom_instance_line_id ?? l.id,
          sku: l.sku ?? '',
          item_name: l.item_name ?? '',
          cut_length_mm: l.cut_length_mm != null ? Number(l.cut_length_mm) : null,
          cut_height_mm: l.cut_width_mm != null ? Number(l.cut_width_mm) : null,
          qty: Number(l.qty),
          mo_id: moId,
          mo_number: moMap[moId] ?? '',
          so_number: moToSoId[moId] ? soMap[moToSoId[moId] as string] ?? null : null,
          part_role: l.component_role ?? '',
          stock_length_mm: ci?.stock_length_mm != null ? Number(ci.stock_length_mm) : null,
          roll_width_m: ci?.roll_width_m != null ? Number(ci.roll_width_m) : null,
          roll_length_value: ci?.roll_length_value != null ? Number(ci.roll_length_value) : null,
          roll_length_uom: ci?.roll_length_uom ?? null,
          product_type: bilMeta?.product_type ?? null,
          product_width_m: bilMeta?.width_m ?? null,
          product_height_m: bilMeta?.height_m ?? null,
        };
      });

      setPendingCuts(cuts);
      setSelectedSkus(new Set(cuts.map(c => c.sku)));
    } catch (err) {
      console.error('Failed to fetch pending cuts:', err);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, mode, isOperator, currentUserId]);

  useEffect(() => { fetchPendingCuts(); }, [fetchPendingCuts]);

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

  // All SKU groups (unfiltered) for the sidebar
  const allSkuGroups: SkuGroup[] = useMemo(() => {
    const map = new Map<string, PendingCut[]>();
    pendingCuts.forEach(c => {
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
  }, [pendingCuts, fabricRuleMap]);

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

  const toggleSku = (sku: string) => {
    setSelectedSkus(prev => {
      const next = new Set(prev);
      if (next.has(sku)) next.delete(sku);
      else next.add(sku);
      return next;
    });
  };

  const selectAll = () => setSelectedSkus(new Set(pendingCuts.map(c => c.sku)));
  const selectNone = () => setSelectedSkus(new Set());

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

  const handlePrintAllProfiles = useCallback(async () => {
    const profileGroups = selectedGroups.filter(g => {
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
          label: c.mo_number,
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

  const handlePrintAllFabric = useCallback(async () => {
    if (selectedGroups.length === 0) return;
    const logo = await loadLogo();

    const allMoIds = [...new Set(selectedGroups.flatMap(g => g.cuts.map(c => c.mo_id)))];
    const moHexMap: Record<string, string> = {};
    allMoIds.forEach((id, i) => { moHexMap[id] = MO_HEX_COLORS[i % MO_HEX_COLORS.length]; });
    const moNumberMap: Record<string, string> = {};
    selectedGroups.forEach(g => g.cuts.forEach(c => { moNumberMap[c.mo_id] = c.mo_number; }));

    for (const group of selectedGroups) {
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
              moNumber: c.mo_number,
              stationCode: 'CUT-PROFILE',
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
              moNumber: c.mo_number,
              stationCode: 'CUT-ROLL',
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
              moNumber: c.mo_number,
              stationCode: 'CUT-ROLL',
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
    openThermalStickerPrintWindow(doc);
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
    const dimLabel = prodW && prodH ? `${prodW}×${prodH}` : null;

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
        label: `${cut.mo_number} · W${w}×H${h}mm`,
      }];
    }

    if (panelWidthMm <= rollWidthMm) {
      return [{
        id: `${cut.bil_id}-d1`,
        widthMm: panelWidthMm,
        heightMm: dropHeightMm,
        moId: cut.mo_id,
        moNumber: cut.mo_number,
        label: `${cut.mo_number} · ${dimLabel ?? `W${Math.round(panelWidthMm)}×H${Math.round(dropHeightMm)}`}mm`,
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
            onClick={fetchPendingCuts}
            className="inline-flex items-center justify-center w-8 h-8 text-gray-500 hover:text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            title="Refresh"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </button>

          {/* Actions dropdown */}
          {selectedGroups.length > 0 && (
            <div className="relative">
              <button
                type="button"
                onClick={() => setActionsOpen((p) => !p)}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-gray-700 rounded-lg hover:bg-gray-600 transition-colors"
              >
                Actions <MoreVertical className="w-3.5 h-3.5" />
              </button>
              {actionsOpen && (
                <>
                  <div className="fixed inset-0 z-30" onClick={() => setActionsOpen(false)} />
                  <div className="absolute right-0 mt-1 w-52 bg-white border border-gray-200 rounded-lg shadow-lg z-40 py-1">
                    <button
                      type="button"
                      onClick={() => { setActionsOpen(false); mode === 'profiles' ? handlePrintAllProfiles() : handlePrintAllFabric(); }}
                      className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
                    >
                      <Printer className="w-4 h-4 text-gray-400" /> Cut Order PDF
                    </button>
                    <button
                      type="button"
                      onClick={() => { setActionsOpen(false); printThermalStickers(); }}
                      className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
                    >
                      <Printer className="w-4 h-4 text-gray-400" /> Thermal Stickers (4×1″)
                    </button>
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="w-6 h-6 animate-spin text-gray-400" />
        </div>
      ) : pendingCuts.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <Scissors className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-sm text-gray-500">No pending cuts found for {mode === 'profiles' ? 'Profile Cut' : 'Roll Cut'} stations.</p>
          <p className="text-xs text-gray-400 mt-1">Generate work orders from a Manufacturing Order first.</p>
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
                  const moEntries = [...new Set(group.cuts.map(c => `${c.mo_id}|${c.mo_number}`))].map(e => {
                    const [id, num] = e.split('|');
                    const count = group.cuts.filter(c => c.mo_id === id).length;
                    return { id, number: num, pieceCount: count };
                  });
                  const isExpanded = expandedSkuMOs.has(group.sku);
                  const activeMoCount = moEntries.filter(m => !excludedMOs.has(m.id)).length;

                  return (
                    <div key={group.sku}>
                      <div className="flex items-start gap-2.5 px-4 py-2.5 hover:bg-gray-50">
                        <input
                          type="checkbox"
                          checked={selectedSkus.has(group.sku)}
                          onChange={() => toggleSku(group.sku)}
                          className="rounded border-gray-300 mt-0.5 cursor-pointer"
                        />
                        <div className="flex-1 min-w-0">
                          <p className="text-xs font-mono text-gray-800 truncate">{group.sku}</p>
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
                          {moEntries.length > 1 && (
                            <button
                              type="button"
                              onClick={() => setExpandedSkuMOs(prev => {
                                const next = new Set(prev);
                                if (next.has(group.sku)) next.delete(group.sku); else next.add(group.sku);
                                return next;
                              })}
                              className="text-[10px] text-primary hover:underline mt-1 flex items-center gap-0.5"
                            >
                              {isExpanded ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
                              {isExpanded ? 'Hide MOs' : 'Filter MOs'}
                            </button>
                          )}
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
                              <span className="text-[10px] font-mono text-gray-600 group-hover:text-gray-900">{mo.number}</span>
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
                  label: `${c.mo_number}`,
                }));
              if (pieces.length === 0) return null;
              return (
                <CutPlanVisualizer
                  key={group.sku}
                  pieces={pieces}
                  stockLengthMm={group.stockLengthMm}
                  title={`${group.sku} — ${group.itemName}`}
                  subtitle={`${pieces.length} pieces · MOs: ${group.moNumbers.join(', ')}`}
                  onPrintStickers={async () => {
                    const labels: ThermalCutLabel[] = group.cuts
                      .filter(c => c.cut_length_mm != null && c.cut_length_mm > 0)
                      .map(c => ({
                        soNumber: c.so_number,
                        moNumber: c.mo_number,
                        stationCode: 'CUT-PROFILE' as const,
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
                    openThermalStickerPrintWindow(doc);
                  }}
                />
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
                <div key={group.sku} className="space-y-3">
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
                            moNumber: c.mo_number,
                            stationCode: 'CUT-ROLL',
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
                            moNumber: c.mo_number,
                            stationCode: 'CUT-ROLL',
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
                      openThermalStickerPrintWindow(doc);
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
                        productWidthMm={cut?.product_width_m ? cut.product_width_m * 1000 : (cut?.cut_length_mm ?? p.widthMm)}
                        productHeightMm={cut?.product_height_m ? cut.product_height_m * 1000 : (cut?.cut_height_mm ?? p.heightMm)}
                        cutWidthMm={cut?.cut_length_mm ?? p.widthMm}
                        cutHeightMm={cut?.cut_height_mm ?? p.heightMm}
                        rollWidthMm={group.rollWidthMm}
                        heatsealDirection={rule.heatseal_direction}
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
    </div>
  );
}
