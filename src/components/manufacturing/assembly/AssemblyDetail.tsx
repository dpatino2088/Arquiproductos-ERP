import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../../lib/supabase/client';
import { Loader2, Box, ChevronDown, ChevronRight, CheckCircle2, Circle, PackageCheck, Clock } from 'lucide-react';
import RollerAssemblyDiagram from './RollerAssemblyDiagram';
import DraperyAssemblyDiagram from './DraperyAssemblyDiagram';

import AssemblyPickList, { type PickListItem, type ReadinessStatus } from './AssemblyPickList';

export interface AssemblyLine extends PickListItem {
  bom_instance_line_id: string | null;
}

interface SiblingTaskInfo {
  code: string;
  status: string;
}

interface AssemblyDetailProps {
  manufacturingOrderId: string;
  moNumber: string;
  productName: string;
  lines: AssemblyLine[];
  onToggleLine: (lineId: string, completed: boolean) => void;
  siblingTasks?: SiblingTaskInfo[];
  readOnly?: boolean;
}

export interface CutBreakdownDeduction {
  role: string;
  sku: string;
  delta: number;
  qty: number;
  total: number;
  mode?: 'subtract' | 'add' | 'info';
  affects_cut?: boolean;
  conditional: boolean;
  label?: string;
}

export interface PanelDeduction {
  role: string;
  sku: string;
  delta: number;
  qty: number;
  total: number;
  mode?: 'subtract' | 'add' | 'info';
  note?: string;
}

export interface PanelCut {
  panel: number;
  base_mm: number;
  cut_mm: number;
  deduction: number;
  calc_ded?: number;
  position: 'left' | 'center' | 'right';
  cut_height?: number;
  deductions?: PanelDeduction[];
}

export interface CutBreakdownItem {
  role: string;
  label: string;
  sku: string;
  axis: 'width' | 'height' | 'special';
  base_label: string;
  base_mm: number;
  tolerance_mm: number;
  deductions: CutBreakdownDeduction[];
  total_deduction: number;
  resolved_mm: number;
  instance_cut_mm: number | null;
  match: boolean;
  per_panel: boolean;
  panel_count?: number;
  panel_cuts?: PanelCut[];
  qty_type: string;
  qty_value: number;
  resolved_height_mm?: number;
  instance_cut_height_mm?: number;
  fabric_width_mm?: number;
  fabric_width_source?: string;
}

interface ProductConfig {
  product_type: string | null;
  width_mm: number;
  height_mm: number;
  panel_count: number;
  panel_widths: number[];
  operating_system: 'manual' | 'motorized' | 'motor' | null;
  operator_side: 'left' | 'right' | null;
  drive_side: 'left' | 'right' | null;
  opening_direction: 'left' | 'center' | 'right';
  has_cassette: boolean;
  has_side_channel: boolean;
  has_bottom_bar: boolean;
  has_track: boolean;
  tube_type: string | null;
  tube_cut_mm: number | null;
  tube_cuts_per_panel: number[];
  fabric_cut_mm: number | null;
  bottom_bar_cut_mm: number | null;
  bottom_bar_cuts_per_panel: number[];
  hardware_color: string | null;
  fabric_name: string | null;
  fabric_names: (string | null)[];
  fullness_factor: number;
  cut_breakdown: CutBreakdownItem[] | null;
  bom_template_code: string | null;
}

interface ProductUnit {
  solId: string;
  productType: string | null;
  description: string | null;
  widthMm: number;
  heightMm: number;
  lines: AssemblyLine[];
  config: ProductConfig | null;
}

function normalizeProductType(pt: string | null): string | null {
  if (!pt) return null;
  const lower = pt.toLowerCase();
  if (lower.includes('roller')) return 'roller';
  if (lower.includes('drapery') || lower.includes('curtain')) return 'drapery';
  if (lower.includes('triple')) return 'triple';
  if (lower.includes('dual')) return 'dual';
  return lower;
}

function buildConfigFromSol(
  sol: any,
  cpConfig: any,
  productLines: AssemblyLine[],
): ProductConfig {
  const widthMm = sol.width_m ? Math.round(Number(sol.width_m) * 1000) : 0;
  const heightMm = sol.height_m ? Math.round(Number(sol.height_m) * 1000) : 0;

  const panelCount = cpConfig?.total_panels ?? cpConfig?.panels?.length ?? 1;
  const panelWidths: number[] = cpConfig?.panels?.map((p: any) => p.width_mm ?? widthMm) ?? [widthMm];

  const hasCassette = cpConfig?.cassette === true || cpConfig?.headbox_type === 'cassette' || cpConfig?.headbox_type === 'standard'
    || productLines.some(l => l.component_role === 'headbox');
  const hasSideChannel = cpConfig?.side_channel === true || cpConfig?.side_channel_mode === 'with_channel'
    || productLines.some(l => l.component_role === 'side_channel');
  const hasBottomBar = productLines.some(l => l.component_role === 'bottom_bar' || l.component_role === 'bottom_channel');
  const hasTrack = productLines.some(l => l.component_role === 'track' || l.component_role === 'top_rail');
  const pickCutLength = (roles: string[]) => {
    const direct = productLines.find(
      (l) => roles.includes(l.component_role ?? '') && l.cut_length_mm != null && Number(l.qty) <= 1,
    );
    if (direct?.cut_length_mm != null) return Number(direct.cut_length_mm);
    const fallback = productLines.find((l) => roles.includes(l.component_role ?? '') && l.cut_length_mm != null);
    return fallback?.cut_length_mm != null ? Number(fallback.cut_length_mm) : null;
  };

  const pickAllCutLengths = (roles: string[]): number[] => {
    return productLines
      .filter((l) => roles.includes(l.component_role ?? '') && l.cut_length_mm != null)
      .map((l) => Number(l.cut_length_mm));
  };

  const fabricLine = productLines.find(l => l.component_role === 'fabric');
  const fabricName = fabricLine?.item_name ?? (sol.collection_name && sol.variant_name ? `${sol.collection_name} ${sol.variant_name}` : null);

  const fabricNames: (string | null)[] = [fabricName];
  if (cpConfig?.frontFabric) fabricNames[0] = cpConfig.frontFabric.collectionId ?? fabricName;
  if (cpConfig?.middleFabric) fabricNames.push(cpConfig.middleFabric.collectionId ?? null);
  if (cpConfig?.backFabric) fabricNames.push(cpConfig.backFabric.collectionId ?? null);

  const tubeLine = productLines.find(l => l.component_role === 'tube');
  const tubeType = cpConfig?.tube_type ?? cpConfig?.tubeSize ?? tubeLine?.sku ?? null;
  const opSys = cpConfig?.drive_type ?? cpConfig?.operation_type ?? null;
  const opSide = cpConfig?.operatingSystemSide ?? null;
  const openDir = cpConfig?.opening_direction ?? cpConfig?.openingDirection ?? 'left';
  const driveSide = cpConfig?.driveSide ?? cpConfig?.drive_side ?? (openDir !== 'center' ? openDir : null);
  const hwColor = sol.hardware_color ?? cpConfig?.hardware_color ?? cpConfig?.hardwareColor ?? null;
  const fullness = cpConfig?.fullness_factor ?? 2;
  const tubeCutMm = pickCutLength(['tube']);
  const tubeCutsPerPanel = pickAllCutLengths(['tube']);
  const fabricCutMm = pickCutLength(['fabric', 'fabric_panel', 'tape']);
  const bottomBarCutMm = pickCutLength(['bottom_bar', 'bottom_channel']);
  const bottomBarCutsPerPanel = pickAllCutLengths(['bottom_bar', 'bottom_channel']);

  let productType = sol.product_type ?? cpConfig?.productType ?? cpConfig?.product_type ?? null;
  if (!productType) {
    if (hasTrack) productType = 'drapery';
    else if (productLines.some(l => l.component_role === 'tube')) productType = 'roller';
  }

  return {
    product_type: normalizeProductType(productType),
    width_mm: widthMm,
    height_mm: heightMm,
    panel_count: panelCount,
    panel_widths: panelWidths,
    operating_system: opSys,
    operator_side: opSide,
    drive_side: driveSide,
    opening_direction: openDir,
    has_cassette: hasCassette,
    has_side_channel: hasSideChannel,
    has_bottom_bar: hasBottomBar,
    has_track: hasTrack,
    tube_type: tubeType,
    tube_cut_mm: tubeCutMm,
    tube_cuts_per_panel: tubeCutsPerPanel,
    fabric_cut_mm: fabricCutMm,
    bottom_bar_cut_mm: bottomBarCutMm,
    bottom_bar_cuts_per_panel: bottomBarCutsPerPanel,
    hardware_color: hwColor,
    fabric_name: fabricName,
    fabric_names: fabricNames,
    fullness_factor: fullness,
    cut_breakdown: null,
    bom_template_code: cpConfig?.bom_template_code ?? null,
  };
}

function ProductDiagram({ config }: { config: ProductConfig | null }) {
  if (!config || !config.product_type) {
    return (
      <div className="text-center py-4">
        <Box className="w-6 h-6 text-gray-300 mx-auto mb-1" />
        <p className="text-[10px] text-gray-400">No diagram available</p>
      </div>
    );
  }

  switch (config.product_type) {
    case 'roller':
      return (
        <RollerAssemblyDiagram
          widthMm={config.width_mm}
          heightMm={config.height_mm}
          panelCount={config.panel_count}
          panelWidths={config.panel_widths}
          operatingSystem={config.operating_system}
          operatingSide={config.operator_side}
          hasCassette={config.has_cassette}
          hasSideChannel={config.has_side_channel}
          hasBottomBar={config.has_bottom_bar}
          tubeType={config.tube_type}
          tubeCutMm={config.tube_cut_mm}
          tubeCutsPerPanel={config.tube_cuts_per_panel}
          fabricCutMm={config.fabric_cut_mm}
          bottomBarCutMm={config.bottom_bar_cut_mm}
          bottomBarCutsPerPanel={config.bottom_bar_cuts_per_panel}
          hardwareColor={config.hardware_color}
          fabricName={config.fabric_name}
          cutBreakdown={config.cut_breakdown}
          bomTemplateCode={config.bom_template_code}
        />
      );
    case 'drapery':
      return (
        <DraperyAssemblyDiagram
          widthMm={config.width_mm}
          heightMm={config.height_mm}
          panelCount={config.panel_count}
          openingDirection={config.opening_direction}
          driveSide={config.drive_side}
          operatingSystem={config.operating_system}
          hasTrack={config.has_track}
          fabricName={config.fabric_name}
          fullnessFactor={config.fullness_factor}
          cutBreakdown={config.cut_breakdown}
          bomTemplateCode={config.bom_template_code}
        />
      );
    case 'dual':
    case 'triple':
      return (
        <RollerAssemblyDiagram
          widthMm={config.width_mm}
          heightMm={config.height_mm}
          panelCount={config.panel_count}
          panelWidths={config.panel_widths}
          operatingSystem={config.operating_system}
          operatingSide={config.operator_side}
          hasCassette={config.has_cassette}
          hasSideChannel={config.has_side_channel}
          hasBottomBar={config.has_bottom_bar}
          tubeType={config.tube_type}
          tubeCutMm={config.tube_cut_mm}
          tubeCutsPerPanel={config.tube_cuts_per_panel}
          fabricCutMm={config.fabric_cut_mm}
          bottomBarCutMm={config.bottom_bar_cut_mm}
          bottomBarCutsPerPanel={config.bottom_bar_cuts_per_panel}
          hardwareColor={config.hardware_color}
          fabricName={config.fabric_name}
          fabricLayers={config.product_type === 'dual' ? 2 : config.product_type === 'triple' ? 3 : 1}
          cutBreakdown={config.cut_breakdown}
          bomTemplateCode={config.bom_template_code}
        />
      );
    default:
      return (
        <div className="text-center py-4">
          <Box className="w-6 h-6 text-gray-300 mx-auto mb-1" />
          <p className="text-[10px] text-gray-400">Diagram not available for "{config.product_type}"</p>
        </div>
      );
  }
}

function ProductCard({
  unit,
  index,
  expanded,
  onToggle,
  onMarkAssembled,
  readinessMap,
  marking,
  readOnly,
}: {
  unit: ProductUnit;
  index: number;
  expanded: boolean;
  onToggle: () => void;
  onMarkAssembled: () => void;
  readinessMap: Record<string, ReadinessStatus>;
  marking: boolean;
  readOnly: boolean;
}) {
  const isComplete = unit.lines.length > 0 && unit.lines.every(l => l.completed);
  const allMaterialsReady = unit.lines.every(l => {
    const status = readinessMap[l.component_role ?? ''] ?? 'ready';
    return status === 'ready';
  });
  const ptLabel = unit.config?.product_type
    ? unit.config.product_type.charAt(0).toUpperCase() + unit.config.product_type.slice(1)
    : 'Product';

  return (
    <div className={`border rounded-lg overflow-hidden transition-colors ${isComplete ? 'border-green-200 bg-green-50/30' : 'border-gray-200'}`}>
      <button
        type="button"
        onClick={onToggle}
        className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50/50 transition-colors"
      >
        <div className="flex-shrink-0">
          {isComplete
            ? <CheckCircle2 className="w-5 h-5 text-green-500" />
            : <Circle className="w-5 h-5 text-gray-300" />}
        </div>
        <div className="flex-shrink-0 w-7 h-7 rounded-full bg-gray-100 flex items-center justify-center">
          <span className="text-xs font-bold text-gray-600">{index + 1}</span>
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className={`text-sm font-medium truncate ${isComplete ? 'text-gray-500 line-through' : 'text-gray-900'}`}>
              {unit.description ?? ptLabel}
            </span>
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-gray-100 text-gray-500 font-medium">
              {ptLabel}
            </span>
            {isComplete && (
              <span className="text-[9px] px-1.5 py-0.5 rounded bg-green-100 text-green-700 font-semibold">
                ASSEMBLED
              </span>
            )}
          </div>
          <p className="text-[10px] text-gray-400 mt-0.5">
            {unit.widthMm > 0 ? `${unit.widthMm}×${unit.heightMm}mm` : 'Catalog item'}
            {unit.config?.hardware_color && ` · ${unit.config.hardware_color}`}
            {unit.config?.fabric_name && ` · ${unit.config.fabric_name}`}
          </p>
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          {expanded ? <ChevronDown className="w-4 h-4 text-gray-400" /> : <ChevronRight className="w-4 h-4 text-gray-400" />}
        </div>
      </button>

      {expanded && (
        <div className="border-t border-gray-100">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-0 divide-y lg:divide-y-0 lg:divide-x divide-gray-100">
            <div className="p-3">
              <h4 className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-2">Assembly Diagram</h4>
              <ProductDiagram config={unit.config} />
            </div>
            <div className="p-3">
              <AssemblyPickList
                lines={unit.lines}
                onToggle={() => {}}
                mode="readiness"
                readinessMap={readinessMap}
              />
            </div>
          </div>

          {!readOnly && (
            <div className="px-4 py-3 bg-gray-50 border-t border-gray-100 flex items-center justify-between">
              {!allMaterialsReady && !isComplete && (
                <span className="text-[10px] text-amber-600 flex items-center gap-1">
                  <Clock className="w-3 h-3" /> Waiting for upstream tasks to complete
                </span>
              )}
              <div className="ml-auto">
                {isComplete ? (
                  <button
                    type="button"
                    onClick={onMarkAssembled}
                    className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-medium text-amber-700 bg-amber-50 border border-amber-200 rounded-lg hover:bg-amber-100"
                  >
                    Undo Assembly
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={onMarkAssembled}
                    disabled={marking || !allMaterialsReady}
                    className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {marking ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <PackageCheck className="w-3.5 h-3.5" />}
                    Mark as Assembled
                  </button>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function AssemblyDetail({
  manufacturingOrderId,
  moNumber,
  productName,
  lines,
  onToggleLine,
  siblingTasks: siblingTasksProp,
  readOnly = false,
}: AssemblyDetailProps) {
  const [products, setProducts] = useState<ProductUnit[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedIdx, setExpandedIdx] = useState<number | null>(null);
  const [markingIdx, setMarkingIdx] = useState<number | null>(null);

  const readinessMap = useMemo(() => {
    const map: Record<string, ReadinessStatus> = {};

    const stationStatus: Record<string, string | undefined> = {};
    if (siblingTasksProp) {
      for (const t of siblingTasksProp) {
        stationStatus[t.code] = t.status;
      }
    }

    const isReady = (code: string) =>
      stationStatus[code] === undefined || stationStatus[code] === 'completed';

    const profileOk = isReady('CUT-PROFILE');
    const rollOk = isReady('CUT-ROLL');
    const pickOk = isReady('PICK');

    ['tube', 'headbox', 'top_rail', 'track'].forEach(r => { map[r] = profileOk ? 'ready' : 'pending'; });
    ['bottom_bar', 'bottom_channel', 'side_channel'].forEach(r => { map[r] = profileOk ? 'ready' : 'pending'; });
    ['fabric', 'tape'].forEach(r => { map[r] = rollOk ? 'ready' : 'pending'; });
    ['bracket', 'idler', 'end_cap', 'adapter', 'filler', 'mounting_clip', 'end_plug',
     'connector', 'guide', 'rail_connector', 'spring', 'stopper', 'bearing',
     'drive', 'motor', 'chain', 'chain_stop', 'chain_tensioner', 'wand', 'belt', 'belt_connector',
     'hem_weight', 'accessory', 'consumable', 'fastener', 'carrier', 'hook', 'brush',
    ].forEach(r => { map[r] = pickOk ? 'ready' : 'pending'; });

    return map;
  }, [siblingTasksProp]);

  const handleMarkAssembled = useCallback(async (unitIdx: number) => {
    const unit = products[unitIdx];
    if (!unit) return;

    setMarkingIdx(unitIdx);
    try {
      const isComplete = unit.lines.length > 0 && unit.lines.every(l => l.completed);
      const newCompleted = !isComplete;

      for (const line of unit.lines) {
        if (line.completed !== newCompleted) {
          onToggleLine(line.id, newCompleted);
        }
      }
    } finally {
      setTimeout(() => setMarkingIdx(null), 300);
    }
  }, [products, onToggleLine]);

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const bilIds = lines.map(l => l.bom_instance_line_id).filter(Boolean) as string[];
      if (bilIds.length === 0) {
        setProducts([{
          solId: 'unknown',
          productType: null,
          description: productName,
          widthMm: 0,
          heightMm: 0,
          lines,
          config: null,
        }]);
        setLoading(false);
        return;
      }

      // BOMInstanceLines → BOMInstances (bom_instance_id)
      const { data: bilRows } = await supabase
        .from('BOMInstanceLines')
        .select('id, bom_instance_id')
        .in('id', bilIds);

      const bilToBi: Record<string, string> = {};
      (bilRows ?? []).forEach((r: any) => { bilToBi[r.id] = r.bom_instance_id; });

      // BOMInstances → SaleOrderLines (include created_at for sorting)
      const biIds = [...new Set(Object.values(bilToBi))];
      const { data: biRows } = await supabase
        .from('BOMInstances')
        .select('id, sales_order_line_id, created_at')
        .in('id', biIds);

      const biToSol: Record<string, string> = {};
      const biCreatedAt: Record<string, string> = {};
      (biRows ?? []).forEach((r: any) => {
        if (r.sales_order_line_id) biToSol[r.id] = r.sales_order_line_id;
        if (r.created_at) biCreatedAt[r.id] = r.created_at;
      });

      // Build line-to-SOL mapping
      const lineToSol: Record<string, string> = {};
      for (const line of lines) {
        if (line.bom_instance_line_id) {
          const biId = bilToBi[line.bom_instance_line_id];
          const solId = biId ? biToSol[biId] : undefined;
          if (solId) lineToSol[line.id] = solId;
        }
      }

      // Group lines by SOL
      const solGroups = new Map<string, AssemblyLine[]>();
      const unmapped: AssemblyLine[] = [];
      for (const line of lines) {
        const solId = lineToSol[line.id];
        if (solId) {
          if (!solGroups.has(solId)) solGroups.set(solId, []);
          solGroups.get(solId)!.push(line);
        } else {
          unmapped.push(line);
        }
      }

      // Fetch SaleOrderLines details
      const solIds = [...solGroups.keys()];
      const { data: solRows } = solIds.length > 0
        ? await supabase
            .from('SaleOrderLines')
            .select('id, product_type, width_m, height_m, description, collection_name, variant_name, hardware_color, configured_product_id')
            .in('id', solIds)
        : { data: [] };

      const solMap: Record<string, any> = {};
      (solRows ?? []).forEach((r: any) => { solMap[r.id] = r; });

      // Fetch ConfiguredProducts for all
      const cpIds = (solRows ?? []).map((r: any) => r.configured_product_id).filter(Boolean);
      const { data: cpRows } = cpIds.length > 0
        ? await supabase
            .from('ConfiguredProducts')
            .select('id, config_snapshot')
            .in('id', cpIds)
        : { data: [] };

      const cpMap: Record<string, any> = {};
      (cpRows ?? []).forEach((r: any) => { cpMap[r.id] = r.config_snapshot; });

      // Fetch BOM template codes for display
      const templateIds = [...new Set(
        Object.values(cpMap)
          .map((cs: any) => cs?.bom_template_id)
          .filter(Boolean),
      )];
      const templateCodeMap: Record<string, string> = {};
      if (templateIds.length > 0) {
        const { data: tmplRows } = await supabase
          .from('BOMTemplates')
          .select('id, code')
          .in('id', templateIds);
        (tmplRows ?? []).forEach((r: any) => {
          if (r.code) templateCodeMap[r.id] = r.code;
        });
        for (const cs of Object.values(cpMap)) {
          if (cs?.bom_template_id && templateCodeMap[cs.bom_template_id]) {
            cs.bom_template_code = templateCodeMap[cs.bom_template_id];
          }
        }
      }

      // Fetch cut breakdowns for each BOM instance (parallel)
      const breakdownByBi: Record<string, CutBreakdownItem[]> = {};
      const uniqueBiIds = [...new Set(Object.values(bilToBi))];
      await Promise.all(
        uniqueBiIds.map(async (biId) => {
          try {
            const { data, error } = await supabase.rpc('compute_instance_cut_breakdown', {
              p_bom_instance_id: biId,
            });
            if (error) return;
            // supabase.rpc for scalar jsonb: data is the value directly
            const arr = Array.isArray(data) ? data : null;
            if (arr && arr.length > 0 && typeof arr[0] === 'object' && arr[0] !== null && 'role' in arr[0]) {
              breakdownByBi[biId] = arr as CutBreakdownItem[];
            }
          } catch {
            // non-critical
          }
        }),
      );

      // Map SOL → BOM instance: prefer the LATEST instance with the most panel data
      const countPanelCuts = (biId: string) => {
        const items = breakdownByBi[biId];
        if (!items) return 0;
        return items.reduce((sum, item) => sum + (item.panel_cuts?.length ?? 0), 0);
      };
      const solToBi: Record<string, string> = {};
      for (const [biId, solId] of Object.entries(biToSol)) {
        const prev = solToBi[solId];
        if (!prev) {
          solToBi[solId] = biId;
        } else {
          const prevPanels = countPanelCuts(prev);
          const curPanels = countPanelCuts(biId);
          if (curPanels > prevPanels) {
            solToBi[solId] = biId;
          } else if (curPanels === prevPanels) {
            // same panel count: prefer the latest created instance
            if ((biCreatedAt[biId] ?? '') > (biCreatedAt[prev] ?? '')) {
              solToBi[solId] = biId;
            }
          }
        }
      }

      // Build product units
      const units: ProductUnit[] = [];
      for (const [solId, groupLines] of solGroups.entries()) {
        const sol = solMap[solId];
        if (!sol) {
          units.push({
            solId,
            productType: null,
            description: null,
            widthMm: 0,
            heightMm: 0,
            lines: groupLines,
            config: null,
          });
          continue;
        }

        const cpConfig = sol.configured_product_id ? cpMap[sol.configured_product_id] ?? null : null;
        const config = buildConfigFromSol(sol, cpConfig, groupLines);

        const biId = solToBi[solId];
        if (biId && breakdownByBi[biId]) {
          config.cut_breakdown = breakdownByBi[biId];
        }

        units.push({
          solId,
          productType: config.product_type,
          description: sol.description ?? (sol.collection_name && sol.variant_name ? `${sol.collection_name} ${sol.variant_name}` : null),
          widthMm: config.width_mm,
          heightMm: config.height_mm,
          lines: groupLines,
          config,
        });
      }

      // Add unmapped lines as a generic group
      if (unmapped.length > 0) {
        units.push({
          solId: 'unmapped',
          productType: 'catalog',
          description: 'Additional Items',
          widthMm: 0,
          heightMm: 0,
          lines: unmapped,
          config: null,
        });
      }

      // Sort: incomplete first, then by type, then by dimensions
      units.sort((a, b) => {
        const aComplete = a.lines.every(l => l.completed);
        const bComplete = b.lines.every(l => l.completed);
        if (aComplete !== bComplete) return aComplete ? 1 : -1;
        const typeOrder = ['roller', 'drapery', 'dual', 'triple', 'catalog'];
        const aIdx = typeOrder.indexOf(a.productType ?? 'catalog');
        const bIdx = typeOrder.indexOf(b.productType ?? 'catalog');
        if (aIdx !== bIdx) return aIdx - bIdx;
        return (b.widthMm * b.heightMm) - (a.widthMm * a.heightMm);
      });

      setProducts(units);
    } catch (err) {
      console.error('AssemblyDetail fetch error:', err);
      setProducts([]);
    } finally {
      setLoading(false);
    }
  }, [manufacturingOrderId, lines, productName]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="w-5 h-5 animate-spin text-gray-400" />
      </div>
    );
  }

  const totalProducts = products.length;
  const completedProducts = products.filter(p => p.lines.length > 0 && p.lines.every(l => l.completed)).length;
  const totalLines = lines.length;
  const completedLines = lines.filter(l => l.completed).length;

  return (
    <div className="space-y-3">
      {/* Header */}
      <div className="flex items-center justify-between px-1">
        <div>
          <div className="flex items-center gap-2">
            <Box className="w-4 h-4 text-gray-500" />
            <h3 className="text-sm font-semibold text-gray-900">Assembly — {moNumber}</h3>
          </div>
          <p className="text-[10px] text-gray-400 mt-0.5 ml-6">
            {totalProducts} product{totalProducts !== 1 ? 's' : ''} to assemble · {completedLines}/{totalLines} components
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-right">
            <p className={`text-sm font-bold ${completedProducts === totalProducts && totalProducts > 0 ? 'text-green-600' : 'text-gray-700'}`}>
              {completedProducts}/{totalProducts}
            </p>
            <p className="text-[9px] text-gray-400 uppercase tracking-wider">Assembled</p>
          </div>
          <div className="w-20 h-2 bg-gray-200 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${completedProducts === totalProducts && totalProducts > 0 ? 'bg-green-500' : 'bg-blue-500'}`}
              style={{ width: `${totalProducts > 0 ? (completedProducts / totalProducts) * 100 : 0}%` }}
            />
          </div>
        </div>
      </div>

      {/* Product list */}
      <div className="space-y-2">
        {products.map((unit, idx) => (
          <ProductCard
            key={unit.solId}
            unit={unit}
            index={idx}
            expanded={expandedIdx === idx}
            onToggle={() => setExpandedIdx(expandedIdx === idx ? null : idx)}
            onMarkAssembled={() => handleMarkAssembled(idx)}
            readinessMap={readinessMap}
            marking={markingIdx === idx}
            readOnly={readOnly}
          />
        ))}
      </div>
    </div>
  );
}
