import { useState, useEffect, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFinishedGoods, type FinishedGoodsGroup } from '../../hooks/useFinishedGoods';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import StatusBadge from '../../components/shared/StatusBadge';
import { Package, ChevronDown, ChevronRight, Truck, Search, FileText, Lock } from 'lucide-react';
import { formatDate } from '../../lib/utils';
import { withReturnTo } from '../../lib/navigation/returnTo';

type FilterMode = 'ready' | 'delivered' | 'all';

type FinancialInfo = { balance_due: number; total_paid: number; invoice_status: string };

export default function FinishedGoods() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules } = useSubmoduleNav();
  const { groups, loading, error, refetch } = useFinishedGoods();
  const { orgRole } = useOrganizationContext();
  const [filter, setFilter] = useState<FilterMode>('ready');
  const [search, setSearch] = useState('');
  const [expandedMOs, setExpandedMOs] = useState<Set<string>>(new Set());
  const [financialBySoId, setFinancialBySoId] = useState<Record<string, FinancialInfo>>({});

  const canAuthorizeRelease = orgRole === 'superadmin' || orgRole === 'admin';

  useEffect(() => {
    const soIds = [...new Set(groups.map(g => g.sales_order_id).filter(Boolean))] as string[];
    if (soIds.length === 0) { setFinancialBySoId({}); return; }
    supabase
      .from('sales_order_financial_summary')
      .select('sales_order_id, balance_due, total_paid, invoice_status')
      .in('sales_order_id', soIds)
      .then(({ data }) => {
        const m: Record<string, FinancialInfo> = {};
        (data ?? []).forEach((r: any) => {
          m[r.sales_order_id] = { balance_due: r.balance_due ?? 0, total_paid: r.total_paid ?? 0, invoice_status: r.invoice_status ?? 'none' };
        });
        setFinancialBySoId(m);
      });
  }, [groups]);

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
  }, [registerSubmodules, filteredSubmodules]);

  const filteredGroups = useMemo(() => {
    let result = groups;

    if (filter === 'ready') {
      result = result.filter((g) => g.readyLines > 0);
    } else if (filter === 'delivered') {
      result = result.filter((g) => g.deliveredLines > 0);
    }

    if (search.length >= 2) {
      const q = search.toLowerCase();
      result = result.filter((g) =>
        g.manufacturing_order_no.toLowerCase().includes(q) ||
        (g.sales_order_no ?? '').toLowerCase().includes(q) ||
        (g.customer_name ?? '').toLowerCase().includes(q) ||
        (g.product_name ?? '').toLowerCase().includes(q)
      );
    }

    return result;
  }, [groups, filter, search]);

  const toggleExpand = (moId: string) => {
    setExpandedMOs((prev) => {
      const next = new Set(prev);
      if (next.has(moId)) next.delete(moId);
      else next.add(moId);
      return next;
    });
  };

  const readyCount = groups.reduce((s, g) => s + g.readyLines, 0);
  const deliveredCount = groups.reduce((s, g) => s + g.deliveredLines, 0);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-bold text-gray-900">Finished Goods</h2>
          <p className="text-sm text-gray-500">Products ready for delivery from completed manufacturing orders</p>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <div className="flex items-center gap-1.5">
            <span className="inline-block w-2 h-2 rounded-full bg-blue-500" />
            <span className="text-gray-600">{readyCount} ready</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="inline-block w-2 h-2 rounded-full bg-green-500" />
            <span className="text-gray-600">{deliveredCount} delivered</span>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3">
        <div className="flex rounded-lg border border-gray-200 bg-white overflow-hidden">
          {([['ready', 'Ready'], ['delivered', 'Delivered'], ['all', 'All']] as const).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setFilter(key)}
              className={`px-3 py-1.5 text-sm font-medium border-r last:border-r-0 border-gray-200 ${
                filter === key ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search MO, SO, customer..."
            className="w-full pl-8 pr-3 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-200"
          />
        </div>
      </div>

      {/* Content */}
      {loading ? (
        <div className="animate-pulse space-y-3">
          {[0, 1, 2].map((i) => <div key={i} className="h-20 bg-gray-100 rounded-lg" />)}
        </div>
      ) : error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">{error}</div>
      ) : filteredGroups.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <Package className="w-10 h-10 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">
            {filter === 'ready' ? 'No products ready for delivery' : 'No finished goods found'}
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredGroups.map((group) => (
            <FinishedGoodsCard
              key={group.manufacturing_order_id}
              group={group}
              expanded={expandedMOs.has(group.manufacturing_order_id)}
              onToggle={() => toggleExpand(group.manufacturing_order_id)}
              financial={group.sales_order_id ? financialBySoId[group.sales_order_id] : undefined}
              canAuthorizeRelease={canAuthorizeRelease}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function FinishedGoodsCard({
  group,
  expanded,
  onToggle,
  financial,
  canAuthorizeRelease,
}: {
  group: FinishedGoodsGroup;
  expanded: boolean;
  onToggle: () => void;
  financial?: FinancialInfo;
  canAuthorizeRelease: boolean;
}) {
  const paymentComplete = financial ? financial.balance_due <= 0.005 : false;
  const isNotInvoiced = !financial || financial.invoice_status === 'none';
  const deliveryBlocked = !isNotInvoiced && !paymentComplete && !canAuthorizeRelease;
  const paymentLabel = isNotInvoiced ? null
    : paymentComplete ? 'Paid'
    : financial!.total_paid > 0.005 ? 'Partial Payment'
    : 'Unpaid';

  return (
    <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
      <div
        className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50"
        onClick={onToggle}
      >
        <div className="flex items-center gap-3">
          <button type="button" className="text-gray-400">
            {expanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>
          <div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${group.manufacturing_order_id}`));
                }}
                className="font-semibold text-sm text-primary hover:underline"
              >
                {group.manufacturing_order_no}
              </button>
              <StatusBadge status={group.mo_status} type="manufacturing" size="sm" />
              {group.sales_order_no && (
                <span className="text-xs text-gray-400">
                  {group.sales_order_no}
                </span>
              )}
              {paymentLabel && (
                <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                  paymentComplete ? 'bg-green-100 text-green-800' :
                  paymentLabel === 'Partial Payment' ? 'bg-amber-100 text-amber-800' :
                  'bg-red-100 text-red-800'
                }`}>
                  {paymentLabel}
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-500">
              {group.customer_name && <span>{group.customer_name}</span>}
              {group.product_name && <span>· {group.product_name}</span>}
              {group.released_at && <span>· Ready {formatDate(group.released_at)}</span>}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="text-right">
            <div className="text-xs text-gray-500">
              {group.readyLines > 0 && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 font-medium mr-1">
                  {group.readyLines} ready
                </span>
              )}
              {group.deliveredLines > 0 && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-50 text-green-700 font-medium">
                  {group.deliveredLines} delivered
                </span>
              )}
            </div>
          </div>
          {group.readyLines > 0 && (
            <button
              type="button"
              disabled={deliveryBlocked}
              onClick={(e) => {
                e.stopPropagation();
                if (deliveryBlocked) return;
                router.navigate(withReturnTo(`/manufacturing/delivery-notes/new?mo_id=${group.manufacturing_order_id}`));
              }}
              title={deliveryBlocked ? `Payment not complete ($${financial?.balance_due?.toFixed(2) ?? '?'} balance due). Manager authorization required.` : undefined}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg ${
                deliveryBlocked
                  ? 'bg-gray-200 text-gray-500 cursor-not-allowed'
                  : 'text-white bg-primary hover:bg-primary/90'
              }`}
            >
              {deliveryBlocked ? <Lock className="w-3.5 h-3.5" /> : <Truck className="w-3.5 h-3.5" />}
              {deliveryBlocked ? 'Payment Required' : 'Create Delivery'}
            </button>
          )}
        </div>
      </div>

      {expanded && (
        <div className="border-t border-gray-100">
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-2 text-left font-medium text-gray-600 text-xs">Product</th>
                <th className="px-4 py-2 text-left font-medium text-gray-600 text-xs">Area</th>
                <th className="px-4 py-2 text-center font-medium text-gray-600 text-xs">Position</th>
                <th className="px-4 py-2 text-right font-medium text-gray-600 text-xs">Qty</th>
                <th className="px-4 py-2 text-center font-medium text-gray-600 text-xs">Status</th>
              </tr>
            </thead>
            <tbody>
              {group.lines.map((line) => (
                <tr key={line.mo_line_id} className="border-t border-gray-50 hover:bg-gray-50">
                  <td className="px-4 py-2">
                    <div className="font-medium text-gray-900 text-sm">
                      {line.catalog_item_name ?? line.line_description ?? 'Item'}
                    </div>
                    {line.catalog_item_sku && (
                      <div className="text-xs text-gray-400 font-mono">{line.catalog_item_sku}</div>
                    )}
                  </td>
                  <td className="px-4 py-2 text-gray-600 text-sm">{line.area ?? '—'}</td>
                  <td className="px-4 py-2 text-center text-gray-600 text-sm">{line.position ?? '—'}</td>
                  <td className="px-4 py-2 text-right tabular-nums text-gray-900">{line.quantity}</td>
                  <td className="px-4 py-2 text-center">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                      line.delivery_status === 'delivered' ? 'bg-green-100 text-green-800' :
                      line.delivery_status === 'ready' ? 'bg-blue-100 text-blue-800' :
                      'bg-gray-100 text-gray-600'
                    }`}>
                      {line.delivery_status === 'delivered' ? 'Delivered' :
                       line.delivery_status === 'ready' ? 'Ready' : 'Pending'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {group.deliveredLines > 0 && (
            <DeliveryNotesSection moId={group.manufacturing_order_id} />
          )}
        </div>
      )}
    </div>
  );
}

interface DeliveryNoteRef {
  id: string;
  delivery_number: string;
  status: string;
  completed_at: string | null;
  received_by_name: string | null;
  pdf_path: string | null;
}

function DeliveryNotesSection({ moId }: { moId: string }) {
  const [notes, setNotes] = useState<DeliveryNoteRef[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const { data: dns } = await supabase
        .from('DeliveryNotes')
        .select('id, delivery_number, status, completed_at, received_by_name')
        .eq('manufacturing_order_id', moId)
        .eq('deleted', false)
        .in('status', ['completed', 'partial'])
        .order('completed_at', { ascending: false });

      if (!dns || dns.length === 0) { setLoading(false); return; }

      const { data: attachments } = await supabase
        .from('manufacturing_order_attachments')
        .select('file_name, file_path')
        .eq('manufacturing_order_id', moId)
        .eq('content_type', 'application/pdf')
        .ilike('file_name', 'DN-%');

      const pdfMap = new Map<string, string>();
      (attachments ?? []).forEach((a: any) => {
        const dnNum = a.file_name.replace('.pdf', '');
        pdfMap.set(dnNum, a.file_path);
      });

      setNotes(dns.map((dn: any) => ({
        ...dn,
        pdf_path: pdfMap.get(dn.delivery_number) ?? null,
      })));
      setLoading(false);
    })();
  }, [moId]);

  const handleViewPdf = useCallback((filePath: string) => {
    const { data } = supabase.storage.from('mo-attachments').getPublicUrl(filePath);
    if (data?.publicUrl) window.open(data.publicUrl, '_blank');
  }, []);

  if (loading || notes.length === 0) return null;

  return (
    <div className="px-4 py-2.5 border-t border-gray-100 bg-gray-50/50 flex flex-wrap items-center gap-2">
      <span className="text-xs font-medium text-gray-500 mr-1">Delivery Notes:</span>
      {notes.map((dn) => (
        <div key={dn.id} className="inline-flex items-center gap-1">
          <button
            type="button"
            onClick={() => router.navigate(withReturnTo(`/manufacturing/delivery-notes/${dn.id}`))}
            className="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 rounded transition"
          >
            <Truck className="w-3 h-3" />
            {dn.delivery_number}
            <span className={`ml-0.5 px-1.5 py-0.5 rounded-full text-[10px] font-medium ${
              dn.status === 'completed' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'
            }`}>
              {dn.status === 'completed' ? 'Complete' : 'Partial'}
            </span>
          </button>
          {dn.pdf_path && (
            <button
              type="button"
              onClick={() => handleViewPdf(dn.pdf_path!)}
              className="inline-flex items-center gap-1 px-1.5 py-1 text-xs text-blue-700 hover:bg-blue-50 rounded transition"
              title="View PDF"
            >
              <FileText className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      ))}
    </div>
  );
}
