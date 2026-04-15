import { useMemo } from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import type { ProposalLine, ProposalLineAddOn } from '../../types/proposals';
import type { QuoteLineInfoForPDF } from '../../hooks/useProposals';

interface Props {
  lines: ProposalLine[];
  quoteLinesMap: Map<string, QuoteLineInfoForPDF>;
  addonsMap: Map<string, ProposalLineAddOn[]>;
  /** Pre-computed sale price per line (same order as `lines`), from computeLineTotal × feeMul */
  lineTotals: number[];
  globalDiscountPct: number;
  globalDiscountAmount: number;
  globalFeePct: number;
  installationDiscountPct: number;
  installationDiscountAmount: number;
  installationFeePct: number;
  totalProduct: number;
  installationTotal: number;
  subtotal: number;
  taxAmount: number;
  total: number;
  currency: string;
}

function fmt(amount: number, currency = 'USD') {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency || 'USD' }).format(amount || 0);
}

const COLORS = {
  materials: '#3b82f6',
  otherCosts: '#f59e0b',
  discounts: '#ef4444',
  profit: '#22c55e',
};

const CATEGORY_LABELS: Record<string, string> = {
  installation: 'Installation',
  delivery: 'Delivery',
  service: 'Service',
  other: 'Other',
};

interface LineDetail {
  id: string;
  name: string;
  type: 'product' | 'custom';
  category?: string;
  dealerCost: number;
  salePrice: number;
  profit: number;
  marginPct: number;
}

export default function ProposalProfitabilityTab({
  lines,
  quoteLinesMap,
  addonsMap,
  lineTotals,
  globalDiscountPct,
  globalDiscountAmount,
  globalFeePct,
  installationDiscountPct,
  installationDiscountAmount,
  installationFeePct,
  totalProduct,
  installationTotal,
  subtotal,
  taxAmount,
  total,
  currency,
}: Props) {
  const analysis = useMemo(() => {
    let materialsCost = 0;
    let customCost = 0;
    const lineDetails: LineDetail[] = [];

    lines.forEach((line, idx) => {
      const salePrice = lineTotals[idx] ?? 0;

      if (line.line_type === 'from_quote' && line.quote_line_id) {
        const ql = quoteLinesMap.get(line.quote_line_id);
        if (!ql) return;
        const dealerCost = ql.dealer_price_total ?? 0;
        materialsCost += dealerCost;

        lineDetails.push({
          id: line.id,
          name: ql.name || ql.sku || 'Product',
          type: 'product',
          dealerCost,
          salePrice,
          profit: salePrice - dealerCost,
          marginPct: salePrice > 0 ? ((salePrice - dealerCost) / salePrice) * 100 : 0,
        });
      } else if (line.line_type === 'custom') {
        const qty = Number(line.qty ?? 1) || 1;
        const cost = (Number(line.unit_cost ?? 0) || 0) * qty;
        customCost += cost;

        lineDetails.push({
          id: line.id,
          name: line.description || CATEGORY_LABELS[line.custom_category ?? ''] || 'Custom',
          type: 'custom',
          category: line.custom_category ?? undefined,
          dealerCost: cost,
          salePrice,
          profit: salePrice - cost,
          marginPct: salePrice > 0 ? ((salePrice - cost) / salePrice) * 100 : 0,
        });
      }
    });

    // Installation addons cost
    let installCost = 0;
    for (const [lineId, addons] of addonsMap) {
      const line = lines.find((l) => l.id === lineId);
      const ql = line?.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
      const lineQty = Number(line?.qty ?? ql?.quantity ?? 1) || 1;
      addons.forEach((a) => {
        if (a.addon_type === 'installation') {
          installCost += (Number(a.cost_amount) || 0) * lineQty;
        }
      });
    }
    customCost += installCost;

    const totalDiscounts = globalDiscountAmount + installationDiscountAmount;
    const totalCost = materialsCost + customCost;
    const saleBeforeTax = subtotal;
    const grossProfit = saleBeforeTax - totalCost;
    const marginPct = saleBeforeTax > 0 ? (grossProfit / saleBeforeTax) * 100 : 0;

    return {
      materialsCost,
      customCost,
      totalDiscounts,
      totalCost,
      grossProfit,
      marginPct,
      saleBeforeTax,
      lineDetails,
    };
  }, [lines, quoteLinesMap, addonsMap, lineTotals, globalDiscountAmount, installationDiscountAmount, subtotal]);

  const donutData = useMemo(() => {
    const segments = [];
    if (analysis.materialsCost > 0) {
      segments.push({ name: 'Materials', value: analysis.materialsCost, color: COLORS.materials });
    }
    if (analysis.customCost > 0) {
      segments.push({ name: 'Other Costs', value: analysis.customCost, color: COLORS.otherCosts });
    }
    if (analysis.totalDiscounts > 0) {
      segments.push({ name: 'Discounts', value: analysis.totalDiscounts, color: COLORS.discounts });
    }
    if (analysis.grossProfit > 0) {
      segments.push({ name: 'Profit', value: analysis.grossProfit, color: COLORS.profit });
    }
    if (segments.length === 0) {
      segments.push({ name: 'No data', value: 1, color: '#e5e7eb' });
    }
    return segments;
  }, [analysis]);

  const hasData = analysis.saleBeforeTax > 0 || analysis.totalCost > 0;

  return (
    <div className="space-y-6 w-full max-w-full">
      {/* Donut + Breakdown */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider mb-6">Project Performance</h3>
        {!hasData ? (
          <p className="text-sm text-gray-500 py-8 text-center">No line data available to calculate profitability.</p>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
            {/* Donut chart */}
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
                    />
                  </PieChart>
                </ResponsiveContainer>
                {/* Center label */}
                <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                  <span className="text-xs text-gray-500 uppercase tracking-wide">Sale</span>
                  <span className="text-lg font-bold text-gray-900">{fmt(analysis.saleBeforeTax, currency)}</span>
                </div>
              </div>
              {/* Legend */}
              <div className="flex flex-wrap gap-4 mt-4 justify-center">
                {donutData.filter(d => d.name !== 'No data').map((d) => (
                  <div key={d.name} className="flex items-center gap-1.5 text-xs text-gray-600">
                    <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
                    {d.name}
                  </div>
                ))}
              </div>
            </div>

            {/* Breakdown summary */}
            <div className="space-y-3">
              <BreakdownRow
                color={COLORS.materials}
                label="Materials (Dealer Cost)"
                sublabel="Product cost from manufacturer"
                amount={analysis.materialsCost}
                currency={currency}
              />
              <BreakdownRow
                color={COLORS.otherCosts}
                label="Other Costs"
                sublabel="Installation, Delivery, Service"
                amount={analysis.customCost}
                currency={currency}
              />
              <div className="border-t border-gray-200 pt-3">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600 font-medium">Total Cost</span>
                  <span className="font-semibold text-gray-900 tabular-nums">{fmt(analysis.totalCost, currency)}</span>
                </div>
              </div>
              <BreakdownRow
                color={COLORS.discounts}
                label="Discounts Given"
                sublabel={[
                  globalDiscountPct > 0 ? `Global ${globalDiscountPct}%` : null,
                  installationDiscountPct > 0 ? `Labor ${installationDiscountPct}%` : null,
                ].filter(Boolean).join(' + ') || 'None'}
                amount={analysis.totalDiscounts}
                currency={currency}
                negative
              />
              <BreakdownRow
                color={COLORS.profit}
                label="Gross Profit"
                sublabel={`Margin: ${analysis.marginPct.toFixed(1)}%`}
                amount={analysis.grossProfit}
                currency={currency}
                highlight
              />
              <div className="border-t border-gray-200 pt-3 space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Sale (before tax)</span>
                  <span className="font-semibold text-gray-900 tabular-nums">{fmt(analysis.saleBeforeTax, currency)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Tax</span>
                  <span className="tabular-nums text-gray-700">{fmt(taxAmount, currency)}</span>
                </div>
                <div className="flex justify-between text-sm font-bold">
                  <span className="text-gray-900">Total ({currency})</span>
                  <span className="text-gray-900 tabular-nums">{fmt(total, currency)}</span>
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
                <col style={{ width: '35%' }} />
                <col style={{ width: '11%' }} />
                <col style={{ width: '14%' }} />
                <col style={{ width: '14%' }} />
                <col style={{ width: '14%' }} />
                <col style={{ width: '12%' }} />
              </colgroup>
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 pr-3 font-medium text-gray-500 text-xs uppercase tracking-wide">Line</th>
                  <th className="text-left py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Type</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Cost</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Sale</th>
                  <th className="text-right py-2 px-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Profit</th>
                  <th className="text-right py-2 pl-2 font-medium text-gray-500 text-xs uppercase tracking-wide">Margin</th>
                </tr>
              </thead>
              <tbody>
                {analysis.lineDetails.map((d) => (
                  <tr key={d.id} className="border-b border-gray-100 last:border-0">
                    <td className="py-2.5 pr-3 text-gray-900 font-medium truncate">{d.name}</td>
                    <td className="py-2.5 px-2 text-gray-500">
                      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${
                        d.type === 'product' ? 'bg-blue-50 text-blue-700' : 'bg-amber-50 text-amber-700'
                      }`}>
                        {d.type === 'product' ? 'Product' : CATEGORY_LABELS[d.category ?? ''] || 'Custom'}
                      </span>
                    </td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.dealerCost, currency)}</td>
                    <td className="py-2.5 px-2 text-right tabular-nums text-gray-700">{fmt(d.salePrice, currency)}</td>
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
                  <td className="py-3 pr-3 font-bold text-gray-900" colSpan={2}>Total</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.totalCost, currency)}</td>
                  <td className="py-3 px-2 text-right tabular-nums font-bold text-gray-900">{fmt(analysis.saleBeforeTax, currency)}</td>
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

function BreakdownRow({ color, label, sublabel, amount, currency, negative, highlight }: {
  color: string; label: string; sublabel: string; amount: number; currency: string; negative?: boolean; highlight?: boolean;
}) {
  return (
    <div className={`flex items-start gap-3 py-2 ${highlight ? 'bg-green-50 -mx-3 px-3 rounded-lg' : ''}`}>
      <span className="w-3 h-3 rounded-full mt-0.5 shrink-0" style={{ backgroundColor: color }} />
      <div className="flex-1 min-w-0">
        <div className="flex justify-between">
          <span className={`text-sm font-medium ${highlight ? 'text-green-800' : 'text-gray-900'}`}>{label}</span>
          <span className={`text-sm font-semibold tabular-nums ${negative ? 'text-red-600' : highlight ? 'text-green-800' : 'text-gray-900'}`}>
            {negative && amount > 0 ? '-' : ''}{fmt(amount, currency)}
          </span>
        </div>
        <p className="text-xs text-gray-500 mt-0.5">{sublabel}</p>
      </div>
    </div>
  );
}

