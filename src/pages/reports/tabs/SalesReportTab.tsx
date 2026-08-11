import { useMemo } from 'react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { CheckCircle, Clock, DollarSign, Package, ReceiptText, TrendingUp } from 'lucide-react';
import { deltaPct, useReport, type ReportDateRange, type SalesSummaryReport } from '../../../hooks/useReports';
import { formatCurrency } from '../../../lib/utils';
import { CHART_COLORS, CsvButton, EmptyState, KpiCard, moneyTotalFormatter, Panel } from '../reportUi';

export default function SalesReportTab({ range, active }: { range: ReportDateRange; active: boolean }) {
  const { data, previousData, isInitialLoading, isRefreshing, error } = useReport<SalesSummaryReport>(
    'sales',
    range,
    { withPrevious: true, enabled: active }
  );

  const funnel = data?.funnel;

  const funnelSteps = useMemo(() => {
    if (!funnel) return [];
    const base = Math.max(funnel.quotes_created, 1);
    return [
      { label: 'Quotes created', value: funnel.quotes_created, pct: 100 },
      {
        label: 'Proposals created',
        value: funnel.proposals_created,
        pct: Math.round((funnel.proposals_created / base) * 100),
      },
      {
        label: 'Proposals accepted',
        value: funnel.proposals_accepted,
        pct: Math.round((funnel.proposals_accepted / base) * 100),
      },
      {
        label: 'Sales Orders',
        value: funnel.orders_created,
        pct: Math.round((funnel.orders_created / base) * 100),
      },
    ];
  }, [funnel]);

  const monthlyCsv = useMemo(
    () => (data?.monthly ?? []).map((m) => ({ month: m.month, total: m.total, orders: m.orders })),
    [data]
  );

  return (
    <div className="space-y-6">
      {error ? <p className="text-xs text-status-red">Report error: {error}</p> : null}
      {isRefreshing ? <p className="text-xs text-muted-foreground">Updating…</p> : null}

      {/* KPI cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <KpiCard
          title="Total Sales"
          value={formatCurrency(data?.total_sales ?? 0)}
          delta={deltaPct(data?.total_sales, previousData?.total_sales)}
          icon={DollarSign}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Sales Orders"
          value={String(data?.orders_count ?? 0)}
          delta={deltaPct(data?.orders_count, previousData?.orders_count)}
          icon={Package}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Avg Ticket"
          value={formatCurrency(data?.avg_ticket ?? 0)}
          delta={deltaPct(data?.avg_ticket, previousData?.avg_ticket)}
          icon={TrendingUp}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Avg Cycle (Quote → Order)"
          value={`${funnel?.avg_cycle_days ?? 0} days`}
          icon={Clock}
          loading={isInitialLoading}
        />
      </div>

      {/* Monthly trend + status mix */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <Panel
            title="Monthly Sales"
            subtitle="Sales Orders total by month"
            action={<CsvButton filename={`sales-monthly-${range.from}-${range.to}.csv`} rows={monthlyCsv} />}
          >
            {(data?.monthly?.length ?? 0) === 0 ? (
              <EmptyState message="No sales in this period" />
            ) : (
              <ResponsiveContainer width="100%" height={280}>
                <AreaChart data={data!.monthly} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
                  <defs>
                    <linearGradient id="salesGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={CHART_COLORS[0]} stopOpacity={0.25} />
                      <stop offset="100%" stopColor={CHART_COLORS[0]} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                  <XAxis dataKey="month" tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
                  <YAxis
                    tick={{ fontSize: 11 }}
                    tickLine={false}
                    axisLine={false}
                    tickFormatter={(v: number) => `$${v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}`}
                  />
                  <Tooltip formatter={moneyTotalFormatter} />
                  <Area
                    type="monotone"
                    dataKey="total"
                    stroke={CHART_COLORS[0]}
                    strokeWidth={2}
                    fill="url(#salesGradient)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </Panel>
        </div>

        <Panel title="Order Status" subtitle="Active orders by status">
          {(data?.status_mix?.length ?? 0) === 0 ? (
            <EmptyState message="No orders in this period" />
          ) : (
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie
                  data={data!.status_mix}
                  dataKey="count"
                  nameKey="status"
                  innerRadius={55}
                  outerRadius={90}
                  paddingAngle={2}
                  label={({ name, value }) => `${String(name).replace(/_/g, ' ')} (${value})`}
                  labelLine={false}
                >
                  {data!.status_mix.map((_, i) => (
                    <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          )}
        </Panel>
      </div>

      {/* Conversion funnel */}
      <Panel
        title="Conversion Funnel"
        subtitle={`Quote → Proposal → Sales Order · conversion ${funnel?.quote_to_order_pct ?? 0}%`}
      >
        {funnelSteps.length === 0 ? (
          <EmptyState message="No activity in this period" />
        ) : (
          <div className="space-y-3">
            {funnelSteps.map((step, i) => {
              const icons = [ReceiptText, ReceiptText, CheckCircle, Package];
              const Icon = icons[i] ?? ReceiptText;
              return (
                <div key={step.label} className="flex items-center gap-4">
                  <div className="flex items-center gap-2 w-48 shrink-0">
                    <Icon className="h-4 w-4 text-primary" />
                    <span className="text-sm font-medium">{step.label}</span>
                  </div>
                  <div className="flex-1 h-6 bg-gray-100 rounded-md overflow-hidden">
                    <div
                      className="h-full rounded-md transition-all duration-500"
                      style={{
                        width: `${Math.max(step.pct, 2)}%`,
                        backgroundColor: CHART_COLORS[i % CHART_COLORS.length],
                        opacity: 0.85,
                      }}
                    />
                  </div>
                  <div className="w-28 shrink-0 text-right text-sm tabular-nums">
                    <span className="font-semibold">{step.value}</span>
                    <span className="text-muted-foreground ml-1.5">{step.pct}%</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </Panel>
    </div>
  );
}
