import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  DollarSign,
  AlertCircle,
  CheckCircle,
  TrendingUp,
  ArrowRight,
} from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
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

interface InvoiceRow {
  id: string;
  invoice_number: string;
  status: string;
  issue_date: string;
  due_date: string | null;
  total: number;
  currency_code: string;
  dealer_id: string;
  Dealers?: { dealer_name: string } | null;
}

interface PaymentRow {
  id: string;
  amount: number;
  payment_date: string;
}

export default function FinanceDashboard() {
  const { activeOrganizationId } = useOrganizationContext();

  const invoicesQuery = useQuery({
    queryKey: ['finance-dashboard-invoices', activeOrganizationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('DealerInvoices')
        .select('id, invoice_number, status, issue_date, due_date, total, currency_code, dealer_id, Dealers(dealer_name)')
        .eq('organization_id', activeOrganizationId!)
        .eq('deleted', false)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (data ?? []) as InvoiceRow[];
    },
    enabled: !!activeOrganizationId,
  });

  const paymentsQuery = useQuery({
    queryKey: ['finance-dashboard-payments', activeOrganizationId],
    queryFn: async () => {
      const startOfMonth = new Date();
      startOfMonth.setDate(1);
      startOfMonth.setHours(0, 0, 0, 0);

      const { data, error } = await supabase
        .from('Payments')
        .select('id, amount, payment_date')
        .eq('organization_id', activeOrganizationId!)
        .eq('status', 'completed')
        .gte('payment_date', startOfMonth.toISOString());
      if (error) throw error;
      return (data ?? []) as PaymentRow[];
    },
    enabled: !!activeOrganizationId,
  });

  const kpis = useMemo(() => {
    const invoices = invoicesQuery.data ?? [];
    const today = new Date().toISOString().split('T')[0];

    const openInvoices = invoices.filter((i) => !['paid', 'cancelled', 'voided'].includes(i.status));
    const arPending = openInvoices.reduce((sum, i) => sum + (i.total ?? 0), 0);
    const overdue = openInvoices.filter((i) => i.due_date && i.due_date < today).length;
    const paymentsThisMonth = (paymentsQuery.data ?? []).reduce((sum, p) => sum + (p.amount ?? 0), 0);
    const paidThisMonth = invoices.filter((i) => i.status === 'paid').length;

    return { arPending, overdue, paymentsThisMonth, paidThisMonth };
  }, [invoicesQuery.data, paymentsQuery.data]);

  const recentInvoices = useMemo(() => (invoicesQuery.data ?? []).slice(0, 10), [invoicesQuery.data]);

  const loading = invoicesQuery.isLoading;

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-title font-semibold text-foreground">Finance Dashboard</h1>
        <p className="text-sm text-muted-foreground mt-1">Accounts Receivable Overview</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <KpiCard
          icon={DollarSign}
          title="AR Pending"
          value={formatCurrency(kpis.arPending)}
          sub="Open invoices total"
          loading={loading}
          accent="blue"
        />
        <KpiCard
          icon={AlertCircle}
          title="Overdue Invoices"
          value={kpis.overdue}
          sub="Past due date"
          loading={loading}
          accent={kpis.overdue > 0 ? 'red' : 'green'}
        />
        <KpiCard
          icon={TrendingUp}
          title="Collected This Month"
          value={formatCurrency(kpis.paymentsThisMonth)}
          sub="Completed payments"
          loading={paymentsQuery.isLoading}
          accent="green"
        />
        <KpiCard
          icon={CheckCircle}
          title="Paid Invoices"
          value={kpis.paidThisMonth}
          sub="Status: paid"
          loading={loading}
          accent="green"
        />
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-heading font-semibold">Recent Invoices</h2>
          <button
            type="button"
            onClick={() => router.navigate('/financials/invoices')}
            className="flex items-center gap-1 text-xs text-primary hover:underline"
          >
            View all <ArrowRight className="w-3 h-3" />
          </button>
        </div>

        {loading ? (
          <div className="text-sm text-muted-foreground">Loading...</div>
        ) : recentInvoices.length === 0 ? (
          <div className="text-sm text-muted-foreground">No invoices yet.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-gray-500 border-b border-gray-200">
                  <th className="pb-2 pr-4">Invoice #</th>
                  <th className="pb-2 pr-4">Dealer</th>
                  <th className="pb-2 pr-4">Issue Date</th>
                  <th className="pb-2 pr-4">Due Date</th>
                  <th className="pb-2 pr-4 text-right">Total</th>
                  <th className="pb-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {recentInvoices.map((inv) => {
                  const today = new Date().toISOString().split('T')[0];
                  const isOverdue = inv.due_date && inv.due_date < today && !['paid', 'cancelled', 'voided'].includes(inv.status);
                  return (
                    <tr
                      key={inv.id}
                      className={`border-b border-gray-100 hover:bg-gray-50 cursor-pointer transition-colors ${isOverdue ? 'bg-red-50/40' : ''}`}
                      onClick={() => router.navigate(`/financials/invoices/${inv.id}`)}
                    >
                      <td className="py-2.5 pr-4 font-medium text-primary">{inv.invoice_number}</td>
                      <td className="py-2.5 pr-4 text-muted-foreground">{inv.Dealers?.dealer_name ?? '—'}</td>
                      <td className="py-2.5 pr-4 text-muted-foreground">
                        {inv.issue_date ? new Date(inv.issue_date).toLocaleDateString() : '—'}
                      </td>
                      <td className={`py-2.5 pr-4 ${isOverdue ? 'text-red-600 font-medium' : 'text-muted-foreground'}`}>
                        {inv.due_date ? new Date(inv.due_date).toLocaleDateString() : '—'}
                      </td>
                      <td className="py-2.5 pr-4 text-right font-semibold">
                        {formatCurrency(inv.total)}
                      </td>
                      <td className="py-2.5">
                        <StatusBadge status={inv.status} type="invoice" size="sm" />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
