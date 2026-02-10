import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Plus, Edit, Trash2, Search, Wrench, Info, Settings, Package, Copy, GripVertical } from 'lucide-react';
import Label from '../../components/ui/Label';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue, SelectGroup, SelectLabel } from '../../components/ui/SelectShadcn';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useCatalogItems, useItemCategories, useLeafItemCategories } from '../../hooks/useCatalog';
import { useBOMCRUD, useBOMComponents } from '../../hooks/useBOM';
import { useBOMTemplates, useBOMTemplateCRUD } from '../../hooks/useBOMTemplates';
import { Folder, X } from 'lucide-react';
import { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider } from '../../components/ui/Tooltip';
import { CANONICAL_COMPONENT_ROLES, VALID_CHILD_ROLES, normalizeRole, isValidRole, getRoleLabel, getSubRoleLabel } from '../../lib/bom/roles';
import { getValidUomOptions, normalizeMeasureBasis, normalizeUom } from '../../lib/uom';
import { calculateFabricLinearM, getFabricCalculationPreview } from '../../lib/bom/fabric-calculations';
import { useOnVisibilityChange } from '../../lib/app-persistence';

// Helper functions for conditional UI rendering based on role
const shouldShowHardwareColor = (role: string | null | undefined): boolean => {
  if (!role) return false;
  const normalized = normalizeRole(role);
  if (!normalized) return false;
  // Color NO aplica a drives/motors - no se pintan
  if (['drive_manual', 'drive_motorized', 'operating_system'].includes(normalized)) return false;
  return ['bracket', 'cassette', 'bottom_bar', 'end_cap', 'hardware'].includes(normalized);
};

const shouldShowSKUResolutionRule = (role: string | null | undefined): boolean => {
  if (!role) return false;
  const normalized = normalizeRole(role);
  if (!normalized) return false;
  return ['tube', 'bracket', 'cassette', 'drive_manual', 'drive_motorized', 'operating_system'].includes(normalized);
};

// Get valid SKU resolution rules for a role
const getValidSKUResolutionRules = (role: string | null | undefined): SKUResolutionRule[] => {
  if (!role) return [];
  const normalized = normalizeRole(role);
  if (!normalized) return [];
  
  // Drive roles: solo compatibilidad, sin color
  if (['drive_manual', 'drive_motorized', 'operating_system'].includes(normalized)) {
    return ['ROLE_AND_COLOR']; // This will be interpreted as "por sistema/compatibilidad" for drives
  }
  
  // Bracket, cassette, bottom_bar: reglas con color
  if (['bracket', 'cassette', 'bottom_bar', 'end_cap', 'hardware'].includes(normalized)) {
    return ['SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR'];
  }
  
  // Tube: compatibilidad o exact SKU
  if (normalized === 'tube') {
    return ['EXACT_SKU', 'ROLE_AND_COLOR'];
  }
  
  // Default: todas las reglas
  return ['EXACT_SKU', 'SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR'];
};

// Get label for SKU resolution rule (user-friendly)
const getSKUResolutionRuleLabel = (rule: SKUResolutionRule, role: string | null | undefined): string => {
  const normalized = normalizeRole(role);
  
  // Para drives, ROLE_AND_COLOR significa "por sistema/compatibilidad"
  if (['drive_manual', 'drive_motorized', 'operating_system'].includes(normalized || '')) {
    if (rule === 'ROLE_AND_COLOR') {
      return 'Por sistema / compatibilidad';
    }
  }
  
  const labels: Record<string, string> = {
    'EXACT_SKU': 'SKU exacto',
    'SKU_SUFFIX_COLOR': 'Por sufijo SKU + color',
    'ROLE_AND_COLOR': 'Por tipo de componente + color',
  };
  
  return labels[rule] || rule;
};

// Get helper text for SKU resolution based on role
const getSKUResolutionHelperText = (role: string | null | undefined): string => {
  if (!role) return '';
  const normalized = normalizeRole(role);
  if (!normalized) return '';
  
  if (['drive_manual', 'drive_motorized', 'operating_system'].includes(normalized)) {
    if (normalized === 'drive_motorized') {
      return 'El motor se selecciona automáticamente según el sistema configurado.';
    }
    if (normalized === 'drive_manual') {
      return 'El sistema manual se selecciona automáticamente según la configuración.';
    }
    if (normalized === 'operating_system') {
      return 'El sistema operativo se selecciona automáticamente según la compatibilidad.';
    }
  }
  
  return '';
};

const shouldShowBlockCondition = (role: string | null | undefined): boolean => {
  if (!role) return false;
  const normalized = normalizeRole(role);
  if (!normalized) return false;
  return ['bracket', 'bottom_rail', 'side_channel'].includes(normalized);
};

const isQtyAlwaysFixed = (role: string | null | undefined): boolean => {
  if (!role) return false;
  const normalized = normalizeRole(role);
  if (!normalized) return false;
  // Roles that always use fixed quantity
  return ['drive_manual', 'drive_motorized', 'remote_control', 'battery', 'tool', 'accessory'].includes(normalized);
};


// Get UOM for tube component based on measure_basis
const getUomForTubeFromMeasureBasis = (measureBasis: string | null | undefined): string => {
  if (!measureBasis) return 'm'; // Default to meters
  const normalized = normalizeMeasureBasis(measureBasis);
  
  // For linear_m, default to 'm' (meters)
  // Could be extended to support 'ft' based on user preference/region
  if (normalized === 'linear_m') {
    return 'm'; // Default to meters for linear measure basis
  }
  
  // For other measure basis, return first valid UOM option
  const validUoms = getValidUomOptions(normalized);
  return validUoms.length > 0 ? (validUoms[0] || 'm') : 'm';
};

// Check if UOM should be readonly for a component
// For Auto-Select: UOM is ALWAYS readonly (determined from CatalogItems.uom at BOM generation time)
// For Fixed: UOM is readonly (comes from CatalogItems.uom of selected component)
const isUomReadonlyForComponent = (role: string | null | undefined, selectionMode: 'fixed' | 'user_select' | 'none_allowed' | undefined): boolean => {
  // Always readonly - UOM comes from CatalogItems.uom at BOM generation time
  return true;
};

interface BOMTemplate {
  id: string;
  product_type_id: string;
  name?: string;
  template_name?: string;
  description?: string;
  created_at: string;
  updated_at: string;
  ProductType?: {
    id: string;
    name: string;
    code: string;
  };
}

// ✅ FIX: Shared constants for bom_qty_type enum (must match DB enum exactly)
export const BOM_QTY_TYPES = ['fixed', 'per_width', 'per_height', 'per_area'] as const;
export type BOMQtyType = typeof BOM_QTY_TYPES[number];

type SKUResolutionRule = 'EXACT_SKU' | 'SKU_SUFFIX_COLOR' | 'ROLE_AND_COLOR' | 'CATEGORY_FIRST_MATCH' | string;
type HardwareColor = 'none' | 'white' | 'black' | 'silver' | 'bronze' | 'grey' | string;

interface BOMComponent {
  id: string;
  bom_template_id: string;
  component_role?: string;
  component_sub_role?: string; // Optional sub-role for granularity (e.g., hardware: fastener, end_cap, adapter)
  component_item_id?: string;
  uom: string;
  block_type?: string;
  block_condition?: any;
  applies_color?: boolean;
  sku_resolution_rule?: SKUResolutionRule;
  hardware_color?: HardwareColor;
  select_rule?: Record<string, any> | null;
  qty_type?: BOMQtyType | null;
  qty_value?: number | null;
  qty_formula_code?: string | null; // Formula code (e.g., 'CHAIN_HEIGHT_FACTOR')
  qty_formula_params?: Record<string, any> | null; // Formula parameters (JSON)
  auto_select?: boolean; // DB field (boolean)
  selection_mode?: 'fixed' | 'user_select' | 'none_allowed';
  sequence_order: number;
  depends_on_role?: string;
  cut_axis?: string;
  cut_delta_mm?: number;
  cut_delta_scope?: string;
  CatalogItems?: {
    id: string;
    sku: string;
    item_name: string;
  };
}

interface ComponentGroupedByCategory {
  category_id: string | null;
  category_name: string;
  category_code: string | null;
  components: any[];
}

export default function BOMTemplates() {
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();
  const [templates, setTemplates] = useState<BOMTemplate[]>([]);
  const [components, setComponents] = useState<Map<string, BOMComponent[]>>(new Map());
  const [productTypes, setProductTypes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [draggedTemplateId, setDraggedTemplateId] = useState<string | null>(null);
  const [dragOverTemplateId, setDragOverTemplateId] = useState<string | null>(null);
  
  // ✅ Persist edit state across tab changes
  const PERSISTENCE_KEY = 'bomTemplates:editState';
  
  // Restore persisted state on mount
  const [showTemplateModal, setShowTemplateModal] = useState(() => {
    if (typeof window !== 'undefined') {
      try {
        const saved = localStorage.getItem(PERSISTENCE_KEY);
        if (saved) {
          const parsed = JSON.parse(saved);
          return parsed.showTemplateModal === true;
        }
      } catch (e) {
        // Ignore parse errors
      }
    }
    return false;
  });
  
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(() => {
    if (typeof window !== 'undefined') {
      try {
        const saved = localStorage.getItem(PERSISTENCE_KEY);
        if (saved) {
          const parsed = JSON.parse(saved);
          return parsed.editingTemplateId || null;
        }
      } catch (e) {
        // Ignore parse errors
      }
    }
    return null;
  });
  
  const [productTypeId, setProductTypeId] = useState<string>('');

  // Register Catalog submodules when BOMTemplates component mounts
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
      ]);
    }
  }, [registerSubmodules]);

  // ✅ Restore persisted edit state on mount (verify template exists)
  const hasRestoredState = useRef(false);
  useEffect(() => {
    if (hasRestoredState.current || !activeOrganizationId) return;
    
    const persistedId = editingTemplateId;
    const persistedModal = showTemplateModal;
    
    if (persistedId && persistedModal) {
      hasRestoredState.current = true;
      // Verify template still exists before restoring
      supabase
        .from('BOMTemplates')
        .select('id')
        .eq('id', persistedId)
        .eq('organization_id', activeOrganizationId)
        .eq('is_active', true)
        .eq('archived', false)
        .single()
        .then(({ data, error }: { data: any; error: any }) => {
          if (error || !data) {
            // Template no longer exists, clear persisted state
            if (typeof window !== 'undefined') {
              try {
                localStorage.removeItem(PERSISTENCE_KEY);
              } catch (e) {
                // Ignore storage errors
              }
            }
            setShowTemplateModal(false);
            setEditingTemplateId(null);
          }
          // If template exists, modal will stay open (already set in state)
        });
    } else {
      hasRestoredState.current = true;
    }
  }, [activeOrganizationId, editingTemplateId, showTemplateModal]);

  // Load product types
  useEffect(() => {
    const loadProductTypes = async () => {
      if (!activeOrganizationId) return;
      try {
        // ✅ FIX: Soportar registros globales (organization_id NULL)
        const { data, error } = await supabase
          .from('ProductTypes')
          .select('id, name, code')
          .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
          .order('name');
        
        if (error) throw error;
        setProductTypes(data || []);
      } catch (err) {
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = err instanceof Error 
          ? { message: err.message, name: err.name }
          : typeof err === 'object' && err !== null
          ? { message: (err as any).message || String(err), code: (err as any).code }
          : String(err);
        console.error('Error loading product types:', errorDetails);
      }
    };
    loadProductTypes();
  }, [activeOrganizationId]);

  // Load BOM templates
  useEffect(() => {
    // ✅ FIX: Early return guard to prevent unnecessary fetches
    if (!activeOrganizationId) {
      setLoading(false);
      return;
    }

    // ✅ FIX: Add request counter and logging (DEV-only)
    if (import.meta.env.DEV) {
      console.log('[BOMTemplates] Fetching templates', {
        activeOrganizationId,
        requestId: `${activeOrganizationId}-${Date.now()}`,
        stack: new Error().stack?.split('\n').slice(1, 4).join('\n'),
      });
    }

    const loadTemplates = async () => {
      try {
        setLoading(true);
        setError(null);

        // ✅ FIX: Intentar ordenar por sort_order, pero si la columna no existe, usar created_at
        let query = supabase
          .from('BOMTemplates')
          .select(`
            *,
            ProductType:product_type_id (
              id,
              name,
              code
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true)
          .eq('archived', false)
          .order('sort_order', { ascending: true })
          .order('created_at', { ascending: false });
        
        let { data, error } = await query;

        // ✅ FIX: Si el error es porque sort_order no existe, reintentar sin ese ordenamiento
        if (error && (error.code === '42703' || error.message?.includes('sort_order') || error.message?.includes('column') && error.message?.includes('does not exist'))) {
          if (import.meta.env.DEV) {
            console.warn('[BOMTemplates] sort_order column not found, retrying with created_at only');
          }
          // Reintentar sin sort_order
          query = supabase
            .from('BOMTemplates')
            .select(`
              *,
              ProductType:product_type_id (
                id,
                name,
                code
              )
            `)
            .eq('organization_id', activeOrganizationId)
            .eq('is_active', true)
            .eq('archived', false)
            .order('created_at', { ascending: false });
          
          const retryResult = await query;
          data = retryResult.data;
          error = retryResult.error;
        }

        // ✅ FIX: Don't retry on 404/400 errors
        if (error) {
          if (error.code === 'PGRST116' || error.code === '42P01' || 
              error.message?.includes('does not exist')) {
            if (import.meta.env.DEV) {
              console.warn('[BOMTemplates] Client error (not retrying):', error.code, error.message);
            }
            setError(null); // Don't show error for expected 404s
            setTemplates([]);
            setLoading(false);
            return;
          }
          throw error;
        }

        setTemplates(data || []);

        // Load components for each template
        if (data && data.length > 0) {
          const templateIds = data.map((t: any) => t.id);
          // ✅ FIX: No usar join relacional (PGRST200) - traer plano y resolver en memoria
          const { data: componentsData, error: componentsError } = await supabase
            .from('BOMComponents')
            .select('*') // ✅ Solo campos de BOMComponents, sin join
            .in('bom_template_id', templateIds)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .eq('archived', false)
            .order('parent_component_id', { ascending: true })
            .order('sort_order', { ascending: true })
            .order('created_at', { ascending: true });

          // ✅ FIX: Handle 404/400 errors gracefully
          if (componentsError) {
            if (componentsError.code === 'PGRST116' || componentsError.code === '42P01' || 
                componentsError.message?.includes('does not exist')) {
              if (import.meta.env.DEV) {
                console.warn('[BOMTemplates] Components fetch error (not retrying):', componentsError.code, componentsError.message);
              }
              setComponents(new Map()); // Set empty map on expected errors
            } else {
              // ✅ FIX: Formatear error para evitar "[circular]"
              const errorDetails = { 
                message: componentsError.message, 
                code: componentsError.code,
                details: componentsError.details 
              };
              console.error('[BOMTemplates] Unexpected error fetching components:', errorDetails);
            }
          } else if (componentsData) {
            const componentsMap = new Map<string, BOMComponent[]>();
            componentsData.forEach((comp: BOMComponent) => {
              const templateId = comp.bom_template_id;
              if (!componentsMap.has(templateId)) {
                componentsMap.set(templateId, []);
              }
              componentsMap.get(templateId)!.push(comp);
            });
            setComponents(componentsMap);
          }
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error loading BOM templates');
      } finally {
        setLoading(false);
      }
    };

    loadTemplates();
  }, [activeOrganizationId]);

  // Filter templates
  const filteredTemplates = useMemo(() => {
    if (!searchTerm) return templates;
    const searchLower = searchTerm.toLowerCase();
    return templates.filter((t: any) => 
      t.template_name?.toLowerCase().includes(searchLower) ||
      t.description?.toLowerCase().includes(searchLower) ||
      t.ProductType?.name.toLowerCase().includes(searchLower)
    );
  }, [templates, searchTerm]);

  // ✅ Persist state to localStorage whenever it changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        localStorage.setItem(PERSISTENCE_KEY, JSON.stringify({
          editingTemplateId,
          showTemplateModal,
        }));
      } catch (e) {
        // Ignore storage errors (quota exceeded, etc.)
      }
    }
  }, [editingTemplateId, showTemplateModal]);

  const handleNewTemplate = () => {
    setEditingTemplateId(null);
    setShowTemplateModal(true);
  };

  const handleEditTemplate = (templateId: string) => {
    setEditingTemplateId(templateId);
    setShowTemplateModal(true);
  };

  const buildUniqueName = (baseName: string) => {
    const existingNames = new Set(
      templates.map((t) => String((t as any).name || (t as any).template_name || '').trim().toLowerCase())
    );
    let candidate = baseName.trim();
    if (!candidate) candidate = 'BOM Template Copy';
    if (!existingNames.has(candidate.toLowerCase())) return candidate;
    let index = 2;
    while (existingNames.has(`${candidate} ${index}`.toLowerCase())) {
      index += 1;
    }
    return `${candidate} ${index}`;
  };

  const buildUniqueCode = (baseCode: string) => {
    const existingCodes = new Set(
      templates.map((t) => String((t as any).code || (t as any).template_code || '').trim().toUpperCase())
    );
    const normalizedBase = (baseCode || 'BOM').trim().toUpperCase();
    let candidate = `${normalizedBase}_COPY`;
    if (!existingCodes.has(candidate)) return candidate;
    let index = 2;
    while (existingCodes.has(`${candidate}_${index}`)) {
      index += 1;
    }
    return `${candidate}_${index}`;
  };

  const buildNextCopyCode = (baseCode: string, attempt: number) => {
    const normalizedBase = (baseCode || 'BOM').trim().toUpperCase();
    if (attempt <= 1) return `${normalizedBase}_COPY`;
    return `${normalizedBase}_COPY_${attempt}`;
  };

  const handleDuplicateTemplate = async (template: BOMTemplate) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Organization Required',
        message: 'Please select an organization before duplicating.',
      });
      return;
    }

    try {
      setLoading(true);

      const baseName = String(template.name || (template as any).template_name || (template as any).code || 'BOM Template');
      const baseCode = String((template as any).code || (template as any).template_code || 'BOM_TEMPLATE');
      const duplicatedName = buildUniqueName(`${baseName} Copy`);
      let newTemplate: any = null;
      let duplicatedCode = buildNextCopyCode(baseCode, 1);
      let attempt = 1;
      const maxAttempts = 20;

      while (!newTemplate && attempt <= maxAttempts) {
        const { data: created, error: templateError } = await supabase
          .from('BOMTemplates')
          .insert({
            organization_id: activeOrganizationId,
            product_type_id: (template as any).product_type_id,
            code: duplicatedCode,
            name: duplicatedName,
            description: template.description || null,
            hardware_color: (template as any).hardware_color || null,
            panel_count_min: (template as any).panel_count_min ?? 1,
            panel_count_max: (template as any).panel_count_max ?? 1,
            metadata: (template as any).metadata || {},
            is_active: true,
            archived: false,
          })
          .select('id, product_type_id, code, name, description, hardware_color, panel_count_min, panel_count_max')
          .single();

        if (!templateError && created) {
          newTemplate = created;
          break;
        }

        const errorMessage = templateError?.message || '';
        const isSchemaCacheClone =
          errorMessage.toLowerCase().includes('clone_bomcomponents') ||
          errorMessage.toLowerCase().includes('schema cache');

        if (isSchemaCacheClone) {
          const { data: recovered, error: recoverError } = await supabase
            .from('BOMTemplates')
            .select('id, product_type_id, code, name, description, hardware_color')
            .eq('organization_id', activeOrganizationId)
            .eq('code', duplicatedCode)
            .eq('is_active', true)
            .eq('archived', false)
            .single();

          if (!recoverError && recovered) {
            newTemplate = recovered;
            break;
          }
        }
        const isDuplicate =
          templateError?.code === '23505' ||
          errorMessage.toLowerCase().includes('duplicate key') ||
          errorMessage.includes('BOMTemplates_code_key');

        if (!isDuplicate) {
          throw new Error(templateError?.message || 'Failed to create duplicated template');
        }

        attempt += 1;
        duplicatedCode = buildNextCopyCode(baseCode, attempt);
      }

      if (!newTemplate) {
        throw new Error('Failed to create duplicated template (code conflict)');
      }

      const { data: componentsData, error: componentsError } = await supabase
        .from('BOMComponents')
        .select('id, organization_id, bom_template_id, parent_component_id, component_item_id, component_role, auto_select, uom, is_required, sort_order, deleted, archived, qty_type, qty_value, qty_delta_mm, waste_pct, cut_axis, cut_delta_mm, depends_on_role, component_scope, slot_id, sku_resolution_rule, component_mode, type_per_unit, qty_spacing_mm, qty_min')
        .eq('organization_id', activeOrganizationId)
        .eq('bom_template_id', template.id)
        .eq('deleted', false)
        .eq('archived', false)
        .order('parent_component_id', { ascending: true })
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: true });

      if (componentsError) {
        throw new Error(componentsError.message || 'Failed to load components to duplicate');
      }

      const parents = (componentsData || []).filter((c: any) => !c.parent_component_id);
      const children = (componentsData || []).filter((c: any) => !!c.parent_component_id);
      const idMap = new Map<string, string>();
      const duplicatedComponents: any[] = [];

      const buildComponentPayload = (comp: any, parentId: string | null) => {
        // Solo usar columnas que existen según el DUMP SQL
        return {
          organization_id: activeOrganizationId,
          bom_template_id: newTemplate.id,
          parent_component_id: parentId,
          component_item_id: comp.component_item_id || null,
          component_role: comp.component_role || null,
          auto_select: comp.auto_select ?? true,
          uom: comp.uom || 'ea',
          is_required: comp.is_required !== false,
          sort_order: comp.sort_order || 0,
          deleted: false,
          archived: false,
          qty_type: comp.qty_type || 'fixed',
          qty_value: comp.qty_value || 1,
          qty_delta_mm: comp.qty_delta_mm || 0,
          waste_pct: comp.waste_pct || 0,
          cut_axis: comp.cut_axis || null,
          cut_delta_mm: comp.cut_delta_mm || 0,
          depends_on_role: comp.depends_on_role || null,
          component_scope: comp.component_scope || 'bom',
          slot_id: comp.slot_id || null,
          sku_resolution_rule: comp.sku_resolution_rule || 'ROLE_AND_COLOR',
          component_mode: comp.component_mode || 'auto',
          type_per_unit: comp.type_per_unit || null,
          qty_spacing_mm: comp.qty_spacing_mm || null,
          qty_min: comp.qty_min || null,
        };
      };

      for (const parent of parents) {
        const { data: newParent, error: parentError } = await supabase
          .from('BOMComponents')
          .insert(buildComponentPayload(parent, null))
          .select('id')
          .single();
        if (parentError || !newParent) {
          throw new Error(parentError?.message || 'Failed to duplicate parent component');
        }
        idMap.set(parent.id, newParent.id);
        duplicatedComponents.push({
          ...parent,
          id: newParent.id,
          bom_template_id: newTemplate.id,
          parent_component_id: null,
          deleted: false,
          archived: false,
        });
      }

      for (const child of children) {
        const mappedParentId = idMap.get(child.parent_component_id) || null;
        const { data: newChild, error: childError } = await supabase
          .from('BOMComponents')
          .insert(buildComponentPayload(child, mappedParentId))
          .select('id')
          .single();
        if (childError || !newChild) {
          throw new Error(childError?.message || 'Failed to duplicate child component');
        }
        duplicatedComponents.push({
          ...child,
          id: newChild.id,
          bom_template_id: newTemplate.id,
          parent_component_id: mappedParentId,
          deleted: false,
          archived: false,
        });
      }

      const mappedDraftComponents = duplicatedComponents.map((comp: any) => ({
        id: comp.id,
        parent_component_id: comp.parent_component_id || null,
        component_item_id: comp.component_item_id || null,
        component_role: comp.component_role || null,
        qty_type: comp.qty_type || 'fixed',
        qty_value: comp.qty_value || 1,
        qty_delta_mm: comp.qty_delta_mm || 0,
        waste_pct: comp.waste_pct || 0,
        depends_on_role: comp.depends_on_role || null,
        cut_axis: comp.cut_axis || null,
        cut_delta_mm: comp.cut_delta_mm || 0,
        uom: comp.uom || 'ea',
        sort_order: comp.sort_order || 0,
        sequence_order: comp.sort_order || 0,
        is_required: comp.is_required !== false,
        auto_select: comp.auto_select ?? false,
      }));

      setTemplates((prev) => [newTemplate, ...prev]);
      setComponents((prev) => {
        const next = new Map(prev);
        next.set(newTemplate.id, duplicatedComponents);
        return next;
      });

      try {
        const draftKey = `bomTemplateDraft:${newTemplate.id}`;
        sessionStorage.setItem(
          draftKey,
          JSON.stringify({
            productTypeId: newTemplate.product_type_id,
            templateCode: newTemplate.code || duplicatedCode,
            templateName: newTemplate.name || duplicatedName,
            templateDescription: newTemplate.description || '',
            templateHardwareColor: newTemplate.hardware_color || '',
            templatePanelCount: (newTemplate as any).panel_count_min ?? (newTemplate as any).panel_count_max ?? 1,
            components: mappedDraftComponents,
            showAddComponentForm: false,
          })
        );
      } catch (err) {
        if (import.meta.env.DEV) {
          console.warn('[BOMTemplates] Failed to write duplication draft:', err);
        }
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Duplicated',
        message: 'BOM template duplicated successfully.',
      });

      setEditingTemplateId(newTemplate.id);
      setShowTemplateModal(true);
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('[BOMTemplates] Duplicate failed:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Duplicate Failed',
        message:
          err instanceof Error
            ? err.message
            : (err as any)?.message || (err as any)?.details || 'Failed to duplicate BOM template',
      });
    } finally {
      setLoading(false);
    }
  };
  
  // ✅ Clear persisted state when modal closes
  const handleCloseModal = () => {
    setShowTemplateModal(false);
    if (typeof window !== 'undefined') {
      try {
        localStorage.removeItem(PERSISTENCE_KEY);
      } catch (e) {
        // Ignore storage errors
      }
    }
  };

  const handleDragStart = (templateId: string) => {
    setDraggedTemplateId(templateId);
  };

  const handleDragOver = (e: React.DragEvent, templateId: string) => {
    e.preventDefault();
    if (draggedTemplateId && draggedTemplateId !== templateId) {
      setDragOverTemplateId(templateId);
    }
  };

  const handleDragLeave = () => {
    setDragOverTemplateId(null);
  };

  const handleDrop = async (e: React.DragEvent, targetTemplateId: string) => {
    e.preventDefault();
    setDragOverTemplateId(null);

    if (!draggedTemplateId || draggedTemplateId === targetTemplateId || !activeOrganizationId) {
      setDraggedTemplateId(null);
      return;
    }

    try {
      const draggedIndex = filteredTemplates.findIndex(t => t.id === draggedTemplateId);
      const targetIndex = filteredTemplates.findIndex(t => t.id === targetTemplateId);

      if (draggedIndex === -1 || targetIndex === -1) {
        setDraggedTemplateId(null);
        return;
      }

      // Reordenar templates localmente
      const reorderedTemplates = [...filteredTemplates];
      const spliced = reorderedTemplates.splice(draggedIndex, 1);
      const draggedTemplate = spliced[0];
      if (!draggedTemplate) {
        setDraggedTemplateId(null);
        return;
      }
      reorderedTemplates.splice(targetIndex, 0, draggedTemplate);

      // Preparar updates para batch update - asegurar que solo contenga datos primitivos
      const updates = reorderedTemplates.map((template, index) => ({
        id: String(template.id), // Asegurar que sea string
        sort_order: Number(index), // Asegurar que sea número
      }));

      // ✅ OPTIMIZACIÓN: Usar función RPC para batch update (mucho más rápido)
      const { data, error } = await supabase.rpc('update_bom_template_sort_orders', {
        p_organization_id: activeOrganizationId,
        p_updates: updates,
      });

      if (error) {
        // ✅ FIX: Extraer información del error sin referencias circulares
        const errorMessage = error.message || 'Unknown error';
        const errorCode = error.code || 'UNKNOWN';
        const errorDetails = error.details || '';
        const errorHint = error.hint || '';
        
        if (import.meta.env.DEV) {
          console.error('[BOMTemplates] RPC error:', {
            message: errorMessage,
            code: errorCode,
            details: errorDetails,
            hint: errorHint,
          });
        }
        
        // Si la función RPC no existe, usar método alternativo (updates individuales)
        if (errorCode === '42883' || errorMessage.includes('does not exist') || errorMessage.includes('function')) {
          if (import.meta.env.DEV) {
            console.warn('[BOMTemplates] RPC function not found, falling back to individual updates');
          }
          
          // Fallback: actualizar individualmente
          const updatePromises = updates.map(update =>
            supabase
              .from('BOMTemplates')
              .update({ sort_order: update.sort_order })
              .eq('id', update.id)
              .eq('organization_id', activeOrganizationId)
          );
          
          const results = await Promise.all(updatePromises);
          const hasErrors = results.some(r => r.error);
          
          if (hasErrors) {
            const firstError = results.find(r => r.error)?.error;
            throw new Error(firstError?.message || 'Failed to update some templates');
          }
        } else {
          throw new Error(errorMessage);
        }
      }

      // Verificar resultado
      if (data && typeof data === 'object' && 'updated_count' in data) {
        const updatedCount = Number(data.updated_count) || 0;
        if (updatedCount !== updates.length) {
          console.warn('[BOMTemplates] Some templates were not updated:', {
            expected: updates.length,
            updated: updatedCount,
          });
        }
      }

      // Actualizar estado local
      setTemplates(reorderedTemplates);

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Reordered',
        message: 'Template order updated successfully.',
      });
    } catch (err) {
      // ✅ FIX: Extraer mensaje de error sin referencias circulares
      const errorMessage = err instanceof Error 
        ? err.message 
        : typeof err === 'string' 
          ? err 
          : 'Failed to reorder templates';
      
      if (import.meta.env.DEV) {
        console.error('[BOMTemplates] Error reordering templates:', errorMessage);
      }
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Reorder Failed',
        message: errorMessage,
      });
    } finally {
      setDraggedTemplateId(null);
    }
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
      const { error } = await supabase
        .from('BOMTemplates')
        .update({ is_active: false })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'BOM Template deleted successfully',
      });
      // Reload templates
      window.location.reload();
    } catch (err) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err instanceof Error ? err.message : 'Failed to delete BOM template',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">BOM Templates</h2>
          <p className="text-sm text-gray-500">Configure Bill of Materials for product types</p>
        </div>
        <button
          onClick={handleNewTemplate}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          New BOM Template
        </button>
      </div>

      {/* Search */}
      <div className="mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search BOM templates..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {/* Templates List */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
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
          {filteredTemplates.map((template) => {
            const templateComponents = components.get(template.id) || [];
            const isDragging = draggedTemplateId === template.id;
            const isDragOver = dragOverTemplateId === template.id;
            return (
              <div
                key={template.id}
                draggable
                onDragStart={() => handleDragStart(template.id)}
                onDragOver={(e) => handleDragOver(e, template.id)}
                onDragLeave={handleDragLeave}
                onDrop={(e) => handleDrop(e, template.id)}
                className={`bg-white border rounded-lg p-6 transition-all ${
                  isDragging ? 'opacity-50 cursor-grabbing' : 'cursor-grab'
                } ${
                  isDragOver ? 'border-primary border-2 shadow-md' : 'border-gray-200'
                }`}
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-start gap-2 flex-1">
                    <div
                      className="cursor-grab active:cursor-grabbing text-gray-400 hover:text-gray-600 mt-1"
                      title="Drag to reorder"
                    >
                      <GripVertical className="w-5 h-5" />
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-lg font-semibold text-gray-900">
                          {(template.name || template.template_name) || template.ProductType?.name || 'BOM Template'}
                        </h3>
                      </div>
                      <p className="text-sm text-gray-600 mb-2">
                        Product Type: {template.ProductType?.name || 'N/A'}
                      </p>
                      {template.description && (
                        <p className="text-sm text-gray-500">{template.description}</p>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => handleEditTemplate(template.id)}
                      className="p-2 hover:bg-gray-100 rounded text-gray-600"
                      title="Edit Template and Components"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDuplicateTemplate(template)}
                      className="p-2 hover:bg-gray-100 rounded text-gray-600"
                      title="Duplicate Template"
                    >
                      <Copy className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDeleteTemplate(template.id)}
                      className="p-2 hover:bg-red-100 rounded text-red-600"
                      title="Delete Template"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                {/* Components Preview */}
                {templateComponents.length > 0 && (
                  <div className="mt-4 pt-4 border-t border-gray-200">
                    <p className="text-xs font-medium text-gray-700 mb-2">Components ({templateComponents.length}):</p>
                    <div className="flex flex-wrap gap-2">
                      {templateComponents.slice(0, 5).map((comp) => (
                        <span key={comp.id} className="text-xs bg-gray-100 px-2 py-1 rounded">
                          {comp.CatalogItems?.item_name || comp.CatalogItems?.sku || comp.component_role || 'Unknown'}
                          {(comp.qty_value || 0) > 1 && ` (x${comp.qty_value})`}
                        </span>
                      ))}
                      {templateComponents.length > 5 && (
                        <span className="text-xs text-gray-500">+{templateComponents.length - 5} more</span>
                      )}
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Template Modal - Full BOM Configuration */}
      {showTemplateModal && (
        <BOMModal
          isOpen={showTemplateModal}
          onClose={() => {
            handleCloseModal();
            setEditingTemplateId(null);
          }}
          onSave={() => {
            // ✅ Clear persisted state on successful save
            if (typeof window !== 'undefined') {
              try {
                localStorage.removeItem(PERSISTENCE_KEY);
              } catch (e) {
                // Ignore storage errors
              }
            }
            setShowTemplateModal(false);
            setEditingTemplateId(null);
            // Reload templates
            window.location.reload();
          }}
          editingTemplateId={editingTemplateId}
          setEditingTemplateId={setEditingTemplateId}
        />
      )}



      {/* Confirm Dialog */}
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

// BOM Modal Component - Full configuration modal with components management
function BOMModal({ isOpen, onClose, onSave, editingTemplateId, setEditingTemplateId }: {
  isOpen: boolean;
  onClose: () => void;
  onSave: () => void;
  editingTemplateId: string | null;
  setEditingTemplateId: (id: string | null) => void;
}) {
  const { activeOrganizationId } = useOrganizationContext();
  const { productTypes } = useProductTypes();
  
  // ✅ FIX: Declarar productTypeId ANTES de usarlo en useCatalogItems
  const [productTypeId, setProductTypeId] = useState<string>('');
  
  // ✅ FIX: Cargar TODOS los CatalogItems (sin filtro por ProductType temporalmente para debugging)
  // TODO: Restaurar filtro por ProductType una vez que la búsqueda funcione correctamente
  const { items: catalogItems, loading: catalogItemsLoading } = useCatalogItems();
  
  // Debug: Log cuando cambian los catalogItems
  useEffect(() => {
    if (import.meta.env.DEV && catalogItems.length > 0) {
      console.log(`[BOMTemplates] CatalogItems loaded: ${catalogItems.length} items`);
      const rca04Items = catalogItems.filter((item: any) => 
        (item.sku || '').toUpperCase().includes('RCA-04')
      );
      if (rca04Items.length > 0) {
        console.log(`[BOMTemplates] RCA-04 items found:`, rca04Items.map((item: any) => item.sku).join(', '));
      }
    }
  }, [catalogItems.length]);
  const { categories } = useItemCategories();
  const { categories: leafCategories = [] } = useLeafItemCategories();
  const { createTemplate, updateTemplate, isCreating, isUpdating } = useBOMTemplateCRUD();
  const { createComponent, updateComponent } = useBOMCRUD();
  const { components: existingComponents } = useBOMComponents(editingTemplateId || null);

  const [templateCode, setTemplateCode] = useState<string>(''); // ✅ Template code (unique)
  const [templateName, setTemplateName] = useState<string>('');
  const [templateDescription, setTemplateDescription] = useState<string>('');
  const [templateHardwareColor, setTemplateHardwareColor] = useState<string>(''); // ✅ Hardware color (White, Black, etc.) or empty for all colors
  const [templatePanelCount, setTemplatePanelCount] = useState<1 | 2 | 3>(1); // ✅ Paños (1, 2 or 3) - filter in configurator
  const [components, setComponents] = useState<any[]>([]);
  const [componentsToDelete, setComponentsToDelete] = useState<string[]>([]); // ✅ IDs de componentes a borrar en save
  const initialComponentsRef = useRef<any[]>([]); // ✅ Snapshot inicial para comparar
  const [showAddComponentForm, setShowAddComponentForm] = useState(false);
  const [editingComponentId, setEditingComponentId] = useState<string | null>(null);
  const [componentSearchTerm, setComponentSearchTerm] = useState<string>('');
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState<string>('');
  const [showComponentDropdown, setShowComponentDropdown] = useState(false);
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const componentInputRef = useRef<HTMLDivElement>(null);
  const componentInputFieldRef = useRef<HTMLInputElement>(null);
  const [showEngineeringModal, setShowEngineeringModal] = useState(false);
  const [editingEngineeringComponentId, setEditingEngineeringComponentId] = useState<string | null>(null);
  const [engineeringData, setEngineeringData] = useState({
    depends_on_role: '',
    cut_axis: 'none' as 'length' | 'width' | 'height' | 'none',
    cut_delta_mm: null as number | null,
    cut_delta_scope: 'none' as 'per_side' | 'per_item' | 'none',
  });
  
  // ✅ NUEVO: Estado para gestión de HIJOS
  const [showChildrenModal, setShowChildrenModal] = useState(false);
  const [editingParentComponentId, setEditingParentComponentId] = useState<string | null>(null);
  const [childComponents, setChildComponents] = useState<any[]>([]);
  const [loadingChildren, setLoadingChildren] = useState(false);
  const [showAddChildForm, setShowAddChildForm] = useState(false);
  const [editingChildId, setEditingChildId] = useState<string | null>(null);
  const [childFormData, setChildFormData] = useState({
    child_item_id: '',
    child_role: '',
    qty: 1,
    uom: 'ea',
    required: true,
    notes: '',
  });
  const [childSearchTerm, setChildSearchTerm] = useState('');
  const [showChildDropdown, setShowChildDropdown] = useState(false);
  // ✅ FIX: Cargar roles canónicos desde CatalogItemRoles y filtrar solo los válidos como child roles
  const [catalogItemRoles, setCatalogItemRoles] = useState<any[]>([]);
  const childRoleOptions = useMemo(() => {
    // Primero intentar cargar desde CatalogItemRoles (si está disponible)
    if (catalogItemRoles.length > 0) {
      // Filtrar solo roles canónicos que pueden ser child roles
      const validRoles = catalogItemRoles
        .filter((role: any) => 
          role.active !== false && 
          VALID_CHILD_ROLES.includes(role.role_code as any)
        )
        .map((role: any) => role.role_code)
        .filter((code: string) => VALID_CHILD_ROLES.includes(code as any));
      
      if (validRoles.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[BOMTemplates] Child roles from CatalogItemRoles (canonical):', validRoles);
        }
        return validRoles as readonly string[];
      }
    }
    
    // Fallback: usar VALID_CHILD_ROLES directamente
    const roles = VALID_CHILD_ROLES as readonly string[];
    if (import.meta.env.DEV) {
      console.log('[BOMTemplates] Using VALID_CHILD_ROLES (canonical):', roles);
    }
    return roles;
  }, [catalogItemRoles]);

  // Cargar CatalogItemRoles al montar el componente
  useEffect(() => {
    const loadCatalogItemRoles = async () => {
      try {
        const { data, error } = await supabase
          .from('CatalogItemRoles')
          .select('role_code, label, description, active, sort_order')
          .eq('active', true)
          .order('sort_order', { ascending: true });
        
        if (error) {
          if (import.meta.env.DEV) {
            console.warn('[BOMTemplates] Error loading CatalogItemRoles (non-critical):', error);
          }
          return; // Fallback a VALID_CHILD_ROLES
        }
        
        if (data && data.length > 0) {
          if (import.meta.env.DEV) {
            console.log('[BOMTemplates] Loaded CatalogItemRoles:', data.length, 'roles');
          }
          setCatalogItemRoles(data);
        }
      } catch (err) {
        if (import.meta.env.DEV) {
          console.warn('[BOMTemplates] Exception loading CatalogItemRoles (non-critical):', err);
        }
        // Fallback a VALID_CHILD_ROLES
      }
    };
    
    loadCatalogItemRoles();
  }, []);

  // ✅ FIX: Mapear item_role a child_role canónico válido
  // Solo retorna roles que están en childRoleOptions (roles canónicos válidos como child)
  const mapChildRoleFromItemRole = useCallback(
    (itemRole: string | null | undefined): string => {
      const normalized = normalizeRole(itemRole);
      if (!normalized) return '';
      
      // Si ya es un child role canónico válido, retornarlo
      if (childRoleOptions.includes(normalized)) return normalized;
      
      // Mapear variaciones a roles canónicos válidos
      if (normalized.includes('end_cap') || normalized === 'end_cap') return 'end_cap';
      if (normalized.includes('adapter') || normalized === 'adapter') return 'adapter';
      if (normalized.includes('fastener') || normalized === 'fastener') return 'fastener';
      if (normalized.includes('idler') || normalized === 'idler') return 'idler';
      if (normalized.includes('chain_stop') || normalized === 'chain_stop') return 'chain_stop';
      if (normalized.includes('chain_tensioner') || normalized === 'chain_tensioner') return 'chain_tensioner';
      if (normalized.includes('filler') || normalized === 'filler') return 'filler';
      
      // Si no se puede mapear a un role canónico válido, retornar vacío
      // (el usuario deberá seleccionar manualmente)
      return '';
    },
    [childRoleOptions]
  );
  
  // ✅ PERSISTENCIA: Draft key para sessionStorage
  const draftKey = `bomTemplateDraft:${editingTemplateId || 'new'}`;
  const isInitialMount = useRef(true);

  // ✅ MVP: Simplified form state - only MVP fields
  const [formData, setFormData] = useState<{
    component_item_id: string;
    component_role: string;
    qty_type: BOMQtyType;
    qty_value: number | null;
    uom: string;
    sequence_order: number;
    is_required: boolean;
  }>({
    component_item_id: '',
    component_role: '',
    qty_type: 'fixed',
    qty_value: null,
    uom: 'ea',
    sequence_order: 0,
    is_required: true,
  });

  // ✅ Cerrar dropdown de child component al hacer clic fuera
  useEffect(() => {
    if (!showChildDropdown) return;

    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      const dropdown = document.querySelector('[data-child-dropdown]');
      const input = document.querySelector('[data-child-input]');
      
      if (dropdown && input && !dropdown.contains(target) && !input.contains(target)) {
        setShowChildDropdown(false);
      }
    };

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setShowChildDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleEscape);

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleEscape);
    };
  }, [showChildDropdown]);

  // ✅ PERSISTENCIA: Restaurar estado desde sessionStorage al montar
  useEffect(() => {
    if (isInitialMount.current) {
      try {
        const rawDraft = sessionStorage.getItem(draftKey);
        if (rawDraft) {
          const parsed = JSON.parse(rawDraft);
          if (parsed.productTypeId) setProductTypeId(parsed.productTypeId);
          if (parsed.templateCode) setTemplateCode(parsed.templateCode);
          if (parsed.templateName) setTemplateName(parsed.templateName);
          if (parsed.templateDescription) setTemplateDescription(parsed.templateDescription);
          if (parsed.templateHardwareColor !== undefined) setTemplateHardwareColor(parsed.templateHardwareColor || '');
          if (parsed.templatePanelCount !== undefined) setTemplatePanelCount(Math.min(3, Math.max(1, Number(parsed.templatePanelCount) || 1)) as 1 | 2 | 3);
          if (parsed.components) {
            const shouldRestoreComponents =
              !editingTemplateId ||
              (Array.isArray(parsed.components) && parsed.components.length > 0);
            if (shouldRestoreComponents) {
              setComponents(parsed.components);
            }
          }
          if (parsed.showAddComponentForm !== undefined) setShowAddComponentForm(parsed.showAddComponentForm);
          console.log('[BOMModal] Restored draft from sessionStorage:', parsed);
        }
      } catch (err) {
        console.warn('[BOMModal] Failed to restore draft from sessionStorage', err);
      } finally {
        isInitialMount.current = false;
      }
    }
  }, [draftKey, editingTemplateId]);

  // ✅ PERSISTENCIA: Guardar estado en sessionStorage cuando cambia
  useEffect(() => {
    if (isInitialMount.current) return; // No guardar en el primer mount

    const payload = {
      productTypeId,
      templateCode,
      templateName,
      templateDescription,
      templateHardwareColor,
      templatePanelCount,
      components,
      showAddComponentForm,
    };
    sessionStorage.setItem(draftKey, JSON.stringify(payload));
  }, [draftKey, productTypeId, templateCode, templateName, templateDescription, templateHardwareColor, templatePanelCount, components, showAddComponentForm]);

  // ✅ PERSISTENCIA: Restaurar al volver al tab
  useOnVisibilityChange(useCallback(() => {
    if (document.visibilityState === 'visible') {
      try {
        const rawDraft = sessionStorage.getItem(draftKey);
        if (rawDraft) {
          const parsed = JSON.parse(rawDraft);
          if (parsed.productTypeId) setProductTypeId(parsed.productTypeId);
          if (parsed.templateCode) setTemplateCode(parsed.templateCode);
          if (parsed.templateName) setTemplateName(parsed.templateName);
          if (parsed.templateDescription) setTemplateDescription(parsed.templateDescription);
          if (parsed.templateHardwareColor !== undefined) setTemplateHardwareColor(parsed.templateHardwareColor || '');
          if (parsed.templatePanelCount !== undefined) setTemplatePanelCount(Math.min(3, Math.max(1, Number(parsed.templatePanelCount) || 1)) as 1 | 2 | 3);
          if (parsed.components) {
            const shouldRestoreComponents =
              !editingTemplateId ||
              (Array.isArray(parsed.components) && parsed.components.length > 0);
            if (shouldRestoreComponents) {
              setComponents(parsed.components);
            }
          }
          if (parsed.showAddComponentForm !== undefined) setShowAddComponentForm(parsed.showAddComponentForm);
          console.log('[BOMModal] Restored draft on visibility change:', parsed);
        }
      } catch (err) {
        console.warn('[BOMModal] Failed to restore draft on visibility change', err);
      }
    }
  }, [draftKey]));

  // ✅ PERSISTENCIA: Limpiar draft al cerrar modal
  const clearDraft = useCallback(() => {
    sessionStorage.removeItem(draftKey);
    console.log('[BOMModal] Cleared draft from sessionStorage');
  }, [draftKey]);

  // Load template data if editing
  useEffect(() => {
    if (editingTemplateId && activeOrganizationId) {
      supabase
        .from('BOMTemplates')
        .select('*')
        .eq('id', editingTemplateId)
        .single()
        .then(({ data, error }: { data: any; error: any }) => {
          if (!error && data) {
            setProductTypeId(data.product_type_id);
            setTemplateCode(data.code || ''); // ✅ Load code
            setTemplateName(data.name || data.template_name || '');
            setTemplateDescription(data.description || '');
            setTemplateHardwareColor(data.hardware_color || ''); // ✅ Load hardware_color
            const pc = data.panel_count_min ?? data.panel_count_max ?? 1;
            setTemplatePanelCount(Math.min(3, Math.max(1, Number(pc) || 1)) as 1 | 2 | 3);
            // ✅ Backend still saves metadata (as {}), but UI doesn't use it
          }
        });
    } else if (!editingTemplateId) {
      // ✅ Reset completo cuando no hay template
      setProductTypeId('');
      setTemplateCode('');
      setTemplateName('');
      setTemplateDescription('');
      setTemplateHardwareColor('');
      setTemplatePanelCount(1);
      setComponents([]);
      setComponentsToDelete([]);
      initialComponentsRef.current = [];
    }
  }, [editingTemplateId, activeOrganizationId]);

  // ✅ MVP: Removed auto-select UOM logic - UOM is always user-selected

  // ✅ FIX: Reset total de estado al cargar template - SIEMPRE REEMPLAZAR, NUNCA MERGE
  useEffect(() => {
    // ✅ Limpiar estado ANTES de cargar cuando cambia templateId
    if (editingTemplateId) {
      // ✅ Limpiar inmediatamente cuando cambia templateId
      setComponents([]);
      setComponentsToDelete([]);
      setEditingComponentId(null);
      setShowAddComponentForm(false);
      setComponentSearchTerm('');
      setSelectedCategoryFilter('');
      setShowComponentDropdown(false);
      setHighlightedIndex(-1);
      initialComponentsRef.current = [];
    } else {
      // ✅ Reset completo cuando no hay template
      setComponents([]);
      setComponentsToDelete([]);
      setEditingComponentId(null);
      setShowAddComponentForm(false);
      setComponentSearchTerm('');
      setSelectedCategoryFilter('');
      setShowComponentDropdown(false);
      setHighlightedIndex(-1);
      setFormData({
        component_item_id: '',
        component_role: '',
        qty_type: 'fixed',
        qty_value: null,
        uom: 'ea',
        sequence_order: 0,
        is_required: true,
      });
      initialComponentsRef.current = [];
      return;
    }
  }, [editingTemplateId]);

  // ✅ FIX: Cargar componentes SOLO cuando existingComponents cambia y templateId existe
  useEffect(() => {
    if (!editingTemplateId) {
      return;
    }

    // ✅ Cargar componentes desde DB - SIEMPRE REEMPLAZAR
    if (existingComponents && Array.isArray(existingComponents)) {
      if (import.meta.env.DEV) {
        console.log('[BOMTemplates] Loading existing components', {
          editingTemplateId,
          componentCount: existingComponents.length,
        });
      }

      // ✅ MVP: Mapear solo campos MVP necesarios
      const mappedComponents = existingComponents.map((comp: any) => ({
        id: comp.id,
        parent_component_id: comp.parent_component_id || null,
        component_item_id: comp.component_item_id || null,
        component_role: comp.component_role || null,
        qty_type: comp.qty_type || 'fixed',
        qty_value: comp.qty_value || 1,
        qty_delta_mm: comp.qty_delta_mm || 0,
        waste_pct: comp.waste_pct || 0,
        depends_on_role: comp.depends_on_role || null,
        cut_axis: comp.cut_axis || null,
        cut_delta_mm: comp.cut_delta_mm || 0,
        uom: comp.uom || 'ea',
        sort_order: comp.sort_order || 0,
        sequence_order: comp.sort_order || 0,
        component_mode: comp.component_mode || 'auto',
        is_required: comp.is_required !== false,
        auto_select: false, // ✅ MVP: siempre false
        catalog_item: comp.component_item || null,
      }));

      // ✅ FIX: Deduplicación defensiva por ID (O(n))
      const uniqueById = Array.from(
        mappedComponents.reduce((acc, comp) => {
          acc.set(comp.id, comp);
          return acc;
        }, new Map<string, any>()).values()
      );

      // ✅ SIEMPRE REEMPLAZAR estado, NUNCA merge
      setComponents(uniqueById);
      setComponentsToDelete([]); // ✅ Limpiar deletions al cargar
      setEditingComponentId(null);
      setShowAddComponentForm(false);
      setComponentSearchTerm('');
      setSelectedCategoryFilter('');
      setShowComponentDropdown(false);
      setHighlightedIndex(-1);
      setFormData({
        component_item_id: '',
        component_role: '',
        qty_type: 'fixed',
        qty_value: null,
        uom: 'ea',
        sequence_order: uniqueById.length || 0,
        is_required: true,
      });
      
      // ✅ Guardar snapshot inicial
      initialComponentsRef.current = uniqueById.map(c => ({ ...c }));

      if (import.meta.env.DEV) {
        console.log('[BOMTemplates] Components loaded and state reset:', uniqueById.length, 'components (deduplicated by ID)');
      }
    } else if (editingTemplateId) {
      // ✅ Si templateId existe pero no hay componentes válidos, limpiar estado
      if (!existingComponents || !Array.isArray(existingComponents)) {
        setComponents([]);
        setComponentsToDelete([]);
        initialComponentsRef.current = [];
      } else {
        const componentsArray = existingComponents as any[];
        if (componentsArray.length === 0) {
          setComponents([]);
          setComponentsToDelete([]);
          initialComponentsRef.current = [];
        }
      }
    }
  }, [editingTemplateId, existingComponents]);

  const childrenByParent = useMemo(() => {
    const grouped: Record<string, any[]> = {};
    (components || [])
      .filter((c: any) => c.parent_component_id)
      .forEach((child: any) => {
        const parentId = child.parent_component_id;
        if (!grouped[parentId]) grouped[parentId] = [];
        grouped[parentId].push(child);
      });
    Object.keys(grouped).forEach((parentId) => {
      const list = grouped[parentId];
      if (!list) return;
      list.sort((a, b) => {
        const aOrder = a.sort_order ?? a.sequence_order ?? 0;
        const bOrder = b.sort_order ?? b.sequence_order ?? 0;
        if (aOrder !== bOrder) return aOrder - bOrder;
        return String(a.id || '').localeCompare(String(b.id || ''));
      });
    });
    return grouped;
  }, [components]);

  const displayComponents = useMemo(() => {
    return (components || []).filter((c: any) => !c.parent_component_id);
  }, [components]);

  // Group components by block_type (new BOM structure) or category (fallback)
  const componentsByCategory = useMemo(() => {
    console.log('🔍 Grouping components. Total components:', displayComponents?.length || 0);
    if (!displayComponents || displayComponents.length === 0) {
      console.log('⚠️ No components to group');
      return [];
    }

    const groups = new Map<string | null, ComponentGroupedByCategory>();
    
    const blockTypeLabels: Record<string, string> = {
      'tube': 'TUBO',
      'drive': 'DRIVE',
      'brackets': 'BRACKET',
      'cassette': 'CASSETTE',
      'bottom_rail': 'BOTTOM_RAIL',
      'side_channel': 'SIDE_CHANNEL',
    };
    
    displayComponents.forEach((component: any) => {
      const componentItem = catalogItems.find(item => item.id === component.component_item_id) || component.catalog_item;
      
      const blockType = component.block_type;
      const categoryId = componentItem?.item_category_id || component.component_category_id || null;
      
      let groupKey: string | null;
      let categoryName: string;
      let categoryCode: string | null;
      
      if (blockType) {
        groupKey = `block_type_${blockType}`;
        categoryName = blockTypeLabels[blockType] || blockType.toUpperCase();
        categoryCode = blockType;
      } else {
        const category = categories.find(cat => cat.id === categoryId);
        groupKey = categoryId;
        categoryName = category?.name || component.component_category_name || 'Uncategorized';
        categoryCode = category?.code || component.component_category_code || null;
      }
      
      if (!groups.has(groupKey)) {
        groups.set(groupKey, {
          category_id: groupKey,
          category_name: categoryName,
          category_code: categoryCode,
          components: [],
        });
      }
      groups.get(groupKey)!.components.push(component);
    });

    const blockTypeOrder = ['tube', 'drive', 'brackets', 'cassette', 'bottom_rail', 'side_channel'];
    const sortedGroups = Array.from(groups.values()).sort((a, b) => {
      const aIsBlockType = a.category_code && blockTypeOrder.includes(a.category_code);
      const bIsBlockType = b.category_code && blockTypeOrder.includes(b.category_code);
      
      if (aIsBlockType && bIsBlockType) {
        return blockTypeOrder.indexOf(a.category_code!) - blockTypeOrder.indexOf(b.category_code!);
      }
      if (aIsBlockType) return -1;
      if (bIsBlockType) return 1;
      
      if (a.category_code && b.category_code) {
        return a.category_code.localeCompare(b.category_code);
      }
      return a.category_name.localeCompare(b.category_name);
    });

    sortedGroups.forEach(group => {
      group.components.sort((a, b) => (a.sequence_order || 0) - (b.sequence_order || 0));
    });

    return sortedGroups;
  }, [displayComponents, catalogItems, categories]);

  // Get flat list of filtered items for autocomplete
  // Note: This must be defined after filteredAndGroupedComponents, so we'll calculate it directly
  const flatFilteredItems = useMemo(() => {
    const items: Array<{ 
      id: string; 
      sku: string; 
      name: string; 
      category: string; 
      categoryCode: string | null;
      uom: string;
    }> = [];
    
    // Calculate filtered items directly from catalogItems to avoid dependency on filteredAndGroupedComponents
    const searchTerm = componentSearchTerm.trim();
    const normalizedSearch = searchTerm.toLowerCase().replace(/[-_\s]/g, '');
    
    const filtered = catalogItems.filter((item) => {
      // Exclude items already in components (unless editing)
      if (editingComponentId) {
        const editingComponent = components.find(c => c.id === editingComponentId);
        if (editingComponent && editingComponent.component_item_id === item.id) {
          // Allow the item being edited
        } else if (components.some(c => c.component_item_id === item.id)) {
          return false;
        }
      } else {
        if (components.some(c => c.component_item_id === item.id)) {
          return false;
        }
      }

      // Category filter
      if (selectedCategoryFilter) {
        // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
        const itemCategoryId = item.category_id || item.item_category_id;
        if (itemCategoryId !== selectedCategoryFilter) {
          return false;
        }
      }

      // ✅ FIX: Search filter - Mejorado para ser tan flexible como Items.tsx
      if (normalizedSearch) {
        const searchLower = searchTerm.toLowerCase().trim();
        const searchNormalized = searchLower.replace(/[-\s]/g, ''); // Remove hyphens and spaces
        
        // Normalize SKU for flexible matching (RCA-04-W = RCA04W = "RCA 04 W")
        const skuNormalized = (item.sku || '').toLowerCase().replace(/[-\s]/g, '');
        const skuExact = (item.sku || '').toLowerCase();
        
        // Get additional fields from item
        const itemName = (item.name || item.item_name || '').toLowerCase();
        const itemDesc = (item.description || '').toLowerCase();
        const collectionName = (item.collection_name || '').toLowerCase();
        const variantName = (item.variant_name || '').toLowerCase();
        const color = (item.color || '').toLowerCase();
        const measureBasis = (item.measure_basis || '').toLowerCase();
        const uom = (item.unit_of_measure || item.uom || '').toLowerCase();
        const manufacturer = ((item as any).manufacturer || '').toLowerCase();
        
        // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
        const itemCategoryId = item.category_id || item.item_category_id;
        const category = categories.find(c => c.id === itemCategoryId);
        const categoryName = (category?.name || '').toLowerCase();
        const categoryCode = (category?.code || '').toLowerCase();
        
        // Check if matches any field (flexible matching)
        const matches = (
          // SKU: exact + normalized matching (RCA-04-W matches "rca-04", "rca04", "rca-04-w", etc.)
          skuExact.includes(searchLower) ||
          skuNormalized.includes(searchNormalized) ||
          // Name
          itemName.includes(searchLower) ||
          // Description
          itemDesc.includes(searchLower) ||
          // Collection, Variant, Color
          collectionName.includes(searchLower) ||
          variantName.includes(searchLower) ||
          color.includes(searchLower) ||
          // Measure basis, UOM
          measureBasis.includes(searchLower) ||
          uom.includes(searchLower) ||
          // Manufacturer
          manufacturer.includes(searchLower) ||
          // Category
          categoryName.includes(searchLower) ||
          categoryCode.includes(searchLower)
        );
        
        if (!matches) {
          return false;
        }
      }

      return true;
    });

    // Group by category and create flat list
    const categoryMap = new Map<string | null, { category: any; items: any[] }>();
    
    filtered.forEach((item) => {
      // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
      const categoryId = item.category_id || item.item_category_id || null;
      const category = categories.find(c => c.id === categoryId) || {
        id: null,
        name: 'Uncategorized',
        code: null 
      };
      
      if (!categoryMap.has(categoryId)) {
        categoryMap.set(categoryId, {
          category: { id: category.id, name: category.name, code: category.code },
          items: []
        });
      }
      categoryMap.get(categoryId)!.items.push(item);
    });

    // Flatten into array
    categoryMap.forEach((group) => {
      group.items.forEach((item) => {
        items.push({
          id: item.id,
          sku: item.sku || '',
          name: item.name || item.item_name || 'Unnamed',
          category: group.category.name,
          categoryCode: group.category.code,
          uom: item.uom || 'ea',
        });
      });
    });

    return items;
  }, [catalogItems, componentSearchTerm, selectedCategoryFilter, components, categories, editingComponentId]);

  // Handle keyboard navigation
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!showComponentDropdown || flatFilteredItems.length === 0) {
      if (e.key === 'ArrowDown' && flatFilteredItems.length > 0) {
        setShowComponentDropdown(true);
        setHighlightedIndex(0);
      }
      return;
    }

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setHighlightedIndex(prev => 
        prev < flatFilteredItems.length - 1 ? prev + 1 : prev
      );
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setHighlightedIndex(prev => prev > 0 ? prev - 1 : 0);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (highlightedIndex >= 0 && highlightedIndex < flatFilteredItems.length && flatFilteredItems[highlightedIndex]) {
        handleSelectComponent(flatFilteredItems[highlightedIndex].id);
      }
    } else if (e.key === 'Escape') {
      setShowComponentDropdown(false);
      setHighlightedIndex(-1);
    }
  };

  const handleSelectComponent = (itemId: string) => {
    const selectedItem = catalogItems.find(item => item.id === itemId);
    
    if (!selectedItem) {
      console.warn('⚠️ Selected item not found:', itemId);
      return;
    }
    
    // ✅ FIX: Auto-llenar component_role desde item_role del CatalogItem
    // Intentar obtener item_role de múltiples formas para compatibilidad
    const itemRole = selectedItem?.item_role || (selectedItem as any)?.item_role || '';
    const autoRole = itemRole ? normalizeRole(itemRole) : '';
    
    if (import.meta.env.DEV) {
      console.log('🔍 handleSelectComponent:', {
        itemId,
        sku: selectedItem.sku,
        name: selectedItem.name,
        item_role: itemRole,
        normalizedRole: autoRole,
        selectedItemKeys: Object.keys(selectedItem),
      });
    }
    
    // ✅ FIX: For fabrics, force UOM to 'm' (linear meters)
    const isFabric = selectedItem?.is_fabric || false;
    const isFabricRole = autoRole === 'fabric';
    const shouldUseMeters = isFabric || isFabricRole;
    const catalogUom = shouldUseMeters ? 'm' : (selectedItem?.unit_of_measure || selectedItem?.uom || 'ea');
    
    setFormData({ 
      ...formData, 
      component_item_id: itemId,
      component_role: autoRole || formData.component_role || '', // ✅ Auto-fill desde item_role, mantener el actual si no hay item_role
      uom: catalogUom // ✅ Force 'm' for fabrics
    });
    
    // ✅ FIX: Set search term to show selected item
    if (selectedItem) {
      setComponentSearchTerm(`${selectedItem.sku} - ${selectedItem.name || selectedItem.item_name || ''}`);
    }
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  };

  // Note: Search term is now controlled by the Input value directly (shows selected component when selected)

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      const inputContainer = componentInputRef.current;
      const dropdown = document.querySelector('.component-autocomplete-dropdown');
      
      if (inputContainer && !inputContainer.contains(target) && 
          dropdown && !dropdown.contains(target)) {
        setShowComponentDropdown(false);
        setHighlightedIndex(-1);
      }
    };

    if (showComponentDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => {
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [showComponentDropdown]);

  // ✅ Add parent component
  const handleAddComponent = () => {
    if (import.meta.env.DEV) {
      console.log('[handleAddComponent] Called with formData:', formData);
    }
    
    // MVP Validations
    if (!formData.component_item_id) {
      if (import.meta.env.DEV) {
        console.log('[handleAddComponent] Validation failed: component_item_id missing');
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Selecciona un componente (SKU)',
      });
      return;
    }

    if (!formData.component_role) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Component role is required.',
      });
      return;
    }

    if (!isValidRole(formData.component_role)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Role',
        message: `Invalid component_role: "${formData.component_role}". Please select a valid role from the dropdown.`,
      });
      return;
    }
    
    const normalizedRole = normalizeRole(formData.component_role);
    // ✅ MVP: Dropdown already provides canonical snake_case values, so normalization check is redundant
    
    if (!formData.qty_type) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Quantity Type is required.',
      });
      return;
    }

    if (formData.qty_type === 'fixed' && (!formData.qty_value || formData.qty_value <= 0)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Quantity Value is required and must be > 0 when Quantity Type is fixed.',
      });
      return;
    }

    if (!formData.uom) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'UOM is required.',
      });
      return;
    }

    // ✅ FIX: For fabric role, ensure UOM is 'm' and set qty_type to allow formula
    const isFabricRole = normalizedRole === 'fabric';
    const finalUom = isFabricRole ? 'm' : normalizeUom(formData.uom) || 'ea';
    const finalQtyType = isFabricRole && formData.qty_type === 'fixed' 
      ? 'per_area' // ✅ Fabric should use formula, not fixed
      : formData.qty_type;
    
    const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);

    const newParent = {
      id: `temp-${crypto.randomUUID()}`,
      organization_id: activeOrganizationId || '',
      bom_template_id: editingTemplateId || null,
      parent_component_id: null,
      component_item_id: formData.component_item_id,
      component_role: normalizedRole,
      qty_type: finalQtyType,
      qty_value: finalQtyType === 'fixed' ? (formData.qty_value || 1) : 1,
      qty_delta_mm: 0,
      waste_pct: 0,
      uom: finalUom,
      sort_order: formData.sequence_order ?? 0,
      sequence_order: formData.sequence_order ?? 0,
      is_required: formData.is_required ?? true,
      deleted: false,
      archived: false,
      catalog_item: selectedItem
        ? {
            id: selectedItem.id,
            sku: selectedItem.sku,
            name: selectedItem.name || selectedItem.item_name,
          }
        : null,
    };

    setComponents([...components, newParent]);

    resetForm();
    
    useUIStore.getState().addNotification({
      type: 'success',
      title: 'Success',
      message: 'Component added successfully.',
    });
  };

  // ✅ Update Parent Component (BOMComponents)
  const handleUpdateComponent = async () => {
    if (!editingComponentId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'No component selected for editing.',
      });
      return;
    }

    // MVP Validations (same as handleAddComponent)
    if (!formData.component_item_id) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Selecciona un componente (SKU)',
      });
      return;
    }

    // ✅ FIX: Si no hay component_role pero hay component_item_id, intentar obtenerlo del item
    let finalComponentRole = formData.component_role;
    if (!finalComponentRole && formData.component_item_id) {
      const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);
      if (selectedItem) {
        const itemRole = selectedItem?.item_role || (selectedItem as any)?.item_role || '';
        finalComponentRole = itemRole ? (normalizeRole(itemRole) || '') : '';
        if (finalComponentRole) {
          // Actualizar formData con el role encontrado
          setFormData({ ...formData, component_role: finalComponentRole });
        }
      }
    }

    if (!finalComponentRole) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Component role is required. Please select a component with a valid item_role.',
      });
      return;
    }

    if (!isValidRole(finalComponentRole)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Role',
        message: `Invalid component_role: "${finalComponentRole}". The role must be a valid canonical role.`,
      });
      return;
    }
    
    const normalizedRole = normalizeRole(finalComponentRole);
    // ✅ MVP: Dropdown already provides canonical snake_case values, so normalization check is redundant
    
    if (!formData.qty_type) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Quantity Type is required.',
      });
      return;
    }

    if (formData.qty_type === 'fixed' && (!formData.qty_value || formData.qty_value <= 0)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Quantity Value is required and must be > 0 when Quantity Type is fixed.',
      });
      return;
    }

    if (!formData.uom) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'UOM is required.',
      });
      return;
    }

    try {
      // ✅ FIX: For fabric role, ensure UOM is 'm' and set qty_type/formula
      const isFabricRole = normalizedRole === 'fabric';
      const normalizedUom = isFabricRole ? 'm' : (normalizeUom(formData.uom) || 'ea');
      const finalQtyType = isFabricRole && formData.qty_type === 'fixed' 
        ? 'per_area' // ✅ Fabric should use formula, not fixed
        : formData.qty_type;

      const updateData = {
        component_item_id: formData.component_item_id,
        component_role: normalizedRole,
        qty_type: finalQtyType,
        qty_value: formData.qty_value || 1,
        qty_delta_mm: 0,
        waste_pct: 0,
        uom: normalizedUom,
        sort_order: formData.sequence_order ?? 0,
        is_required: formData.is_required ?? true,
      };

      if (editingComponentId) {
        // ✅ Local-only update when template isn't saved yet (or temp component)
        const isLocalComponent =
          !editingTemplateId || String(editingComponentId).startsWith('temp-');

        if (isLocalComponent) {
          const updatedComponents = components.map((c) =>
            c.id === editingComponentId ? { ...c, ...updateData } : c
          );
          setComponents(updatedComponents);
          if (import.meta.env.DEV) {
            console.log('[handleUpdateComponent] Local update (no templateId):', {
              componentId: editingComponentId,
            });
          }
          resetForm();
          return;
        }

        // ✅ Verify component exists
        const componentExists = components.some(c => c.id === editingComponentId);
        if (!componentExists) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: 'Component not found. Please try again.',
          });
          return;
        }

        if (import.meta.env.DEV) {
          console.log('[handleUpdateComponent] Updating component:', {
            componentId: editingComponentId,
            originalUom: formData.uom,
            normalizedUom,
            updateData,
          });
        }

        await updateComponent(editingComponentId, updateData);

        // ✅ FIX: Recargar desde DB para asegurar estado sincronizado (igual que en handleSave)
        if (editingTemplateId) {
          const { data: refreshedComponents, error: refreshError } = await supabase
            .from('BOMComponents')
            .select('*')
            .eq('bom_template_id', editingTemplateId)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .eq('archived', false)
            .order('parent_component_id', { ascending: true })
            .order('sort_order', { ascending: true })
            .order('created_at', { ascending: true });
          
          if (!refreshError && refreshedComponents) {
            const mappedComponents = (refreshedComponents as any[]).map((comp: any) => ({
              id: comp.id,
              parent_component_id: comp.parent_component_id || null,
              component_item_id: comp.component_item_id || null,
              component_role: comp.component_role || null,
              qty_type: comp.qty_type || 'fixed',
              qty_value: comp.qty_value || 1,
              qty_delta_mm: comp.qty_delta_mm || 0,
              waste_pct: comp.waste_pct || 0,
              depends_on_role: comp.depends_on_role || null,
              cut_axis: comp.cut_axis || null,
              cut_delta_mm: comp.cut_delta_mm || 0,
              uom: normalizeUom(comp.uom) || 'ea', // ✅ Normalize UOM from DB
              sort_order: comp.sort_order || 0,
              sequence_order: comp.sort_order || 0,
              auto_select: false,
            }));
            
            // ✅ Deduplicación defensiva por ID
            const uniqueById = Array.from(
              mappedComponents.reduce((acc: Map<string, any>, comp: any) => {
                acc.set(comp.id, comp);
                return acc;
              }, new Map<string, any>()).values()
            ) as any[];
            
            setComponents(uniqueById);
            initialComponentsRef.current = uniqueById.map((c: any) => ({ ...c }));
            
            if (import.meta.env.DEV) {
              console.log('[handleUpdateComponent] Components reloaded from DB:', {
                componentId: editingComponentId,
                updatedUom: uniqueById.find((c: any) => c.id === editingComponentId)?.uom,
                totalComponents: uniqueById.length,
              });
            }
          } else if (refreshError) {
            // ✅ FIX: Formatear error para evitar "[circular]"
            const errorDetails = { 
              message: refreshError.message, 
              code: refreshError.code,
              details: refreshError.details 
            };
            console.warn('[handleUpdateComponent] Error reloading components (non-critical):', errorDetails);
            // Fallback: update local state with updateData
            const updatedComponents = components.map(c => {
              if (c.id === editingComponentId) {
                return {
                  ...c,
                  ...updateData,
                };
              }
              return c;
            });
            setComponents(updatedComponents);
          }
        } else {
          // Fallback: update local state if no templateId
          const updatedComponents = components.map(c => {
            if (c.id === editingComponentId) {
              return {
                ...c,
                ...updateData,
              };
            }
            return c;
          });
          setComponents(updatedComponents);
        }
      }
      
      resetForm();

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Component updated successfully.',
      });
    } catch (error) {
      // ✅ FIX: Formatear error para evitar "[circular]"
      const errorDetails = error instanceof Error 
        ? { message: error.message, name: error.name }
        : typeof error === 'object' && error !== null
        ? { message: (error as any).message || String(error), code: (error as any).code }
        : String(error);
      console.error('[handleUpdateComponent] Error updating component:', errorDetails);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: error instanceof Error ? error.message : 'Failed to update component.',
      });
    }
  };

  // ✅ MVP: Simplified resetForm - only MVP fields
  const resetForm = () => {
    setEditingComponentId(null);
    setFormData({
      component_item_id: '',
      component_role: '',
      qty_type: 'fixed',
      qty_value: null,
      uom: 'ea',
      sequence_order: components.length,
      is_required: true,
    });
    setShowAddComponentForm(false);
    setComponentSearchTerm('');
    setSelectedCategoryFilter('');
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  };

  // ✅ Local delete; persisted on save (soft delete)
  const handleDeleteComponent = (component: any) => {
    const componentId = component?.id as string;

    const childIds = components
      .filter(c => String(c.parent_component_id) === String(componentId))
      .map(c => c.id);

    if (componentId.startsWith('temp-')) {
      setComponents(components.filter(c => c.id !== componentId && !childIds.includes(c.id)));
    } else {
      setComponents(components.filter(c => c.id !== componentId && !childIds.includes(c.id)));
      setComponentsToDelete(prev => {
        const next = new Set(prev);
        next.add(componentId);
        childIds.filter(id => !String(id).startsWith('temp-')).forEach(id => next.add(id));
        return Array.from(next);
      });
    }

    if (import.meta.env.DEV) {
      console.log('[BOMTemplates] Component deleted locally:', {
        componentId,
        isTemp: componentId?.startsWith('temp-'),
        componentsToDeleteCount: componentId?.startsWith('temp-') ? componentsToDelete.length : componentsToDelete.length + 1,
      });
    }
  };

  // ✅ MVP: Simplified handleEditComponent - only MVP fields
  const handleEditComponent = (component: any) => {
    // ✅ FIX: Cerrar modal de children si está abierto antes de editar
    if (showChildrenModal) {
      handleCloseChildrenModal();
    }

    const componentItemId = component.component_item_id || '';
    const componentItem = catalogItems.find(item => item.id === componentItemId);
    // ✅ FIX: Usar solo 'name' (no 'item_name' que no existe) y mostrar SKU incluso si no hay name
    // ✅ FIX: Si no hay componente, dejar el campo en blanco (no mostrar "No component selected")
    const displayText = componentItem 
      ? `${componentItem.sku || 'N/A'} - ${componentItem.name || 'Unnamed'}` 
      : (component.catalog_item 
          ? `${component.catalog_item.sku || 'N/A'} - ${component.catalog_item.name || 'Unnamed'}` 
          : ''); // ✅ Cambiado: '' en lugar de 'No component selected'
    
    // ✅ FIX: Ensure UOM is properly initialized from component (prioritize component.uom)
    // Normalize UOM from component (lowercase, trim)
    // For fabric role, force UOM to 'm'
    const isFabricRole = component.component_role === 'fabric';
    const componentUomNormalized = isFabricRole ? 'm' : normalizeUom(component.uom);
    const fallbackUom = isFabricRole
      ? 'm'
      : (normalizeUom(componentItem?.unit_of_measure || componentItem?.uom) || 'ea');
    const finalUom = componentUomNormalized || fallbackUom;
    
    if (import.meta.env.DEV) {
      console.log('[handleEditComponent] Initializing form:', {
        componentId: component.id,
        componentItemId,
        componentItem: componentItem ? { id: componentItem.id, sku: componentItem.sku, name: componentItem.name } : null,
        catalogItem: component.catalog_item ? { id: component.catalog_item.id, sku: component.catalog_item.sku, name: component.catalog_item.name } : null,
        displayText,
        componentUom: component.uom,
        componentUomNormalized,
        componentItemUom: componentItem?.uom,
        fallbackUom,
        finalUom,
      });
    }
    
    setEditingComponentId(component.id);
    // ✅ FIX: Establecer el texto de búsqueda para mostrar el componente seleccionado ANTES de mostrar el formulario
    // ✅ Si no hay componente, dejar en blanco (no mostrar "No component selected")
    setComponentSearchTerm(displayText);
    setFormData({
      component_item_id: componentItemId,
      component_role: component.component_role || '',
      qty_type: component.qty_type || 'fixed',
      qty_value: component.qty_type === 'fixed' ? (component.qty_value || 1) : null,
      uom: finalUom, // ✅ FIX: Use normalized UOM
      sequence_order: component.sort_order || component.sequence_order || 0,
      is_required: component.is_required ?? true,
    });
    setShowAddComponentForm(true);
    setSelectedCategoryFilter('');
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  };

  const handleOpenEngineeringModal = (componentId: string) => {
    const component = components.find(c => c.id === componentId);
    if (component) {
      setEditingEngineeringComponentId(componentId);
      const cutAxis = component.cut_axis || 'none';
      setEngineeringData({
        depends_on_role: (cutAxis === 'none' || !cutAxis) ? '' : (component.depends_on_role || ''),
        cut_axis: cutAxis,
        cut_delta_mm: component.cut_delta_mm || null,
        cut_delta_scope: component.cut_delta_scope || 'none',
      });
      setShowEngineeringModal(true);
    }
  };

  const handleSaveEngineeringRules = () => {
    if (!editingEngineeringComponentId) return;
    
    const finalDependsOnRole = (engineeringData.cut_axis === 'none' || !engineeringData.cut_axis) 
      ? null 
      : normalizeRole(engineeringData.depends_on_role);
    
    setComponents(components.map(c => {
      if (c.id === editingEngineeringComponentId) {
        return {
          ...c,
          depends_on_role: finalDependsOnRole,
          cut_axis: engineeringData.cut_axis === 'none' ? null : engineeringData.cut_axis || null,
          cut_delta_mm: engineeringData.cut_delta_mm || null,
          cut_delta_scope: engineeringData.cut_delta_scope === 'none' ? null : engineeringData.cut_delta_scope || null,
        };
      }
      return c;
    }));
    
    setShowEngineeringModal(false);
    setEditingEngineeringComponentId(null);
    setEngineeringData({
      depends_on_role: '',
      cut_axis: 'none',
      cut_delta_mm: null,
      cut_delta_scope: 'none',
    });
  };

  // ✅ Open modal with children from BOMComponents tree
  const handleOpenChildrenModal = (parentComponentId: string) => {
    if (!parentComponentId) return;
    setEditingParentComponentId(parentComponentId);
    setShowChildrenModal(true);
    setLoadingChildren(false);
    setChildComponents(childrenByParent[parentComponentId] || []);
  };

  // ✅ NUEVO: Cerrar modal de HIJOS
  const handleCloseChildrenModal = () => {
    if (import.meta.env.DEV) {
      console.log('[handleCloseChildrenModal] Closing modal and resetting state');
    }
    setShowChildrenModal(false);
    setEditingParentComponentId(null);
    setChildComponents([]);
    setShowAddChildForm(false);
    setEditingChildId(null);
    setChildFormData({
      child_item_id: '',
      child_role: '',
      qty: 1,
      uom: 'ea',
      required: true,
      notes: '',
    });
    setChildSearchTerm('');
    setShowChildDropdown(false);
  };

  // ✅ Add or update child component in BOMComponents tree
  const handleAddChild = async () => {
    if (!editingParentComponentId || !activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Missing parent component or organization',
      });
      return;
    }

    const canPersistChild =
      Boolean(editingTemplateId) && !String(editingParentComponentId).startsWith('temp-');

    if (!childFormData.child_item_id) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Select a child item.',
      });
      return;
    }

    if (!childFormData.child_role) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Child role is required.',
      });
      return;
    }

    if (!isValidRole(childFormData.child_role)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Role',
        message: `Invalid child_role: "${childFormData.child_role}". Please select a valid role.`,
      });
      return;
    }

    if (!childFormData.uom) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'UOM is required.',
      });
      return;
    }

    if (!childFormData.qty || childFormData.qty <= 0) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Quantity must be greater than 0.',
      });
      return;
    }

    const normalizedChildRole = normalizeRole(childFormData.child_role) || childFormData.child_role;
    if (!normalizedChildRole) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Child role is invalid.',
      });
      return;
    }

    const duplicate = childComponents.find(
      (c) =>
        c.component_item_id === childFormData.child_item_id &&
        c.parent_component_id === editingParentComponentId &&
        c.id !== editingChildId
    );
    if (duplicate) {
      useUIStore.getState().addNotification({
        type: 'warning',
        title: 'Duplicate Child',
        message: 'This child SKU already exists under this parent.',
      });
      return;
    }

    try {
      const selectedItem = catalogItems.find(item => item.id === childFormData.child_item_id);
      const normalizedUom = normalizeUom(childFormData.uom) || 'ea';
      const wasEditing = Boolean(editingChildId);
      const sortOrder = childComponents.find(c => c.id === editingChildId)?.sort_order ?? childComponents.length;

      const basePayload = {
        organization_id: activeOrganizationId,
        bom_template_id: editingTemplateId || null,
        parent_component_id: editingParentComponentId,
        component_item_id: childFormData.child_item_id,
        component_role: normalizedChildRole,
        qty_type: 'fixed',
        qty_value: childFormData.qty || 1,
        uom: normalizedUom,
        sort_order: sortOrder,
        is_required: childFormData.required !== false,
        deleted: false,
        archived: false,
      };

      let savedChild: any = null;

      if (canPersistChild && editingChildId && !String(editingChildId).startsWith('temp-')) {
        const { data, error } = await supabase
          .from('BOMComponents')
          .update({ ...basePayload, updated_at: new Date().toISOString() })
          .eq('id', editingChildId)
          .eq('organization_id', activeOrganizationId)
          .select('*')
          .single();
        if (error) throw error;
        // ✅ Clean catalog_item to avoid circular references
        const cleanCatalogItem1 = selectedItem ? {
          id: selectedItem.id,
          sku: selectedItem.sku,
          name: selectedItem.name || selectedItem.item_name,
        } : null;
        savedChild = { ...data, catalog_item: cleanCatalogItem1 };
      } else if (canPersistChild && !editingChildId) {
        const { data, error } = await supabase
          .from('BOMComponents')
          .insert(basePayload)
          .select('*')
          .single();
        if (error) throw error;
        // ✅ Clean catalog_item to avoid circular references
        const cleanCatalogItem2 = selectedItem ? {
          id: selectedItem.id,
          sku: selectedItem.sku,
          name: selectedItem.name || selectedItem.item_name,
        } : null;
        savedChild = { ...data, catalog_item: cleanCatalogItem2 };
      } else {
        const tempId = editingChildId || `temp-${crypto.randomUUID()}`;
        // ✅ Clean catalog_item to avoid circular references
        const cleanCatalogItem = selectedItem ? {
          id: selectedItem.id,
          sku: selectedItem.sku,
          name: selectedItem.name || selectedItem.item_name,
        } : null;
        savedChild = { id: tempId, ...basePayload, catalog_item: cleanCatalogItem };
      }

      setComponents((prev) => {
        if (editingChildId) {
          return prev.map(c => (String(c.id) === String(editingChildId) ? savedChild : c));
        }
        return [...prev, savedChild];
      });

      setChildComponents((prev) => {
        if (editingChildId) {
          return prev.map(c => (String(c.id) === String(editingChildId) ? savedChild : c));
        }
        return [...prev, savedChild];
      });

      setShowAddChildForm(false);
      setEditingChildId(null);
      setChildFormData({
        child_item_id: '',
        child_role: '',
        qty: 1,
        uom: 'ea',
        required: true,
        notes: '',
      });
      setChildSearchTerm('');

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: wasEditing ? 'Child component updated successfully' : 'Child component added successfully',
      });
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error Adding Child Component',
        message: err?.message || 'Failed to add child component',
      });
    }
  };

  const handleSave = async () => {
    // ✅ GATING: No hacer nada si no hay organization
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Organization Required',
        message: 'Please select an organization before saving.',
      });
      return;
    }

    if (!productTypeId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Please select a Product Type',
      });
      return;
    }


    // Validate roles: strict for new components, allow legacy only if they come from DB (have temp- ID with _originalId)
    const invalidComponents: string[] = [];
    const legacyComponents: string[] = [];
    
    components.forEach((component, index) => {
      const componentIndex = index + 1;
      const isLegacyFromDB = component.id && !component.id.startsWith('temp-') || (component as any)._originalId;
      
      // Validate component_role
      if (component.component_role && component.component_role.trim() !== '') {
        if (!isValidRole(component.component_role)) {
          if (isLegacyFromDB) {
            // Legacy role from DB - show warning but allow save
            legacyComponents.push(`Component ${componentIndex}: legacy role "${component.component_role}" (migrate to canonical)`);
          } else {
            // New component with invalid role - strict validation
            invalidComponents.push(`Component ${componentIndex}: invalid component_role "${component.component_role}"`);
          }
        }
      }
      
      // Validate depends_on_role
      if (component.depends_on_role && component.depends_on_role.trim() !== '') {
        if (!isValidRole(component.depends_on_role)) {
          if (isLegacyFromDB) {
            legacyComponents.push(`Component ${componentIndex}: legacy depends_on_role "${component.depends_on_role}" (migrate to canonical)`);
          } else {
            invalidComponents.push(`Component ${componentIndex}: invalid depends_on_role "${component.depends_on_role}"`);
          }
        }
      }
    });

    // Block saving if there are invalid roles in new components
    if (invalidComponents.length > 0) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: `Invalid roles found. Please select valid canonical roles for all components:\n${invalidComponents.join('\n')}`,
      });
      return;
    }

    // Show warning for legacy roles from DB (allow save, but encourage migration)
    if (legacyComponents.length > 0) {
      useUIStore.getState().addNotification({
        type: 'warning',
        title: 'Legacy Roles Detected',
        message: `Template contains legacy roles that should be migrated to canonical roles:\n${legacyComponents.join('\n')}\n\nThese will be saved, but please update them to canonical roles.`,
      });
      // Don't return - allow saving to proceed with legacy roles from DB
    }

    try {
      let templateId = editingTemplateId;

      // ✅ MVP: Validar code requerido
      if (!templateCode || templateCode.trim() === '') {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Validation Error',
          message: 'Template Code is required',
        });
        return;
      }

      // ✅ Validar hardware_color requerido
      if (!templateHardwareColor || templateHardwareColor.trim() === '') {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Validation Error',
          message: 'Hardware Color is required to filter templates in the product configurator',
        });
        return;
      }
      
      const normalizedTemplateCode = templateCode.trim();
      const normalizedTemplateName = (templateName || '').trim() || normalizedTemplateCode;
      // Normalize hardware_color (capitalize first letter) - REQUIRED
      const normalizedHardwareColor = templateHardwareColor.trim().charAt(0).toUpperCase() + templateHardwareColor.trim().slice(1).toLowerCase();

      // ✅ FIX: Save template first, then components
      if (editingTemplateId) {
        await updateTemplate(editingTemplateId, {
          code: normalizedTemplateCode,
          name: normalizedTemplateName,
          description: templateDescription || null,
          hardware_color: normalizedHardwareColor,
          panel_count_min: templatePanelCount,
          panel_count_max: templatePanelCount,
          metadata: {},
        } as any);
        templateId = editingTemplateId;
      } else {
        const newTemplate = await createTemplate({
          product_type_id: productTypeId,
          code: normalizedTemplateCode,
          name: normalizedTemplateName,
          description: templateDescription || null,
          hardware_color: normalizedHardwareColor,
          panel_count_min: templatePanelCount,
          panel_count_max: templatePanelCount,
          metadata: {},
        } as any);
        templateId = newTemplate.id;
        // ✅ FIX: Establecer editingTemplateId después de crear el template
        setEditingTemplateId(templateId);
      }

      // ✅ Save BOMComponents only
      if (!templateId) {
        throw new Error('Template ID missing after save');
      }

      // ✅ FIX: Save flow determinístico - deletions, updates, inserts en orden
      const componentsToDeleteSet = new Set(componentsToDelete);
      const tempIdToRealIdMap = new Map<string, string>(); // Map temp IDs to real DB IDs
      
      // Separate parents (no parent_component_id) from children (has parent_component_id)
      const allComponents = components.filter(c => !componentsToDeleteSet.has(c.id));
      const parentComponents = allComponents.filter(c => !c.parent_component_id);
      const childComponents = allComponents.filter(c => !!c.parent_component_id);
      
      // 1) DELETIONS: Borrar componentes marcados para borrado
      if (componentsToDelete.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Deleting components:', componentsToDelete);
        }
        
        const { error: deleteError } = await supabase
          .from('BOMComponents')
          .update({ deleted: true })
          .in('id', componentsToDelete)
          .eq('organization_id', activeOrganizationId)
          .eq('bom_template_id', templateId);
        
        if (deleteError) {
          const errorDetails = { 
            message: deleteError.message, 
            code: deleteError.code,
            details: deleteError.details 
          };
          console.error('[handleSave] Error deleting components:', errorDetails);
          throw new Error(`Error deleting components: ${deleteError.message}`);
        }
      }
      
      // 2) UPDATES: Actualizar componentes existentes (id real y NO en componentsToDelete)
      const parentsToUpdate = parentComponents.filter(c => !c.id.startsWith('temp-'));
      const childrenToUpdate = childComponents.filter(c => !c.id.startsWith('temp-'));
      
      if (parentsToUpdate.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Updating parent components:', parentsToUpdate.length);
        }
        
        for (const component of parentsToUpdate) {
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          const finalComponentRole = normalizedComponentRole || component.component_role || null;
          const normalizedDependsOnRole = normalizeRole(component.depends_on_role || '');
          const finalDependsOnRole = normalizedDependsOnRole || component.depends_on_role || null;
          const isFabricRole = normalizedComponentRole === 'fabric';
          const updateData = {
            parent_component_id: null, // Parents always have null
            component_item_id: component.component_item_id || null,
            component_role: finalComponentRole,
            qty_type: component.qty_type || 'fixed',
            qty_value: component.qty_value || 1,
            qty_delta_mm: component.qty_delta_mm || 0,
            waste_pct: component.waste_pct || 0,
            depends_on_role: finalDependsOnRole,
            cut_axis: component.cut_axis || null,
            cut_delta_mm: component.cut_delta_mm || 0,
            uom: isFabricRole ? 'm' : (component.uom || 'ea'),
            sort_order: component.sort_order || component.sequence_order || 0,
            is_required: component.is_required !== false,
            auto_select: false,
          };
          
          const { error: updateError } = await supabase
            .from('BOMComponents')
            .update(updateData)
            .eq('id', component.id)
            .eq('organization_id', activeOrganizationId)
            .eq('bom_template_id', templateId);
          
          if (updateError) {
            const errorDetails = { 
              message: updateError.message, 
              code: updateError.code,
              details: updateError.details 
            };
            console.error('[handleSave] Error updating parent component:', component.id, errorDetails);
            throw new Error(`Error updating component ${component.id}: ${updateError.message}`);
          }
        }
      }
      
      if (childrenToUpdate.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Updating child components:', childrenToUpdate.length);
        }
        
        for (const component of childrenToUpdate) {
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          const finalComponentRole = normalizedComponentRole || component.component_role || null;
          const normalizedDependsOnRole = normalizeRole(component.depends_on_role || '');
          const finalDependsOnRole = normalizedDependsOnRole || component.depends_on_role || null;
          const isFabricRole = normalizedComponentRole === 'fabric';
          
          // Resolve parent_component_id: if it's a temp ID, look it up in the map
          let resolvedParentId = component.parent_component_id;
          if (resolvedParentId && String(resolvedParentId).startsWith('temp-')) {
            resolvedParentId = tempIdToRealIdMap.get(String(resolvedParentId)) || null;
            if (!resolvedParentId) {
              console.warn('[handleSave] Child component has temp parent ID that was not mapped:', component.id, component.parent_component_id);
              continue; // Skip this child if parent wasn't saved
            }
          }
          
          const updateData = {
            parent_component_id: resolvedParentId,
            component_item_id: component.component_item_id || null,
            component_role: finalComponentRole,
            qty_type: component.qty_type || 'fixed',
            qty_value: component.qty_value || 1,
            qty_delta_mm: component.qty_delta_mm || 0,
            waste_pct: component.waste_pct || 0,
            depends_on_role: finalDependsOnRole,
            cut_axis: component.cut_axis || null,
            cut_delta_mm: component.cut_delta_mm || 0,
            uom: isFabricRole ? 'm' : (component.uom || 'ea'),
            sort_order: component.sort_order || component.sequence_order || 0,
            is_required: component.is_required !== false,
            auto_select: false,
          };
          
          const { error: updateError } = await supabase
            .from('BOMComponents')
            .update(updateData)
            .eq('id', component.id)
            .eq('organization_id', activeOrganizationId)
            .eq('bom_template_id', templateId);
          
          if (updateError) {
            const errorDetails = { 
              message: updateError.message, 
              code: updateError.code,
              details: updateError.details 
            };
            console.error('[handleSave] Error updating child component:', component.id, errorDetails);
            throw new Error(`Error updating child component ${component.id}: ${updateError.message}`);
          }
        }
      }
      
      // 3) INSERTS: Crear componentes nuevos (id temp-)
      // First insert parents, then children (children need parent IDs)
      const parentsToInsert = parentComponents.filter(c => c.id.startsWith('temp-'));
      const childrenToInsert = childComponents.filter(c => c.id.startsWith('temp-'));
      
      if (parentsToInsert.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Creating parent components:', parentsToInsert.length);
        }
        
        for (const component of parentsToInsert) {
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          const finalComponentRole = normalizedComponentRole || component.component_role || null;
          const normalizedDependsOnRole = normalizeRole(component.depends_on_role || '');
          const finalDependsOnRole = normalizedDependsOnRole || component.depends_on_role || null;
          const isFabricRole = normalizedComponentRole === 'fabric';
          const tempId = component.id;
          
          const componentData = {
            bom_template_id: templateId,
            parent_component_id: null, // Parents always have null
            component_item_id: component.component_item_id || null,
            component_role: finalComponentRole,
            qty_type: component.qty_type || 'fixed',
            qty_value: component.qty_value || 1,
            qty_delta_mm: component.qty_delta_mm || 0,
            waste_pct: component.waste_pct || 0,
            depends_on_role: finalDependsOnRole,
            cut_axis: component.cut_axis || null,
            cut_delta_mm: component.cut_delta_mm || 0,
            uom: isFabricRole ? 'm' : (component.uom || 'ea'),
            is_required: component.is_required !== false,
            sort_order: component.sort_order || component.sequence_order || 0,
            auto_select: false,
          };
          
          const result = await createComponent(componentData);
          
          if (!result || !result.id) {
            throw new Error('Component creation returned no data or ID');
          }
          
          // Map temp ID to real ID for children resolution
          tempIdToRealIdMap.set(tempId, result.id);
        }
      }
      
      if (childrenToInsert.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Creating child components:', childrenToInsert.length);
        }
        
        for (const component of childrenToInsert) {
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          const finalComponentRole = normalizedComponentRole || component.component_role || null;
          const normalizedDependsOnRole = normalizeRole(component.depends_on_role || '');
          const finalDependsOnRole = normalizedDependsOnRole || component.depends_on_role || null;
          const isFabricRole = normalizedComponentRole === 'fabric';
          
          // Resolve parent_component_id: if it's a temp ID, look it up in the map
          let resolvedParentId = component.parent_component_id;
          if (resolvedParentId && String(resolvedParentId).startsWith('temp-')) {
            resolvedParentId = tempIdToRealIdMap.get(String(resolvedParentId)) || null;
            if (!resolvedParentId) {
              console.warn('[handleSave] Child component has temp parent ID that was not mapped, skipping:', component.id, component.parent_component_id);
              continue; // Skip this child if parent wasn't saved
            }
          }
          
          // Verify parent exists (either in our list or already in DB)
          if (resolvedParentId && !String(resolvedParentId).startsWith('temp-')) {
            // Check if parent is in our current list (to be updated or inserted)
            const parentInList = parentComponents.find(p => {
              const pId = String(p.id);
              const realId = pId.startsWith('temp-') ? tempIdToRealIdMap.get(pId) : pId;
              return String(realId) === String(resolvedParentId);
            });
            
            if (!parentInList) {
              // Parent should already exist in DB - verify it's a valid parent component
              // (We'll let the DB foreign key constraint handle validation)
              if (import.meta.env.DEV) {
                console.log('[handleSave] Child component parent ID from DB:', component.id, resolvedParentId);
              }
            }
          }
          
          const componentData = {
            bom_template_id: templateId,
            parent_component_id: resolvedParentId,
            component_item_id: component.component_item_id || null,
            component_role: finalComponentRole,
            qty_type: component.qty_type || 'fixed',
            qty_value: component.qty_value || 1,
            qty_delta_mm: component.qty_delta_mm || 0,
            waste_pct: component.waste_pct || 0,
            depends_on_role: finalDependsOnRole,
            cut_axis: component.cut_axis || null,
            cut_delta_mm: component.cut_delta_mm || 0,
            uom: isFabricRole ? 'm' : (component.uom || 'ea'),
            is_required: component.is_required !== false,
            sort_order: component.sort_order || component.sequence_order || 0,
            auto_select: false,
          };
          
          const result = await createComponent(componentData);
          
          if (!result) {
            throw new Error('Child component creation returned no data');
          }
        }
      }
      
      // ✅ Limpiar estado de deletions
      setComponentsToDelete([]);
      
      // ✅ Recargar desde DB para tener estado sincronizado (tanto para edit como create)
      const { data: refreshedComponents, error: refreshError } = await supabase
        .from('BOMComponents')
        .select(`
          *,
          component_item:component_item_id (
            id,
            sku,
            name
          )
        `)
        .eq('bom_template_id', templateId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .eq('archived', false)
        .order('parent_component_id', { ascending: true })
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: true });
      
      if (!refreshError && refreshedComponents) {
        const mappedComponents = (refreshedComponents as any[]).map((comp: any) => {
          // ✅ Clean catalog_item to avoid circular references
          const catalogItem = comp.component_item ? {
            id: comp.component_item.id,
            sku: comp.component_item.sku,
            name: comp.component_item.name,
          } : null;
          
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
            cut_axis: comp.cut_axis || null,
            cut_delta_mm: comp.cut_delta_mm || 0,
            uom: normalizeUom(comp.uom) || 'ea', // ✅ Normalize UOM
            sort_order: comp.sort_order || 0,
            sequence_order: comp.sort_order || 0,
            auto_select: false,
            catalog_item: catalogItem,
          };
        });
        
        // ✅ FIX: Deduplicación defensiva por ID (O(n))
        const uniqueById = Array.from(
          mappedComponents.reduce((acc: Map<string, any>, comp: any) => {
            acc.set(comp.id, comp);
            return acc;
          }, new Map<string, any>()).values()
        ) as any[];
        
        // ✅ SIEMPRE REEMPLAZAR estado, NUNCA merge
        setComponents(uniqueById);
        initialComponentsRef.current = uniqueById.map((c: any) => ({ ...c }));
        
        if (import.meta.env.DEV) {
          console.log('[handleSave] Components reloaded from DB:', mappedComponents.length);
        }
      } else if (refreshError) {
        if (import.meta.env.DEV) {
          // ✅ FIX: Formatear error para evitar "[circular]"
          const errorDetails = { 
            message: refreshError.message, 
            code: refreshError.code,
            details: refreshError.details 
          };
          console.warn('[handleSave] Error reloading components (non-critical):', errorDetails);
        }
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'BOM Template saved successfully.',
      });

      clearDraft(); // ✅ Limpiar draft al guardar exitosamente
      onSave();
    } catch (error) {
      // ✅ FIX: Formatear error para evitar "[circular]"
      const errorDetails = error instanceof Error 
        ? { message: error.message, name: error.name, stack: error.stack }
        : typeof error === 'object' && error !== null
        ? { message: (error as any).message || String(error), code: (error as any).code, details: (error as any).details }
        : String(error);
      console.error('Error saving BOM:', errorDetails);
      
      // Extract detailed error message from Supabase or other errors
      let errorMessage = 'Error saving BOM template';
      if (error instanceof Error) {
        errorMessage = error.message;
        } else if (error && typeof error === 'object') {
          // Handle Supabase PostgrestError
          if ('message' in error) {
            errorMessage = String((error as any).message);
          } else if ('details' in error) {
            errorMessage = `${(error as any).message || 'Database error'}: ${(error as any).details || ''}`;
          } else if ('hint' in error) {
            errorMessage = `${(error as any).message || 'Database error'}: ${(error as any).hint || ''}`;
          } else {
            // ✅ FIX: Evitar JSON.stringify de objetos circulares
            try {
              errorMessage = JSON.stringify(error, null, 2);
            } catch {
              errorMessage = `Error: ${(error as any).message || 'Unknown error'}`;
            }
          }
        } else if (error) {
        errorMessage = String(error);
      }
      
      // ✅ FIX: Extraer información de debugging para errores 23505
      let debugInfo = '';
      if (error && typeof error === 'object' && 'code' in error) {
        const errorCode = (error as any).code;
        if (errorCode === '23505') {
          // Extraer code del mensaje de error
          const codeMatch = errorMessage.match(/Code "([^"]+)"/);
          const idMatch = errorMessage.match(/ID: ([a-f0-9-]+)/);
          if (codeMatch || idMatch) {
            debugInfo = `\n\nDebug: Code="${codeMatch?.[1] || 'unknown'}"${idMatch ? `, Existing ID=${idMatch[1]}` : ''}`;
          } else {
            // Si no está en el mensaje, intentar extraer del error original
            const originalError = error instanceof Error ? error : (error as any);
            debugInfo = `\n\nDebug: Error code 23505 (duplicate key constraint)`;
          }
        }
      }

      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage + debugInfo,
      });
    }
  };

  const normalizeSearchTerm = (term: string): string => {
    return term
      .toLowerCase()
      .replace(/[-_\s]/g, '')
      .trim();
  };

  const filteredAndGroupedComponents = useMemo(() => {
    const searchTerm = componentSearchTerm.trim();
    const normalizedSearch = normalizeSearchTerm(searchTerm);
    
    const filtered = catalogItems.filter(item => {
      if (!item.id) return false;
      
      // When editing, allow the item being edited to appear in the list
      const isAlreadyAdded = components.some(c => {
        if (c.component_item_id === item.id) {
          if (editingComponentId && c.id === editingComponentId) {
            return false;
          }
          return true;
        }
        return false;
      });
      if (isAlreadyAdded) return false;
      
      if (selectedCategoryFilter && selectedCategoryFilter !== '__all__') {
        // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
        const itemCategoryId = item.category_id || item.item_category_id;
        if (itemCategoryId !== selectedCategoryFilter) {
          return false;
        }
      }
      
      if (searchTerm) {
        const sku = normalizeSearchTerm(item.sku || '');
        const name = normalizeSearchTerm(item.name || item.item_name || '');
        const description = normalizeSearchTerm(item.description || '');
        // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
        const categoryId = item.category_id || item.item_category_id;
        const category = categories.find(cat => cat.id === categoryId);
        const categoryName = normalizeSearchTerm(category?.name || '');
        const categoryCode = normalizeSearchTerm(category?.code || '');
        
        const skuOriginal = (item.sku || '').toLowerCase();
        const nameOriginal = (item.name || item.item_name || '').toLowerCase();
        const searchLower = searchTerm.toLowerCase();
        
        const matchesSearch = 
          sku.includes(normalizedSearch) || 
          name.includes(normalizedSearch) || 
          description.includes(normalizedSearch) ||
          categoryName.includes(normalizedSearch) ||
          categoryCode.includes(normalizedSearch) ||
          skuOriginal.includes(searchLower) ||
          nameOriginal.includes(searchLower) ||
          (item.description || '').toLowerCase().includes(searchLower) ||
          (category?.name || '').toLowerCase().includes(searchLower) ||
          (category?.code || '').toLowerCase().includes(searchLower);
        
        if (!matchesSearch) return false;
      }
      
      return true;
    });

    const groups = new Map<string | null, { category: any; items: any[] }>();
    
    filtered.forEach((item) => {
      // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
      const categoryId = item.category_id || item.item_category_id || null;
      const category = categories.find(cat => cat.id === categoryId);
      
      const categoryData = category || { 
        id: null, 
        name: 'Uncategorized', 
        code: null 
      };
      
      if (!groups.has(categoryId)) {
        groups.set(categoryId, {
          category: categoryData,
          items: [],
        });
      }
      groups.get(categoryId)!.items.push(item);
    });

    const sortedGroups = Array.from(groups.values()).sort((a, b) => {
      if (a.category.id === null && b.category.id !== null) return 1;
      if (b.category.id === null && a.category.id !== null) return -1;
      if (a.category.id === null && b.category.id === null) return 0;
      
      if (a.category.code && b.category.code) {
        return a.category.code.localeCompare(b.category.code);
      }
      if (a.category.code && !b.category.code) return -1;
      if (!a.category.code && b.category.code) return 1;
      
      return a.category.name.localeCompare(b.category.name);
    });

    sortedGroups.forEach(group => {
      group.items.sort((a, b) => {
        const nameA = (a.name || a.item_name || a.sku || '').toLowerCase();
        const nameB = (b.name || b.item_name || b.sku || '').toLowerCase();
        return nameA.localeCompare(nameB);
      });
    });

    return sortedGroups;
  }, [catalogItems, componentSearchTerm, selectedCategoryFilter, components, categories, editingComponentId]);

  if (!isOpen) return null;

  return (
    <div className={`fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center ${showChildrenModal ? 'pointer-events-none z-0' : ''}`}>
      <div className={`bg-white rounded-lg w-full h-full max-w-6xl m-4 overflow-hidden flex flex-col ${showChildrenModal ? 'pointer-events-auto' : ''}`}>
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              {editingTemplateId ? 'Edit BOM Template' : 'Add New BOM Template'}
            </h2>
            <p className="text-sm text-gray-500 mt-1">
              Configure the Bill of Materials for a Product Type
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded transition-colors text-gray-600"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-6 py-4">
          {/* Product Type Selection */}
          <div className="mb-6">
            <Label htmlFor="product_type" className="text-sm" required>
              Product Type
            </Label>
            <SelectShadcn
              value={productTypeId}
              onValueChange={setProductTypeId}
            >
              <SelectTrigger className="mt-1">
                <SelectValue placeholder="Select product type" />
              </SelectTrigger>
              <SelectContent>
                {productTypes.map((pt) => (
                  <SelectItem key={pt.id} value={pt.id}>
                    {pt.code} - {pt.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          {/* ✅ Template Code */}
          <div className="mb-6">
            <Label htmlFor="template_code" className="text-sm" required>
              Code
            </Label>
            <Input
              id="template_code"
              value={templateCode}
              onChange={(e) => setTemplateCode(e.target.value.toUpperCase().replace(/\s+/g, '_'))}
              className="mt-1"
              placeholder="ROLLER_MANUAL_BASIC_WHITE"
              required
            />
            <p className="text-xs text-gray-500 mt-1">Unique template code (e.g., ROLLER_MANUAL_BASIC_WHITE)</p>
          </div>

          {/* Template Name and Description */}
          <div className="mb-6 grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="template_name" className="text-sm">Template Name (Optional)</Label>
              <Input
                id="template_name"
                value={templateName}
                onChange={(e) => setTemplateName(e.target.value)}
                className="mt-1"
                placeholder="e.g., Standard BOM, Premium BOM"
              />
            </div>
            <div>
              <Label htmlFor="template_description" className="text-sm">Description (Optional)</Label>
              <Input
                id="template_description"
                value={templateDescription}
                onChange={(e) => setTemplateDescription(e.target.value)}
                className="mt-1"
                placeholder="Brief description"
              />
            </div>
          </div>

          {/* Hardware Color - REQUIRED */}
          <div className="mb-6">
            <Label htmlFor="template_hardware_color" className="text-sm" required>
              Hardware Color
            </Label>
            <SelectShadcn
              value={templateHardwareColor || ''}
              onValueChange={(value) => {
                setTemplateHardwareColor(value);
              }}
              required
            >
              <SelectTrigger className="mt-1">
                <SelectValue placeholder="Select hardware color (required)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="White">White</SelectItem>
                <SelectItem value="Black">Black</SelectItem>
                <SelectItem value="Silver">Silver</SelectItem>
                <SelectItem value="Bronze">Bronze</SelectItem>
                <SelectItem value="Grey">Grey</SelectItem>
              </SelectContent>
            </SelectShadcn>
            <p className="text-xs text-gray-500 mt-1">
              Select the hardware color (White, Black, etc.) to filter templates in the product configurator. Required field.
            </p>
          </div>

          {/* Paños / Panel count - same style as Hardware Color */}
          <div className="mb-6">
            <Label htmlFor="template_panel_count" className="text-sm" required>
              Paños / Panels
            </Label>
            <SelectShadcn
              value={String(templatePanelCount)}
              onValueChange={(value) => setTemplatePanelCount(Number(value) as 1 | 2 | 3)}
              required
            >
              <SelectTrigger className="mt-1">
                <SelectValue placeholder="Select number of panels (required)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="1">1 paño</SelectItem>
                <SelectItem value="2">2 paños</SelectItem>
                <SelectItem value="3">3 paños</SelectItem>
              </SelectContent>
            </SelectShadcn>
            <p className="text-xs text-gray-500 mt-1">
              Number of panels (paños) this template supports. Used to filter templates in the product configurator. Required field.
            </p>
          </div>

          {/* Components Section */}
          <div className="mb-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-semibold text-gray-900">Components</h3>
              {!showAddComponentForm && (
                <button
                  onClick={() => {
                    setShowAddComponentForm(true);
                    setEditingComponentId(null);
                    // ✅ MVP: Reset to MVP fields only
                    setFormData({
                      component_item_id: '',
                      component_role: '',
                      qty_type: 'fixed',
                      qty_value: null,
                      uom: 'ea',
                      sequence_order: components.length,
                      is_required: true,
                    });
                  }}
                  className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                >
                  <Plus className="w-4 h-4" />
                  Add Component
                </button>
              )}
            </div>

            {/* ✅ MVP: Add/Edit Component Form - Simplified (No Auto-Select) */}
            {showAddComponentForm && (
              <div
                onKeyDown={(e) => {
                  // ✅ FIX: Prevent Enter key from submitting form
                  if (e.key === 'Enter' && e.target instanceof HTMLInputElement) {
                    e.preventDefault();
                  }
                }}
              >
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
                <div className="grid grid-cols-12 gap-4">
                  {/* Filter by Category - Above the main fields row */}
                  <div className="col-span-12 mb-1">
                    <Label htmlFor="category_filter" className="text-xs text-gray-600 mb-0.5 block">
                      Filter by Category (Optional)
                    </Label>
                    <SelectShadcn
                      value={selectedCategoryFilter || '__all__'}
                      onValueChange={(value) => {
                        setSelectedCategoryFilter(value === '__all__' ? '' : value);
                        setShowComponentDropdown(true);
                      }}
                    >
                      <SelectTrigger className="h-9 w-full max-w-xs">
                        <SelectValue placeholder="All Categories" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="__all__">All Categories</SelectItem>
                        {leafCategories && leafCategories.length > 0 ? leafCategories.map((category) => (
                          category?.id ? (
                            <SelectItem key={category.id} value={category.id}>
                              {category.name}
                              {category.code && (
                                <span className="text-gray-500 ml-1">({category.code})</span>
                              )}
                            </SelectItem>
                          ) : null
                        )) : null}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                  
                  {/* ✅ MVP: Component Selector - Aligned with other fields */}
                  <div className="col-span-4">
                    <Label htmlFor="component_item_id" required className="mb-1.5">Component</Label>
                    <div className="relative" ref={componentInputRef}>
                      <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none z-10" />
                      <Input
                        ref={componentInputFieldRef}
                        type="text"
                        placeholder="Type SKU or name to search and select..."
                        value={componentSearchTerm}
                        onChange={(e) => {
                          const value = e.target.value;
                          setComponentSearchTerm(value);
                          setShowComponentDropdown(true);
                          setHighlightedIndex(-1);
                          // Clear component_item_id if user starts typing
                          if (value && formData.component_item_id) {
                            setFormData({ ...formData, component_item_id: '' });
                          }
                        }}
                        onFocus={() => {
                          if (flatFilteredItems.length > 0 || componentSearchTerm.trim()) {
                            setShowComponentDropdown(true);
                          }
                        }}
                        onKeyDown={handleKeyDown}
                        className="pl-8 pr-8 h-9"
                        autoComplete="off"
                      />
                      {componentSearchTerm && (
                        <button
                          onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            setFormData({ ...formData, component_item_id: '' });
                            setComponentSearchTerm('');
                            setShowComponentDropdown(false);
                            setHighlightedIndex(-1);
                            componentInputFieldRef.current?.focus();
                          }}
                          className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                          type="button"
                          title="Clear"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      )}

                      {/* Autocomplete Dropdown */}
                      {showComponentDropdown && (flatFilteredItems.length > 0 || componentSearchTerm.trim()) && (
                        <div className="absolute left-0 top-full mt-1 z-[100] w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-[300px] overflow-y-auto">
                          {flatFilteredItems.length > 0 ? (
                            <>
                              {/* Group by category */}
                              {filteredAndGroupedComponents.map((group) => {
                                if (!group.items || group.items.length === 0) return null;
                                
                                const groupKey = group.category.id || `uncategorized-${group.category.name}`;
                                // Get items from flatFilteredItems that belong to this group
                                const groupItems = flatFilteredItems.filter(item => {
                                  const catalogItem = catalogItems.find(ci => ci.id === item.id);
                                  // ✅ FIX: Use category_id (new schema) with fallback to item_category_id (legacy)
                                  const itemCategoryId = catalogItem?.category_id || catalogItem?.item_category_id || null;
                                  return itemCategoryId === group.category.id || 
                                         (!group.category.id && !itemCategoryId);
                                });
                                
                                if (groupItems.length === 0) return null;
                                
                                return (
                                  <div key={groupKey}>
                                    <div className="sticky top-0 bg-gray-50 border-b border-gray-200 px-3 py-1.5 flex items-center gap-2 z-10">
                                      <Folder className="w-3.5 h-3.5 text-gray-500 flex-shrink-0" />
                                      <span className="font-semibold text-gray-900 text-xs">
                                        {group.category.name}
                                      </span>
                                      {group.category.code && (
                                        <span className="text-gray-500 font-normal text-xs">({group.category.code})</span>
                                      )}
                                      <span className="text-gray-400 text-xs ml-auto">
                                        {groupItems.length} item{groupItems.length !== 1 ? 's' : ''}
                                      </span>
                                    </div>
                                    {groupItems.map((item) => {
                                      const globalIndex = flatFilteredItems.findIndex(fi => fi.id === item.id);
                                      const isHighlighted = globalIndex === highlightedIndex;
                                      const isSelected = formData.component_item_id === item.id;
                                      
                                      return (
                                        <button
                                          key={item.id}
                                          type="button"
                                          onClick={() => handleSelectComponent(item.id)}
                                          onMouseEnter={() => setHighlightedIndex(globalIndex)}
                                          className={`w-full text-left px-3 py-2 text-xs transition-colors border-b border-gray-100 last:border-b-0 ${
                                            isSelected
                                              ? 'bg-primary/10 text-primary font-medium'
                                              : isHighlighted
                                              ? 'bg-gray-100 text-gray-900'
                                              : 'text-gray-700 hover:bg-gray-50'
                                          }`}
                                        >
                                          <div className="flex items-center justify-between">
                                            <div className="flex-1 min-w-0">
                                              <div className="font-medium truncate">
                                                <span className="text-gray-900">{item.sku}</span>
                                                {item.sku && ' - '}
                                                <span className="text-gray-700">{item.name}</span>
                                              </div>
                                            </div>
                                            {isSelected && (
                                              <div className="ml-2 text-primary flex-shrink-0">
                                                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                                                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                                                </svg>
                                              </div>
                                            )}
                                          </div>
                                        </button>
                                      );
                                    })}
                                  </div>
                                );
                              })}
                            </>
                          ) : (
                            <div className="px-3 py-4 text-xs text-gray-500 text-center">
                              No components found matching "{componentSearchTerm}"
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* ✅ Component Role - Auto-filled from CatalogItems.item_role, visible but read-only */}
                  <div className="col-span-3">
                    <Label htmlFor="component_role" required className="mb-1.5">
                      Component Role
                      {formData.component_item_id && formData.component_role && (
                        <span className="text-xs text-gray-500 ml-2 font-normal">(auto from item)</span>
                      )}
                    </Label>
                    <Input
                      id="component_role"
                      value={formData.component_role || ''}
                      readOnly
                      className="h-9 bg-gray-50 cursor-not-allowed"
                      placeholder="Will auto-fill when component is selected"
                    />
                    {formData.component_item_id && !formData.component_role && (
                      <p className="text-xs text-amber-600 mt-1">
                        ⚠️ No item_role found for selected item. Please select a different component.
                      </p>
                    )}
                  </div>
                  
                  {/* ✅ MVP: Qty Type */}
                  <div className="col-span-2">
                    <Label htmlFor="qty_type" required className="mb-1.5">Qty Type</Label>
                    <SelectShadcn
                      value={formData.qty_type || 'fixed'}
                      onValueChange={(value) => {
                        setFormData({ 
                          ...formData, 
                          qty_type: value as BOMQtyType,
                          qty_value: value === 'fixed' ? (formData.qty_value || 1) : null
                        });
                      }}
                    >
                      <SelectTrigger className="h-9">
                        <SelectValue placeholder="Select type" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="fixed">Fixed</SelectItem>
                        <SelectItem value="per_width">Per Width</SelectItem>
                        <SelectItem value="per_height">Per Height</SelectItem>
                        <SelectItem value="per_area">Per Area</SelectItem>
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                  
                  {/* ✅ MVP: Qty Value (only if fixed) */}
                  {formData.qty_type === 'fixed' && (
                    <div className="col-span-2">
                      <Label htmlFor="qty_value" required className="mb-1.5">Qty Value</Label>
                      <Input
                        id="qty_value"
                        type="number"
                        step="1"
                        min="1"
                        value={formData.qty_value || ''}
                        onChange={(e) => {
                          const value = e.target.value === '' ? null : parseFloat(e.target.value);
                          setFormData({ ...formData, qty_value: value });
                        }}
                        placeholder="1"
                        className="h-9"
                      />
                    </div>
                  )}
                  
                  {/* ✅ MVP: UOM (always editable, but locked to 'm' for fabric role) */}
                  <div className="col-span-2">
                    <Label htmlFor="uom" required className="mb-1.5">UOM</Label>
                    <SelectShadcn
                      value={formData.uom || 'ea'}
                      onValueChange={(value) => {
                        // ✅ FIX: Prevent changing UOM if role='fabric' (must be 'm')
                        if (formData.component_role === 'fabric' && value !== 'm') {
                          useUIStore.getState().addNotification({
                            type: 'warning',
                            title: 'UOM Locked',
                            message: 'Fabric components must use UOM: m (linear meters)',
                          });
                          return;
                        }
                        setFormData({ ...formData, uom: value });
                      }}
                      disabled={formData.component_role === 'fabric'} // ✅ Lock UOM for fabric
                    >
                      <SelectTrigger className="h-9">
                        <SelectValue placeholder="Select UOM" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="ea">ea</SelectItem>
                        <SelectItem value="m">m</SelectItem>
                        <SelectItem value="m2">m²</SelectItem>
                      </SelectContent>
                    </SelectShadcn>
                    {formData.component_role === 'fabric' && (
                      <p className="text-xs text-gray-500 mt-1">Fabric uses linear meters (m)</p>
                    )}
                  </div>
                  
                  {/* ✅ FABRIC: Show roll_width_m reference and calculation preview */}
                  {formData.component_role === 'fabric' && formData.component_item_id && (() => {
                    const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);
                    const rollWidthM = selectedItem?.roll_width_m;
                    const isFabric = selectedItem?.is_fabric;
                    
                    return (
                      <div className="col-span-full mt-2 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                        <div className="text-xs">
                          <div className="font-medium text-blue-900 mb-1">Fabric Information</div>
                          {rollWidthM ? (
                            <div className="text-blue-700">
                              Roll Width: <span className="font-medium">{rollWidthM} m</span>
                            </div>
                          ) : (
                            <div className="text-blue-600 italic">
                              Roll width not set for this fabric item
                            </div>
                          )}
                          {isFabric && (
                            <div className="text-blue-600 text-xs mt-1">
                              Fabric consumption will be calculated in linear meters (m) based on product dimensions and roll width.
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })()}
                  <div className="col-span-2">
                    <Label htmlFor="sequence_order" className="mb-1.5">Order</Label>
                    <Input
                      id="sequence_order"
                      type="number"
                      value={formData.sequence_order}
                      onChange={(e) => setFormData({ ...formData, sequence_order: parseInt(e.target.value) || 0 })}
                      className="h-9"
                    />
                  </div>
                  <div className="col-span-1 flex items-end pb-0.5">
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        id="is_required"
                        checked={formData.is_required}
                        onChange={(e) => setFormData({ ...formData, is_required: e.target.checked })}
                        className="h-4 w-4"
                      />
                      <Label htmlFor="is_required" className="mb-0">Required</Label>
                    </div>
                  </div>
                </div>
                
                {/* ✅ MVP: Form Actions */}
                <div className="flex items-center gap-2 mt-3">
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      if (editingComponentId) {
                        handleUpdateComponent();
                      } else {
                        handleAddComponent();
                      }
                    }}
                    type="button"
                    className="px-3 py-1.5 text-xs bg-primary text-white rounded hover:opacity-90"
                  >
                    {editingComponentId ? 'Update' : 'Add'} Component
                  </button>
                  <button
                    onClick={resetForm}
                    type="button"
                    className="px-3 py-1.5 text-xs border border-gray-300 rounded hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                </div>
              </div>
              </div>
            )}

            {/* Components Grouped by Category */}
            {componentsByCategory.length === 0 ? (
              <div className="text-sm text-gray-500 py-8 text-center border border-gray-200 rounded-lg">
                No components added yet. Click "Add Component" to get started.
              </div>
            ) : (
              <div className="space-y-4">
                {componentsByCategory.map((categoryGroup) => (
                  <div key={categoryGroup.category_id || 'uncategorized'} className="border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-gray-50 border-b border-gray-200 px-4 py-2">
                      <div className="flex items-center gap-2">
                        <Folder className="w-4 h-4 text-gray-500" />
                        <span className="text-xs font-semibold text-gray-900">
                          {categoryGroup.category_name}
                        </span>
                        {categoryGroup.category_code && (
                          <span className="text-xs text-gray-500">
                            ({categoryGroup.category_code})
                          </span>
                        )}
                      </div>
                    </div>

                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead className="bg-gray-50 border-b border-gray-200">
                          <tr>
                            <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">Component</th>
                            <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Qty/Unit</th>
                            <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">
                              <div className="flex items-center gap-1.5">
                                UOM
                                <TooltipProvider>
                                  <Tooltip
                                    content="UOM of the component as defined by supplier. Final BOM quantities are normalized automatically."
                                    side="top"
                                  >
                                    <TooltipTrigger asChild>
                                      <Info className="w-3.5 h-3.5 text-gray-400 hover:text-gray-600 cursor-help" />
                                    </TooltipTrigger>
                                  </Tooltip>
                                </TooltipProvider>
                              </div>
                            </th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Role</th>
                            <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">Children</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Condition</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Color</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Order</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Required</th>
                            <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {categoryGroup.components.map((component) => {
                            const componentItem = catalogItems.find(item => item.id === component.component_item_id) || component.catalog_item;
                            // ✅ Resolve qty display: show qty_type + qty_value format
            const qtyDisplay = component.qty_type === 'fixed' 
              ? (component.qty_value || 1)
                              : component.qty_type === 'per_width'
                                ? 'per_width'
                                : component.qty_type === 'per_height'
                                  ? 'per_height'
                                  : component.qty_type === 'per_area'
                                    ? 'per_area'
                                    : '-';
                            
                            return (
                              <tr key={component.id} className="hover:bg-gray-50">
                                {/* 1. Component (SKU + Name) */}
                                <td className="py-2 px-4 text-xs text-gray-900">
                                  {componentItem ? (
                                    <>
                                      <div className="font-medium">{componentItem.name || componentItem.item_name || 'Unknown'}</div>
                                      <div className="text-gray-500 text-xs mt-0.5">
                                        SKU: {componentItem.sku || 'N/A'}
                                      </div>
                                    </>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                {/* 2. Qty/Unit (qty_type + qty_value) */}
                                <td className="py-2 px-4 text-xs text-gray-700 text-right">
                                  {typeof qtyDisplay === 'number' 
                                    ? qtyDisplay 
                                    : <span className="text-gray-500 italic">{qtyDisplay}</span>}
                                </td>
                                {/* 3. UOM (actual uom value, NOT qty_type) */}
                                <td className="py-2 px-4 text-xs text-center">
                                  <span className="text-gray-700">
                                    {(component.uom !== null && component.uom !== undefined && component.uom !== '') 
                                      ? component.uom 
                                      : (componentItem?.unit_of_measure || componentItem?.uom || 'ea')}
                                  </span>
                                </td>
                                {/* 4. Role */}
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.component_role ? (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                      {getRoleLabel(component.component_role)}
                                    </span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                {/* 5. Children */}
                                <td className="py-2 px-4 text-xs text-gray-700">
                                  {(() => {
                                    const parentId = component.id;
                                    const children = parentId ? (childrenByParent[parentId] || []) : [];
                                    if (!children.length) return <span className="text-gray-400">—</span>;

                                    const preview = children.slice(0, 3).map((child: any) => {
                                      const item = child.catalog_item || catalogItems.find(ci => ci.id === child.component_item_id);
                                      const sku = item?.sku || child.component_item_id || 'N/A';
                                      const qty = child.qty_value || 1;
                                      const uom = child.uom || 'ea';
                                      return `${sku} (${qty} ${uom})`;
                                    });
                                    const remaining = children.length - preview.length;

                                    return (
                                      <span>
                                        {preview.join(', ')}
                                        {remaining > 0 ? ` +${remaining}` : ''}
                                      </span>
                                    );
                                  })()}
                                </td>
                                {/* 6. Condition */}
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.block_condition ? (
                                    <span className="text-gray-700">{String(component.block_condition)}</span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                {/* 7. Color (resolve from hardware_color or color_id if exists) */}
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.hardware_color ? (
                                    <span className="text-gray-700">{String(component.hardware_color)}</span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                {/* 8. Order/Priority */}
                                <td className="py-2 px-4 text-xs text-gray-700 text-center">
                                  {component.sort_order || component.sequence_order || 0}
                                </td>
                                {/* 9. Required (checkmark here) */}
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.is_required !== false ? (
                                    <span className="text-green-600 font-bold">✓</span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                <td className="py-2 px-4 text-right">
                                  <div className="flex items-center gap-1 justify-end">
                                    <button
                                      onClick={(e) => {
                                        e.preventDefault();
                                        e.stopPropagation();
                                        handleEditComponent(component);
                                      }}
                                      className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                      title="Edit component"
                                      type="button"
                                    >
                                      <Edit className="w-4 h-4" />
                                    </button>
                                    <button
                                      onClick={() => handleOpenEngineeringModal(component.id)}
                                      className="p-1.5 hover:bg-blue-100 rounded transition-colors text-blue-600"
                                      title="Engineering rules"
                                      type="button"
                                    >
                                      <Settings className="w-4 h-4" />
                                    </button>
                                    <button
                                      onClick={() => handleOpenChildrenModal(component.id)}
                                      className="p-1.5 hover:bg-green-100 rounded transition-colors text-green-600 disabled:opacity-40 disabled:cursor-not-allowed"
                                      title="Manage child components (adapters, end caps, screws, etc)"
                                      type="button"
                                      disabled={!component.component_item_id}
                                    >
                                      <Package className="w-4 h-4" />
                                    </button>
                                    <button
                                      onClick={() => {
                                        handleDeleteComponent(component);
                                      }}
                                      className="p-1.5 hover:bg-red-100 rounded transition-colors text-red-600"
                                      title="Delete component"
                                      type="button"
                                    >
                                      <Trash2 className="w-4 h-4" />
                                    </button>
                                  </div>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50">
          <button
            onClick={() => {
              clearDraft(); // ✅ Limpiar draft al cancelar
              onClose();
            }}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => {
              handleSave();
            }}
            disabled={isCreating || isUpdating || !productTypeId || components.length === 0}
            className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isCreating || isUpdating ? 'Saving...' : 'Save BOM Template'}
          </button>
        </div>
      </div>

      {/* Engineering Rules Modal */}
      {showEngineeringModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg w-full max-w-md m-4 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Engineering Rules</h3>
              <button
                onClick={() => {
                  setShowEngineeringModal(false);
                  setEditingEngineeringComponentId(null);
                  setEngineeringData({
                    depends_on_role: '',
                    cut_axis: 'none',
                    cut_delta_mm: null,
                    cut_delta_scope: 'none',
                  });
                }}
                className="p-1 hover:bg-gray-100 rounded transition-colors text-gray-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <div className="space-y-4">
              <div>
                <Label htmlFor="cut_axis" className="text-xs">Cut Axis</Label>
                <SelectShadcn
                  value={engineeringData.cut_axis || 'none'}
                  onValueChange={(value) => {
                    const newCutAxis = value as 'length' | 'width' | 'height' | 'none';
                    setEngineeringData({ 
                      ...engineeringData, 
                      cut_axis: newCutAxis,
                      depends_on_role: newCutAxis === 'none' ? '' : engineeringData.depends_on_role
                    });
                  }}
                >
                  <SelectTrigger className="py-1 text-xs mt-1">
                    <SelectValue placeholder="Select axis" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">— None —</SelectItem>
                    <SelectItem value="length">Length</SelectItem>
                    <SelectItem value="width">Width</SelectItem>
                    <SelectItem value="height">Height</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>
              
              <div>
                <Label htmlFor="depends_on_role" className="text-xs">Depends on Role</Label>
                <SelectShadcn
                  value={engineeringData.depends_on_role || 'none'}
                  onValueChange={(value) => {
                    if (value !== 'none' && !isValidRole(value)) {
                      useUIStore.getState().addNotification({
                        type: 'error',
                        title: 'Invalid Role',
                        message: `Invalid depends_on_role: "${value}". Please select a valid role from the dropdown.`,
                      });
                      return;
                    }
                    setEngineeringData({ ...engineeringData, depends_on_role: value === 'none' ? '' : value });
                  }}
                  disabled={engineeringData.cut_axis === 'none' || !engineeringData.cut_axis}
                >
                  <SelectTrigger className="py-1 text-xs mt-1">
                    <SelectValue placeholder={engineeringData.cut_axis === 'none' || !engineeringData.cut_axis ? "Select cut axis first" : "Select role"} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">— None —</SelectItem>
                    {CANONICAL_COMPONENT_ROLES.map((role) => (
                      <SelectItem key={role} value={role}>
                        {role}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                <p className="text-xs text-gray-500 mt-1">
                  {engineeringData.cut_axis === 'none' || !engineeringData.cut_axis 
                    ? 'Select a cut axis first to enable this field' 
                    : 'Role that this component depends on'}
                </p>
              </div>
              
              <div>
                <Label htmlFor="cut_delta_mm" className="text-xs">Delta (mm)</Label>
                <Input
                  id="cut_delta_mm"
                  type="number"
                  step="0.01"
                  value={engineeringData.cut_delta_mm || ''}
                  onChange={(e) => setEngineeringData({ ...engineeringData, cut_delta_mm: e.target.value ? parseFloat(e.target.value) : null })}
                  className="py-1 text-xs mt-1"
                  placeholder="0.00"
                />
                <p className="text-xs text-gray-500 mt-1">Adjustment in millimeters (positive or negative)</p>
              </div>
              
              <div>
                <Label htmlFor="cut_delta_scope" className="text-xs">Delta Scope</Label>
                <SelectShadcn
                  value={engineeringData.cut_delta_scope || 'none'}
                  onValueChange={(value) => setEngineeringData({ ...engineeringData, cut_delta_scope: value as 'per_side' | 'per_item' | 'none' })}
                >
                  <SelectTrigger className="py-1 text-xs mt-1">
                    <SelectValue placeholder="Select scope" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">None</SelectItem>
                    <SelectItem value="per_item">Per Item</SelectItem>
                    <SelectItem value="per_side">Per Side (applied twice)</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>
            </div>
            
            <div className="flex items-center justify-end gap-3 mt-6">
              <button
                onClick={() => {
                  setShowEngineeringModal(false);
                  setEditingEngineeringComponentId(null);
                  setEngineeringData({
                    depends_on_role: '',
                    cut_axis: 'none',
                    cut_delta_mm: null,
                    cut_delta_scope: 'none',
                  });
                }}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveEngineeringRules}
                className="px-4 py-2 text-sm font-medium text-white rounded-lg transition-colors"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ✅ REHECHO: Modal para gestionar HIJOS (Child Components) - Versión limpia */}
      {showChildrenModal && editingParentComponentId && (
        <div 
          className="fixed inset-0 bg-black/50 z-[9999] flex items-center justify-center p-4"
          style={{ pointerEvents: 'auto' }}
          onClick={(e) => {
            // Cerrar modal si se hace click en el overlay (no en el contenido)
            if (e.target === e.currentTarget) {
              handleCloseChildrenModal();
            }
          }}
        >
          <div 
            className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col"
            style={{ pointerEvents: 'auto' }}
            onClick={(e) => {
              // Prevenir que clicks dentro del modal se propaguen al overlay
              e.stopPropagation();
            }}
          >
            {/* Header */}
            <div className="flex items-center justify-between p-4 border-b">
              <div>
                <h3 className="text-lg font-semibold">Manage Child Components</h3>
                <p className="text-sm text-gray-500 mt-1">
                  Add adapters, end caps, screws, and other parts that come with this SKU
                </p>
              </div>
              <button
                type="button"
                onClick={handleCloseChildrenModal}
                className="p-1 hover:bg-gray-100 rounded transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Body */}
            <div className="flex-1 overflow-y-auto p-6 space-y-4" style={{ pointerEvents: 'auto' }}>
              {loadingChildren ? (
                <div className="text-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
                  <p className="text-sm text-gray-600">Loading children...</p>
                </div>
              ) : (
                <>
                  {/* Botón para agregar nuevo hijo */}
                  {!showAddChildForm ? (
                    <div style={{ pointerEvents: 'auto', position: 'relative', zIndex: 1 }}>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault();
                          e.stopPropagation();
                          
                          if (import.meta.env.DEV) {
                            console.log('[BOMTemplates] Add Child Button clicked');
                          }
                          
                          // Resetear todo primero
                          setEditingChildId(null);
                          setChildFormData({
                            child_item_id: '',
                            child_role: '',
                            qty: 1,
                            uom: 'ea',
                            required: true,
                            notes: '',
                          });
                          setChildSearchTerm('');
                          setShowChildDropdown(false);
                          
                          // Luego mostrar formulario
                          setShowAddChildForm(true);
                        }}
                        className="w-full px-4 py-3 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary hover:bg-primary/5 transition-colors text-sm text-gray-600 hover:text-primary flex items-center justify-center gap-2 cursor-pointer"
                        style={{ pointerEvents: 'auto', position: 'relative', zIndex: 10 }}
                      >
                        <Plus className="w-4 h-4" />
                        Add Child Component
                      </button>
                      <div className="text-xs text-gray-400 mt-1 text-center" style={{ pointerEvents: 'none' }}>
                        Click to add a new child component
                      </div>
                    </div>
                  ) : null}

                  {/* Formulario para agregar/editar HIJO */}
                  {showAddChildForm ? (
                    <div className="border border-gray-200 rounded-lg p-4 bg-gray-50 space-y-3">
                      <div className="flex items-center justify-between mb-3">
                        <h4 className="text-sm font-semibold">
                          {editingChildId ? 'Edit Child Component' : 'Add Child Component'}
                        </h4>
                        <button
                          type="button"
                          onClick={() => {
                            setShowAddChildForm(false);
                            setEditingChildId(null);
                            setChildFormData({
                              child_item_id: '',
                              child_role: '',
                              qty: 1,
                              uom: 'ea',
                              required: true,
                              notes: '',
                            });
                            setChildSearchTerm('');
                            setShowChildDropdown(false);
                          }}
                          className="text-gray-400 hover:text-gray-600"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>

                      <div className="grid grid-cols-2 gap-3">
                        {/* Child Component Selector */}
                        <div>
                          <Label className="text-xs mb-1">Child Component *</Label>
                          <div className="relative">
                            <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 w-3.5 h-3.5 text-gray-400 pointer-events-none z-10" />
                            <Input
                              data-child-input
                              type="text"
                              placeholder="Search SKU or name..."
                              value={childSearchTerm}
                              onChange={(e) => {
                                setChildSearchTerm(e.target.value);
                                setShowChildDropdown(true);
                                if (e.target.value && childFormData.child_item_id) {
                                  setChildFormData({ ...childFormData, child_item_id: '', child_role: '' });
                                }
                              }}
                              onFocus={() => setShowChildDropdown(true)}
                              onKeyDown={(e) => {
                                if (e.key === 'Escape') {
                                  setShowChildDropdown(false);
                                }
                              }}
                              className="pl-8 h-8 text-xs"
                            />
                            {showChildDropdown && catalogItems.length > 0 && (
                              <div data-child-dropdown className="absolute left-0 top-full mt-1 z-[110] w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                                <div className="flex items-center justify-between px-3 py-1.5 border-b border-gray-200 bg-gray-50 sticky top-0">
                                  <span className="text-xs font-medium text-gray-700">Select component</span>
                                  <button
                                    type="button"
                                    onClick={() => setShowChildDropdown(false)}
                                    className="p-0.5 hover:bg-gray-200 rounded transition-colors text-gray-500 hover:text-gray-700"
                                    title="Close dropdown"
                                  >
                                    <X className="w-3.5 h-3.5" />
                                  </button>
                                </div>
                                {catalogItems
                                  .filter(item => {
                                    if (!item || item.deleted) return false;
                                    if (!childSearchTerm) return true;
                                    const searchLower = childSearchTerm.toLowerCase();
                                    return (
                                      item.sku?.toLowerCase().includes(searchLower) ||
                                      item.name?.toLowerCase().includes(searchLower) ||
                                      (item as any).item_name?.toLowerCase().includes(searchLower)
                                    );
                                  })
                                  .slice(0, 50)
                                  .map((item) => {
                                    const mappedChildRole = mapChildRoleFromItemRole((item as any).item_role);
                                    return (
                                      <button
                                        key={item.id}
                                        type="button"
                                        onClick={() => {
                                          setChildFormData({ 
                                            ...childFormData, 
                                            child_item_id: item.id,
                                            child_role: mappedChildRole || childFormData.child_role || '',
                                            uom: item.unit_of_measure || item.uom || 'ea'
                                          });
                                          setChildSearchTerm(`${item.sku || 'N/A'} - ${item.name || (item as any).item_name || 'Unknown'}`);
                                          setShowChildDropdown(false);
                                        }}
                                        className="w-full text-left px-3 py-2 text-xs hover:bg-gray-100 border-b border-gray-100 last:border-b-0"
                                      >
                                        <div className="font-medium">{item.sku || 'N/A'}</div>
                                        <div className="text-gray-500 text-xs">{item.name || (item as any).item_name || 'Unknown'}</div>
                                        {mappedChildRole && (
                                          <div className="text-gray-400 text-xs mt-0.5">Role: {mappedChildRole}</div>
                                        )}
                                      </button>
                                    );
                                  })}
                                {catalogItems.filter(item => {
                                  if (!item || item.deleted) return false;
                                  if (!childSearchTerm) return true;
                                  const searchLower = childSearchTerm.toLowerCase();
                                  return (
                                    item.sku?.toLowerCase().includes(searchLower) ||
                                    item.name?.toLowerCase().includes(searchLower) ||
                                    (item as any).item_name?.toLowerCase().includes(searchLower)
                                  );
                                }).length === 0 && (
                                  <div className="px-3 py-2 text-xs text-gray-500 text-center">
                                    No items found
                                  </div>
                                )}
                              </div>
                            )}
                          </div>
                        </div>

                        {/* Child Role */}
                        <div>
                          <Label className="text-xs mb-1">Child Role *</Label>
                          <SelectShadcn
                            value={childFormData.child_role}
                            onValueChange={(value) => setChildFormData({ ...childFormData, child_role: value })}
                          >
                            <SelectTrigger className="h-8 text-xs">
                              <SelectValue placeholder="Select role" />
                            </SelectTrigger>
                            <SelectContent>
                              {/* ✅ FIX: Solo roles canónicos válidos como child roles (desde VALID_CHILD_ROLES) */}
                              {VALID_CHILD_ROLES.map((role) => {
                                const label = getSubRoleLabel(role) || getRoleLabel(role);
                                return (
                                  <SelectItem key={role} value={role}>
                                    {label}
                                  </SelectItem>
                                );
                              })}
                            </SelectContent>
                          </SelectShadcn>
                        </div>


                        {/* Qty */}
                        <div>
                          <Label className="text-xs mb-1">Quantity *</Label>
                          <Input
                            type="number"
                            min="1"
                            step="1"
                            value={childFormData.qty}
                            onChange={(e) => setChildFormData({ ...childFormData, qty: parseFloat(e.target.value) || 1 })}
                            className="h-8 text-xs"
                          />
                        </div>

                        {/* UOM */}
                        <div>
                          <Label className="text-xs mb-1">UOM *</Label>
                          <SelectShadcn
                            value={childFormData.uom}
                            onValueChange={(value) => setChildFormData({ ...childFormData, uom: value })}
                          >
                            <SelectTrigger className="h-8 text-xs">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="ea">ea (Each)</SelectItem>
                              <SelectItem value="pcs">pcs (Pieces)</SelectItem>
                              <SelectItem value="set">set</SelectItem>
                              <SelectItem value="m">m (Meters)</SelectItem>
                            </SelectContent>
                          </SelectShadcn>
                        </div>
                      </div>

                      <div className="flex items-center justify-end gap-2 mt-4">
                        <button
                          onClick={() => {
                            setShowAddChildForm(false);
                            setEditingChildId(null);
                            setChildFormData({
                              child_item_id: '',
                              child_role: '',
                              qty: 1,
                              uom: 'ea',
                              required: true,
                              notes: '',
                            });
                            setChildSearchTerm('');
                          }}
                          className="px-3 py-1.5 text-xs border border-gray-300 rounded hover:bg-gray-50"
                        >
                          Cancel
                        </button>
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            
                            if (import.meta.env.DEV) {
                              console.log('[Add Child Button] Form submit clicked:', {
                                child_item_id: childFormData.child_item_id,
                                child_role: childFormData.child_role,
                                editingParentComponentId,
                                hasOrganization: !!activeOrganizationId,
                              });
                            }
                            
                            if (!childFormData.child_item_id) {
                              useUIStore.getState().addNotification({
                                type: 'error',
                                title: 'Validation Error',
                                message: 'Please select a child component (SKU)',
                              });
                              return;
                            }
                            
                            if (!childFormData.child_role) {
                              useUIStore.getState().addNotification({
                                type: 'error',
                                title: 'Validation Error',
                                message: 'Please select a child role',
                              });
                              return;
                            }
                            
                            try {
                              await handleAddChild();
                            } catch (err) {
                              if (import.meta.env.DEV) {
                                console.error('[Add Child Button] Error in handleAddChild:', err);
                              }
                            }
                          }}
                          className="px-3 py-1.5 text-xs bg-primary text-white rounded hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
                          disabled={!childFormData.child_item_id || !childFormData.child_role}
                        >
                          {editingChildId ? 'Update Child' : 'Add Child'}
                        </button>
                      </div>
                    </div>
                  ) : null}

                  {/* Lista de HIJOS - Versión limpia */}
                  {childComponents.length > 0 && (
                    <div className="space-y-2 mt-4">
                      <div className="flex items-center justify-between mb-2">
                        <h4 className="text-sm font-semibold text-gray-700">
                          Children ({childComponents.length})
                        </h4>
                      </div>
                      {childComponents.map((child) => {
                        // Validar que child.id existe
                        if (!child?.id) {
                          if (import.meta.env.DEV) {
                            console.warn('[BOMTemplates] Child without ID, skipping:', {
                              component_item_id: child?.component_item_id,
                              component_role: child?.component_role,
                            });
                          }
                          return null;
                        }
                        
                        const childId = String(child.id);
                        const childItem = (child.catalog_item || child.child_item || catalogItems.find(item => item.id === child.component_item_id)) as any;
                        const childItemId = child.component_item_id;
                        const childName = childItem?.name || childItem?.item_name || 'Unknown';
                        const childSku = childItem?.sku || childItemId || 'N/A';
                        const childRole = child.component_role || 'N/A';
                        const childQty = child.qty_value || child.qty || 1;
                        const childUom = child.uom || 'ea';
                        
                        return (
                          <div 
                            key={childId} 
                            className="flex items-center justify-between p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                          >
                            <div className="flex-1 min-w-0">
                              <div className="font-medium text-sm text-gray-900 truncate">
                                {childName}
                              </div>
                            <div className="text-xs text-gray-500 mt-1">
                              SKU: {childSku} • Role: {childRole} • Qty: {childQty} {childUom}
                            </div>
                            </div>
                            <div className="flex items-center gap-2 ml-4 flex-shrink-0">
                              {/* Botón Editar */}
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.preventDefault();
                                  e.stopPropagation();
                                  
                                  if (!childId) {
                                    useUIStore.getState().addNotification({
                                      type: 'error',
                                      title: 'Error',
                                      message: 'Child component ID is missing',
                                    });
                                    return;
                                  }
                                  
                                  setEditingChildId(childId);
                                  setShowAddChildForm(true);
                                  setChildFormData({
                                    child_item_id: childItemId || '',
                                    child_role: childRole !== 'N/A' ? childRole : '',
                                    qty: childQty,
                                    uom: childUom,
                                    required: child.is_required !== false,
                                    notes: child.notes || '',
                                  });
                                  setChildSearchTerm(
                                    childItem
                                      ? `${childSku} - ${childName}`
                                      : ''
                                  );
                                  setShowChildDropdown(false);
                                }}
                                className="p-1.5 hover:bg-blue-100 rounded transition-colors text-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
                                title="Edit child component"
                              >
                                <Edit className="w-4 h-4" />
                              </button>
                              
                              {/* Botón Eliminar */}
                              <button
                                type="button"
                                onClick={async (e) => {
                                  e.preventDefault();
                                  e.stopPropagation();
                                  
                                  if (!childId) {
                                    useUIStore.getState().addNotification({
                                      type: 'error',
                                      title: 'Error',
                                      message: 'Child component ID is missing',
                                    });
                                    return;
                                  }
                                  
                                  if (!window.confirm(`Delete "${childName}" (${childSku})?`)) {
                                    return;
                                  }
                                  
                                  if (!activeOrganizationId) {
                                    useUIStore.getState().addNotification({
                                      type: 'error',
                                      title: 'Error',
                                      message: 'No organization selected',
                                    });
                                    return;
                                  }
                                  
                                  try {
                                    if (!childId.startsWith('temp-')) {
                                      const { error: deleteError } = await supabase
                                        .from('BOMComponents')
                                        .update({
                                          deleted: true,
                                          updated_at: new Date().toISOString(),
                                        })
                                        .eq('id', childId)
                                        .eq('organization_id', activeOrganizationId);

                                      if (deleteError) {
                                        throw deleteError;
                                      }
                                    }

                                    setComponents(prev => prev.filter(c => String(c.id) !== childId));
                                    setChildComponents(prev => prev.filter(c => String(c.id) !== childId));

                                    if (editingChildId === childId) {
                                      setEditingChildId(null);
                                      setShowAddChildForm(false);
                                      setChildFormData({
                                        child_item_id: '',
                                        child_role: '',
                                        qty: 1,
                                        uom: 'ea',
                                        required: true,
                                        notes: '',
                                      });
                                      setChildSearchTerm('');
                                    }

                                    useUIStore.getState().addNotification({
                                      type: 'success',
                                      title: 'Success',
                                      message: 'Child component deleted successfully',
                                    });
                                  } catch (err: any) {
                                    useUIStore.getState().addNotification({
                                      type: 'error',
                                      title: 'Error',
                                      message: err?.message || 'Failed to delete child component',
                                    });
                                  }
                                }}
                                className="p-1.5 hover:bg-red-100 rounded transition-colors text-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
                                title="Delete child component"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                  
                  {/* Mensaje cuando no hay hijos */}
                  {!showAddChildForm && childComponents.length === 0 && (
                    <div className="text-center py-8 text-gray-500 text-sm">
                      No child components yet. Click "Add Child Component" to add one.
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Footer */}
            <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50">
              <button
                type="button"
                onClick={handleCloseChildrenModal}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
