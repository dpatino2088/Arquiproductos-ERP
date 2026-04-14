import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useUIStore } from '../../../stores/ui-store';
import { useProductTypes } from '../../../hooks/useProductTypes';
import { useCatalogItems, useItemCategories, useLeafItemCategories } from '../../../hooks/useCatalog';
import { useBOMComponents } from '../../../hooks/useBOM';
import { normalizeRole, isValidRole, CANONICAL_COMPONENT_ROLES, VALID_CHILD_ROLES } from '../../../lib/bom/roles';
import { normalizeUom, canonicalUom } from '../../../lib/uom';
import { useOnVisibilityChange } from '../../../lib/app-persistence';
import type {
  BOMComponentDraft,
  ComponentFormData,
  ChildFormData,
  ComponentGroupedByCategory,
  BOMQtyType,
} from './types';
import {
  INITIAL_FORM_DATA,
  INITIAL_CHILD_FORM_DATA,
  getCascadeOrder,
  getDefaultDependsOn,
} from './types';

export function useBOMTemplateForm(editingTemplateId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const { productTypes } = useProductTypes();
  const { items: catalogItems } = useCatalogItems();
  const { categories } = useItemCategories();
  const { categories: leafCategories = [] } = useLeafItemCategories();
  const { components: existingComponents } = useBOMComponents(editingTemplateId || null);

  // --- Template fields ---
  const [productTypeId, setProductTypeId] = useState('');
  const [templateCode, setTemplateCode] = useState('');
  const [templateName, setTemplateName] = useState('');
  const [templateDescription, setTemplateDescription] = useState('');
  const [templateHardwareColor, setTemplateHardwareColor] = useState('');
  const [templatePanelCount, setTemplatePanelCount] = useState<number>(1);
  const [templateDriveType, setTemplateDriveType] = useState<'manual' | 'motor' | null>(null);
  const [templateDriveSide, setTemplateDriveSide] = useState<'left' | 'right' | 'both' | null>(null);
  const [templateOpeningDirection, setTemplateOpeningDirection] = useState<'left' | 'right' | 'center' | 'all' | null>(null);
  const [templateInstallationLocation, setTemplateInstallationLocation] = useState<'ceiling' | 'wall' | null>(null);
  const [templateManufacturer, setTemplateManufacturer] = useState<string | null>(null);
  const [templateProductLine, setTemplateProductLine] = useState<string | null>(null);
  const [templateSystemSize, setTemplateSystemSize] = useState<string | null>(null);
  const [templateHeadbox, setTemplateHeadbox] = useState<boolean>(false);

  // --- Components ---
  const [components, setComponents] = useState<BOMComponentDraft[]>([]);
  const [componentsToDelete, setComponentsToDelete] = useState<string[]>([]);
  const initialComponentsRef = useRef<BOMComponentDraft[]>([]);

  // --- Component form ---
  const [showAddComponentForm, setShowAddComponentForm] = useState(false);
  const [editingComponentId, setEditingComponentId] = useState<string | null>(null);
  const [formData, setFormData] = useState<ComponentFormData>({ ...INITIAL_FORM_DATA });
  const [componentSearchTerm, setComponentSearchTerm] = useState('');
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState('');
  const [showComponentDropdown, setShowComponentDropdown] = useState(false);
  const [highlightedIndex, setHighlightedIndex] = useState(-1);

  // --- Engineering popup ---
  const [showEngineeringPopup, setShowEngineeringPopup] = useState(false);
  const [editingEngineeringComponentId, setEditingEngineeringComponentId] = useState<string | null>(null);

  // --- Children modal ---
  const [showChildrenModal, setShowChildrenModal] = useState(false);
  const [editingParentComponentId, setEditingParentComponentId] = useState<string | null>(null);
  const [childComponents, setChildComponents] = useState<BOMComponentDraft[]>([]);
  const [showAddChildForm, setShowAddChildForm] = useState(false);
  const [editingChildId, setEditingChildId] = useState<string | null>(null);
  const [childFormData, setChildFormData] = useState<ChildFormData>({ ...INITIAL_CHILD_FORM_DATA });
  const [childSearchTerm, setChildSearchTerm] = useState('');
  const [showChildDropdown, setShowChildDropdown] = useState(false);
  /** True when the user has added, updated, or deleted a child without yet saving the main template */
  const [childrenHavePendingChanges, setChildrenHavePendingChanges] = useState(false);

  // --- Save state ---
  const [isSaving, setIsSaving] = useState(false);

  // --- Draft persistence ---
  const draftKey = `bomTemplateDraft:${editingTemplateId || 'new'}`;
  const isInitialMount = useRef(true);

  // ========== DERIVED DATA ==========

  const childrenByParent = useMemo(() => {
    const grouped: Record<string, BOMComponentDraft[]> = {};
    (components || [])
      .filter(c => c.parent_component_id)
      .forEach(child => {
        const pid = child.parent_component_id!;
        if (!grouped[pid]) grouped[pid] = [];
        grouped[pid].push(child);
      });
    Object.values(grouped).forEach(list =>
      list.sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
    );
    return grouped;
  }, [components]);

  const displayComponents = useMemo(
    () => (components || []).filter(c => !c.parent_component_id),
    [components]
  );

  const componentsByCategory = useMemo((): ComponentGroupedByCategory[] => {
    if (!displayComponents.length) return [];

    const cuttable: BOMComponentDraft[] = [];
    const units: BOMComponentDraft[] = [];
    displayComponents.forEach(c => {
      const order = getCascadeOrder(c.component_role);
      const item = catalogItems.find(i => i.id === c.component_item_id) || c.catalog_item;
      const mb = (item as any)?.measure_basis;
      const isCuttable = mb === 'linear' || mb === 'area' || c.uom === 'm' || c.uom === 'm2';
      if (isCuttable || order < 80) {
        cuttable.push(c);
      } else {
        units.push(c);
      }
    });

    cuttable.sort((a, b) => getCascadeOrder(a.component_role) - getCascadeOrder(b.component_role) || (a.sort_order || 0) - (b.sort_order || 0));
    units.sort((a, b) => getCascadeOrder(a.component_role) - getCascadeOrder(b.component_role) || (a.sort_order || 0) - (b.sort_order || 0));

    const groups: ComponentGroupedByCategory[] = [];
    if (cuttable.length > 0) {
      groups.push({ category_id: '__cascade_cuttable', category_name: 'CASCADE ORDER (Cuttable)', category_code: '__cascade', components: cuttable });
    }
    if (units.length > 0) {
      groups.push({ category_id: '__cascade_units', category_name: 'UNIT ITEMS (No Cut)', category_code: '__units', components: units });
    }
    return groups;
  }, [displayComponents, catalogItems]);

  const isDirty = useMemo(() => {
    const initial = initialComponentsRef.current;
    if (components.length !== initial.length) return true;
    if (componentsToDelete.length > 0) return true;
    return components.some((c, i) => {
      const orig = initial[i];
      if (!orig) return true;
      return c.component_item_id !== orig.component_item_id
        || c.component_role !== orig.component_role
        || c.qty_type !== orig.qty_type
        || c.qty_value !== orig.qty_value
        || c.uom !== orig.uom
        || c.depends_on_role !== orig.depends_on_role
        || c.affects_role !== orig.affects_role
        || c.cut_axis !== orig.cut_axis
        || c.cut_delta_mm !== orig.cut_delta_mm
        || c.delta_mode !== orig.delta_mode;
    });
  }, [components, componentsToDelete]);

  // ========== FLAT FILTERED ITEMS (autocomplete) ==========

  const flatFilteredItems = useMemo(() => {
    const items: Array<{ id: string; sku: string; name: string; category: string; categoryCode: string | null; uom: string }> = [];
    const searchTerm = componentSearchTerm.trim();
    const normalizedSearch = searchTerm.toLowerCase().replace(/[-_\s]/g, '');
    const filtered = catalogItems.filter(item => {
      if (selectedCategoryFilter) {
        const catId = item.category_id || item.item_category_id;
        if (catId !== selectedCategoryFilter) return false;
      }
      if (normalizedSearch) {
        const skuNorm = (item.sku || '').toLowerCase().replace(/[-\s]/g, '');
        const skuExact = (item.sku || '').toLowerCase();
        const itemName = (item.name || item.item_name || '').toLowerCase();
        const catId = item.category_id || item.item_category_id;
        const cat = categories.find(c => c.id === catId);
        const catName = (cat?.name || '').toLowerCase();
        const catCode = (cat?.code || '').toLowerCase();
        const searchLower = searchTerm.toLowerCase();
        if (!(skuExact.includes(searchLower) || skuNorm.includes(normalizedSearch) || itemName.includes(searchLower) || catName.includes(searchLower) || catCode.includes(searchLower)))
          return false;
      }
      return true;
    });
    const categoryMap = new Map<string | null, { category: any; items: any[] }>();
    filtered.forEach(item => {
      const catId = item.category_id || item.item_category_id || null;
      const cat = categories.find(c => c.id === catId) || { id: null, name: 'Uncategorized', code: null };
      if (!categoryMap.has(catId)) categoryMap.set(catId, { category: cat, items: [] });
      categoryMap.get(catId)!.items.push(item);
    });
    categoryMap.forEach(group => {
      group.items.forEach(item => {
        items.push({ id: item.id, sku: item.sku || '', name: item.name || item.item_name || 'Unnamed', category: group.category.name, categoryCode: group.category.code, uom: item.uom || 'ea' });
      });
    });
    return items;
  }, [catalogItems, componentSearchTerm, selectedCategoryFilter, components, categories, editingComponentId]);

  // ========== LOAD TEMPLATE DATA ==========

  useEffect(() => {
    if (editingTemplateId && activeOrganizationId) {
      supabase.from('BOMTemplates').select('*').eq('id', editingTemplateId).single()
        .then(({ data, error }: any) => {
          if (!error && data) {
            setProductTypeId(data.product_type_id);
            setTemplateCode(data.code || '');
            setTemplateName(data.name || '');
            setTemplateDescription(data.description || '');
            setTemplateHardwareColor(data.hardware_color || '');
            const pc = data.panel_count_max ?? data.panel_count_min ?? 1;
            setTemplatePanelCount(Math.max(1, Number(pc) || 1));
            setTemplateDriveType(data.drive_type || null);
            setTemplateDriveSide(data.drive_side === 'left' ? 'left' : data.drive_side === 'right' ? 'right' : data.drive_type ? 'both' : null);
            setTemplateOpeningDirection(data.opening_direction || (data.product_type_id ? 'all' : null));
            setTemplateManufacturer(data.manufacturer || null);
            setTemplateProductLine(data.product_line || null);
            setTemplateSystemSize(data.system_size || null);
            setTemplateInstallationLocation(data.installation_location || null);
            setTemplateHeadbox(data.headbox === true);
          }
        });
    } else if (!editingTemplateId) {
      setProductTypeId('');
      setTemplateCode('');
      setTemplateName('');
      setTemplateDescription('');
      setTemplateHardwareColor('');
      setTemplatePanelCount(1);
      setTemplateDriveType(null);
      setTemplateDriveSide(null);
      setTemplateOpeningDirection(null);
      setTemplateManufacturer(null);
      setTemplateProductLine(null);
      setTemplateSystemSize(null);
      setTemplateHeadbox(false);
      setComponents([]);
      setComponentsToDelete([]);
      initialComponentsRef.current = [];
    }
  }, [editingTemplateId, activeOrganizationId]);

  useEffect(() => {
    if (!editingTemplateId) { setComponents([]); setComponentsToDelete([]); initialComponentsRef.current = []; return; }
    setComponents([]);
    setComponentsToDelete([]);
    setEditingComponentId(null);
    setShowAddComponentForm(false);
    initialComponentsRef.current = [];
  }, [editingTemplateId]);

  useEffect(() => {
    if (!editingTemplateId || !existingComponents?.length) return;
    const mapped: BOMComponentDraft[] = existingComponents.map((comp: any) => {
      const catItem = comp.component_item_id
        ? catalogItems.find(i => i.id === comp.component_item_id)
        : null;
      const isFabric = comp.component_role === 'fabric';
      const syncedUom = isFabric
        ? 'm'
        : canonicalUom(catItem?.unit_of_measure || catItem?.uom || comp.uom, catItem?.measure_basis);
      return {
        id: comp.id,
        parent_component_id: comp.parent_component_id || null,
        component_item_id: comp.component_item_id || null,
        component_role: comp.component_role || null,
        qty_type: comp.qty_type || 'fixed',
        qty_value: comp.qty_value || 1,
        qty_delta_mm: comp.qty_delta_mm || 0,
        waste_pct: comp.waste_pct || 0,
        depends_on_role: comp.depends_on_role || null,
        affects_role: comp.affects_role || null,
        cut_axis: comp.cut_axis || null,
        cut_delta_mm: comp.cut_delta_mm || 0,
        delta_mode: comp.delta_mode || 'subtract',
        qty_spacing_mm: comp.qty_spacing_mm ?? null,
        qty_min: comp.qty_min != null ? Number(comp.qty_min) : null,
        uom: syncedUom,
        sort_order: comp.sort_order || 0,
        is_required: comp.is_required !== false,
        per_panel: comp.per_panel === true,
        auto_select: false,
        condition_key: comp.condition_key || null,
        condition_value: comp.condition_value || null,
        catalog_item: catItem
          ? { id: catItem.id, sku: catItem.sku, name: catItem.name ?? catItem.item_name, delta_x_mm: catItem.delta_x_mm ?? null, delta_y_mm: catItem.delta_y_mm ?? null, measure_basis: catItem.measure_basis ?? null }
          : comp.component_item || null,
      };
    });
    const unique = Array.from(new Map(mapped.map(c => [c.id, c])).values());
    setComponents(unique);
    setComponentsToDelete([]);
    initialComponentsRef.current = unique.map(c => ({ ...c }));
  }, [editingTemplateId, existingComponents, catalogItems]);

  // ========== DRAFT PERSISTENCE ==========

  useEffect(() => {
    if (isInitialMount.current) {
      try {
        const raw = sessionStorage.getItem(draftKey);
        if (raw) {
          const p = JSON.parse(raw);
          if (p.productTypeId) setProductTypeId(p.productTypeId);
          if (p.templateCode) setTemplateCode(p.templateCode);
          if (p.templateName) setTemplateName(p.templateName);
          if (p.templateDescription) setTemplateDescription(p.templateDescription);
          if (p.templateHardwareColor !== undefined) setTemplateHardwareColor(p.templateHardwareColor || '');
          if (p.templatePanelCount !== undefined) setTemplatePanelCount(Math.max(1, Number(p.templatePanelCount) || 1));
          if (p.templateDriveType !== undefined) setTemplateDriveType(p.templateDriveType || null);
          if (p.templateDriveSide !== undefined) setTemplateDriveSide(p.templateDriveSide || null);
          if (p.templateOpeningDirection !== undefined) setTemplateOpeningDirection(p.templateOpeningDirection || null);
          if (p.templateInstallationLocation !== undefined) setTemplateInstallationLocation(p.templateInstallationLocation || null);
          if (p.templateManufacturer !== undefined) setTemplateManufacturer(p.templateManufacturer || null);
          if (p.templateProductLine !== undefined) setTemplateProductLine(p.templateProductLine || null);
          if (p.templateSystemSize !== undefined) setTemplateSystemSize(p.templateSystemSize || null);
          if (p.templateHeadbox !== undefined) setTemplateHeadbox(p.templateHeadbox === true);
          if (p.components && (!editingTemplateId || p.components.length > 0)) setComponents(p.components);
          if (Array.isArray(p.componentsToDelete) && p.componentsToDelete.length > 0) setComponentsToDelete(p.componentsToDelete);
        }
      } catch { /* ignore */ }
      isInitialMount.current = false;
    }
  }, [draftKey, editingTemplateId]);

  useEffect(() => {
    if (isInitialMount.current) return;
    try {
      sessionStorage.setItem(draftKey, JSON.stringify({
        productTypeId, templateCode, templateName, templateDescription,
        templateHardwareColor, templatePanelCount, templateDriveType, templateDriveSide, templateOpeningDirection,
        templateInstallationLocation, templateManufacturer, templateProductLine, templateSystemSize, templateHeadbox,
        components, componentsToDelete,
      }));
    } catch { /* ignore */ }
  }, [draftKey, productTypeId, templateCode, templateName, templateDescription, templateHardwareColor, templatePanelCount, templateDriveType, templateDriveSide, templateOpeningDirection, templateInstallationLocation, templateManufacturer, templateProductLine, templateSystemSize, templateHeadbox, components, componentsToDelete]);

  useOnVisibilityChange(useCallback(() => {
    if (document.visibilityState !== 'visible') return;
    try {
      const raw = sessionStorage.getItem(draftKey);
      if (raw) {
        const p = JSON.parse(raw);
        if (p.productTypeId) setProductTypeId(p.productTypeId);
        if (p.templateCode) setTemplateCode(p.templateCode);
        if (p.templateName) setTemplateName(p.templateName);
        if (p.templateDescription) setTemplateDescription(p.templateDescription);
        if (p.templateHardwareColor !== undefined) setTemplateHardwareColor(p.templateHardwareColor || '');
        if (p.templatePanelCount !== undefined) setTemplatePanelCount(Math.max(1, Number(p.templatePanelCount) || 1));
        if (p.templateDriveType !== undefined) setTemplateDriveType(p.templateDriveType || null);
        if (p.templateDriveSide !== undefined) setTemplateDriveSide(p.templateDriveSide || null);
        if (p.templateOpeningDirection !== undefined) setTemplateOpeningDirection(p.templateOpeningDirection || null);
        if (p.templateManufacturer !== undefined) setTemplateManufacturer(p.templateManufacturer || null);
        if (p.templateProductLine !== undefined) setTemplateProductLine(p.templateProductLine || null);
        if (p.templateSystemSize !== undefined) setTemplateSystemSize(p.templateSystemSize || null);
        if (p.templateHeadbox !== undefined) setTemplateHeadbox(p.templateHeadbox === true);
        if (p.components && (!editingTemplateId || p.components.length > 0)) setComponents(p.components);
        if (Array.isArray(p.componentsToDelete) && p.componentsToDelete.length > 0) setComponentsToDelete(p.componentsToDelete);
      }
    } catch { /* ignore */ }
  }, [draftKey, editingTemplateId]));

  const clearDraft = useCallback(() => { sessionStorage.removeItem(draftKey); }, [draftKey]);

  // ========== COMPONENT FORM HANDLERS ==========

  const resetForm = useCallback(() => {
    setEditingComponentId(null);
    setFormData({ ...INITIAL_FORM_DATA, sort_order: components.length });
    setShowAddComponentForm(false);
    setComponentSearchTerm('');
    setSelectedCategoryFilter('');
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  }, [components.length]);

  const handleSelectComponent = useCallback((itemId: string) => {
    const sel = catalogItems.find(i => i.id === itemId);
    if (!sel) return;
    const autoRole = normalizeRole(sel.item_role) || '';
    const isFabric = sel.is_fabric || autoRole === 'fabric';
    const catalogUom = isFabric ? 'm' : canonicalUom(sel.unit_of_measure || sel.uom, sel.measure_basis);
    setFormData(prev => ({ ...prev, component_item_id: itemId, component_role: autoRole || prev.component_role, uom: catalogUom }));
    setComponentSearchTerm(`${sel.sku} - ${sel.name || sel.item_name || ''}`);
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  }, [catalogItems]);

  const handleAddComponent = useCallback(() => {
    if (!formData.component_item_id) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Selecciona un componente (SKU)' }); return; }
    if (!formData.component_role || !isValidRole(formData.component_role)) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Component role is required and must be valid.' }); return; }
    if (!formData.qty_type) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Quantity Type is required.' }); return; }
    if (formData.qty_type === 'fixed' && (!formData.qty_value || formData.qty_value <= 0)) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Quantity Value must be > 0.' }); return; }

    const role = normalizeRole(formData.component_role) || formData.component_role;

    const duplicate = components.some(c =>
      !c.parent_component_id
      && c.component_item_id === formData.component_item_id
      && c.component_role === role,
    );
    if (duplicate) {
      const sel = catalogItems.find(i => i.id === formData.component_item_id);
      useUIStore.getState().addNotification({ type: 'error', title: 'Duplicate', message: `${sel?.sku ?? 'SKU'} already exists with role "${role}". Use a different role.` });
      return;
    }
    const isFabric = role === 'fabric';
    const sel = catalogItems.find(i => i.id === formData.component_item_id);
    const finalUom = isFabric ? 'm' : canonicalUom(formData.uom || sel?.unit_of_measure || sel?.uom, sel?.measure_basis);
    const finalQty = isFabric && formData.qty_type === 'fixed' ? 'per_area' : formData.qty_type;

    const cascadeOrder = getCascadeOrder(role);
    const defaultDep = getDefaultDependsOn(role);

    const newComp: BOMComponentDraft = {
      id: `temp-${crypto.randomUUID()}`,
      parent_component_id: null,
      component_item_id: formData.component_item_id,
      component_role: role,
      qty_type: finalQty,
      qty_value: finalQty === 'fixed' ? (formData.qty_value || 1)
        : finalQty === 'per_spacing' ? 1
        : (formData.qty_value || 1),
      qty_delta_mm: 0,
      waste_pct: 0,
      depends_on_role: defaultDep,
      affects_role: null,
      cut_axis: null,
      cut_delta_mm: 0,
      qty_spacing_mm: finalQty === 'per_spacing' ? (formData.qty_spacing_mm ?? 500) : null,
      qty_min: finalQty === 'per_spacing' ? formData.qty_min : null,
      uom: finalUom,
      sort_order: cascadeOrder,
      is_required: formData.is_required ?? true,
      per_panel: formData.per_panel ?? false,
      auto_select: false,
      condition_key: formData.condition_key || null,
      condition_value: formData.condition_value || null,
      catalog_item: sel ? { id: sel.id, sku: sel.sku, name: sel.name || sel.item_name || null } : null,
    };
    setComponents(prev => [...prev, newComp]);
    resetForm();
  }, [formData, catalogItems, resetForm]);

  const handleUpdateComponent = useCallback(() => {
    if (!editingComponentId) return;
    if (!formData.component_item_id) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Selecciona un componente (SKU)' }); return; }

    let role = formData.component_role;
    if (!role && formData.component_item_id) {
      const sel = catalogItems.find(i => i.id === formData.component_item_id);
      role = sel ? (normalizeRole(sel.item_role) || '') : '';
    }
    if (!role || !isValidRole(role)) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Component role is required and must be valid.' }); return; }

    const normalized = normalizeRole(role) || role;
    const isFabric = normalized === 'fabric';
    const sel = catalogItems.find(i => i.id === formData.component_item_id);
    const finalUom = isFabric ? 'm' : canonicalUom(formData.uom || sel?.unit_of_measure || sel?.uom, sel?.measure_basis);
    const finalQty = isFabric && formData.qty_type === 'fixed' ? 'per_area' : formData.qty_type;

    setComponents(prev => prev.map(c => {
      if (c.id !== editingComponentId) return c;
      return {
        ...c,
        component_item_id: formData.component_item_id,
        component_role: normalized,
        qty_type: finalQty,
        qty_value: finalQty === 'per_spacing' ? 1 : (formData.qty_value || 1),
        qty_spacing_mm: finalQty === 'per_spacing' ? (formData.qty_spacing_mm ?? 500) : null,
        qty_min: finalQty === 'per_spacing' ? formData.qty_min : null,
        uom: finalUom,
        sort_order: formData.sort_order ?? 0,
        is_required: formData.is_required ?? true,
        per_panel: formData.per_panel ?? false,
        condition_key: formData.condition_key || null,
        condition_value: formData.condition_value || null,
        catalog_item: sel ? { id: sel.id, sku: sel.sku, name: sel.name || sel.item_name || null } : c.catalog_item,
      };
    }));
    resetForm();
  }, [editingComponentId, formData, catalogItems, resetForm]);

  const handleDeleteComponent = useCallback((component: BOMComponentDraft) => {
    const id = component.id;
    const childIds = components.filter(c => c.parent_component_id === id).map(c => c.id);
    setComponents(prev => prev.filter(c => c.id !== id && !childIds.includes(c.id)));
    if (!id.startsWith('temp-')) {
      setComponentsToDelete(prev => {
        const s = new Set(prev);
        s.add(id);
        childIds.filter(cid => !cid.startsWith('temp-')).forEach(cid => s.add(cid));
        return Array.from(s);
      });
    }
  }, [components]);

  const handleEditComponent = useCallback((component: BOMComponentDraft) => {
    if (showChildrenModal) handleCloseChildrenModal();
    const itemId = component.component_item_id || '';
    const item = catalogItems.find(i => i.id === itemId);
    const display = item
      ? `${item.sku || 'N/A'} - ${item.name || 'Unnamed'}`
      : component.catalog_item ? `${component.catalog_item.sku || 'N/A'} - ${component.catalog_item.name || 'Unnamed'}` : '';
    const isFabric = component.component_role === 'fabric';
    const catalogItem = catalogItems.find(i => i.id === component.component_item_id);
    const uomNorm = isFabric ? 'm' : canonicalUom(component.uom || catalogItem?.unit_of_measure, catalogItem?.measure_basis);
    setEditingComponentId(component.id);
    setComponentSearchTerm(display);
    setFormData({
      component_item_id: itemId,
      component_role: component.component_role || '',
      qty_type: (component.qty_type || 'fixed') as BOMQtyType,
      qty_value: component.qty_type === 'fixed' ? (component.qty_value || 1)
        : component.qty_type === 'per_spacing' ? null
        : (component.qty_value || 1),
      qty_spacing_mm: component.qty_spacing_mm ?? null,
      qty_min: component.qty_min ?? null,
      uom: uomNorm,
      sort_order: component.sort_order || 0,
      is_required: component.is_required ?? true,
      per_panel: component.per_panel === true,
      condition_key: component.condition_key || '',
      condition_value: component.condition_value || '',
    });
    setShowAddComponentForm(true);
    setSelectedCategoryFilter('');
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  }, [catalogItems, showChildrenModal]);

  // ========== ENGINEERING POPUP ==========

  const handleOpenEngineeringPopup = useCallback((componentId: string) => {
    setEditingEngineeringComponentId(componentId);
    setShowEngineeringPopup(true);
  }, []);

  const handleCloseEngineeringPopup = useCallback(() => {
    setShowEngineeringPopup(false);
    setEditingEngineeringComponentId(null);
  }, []);

  const handlePatchComponent = useCallback((componentId: string, fields: Partial<BOMComponentDraft>) => {
    setComponents(prev => prev.map(c => c.id === componentId ? { ...c, ...fields } : c));
  }, []);

  // ========== CHILDREN MODAL ==========

  const handleOpenChildrenModal = useCallback((parentComponentId: string) => {
    if (!parentComponentId) return;
    setEditingParentComponentId(parentComponentId);
    setShowChildrenModal(true);
    setChildComponents(childrenByParent[parentComponentId] || []);
    setShowAddChildForm(true);
    setEditingChildId(null);
    setChildFormData({ ...INITIAL_CHILD_FORM_DATA });
    setChildSearchTerm('');
    setShowChildDropdown(false);
  }, [childrenByParent]);

  const handleCloseChildrenModal = useCallback(() => {
    setShowChildrenModal(false);
    setEditingParentComponentId(null);
    setChildComponents([]);
    setShowAddChildForm(false);
    setEditingChildId(null);
    setChildFormData({ ...INITIAL_CHILD_FORM_DATA });
    setChildSearchTerm('');
    setShowChildDropdown(false);
    // Keep childrenHavePendingChanges = true so the user is aware they still need to Save
  }, []);

  const handleAddChild = useCallback((): boolean => {
    if (!editingParentComponentId || !activeOrganizationId) return false;
    if (!childFormData.child_item_id) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Select a child item.' }); return false; }
    if (!childFormData.child_role || !isValidRole(childFormData.child_role)) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Child role is required and must be valid.' }); return false; }
    if (!childFormData.qty || childFormData.qty <= 0) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Quantity must be > 0.' }); return false; }

    const normalizedChildRole = normalizeRole(childFormData.child_role) || childFormData.child_role;
    const sel = catalogItems.find(i => i.id === childFormData.child_item_id);
    const uom = canonicalUom(childFormData.uom || sel?.unit_of_measure || sel?.uom, sel?.measure_basis);
    const sortOrder = childComponents.find(c => c.id === editingChildId)?.sort_order ?? childComponents.length;

    const childQtyType = childFormData.qty_type || 'fixed';
    const childPayload: BOMComponentDraft = {
      id: editingChildId || `temp-${crypto.randomUUID()}`,
      parent_component_id: editingParentComponentId,
      component_item_id: childFormData.child_item_id,
      component_role: normalizedChildRole,
      qty_type: childQtyType,
      qty_value: childQtyType === 'per_spacing' ? 1 : (childFormData.qty || 1),
      qty_delta_mm: 0,
      waste_pct: 0,
      depends_on_role: null,
      affects_role: null,
      cut_axis: null,
      cut_delta_mm: 0,
      qty_spacing_mm: childQtyType === 'per_spacing' ? (childFormData.qty_spacing_mm ?? 500) : null,
      qty_min: childQtyType === 'per_spacing' ? childFormData.qty_min : null,
      uom,
      sort_order: sortOrder,
      is_required: childFormData.required !== false,
      per_panel: childFormData.per_panel === true,
      auto_select: false,
      condition_key: childFormData.condition_key || null,
      condition_value: childFormData.condition_value || null,
      catalog_item: sel ? { id: sel.id, sku: sel.sku, name: sel.name || sel.item_name || null } : null,
    };

    if (editingChildId) {
      setComponents(prev => prev.map(c => c.id === editingChildId ? childPayload : c));
      setChildComponents(prev => prev.map(c => c.id === editingChildId ? childPayload : c));
    } else {
      setComponents(prev => [...prev, childPayload]);
      setChildComponents(prev => [...prev, childPayload]);
    }

    setShowAddChildForm(true);
    setEditingChildId(null);
    setChildFormData({ ...INITIAL_CHILD_FORM_DATA });
    setChildSearchTerm('');
    setChildrenHavePendingChanges(true);
    useUIStore.getState().addNotification({ type: 'success', title: 'Success', message: editingChildId ? 'Child updated' : 'Child added' });
    return true;
  }, [editingParentComponentId, activeOrganizationId, childFormData, catalogItems, editingChildId, childComponents]);

  const handleDeleteChild = useCallback((childId: string) => {
    setComponents(prev => prev.filter(c => c.id !== childId));
    setChildComponents(prev => prev.filter(c => c.id !== childId));
    if (!childId.startsWith('temp-')) {
      setComponentsToDelete(prev => [...new Set([...prev, childId])]);
    }
    setChildrenHavePendingChanges(true);
    if (editingChildId === childId) {
      setEditingChildId(null);
      setShowAddChildForm(false);
      setChildFormData({ ...INITIAL_CHILD_FORM_DATA });
      setChildSearchTerm('');
    }
  }, [editingChildId]);

  // ========== SAVE (using batch RPC) ==========

  const handleSave = useCallback(async (): Promise<boolean> => {
    if (!activeOrganizationId) { useUIStore.getState().addNotification({ type: 'error', title: 'Organization Required', message: 'Please select an organization.' }); return false; }
    if (!productTypeId) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Please select a Product Type' }); return false; }
    if (!templateCode.trim()) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Template Code is required' }); return false; }
    if (!templateName.trim()) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Template Name is required' }); return false; }
    if (!templateHardwareColor.trim()) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Hardware Color is required' }); return false; }
    if (!templateManufacturer) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Manufacturer is required' }); return false; }
    if (!templateDriveType) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Drive Type is required (Manual or Motor)' }); return false; }
    if (!templateDriveSide) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Drive Side is required (select Left, Right, or both)' }); return false; }
    {
      const pts = (productTypes || []) as any[];
      const selPt = pts.find((pt: any) => pt.id === productTypeId);
      const isDrap = selPt && (selPt.code === 'drapery' || selPt.name?.toLowerCase().includes('drapery'));
      if (isDrap && !templateOpeningDirection) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Opening Direction is required for Drapery' }); return false; }
      if (isDrap && !templateProductLine?.trim()) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: 'Product Line is required for Drapery' }); return false; }
    }

    // If Children modal is open with pending form data, apply it before saving so it's included
    let effectiveComponents = components;
    const hasPendingChild = showChildrenModal && childFormData.child_item_id && childFormData.child_role && childFormData.qty != null && childFormData.qty > 0;
    if (hasPendingChild && editingParentComponentId) {
      const normalizedChildRole = normalizeRole(childFormData.child_role) || childFormData.child_role;
      const sel = catalogItems.find(i => i.id === childFormData.child_item_id);
      const uom = canonicalUom(childFormData.uom || sel?.unit_of_measure || sel?.uom, sel?.measure_basis);
      const childComponentsForSort = components.filter(c => c.parent_component_id === editingParentComponentId);
      const sortOrder = childComponentsForSort.find(c => c.id === editingChildId)?.sort_order ?? childComponentsForSort.length;
      const childQtyType = (childFormData.qty_type || 'fixed') as BOMQtyType;
      const childPayload: BOMComponentDraft = {
        id: editingChildId || `temp-${crypto.randomUUID()}`,
        parent_component_id: editingParentComponentId,
        component_item_id: childFormData.child_item_id,
        component_role: normalizedChildRole,
        qty_type: childQtyType,
        qty_value: childQtyType === 'per_spacing' ? 1 : (childFormData.qty || 1),
        qty_delta_mm: 0,
        waste_pct: 0,
        depends_on_role: null,
        affects_role: null,
        cut_axis: null,
        cut_delta_mm: 0,
        qty_spacing_mm: childQtyType === 'per_spacing' ? (childFormData.qty_spacing_mm ?? 500) : null,
        qty_min: childQtyType === 'per_spacing' ? childFormData.qty_min ?? null : null,
        uom,
        sort_order: sortOrder,
        is_required: childFormData.required !== false,
        per_panel: childFormData.per_panel === true,
        auto_select: false,
        catalog_item: sel ? { id: sel.id, sku: sel.sku, name: sel.name || sel.item_name || null } : null,
      };
      if (editingChildId) {
        effectiveComponents = components.map(c => (c.id === editingChildId ? childPayload : c));
      } else {
        effectiveComponents = [...components, childPayload];
      }
      setShowChildrenModal(false);
      setEditingParentComponentId(null);
      setChildComponents([]);
      setShowAddChildForm(false);
      setEditingChildId(null);
      setChildFormData({ ...INITIAL_CHILD_FORM_DATA });
      setChildSearchTerm('');
      setShowChildDropdown(false);
    }

    const invalidRoles = effectiveComponents.filter(c => c.component_role && !c.id.startsWith('temp-') ? false : (c.component_role ? !isValidRole(c.component_role) : false));
    if (invalidRoles.length) { useUIStore.getState().addNotification({ type: 'error', title: 'Validation Error', message: `Invalid roles found in ${invalidRoles.length} component(s).` }); return false; }

    setIsSaving(true);
    try {
      const normalizedCode = templateCode.trim();
      const normalizedName = templateName.trim() || normalizedCode;
      const normalizedColor = templateHardwareColor.trim().charAt(0).toUpperCase() + templateHardwareColor.trim().slice(1).toLowerCase();

      const templatePayload: Record<string, any> = {
        product_type_id: productTypeId,
        code: normalizedCode,
        name: normalizedName,
        description: templateDescription.trim() || null,
        hardware_color: normalizedColor,
        panel_count_min: 1,
        panel_count_max: 99,
        drive_type: templateDriveType || null,
        drive_side: templateDriveSide === 'both' ? null : (templateDriveSide || null),
        opening_direction: templateOpeningDirection === 'all' ? null : (templateOpeningDirection || null),
        installation_location: templateInstallationLocation || null,
        manufacturer: templateManufacturer || null,
        product_line: templateProductLine || null,
        system_size: templateSystemSize || null,
        headbox: effectiveComponents.some(c => (normalizeRole(c.component_role || '') === 'headbox' || normalizeRole(c.component_role || '') === 'cassette') && c.is_required !== false),
        is_active: true,
      };
      if (editingTemplateId) templatePayload.id = editingTemplateId;

      const componentsPayload = effectiveComponents.map(c => {
        const role = normalizeRole(c.component_role || '') || c.component_role || null;
        const isFabric = role === 'fabric';
        return {
          id: c.id.startsWith('temp-') ? null : c.id,
          temp_id: c.id.startsWith('temp-') ? c.id : null,
          parent_component_id: (c.parent_component_id && !c.parent_component_id.startsWith('temp-')) ? c.parent_component_id : null,
          parent_temp_id: (c.parent_component_id && c.parent_component_id.startsWith('temp-')) ? c.parent_component_id : null,
          component_item_id: c.component_item_id || null,
          component_role: role,
          qty_type: c.qty_type || 'fixed',
          qty_value: c.qty_value || 1,
          qty_delta_mm: c.qty_delta_mm || 0,
          waste_pct: c.waste_pct || 0,
          depends_on_role: c.depends_on_role || null,
          affects_role: c.affects_role || null,
          cut_axis: c.cut_axis || null,
          cut_delta_mm: c.cut_delta_mm || 0,
          delta_mode: c.delta_mode || 'subtract',
          qty_spacing_mm: c.qty_spacing_mm ?? null,
          qty_min: c.qty_min ?? null,
          uom: isFabric ? 'm' : canonicalUom(c.uom, null),
          sort_order: c.sort_order || 0,
          is_required: c.is_required !== false,
          per_panel: c.per_panel === true,
          condition_key: c.condition_key || null,
          condition_value: c.condition_value || null,
          engineering_delta_source: c.engineering_delta_source || 'fixed',
          engineering_attr_key: c.engineering_attr_key || null,
          engineering_scope: c.engineering_scope || 'total',
          engineering_source_role: c.engineering_source_role || null,
        };
      });

      for (const c of effectiveComponents) {
        if (c.engineering_delta_source === 'derived' && c.engineering_source_role) {
          const sourceExists = effectiveComponents.some(
            (other) => other.id !== c.id && other.component_role === c.engineering_source_role,
          );
          if (!sourceExists) {
            useUIStore.getState().addNotification({
              type: 'warning',
              title: 'Derived delta warning',
              message: `Component "${c.component_role ?? c.id}" references role "${c.engineering_source_role}" for derived delta, but no component with that role exists in this template.`,
            });
          }
        }
      }

      const deleteIds = componentsToDelete.filter(id => !id.startsWith('temp-'));

      const { data, error } = await supabase.rpc('save_bom_template_batch', {
        p_organization_id: activeOrganizationId,
        p_template: templatePayload,
        p_components_upsert: componentsPayload,
        p_component_ids_delete: deleteIds,
      });

      if (error) throw new Error(error.message || 'Error saving BOM template');

      const result = data as { template_id: string; id_map: Record<string, string>; components: any[] };

      if (result?.components) {
        const refreshed: BOMComponentDraft[] = result.components.map((comp: any) => ({
          id: comp.id,
          parent_component_id: comp.parent_component_id || null,
          component_item_id: comp.component_item_id || null,
          component_role: comp.component_role || null,
          qty_type: comp.qty_type || 'fixed',
          qty_value: comp.qty_value || 1,
          qty_delta_mm: comp.qty_delta_mm || 0,
          waste_pct: comp.waste_pct || 0,
          depends_on_role: comp.depends_on_role || null,
          affects_role: comp.affects_role || null,
          cut_axis: comp.cut_axis || null,
          cut_delta_mm: comp.cut_delta_mm || 0,
          delta_mode: comp.delta_mode || 'subtract',
          qty_spacing_mm: comp.qty_spacing_mm ?? null,
          qty_min: comp.qty_min != null ? Number(comp.qty_min) : null,
          uom: comp.uom || 'ea',
          sort_order: comp.sort_order || 0,
          is_required: comp.is_required !== false,
          per_panel: comp.per_panel === true,
          auto_select: false,
          condition_key: comp.condition_key || null,
          condition_value: comp.condition_value || null,
        }));
        setComponents(refreshed);
        initialComponentsRef.current = refreshed.map(c => ({ ...c }));
      }
      setComponentsToDelete([]);
      setChildrenHavePendingChanges(false);
      clearDraft();
      useUIStore.getState().addNotification({ type: 'success', title: 'Success', message: 'BOM Template saved successfully.' });
      return true;
    } catch (err: any) {
      console.error('Error saving BOM:', err);
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message || 'Error saving BOM template' });
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, productTypeId, templateCode, templateName, templateDescription, templateHardwareColor, templatePanelCount, templateDriveType, templateDriveSide, templateOpeningDirection, templateInstallationLocation, templateManufacturer, templateProductLine, templateSystemSize, editingTemplateId, components, componentsToDelete, clearDraft, showChildrenModal, childFormData, editingParentComponentId, editingChildId, catalogItems]);

  // ========== RETURN ==========

  return {
    // Template fields
    productTypeId, setProductTypeId,
    templateCode, setTemplateCode: (v: string) => setTemplateCode(v.toUpperCase().replace(/\s+/g, '_')),
    templateName, setTemplateName,
    templateDescription, setTemplateDescription,
    templateHardwareColor, setTemplateHardwareColor,
    templatePanelCount, setTemplatePanelCount,
    templateDriveType, setTemplateDriveType,
    templateDriveSide, setTemplateDriveSide,
    templateOpeningDirection, setTemplateOpeningDirection,
    templateInstallationLocation, setTemplateInstallationLocation,
    templateManufacturer, setTemplateManufacturer,
    templateProductLine, setTemplateProductLine,
    templateSystemSize, setTemplateSystemSize,
    templateHeadbox,
    productTypes,
    catalogItems,
    categories,
    leafCategories,

    // Components
    components, displayComponents, componentsByCategory, childrenByParent,

    // Component form
    showAddComponentForm, setShowAddComponentForm,
    editingComponentId, setEditingComponentId,
    formData, setFormData,
    componentSearchTerm, setComponentSearchTerm,
    selectedCategoryFilter, setSelectedCategoryFilter,
    showComponentDropdown, setShowComponentDropdown,
    highlightedIndex, setHighlightedIndex,
    flatFilteredItems,
    handleSelectComponent,
    handleAddComponent,
    handleUpdateComponent,
    handleDeleteComponent,
    handleEditComponent,
    resetForm,

    // Engineering popup
    showEngineeringPopup,
    editingEngineeringComponentId,
    handleOpenEngineeringPopup,
    handleCloseEngineeringPopup,
    handlePatchComponent,

    // Children
    showChildrenModal,
    childrenHavePendingChanges,
    editingParentComponentId,
    editingParentComponentRole: editingParentComponentId
      ? (components.find((c) => c.id === editingParentComponentId)?.component_role ?? null)
      : null,
    childComponents, setChildComponents,
    showAddChildForm, setShowAddChildForm,
    editingChildId, setEditingChildId,
    childFormData, setChildFormData,
    childSearchTerm, setChildSearchTerm,
    showChildDropdown, setShowChildDropdown,
    handleOpenChildrenModal,
    handleCloseChildrenModal,
    handleAddChild,
    handleDeleteChild,

    // Save
    isSaving,
    isDirty,
    handleSave,
    clearDraft,
  };
}
