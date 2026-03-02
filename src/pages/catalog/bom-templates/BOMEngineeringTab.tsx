import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useBOMCRUD } from '../../../hooks/useBOM';
import { useUIStore } from '../../../stores/ui-store';
import { getRoleLabel } from '../../../lib/bom/roles';
import { Settings, Search, ChevronRight, LayoutTemplate } from 'lucide-react';
import BOMEngineeringModal from './BOMEngineeringModal';
import type { EngineeringData } from './types';

export interface EngineeringTemplateSummary {
  id: string;
  name: string;
  code: string | null;
  product_type_id: string | null;
  product_type_name: string;
  parent_count: number;
}

export interface EngineeringRow {
  id: string;
  bom_template_id: string;
  component_item_id: string | null;
  component_role: string | null;
  cut_axis: string | null;
  cut_delta_mm: number | null;
  cut_delta_scope: string | null;
  depends_on_role: string | null;
  engineering_delta_source: string | null;
  engineering_attr_key: string | null;
  engineering_scope: string | null;
  engineering_source_role: string | null;
  template_name?: string;
  product_type_name?: string;
  component_sku?: string;
  component_name?: string;
}

const CUT_AXIS_LABELS: Record<string, string> = {
  none: '—',
  length: 'Length',
  width: 'Width',
  height: 'Height',
};

const SCOPE_LABELS: Record<string, string> = {
  none: '—',
  per_item: 'Per item',
  per_side: 'Per side',
};

export default function BOMEngineeringTab() {
  const { activeOrganizationId } = useOrganizationContext();
  const { updateComponent } = useBOMCRUD();
  const [rows, setRows] = useState<EngineeringRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [templateSearch, setTemplateSearch] = useState('');
  const [componentSearch, setComponentSearch] = useState('');
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [engineeringData, setEngineeringData] = useState<EngineeringData>({
    depends_on_role: '',
    cut_axis: 'none',
    cut_delta_mm: null,
    cut_delta_scope: 'none',
    engineering_delta_source: 'fixed',
    engineering_attr_key: '',
    engineering_scope: 'total',
    engineering_source_role: '',
  });

  const fetchComponents = useCallback(async () => {
    if (!activeOrganizationId) {
      setRows([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const { data: compData, error: compErr } = await supabase
        .from('BOMComponents')
        .select(`
          id,
          bom_template_id,
          component_item_id,
          component_role,
          cut_axis,
          cut_delta_mm,
          cut_delta_scope,
          depends_on_role,
          engineering_delta_source,
          engineering_attr_key,
          engineering_scope,
          engineering_source_role,
          BOMTemplate:bom_template_id (name, product_type_id),
          component_item:component_item_id (sku, name)
        `)
        .eq('organization_id', activeOrganizationId)
        .is('parent_component_id', null)
        .eq('deleted', false)
        .eq('archived', false)
        .order('bom_template_id')
        .order('sort_order');

      if (compErr) throw new Error(compErr.message);

      const ptIds = [...new Set((compData ?? []).map((c: any) => c.BOMTemplate?.product_type_id).filter(Boolean))];
      let productTypeMap: Record<string, string> = {};
      if (ptIds.length > 0) {
        const { data: pts } = await supabase.from('ProductTypes').select('id, name').in('id', ptIds);
        productTypeMap = (pts ?? []).reduce((acc: Record<string, string>, p: any) => {
          acc[p.id] = p.name ?? '';
          return acc;
        }, {});
      }

      const list: EngineeringRow[] = (compData ?? []).map((c: any) => {
        const template = c.BOMTemplate;
        const item = c.component_item;
        return {
          id: c.id,
          bom_template_id: c.bom_template_id,
          component_item_id: c.component_item_id,
          component_role: c.component_role,
          cut_axis: c.cut_axis ?? null,
          cut_delta_mm: c.cut_delta_mm ?? null,
          cut_delta_scope: c.cut_delta_scope ?? null,
          depends_on_role: c.depends_on_role ?? null,
          engineering_delta_source: c.engineering_delta_source ?? 'fixed',
          engineering_attr_key: c.engineering_attr_key ?? null,
          engineering_scope: c.engineering_scope ?? 'total',
          engineering_source_role: c.engineering_source_role ?? null,
          template_name: template?.name ?? template?.template_name ?? '',
          product_type_name: template?.product_type_id ? (productTypeMap[template.product_type_id] ?? '') : '',
          component_sku: item?.sku ?? '',
          component_name: item?.name ?? '',
        };
      });

      setRows(list);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error loading components');
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => {
    fetchComponents();
  }, [fetchComponents]);

  const templateList = useMemo(() => {
    const byId = new Map<string, EngineeringTemplateSummary>();
    for (const r of rows) {
      const id = r.bom_template_id;
      if (!byId.has(id)) {
        byId.set(id, {
          id,
          name: r.template_name ?? '',
          code: null,
          product_type_id: null,
          product_type_name: r.product_type_name ?? '',
          parent_count: 0,
        });
      }
      const t = byId.get(id)!;
      t.parent_count += 1;
    }
    return Array.from(byId.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [rows]);

  const filteredTemplateList = useMemo(() => {
    if (!templateSearch.trim()) return templateList;
    const q = templateSearch.toLowerCase();
    return templateList.filter(
      (t) =>
        t.name.toLowerCase().includes(q) ||
        (t.code ?? '').toLowerCase().includes(q) ||
        t.product_type_name.toLowerCase().includes(q),
    );
  }, [templateList, templateSearch]);

  const selectedTemplate = useMemo(
    () => (selectedTemplateId ? templateList.find((t) => t.id === selectedTemplateId) : null),
    [templateList, selectedTemplateId],
  );

  const componentsForSelected = useMemo(() => {
    if (!selectedTemplateId) return [];
    return rows.filter((r) => r.bom_template_id === selectedTemplateId);
  }, [rows, selectedTemplateId]);

  const filteredRows = useMemo(() => {
    if (!componentSearch.trim()) return componentsForSelected;
    const q = componentSearch.toLowerCase();
    return componentsForSelected.filter(
      (r) =>
        (r.component_sku ?? '').toLowerCase().includes(q) ||
        (r.component_name ?? '').toLowerCase().includes(q) ||
        getRoleLabel(r.component_role ?? '').toLowerCase().includes(q),
    );
  }, [componentsForSelected, componentSearch]);

  const handleOpenEdit = useCallback((row: EngineeringRow) => {
    setEngineeringData({
      depends_on_role: row.depends_on_role ?? '',
      cut_axis: (row.cut_axis === 'length' || row.cut_axis === 'width' || row.cut_axis === 'height' ? row.cut_axis : 'none') as 'length' | 'width' | 'height' | 'none',
      cut_delta_mm: row.cut_delta_mm,
      cut_delta_scope: (row.cut_delta_scope === 'per_side' || row.cut_delta_scope === 'per_item' ? row.cut_delta_scope : 'none') as 'per_side' | 'per_item' | 'none',
      engineering_delta_source: (row.engineering_delta_source === 'derived' ? 'derived' : 'fixed') as 'fixed' | 'derived',
      engineering_attr_key: row.engineering_attr_key ?? '',
      engineering_scope: (row.engineering_scope === 'per_side' ? 'per_side' : 'total') as 'total' | 'per_side',
      engineering_source_role: row.engineering_source_role ?? '',
    });
    setEditingId(row.id);
  }, []);

  const handleSaveEngineering = useCallback(async () => {
    if (!editingId) return;
    try {
      await updateComponent(editingId, {
        cut_axis: engineeringData.cut_axis === 'none' ? null : engineeringData.cut_axis,
        cut_delta_mm: engineeringData.cut_delta_mm ?? 0,
        cut_delta_scope: engineeringData.cut_delta_scope === 'none' ? null : engineeringData.cut_delta_scope,
        depends_on_role: engineeringData.cut_axis === 'none' ? null : (engineeringData.depends_on_role || null),
        engineering_delta_source: engineeringData.engineering_delta_source || 'fixed',
        engineering_attr_key: engineeringData.engineering_attr_key || null,
        engineering_scope: engineeringData.engineering_scope || 'total',
        engineering_source_role: engineeringData.engineering_source_role || null,
      });
      useUIStore.getState().addNotification({ type: 'success', title: 'Saved', message: 'Engineering rules updated' });
      setEditingId(null);
      fetchComponents();
    } catch (err) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err instanceof Error ? err.message : 'Failed to save',
      });
    }
  }, [editingId, engineeringData, updateComponent, fetchComponents]);

  const handleCloseModal = useCallback(() => {
    setEditingId(null);
  }, []);

  if (loading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
        <p className="text-sm text-gray-600">Loading components...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
        <p className="text-sm text-red-600">{error}</p>
      </div>
    );
  }

  return (
    <div className="flex gap-4 h-[calc(100vh-11rem)] min-h-[420px] overflow-hidden">
      {/* Left: unique template list */}
      <div className="w-80 flex-shrink-0 flex flex-col bg-white border border-gray-200 rounded-lg overflow-hidden min-h-0">
        <div className="p-3 border-b border-gray-200 flex-shrink-0">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search templates..."
              value={templateSearch}
              onChange={(e) => setTemplateSearch(e.target.value)}
              className="w-full pl-8 pr-3 py-1.5 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
          </div>
          <p className="mt-2 text-xs text-gray-500">
            {filteredTemplateList.length} template{filteredTemplateList.length !== 1 ? 's' : ''}
          </p>
        </div>
        <div className="flex-1 overflow-y-auto min-h-0">
          {filteredTemplateList.length === 0 ? (
            <div className="p-4 text-center text-sm text-gray-500">
              {templateList.length === 0 ? 'No BOM templates with components.' : 'No templates match search.'}
            </div>
          ) : (
            <ul className="py-1">
              {filteredTemplateList.map((t) => (
                <li key={t.id}>
                  <button
                    type="button"
                    onClick={() => setSelectedTemplateId(t.id)}
                    className={`w-full text-left px-4 py-2.5 flex items-center gap-2 hover:bg-gray-50 border-l-2 border-transparent ${
                      selectedTemplateId === t.id ? 'bg-primary/5 border-l-primary border-l-2' : ''
                    }`}
                  >
                    <LayoutTemplate className="h-4 w-4 text-gray-400 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="truncate text-sm font-medium text-gray-900" title={t.name}>
                        {t.name || 'Unnamed'}
                      </p>
                      {t.product_type_name && (
                        <p className="truncate text-xs text-gray-500" title={t.product_type_name}>
                          {t.product_type_name} · {t.parent_count} components
                        </p>
                      )}
                    </div>
                    <ChevronRight className="h-4 w-4 text-gray-400 flex-shrink-0" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      {/* Right: components for selected template */}
      <div className="flex-1 flex flex-col min-w-0 min-h-0 bg-white border border-gray-200 rounded-lg overflow-hidden">
        {!selectedTemplateId ? (
          <div className="flex-1 flex items-center justify-center p-12 text-gray-500 min-h-0">
            <div className="text-center">
              <LayoutTemplate className="h-12 w-12 mx-auto mb-3 text-gray-300" />
              <p className="text-sm font-medium">Select a template</p>
              <p className="text-xs mt-1">Choose a template from the list to view and edit its engineering rules.</p>
            </div>
          </div>
        ) : (
          <>
            <div className="px-4 py-3 border-b border-gray-200 flex items-center gap-3 flex-wrap flex-shrink-0">
              <h3 className="text-sm font-semibold text-gray-900 truncate" title={selectedTemplate?.name}>
                {selectedTemplate?.name || 'Template'}
              </h3>
              {selectedTemplate?.product_type_name && (
                <span className="text-xs text-gray-500">{selectedTemplate.product_type_name}</span>
              )}
              <div className="flex-1 min-w-[180px] relative">
                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search components..."
                  value={componentSearch}
                  onChange={(e) => setComponentSearch(e.target.value)}
                  className="w-full pl-8 pr-3 py-1.5 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <span className="text-xs text-gray-500">
                {filteredRows.length} component{filteredRows.length !== 1 ? 's' : ''}
              </span>
            </div>
            <div className="flex-1 overflow-y-auto overflow-x-auto min-h-0">
              <table className="w-full text-sm">
                <thead className="sticky top-0 bg-gray-50 z-10">
                  <tr className="border-b border-gray-200">
                    <th className="text-left px-4 py-2.5 text-xs font-semibold text-gray-500 uppercase">Component</th>
                    <th className="text-left px-3 py-2.5 text-xs font-semibold text-gray-500 uppercase">Role</th>
                    <th className="text-center px-2 py-2.5 text-xs font-semibold text-gray-500 uppercase">Cut Axis</th>
                    <th className="text-left px-2 py-2.5 text-xs font-semibold text-gray-500 uppercase">Depends on</th>
                    <th className="text-center px-2 py-2.5 text-xs font-semibold text-gray-500 uppercase">Delta (mm)</th>
                    <th className="text-center px-2 py-2.5 text-xs font-semibold text-gray-500 uppercase">Scope</th>
                    <th className="text-left px-2 py-2.5 text-xs font-semibold text-gray-500 uppercase">Source</th>
                    <th className="w-14 px-2 py-2.5"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {filteredRows.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="px-4 py-10 text-center text-gray-500">
                        No components in this template or no match for search.
                      </td>
                    </tr>
                  ) : (
                    filteredRows.map((row) => (
                      <tr key={row.id} className="hover:bg-gray-50/50">
                        <td className="px-4 py-2.5">
                          <span className="font-mono text-gray-700">{row.component_sku || '—'}</span>
                          {row.component_name && (
                            <span className="text-gray-500 ml-1">{row.component_name}</span>
                          )}
                        </td>
                        <td className="px-3 py-2.5 text-gray-600">{getRoleLabel(row.component_role ?? '') || '—'}</td>
                        <td className="px-2 py-2.5 text-center">
                          <span className="text-xs text-gray-600">{CUT_AXIS_LABELS[row.cut_axis ?? 'none'] ?? row.cut_axis ?? '—'}</span>
                        </td>
                        <td className="px-2 py-2.5 text-xs text-gray-600">{row.depends_on_role ? getRoleLabel(row.depends_on_role) : '—'}</td>
                        <td className="px-2 py-2.5 text-center text-gray-600">{row.cut_delta_mm != null ? row.cut_delta_mm : '—'}</td>
                        <td className="px-2 py-2.5 text-center text-xs text-gray-600">{SCOPE_LABELS[row.cut_delta_scope ?? 'none'] ?? '—'}</td>
                        <td className="px-2 py-2.5 text-xs text-gray-600">
                          {row.engineering_delta_source === 'derived'
                            ? <span className="text-amber-600">{getRoleLabel(row.engineering_source_role ?? '')}.{row.engineering_attr_key ?? '?'}</span>
                            : <span className="text-gray-400">Fixed</span>
                          }
                        </td>
                        <td className="px-2 py-2.5">
                          <button
                            type="button"
                            onClick={() => handleOpenEdit(row)}
                            className="p-1.5 rounded hover:bg-primary/10 text-gray-500 hover:text-primary"
                            title="Edit engineering rules"
                          >
                            <Settings className="h-4 w-4" />
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>

      <BOMEngineeringModal
        showEngineeringModal={!!editingId}
        engineeringData={engineeringData}
        setEngineeringData={setEngineeringData}
        onSave={handleSaveEngineering}
        onClose={handleCloseModal}
      />
    </div>
  );
}
