import { useEffect, useState, useCallback, useMemo } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useUIStore } from '../../stores/ui-store';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import { CheckCircle, Package, AlertTriangle } from 'lucide-react';
import { normalizeUUID } from '../../utils/uuid';

interface MOLineDetailProps {
  moId?: string;
  lineId?: string;
}

interface LineData {
  id: string;
  status: string;
  quantity: number;
  sales_order_line_id: string | null;
  manufacturing_order_id: string;
}

interface SaleOrderLineData {
  description: string | null;
  variant_name: string | null;
  product_type: string | null;
  hardware_color: string | null;
  area: string | null;
  position: string | null;
  quantity: number;
  width_m: number | null;
  height_m: number | null;
  CatalogItems: { name: string; sku: string; manufacturer: string | null } | null;
}

interface MaterialRow {
  bom_instance_line_id: string;
  catalog_item_id: string;
  sku: string;
  item_name: string;
  part_role: string;
  qty: number;
  uom: string;
  unit_cost: number;
  total_cost: number;
  on_hand_qty: number;
  on_order_qty: number;
  allocated_qty: number;
  missing_qty: number;
  readiness: string;
}

const PART_ROLE_LABELS: Record<string, string> = {
  fabric: 'Fabric',
  tube: 'Tube',
  motor: 'Motor',
  drive: 'Drive',
  bracket: 'Bracket',
  intermediate_bracket: 'Intermediate Bracket',
  intermediate_connector: 'Intermediate Connector',
  headbox: 'Headbox / Cassette',
  bottom_bar: 'Bottom Bar',
  bottom_bar_profile: 'Bottom Bar Profile',
  end_cap: 'End Cap',
  end_plug: 'End Plug',
  chain: 'Chain',
  chain_stop: 'Chain Stop',
  track: 'Track',
  carrier: 'Carrier',
  glider: 'Glider',
  hook: 'Hook',
  adapter: 'Adapter',
  bearing: 'Bearing',
  belt: 'Belt',
  belt_connector: 'Belt Connector',
  idler: 'Idler',
  mounting_clip: 'Mounting Clip',
  accessory: 'Accessory',
};

const PT_LABELS: Record<string, string> = {
  roller: 'Roller Shade', roller_shade: 'Roller Shade',
  drapery: 'Drapery', dual: 'Dual Shade', dual_shade: 'Dual Shade',
  triple: 'Triple Shade', triple_shade: 'Triple Shade',
  zebra: 'Zebra Shade', zebra_shade: 'Zebra Shade',
  blind: 'Blind', curtain: 'Curtain', catalog: 'Catalog',
};

export default function MOLineDetail({ moId: propMoId, lineId: propLineId }: MOLineDetailProps) {
  const normalizedMoId = propMoId ? normalizeUUID(propMoId) : null;
  const normalizedLineId = propLineId ? normalizeUUID(propLineId) : null;
  const [moId, setMoId] = useState<string | null>(normalizedMoId);
  const [lineId, setLineId] = useState<string | null>(normalizedLineId);
  const [moNo, setMoNo] = useState<string>('');
  const [line, setLine] = useState<LineData | null>(null);
  const [sol, setSol] = useState<SaleOrderLineData | null>(null);
  const [materials, setMaterials] = useState<MaterialRow[]>([]);
  const [loadingMaterials, setLoadingMaterials] = useState(true);
  const [reverting, setReverting] = useState(false);
  const [activeTab, setActiveTab] = useState('materials');
  const [materialFilter, setMaterialFilter] = useState<'all' | 'ok' | 'shortage'>('all');

  const mfgSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);

  useEffect(() => { registerSubmodules('Manufacturing', mfgSubmodules); }, [registerSubmodules, mfgSubmodules]);

  useEffect(() => {
    if (!moId || !lineId) {
      const path = window.location.pathname;
      const match = path.match(/\/manufacturing\/manufacturing-orders\/([^/]+)\/lines\/([^/]+)/);
      if (match) {
        setMoId(normalizeUUID(match[1]));
        setLineId(normalizeUUID(match[2]));
      }
    }
  }, [moId, lineId]);

  const fetchLine = useCallback(async () => {
    if (!moId || !lineId) return;

    const [{ data: moData }, { data: molData }] = await Promise.all([
      supabase.from('ManufacturingOrders').select('manufacturing_order_no').eq('id', moId).eq('deleted', false).single(),
      supabase.from('ManufacturingOrderLines').select('id, status, quantity, sales_order_line_id, manufacturing_order_id').eq('id', lineId).eq('deleted', false).single(),
    ]);

    if (moData) setMoNo(moData.manufacturing_order_no);
    if (!molData) return;
    setLine(molData);

    if (molData.sales_order_line_id) {
      const { data: solData, error: solErr } = await supabase
        .from('SaleOrderLines')
        .select('description, variant_name, product_type, hardware_color, area, position, quantity, width_m, height_m, catalog_item_id')
        .eq('id', molData.sales_order_line_id)
        .maybeSingle();

      if (solErr) console.warn('[MOLineDetail] SaleOrderLines query error:', solErr);

      if (solData) {
        let catItem = null;
        if (solData.catalog_item_id) {
          const { data: cat } = await supabase.from('CatalogItems').select('name, sku, manufacturer').eq('id', solData.catalog_item_id).maybeSingle();
          catItem = cat;
        }
        setSol({ ...solData, CatalogItems: catItem });
      } else {
        const { data: cpData } = await supabase
          .from('ConfiguredProducts')
          .select('product_type, config_snapshot')
          .eq('sales_order_line_id', molData.sales_order_line_id)
          .maybeSingle();
        if (cpData) {
          const snap = cpData.config_snapshot as Record<string, any> | null;
          setSol({
            description: snap?.fabricName ?? snap?.variant_name ?? null,
            variant_name: snap?.variant_name ?? null,
            product_type: cpData.product_type,
            hardware_color: snap?.hardware_color ?? null,
            area: snap?.area ?? null,
            position: snap?.position ?? null,
            quantity: snap?.quantity ?? molData.quantity ?? 1,
            width_m: snap?.width_mm ? snap.width_mm / 1000 : null,
            height_m: snap?.height_mm ? snap.height_mm / 1000 : null,
            CatalogItems: snap?.sku ? { name: snap.fabricName ?? '', sku: snap.sku, manufacturer: snap.manufacturer ?? null } : null,
          });
        }
      }
    }
  }, [moId, lineId]);

  const fetchMaterials = useCallback(async () => {
    if (!moId || !line?.sales_order_line_id) { setLoadingMaterials(false); return; }
    setLoadingMaterials(true);
    const { data, error } = await supabase.rpc('get_mo_line_materials_detail', {
      p_mo_id: moId,
      p_sales_order_line_id: line.sales_order_line_id,
    });
    if (error) {
      console.warn('get_mo_line_materials_detail error:', error);
      setMaterials([]);
    } else {
      setMaterials((data ?? []) as MaterialRow[]);
    }
    setLoadingMaterials(false);
  }, [moId, line?.sales_order_line_id]);

  useEffect(() => { fetchLine(); }, [fetchLine]);
  useEffect(() => { fetchMaterials(); }, [fetchMaterials]);

  const allMaterialsOk = useMemo(() => {
    if (materials.length === 0) return false;
    return materials.every(m => m.readiness === 'ok');
  }, [materials]);


  const onBack = useCallback(() => {
    if (moId) {
      router.navigate(`/manufacturing/manufacturing-orders/${moId}`);
    } else {
      router.navigate('/manufacturing/manufacturing-orders');
    }
  }, [moId]);

  const goToLines = useCallback(() => {
    if (moId) {
      router.navigate(`/manufacturing/manufacturing-orders/${moId}?tab=lines`);
    }
  }, [moId]);

  const handleSetDraftFromCancelled = useCallback(async () => {
    if (!lineId || line?.status !== 'cancelled') return;
    setReverting(true);
    const { data, error } = await supabase.rpc('advance_mo_line_status', {
      p_line_id: lineId,
      p_new_status: 'draft',
    });
    setReverting(false);
    const result = data as { ok?: boolean; status?: string; error?: string } | null;
    if (error || !result?.ok) {
      addNotification({
        type: 'error',
        title: 'Cannot set Draft',
        message: result?.error ?? error?.message ?? 'Unknown error',
      });
      return;
    }
    setLine(prev => (prev ? { ...prev, status: 'draft' } : prev));
    addNotification({ type: 'success', title: 'Line Updated', message: 'Line moved back to Draft.' });
  }, [lineId, line?.status, addNotification]);

  if (!line) {
    return (
      <div className="py-6 px-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-200 rounded w-1/3"></div>
          <div className="h-4 bg-gray-200 rounded w-1/2"></div>
        </div>
      </div>
    );
  }

  const ptRaw = (sol?.product_type || '').toLowerCase();
  const ptLabel = PT_LABELS[ptRaw] || (ptRaw ? ptRaw.charAt(0).toUpperCase() + ptRaw.slice(1) : 'Item');
  const fabricName = sol?.description || sol?.CatalogItems?.name || sol?.variant_name || 'Item';
  const sku = sol?.CatalogItems?.sku;
  const manufacturer = sol?.CatalogItems?.manufacturer;
  const hwColor = sol?.hardware_color;

  const tabs = [
    { id: 'materials', label: 'Materials', count: materials.length },
    { id: 'overview', label: 'Overview' },
  ];

  const shortages = materials.filter(m => m.readiness === 'shortage');
  const okCount = materials.filter(m => m.readiness === 'ok').length;
  const filteredMaterials = materialFilter === 'all'
    ? materials
    : materials.filter(m => m.readiness === materialFilter);

  return (
    <DetailPageLayout
      title={`${ptLabel} — ${fabricName}`}
      subtitle={[sku, manufacturer, hwColor].filter(Boolean).join(' · ')}
      status={<StatusBadge status={line.status} type="moLineStatus" />}
      actions={
        <div className="flex items-center gap-2">
          {line.status === 'cancelled' && (
            <button
              onClick={handleSetDraftFromCancelled}
              disabled={reverting}
              className={`px-3 py-1.5 rounded text-sm font-medium border transition-colors ${
                reverting
                  ? 'text-gray-400 border-gray-200 bg-gray-50 cursor-wait'
                  : 'text-gray-700 border-gray-300 hover:bg-gray-50'
              }`}
            >
              {reverting ? 'Setting...' : 'Set Draft'}
            </button>
          )}
          <button
            onClick={goToLines}
            className="px-3 py-1.5 rounded text-sm font-medium text-gray-700 border border-gray-300 hover:bg-gray-50 transition-colors"
          >
            Back
          </button>
        </div>
      }
      summaryItems={[
        { label: 'MO', value: moNo },
        { label: 'Location', value: [sol?.area, sol?.position].filter(Boolean).join(' / ') || '—' },
        { label: 'Qty', value: String(sol?.quantity ?? line.quantity ?? '—') },
        ...(sol?.width_m && sol?.height_m ? [
          { label: 'Dimensions', value: `${Math.round(sol.width_m * 1000)} × ${Math.round(sol.height_m * 1000)} mm` },
        ] : []),
      ]}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
    >
      {/* Materials Tab */}
      {activeTab === 'materials' && (
        <div className="space-y-4">
          {/* Material readiness summary */}
          {materials.length > 0 && (
            <div className={`flex items-center gap-2 px-4 py-3 rounded-lg border ${
              shortages.length > 0
                ? 'bg-amber-50 border-amber-200'
                : 'bg-emerald-50 border-emerald-200'
            }`}>
              {shortages.length > 0 ? (
                <>
                  <AlertTriangle className="w-4 h-4 text-amber-600" />
                  <span className="text-sm font-medium text-amber-800">
                    {shortages.length} material{shortages.length > 1 ? 's' : ''} not fully allocated
                  </span>
                </>
              ) : (
                <>
                  <CheckCircle className="w-4 h-4 text-emerald-600" />
                  <span className="text-sm font-medium text-emerald-800">All materials allocated</span>
                </>
              )}
            </div>
          )}

          {/* Material filter tabs */}
          {materials.length > 0 && (
            <div className="flex items-center gap-1 bg-gray-100 rounded-lg p-0.5 w-fit">
              {([
                { key: 'all' as const, label: 'All', count: materials.length },
                { key: 'ok' as const, label: 'Allocated', count: okCount },
                { key: 'shortage' as const, label: 'Shortage', count: shortages.length },
              ]).map(f => (
                <button
                  key={f.key}
                  onClick={() => setMaterialFilter(f.key)}
                  className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                    materialFilter === f.key
                      ? 'bg-white text-gray-900 shadow-sm'
                      : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  {f.label}
                  <span className={`ml-1.5 ${materialFilter === f.key ? 'text-gray-500' : 'text-gray-400'}`}>
                    {f.count}
                  </span>
                </button>
              ))}
            </div>
          )}

          {loadingMaterials ? (
            <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
              <div className="animate-pulse space-y-3">
                <div className="h-4 bg-gray-200 rounded w-1/3 mx-auto"></div>
                <div className="h-4 bg-gray-200 rounded w-1/2 mx-auto"></div>
              </div>
            </div>
          ) : materials.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
              <Package className="w-8 h-8 text-gray-300 mx-auto mb-2" />
              <p className="text-gray-500 text-sm">No BOM materials found for this line</p>
            </div>
          ) : (
            <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="py-3 px-4 text-left text-xs font-medium text-gray-500">Part</th>
                    <th className="py-3 px-3 text-left text-xs font-medium text-gray-500">SKU</th>
                    <th className="py-3 px-3 text-right text-xs font-medium text-gray-500">Needed</th>
                    <th className="py-3 px-3 text-right text-xs font-medium text-gray-500">On Hand</th>
                    <th className="py-3 px-3 text-right text-xs font-medium text-gray-500">On Order</th>
                    <th className="py-3 px-3 text-right text-xs font-medium text-gray-500">Allocated</th>
                    <th className="py-3 px-3 text-right text-xs font-medium text-gray-500">Gap</th>
                    <th className="py-3 px-3 text-center text-xs font-medium text-gray-500">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredMaterials.map((m) => {
                    const roleLabel = PART_ROLE_LABELS[m.part_role] || m.part_role.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
                    const fmtQty = (v: number, uom: string) => {
                      const n = Number(v);
                      if (uom === 'ea') return n.toFixed(0);
                      if (uom === 'm') return n.toFixed(2) + ' m';
                      if (uom === 'm2') return n.toFixed(2) + ' m²';
                      return n.toFixed(2) + (uom ? ` ${uom}` : '');
                    };

                    return (
                      <tr key={m.bom_instance_line_id} className="border-t border-gray-100 hover:bg-gray-50/50">
                        <td className="py-2.5 px-4">
                          <div className="font-medium text-gray-900 text-sm">{roleLabel}</div>
                          <div className="text-xs text-gray-500 mt-0.5 truncate max-w-[200px]">{m.item_name}</div>
                        </td>
                        <td className="py-2.5 px-3 text-xs text-gray-500 font-mono">{m.sku || '—'}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-sm">{fmtQty(m.qty, m.uom)}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-sm text-gray-600">{fmtQty(m.on_hand_qty, m.uom)}</td>
                        <td className="py-2.5 px-3 text-right tabular-nums text-sm text-gray-600">{fmtQty(m.on_order_qty, m.uom)}</td>
                        <td className={`py-2.5 px-3 text-right tabular-nums text-sm ${Number(m.allocated_qty) > 0 ? 'text-blue-700 font-medium' : 'text-gray-400'}`}>
                          {Number(m.allocated_qty) > 0 ? fmtQty(m.allocated_qty, m.uom) : '—'}
                        </td>
                        <td className={`py-2.5 px-3 text-right tabular-nums text-sm font-medium ${m.missing_qty > 0 ? 'text-amber-700' : 'text-gray-400'}`}>
                          {m.missing_qty > 0 ? fmtQty(m.missing_qty, m.uom) : '—'}
                        </td>
                        <td className="py-2.5 px-3 text-center">
                          {m.readiness === 'ok' ? (
                            <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-emerald-50 text-emerald-700">OK</span>
                          ) : (
                            <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[11px] font-medium bg-amber-50 text-amber-700">Shortage</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Overview Tab */}
      {activeTab === 'overview' && (
        <div className="bg-white border border-gray-200 rounded-lg p-6 space-y-4">
          <h3 className="text-sm font-semibold text-gray-700">Product Details</h3>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-gray-500">Type</span>
              <p className="font-medium text-gray-900">{ptLabel}</p>
            </div>
            <div>
              <span className="text-gray-500">Fabric / Product</span>
              <p className="font-medium text-gray-900">{fabricName}</p>
            </div>
            {manufacturer && (
              <div>
                <span className="text-gray-500">Manufacturer</span>
                <p className="font-medium text-gray-900">{manufacturer}</p>
              </div>
            )}
            {sku && (
              <div>
                <span className="text-gray-500">SKU</span>
                <p className="font-medium text-gray-900 font-mono">{sku}</p>
              </div>
            )}
            {hwColor && (
              <div>
                <span className="text-gray-500">Hardware Color</span>
                <p className="font-medium text-gray-900">{hwColor}</p>
              </div>
            )}
            {sol?.width_m && sol?.height_m && (
              <div>
                <span className="text-gray-500">Dimensions (W × H)</span>
                <p className="font-medium text-gray-900">{Math.round(sol.width_m * 1000)} × {Math.round(sol.height_m * 1000)} mm</p>
              </div>
            )}
            {sol?.area && (
              <div>
                <span className="text-gray-500">Area</span>
                <p className="font-medium text-gray-900">{sol.area}</p>
              </div>
            )}
            {sol?.position && (
              <div>
                <span className="text-gray-500">Position</span>
                <p className="font-medium text-gray-900">{sol.position}</p>
              </div>
            )}
            <div>
              <span className="text-gray-500">Quantity</span>
              <p className="font-medium text-gray-900">{sol?.quantity ?? line.quantity}</p>
            </div>
          </div>
        </div>
      )}
    </DetailPageLayout>
  );
}
