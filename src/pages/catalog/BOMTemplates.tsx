import { useState, useEffect, useMemo, useRef } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Plus, Edit, Trash2, Search, Wrench, Info, Settings, Package, CheckCircle } from 'lucide-react';
import Label from '../../components/ui/Label';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue, SelectGroup, SelectLabel } from '../../components/ui/SelectShadcn';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useCatalogItems, useItemCategories, useLeafItemCategories } from '../../hooks/useCatalog';
import { useBOMCRUD, useBOMComponents } from '../../hooks/useBOM';
import { useBOMTemplates, useBOMTemplateCRUD } from '../../hooks/useBOMTemplates';
import { Folder, X } from 'lucide-react';
import { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider } from '../../components/ui/Tooltip';
import { CANONICAL_COMPONENT_ROLES, normalizeRole, normalizeSubRole, isValidRole, isValidSubRole, getRoleLabel, getSubRoleLabel, getSubRolesForRole, hasSubRoles } from '../../lib/bom/roles';
import { getValidUomOptions, normalizeMeasureBasis, normalizeUom } from '../../lib/uom';
import { calculateFabricLinearM, getFabricCalculationPreview } from '../../lib/bom/fabric-calculations';

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
const isUomReadonlyForComponent = (role: string | null | undefined, selectionMode: 'fixed' | 'auto_select' | undefined): boolean => {
  // Always readonly - UOM comes from CatalogItems.uom at BOM generation time
  return true;
};

interface BOMTemplate {
  id: string;
  product_type_id: string;
  name?: string;
  template_name?: string;
  description?: string;
  active: boolean;
  created_at: string;
  updated_at: string;
  ProductType?: {
    id: string;
    name: string;
    code: string;
  };
}

// ✅ FIX: Shared constants for bom_qty_type enum (must match DB enum exactly)
export const BOM_QTY_TYPES = ['fixed', 'per_width', 'per_area'] as const;
export type BOMQtyType = typeof BOM_QTY_TYPES[number];

type SKUResolutionRule = 'EXACT_SKU' | 'SKU_SUFFIX_COLOR' | 'ROLE_AND_COLOR' | 'CATEGORY_FIRST_MATCH' | string;
type HardwareColor = 'none' | 'white' | 'black' | 'silver' | 'bronze' | 'grey' | string;

interface BOMComponent {
  id: string;
  bom_template_id: string;
  component_role?: string;
  component_sub_role?: string; // Optional sub-role for granularity (e.g., hardware: fastener, end_cap, adapter)
  component_item_id?: string;
  qty_per_unit: number;
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
  selection_mode?: 'fixed' | 'auto_select'; // UI field (derived from auto_select)
  sequence_order: number;
  affects_role?: string;
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
  const [showTemplateModal, setShowTemplateModal] = useState(false);
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(null);

  // Register Catalog submodules when BOMTemplates component mounts
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
        { id: 'bom-readiness', label: 'BOM Readiness', href: '/catalog/bom-readiness', icon: CheckCircle },
      ]);
    }
  }, [registerSubmodules]);

  // Load product types
  useEffect(() => {
    const loadProductTypes = async () => {
      if (!activeOrganizationId) return;
      try {
        const { data, error } = await supabase
          .from('ProductTypes')
          .select('id, name, code')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .is('archived', null)
          .order('name');
        
        if (error) throw error;
        setProductTypes(data || []);
      } catch (err) {
        console.error('Error loading product types:', err);
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

        const { data, error } = await supabase
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
          .eq('deleted', false)
          .order('created_at', { ascending: false });

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
          const templateIds = data.map(t => t.id);
          // ✅ FIX: No usar join relacional (PGRST200) - traer plano y resolver en memoria
          const { data: componentsData, error: componentsError } = await supabase
            .from('BOMComponents')
            .select('*') // ✅ Solo campos de BOMComponents, sin join
            .in('bom_template_id', templateIds)
            .eq('deleted', false)
            .order('sequence_order', { ascending: true });

          // ✅ FIX: Handle 404/400 errors gracefully
          if (componentsError) {
            if (componentsError.code === 'PGRST116' || componentsError.code === '42P01' || 
                componentsError.message?.includes('does not exist')) {
              if (import.meta.env.DEV) {
                console.warn('[BOMTemplates] Components fetch error (not retrying):', componentsError.code, componentsError.message);
              }
              setComponents(new Map()); // Set empty map on expected errors
            } else {
              console.error('[BOMTemplates] Unexpected error fetching components:', componentsError);
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
    return templates.filter(t => 
      t.template_name?.toLowerCase().includes(searchLower) ||
      t.description?.toLowerCase().includes(searchLower) ||
      t.ProductType?.name.toLowerCase().includes(searchLower)
    );
  }, [templates, searchTerm]);

  const handleNewTemplate = () => {
    setEditingTemplateId(null);
    setShowTemplateModal(true);
  };

  const handleEditTemplate = (templateId: string) => {
    setEditingTemplateId(templateId);
    setShowTemplateModal(true);
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
        .update({ deleted: true })
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
            return (
              <div key={template.id} className="bg-white border border-gray-200 rounded-lg p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <h3 className="text-lg font-semibold text-gray-900">
                        {(template.name || template.template_name) || template.ProductType?.name || 'BOM Template'}
                      </h3>
                      <span className={`px-2 py-1 text-xs rounded ${
                        template.active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                      }`}>
                        {template.active ? 'Active' : 'Inactive'}
                      </span>
                    </div>
                    <p className="text-sm text-gray-600 mb-2">
                      Product Type: {template.ProductType?.name || 'N/A'}
                    </p>
                    {template.description && (
                      <p className="text-sm text-gray-500">{template.description}</p>
                    )}
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
                          {comp.qty_per_unit > 1 && ` (x${comp.qty_per_unit})`}
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
            setShowTemplateModal(false);
            setEditingTemplateId(null);
          }}
          onSave={() => {
            setShowTemplateModal(false);
            setEditingTemplateId(null);
            // Reload templates
            window.location.reload();
          }}
          editingTemplateId={editingTemplateId}
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
function BOMModal({ isOpen, onClose, onSave, editingTemplateId }: {
  isOpen: boolean;
  onClose: () => void;
  onSave: () => void;
  editingTemplateId: string | null;
}) {
  const { activeOrganizationId } = useOrganizationContext();
  const { productTypes } = useProductTypes();
  const { items: catalogItems } = useCatalogItems();
  const { categories } = useItemCategories();
  const { categories: leafCategories = [] } = useLeafItemCategories();
  const { createTemplate, updateTemplate, isCreating, isUpdating } = useBOMTemplateCRUD();
  const { createComponent, updateComponent } = useBOMCRUD();
  const { components: existingComponents } = useBOMComponents(editingTemplateId || null);

  const [productTypeId, setProductTypeId] = useState<string>('');
  const [templateCode, setTemplateCode] = useState<string>(''); // ✅ Template code (unique)
  const [templateName, setTemplateName] = useState<string>('');
  const [templateDescription, setTemplateDescription] = useState<string>('');
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
    affects_role: '',
    cut_axis: 'none' as 'length' | 'width' | 'height' | 'none',
    cut_delta_mm: null as number | null,
    cut_delta_scope: 'none' as 'per_side' | 'per_item' | 'none',
  });
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

  // Load template data if editing
  useEffect(() => {
    if (editingTemplateId && activeOrganizationId) {
      supabase
        .from('BOMTemplates')
        .select('*')
        .eq('id', editingTemplateId)
        .single()
        .then(({ data, error }) => {
          if (!error && data) {
            setProductTypeId(data.product_type_id);
            setTemplateCode(data.code || ''); // ✅ Load code
            setTemplateName(data.name || data.template_name || '');
            setTemplateDescription(data.description || '');
            // ✅ Backend still saves metadata (as {}), but UI doesn't use it
          }
        });
    } else if (!editingTemplateId) {
      // ✅ Reset completo cuando no hay template
      setProductTypeId('');
      setTemplateCode('');
      setTemplateName('');
      setTemplateDescription('');
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
        component_item_id: comp.component_item_id,
        component_role: comp.component_role || null,
        qty_type: comp.qty_type || 'fixed',
        qty_value: comp.qty_value || (comp.qty_type === 'fixed' ? comp.qty_per_unit : null),
        qty_per_unit: comp.qty_per_unit || (comp.qty_type === 'fixed' ? comp.qty_value || 1 : 1),
        uom: comp.uom || 'ea',
        sequence_order: comp.sequence_order || 0,
        is_required: comp.is_required !== false,
        auto_select: false, // ✅ MVP: siempre false
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

  // Group components by block_type (new BOM structure) or category (fallback)
  const componentsByCategory = useMemo(() => {
    console.log('🔍 Grouping components. Total components:', components?.length || 0);
    if (!components || components.length === 0) {
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
    
    components.forEach((component: any) => {
      const componentItem = catalogItems.find(item => item.id === component.component_item_id);
      
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
  }, [components, catalogItems, categories]);

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
        if (item.item_category_id !== selectedCategoryFilter) {
          return false;
        }
      }

      // Search filter
      if (normalizedSearch) {
        const itemSku = (item.sku || '').toLowerCase().replace(/[-_\s]/g, '');
        const itemName = (item.name || item.item_name || '').toLowerCase().replace(/[-_\s]/g, '');
        const itemDesc = (item.description || '').toLowerCase().replace(/[-_\s]/g, '');
        const category = categories.find(c => c.id === item.item_category_id);
        const categoryName = (category?.name || '').toLowerCase().replace(/[-_\s]/g, '');
        const categoryCode = (category?.code || '').toLowerCase().replace(/[-_\s]/g, '');
        
        if (!itemSku.includes(normalizedSearch) && 
            !itemName.includes(normalizedSearch) && 
            !itemDesc.includes(normalizedSearch) &&
            !categoryName.includes(normalizedSearch) &&
            !categoryCode.includes(normalizedSearch)) {
          return false;
        }
      }

      return true;
    });

    // Group by category and create flat list
    const categoryMap = new Map<string | null, { category: any; items: any[] }>();
    
    filtered.forEach((item) => {
      const categoryId = item.item_category_id || null;
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
    
    // ✅ FIX: For fabrics, force UOM to 'm' (linear meters)
    const isFabric = selectedItem?.is_fabric || false;
    const isFabricRole = formData.component_role === 'fabric';
    const shouldUseMeters = isFabric || isFabricRole;
    const catalogUom = shouldUseMeters ? 'm' : (selectedItem?.uom || 'ea');
    
    setFormData({ 
      ...formData, 
      component_item_id: itemId,
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

  // ✅ MVP: Simplified handleAddComponent - only MVP fields
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
    
    // ✅ MVP: Build component with only MVP fields
    const newComponent = {
      id: `temp-${crypto.randomUUID()}`,
      component_item_id: formData.component_item_id,
      component_role: normalizedRole,
      qty_type: finalQtyType,
      qty_value: finalQtyType === 'fixed' ? formData.qty_value : null,
      qty_formula_code: isFabricRole ? 'FABRIC_LINEAR_M' : null, // ✅ Set formula for fabric
      qty_formula_params: isFabricRole ? { 
        roll_width_m: selectedItem?.roll_width_m || null,
        allowance_m: 0.1, // Default allowance
      } : null,
      uom: finalUom, // ✅ Normalized UOM (forced 'm' for fabric)
      sequence_order: formData.sequence_order ?? 0,
      is_required: formData.is_required ?? true,
      auto_select: false, // ✅ MVP: Always false
    };
    
    setComponents([...components, newComponent]);
    resetForm();
    
    useUIStore.getState().addNotification({
      type: 'success',
      title: 'Success',
      message: 'Component added successfully.',
    });
  };

  // ✅ MVP: Simplified handleUpdateComponent - only MVP fields
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

    // ✅ FIX: UPDATE by id - never insert when editing
    if (!editingTemplateId || !activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Template ID or Organization ID missing. Cannot update component.',
      });
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

    try {
      // ✅ FIX: For fabric role, ensure UOM is 'm' and set qty_type/formula
      const isFabricRole = normalizedRole === 'fabric';
      const normalizedUom = isFabricRole ? 'm' : (normalizeUom(formData.uom) || 'ea');
      const finalQtyType = isFabricRole && formData.qty_type === 'fixed' 
        ? 'per_area' // ✅ Fabric should use formula, not fixed
        : formData.qty_type;
      
      const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);
      
      const updateData = {
        component_item_id: formData.component_item_id,
        component_role: normalizedRole,
        qty_type: finalQtyType,
        qty_value: finalQtyType === 'fixed' ? formData.qty_value : null,
        qty_per_unit: finalQtyType === 'fixed' ? (formData.qty_value || 1) : 1,
        qty_formula_code: isFabricRole ? 'FABRIC_LINEAR_M' : null, // ✅ Set formula for fabric
        qty_formula_params: isFabricRole ? { 
          roll_width_m: selectedItem?.roll_width_m || null,
          allowance_m: 0.1, // Default allowance
        } : null,
        uom: normalizedUom, // ✅ Normalized UOM (forced 'm' for fabric)
        sequence_order: formData.sequence_order ?? 0,
        is_required: formData.is_required ?? true,
        auto_select: false,
      };

      if (import.meta.env.DEV) {
        console.log('[handleUpdateComponent] Updating component:', {
          componentId: editingComponentId,
          originalUom: formData.uom,
          normalizedUom,
          updateData,
        });
      }

      // ✅ FIX: UPDATE by BOMComponent.id (not catalog_item_id) - NEVER INSERT
      await updateComponent(editingComponentId, updateData);

      // ✅ FIX: Recargar desde DB para asegurar estado sincronizado (igual que en handleSave)
      if (editingTemplateId) {
        const { data: refreshedComponents, error: refreshError } = await supabase
          .from('BOMComponents')
          .select('*')
          .eq('bom_template_id', editingTemplateId)
          .eq('deleted', false)
          .order('sequence_order', { ascending: true });
        
        if (!refreshError && refreshedComponents) {
          const mappedComponents = refreshedComponents.map((comp: any) => ({
            id: comp.id,
            component_item_id: comp.component_item_id,
            component_role: comp.component_role || null,
            qty_type: comp.qty_type || 'fixed',
            qty_value: comp.qty_value || (comp.qty_type === 'fixed' ? comp.qty_per_unit : null),
            qty_per_unit: comp.qty_per_unit || (comp.qty_type === 'fixed' ? comp.qty_value || 1 : 1),
            uom: normalizeUom(comp.uom) || 'ea', // ✅ Normalize UOM from DB
            sequence_order: comp.sequence_order || 0,
            is_required: comp.is_required !== false,
            auto_select: false,
          }));
          
          // ✅ Deduplicación defensiva por ID
          const uniqueById = Array.from(
            mappedComponents.reduce((acc, comp) => {
              acc.set(comp.id, comp);
              return acc;
            }, new Map<string, any>()).values()
          );
          
          setComponents(uniqueById);
          initialComponentsRef.current = uniqueById.map(c => ({ ...c }));
          
          if (import.meta.env.DEV) {
            console.log('[handleUpdateComponent] Components reloaded from DB:', {
              componentId: editingComponentId,
              updatedUom: uniqueById.find(c => c.id === editingComponentId)?.uom,
              totalComponents: uniqueById.length,
            });
          }
        } else if (refreshError) {
          console.warn('[handleUpdateComponent] Error reloading components (non-critical):', refreshError);
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
      
      resetForm();

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Component updated successfully.',
      });
    } catch (error) {
      console.error('[handleUpdateComponent] Error updating component:', error);
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

  // ✅ FIX: Borrado solo local - se confirma en save
  const handleDeleteComponent = (componentId: string) => {
    if (componentId.startsWith('temp-')) {
      // ✅ Componente temporal: solo remover de lista
      setComponents(components.filter(c => c.id !== componentId));
    } else {
      // ✅ Componente real: remover de lista y marcar para borrado
      setComponents(components.filter(c => c.id !== componentId));
      setComponentsToDelete(prev => [...prev, componentId]);
    }
    
    if (import.meta.env.DEV) {
      console.log('[BOMTemplates] Component deleted locally:', {
        componentId,
        isTemp: componentId.startsWith('temp-'),
        componentsToDeleteCount: componentId.startsWith('temp-') ? componentsToDelete.length : componentsToDelete.length + 1,
      });
    }
  };

  // ✅ MVP: Simplified handleEditComponent - only MVP fields
  const handleEditComponent = (component: any) => {
    const componentItemId = component.component_item_id || '';
    const componentItem = catalogItems.find(item => item.id === componentItemId);
    const displayText = componentItem ? `${componentItem.sku} - ${componentItem.name || componentItem.item_name || 'Unnamed'}` : '';
    
    // ✅ FIX: Ensure UOM is properly initialized from component (prioritize component.uom)
    // Normalize UOM from component (lowercase, trim)
    // For fabric role, force UOM to 'm'
    const isFabricRole = component.component_role === 'fabric';
    const componentUomNormalized = isFabricRole ? 'm' : normalizeUom(component.uom);
    const fallbackUom = isFabricRole ? 'm' : (normalizeUom(componentItem?.uom) || 'ea');
    const finalUom = componentUomNormalized || fallbackUom;
    
    if (import.meta.env.DEV) {
      console.log('[handleEditComponent] Initializing form:', {
        componentId: component.id,
        componentUom: component.uom,
        componentUomNormalized,
        componentItemUom: componentItem?.uom,
        fallbackUom,
        finalUom,
      });
    }
    
    setEditingComponentId(component.id);
    setFormData({
      component_item_id: componentItemId,
      component_role: component.component_role || '',
      qty_type: component.qty_type || 'fixed',
      qty_value: component.qty_type === 'fixed' ? (component.qty_value || component.qty_per_unit || 1) : null,
      uom: finalUom, // ✅ FIX: Use normalized UOM
      sequence_order: component.sequence_order || 0,
      is_required: component.is_required ?? true,
    });
    setShowAddComponentForm(true);
    setComponentSearchTerm(displayText);
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
        affects_role: (cutAxis === 'none' || !cutAxis) ? '' : (component.affects_role || ''),
        cut_axis: cutAxis,
        cut_delta_mm: component.cut_delta_mm || null,
        cut_delta_scope: component.cut_delta_scope || 'none',
      });
      setShowEngineeringModal(true);
    }
  };

  const handleSaveEngineeringRules = () => {
    if (!editingEngineeringComponentId) return;
    
    const finalAffectsRole = (engineeringData.cut_axis === 'none' || !engineeringData.cut_axis) 
      ? null 
      : normalizeRole(engineeringData.affects_role);
    
    setComponents(components.map(c => {
      if (c.id === editingEngineeringComponentId) {
        return {
          ...c,
          affects_role: finalAffectsRole,
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
      affects_role: '',
      cut_axis: 'none',
      cut_delta_mm: null,
      cut_delta_scope: 'none',
    });
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
      
      // Validate affects_role
      if (component.affects_role && component.affects_role.trim() !== '') {
        if (!isValidRole(component.affects_role)) {
          if (isLegacyFromDB) {
            legacyComponents.push(`Component ${componentIndex}: legacy affects_role "${component.affects_role}" (migrate to canonical)`);
          } else {
            invalidComponents.push(`Component ${componentIndex}: invalid affects_role "${component.affects_role}"`);
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
      
      // ✅ FIX: Save template first, then components
      if (editingTemplateId) {
        await updateTemplate(editingTemplateId, {
          code: templateCode.trim(),
          name: templateName || null,
          description: templateDescription || null,
          metadata: {},
        } as any);
        templateId = editingTemplateId;
      } else {
        const newTemplate = await createTemplate({
          product_type_id: productTypeId,
          code: templateCode.trim(),
          name: templateName || null,
          description: templateDescription || null,
          metadata: {},
        } as any);
        templateId = newTemplate.id;
      }

      // ✅ FIX: Save flow determinístico - deletions, updates, inserts en orden
      const componentsToDeleteSet = new Set(componentsToDelete);
      
      // 1) DELETIONS: Borrar componentes marcados para borrado
      if (componentsToDelete.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Deleting components:', componentsToDelete);
        }
        
        const { error: deleteError } = await supabase
          .from('BOMComponents')
          .update({ deleted: true })
          .in('id', componentsToDelete)
          .eq('bom_template_id', templateId);
        
        if (deleteError) {
          console.error('[handleSave] Error deleting components:', deleteError);
          throw new Error(`Error deleting components: ${deleteError.message}`);
        }
      }
      
      // 2) UPDATES: Actualizar componentes existentes (id real y NO en componentsToDelete)
      const componentsToUpdate = components.filter(
        c => !c.id.startsWith('temp-') && !componentsToDeleteSet.has(c.id)
      );
      
      if (componentsToUpdate.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Updating components:', componentsToUpdate.length);
        }
        
        for (const component of componentsToUpdate) {
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          
          // ✅ FIX: Include formula fields for fabric components
          const isFabricRole = normalizedComponentRole === 'fabric';
          const selectedItem = catalogItems.find(item => item.id === component.component_item_id);
          
          const updateData = {
            component_item_id: component.component_item_id || null,
            component_role: normalizedComponentRole || null,
            qty_type: component.qty_type || 'fixed',
            qty_value: component.qty_type === 'fixed' ? (component.qty_value || component.qty_per_unit || 1) : null,
            qty_per_unit: component.qty_per_unit || (component.qty_type === 'fixed' ? (component.qty_value || 1) : 1),
            qty_formula_code: isFabricRole ? (component.qty_formula_code || 'FABRIC_LINEAR_M') : (component.qty_formula_code || null),
            qty_formula_params: isFabricRole ? (component.qty_formula_params || { 
              roll_width_m: selectedItem?.roll_width_m || null,
              allowance_m: 0.1,
            }) : (component.qty_formula_params || null),
            uom: isFabricRole ? 'm' : (component.uom || 'ea'), // ✅ Force 'm' for fabric
            sequence_order: component.sequence_order || 0,
            is_required: component.is_required !== false,
            auto_select: false,
          };
          
          const { error: updateError } = await supabase
            .from('BOMComponents')
            .update(updateData)
            .eq('id', component.id)
            .eq('bom_template_id', templateId);
          
          if (updateError) {
            console.error('[handleSave] Error updating component:', component.id, updateError);
            throw new Error(`Error updating component ${component.id}: ${updateError.message}`);
          }
        }
      }
      
      // 3) INSERTS: Crear componentes nuevos (id temp-)
      const componentsToInsert = components.filter(c => c.id.startsWith('temp-'));
      
      if (componentsToInsert.length > 0) {
        if (import.meta.env.DEV) {
          console.log('[handleSave] Creating components:', componentsToInsert.length);
        }
        
        for (const component of componentsToInsert) {
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          
          // ✅ FIX: Include formula fields for fabric components
          const isFabricRole = normalizedComponentRole === 'fabric';
          const selectedItem = catalogItems.find(item => item.id === component.component_item_id);
          
          const componentData = {
            bom_template_id: templateId,
            component_item_id: component.component_item_id || null,
            component_role: normalizedComponentRole || null,
            qty_type: component.qty_type || 'fixed',
            qty_value: component.qty_type === 'fixed' ? (component.qty_value || component.qty_per_unit || 1) : null,
            qty_per_unit: component.qty_per_unit || (component.qty_type === 'fixed' ? (component.qty_value || 1) : 1),
            qty_formula_code: isFabricRole ? (component.qty_formula_code || 'FABRIC_LINEAR_M') : (component.qty_formula_code || null),
            qty_formula_params: isFabricRole ? (component.qty_formula_params || { 
              roll_width_m: selectedItem?.roll_width_m || null,
              allowance_m: 0.1,
            }) : (component.qty_formula_params || null),
            uom: isFabricRole ? 'm' : (component.uom || 'ea'), // ✅ Force 'm' for fabric
            sequence_order: component.sequence_order || 0,
            is_required: component.is_required !== false,
            auto_select: false,
          };
          
          const result = await createComponent(componentData);
          
          if (!result) {
            throw new Error('Component creation returned no data');
          }
        }
      }
      
      // ✅ Limpiar estado de deletions
      setComponentsToDelete([]);
      
      // ✅ Recargar desde DB para tener estado sincronizado (tanto para edit como create)
      const { data: refreshedComponents, error: refreshError } = await supabase
        .from('BOMComponents')
        .select('*')
        .eq('bom_template_id', templateId)
        .eq('deleted', false)
        .order('sequence_order', { ascending: true });
      
      if (!refreshError && refreshedComponents) {
        const mappedComponents = refreshedComponents.map((comp: any) => ({
          id: comp.id,
          component_item_id: comp.component_item_id,
          component_role: comp.component_role || null,
          qty_type: comp.qty_type || 'fixed',
          qty_value: comp.qty_value || (comp.qty_type === 'fixed' ? comp.qty_per_unit : null),
          qty_per_unit: comp.qty_per_unit || (comp.qty_type === 'fixed' ? comp.qty_value || 1 : 1),
          qty_formula_code: comp.qty_formula_code || null, // ✅ Include formula code
          qty_formula_params: comp.qty_formula_params || null, // ✅ Include formula params
          uom: normalizeUom(comp.uom) || 'ea', // ✅ Normalize UOM
          sequence_order: comp.sequence_order || 0,
          is_required: comp.is_required !== false,
          auto_select: false,
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
        initialComponentsRef.current = uniqueById.map(c => ({ ...c }));
        
        if (import.meta.env.DEV) {
          console.log('[handleSave] Components reloaded from DB:', mappedComponents.length);
        }
      } else if (refreshError) {
        if (import.meta.env.DEV) {
          console.warn('[handleSave] Error reloading components (non-critical):', refreshError);
        }
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'BOM Template saved successfully.',
      });

      onSave();
    } catch (error) {
      console.error('Error saving BOM:', error);
      
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
            errorMessage = JSON.stringify(error, null, 2);
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
        if (item.item_category_id !== selectedCategoryFilter) {
          return false;
        }
      }
      
      if (searchTerm) {
        const sku = normalizeSearchTerm(item.sku || '');
        const name = normalizeSearchTerm(item.name || item.item_name || '');
        const description = normalizeSearchTerm(item.description || '');
        const categoryId = item.item_category_id;
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
      const categoryId = item.item_category_id || null;
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
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
      <div className="bg-white rounded-lg w-full h-full max-w-6xl m-4 overflow-hidden flex flex-col">
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
              disabled={!!editingTemplateId}
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
                        <div className="absolute left-0 top-full mt-1 z-50 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-[300px] overflow-y-auto">
                          {flatFilteredItems.length > 0 ? (
                            <>
                              {/* Group by category */}
                              {filteredAndGroupedComponents.map((group) => {
                                if (!group.items || group.items.length === 0) return null;
                                
                                const groupKey = group.category.id || `uncategorized-${group.category.name}`;
                                // Get items from flatFilteredItems that belong to this group
                                const groupItems = flatFilteredItems.filter(item => {
                                  const catalogItem = catalogItems.find(ci => ci.id === item.id);
                                  const itemCategoryId = catalogItem?.item_category_id || null;
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
                                              <div className="text-gray-500 text-xs mt-0.5">
                                                UOM: {item.uom}
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

                  {/* ✅ MVP: Component Role - Always Required */}
                  <div className="col-span-3">
                    <Label htmlFor="component_role" required className="mb-1.5">
                      Component Role
                    </Label>
                    <SelectShadcn
                      value={formData.component_role || ''}
                      onValueChange={(value) => {
                        const newRole = value === 'none' ? '' : value;
                        // ✅ FIX: When role='fabric', force UOM to 'm'
                        const newUom = newRole === 'fabric' ? 'm' : formData.uom;
                        setFormData({ 
                          ...formData, 
                          component_role: newRole,
                          uom: newUom
                        });
                      }}
                    >
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder="Selecciona el role" />
                    </SelectTrigger>
                    <SelectContent>
                      {CANONICAL_COMPONENT_ROLES.map((role) => (
                        <SelectItem key={role} value={role}>
                          {getRoleLabel(role)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                    </SelectShadcn>
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
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Condition</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Color</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Order</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Required</th>
                            <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {categoryGroup.components.map((component) => {
                            const componentItem = catalogItems.find(item => item.id === component.component_item_id);
                            // ✅ Resolve qty display: show qty_type + qty_value format
                            const qtyDisplay = component.qty_type === 'fixed' 
                              ? (component.qty_value || component.qty_per_unit || 1)
                              : component.qty_type === 'per_width'
                                ? 'per_width'
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
                                      : (componentItem?.uom || 'ea')}
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
                                {/* 5. Condition */}
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.block_condition ? (
                                    <span className="text-gray-700">{String(component.block_condition)}</span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                {/* 6. Color (resolve from hardware_color or color_id if exists) */}
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.hardware_color ? (
                                    <span className="text-gray-700">{String(component.hardware_color)}</span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                {/* 7. Order/Priority */}
                                <td className="py-2 px-4 text-xs text-gray-700 text-center">
                                  {component.sequence_order || 0}
                                </td>
                                {/* 8. Required (checkmark here) */}
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
                                      onClick={() => handleDeleteComponent(component.id)}
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
            onClick={onClose}
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
                    affects_role: '',
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
                      affects_role: newCutAxis === 'none' ? '' : engineeringData.affects_role
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
                <Label htmlFor="affects_role" className="text-xs">Affects Role</Label>
                <SelectShadcn
                  value={engineeringData.affects_role || 'none'}
                  onValueChange={(value) => {
                    if (value !== 'none' && !isValidRole(value)) {
                      useUIStore.getState().addNotification({
                        type: 'error',
                        title: 'Invalid Role',
                        message: `Invalid affects_role: "${value}". Please select a valid role from the dropdown.`,
                      });
                      return;
                    }
                    setEngineeringData({ ...engineeringData, affects_role: value === 'none' ? '' : value });
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
                    : 'Target role this component affects'}
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
                    affects_role: '',
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
    </div>
  );
}
