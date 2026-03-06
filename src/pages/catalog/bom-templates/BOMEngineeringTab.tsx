import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useBOMCRUD } from '../../../hooks/useBOM';
import { Search, ChevronRight, LayoutTemplate, Save } from 'lucide-react';
import EngineeringCutBreakdown from './EngineeringCutBreakdown';
import type { CutBreakdownHandle } from './EngineeringCutBreakdown';

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
  parent_component_id: string | null;
  component_role: string | null;
  cut_axis: string | null;
  cut_delta_mm: number | null;
  cut_delta_scope: string | null;
  depends_on_role: string | null;
  affects_role: string | null;
  engineering_delta_source: string | null;
  engineering_attr_key: string | null;
  engineering_scope: string | null;
  engineering_source_role: string | null;
  uom: string;
  qty_value: number;
  measure_basis: string | null;
  delta_x_mm: number | null;
  delta_y_mm: number | null;
  template_name?: string;
  product_type_name?: string;
  component_sku?: string;
  component_name?: string;
}

export default function BOMEngineeringTab() {
  const { activeOrganizationId } = useOrganizationContext();
  const { updateComponent } = useBOMCRUD();
  const [rows, setRows] = useState<EngineeringRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [templateSearch, setTemplateSearch] = useState('');
  const breakdownRef = useRef<CutBreakdownHandle>(null);
  const [breakdownState, setBreakdownState] = useState({ hasChanges: false, saving: false });
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(() => {
    try { return sessionStorage.getItem('bom:eng:templateId') || null; } catch { return null; }
  });

  useEffect(() => {
    try {
      if (selectedTemplateId) sessionStorage.setItem('bom:eng:templateId', selectedTemplateId);
      else sessionStorage.removeItem('bom:eng:templateId');
    } catch { /* ignore */ }
  }, [selectedTemplateId]);

  useEffect(() => {
    const handler = (e: Event) => {
      const templateId = (e as CustomEvent<string>).detail;
      if (templateId) setSelectedTemplateId(templateId);
    };
    window.addEventListener('bom:selectTemplate', handler);
    return () => window.removeEventListener('bom:selectTemplate', handler);
  }, []);

  const handlePendingChange = useCallback((hasChanges: boolean, saving: boolean) => {
    setBreakdownState((prev) => (prev.hasChanges !== hasChanges || prev.saving !== saving ? { hasChanges, saving } : prev));
  }, []);

  const fetchComponents = useCallback(async (showSpinner = true) => {
    if (!activeOrganizationId) {
      setRows([]);
      setLoading(false);
      return;
    }
    if (showSpinner) setLoading(true);
    setError(null);
    try {
      const { data: compData, error: compErr } = await supabase
        .from('BOMComponents')
        .select(`
          id,
          bom_template_id,
          parent_component_id,
          component_item_id,
          component_role,
          cut_axis,
          cut_delta_mm,
          cut_delta_scope,
          depends_on_role,
          affects_role,
          uom,
          qty_value,
          engineering_delta_source,
          engineering_attr_key,
          engineering_scope,
          engineering_source_role,
          BOMTemplate:bom_template_id (name, product_type_id),
          component_item:component_item_id (sku, name, measure_basis, delta_x_mm, delta_y_mm)
        `)
        .eq('organization_id', activeOrganizationId)
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

      const allRows: EngineeringRow[] = (compData ?? []).map((c: any) => {
        const template = c.BOMTemplate;
        const item = c.component_item;
        return {
          id: c.id,
          bom_template_id: c.bom_template_id,
          parent_component_id: c.parent_component_id ?? null,
          component_item_id: c.component_item_id,
          component_role: c.component_role,
          cut_axis: c.cut_axis ?? null,
          cut_delta_mm: c.cut_delta_mm ?? null,
          cut_delta_scope: c.cut_delta_scope ?? null,
          depends_on_role: c.depends_on_role ?? null,
          affects_role: c.affects_role ?? null,
          uom: c.uom ?? 'ea',
          qty_value: c.qty_value ?? 1,
          measure_basis: item?.measure_basis ?? null,
          delta_x_mm: item?.delta_x_mm != null ? Number(item.delta_x_mm) : null,
          delta_y_mm: item?.delta_y_mm != null ? Number(item.delta_y_mm) : null,
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

      setRows(allRows);
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

  const parentRows = useMemo(() => rows.filter((r) => !r.parent_component_id), [rows]);

  const childrenByParent = useMemo(() => {
    const map: Record<string, EngineeringRow[]> = {};
    for (const r of rows) {
      if (r.parent_component_id) {
        if (!map[r.parent_component_id]) map[r.parent_component_id] = [];
        map[r.parent_component_id].push(r);
      }
    }
    return map;
  }, [rows]);

  const templateList = useMemo(() => {
    const byId = new Map<string, EngineeringTemplateSummary>();
    for (const r of parentRows) {
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
  }, [parentRows]);

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
    return parentRows.filter((r) => r.bom_template_id === selectedTemplateId);
  }, [parentRows, selectedTemplateId]);

  const handleSaveAllAffects = useCallback(
    async (changes: Array<{ componentId: string; role: string | null }>) => {
      await Promise.all(
        changes.map((c) => updateComponent(c.componentId, { affects_role: c.role || null })),
      );
      await fetchComponents(false);
    },
    [updateComponent, fetchComponents],
  );

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
      {/* Left: template list */}
      <div className="w-96 flex-shrink-0 flex flex-col bg-white border border-gray-200 rounded-lg overflow-hidden min-h-0">
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

      {/* Right: cut breakdown for selected template */}
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
            <div className="px-4 py-3 border-b border-gray-200 flex items-center gap-3 flex-shrink-0">
              <h3 className="text-sm font-semibold text-gray-900 truncate" title={selectedTemplate?.name}>
                {selectedTemplate?.name || 'Template'}
              </h3>
              {selectedTemplate?.product_type_name && (
                <span className="text-xs text-gray-500">{selectedTemplate.product_type_name}</span>
              )}
              <span className="text-xs text-gray-500 ml-auto">
                {componentsForSelected.length} component{componentsForSelected.length !== 1 ? 's' : ''}
              </span>
              {breakdownState.hasChanges && (
                <>
                  <button type="button" onClick={() => breakdownRef.current?.discard()} disabled={breakdownState.saving} className="text-xs text-gray-400 hover:text-gray-600 disabled:opacity-40">
                    Discard
                  </button>
                  <button type="button" onClick={() => breakdownRef.current?.save()} disabled={breakdownState.saving} className="inline-flex items-center gap-1 text-xs font-medium text-white bg-primary rounded px-2.5 py-1 disabled:opacity-40">
                    <Save className="h-3 w-3" />
                    {breakdownState.saving ? 'Saving…' : 'Save'}
                  </button>
                </>
              )}
            </div>
            <div className="flex-1 min-h-0">
              <EngineeringCutBreakdown
                ref={breakdownRef}
                parentRows={componentsForSelected}
                childrenByParent={childrenByParent}
                onSaveAll={handleSaveAllAffects}
                onPendingChange={handlePendingChange}
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
}
