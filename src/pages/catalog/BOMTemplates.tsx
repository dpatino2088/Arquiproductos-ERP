import { useState, useEffect, useMemo, useRef } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useGranularAccess } from '../../hooks/usePermissions';
import { Plus, Edit, Trash2, Search, Filter, Wrench, Copy, GripVertical, Package, Shield } from 'lucide-react';
import BOMTemplateModal from './bom-templates/BOMTemplateModal';
import BOMRolesTab from './bom-templates/BOMRolesTab';

type BOMInternalTab = 'templates' | 'roles';

interface BOMTemplateRow {
  id: string;
  product_type_id: string;
  code?: string;
  name?: string;
  template_name?: string;
  description?: string;
  hardware_color?: string;
  panel_count_min?: number;
  panel_count_max?: number;
  manufacturer?: string;
  product_line?: string;
  drive_type?: string;
  drive_side?: string;
  opening_direction?: string;
  installation_location?: string;
  system_size?: string;
  headbox?: boolean;
  metadata?: any;
  is_active?: boolean;
  sort_order?: number;
  created_at: string;
  updated_at: string;
  ProductType?: { id: string; name: string; code: string };
}

interface BOMComponentRow {
  id: string;
  bom_template_id: string;
  component_role?: string;
  component_item_id?: string;
  qty_value?: number;
  CatalogItems?: { item_name?: string; sku?: string };
}

function normalizeSearchText(value: string): string {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export default function BOMTemplates() {
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const { canCreate: canCreateCat, canDelete: canDeleteCat } = useGranularAccess('catalog');
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();

  const [templates, setTemplates] = useState<BOMTemplateRow[]>([]);
  const [components, setComponents] = useState<Map<string, BOMComponentRow[]>>(new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [selectedProductTypes, setSelectedProductTypes] = useState<string[]>([]);
  const [headboxFilter, setHeadboxFilter] = useState<boolean | null>(null);
  const [draggedTemplateId, setDraggedTemplateId] = useState<string | null>(null);
  const [dragOverTemplateId, setDragOverTemplateId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<BOMInternalTab>(() => {
    try {
      const saved = sessionStorage.getItem('bom:activeTab');
      if (saved === 'roles') return saved;
    } catch { /* ignore */ }
    return 'templates';
  });

  useEffect(() => {
    try { sessionStorage.setItem('bom:activeTab', activeTab); } catch { /* ignore */ }
  }, [activeTab]);

  const PERSISTENCE_KEY = 'bomTemplates:editState';
  const [showTemplateModal, setShowTemplateModal] = useState(() => {
    try { const s = localStorage.getItem(PERSISTENCE_KEY); return s ? JSON.parse(s).showTemplateModal === true : false; }
    catch { return false; }
  });
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(() => {
    try { const s = localStorage.getItem(PERSISTENCE_KEY); return s ? JSON.parse(s).editingTemplateId || null : null; }
    catch { return null; }
  });

  useEffect(() => {
    const p = window.location.pathname;
    if (p.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
      ]);
    }
  }, [registerSubmodules]);

  const hasRestoredState = useRef(false);
  useEffect(() => {
    if (hasRestoredState.current || !activeOrganizationId) return;
    const pId = editingTemplateId;
    const pModal = showTemplateModal;
    if (pId && pModal) {
      hasRestoredState.current = true;
      supabase.from('BOMTemplates').select('id').eq('id', pId).eq('organization_id', activeOrganizationId).eq('is_active', true).eq('archived', false).single()
        .then(({ error: err }: any) => {
          if (err) { localStorage.removeItem(PERSISTENCE_KEY); setShowTemplateModal(false); setEditingTemplateId(null); }
        });
    } else { hasRestoredState.current = true; }
  }, [activeOrganizationId, editingTemplateId, showTemplateModal]);

  useEffect(() => {
    try { localStorage.setItem(PERSISTENCE_KEY, JSON.stringify({ editingTemplateId, showTemplateModal })); }
    catch { /* ignore */ }
  }, [editingTemplateId, showTemplateModal]);

  useEffect(() => {
    const handler = (e: Event) => {
      const templateId = (e as CustomEvent<string>).detail;
      if (templateId) {
        setActiveTab('templates');
        setEditingTemplateId(templateId);
        setShowTemplateModal(true);
      }
    };
    window.addEventListener('bom:editTemplate', handler);
    return () => window.removeEventListener('bom:editTemplate', handler);
  }, []);

  // ========== LOAD TEMPLATES ==========

  const loadTemplates = async () => {
    if (!activeOrganizationId) { setLoading(false); return; }
    try {
      setLoading(true);
      setError(null);
      let { data, error: fetchErr } = await supabase
        .from('BOMTemplates')
        .select('*, ProductType:product_type_id (id, name, code)')
        .eq('organization_id', activeOrganizationId)
        .eq('is_active', true)
        .eq('deleted', false)
        .eq('archived', false)
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: false });

      if (fetchErr && (fetchErr.code === '42703' || fetchErr.message?.includes('sort_order'))) {
        const retry = await supabase.from('BOMTemplates')
          .select('*, ProductType:product_type_id (id, name, code)')
          .eq('organization_id', activeOrganizationId).eq('is_active', true).eq('deleted', false).eq('archived', false)
          .order('created_at', { ascending: false });
        data = retry.data; fetchErr = retry.error;
      }
      if (fetchErr) throw fetchErr;
      setTemplates(data || []);

      if (data?.length) {
        const ids = data.map((t: any) => t.id);
        const { data: comps } = await supabase
          .from('BOMComponents')
          .select('*')
          .in('bom_template_id', ids)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false).eq('archived', false)
          .order('sort_order', { ascending: true });
        if (comps) {
          const m = new Map<string, BOMComponentRow[]>();
          comps.forEach((c: any) => {
            if (!m.has(c.bom_template_id)) m.set(c.bom_template_id, []);
            m.get(c.bom_template_id)!.push(c);
          });
          setComponents(m);
        }
      }
    } catch (err: any) {
      setError(err?.message || 'Error loading BOM templates');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadTemplates(); }, [activeOrganizationId]);

  const productTypeOptions = useMemo(
    () => Array.from(new Set(templates.map((t) => t.ProductType?.name).filter(Boolean))) as string[],
    [templates]
  );
  const totalActiveFilters = selectedProductTypes.length + (headboxFilter != null ? 1 : 0);

  const filteredTemplates = useMemo(() => {
    const normalizedSearch = normalizeSearchText(searchTerm);
    const tokens = normalizedSearch ? normalizedSearch.split(/\s+/).filter(Boolean) : [];
    let result = templates;
    if (tokens.length > 0) {
      result = result.filter((t: any) =>
        {
          const haystack = normalizeSearchText([
            t.name,
            t.template_name,
            t.description,
            t.ProductType?.name,
            t.ProductType?.code,
            t.code,
          ].filter(Boolean).join(' '));
          return tokens.every((token) => haystack.includes(token));
        }
      );
    }
    if (selectedProductTypes.length > 0) {
      result = result.filter((t) => selectedProductTypes.includes(t.ProductType?.name || ''));
    }
    if (headboxFilter != null) {
      result = result.filter((t) => (t.headbox === true) === headboxFilter);
    }
    return result;
  }, [templates, searchTerm, selectedProductTypes, headboxFilter]);

  // ========== ACTIONS ==========

  const handleNewTemplate = () => { setEditingTemplateId(null); setShowTemplateModal(true); };
  const handleEditTemplate = (id: string) => { setEditingTemplateId(id); setShowTemplateModal(true); };

  const handleCloseModal = () => {
    setShowTemplateModal(false);
    setEditingTemplateId(null);
    try { localStorage.removeItem(PERSISTENCE_KEY); } catch { /* ignore */ }
  };

  const handleSaveComplete = () => {
    handleCloseModal();
    loadTemplates();
  };

  const handleDeleteTemplate = async (id: string) => {
    const confirmed = await showConfirm({
      title: 'Delete BOM Template',
      message: 'Are you sure you want to delete this BOM template? This action cannot be undone.',
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;
    try {
      setLoading(true);
      const { error: err } = await supabase.from('BOMTemplates').update({ is_active: false, deleted: true }).eq('id', id).eq('organization_id', activeOrganizationId);
      if (err) throw err;
      useUIStore.getState().addNotification({ type: 'success', title: 'Success', message: 'BOM Template deleted successfully' });
      setTemplates(prev => prev.filter(t => t.id !== id));
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message || 'Failed to delete BOM template' });
    } finally {
      setLoading(false);
    }
  };

  const handleDuplicateTemplate = async (template: BOMTemplateRow) => {
    if (!activeOrganizationId) return;
    const confirmed = await showConfirm({
      title: 'Duplicate BOM Template',
      message: `Are you sure you want to duplicate "${template.name || template.template_name || 'this template'}"?`,
      variant: 'info',
      confirmText: 'Duplicate',
    });
    if (!confirmed) return;
    try {
      setLoading(true);
      const baseCode = ((template as any).code || 'BOM').trim().toUpperCase();
      let code = `${baseCode}_COPY`;
      let attempt = 1;
      let created: any = null;
      while (!created && attempt <= 20) {
        const { data, error: err } = await supabase.from('BOMTemplates')
          .insert({
            organization_id: activeOrganizationId,
            product_type_id: template.product_type_id,
            code,
            name: `${template.name || template.template_name || 'BOM'} Copy`,
            description: template.description || null,
            hardware_color: template.hardware_color || null,
            panel_count_min: template.panel_count_min ?? 1,
            panel_count_max: template.panel_count_max ?? 1,
            metadata: template.metadata || {},
            is_active: true,
            archived: false,
          })
          .select('*')
          .single();
        if (!err && data) { created = data; break; }
        if (err?.code !== '23505') throw err;
        attempt++;
        code = `${baseCode}_COPY_${attempt}`;
      }
      if (!created) throw new Error('Failed to create duplicated template (code conflict)');

      const { data: comps } = await supabase.from('BOMComponents')
        .select('*')
        .eq('bom_template_id', template.id)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false).eq('archived', false)
        .order('parent_component_id', { ascending: true })
        .order('sort_order', { ascending: true });

      if (comps?.length) {
        const parents = comps.filter((c: any) => !c.parent_component_id);
        const children = comps.filter((c: any) => !!c.parent_component_id);
        const idMap = new Map<string, string>();

        for (const p of parents) {
          const { id: _id, created_at: _ca, updated_at: _ua, ...rest } = p;
          const { data: np } = await supabase.from('BOMComponents')
            .insert({ ...rest, bom_template_id: created.id, parent_component_id: null })
            .select('id').single();
          if (np) idMap.set(p.id, np.id);
        }
        for (const c of children) {
          const { id: _id, created_at: _ca, updated_at: _ua, ...rest } = c;
          const mappedParent = idMap.get(c.parent_component_id) || null;
          await supabase.from('BOMComponents')
            .insert({ ...rest, bom_template_id: created.id, parent_component_id: mappedParent })
            .select('id').single();
        }
      }

      useUIStore.getState().addNotification({ type: 'success', title: 'Duplicated', message: 'BOM template duplicated successfully.' });
      setEditingTemplateId(created.id);
      setShowTemplateModal(true);
      loadTemplates();
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Duplicate Failed', message: err?.message || 'Failed to duplicate' });
    } finally {
      setLoading(false);
    }
  };

  // ========== DRAG AND DROP ==========

  const handleDrop = (e: React.DragEvent, targetId: string) => {
    e.preventDefault();
    setDragOverTemplateId(null);
    if (!draggedTemplateId || draggedTemplateId === targetId || !activeOrganizationId) { setDraggedTemplateId(null); return; }
    if (searchTerm.trim()) {
      useUIStore.getState().addNotification({
        type: 'info',
        title: 'Reorder disabled while searching',
        message: 'Clear search to reorder BOM templates.',
      });
      setDraggedTemplateId(null);
      return;
    }

    const di = templates.findIndex(t => t.id === draggedTemplateId);
    const ti = templates.findIndex(t => t.id === targetId);
    if (di === -1 || ti === -1) { setDraggedTemplateId(null); return; }

    const reordered = [...templates];
    const [dragged] = reordered.splice(di, 1);
    reordered.splice(ti, 0, dragged);

    setTemplates(reordered);
    setDraggedTemplateId(null);

    const updates = reordered.map((t, i) => ({ id: t.id, sort_order: i }));
    supabase.rpc('update_bom_template_sort_orders', { p_organization_id: activeOrganizationId, p_updates: updates })
      .then(({ error: err }: { error: any }) => {
        if (err) {
          if (err.code === '42883') {
            Promise.all(updates.map(u => supabase.from('BOMTemplates').update({ sort_order: u.sort_order }).eq('id', u.id).eq('organization_id', activeOrganizationId)));
          } else {
            console.warn('[BOMTemplates] Background reorder persist failed:', err.message);
          }
        }
      });
  };

  // ========== RENDER ==========

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h1 className="text-title font-semibold text-foreground">BOM</h1>
        </div>
        {activeTab === 'templates' && canCreateCat && (
          <button onClick={handleNewTemplate} className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded hover:bg-primary/90 transition-colors">
            <Plus className="w-4 h-4" />
            New BOM Template
          </button>
        )}
      </div>

      {/* Internal tab bar */}
      <div className="flex gap-1 mb-5 border-b border-gray-200">
        {([
          { key: 'templates' as BOMInternalTab, label: 'Templates', icon: Wrench },
          { key: 'roles' as BOMInternalTab, label: 'Roles', icon: Shield },
        ]).map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setActiveTab(key)}
            className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium border-b-2 transition-colors -mb-px ${
              activeTab === key
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            <Icon className="w-4 h-4" />
            {label}
          </button>
        ))}
      </div>

      {/* Roles tab */}
      <div hidden={activeTab !== 'roles'}>
        <BOMRolesTab />
      </div>

      {/* Templates tab */}
      <div hidden={activeTab !== 'templates'}>

      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}>
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search BOM templates..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-2 py-1 text-sm font-medium rounded border transition-colors ${
                showFilters || totalActiveFilters > 0
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter style={{ width: 14, height: 14 }} />
              Filters
              {totalActiveFilters > 0 && (
                <span className="bg-white text-blue-600 rounded-full px-2 py-0.5 text-xs font-semibold">
                  {totalActiveFilters}
                </span>
              )}
            </button>
          </div>

          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200 space-y-4">
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-gray-700">Product Type</span>
                  {selectedProductTypes.length > 0 && (
                    <button onClick={() => setSelectedProductTypes([])} className="text-xs text-gray-500 hover:text-gray-700">
                      Clear
                    </button>
                  )}
                </div>
                <div className="flex flex-wrap gap-2">
                  {productTypeOptions.map((name) => (
                    <button
                      key={name}
                      onClick={() =>
                        setSelectedProductTypes((prev) =>
                          prev.includes(name) ? prev.filter((v) => v !== name) : [...prev, name]
                        )
                      }
                      className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                        selectedProductTypes.includes(name) ? 'bg-blue-600 text-white' : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                      }`}
                    >
                      {name}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-gray-700">Headbox</span>
                  {headboxFilter != null && (
                    <button onClick={() => setHeadboxFilter(null)} className="text-xs text-gray-500 hover:text-gray-700">
                      Clear
                    </button>
                  )}
                </div>
                <div className="flex gap-2">
                  {([{ label: 'With Headbox', value: true }, { label: 'Without Headbox', value: false }] as const).map(({ label, value }) => (
                    <button
                      key={String(value)}
                      onClick={() => setHeadboxFilter(headboxFilter === value ? null : value)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                        headboxFilter === value ? 'bg-blue-600 text-white' : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
          <p className="text-sm text-gray-600">Loading BOM templates...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">Error: {error}</p>
        </div>
      ) : filteredTemplates.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <Wrench className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 mb-2">No BOM templates found</p>
          <p className="text-sm text-gray-500">Create your first BOM template to get started</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredTemplates.map((template, idx) => {
            const tc = components.get(template.id) || [];
            return (
              <div
                key={template.id}
                draggable
                onDragStart={() => setDraggedTemplateId(template.id)}
                onDragOver={(e) => { e.preventDefault(); if (draggedTemplateId && draggedTemplateId !== template.id) setDragOverTemplateId(template.id); }}
                onDragLeave={() => setDragOverTemplateId(null)}
                onDrop={(e) => handleDrop(e, template.id)}
                className={`bg-white border rounded-lg p-6 transition-all ${draggedTemplateId === template.id ? 'opacity-50 cursor-grabbing' : 'cursor-grab'} ${dragOverTemplateId === template.id ? 'border-primary border-2 shadow-md' : 'border-gray-200'}`}
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-start gap-2 flex-1">
                    <div className="cursor-grab active:cursor-grabbing text-gray-400 hover:text-gray-600 mt-1" title="Drag to reorder">
                      <GripVertical className="w-5 h-5" />
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-0.5">
                        <span className="text-xs font-medium text-gray-400 tabular-nums">{idx + 1}/{filteredTemplates.length}</span>
                        <h3 className="text-base font-semibold text-gray-900">
                          {template.name || template.template_name || template.ProductType?.name || 'BOM Template'}
                        </h3>
                      </div>
                      {(template as any).code && (
                        <p className="text-xs font-mono text-primary/70 mb-1">{(template as any).code}</p>
                      )}
                      <p className="text-xs text-gray-500 mb-2">Product Type: {template.ProductType?.name || 'N/A'}</p>
                      <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-600">
                        {template.manufacturer && (
                          <span><b className="text-gray-700">Manufacturer:</b> {template.manufacturer}</span>
                        )}
                        {template.product_line && (
                          <span><b className="text-gray-700">Product Line:</b> {template.product_line}</span>
                        )}
                        {template.hardware_color && (
                          <span><b className="text-gray-700">Color:</b> {template.hardware_color}</span>
                        )}
                        <span>
                          <b className="text-gray-700">Drive Type:</b>{' '}
                          {template.drive_type === 'motor' ? 'Motor' : template.drive_type === 'manual' ? 'Manual' : '—'}
                        </span>
                        <span>
                          <b className="text-gray-700">Drive Side:</b>{' '}
                          {template.drive_side === 'left' ? 'Left' : template.drive_side === 'right' ? 'Right' : 'L / R'}
                        </span>
                        {template.system_size && (
                          <span><b className="text-gray-700">System:</b> {template.system_size}</span>
                        )}
                        {template.opening_direction && (
                          <span>
                            <b className="text-gray-700">Opening:</b>{' '}
                            {template.opening_direction === 'center' ? 'Center' : template.opening_direction === 'left' ? 'Left' : 'Right'}
                          </span>
                        )}
                        {template.installation_location && (
                          <span>
                            <b className="text-gray-700">Installation:</b>{' '}
                            {template.installation_location === 'ceiling' ? 'Ceiling' : 'Wall'}
                          </span>
                        )}
                        {template.system_size && (
                          <span><b className="text-gray-700">Size:</b> {template.system_size}</span>
                        )}
                        <span>
                          <b className="text-gray-700">Headbox:</b>{' '}
                          {template.headbox
                            ? <span className="text-green-700 font-medium">Yes</span>
                            : <span className="text-gray-400">No</span>
                          }
                        </span>
                      </div>
                      {template.description && <p className="text-xs text-gray-400 mt-1">{template.description}</p>}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => handleEditTemplate(template.id)} className="p-2 hover:bg-gray-100 rounded text-gray-600" title="Edit"><Edit className="w-4 h-4" /></button>
                    <button onClick={() => handleDuplicateTemplate(template)} className="p-2 hover:bg-gray-100 rounded text-gray-600" title="Duplicate"><Copy className="w-4 h-4" /></button>
                    {canDeleteCat && (
                      <button onClick={() => handleDeleteTemplate(template.id)} className="p-2 hover:bg-red-100 rounded text-red-600" title="Delete"><Trash2 className="w-4 h-4" /></button>
                    )}
                  </div>
                </div>
                {tc.length > 0 && (
                  <div className="mt-4 pt-4 border-t border-gray-200">
                    <p className="text-xs font-medium text-gray-700 mb-2">Components ({tc.length}):</p>
                    <div className="flex flex-wrap gap-2">
                      {tc.slice(0, 5).map(c => (
                        <span key={c.id} className="text-xs bg-gray-100 px-2 py-1 rounded">
                          {c.CatalogItems?.item_name || c.CatalogItems?.sku || c.component_role || 'Unknown'}
                          {(c.qty_value || 0) > 1 && ` (x${c.qty_value})`}
                        </span>
                      ))}
                      {tc.length > 5 && <span className="text-xs text-gray-500">+{tc.length - 5} more</span>}
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      </div>{/* end templates tab */}

      {showTemplateModal && (
        <BOMTemplateModal
          isOpen={showTemplateModal}
          editingTemplateId={editingTemplateId}
          onClose={handleCloseModal}
          onSave={handleSaveComplete}
        />
      )}

      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
