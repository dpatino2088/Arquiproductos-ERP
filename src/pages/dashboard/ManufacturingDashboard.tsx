import { useMemo } from 'react';
import {
  Wrench,
  Play,
  PackageCheck,
  Clock,
  ArrowRight,
  Layers,
} from 'lucide-react';
import { useManufacturingOrders } from '../../hooks/useManufacturing';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';

const OPEN_STATUSES = ['draft', 'confirmed', 'procurement', 'material_available', 'materials_ready', 'in_production'];
const IN_PRODUCTION = ['in_production'];
const READY_STATUSES = ['ready_for_delivery'];
const DELIVERED_STATUSES = ['delivered'];

function KpiCard({
  icon: Icon,
  title,
  value,
  sub,
  loading,
  accent,
}: {
  icon: React.ElementType;
  title: string;
  value: string | number;
  sub?: string;
  loading?: boolean;
  accent?: 'blue' | 'amber' | 'green' | 'purple';
}) {
  const colors = {
    blue: 'text-blue-600',
    amber: 'text-amber-500',
    green: 'text-green-600',
    purple: 'text-purple-600',
  };
  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-all duration-200 hover:border-primary/20">
      <div className="flex items-center justify-between mb-4">
        <Icon className={`h-8 w-8 ${colors[accent ?? 'blue']}`} />
        <div className="text-right">
          <div className="text-2xl font-bold text-foreground">{loading ? '...' : value}</div>
          {sub && <div className="text-sm text-muted-foreground">{sub}</div>}
        </div>
      </div>
      <div className="text-sm font-medium text-muted-foreground">{title}</div>
    </div>
  );
}

export default function ManufacturingDashboard() {
  const { manufacturingOrders, loading } = useManufacturingOrders();

  const kpis = useMemo(() => {
    const mos = manufacturingOrders ?? [];
    return {
      open: mos.filter((m) => OPEN_STATUSES.includes(m.status)).length,
      inProduction: mos.filter((m) => IN_PRODUCTION.includes(m.status)).length,
      readyForDelivery: mos.filter((m) => READY_STATUSES.includes(m.status)).length,
      delivered: mos.filter((m) => DELIVERED_STATUSES.includes(m.status)).length,
    };
  }, [manufacturingOrders]);

  const activeMOs = useMemo(
    () =>
      (manufacturingOrders ?? [])
        .filter((m) => !['delivered', 'cancelled', 'archived'].includes(m.status))
        .slice(0, 10),
    [manufacturingOrders]
  );

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-title font-semibold text-foreground">Manufacturing Dashboard</h1>
        <p className="text-sm text-muted-foreground mt-1">Production Overview</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <KpiCard
          icon={Layers}
          title="Open Orders"
          value={kpis.open}
          sub="All active stages"
          loading={loading}
          accent="blue"
        />
        <KpiCard
          icon={Play}
          title="In Production"
          value={kpis.inProduction}
          sub="Currently running"
          loading={loading}
          accent="amber"
        />
        <KpiCard
          icon={PackageCheck}
          title="Ready for Delivery"
          value={kpis.readyForDelivery}
          sub="Pending dispatch"
          loading={loading}
          accent="green"
        />
        <KpiCard
          icon={Clock}
          title="Delivered"
          value={kpis.delivered}
          sub="This period"
          loading={loading}
          accent="purple"
        />
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <Wrench className="h-5 w-5 text-primary" />
            <h2 className="text-heading font-semibold">Active Manufacturing Orders</h2>
          </div>
          <button
            type="button"
            onClick={() => router.navigate('/manufacturing/manufacturing-orders')}
            className="flex items-center gap-1 text-xs text-primary hover:underline"
          >
            View all <ArrowRight className="w-3 h-3" />
          </button>
        </div>

        {loading ? (
          <div className="text-sm text-muted-foreground">Loading...</div>
        ) : activeMOs.length === 0 ? (
          <div className="text-sm text-muted-foreground">No active manufacturing orders.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-gray-500 border-b border-gray-200">
                  <th className="pb-2 pr-4">MO #</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 pr-4">Priority</th>
                  <th className="pb-2 pr-4">Customer</th>
                  <th className="pb-2">Scheduled Start</th>
                </tr>
              </thead>
              <tbody>
                {activeMOs.map((mo) => (
                  <tr
                    key={mo.id}
                    className="border-b border-gray-100 hover:bg-gray-50 cursor-pointer transition-colors"
                    onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                  >
                    <td className="py-2.5 pr-4 font-medium">{mo.manufacturing_order_no}</td>
                    <td className="py-2.5 pr-4">
                      <StatusBadge status={mo.status} type="manufacturing" size="sm" />
                    </td>
                    <td className="py-2.5 pr-4 capitalize text-muted-foreground">{mo.priority ?? 'normal'}</td>
                    <td className="py-2.5 pr-4 text-muted-foreground">
                      {mo.SalesOrders?.DirectoryCustomers?.customer_name ?? 'N/A'}
                    </td>
                    <td className="py-2.5 text-muted-foreground">
                      {mo.planned_start_at
                        ? new Date(mo.planned_start_at).toLocaleDateString()
                        : 'Not scheduled'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
