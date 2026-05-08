import { useEffect, useMemo, useState } from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import { Loader2 } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';

interface Props {
  quoteId: string;
  organizationId: string;
  taxAmount?: number;
  currency?: string;
}

interface QuoteLinePerf {
  id: string;
  name: string | null;
  product_type: string | null;
  quantity: number;
  dealer_price_total: number | null;
  msrp: number | null;
  roll_cost_snapshot: number | null;
  bom_cost_snapshot: number | null;
  labor_cost_snapshot: number | null;
  accessories_cost_snapshot: number | null;
  unit_cost_total_snapshot: number | null;
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

export default function QuotePerformanceTab({
  quoteId,
  organizationId,
  taxAmount = 0,
  currency = 'USD',
}: Props) {
  const [lines, setLines] = useState<QuoteLinePerf[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function fetchData() {
      setLoading(true);
      const { data, error } = await supabase
        .from('QuoteLines')
        .select(`
          id, name, product_type, quantity, dealer_price_total, msrp,
          roll_cost_snapshot, bom_cost_snapshot, labor_cost_snapshot,
          accessories_cost_snapshot, unit_cost_total_snapshot
        `)
        .eq('quote_id', quoteId)
        .eq('organization_id', organizationId)
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: true });

      if (cancelled) return;

      if (error || !data) {
        console.warn('[QuotePerformanceTab] lines fetch error:', error);
        setLines([]);
        setLoading(false);
        return;
      }

      setLines(
        (data as any[]).map((r) => ({
          id: r.id,
          name: r.name ?? null,
          product_type: r.product_type ?? null,
          quantity: Number(r.quantity) || 0,
          dealer_price_total: r.dealer_price_total != null ? Number(r.dealer_price_total) : null,
          msrp: r.msrp != null ? Number(r.msrp) : null,
          roll_cost_snapshot: r.roll_cost_snapshot != null ? Number(r.roll_cost_snapshot) : null,
          bom_cost_snapshot: r.bom_cost_snapshot != null ? Number(r.bom_cost_snapshot) : null,
          labor_cost_snapshot: r.labor_cost_snapshot != null ? Number(r.labor_cost_snapshot) : null,
          accessories_cost_snapshot: r.accessories_cost_snapshot != null ? Number(r.accessories_cost_snapshot) : null,
          unit_cost_total_snapshot: r.unit_cost_total_snapshot != null ? Number(r.unit_cost_total_snapshot) : null,
        }))
      );
      setLoading(false);
    }
    fetchData();
    return () => {
      cancelled = true;
    };
  }, [quoteId, organizationId]);

  const analysis = useMemo(() => {
    let totalFabric = 0;
    let totalMaterials = 0;
    let totalLabor = 0;
    let totalAccessories = 0;
    let totalCost = 0;
    let totalRevenue = 0; // Before tax

    const lineDetails = lines.map((l, idx) => {
      const qty = l.quantity || 0;
      const revenue = Number(l.dealer_price_total ?? l.msrp ?? 0) || 0;
      const fabricCost = (Number(l.roll_cost_snapshot ?? 0) || 0) * qty;
      const materialsCost = (Number(l.bom_cost_snapshot ?? 0) || 0) * qty;
      const laborCost = (Number(l.labor_cost_snapshot ?? 0) || 0) * qty;
      const accessoriesCost = (Number(l.accessories_cost_snapshot ?? 0) || 0) * qty;
      const lineCost = (Number(l.unit_cost_total_snapshot ?? 0) || 0) * qty;

      totalFabric += fabricCost;
      totalMaterials += materialsCost;
      totalLabor += laborCost;
      totalAccessories += accessoriesCost;
      totalCost += lineCost;
      totalRevenue += revenue;

      const profit = revenue - lineCost;
      const marginPct = revenue > 0 ? (profit / revenue) * 100 : 0;

      return {
        id: l.id,
        name: l.name || `Line ${idx + 1}`,
        productType: l.product_type,
        qty,
        revenue,
        fabricCost,
        materialsCost,
        laborCost,
        accessoriesCost,
        totalLineCost: lineCost,
        profit,
        marginPct,
      };
    });

    const grossProfit = totalRevenue - totalCost;
    const marginPct = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;
    const totalWithTax = totalRevenue + (Number(taxAmount) || 0);

    return {
      totalFabric,
      totalMaterials,
      totalLabor,
      totalAccessories,
      totalCost,
      totalRevenue,
      totalWithTax,
      grossProfit,
      marginPct,
      lineDetails,
    };
  }, [lines, taxAmount]);

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
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider mb-6">Project Performance</h3>
        {!hasData ? (
          <p className="text-sm text-gray-500 py-8 text-center">No line data available to calculate performance.</p>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
            <div className="flex flex-col items-center">
              <div className="relative w-64 h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={donutData} cx="50%" cy="50%" innerRadius={70} outerRadius={110} paddingAngle={2} dataKey="value" stroke="none">
                      {donutData.map((entry, i) => (
                        <Cell key={i} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(value) => fmt(Number(value ?? 0), currency)} contentStyle={{ fontSize: '13px', borderRadius: '8px', border: '1px solid #e5e7eb' }} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                  <span className="text-xs text-gray-500 uppercase tracking-wide">Net Sale</span>
                  <span className="text-lg font-bold text-gray-900">{fmt(analysis.totalRevenue, currency)}</span>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <BreakdownRow color={COLORS.fabric} label="Fabric" sublabel="Roll / textile cost" amount={analysis.totalFabric} currency={currency} />
              <BreakdownRow color={COLORS.materials} label="Materials (BOM)" sublabel="Tubes, brackets, hardware" amount={analysis.totalMaterials} currency={currency} />
              <BreakdownRow color={COLORS.labor} label="Labor" sublabel="Assembly & production" amount={analysis.totalLabor} currency={currency} />
              {analysis.totalAccessories > 0 && (
                <BreakdownRow color={COLORS.accessories} label="Accessories" sublabel="Optional add-ons" amount={analysis.totalAccessories} currency={currency} />
              )}
              <div className="border-t border-gray-200 pt-3">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600 font-medium">Total Cost</span>
                  <span className="font-semibold text-gray-900 tabular-nums">{fmt(analysis.totalCost, currency)}</span>
                </div>
              </div>
              <BreakdownRow color={COLORS.profit} label="Gross Profit" sublabel={`Margin: ${analysis.marginPct.toFixed(1)}%`} amount={analysis.grossProfit} currency={currency} highlight />
              <div className="border-t border-gray-200 pt-3 space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Sale (before tax)</span>
                  <span className="font-semibold text-gray-900 tabular-nums">{fmt(analysis.totalRevenue, currency)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Tax</span>
                  <span className="tabular-nums text-gray-700">{fmt(Number(taxAmount) || 0, currency)}</span>
                </div>
                <div className="flex justify-between text-sm font-bold">
                  <span className="text-gray-900">Total ({currency})</span>
                  <span className="text-gray-900 tabular-nums">{fmt(analysis.totalWithTax, currency)}</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function BreakdownRow({
  color,
  label,
  sublabel,
  amount,
  currency,
  highlight,
}: {
  color: string;
  label: string;
  sublabel: string;
  amount: number;
  currency: string;
  highlight?: boolean;
}) {
  return (
    <div className={`flex items-start gap-3 py-2 ${highlight ? 'bg-green-50 -mx-3 px-3 rounded-lg' : ''}`}>
      <span className="w-3 h-3 rounded-full mt-0.5 shrink-0" style={{ backgroundColor: color }} />
      <div className="flex-1 min-w-0">
        <div className="flex justify-between">
          <span className={`text-sm font-medium ${highlight ? 'text-green-800' : 'text-gray-900'}`}>{label}</span>
          <span className={`text-sm font-semibold tabular-nums ${highlight ? 'text-green-800' : 'text-gray-900'}`}>{fmt(amount, currency)}</span>
        </div>
        <p className="text-xs text-gray-500 mt-0.5">{sublabel}</p>
      </div>
    </div>
  );
}
