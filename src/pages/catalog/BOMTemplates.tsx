import { useState, useEffect, useMemo, useRef } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Plus, Edit, Trash2, Search, Wrench, Copy, GripVertical, Package } from 'lucide-react';
import Input from '../../components/ui/Input';
import BOMTemplateModal from './bom-templates/BOMTemplateModal';

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

export default function BOMTemplates() {
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();

  const [templates, setTemplates] = useState<BOMTemplateRow[]>([]);
  const [components, setComponents] = useState<Map<string, BOMComponentRow[]>>(new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [draggedTemplateId, setDraggedTemplateId] = useState<string | null>(null);
  const [dragOverTemplateId, setDragOverTemplateId] = useState<string | null>(null);

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
        .eq('archived', false)
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: false });

      if (fetchErr && (fetchErr.code === '42703' || fetchErr.message?.includes('sort_order'))) {
        const retry = await supabase.from('BOMTemplates')
          .select('*, ProductType:product_type_id (id, name, code)')
          .eq('organization_id', activeOrganizationId).eq('is_active', true).eq('archived', false)
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

  const filteredTemplates = useMemo(() => {
    if (!searchTerm) return templates;
    const s = searchTerm.toLowerCase();
    return templates.filter((t: any) =>
      t.name?.toLowerCase().includes(s) || t.template_name?.toLowerCase().includes(s)
      || t.description?.toLowerCase().includes(s) || t.ProductType?.name?.toLowerCase().includes(s)
      || t.code?.toLowerCase().includes(s)
    );
  }, [templates, searchTerm]);

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
      const { error: err } = await supabase.from('BOMTemplates').update({ is_active: false }).eq('id', id).eq('organization_id', activeOrganizationId);
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

    const di = filteredTemplates.findIndex(t => t.id === draggedTemplateId);
    const ti = filteredTemplates.findIndex(t => t.id === targetId);
    if (di === -1 || ti === -1) { setDraggedTemplateId(null); return; }

    const reordered = [...filteredTemplates];
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
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">BOM Templates</h2>
          <p className="text-sm text-gray-500">Configure Bill of Materials for product types</p>
        </div>
        <button onClick={handleNewTemplate} className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors">
          <Plus className="w-4 h-4" />
          New BOM Template
        </button>
      </div>

      <div className="mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input type="text" placeholder="Search BOM templates..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} className="pl-10" />
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
          {filteredTemplates.map(template => {
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
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-lg font-semibold text-gray-900">
                          {template.name || template.template_name || template.ProductType?.name || 'BOM Template'}
                        </h3>
                      </div>
                      <p className="text-sm text-gray-600 mb-2">Product Type: {template.ProductType?.name || 'N/A'}</p>
                      {template.description && <p className="text-sm text-gray-500">{template.description}</p>}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => handleEditTemplate(template.id)} className="p-2 hover:bg-gray-100 rounded text-gray-600" title="Edit"><Edit className="w-4 h-4" /></button>
                    <button onClick={() => handleDuplicateTemplate(template)} className="p-2 hover:bg-gray-100 rounded text-gray-600" title="Duplicate"><Copy className="w-4 h-4" /></button>
                    <button onClick={() => handleDeleteTemplate(template.id)} className="p-2 hover:bg-red-100 rounded text-red-600" title="Delete"><Trash2 className="w-4 h-4" /></button>
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
