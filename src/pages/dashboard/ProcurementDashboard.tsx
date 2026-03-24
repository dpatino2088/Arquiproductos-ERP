import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  ShoppingCart,
  PackageCheck,
  AlertTriangle,
  ClipboardList,
  ArrowRight,
} from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { usePurchaseOrders } from '../../hooks/usePurchaseOrders';
import { formatCurrency } from '../../lib/utils';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';

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
  accent?: 'blue' | 'amber' | 'green' | 'red';
}) {
  const colors = {
    blue: 'text-blue-600',
    amber: 'text-amber-500',
    green: 'text-green-600',
    red: 'text-red-500',
  };
  const iconColor = colors[accent ?? 'blue'];
  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-all duration-200 hover:border-primary/20">
      <div className="flex items-center justify-between mb-4">
        <Icon className={`h-8 w-8 ${iconColor}`} />
        <div className="text-right">
          <div className="text-2xl font-bold text-foreground">{loading ? '...' : value}</div>
          {sub && <div className="text-sm text-muted-foreground">{sub}</div>}
        </div>
      </div>
      <div className="text-sm font-medium text-muted-foreground">{title}</div>
    </div>
  );
}

export default function ProcurementDashboard() {
  const { activeOrganizationId } = useOrganizationContext();

  const { purchaseOrders, loading: posLoading } = usePurchaseOrders();

  const shortageQuery = useQuery({
    queryKey: ['procurement-dashboard-shortage', activeOrganizationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('manufacturing_order_material_demand')
        .select('catalog_item_id, sku, need_to_buy')
        .eq('organization_id', activeOrganizationId!)
        .gt('need_to_buy', 0);
      if (error) throw error;

      // Group by catalog item, sum need_to_buy
      const byItem: Record<string, { sku: string; need: number }> = {};
      for (const row of (data ?? []) as { catalog_item_id: string; sku: string | null; need_to_buy: number }[]) {
        const id = row.catalog_item_id;
        const need = row.need_to_buy ?? 0;
        if (need > 0) {
          if (!byItem[id]) byItem[id] = { sku: row.sku ?? id, need: 0 };
          byItem[id].need += need;
        }
      }
      return Object.values(byItem);
    },
    enabled: !!activeOrganizationId,
  });

  const kpis = useMemo(() => {
    const pos = purchaseOrders ?? [];
    const openPOs = pos.filter((p) => ['DRAFT', 'OPEN'].includes(p.status)).length;
    const awaitingReceipt = pos.filter((p) =>
      ['PARTIAL'].includes(p.status)
    ).length;
    const itemsWithShortage = shortageQuery.data?.length ?? 0;
    const totalOpenValue = pos
      .filter((p) => !['CLOSED', 'CANCELLED', 'ARCHIVED'].includes(p.status))
      .reduce((acc, p) => acc + (p.total ?? 0), 0);

    return { openPOs, awaitingReceipt, itemsWithShortage, totalOpenValue };
  }, [purchaseOrders, shortageQuery.data]);

  const recentPOs = useMemo(() => (purchaseOrders ?? []).slice(0, 6), [purchaseOrders]);
  const topShortages = useMemo(
    () => (shortageQuery.data ?? []).sort((a, b) => b.need - a.need).slice(0, 5),
    [shortageQuery.data]
  );

  const loading = posLoading;

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-title font-semibold text-foreground">Procurement Dashboard</h1>
        <p className="text-sm text-muted-foreground mt-1">Purchasing & Inventory Overview</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <KpiCard
          icon={ShoppingCart}
          title="Open Purchase Orders"
          value={kpis.openPOs}
          sub="Draft + Sent"
          loading={loading}
          accent="blue"
        />
        <KpiCard
          icon={PackageCheck}
          title="Awaiting Receipt"
          value={kpis.awaitingReceipt}
          sub="Partially received"
          loading={loading}
          accent="green"
        />
        <KpiCard
          icon={AlertTriangle}
          title="Items with Shortage"
          value={kpis.itemsWithShortage}
          sub="Need to buy"
          loading={shortageQuery.isLoading}
          accent={kpis.itemsWithShortage > 0 ? 'amber' : 'green'}
        />
        <KpiCard
          icon={ClipboardList}
          title="Open PO Value"
          value={formatCurrency(kpis.totalOpenValue)}
          sub="All open POs"
          loading={loading}
          accent="blue"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent POs */}
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-heading font-semibold">Recent Purchase Orders</h2>
            <button
              type="button"
              onClick={() => router.navigate('/inventory/purchase-orders')}
              className="flex items-center gap-1 text-xs text-primary hover:underline"
            >
              View all <ArrowRight className="w-3 h-3" />
            </button>
          </div>
          <div className="space-y-3">
            {loading ? (
              <div className="text-sm text-muted-foreground">Loading...</div>
            ) : recentPOs.length === 0 ? (
              <div className="text-sm text-muted-foreground">No purchase orders yet.</div>
            ) : recentPOs.map((po) => (
              <button
                key={po.id}
                type="button"
                onClick={() => router.navigate(`/inventory/purchase-orders/${po.id}`)}
                className="w-full flex items-center justify-between p-3 hover:bg-gray-50 rounded-lg transition-colors text-left"
              >
                <div>
                  <div className="font-medium text-sm">{po.po_number ?? po.id.slice(0, 8)}</div>
                  <div className="text-xs text-muted-foreground">
                    {po.DirectoryVendors?.name ?? 'No vendor'} · {new Date(po.created_at).toLocaleDateString()}
                  </div>
                </div>
                <StatusBadge status={po.status} type="purchaseOrder" size="sm" />
              </button>
            ))}
          </div>
        </div>

        {/* Material Shortages */}
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-heading font-semibold">Material Shortages</h2>
            <button
              type="button"
              onClick={() => router.navigate('/inventory/material-demand')}
              className="flex items-center gap-1 text-xs text-primary hover:underline"
            >
              View all <ArrowRight className="w-3 h-3" />
            </button>
          </div>
          <div className="space-y-3">
            {shortageQuery.isLoading ? (
              <div className="text-sm text-muted-foreground">Loading...</div>
            ) : topShortages.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-status-green">
                <PackageCheck className="w-4 h-4" />
                All materials covered — no shortages.
              </div>
            ) : topShortages.map((item, i) => (
              <div key={i} className="flex items-center justify-between p-3 bg-amber-50 border border-amber-100 rounded-lg">
                <div className="flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0" />
                  <span className="text-sm font-medium">{item.sku}</span>
                </div>
                <span className="text-sm font-semibold text-red-600">
                  -{item.need.toFixed(2)} needed
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
