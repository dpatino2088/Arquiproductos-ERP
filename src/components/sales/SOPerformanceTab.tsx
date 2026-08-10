import { useState, useEffect, useMemo } from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import { supabase } from '../../lib/supabase/client';
import { Loader2 } from 'lucide-react';

interface Props {
  salesOrderId: string;
  organizationId: string;
  currency?: string;
}

interface SOLineWithCosts {
  id: string;
  line_number: number | null;
  description: string | null;
  product_type: string | null;
  quantity: number;
  unit_price: number;
  line_total: number;
  /** Planned (quote snapshots) — unit costs */
  planned_roll_cost: number;
  planned_bom_cost: number;
  planned_labor_cost: number;
  planned_accessories_cost: number;
  planned_unit_cost_total: number;
  /** Actual material totals from live BOMInstanceLines (line-level, already qty-scaled via instances) */
  actual_fabric_total: number | null;
  actual_materials_total: number | null;
  actual_accessories_total: number | null;
  has_bom: boolean;
  has_substitution: boolean;
}

function fmt(amount: number, currency = 'USD') {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency || 'USD' }).format(amount || 0);
}

const COLORS = {
  fabric: '#3b82f6',
  materials: '#8b5cf6',
  labor: '#f59e0b',
  accessories: '#06b6d4',
  services: '#ec4899',
  profit: '#22c55e',
};

export default function SOPerformanceTab({ salesOrderId, organizationId, currency = 'USD' }: Props) {
  const [lines, setLines] = useState<SOLineWithCosts[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function fetchData() {
      setLoading(true);
      const { data: solRows, error: solErr } = await supabase
        .from('SaleOrderLines')
        .select('id, line_number, description, product_type, quantity, unit_price, line_total, quote_line_id')
        .eq('sales_order_id', salesOrderId)
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('line_number', { ascending: true, nullsFirst: false });

      if (cancelled) return;

      if (solErr || !solRows) {
        console.warn('[SOPerformanceTab] lines fetch error:', solErr);
        setLines([]);
        setLoading(false);
        return;
      }

      const qlIds = [...new Set(solRows.map((r: any) => r.quote_line_id).filter(Boolean))] as string[];
      const solIds = solRows.map((r: any) => r.id as string);
      const qlMap = new Map<string, any>();

      if (qlIds.length > 0) {
        const { data: qlRows } = await supabase
          .from('QuoteLines')
          .select('id, roll_cost_snapshot, bom_cost_snapshot, labor_cost_snapshot, accessories_cost_snapshot, unit_cost_total_snapshot')
          .in('id', qlIds);
        if (cancelled) return;
        (qlRows ?? []).forEach((q: any) => qlMap.set(q.id, q));
      }

      // Live BOM costs per sales order line (actual material cost after substitutes)
      const fabricBySol = new Map<string, number>();
      const materialsBySol = new Map<string, number>();
      const accessoriesBySol = new Map<string, number>();
      const solsWithBom = new Set<string>();
      const solsWithSub = new Set<string>();

      if (solIds.length > 0) {
        const { data: bomInstances } = await supabase
          .from('BOMInstances')
          .select('id, sales_order_line_id, manufacturing_order_id')
          .in('sales_order_line_id', solIds)
          .eq('organization_id', organizationId)
          .eq('deleted', false);

        if (cancelled) return;

        const biIds = (bomInstances ?? []).map((b: any) => b.id as string);
        const biToSol = new Map<string, string>();
        const moIds = new Set<string>();
        for (const bi of bomInstances ?? []) {
          if (bi.sales_order_line_id) {
            biToSol.set(bi.id, bi.sales_order_line_id);
            solsWithBom.add(bi.sales_order_line_id);
          }
          if (bi.manufacturing_order_id) moIds.add(bi.manufacturing_order_id);
        }

        if (biIds.length > 0) {
          const { data: bilRows } = await supabase
            .from('BOMInstanceLines')
            .select('bom_instance_id, part_role, total_cost_exw, excluded')
            .in('bom_instance_id', biIds)
            .eq('organization_id', organizationId)
            .eq('deleted', false);

          if (cancelled) return;

          for (const bil of bilRows ?? []) {
            if (bil.excluded) continue;
            const solId = biToSol.get(bil.bom_instance_id);
            if (!solId) continue;
            const cost = Number(bil.total_cost_exw) || 0;
            const role = String(bil.part_role ?? '').toLowerCase();
            if (role === 'fabric') {
              fabricBySol.set(solId, (fabricBySol.get(solId) ?? 0) + cost);
            } else if (role === 'accessory') {
              accessoriesBySol.set(solId, (accessoriesBySol.get(solId) ?? 0) + cost);
            } else {
              materialsBySol.set(solId, (materialsBySol.get(solId) ?? 0) + cost);
            }
          }
        }

        if (moIds.size > 0) {
          const { data: subRows } = await supabase
            .from('MOMaterialSubstitutions')
            .select('mo_id, bom_instance_line_id')
            .in('mo_id', [...moIds]);

          if (cancelled) return;

          if (subRows && subRows.length > 0) {
            // Map mo → sols via BOMInstances
            const moToSols = new Map<string, Set<string>>();
            for (const bi of bomInstances ?? []) {
              if (!bi.manufacturing_order_id || !bi.sales_order_line_id) continue;
              if (!moToSols.has(bi.manufacturing_order_id)) moToSols.set(bi.manufacturing_order_id, new Set());
              moToSols.get(bi.manufacturing_order_id)!.add(bi.sales_order_line_id);
            }
            for (const sub of subRows) {
              const sols = moToSols.get(sub.mo_id);
              if (!sols) continue;
              for (const sid of sols) solsWithSub.add(sid);
            }
          }
        }
      }

      const mapped: SOLineWithCosts[] = solRows.map((row: any) => {
        const ql = row.quote_line_id ? qlMap.get(row.quote_line_id) : null;
        const hasBom = solsWithBom.has(row.id);
        return {
          id: row.id,
          line_number: row.line_number,
          description: row.description,
          product_type: row.product_type,
          quantity: Number(row.quantity) || 0,
          unit_price: Number(row.unit_price) || 0,
          line_total: Number(row.line_total) || 0,
          planned_roll_cost: Number(ql?.roll_cost_snapshot ?? 0),
          planned_bom_cost: Number(ql?.bom_cost_snapshot ?? 0),
          planned_labor_cost: Number(ql?.labor_cost_snapshot ?? 0),
          planned_accessories_cost: Number(ql?.accessories_cost_snapshot ?? 0),
          planned_unit_cost_total: Number(ql?.unit_cost_total_snapshot ?? 0),
          actual_fabric_total: hasBom ? (fabricBySol.get(row.id) ?? 0) : null,
          actual_materials_total: hasBom ? (materialsBySol.get(row.id) ?? 0) : null,
          actual_accessories_total: hasBom ? (accessoriesBySol.get(row.id) ?? 0) : null,
          has_bom: hasBom,
          has_substitution: solsWithSub.has(row.id),
        };
      });

      setLines(mapped);
      setLoading(false);
    }
    fetchData();
    return () => { cancelled = true; };
  }, [salesOrderId, organizationId]);

  const analysis = useMemo(() => {
    let plannedFabric = 0;
    let plannedMaterials = 0;
    let plannedLabor = 0;
    let plannedAccessories = 0;
    let plannedServices = 0;
    let plannedCost = 0;

    let actualFabric = 0;
    let actualMaterials = 0;
    let actualLabor = 0;
    let actualAccessories = 0;
    let actualServices = 0;
    let actualCost = 0;

    let totalRevenue = 0;
    let anySubstitution = false;

    interface LineDetail {
      id: string;
      name: string;
      productType: string | null;
      qty: number;
      revenue: number;
      plannedFabric: number;
      plannedMaterials: number;
      plannedLabor: number;
      plannedTotal: number;
      actualFabric: number;
      actualMaterials: number;
      actualLabor: number;
      actualTotal: number;
      variance: number;
      profit: number;
      marginPct: number;
      hasSubstitution: boolean;
      hasBom: boolean;
    }
    const lineDetails: LineDetail[] = [];

    for (const l of lines) {
      const qty = l.quantity;
      const isService = (l.product_type ?? '').toLowerCase() === 'service';
      const pFabric = l.planned_roll_cost * qty;
      const pMaterials = l.planned_bom_cost * qty;
      const pLabor = l.planned_labor_cost * qty;
      const pAccessories = l.planned_accessories_cost * qty;
      const pLineCost = l.planned_unit_cost_total * qty;
      const pServices = isService ? pLineCost : 0;
      const revenue = l.line_total;

      // Actual: live BIL for fabric/materials/accessories when BOM exists; labor stays on planned
      const aFabric = l.has_bom && l.actual_fabric_total != null ? l.actual_fabric_total : pFabric;
      const aMaterials = l.has_bom && l.actual_materials_total != null ? l.actual_materials_total : pMaterials;
      const aLabor = pLabor;
      const aAccessories = l.has_bom && l.actual_accessories_total != null
        ? l.actual_accessories_total
        : pAccessories;
      const aServices = pServices;
      const aLineCost = isService
        ? pLineCost
        : l.has_bom
          ? aFabric + aMaterials + aLabor + aAccessories
          : pLineCost;

      plannedFabric += pFabric;
      plannedMaterials += pMaterials;
      plannedLabor += pLabor;
      plannedAccessories += pAccessories;
      plannedServices += pServices;
      plannedCost += pLineCost;

      actualFabric += aFabric;
      actualMaterials += aMaterials;
      actualLabor += aLabor;
      actualAccessories += aAccessories;
      actualServices += aServices;
      actualCost += aLineCost;
      totalRevenue += revenue;
      if (l.has_substitution) anySubstitution = true;

      const profit = revenue - aLineCost;
      lineDetails.push({
        id: l.id,
        name: l.description || `Line ${l.line_number ?? ''}`,
        productType: l.product_type,
        qty,
        revenue,
        plannedFabric: pFabric,
        plannedMaterials: pMaterials,
        plannedLabor: pLabor,
        plannedTotal: pLineCost,
        actualFabric: aFabric,
        actualMaterials: aMaterials,
        actualLabor: aLabor,
        actualTotal: aLineCost,
        variance: aLineCost - pLineCost,
        profit,
        marginPct: revenue > 0 ? (profit / revenue) * 100 : 0,
        hasSubstitution: l.has_substitution,
        hasBom: l.has_bom,
      });
    }

    const grossProfit = totalRevenue - actualCost;
    const marginPct = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;
    const costVariance = actualCost - plannedCost;

    return {
      plannedFabric,
      plannedMaterials,
      plannedLabor,
      plannedAccessories,
      plannedServices,
      plannedCost,
      actualFabric,
      actualMaterials,
      actualLabor,
      actualAccessories,
      actualServices,
      actualCost,
      totalRevenue,
      grossProfit,
      marginPct,
      costVariance,
      anySubstitution,
      lineDetails,
    };
  }, [lines]);

  const donutData = useMemo(() => {
    const segments = [];
    if (analysis.actualFabric > 0) segments.push({ name: 'Fabric', value: analysis.actualFabric, color: COLORS.fabric });
    if (analysis.actualMaterials > 0) segments.push({ name: 'Materials', value: analysis.actualMaterials, color: COLORS.materials });
    if (analysis.actualLabor > 0) segments.push({ name: 'Labor', value: analysis.actualLabor, color: COLORS.labor });
    if (analysis.actualAccessories > 0) segments.push({ name: 'Accessories', value: analysis.actualAccessories, color: COLORS.accessories });
    if (analysis.actualServices > 0) segments.push({ name: 'Services / Shipping', value: analysis.actualServices, color: COLORS.services });
    if (analysis.grossProfit > 0) segments.push({ name: 'Profit', value: analysis.grossProfit, color: COLORS.profit });
    if (segments.length === 0) segments.push({ name: 'No data', value: 1, color: '#e5e7eb' });
    return segments;
  }, [analysis]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="w-5 h-5 animate-spin text-gray-400 mr-2" />
        <span className="text-sm text-gray-500">Loading performance data…</span>
      </div>
    );
  }

  const hasData = analysis.totalRevenue > 0 || analysis.plannedCost > 0 || analysis.actualCost > 0;

  return (
    <div className="space-y-6 w-full max-w-full">
      {/* Donut + Breakdown */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-start justify-between gap-4 mb-6">
          <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">
            Manufacturing Performance
          </h3>
          {analysis.anySubstitution && (
            <span className="text-[11px] font-medium px-2 py-1 rounded-full bg-violet-100 text-violet-800">
              Includes material substitutions
            </span>
          )}
        </div>
        {!hasData ? (
          <p className="text-sm text-gray-500 py-8 text-center">No line data available to calculate performance.</p>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
            {/* Donut — actual cost mix */}
            <div className="flex flex-col items-center">
              <div className="relative w-64 h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={donutData}
                      cx="50%"
                      cy="50%"
                      innerRadius={70}
                      outerRadius={110}
                      paddingAngle={2}
                      dataKey="value"
                      stroke="none"
                    >
                      {donutData.map((entry, i) => (
                        <Cell key={i} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip
                      formatter={(value) => fmt(Number(value ?? 0), currency)}
                      contentStyle={{ fontSize: '13px', borderRadius: '8px', border: '1px solid #e5e7eb' }}
                      wrapperStyle={{ zIndex: 10 }}
                      position={{ x: 270, y: 100 }}
                    />
                  </PieChart>
                </ResponsiveContainer>
                <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                  <span className="text-xs text-gray-500 uppercase tracking-wide">Total</span>
                  <span className="text-lg font-bold text-gray-900">{fmt(analysis.totalRevenue, currency)}</span>
                </div>
              </div>
              <div className="flex flex-wrap gap-4 mt-4 justify-center">
                {donutData.filter((d) => d.name !== 'No data').map((d) => (
                  <div key={d.name} className="flex items-center gap-1.5 text-xs text-gray-600">
                    <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
                    {d.name}
                  </div>
                ))}
              </div>
            </div>

            {/* Breakdown — Planned | Actual | Variance */}
            <div className="space-y-3">
              <div className="grid grid-cols-[1fr_auto_auto_auto] gap-x-3 text-[10px] uppercase tracking-wide text-gray-400 font-medium px-1">
                <span />
                <span className="text-right w-20">Planned</span>
                <span className="text-right w-20">Actual</span>
                <span className="text-right w-20">Variance</span>
              </div>
              <CostCompareRow
                color={COLORS.fabric}
                label="Fabric"
                sublabel="Roll / textile cost"
                planned={analysis.plannedFabric}
                actual={analysis.actualFabric}
                currency={currency}
              />
              <CostCompareRow
                color={COLORS.materials}
                label="Materials (BOM)"
                sublabel="Tubes, brackets, hardware"
                planned={analysis.plannedMaterials}
                actual={analysis.actualMaterials}
                currency={currency}
              />
              <CostCompareRow
                color={COLORS.labor}
                label="Labor"
                sublabel="Assembly & production"
                planned={analysis.plannedLabor}
                actual={analysis.actualLabor}
                currency={currency}
              />
              {(analysis.plannedAccessories > 0 || analysis.actualAccessories > 0) && (
                <CostCompareRow
                  color={COLORS.accessories}
                  label="Accessories"
                  sublabel="Optional add-ons"
                  planned={analysis.plannedAccessories}
                  actual={analysis.actualAccessories}
                  currency={currency}
                />
              )}
              {(analysis.plannedServices > 0 || analysis.actualServices > 0) && (
                <CostCompareRow
                  color={COLORS.services}
                  label="Services / Shipping"
                  sublabel="Custom line cost"
                  planned={analysis.plannedServices}
                  actual={analysis.actualServices}
                  currency={currency}
                />
              )}
              <div className="border-t border-gray-200 pt-3">
                <CostCompareRow
                  color="#6b7280"
                  label="Total Cost"
                  sublabel="Quote plan vs live BOM"
                  planned={analysis.plannedCost}
                  actual={analysis.actualCost}
                  currency={currency}
                  bold
                />
              </div>
              <BreakdownRow
                color={COLORS.profit}
                label="Gross Profit (actual)"
                sublabel={`Margin: ${analysis.marginPct.toFixed(1)}% · Cost variance ${analysis.costVariance <= 0 ? '' : '+'}${fmt(analysis.costVariance, currency)}`}
                amount={analysis.grossProfit}
                currency={currency}
                highlight
              />
              <div className="border-t border-gray-200 pt-3 space-y-1">
                <div className="flex justify-between text-sm font-bold">
                  <span className="text-gray-900">Total (to Dealer)</span>
                  <span className="text-gray-900 tabular-nums">{fmt(analysis.totalRevenue, currency)}</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Per-line detail table */}
      {hasData && analysis.lineDetails.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider mb-4">Per-Line Detail</h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm table-fixed">
              <colgroup>
                <col style={{ width: '26%' }} />
                <col style={{ width: '5%' }} />
                <col style={{ width: '11%' }} />
                <col style={{ width: '11%' }} />
                <col style={{ width: '11%' }} />
                <col style={{ width: '11%' }} />
                <col style={{ width: '10%' }} />
                <col style={{ width: '8%' }} />
                <col style={{ width: '7%' }} />
              </colgroup>
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 pr-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Line</th>
                  <th className="text-center py-2 px-1 font-medium text-gray-500 text-xs uppercase tracking-wide">Qty</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Planned</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Actual</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Variance</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Revenue</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Profit</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Margin</th>
                  <th className="text-center py-2 pl-2 font-medium text-gray-500 text-xs uppercase tracking-wide" />
                </tr>
              </thead>
              <tbody>
                {analysis.lineDetails.map((d) => (
                  <tr key={d.id} className="border-b border-gray-100 last:border-0">
                    <td className="py-2.5 pr-2 text-gray-900 font-medium truncate" title={d.name}>
                      {d.name}
                      {d.hasSubstitution && (
                        <span className="ml-1.5 text-[10px] font-medium text-violet-700 bg-violet-50 px-1.5 py-0.5 rounded">
                          Substituted
                        </span>
                      )}
                      {!d.hasBom && (
                        <span className="ml-1.5 text-[10px] text-gray-400">(quote plan)</span>
                      )}
                    </td>
                    <td className="py-2.5 px-1 text-center tabular-nums text-gray-600">{d.qty}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.plannedTotal, currency)}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.actualTotal, currency)}</td>
                    <td className={`py-2.5 px-2 text-right tabular-nums font-medium ${d.variance < -0.005 ? 'text-green-700' : d.variance > 0.005 ? 'text-red-600' : 'text-gray-500'}`}>
                      {d.variance > 0 ? '+' : ''}{fmt(d.variance, currency)}
                    </td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.revenue, currency)}</td>
                    <td className={`py-2.5 px-2 text-right tabular-nums font-medium ${d.profit >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                      {fmt(d.profit, currency)}
                    </td>
                    <td className={`py-2.5 px-2 text-right tabular-nums font-medium ${d.marginPct >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                      {d.marginPct.toFixed(1)}%
                    </td>
                    <td />
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t-2 border-gray-300">
                  <td className="py-3 pr-2 font-bold text-gray-900" colSpan={2}>Total</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.plannedCost, currency)}</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.actualCost, currency)}</td>
                  <td className={`py-3 px-2 text-right tabular-nums font-bold ${analysis.costVariance < -0.005 ? 'text-green-700' : analysis.costVariance > 0.005 ? 'text-red-600' : 'text-gray-500'}`}>
                    {analysis.costVariance > 0 ? '+' : ''}{fmt(analysis.costVariance, currency)}
                  </td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.totalRevenue, currency)}</td>
                  <td className={`py-3 px-2 text-right tabular-nums font-bold ${analysis.grossProfit >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                    {fmt(analysis.grossProfit, currency)}
                  </td>
                  <td className={`py-3 px-2 text-right tabular-nums font-bold ${analysis.marginPct >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                    {analysis.marginPct.toFixed(1)}%
                  </td>
                  <td />
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

function CostCompareRow({
  color, label, sublabel, planned, actual, currency, bold,
}: {
  color: string; label: string; sublabel: string; planned: number; actual: number; currency: string; bold?: boolean;
}) {
  const variance = actual - planned;
  return (
    <div className="grid grid-cols-[1fr_auto_auto_auto] gap-x-3 items-start py-1.5">
      <div className="flex items-start gap-2 min-w-0">
        <span className="w-3 h-3 rounded-full mt-0.5 shrink-0" style={{ backgroundColor: color }} />
        <div className="min-w-0">
          <div className={`text-sm ${bold ? 'font-semibold text-gray-900' : 'font-medium text-gray-900'}`}>{label}</div>
          <p className="text-xs text-gray-500 mt-0.5">{sublabel}</p>
        </div>
      </div>
      <span className={`text-sm tabular-nums text-right w-20 ${bold ? 'font-semibold text-gray-900' : 'text-gray-700'}`}>
        {fmt(planned, currency)}
      </span>
      <span className={`text-sm tabular-nums text-right w-20 ${bold ? 'font-semibold text-gray-900' : 'text-gray-700'}`}>
        {fmt(actual, currency)}
      </span>
      <span className={`text-sm tabular-nums text-right w-20 font-medium ${variance < -0.005 ? 'text-green-700' : variance > 0.005 ? 'text-red-600' : 'text-gray-500'}`}>
        {variance > 0 ? '+' : ''}{fmt(variance, currency)}
      </span>
    </div>
  );
}

function BreakdownRow({ color, label, sublabel, amount, currency, highlight }: {
  color: string; label: string; sublabel: string; amount: number; currency: string; highlight?: boolean;
}) {
  return (
    <div className={`flex items-start gap-3 py-2 ${highlight ? 'bg-green-50 -mx-3 px-3 rounded-lg' : ''}`}>
      <span className="w-3 h-3 rounded-full mt-0.5 shrink-0" style={{ backgroundColor: color }} />
      <div className="flex-1 min-w-0">
        <div className="flex justify-between">
          <span className={`text-sm font-medium ${highlight ? 'text-green-800' : 'text-gray-900'}`}>{label}</span>
          <span className={`text-sm font-semibold tabular-nums ${highlight ? 'text-green-800' : 'text-gray-900'}`}>
            {fmt(amount, currency)}
          </span>
        </div>
        <p className="text-xs text-gray-500 mt-0.5">{sublabel}</p>
      </div>
    </div>
  );
}
