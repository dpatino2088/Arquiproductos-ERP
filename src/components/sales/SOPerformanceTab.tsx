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
  roll_cost: number;
  bom_cost: number;
  labor_cost: number;
  accessories_cost: number;
  unit_cost_total: number;
}

function fmt(amount: number, currency = 'USD') {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency || 'USD' }).format(amount || 0);
}

const COLORS = {
  fabric: '#3b82f6',
  materials: '#8b5cf6',
  labor: '#f59e0b',
  accessories: '#06b6d4',
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
      const qlMap = new Map<string, any>();

      if (qlIds.length > 0) {
        const { data: qlRows } = await supabase
          .from('QuoteLines')
          .select('id, roll_cost_snapshot, bom_cost_snapshot, labor_cost_snapshot, accessories_cost_snapshot, unit_cost_total_snapshot')
          .in('id', qlIds);
        if (cancelled) return;
        (qlRows ?? []).forEach((q: any) => qlMap.set(q.id, q));
      }

      const mapped: SOLineWithCosts[] = solRows.map((row: any) => {
        const ql = row.quote_line_id ? qlMap.get(row.quote_line_id) : null;
        return {
          id: row.id,
          line_number: row.line_number,
          description: row.description,
          product_type: row.product_type,
          quantity: Number(row.quantity) || 0,
          unit_price: Number(row.unit_price) || 0,
          line_total: Number(row.line_total) || 0,
          roll_cost: Number(ql?.roll_cost_snapshot ?? 0),
          bom_cost: Number(ql?.bom_cost_snapshot ?? 0),
          labor_cost: Number(ql?.labor_cost_snapshot ?? 0),
          accessories_cost: Number(ql?.accessories_cost_snapshot ?? 0),
          unit_cost_total: Number(ql?.unit_cost_total_snapshot ?? 0),
        };
      });

      setLines(mapped);
      setLoading(false);
    }
    fetchData();
    return () => { cancelled = true; };
  }, [salesOrderId, organizationId]);

  const analysis = useMemo(() => {
    let totalFabric = 0;
    let totalMaterials = 0;
    let totalLabor = 0;
    let totalAccessories = 0;
    let totalCost = 0;
    let totalRevenue = 0;

    interface LineDetail {
      id: string;
      name: string;
      productType: string | null;
      qty: number;
      revenue: number;
      fabricCost: number;
      materialsCost: number;
      laborCost: number;
      accessoriesCost: number;
      totalLineCost: number;
      profit: number;
      marginPct: number;
    }
    const lineDetails: LineDetail[] = [];

    for (const l of lines) {
      const qty = l.quantity;
      const fabricCost = l.roll_cost * qty;
      const materialsCost = l.bom_cost * qty;
      const laborCost = l.labor_cost * qty;
      const accessoriesCost = l.accessories_cost * qty;
      const lineCost = l.unit_cost_total * qty;
      const revenue = l.line_total;

      totalFabric += fabricCost;
      totalMaterials += materialsCost;
      totalLabor += laborCost;
      totalAccessories += accessoriesCost;
      totalCost += lineCost;
      totalRevenue += revenue;

      const profit = revenue - lineCost;
      lineDetails.push({
        id: l.id,
        name: l.description || `Line ${l.line_number ?? ''}`,
        productType: l.product_type,
        qty,
        revenue,
        fabricCost,
        materialsCost,
        laborCost,
        accessoriesCost,
        totalLineCost: lineCost,
        profit,
        marginPct: revenue > 0 ? (profit / revenue) * 100 : 0,
      });
    }

    const grossProfit = totalRevenue - totalCost;
    const marginPct = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;

    return {
      totalFabric,
      totalMaterials,
      totalLabor,
      totalAccessories,
      totalCost,
      totalRevenue,
      grossProfit,
      marginPct,
      lineDetails,
    };
  }, [lines]);

  const donutData = useMemo(() => {
    const segments = [];
    if (analysis.totalFabric > 0) segments.push({ name: 'Fabric', value: analysis.totalFabric, color: COLORS.fabric });
    if (analysis.totalMaterials > 0) segments.push({ name: 'Materials', value: analysis.totalMaterials, color: COLORS.materials });
    if (analysis.totalLabor > 0) segments.push({ name: 'Labor', value: analysis.totalLabor, color: COLORS.labor });
    if (analysis.totalAccessories > 0) segments.push({ name: 'Accessories', value: analysis.totalAccessories, color: COLORS.accessories });
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

  const hasData = analysis.totalRevenue > 0 || analysis.totalCost > 0;

  return (
    <div className="space-y-6 w-full max-w-full">
      {/* Donut + Breakdown */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider mb-6">
          Manufacturing Performance
        </h3>
        {!hasData ? (
          <p className="text-sm text-gray-500 py-8 text-center">No line data available to calculate performance.</p>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
            {/* Donut */}
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
                      formatter={(value: number) => fmt(value, currency)}
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

            {/* Breakdown */}
            <div className="space-y-3">
              <BreakdownRow
                color={COLORS.fabric}
                label="Fabric"
                sublabel="Roll / textile cost"
                amount={analysis.totalFabric}
                currency={currency}
              />
              <BreakdownRow
                color={COLORS.materials}
                label="Materials (BOM)"
                sublabel="Tubes, brackets, hardware"
                amount={analysis.totalMaterials}
                currency={currency}
              />
              <BreakdownRow
                color={COLORS.labor}
                label="Labor"
                sublabel="Assembly & production"
                amount={analysis.totalLabor}
                currency={currency}
              />
              {analysis.totalAccessories > 0 && (
                <BreakdownRow
                  color={COLORS.accessories}
                  label="Accessories"
                  sublabel="Optional add-ons"
                  amount={analysis.totalAccessories}
                  currency={currency}
                />
              )}
              <div className="border-t border-gray-200 pt-3">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600 font-medium">Total Cost</span>
                  <span className="font-semibold text-gray-900 tabular-nums">{fmt(analysis.totalCost, currency)}</span>
                </div>
              </div>
              <BreakdownRow
                color={COLORS.profit}
                label="Gross Profit"
                sublabel={`Margin: ${analysis.marginPct.toFixed(1)}%`}
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
                <col style={{ width: '28%' }} />
                <col style={{ width: '6%' }} />
                <col style={{ width: '12%' }} />
                <col style={{ width: '12%' }} />
                <col style={{ width: '12%' }} />
                <col style={{ width: '12%' }} />
                <col style={{ width: '10%' }} />
                <col style={{ width: '8%' }} />
              </colgroup>
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 pr-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Line</th>
                  <th className="text-center py-2 px-1 font-medium text-gray-500 text-xs uppercase tracking-wide">Qty</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Fabric</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Materials</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Labor</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Total</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Profit</th>
                  <th className="text-right py-2 pl-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Margin</th>
                </tr>
              </thead>
              <tbody>
                {analysis.lineDetails.map((d) => (
                  <tr key={d.id} className="border-b border-gray-100 last:border-0">
                    <td className="py-2.5 pr-2 text-gray-900 font-medium truncate" title={d.name}>{d.name}</td>
                    <td className="py-2.5 px-1 text-center tabular-nums text-gray-600">{d.qty}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.fabricCost, currency)}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.materialsCost, currency)}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.laborCost, currency)}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.revenue, currency)}</td>
                    <td className={`py-2.5 px-2 text-right tabular-nums font-medium ${d.profit >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                      {fmt(d.profit, currency)}
                    </td>
                    <td className={`py-2.5 pl-2 text-right tabular-nums font-medium ${d.marginPct >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                      {d.marginPct.toFixed(1)}%
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t-2 border-gray-300">
                  <td className="py-3 pr-2 font-bold text-gray-900" colSpan={2}>Total</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.totalFabric, currency)}</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.totalMaterials, currency)}</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.totalLabor, currency)}</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.totalRevenue, currency)}</td>
                  <td className={`py-3 px-2 text-right tabular-nums font-bold ${analysis.grossProfit >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                    {fmt(analysis.grossProfit, currency)}
                  </td>
                  <td className={`py-3 pl-2 text-right tabular-nums font-bold ${analysis.marginPct >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                    {analysis.marginPct.toFixed(1)}%
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}
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
