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
import { getValidUomOptions, normalizeMeasureBasis } from '../../lib/uom';

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

const getRoleHelperText = (role: string | null | undefined): string => {
  if (!role) return '';
  const normalized = normalizeRole(role);
  if (!normalized) return '';
  
  const helperTexts: Record<string, string> = {
    bracket: 'Soporte o bracket del sistema',
    tube: 'Tubo/barra principal del sistema',
    cassette: 'Cassette del sistema',
    side_channel: 'Canal lateral',
    bottom_bar: 'Barra inferior',
    bottom_rail: 'Riel inferior',
    top_rail: 'Riel superior',
    drive_manual: 'Sistema de control manual',
    drive_motorized: 'Motor o sistema motorizado',
    operating_system: 'Sistema operativo (cadena, etc.)',
    end_cap: 'Tapa o terminación',
    hardware: 'Herrajes y accesorios',
    fabric: 'Tela/textil',
  };
  
  return helperTexts[normalized] || '';
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
  return validUoms.length > 0 ? validUoms[0] : 'm';
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

type BOMQtyType = 'fixed' | 'per_width' | 'per_area' | 'by_option';
type SKUResolutionRule = 'EXACT_SKU' | 'SKU_SUFFIX_COLOR' | 'ROLE_AND_COLOR' | string;
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
    const loadTemplates = async () => {
      if (!activeOrganizationId) {
        setLoading(false);
        return;
      }

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

        if (error) throw error;
        setTemplates(data || []);

        // Load components for each template
        if (data && data.length > 0) {
          const templateIds = data.map(t => t.id);
          const { data: componentsData, error: componentsError } = await supabase
            .from('BOMComponents')
            .select(`
              *,
              CatalogItems:component_item_id (
                id,
                sku,
                item_name
              )
            `)
            .in('bom_template_id', templateIds)
            .eq('deleted', false)
            .order('sequence_order', { ascending: true });

          if (!componentsError && componentsData) {
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
  const { createComponent } = useBOMCRUD();
  const { components: existingComponents } = useBOMComponents(editingTemplateId || null);

  const [productTypeId, setProductTypeId] = useState<string>('');
  const [templateName, setTemplateName] = useState<string>('');
  const [templateDescription, setTemplateDescription] = useState<string>('');
  const [components, setComponents] = useState<any[]>([]);
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
  const [formData, setFormData] = useState<{
    component_item_id: string;
    component_role: string;
    component_sub_role?: string | null;
    qty_per_unit: number;
    uom: string;
    is_required: boolean;
    sequence_order: number;
    selection_mode?: 'fixed' | 'auto_select';
    hardware_color?: HardwareColor | null;
    sku_resolution_rule?: SKUResolutionRule | null;
    select_rule?: Record<string, any> | null;
    block_condition?: Record<string, any> | null;
    qty_type?: BOMQtyType | null;
    qty_value?: number | null;
    applies_color?: boolean;
    _original_component_item_id?: string; // Preserve original component_item_id when switching modes
  }>({
    component_item_id: '',
    component_role: '',
    component_sub_role: null,
    qty_per_unit: 1,
    uom: 'ea',
    is_required: true,
    sequence_order: 0,
    selection_mode: 'fixed',
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
            setTemplateName(data.name || data.template_name || '');
            setTemplateDescription(data.description || '');
          }
        });
    } else if (!editingTemplateId) {
      setProductTypeId('');
      setTemplateName('');
      setTemplateDescription('');
      setComponents([]);
    }
  }, [editingTemplateId, activeOrganizationId]);

  // Update UOM for tube component when productTypeId, component_role, or selection_mode changes
  // NOTE: measure_basis is not currently in ProductTypes table, so UOM calculation for tube is deferred
  // For now, UOM will default to 'm' for tube components in auto_select mode
  useEffect(() => {
    if (productTypeId && formData.component_role === 'tube' && (formData.selection_mode || 'fixed') === 'auto_select') {
      // TODO: When measure_basis is added to ProductTypes or determined from CatalogItems,
      // calculate UOM from measure_basis. For now, default to 'm' (meters)
      if (formData.uom !== 'm') {
        setFormData(prev => ({ ...prev, uom: 'm' }));
      }
    }
  }, [productTypeId, productTypes, formData.component_role, formData.selection_mode, formData.uom]);

  // Load existing components when template is loaded
  useEffect(() => {
    if (editingTemplateId && existingComponents && Array.isArray(existingComponents)) {
      console.log('📦 Loading existing components:', existingComponents.length, 'components');
      console.log('📦 Components data:', existingComponents);
      const mappedComponents = existingComponents.map((comp: any) => {
        // Convert auto_select (boolean) to selection_mode ('fixed' | 'auto_select')
        const selectionMode: 'fixed' | 'auto_select' = comp.auto_select === true ? 'auto_select' : 'fixed';
        
        return {
          ...comp,
          id: comp.id,
          component_role: comp.component_role || null,
          component_sub_role: comp.component_sub_role || null,
          auto_select: comp.auto_select || false, // Preserve auto_select field for DB
          selection_mode: selectionMode, // Add selection_mode for UI
          affects_role: comp.affects_role || null,
          cut_axis: comp.cut_axis || 'none',
          cut_delta_mm: comp.cut_delta_mm || null,
          cut_delta_scope: comp.cut_delta_scope || 'none',
          qty_per_unit: Math.round(comp.qty_per_unit || 1),
          // Preserve auto-select fields
          hardware_color: comp.hardware_color || null,
          sku_resolution_rule: comp.sku_resolution_rule || null,
          select_rule: comp.select_rule || null,
          block_condition: comp.block_condition || null,
          qty_type: comp.qty_type || null,
          qty_value: comp.qty_value || null,
          applies_color: comp.applies_color || false,
        };
      });
      console.log('📦 Mapped components:', mappedComponents.length, 'components');
      setComponents(mappedComponents);
    } else if (!editingTemplateId) {
      setComponents([]);
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
    const catalogUom = selectedItem?.uom || 'ea';
    const displayText = selectedItem ? `${selectedItem.sku} - ${selectedItem.name || selectedItem.item_name || 'Unnamed'}` : '';
    
    setFormData({ 
      ...formData, 
      component_item_id: itemId,
      uom: catalogUom
    });
    setComponentSearchTerm(displayText);
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  };

  // Update search term when component is selected (for display)
  useEffect(() => {
    if (formData.component_item_id && !showComponentDropdown) {
      const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);
      if (selectedItem) {
        // Don't update if user is typing
        if (!componentInputFieldRef.current || document.activeElement !== componentInputFieldRef.current) {
          setComponentSearchTerm(`${selectedItem.sku} - ${selectedItem.name || selectedItem.item_name || 'Unnamed'}`);
        }
      }
    }
  }, [formData.component_item_id, catalogItems, showComponentDropdown]);

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

  const handleAddComponent = () => {
    // Validation
    if (formData.selection_mode === 'fixed' && !formData.component_item_id) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Please select a component.',
      });
      return;
    }

    // Component role is always required
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

    const newComponent = {
      ...formData,
      component_item_id: formData.selection_mode === 'fixed' ? formData.component_item_id : null,
      component_role: normalizeRole(formData.component_role || ''),
      component_sub_role: normalizeSubRole(formData.component_sub_role || null),
      qty_per_unit: Math.round(formData.qty_per_unit || 1),
      // For auto-select: don't persist UOM (it comes from CatalogItems.uom at BOM generation time)
      // For fixed: UOM comes from selected CatalogItem, so we don't persist it either
      // uom: not persisted - always comes from CatalogItems.uom at BOM generation
      auto_select: formData.selection_mode === 'auto_select', // DB field
      selection_mode: formData.selection_mode, // UI field
      id: `temp-${Date.now()}`,
      // Auto-select fields
      hardware_color: formData.selection_mode === 'auto_select' ? formData.hardware_color : null,
      sku_resolution_rule: formData.selection_mode === 'auto_select' ? formData.sku_resolution_rule : null,
      select_rule: formData.selection_mode === 'auto_select' ? formData.select_rule : null,
      block_condition: formData.selection_mode === 'auto_select' ? formData.block_condition : null,
      qty_type: formData.selection_mode === 'auto_select' ? (formData.qty_type || 'fixed') : null,
      qty_value: formData.selection_mode === 'auto_select' ? formData.qty_value : null,
      applies_color: formData.selection_mode === 'auto_select' ? (formData.applies_color || false) : false,
    };
    
    setComponents([...components, newComponent]);
    resetForm();
    
    useUIStore.getState().addNotification({
      type: 'success',
      title: 'Success',
      message: 'Component added successfully.',
    });
  };

  const handleUpdateComponent = () => {
    if (!editingComponentId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'No component selected for editing.',
      });
      return;
    }

    // Validation
    // Component role is always required
    if (!formData.component_role) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Component role is required.',
      });
      return;
    }
    
    if (formData.selection_mode === 'fixed' && !formData.component_item_id) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Please select a component.',
      });
      return;
    }

    if (formData.component_role && !isValidRole(formData.component_role)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Role',
        message: `Invalid component_role: "${formData.component_role}". Please select a valid role from the dropdown.`,
      });
      return;
    }

    const componentExists = components.some(c => c.id === editingComponentId);
    if (!componentExists) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Component not found. Please try again.',
      });
      return;
    }

    const updatedComponents = components.map(c => {
      if (c.id === editingComponentId) {
        // Restore component_item_id if switching back to fixed mode
        const finalComponentItemId = formData.selection_mode === 'fixed' 
          ? (formData.component_item_id || formData._original_component_item_id || '')
          : null;
        
        const updated = { 
          ...c, 
          ...formData,
          component_item_id: finalComponentItemId,
          component_role: normalizeRole(formData.component_role || ''),
          component_sub_role: normalizeSubRole(formData.component_sub_role || null),
          qty_per_unit: Math.round(formData.qty_per_unit || 1),
          // For auto-select: don't persist UOM (it comes from CatalogItems.uom at BOM generation time)
          // For fixed: UOM comes from selected CatalogItem, so we don't persist it either
          // uom: not persisted - always comes from CatalogItems.uom at BOM generation
          auto_select: formData.selection_mode === 'auto_select', // DB field
          selection_mode: formData.selection_mode, // UI field
          // Auto-select fields
          hardware_color: formData.selection_mode === 'auto_select' ? formData.hardware_color : null,
          sku_resolution_rule: formData.selection_mode === 'auto_select' ? formData.sku_resolution_rule : null,
          select_rule: formData.selection_mode === 'auto_select' ? formData.select_rule : null,
          block_condition: formData.selection_mode === 'auto_select' ? formData.block_condition : null,
          qty_type: formData.selection_mode === 'auto_select' ? (formData.qty_type || 'fixed') : null,
          qty_value: formData.selection_mode === 'auto_select' ? formData.qty_value : null,
          applies_color: formData.selection_mode === 'auto_select' ? (formData.applies_color || false) : false,
        };
        if (!c.id.startsWith('temp-')) {
          updated.id = `temp-${Date.now()}-${c.id}`;
          (updated as any)._originalId = c.id;
        }
        return updated;
      }
      return c;
    });
    
    setComponents(updatedComponents);
    resetForm();
    
    useUIStore.getState().addNotification({
      type: 'success',
      title: 'Success',
      message: 'Component updated successfully.',
    });
  };

  const resetForm = () => {
    setEditingComponentId(null);
    setFormData({
      component_item_id: '',
      component_role: '',
      component_sub_role: null,
      qty_per_unit: 1,
      uom: 'ea',
      is_required: true,
      _original_component_item_id: undefined,
      sequence_order: components.length,
      selection_mode: 'fixed',
      hardware_color: null,
      sku_resolution_rule: null,
      select_rule: null,
      block_condition: null,
      qty_type: 'fixed',
      qty_value: null,
      applies_color: false,
    });
    setShowAddComponentForm(false);
    setComponentSearchTerm('');
    setSelectedCategoryFilter('');
    setShowComponentDropdown(false);
    setHighlightedIndex(-1);
  };

  const handleDeleteComponent = (componentId: string) => {
    setComponents(components.filter(c => c.id !== componentId));
  };

  const handleEditComponent = (component: any) => {
    const componentItemId = component.component_item_id || '';
    const componentItem = catalogItems.find(item => item.id === componentItemId);
    const displayText = componentItem ? `${componentItem.sku} - ${componentItem.name || componentItem.item_name || 'Unnamed'}` : '';
    
    // Determine selection mode: use auto_select field if available, otherwise infer from component_item_id
    const selectionMode: 'fixed' | 'auto_select' = component.auto_select === true ? 'auto_select' : (componentItemId ? 'fixed' : 'auto_select');
    
    // Calculate UOM: for tube in auto_select mode, default to 'm'; otherwise use catalog/component UOM
    let initialUom: string;
    const componentRole = normalizeRole(component.component_role || '');
    if (componentRole === 'tube' && selectionMode === 'auto_select') {
      // TODO: When measure_basis is available, calculate from it
      initialUom = 'm'; // Default to meters for tube in auto_select mode
    } else {
      initialUom = componentItem?.uom || component.uom || 'ea';
    }
    
    setEditingComponentId(component.id);
    setFormData({
      component_item_id: componentItemId,
      component_role: component.component_role || '',
      component_sub_role: component.component_sub_role || null,
      qty_per_unit: Math.round(component.qty_per_unit || 1),
      uom: initialUom,
      is_required: component.is_required ?? true,
      sequence_order: component.sequence_order || 0,
      selection_mode: selectionMode,
      hardware_color: component.hardware_color || null,
      sku_resolution_rule: component.sku_resolution_rule || null,
      select_rule: component.select_rule || null,
      block_condition: component.block_condition || null,
      qty_type: component.qty_type || 'fixed',
      qty_value: component.qty_value || null,
      applies_color: component.applies_color || false,
      _original_component_item_id: componentItemId, // Preserve original when editing
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
    if (!productTypeId || !activeOrganizationId) {
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

      if (editingTemplateId) {
        await updateTemplate(editingTemplateId, {
          name: templateName || null,
          description: templateDescription || null,
        } as any);
        templateId = editingTemplateId;
      } else {
        const newTemplate = await createTemplate({
          product_type_id: productTypeId,
          name: templateName || null,
          description: templateDescription || null,
        } as any);
        templateId = newTemplate.id;
      }

      if (editingTemplateId) {
        // Identify components that should be kept (existing components that are still in the list)
        const existingComponentIds = new Set(existingComponents.map((c: any) => c.id));
        const currentComponentIds = new Set(
          components
            .filter(c => !c.id.startsWith('temp-') && !(c as any)._originalId)
            .map(c => c.id)
        );
        
        // Components that were removed (exist in DB but not in current components list)
        const removedComponentIds = Array.from(existingComponentIds).filter(
          id => !currentComponentIds.has(id)
        );
        
        // Soft delete removed components
        if (removedComponentIds.length > 0) {
          console.log('🗑️ Soft deleting removed components:', removedComponentIds);
          await supabase
            .from('BOMComponents')
            .update({ deleted: true })
            .in('id', removedComponentIds);
        }
        
        // Update existing components (real IDs or edited components with _originalId)
        for (const component of components) {
          // Skip truly new components (will be created below)
          if (component.id.startsWith('temp-') && !(component as any)._originalId) continue;
          
          // Determine the ID to use for update:
          // - If component has _originalId, it was edited → use _originalId
          // - Otherwise, use the component's real ID
          const componentIdToUpdate = (component as any)._originalId || component.id;
          
          const normalizedComponentRole = normalizeRole(component.component_role || '');
          const normalizedAffectsRole = normalizeRole(component.affects_role || '');
          const finalAffectsRole = (component.cut_axis === 'none' || !component.cut_axis) ? null : normalizedAffectsRole;
          
          console.log('🔄 Updating component:', componentIdToUpdate, component.id.startsWith('temp-') ? '(was edited)' : '(unchanged)');
          
          // For auto-select: don't persist UOM (it comes from CatalogItems.uom at BOM generation time)
          // For fixed: UOM comes from CatalogItem, but we still store it for backward compatibility
          // Note: The BOM generation function will use CatalogItems.uom regardless of what's stored here
          // Build update data, excluding temporary fields and undefined values
          const updateData: any = {
            component_item_id: component.component_item_id || null,
            component_role: normalizedComponentRole || null,
            component_sub_role: normalizeSubRole(component.component_sub_role || null),
            qty_per_unit: Math.round(component.qty_per_unit || 1),
            // UOM: For auto-select, use a default value (actual UOM comes from CatalogItems.uom at BOM generation)
            // For fixed, use the component's UOM or default to 'ea'
            uom: component.auto_select ? 'ea' : (component.uom || 'ea'),
            is_required: component.is_required,
            sequence_order: component.sequence_order,
            affects_role: finalAffectsRole,
            cut_axis: component.cut_axis === 'none' || !component.cut_axis ? null : component.cut_axis,
            cut_delta_mm: component.cut_delta_mm || null,
            cut_delta_scope: component.cut_delta_scope === 'none' || !component.cut_delta_scope ? null : component.cut_delta_scope,
            // Auto-select fields
            auto_select: component.auto_select || false,
            hardware_color: component.hardware_color || null,
            sku_resolution_rule: component.sku_resolution_rule || null,
            select_rule: component.select_rule || null,
            block_condition: component.block_condition || null,
            qty_type: component.qty_type || null,
            qty_value: component.qty_value || null,
            applies_color: component.applies_color || false,
          };
          
          // Remove any undefined values and temporary fields (fields starting with _)
          Object.keys(updateData).forEach(key => {
            if (updateData[key] === undefined || key.startsWith('_')) {
              delete updateData[key];
            }
          });
          
          const { error: updateError } = await supabase
            .from('BOMComponents')
            .update(updateData)
            .eq('id', componentIdToUpdate);
          
          if (updateError) {
            console.error('Error updating component:', updateError);
            throw new Error(`Error updating component ${componentIdToUpdate}: ${updateError.message || JSON.stringify(updateError)}`);
          }
        }
      }

      // Create new components (those with temp- IDs and no _originalId)
      for (const component of components) {
        // Only create truly new components (temp- ID without _originalId)
        if (!component.id.startsWith('temp-') || (component as any)._originalId) continue;

        const normalizedComponentRole = normalizeRole(component.component_role || '');
        const normalizedAffectsRole = normalizeRole(component.affects_role || '');
        
        const finalAffectsRole = (component.cut_axis === 'none' || !component.cut_axis) ? null : normalizedAffectsRole;
        
        console.log('➕ Creating new component:', component.id);
        
        // For auto-select: don't persist UOM (it comes from CatalogItems.uom at BOM generation time)
        // For fixed: UOM comes from CatalogItem, but we still store it for backward compatibility
        // Note: The BOM generation function will use CatalogItems.uom regardless of what's stored here
        
        const componentData = {
          bom_template_id: templateId,
          component_item_id: component.component_item_id || null,
          component_role: normalizedComponentRole || null,
          component_sub_role: normalizeSubRole(component.component_sub_role || null),
          auto_select: component.auto_select || false,
          applies_color: component.applies_color || false,
          allow_override: component.allow_override || false,
          qty_per_unit: Math.round(component.qty_per_unit || 1),
          // UOM: For auto-select, use a default value (actual UOM comes from CatalogItems.uom at BOM generation)
          // For fixed, use the component's UOM or default to 'ea'
          uom: component.auto_select ? 'ea' : (component.uom || 'ea'),
          is_required: component.is_required,
          sequence_order: component.sequence_order,
          affects_role: finalAffectsRole,
          cut_axis: component.cut_axis === 'none' || !component.cut_axis ? null : component.cut_axis,
          cut_delta_mm: component.cut_delta_mm || null,
          cut_delta_scope: component.cut_delta_scope === 'none' || !component.cut_delta_scope ? null : component.cut_delta_scope,
          // Auto-select fields
          hardware_color: component.hardware_color || null,
          sku_resolution_rule: component.sku_resolution_rule || null,
          select_rule: component.select_rule || null,
          block_condition: component.block_condition || null,
          qty_type: component.qty_type || null,
          qty_value: component.qty_value || null,
        };
        
        // Remove any undefined fields and temporary fields
        const cleanComponentData: any = {};
        Object.keys(componentData).forEach(key => {
          const value = componentData[key as keyof typeof componentData];
          // Only include defined values (not undefined) and exclude temporary fields
          if (value !== undefined && !key.startsWith('_')) {
            cleanComponentData[key] = value;
          }
        });
        
        try {
          const result = await createComponent(cleanComponentData);
          if (!result) {
            throw new Error('Component creation returned no data');
          }
        } catch (createError) {
          console.error('Error creating component:', createError);
          console.error('Component data sent:', cleanComponentData);
          // Re-throw with better error message
          if (createError instanceof Error) {
            throw createError;
          } else if (createError && typeof createError === 'object' && 'message' in createError) {
            throw new Error(String(createError.message));
          } else {
            throw new Error(`Error creating component: ${JSON.stringify(createError)}`);
          }
        }
      }

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
          errorMessage = String(error.message);
        } else if ('details' in error) {
          errorMessage = `${error.message || 'Database error'}: ${error.details || ''}`;
        } else if ('hint' in error) {
          errorMessage = `${error.message || 'Database error'}: ${error.hint || ''}`;
        } else {
          errorMessage = JSON.stringify(error, null, 2);
        }
      } else if (error) {
        errorMessage = String(error);
      }
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage,
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
                    setFormData({
                      component_item_id: '',
                      component_role: '',
                      component_sub_role: null,
                      qty_per_unit: 1,
                      uom: 'ea',
                      is_required: true,
                      _original_component_item_id: undefined,
                      sequence_order: components.length,
                      selection_mode: 'fixed',
                      hardware_color: null,
                      sku_resolution_rule: null,
                      select_rule: null,
                      block_condition: null,
                      qty_type: 'fixed',
                      qty_value: null,
                      applies_color: false,
                    });
                  }}
                  className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                >
                  <Plus className="w-4 h-4" />
                  Add Component
                </button>
              )}
            </div>

            {/* Add/Edit Component Form */}
            {showAddComponentForm && (
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
                {/* Selection Mode Toggle */}
                <div className="mb-4 pb-4 border-b border-gray-200">
                  <Label htmlFor="selection_mode" className="font-semibold mb-2 block">Selection Mode</Label>
                  <div className="flex gap-2 mb-2">
                    <button
                      type="button"
                      onClick={() => {
                        // Restore original component_item_id if switching from auto_select
                        const restoredComponentItemId = formData.selection_mode === 'auto_select' 
                          ? (formData._original_component_item_id || '')
                          : formData.component_item_id;
                        
                        setFormData({ 
                          ...formData, 
                          selection_mode: 'fixed',
                          component_item_id: restoredComponentItemId,
                          _original_component_item_id: undefined, // Clear after restore
                        });
                        if (formData.selection_mode === 'auto_select') {
                          setComponentSearchTerm(restoredComponentItemId ? '' : '');
                        }
                      }}
                      className={`px-4 py-2 text-xs font-medium rounded-lg transition-colors ${
                        formData.selection_mode === 'fixed'
                          ? 'bg-primary text-white'
                          : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
                      }`}
                    >
                      Fixed SKU (Siempre el mismo)
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        // If switching to auto_select and component is tube, default UOM to 'm'
                        let newUom = formData.uom;
                        if (formData.component_role === 'tube') {
                          newUom = 'm'; // Default to meters for tube in auto_select mode
                        }
                        
                        // Preserve original component_item_id before clearing it
                        const originalComponentItemId = formData.selection_mode === 'fixed' && formData.component_item_id
                          ? formData.component_item_id
                          : formData._original_component_item_id;
                        
                        setFormData({ 
                          ...formData, 
                          selection_mode: 'auto_select',
                          component_item_id: '', // Clear fixed selection when switching to auto-select
                          _original_component_item_id: originalComponentItemId, // Preserve original for restoration
                          qty_type: formData.qty_type || 'fixed',
                          uom: newUom,
                        });
                        setComponentSearchTerm('');
                      }}
                      className={`px-4 py-2 text-xs font-medium rounded-lg transition-colors ${
                        formData.selection_mode === 'auto_select'
                          ? 'bg-primary text-white'
                          : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
                      }`}
                    >
                      Auto-Select (Depende del sistema)
                    </button>
                  </div>
                  {/* Helper text for selection mode */}
                  <div className="text-xs text-gray-600">
                    {formData.selection_mode === 'fixed' ? (
                      <span>El SKU seleccionado se usará siempre en este template.</span>
                    ) : (
                      <span>El SKU se seleccionará automáticamente según las reglas configuradas (color, sistema, etc.).</span>
                    )}
                  </div>
                </div>

                <div className="grid grid-cols-12 gap-3 items-end">
                  {/* Component Selector - Only shown in Fixed mode */}
                  {(formData.selection_mode || 'fixed') === 'fixed' && (
                    <div className="col-span-4">
                      <Label htmlFor="component_item_id" required>Component</Label>
                    
                    <div className="mb-2">
                      <Label htmlFor="category_filter" className="text-xs text-gray-600 mb-1 block">
                        Filter by Category (Optional)
                      </Label>
                      <SelectShadcn
                        value={selectedCategoryFilter || '__all__'}
                        onValueChange={(value) => {
                          setSelectedCategoryFilter(value === '__all__' ? '' : value);
                          setShowComponentDropdown(true);
                        }}
                      >
                        <SelectTrigger>
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
                    
                    <div className="relative">
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
                            // Clear selection if user is typing
                            if (value !== `${formData.component_item_id}`) {
                              const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);
                              const selectedText = selectedItem ? `${selectedItem.sku} - ${selectedItem.name || selectedItem.item_name || 'Unnamed'}` : '';
                              if (value !== selectedText) {
                                setFormData({ ...formData, component_item_id: '' });
                              }
                            }
                          }}
                          onFocus={() => {
                            if (flatFilteredItems.length > 0 || componentSearchTerm.trim()) {
                              setShowComponentDropdown(true);
                            }
                          }}
                          onKeyDown={handleKeyDown}
                          className="pl-8 pr-8"
                          autoComplete="off"
                        />
                        {componentSearchTerm && (
                          <button
                            onClick={() => {
                              setComponentSearchTerm('');
                              setFormData({ ...formData, component_item_id: '' });
                              setShowComponentDropdown(false);
                              setHighlightedIndex(-1);
                              componentInputFieldRef.current?.focus();
                            }}
                            className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                            type="button"
                          >
                            <X className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>

                      {/* Autocomplete Dropdown */}
                      {showComponentDropdown && (flatFilteredItems.length > 0 || componentSearchTerm.trim()) && (
                        <div className="component-autocomplete-dropdown absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-[300px] overflow-y-auto">
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

                      {/* Show selected component info when dropdown is closed */}
                      {formData.component_item_id && !showComponentDropdown && (
                        <div className="mt-2 p-2 bg-gray-50 border border-gray-200 rounded text-xs">
                          <div className="font-medium text-gray-900">
                            {(() => {
                              const selectedItem = catalogItems.find(item => item.id === formData.component_item_id);
                              return selectedItem ? `${selectedItem.sku} - ${selectedItem.name || selectedItem.item_name || 'Unnamed'}` : 'Component selected';
                            })()}
                          </div>
                          <button
                            type="button"
                            onClick={() => {
                              setFormData({ ...formData, component_item_id: '' });
                              setComponentSearchTerm('');
                              componentInputFieldRef.current?.focus();
                            }}
                            className="mt-1 text-primary hover:underline text-xs"
                          >
                            Change component
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                  )}

                  {/* Component Role - Always Required */}
                  <div className={`${(formData.selection_mode || 'fixed') === 'fixed' ? 'col-span-3' : 'col-span-4'} flex flex-col`}>
                    <Label htmlFor="component_role" required>
                      Component Role
                    </Label>
                    <div className="flex-1 flex flex-col justify-end">
                      <SelectShadcn
                        value={formData.component_role || ''}
                        onValueChange={(value) => {
                          const newRole = value === 'none' ? '' : value;
                          // Clear sub_role if role changes and new role doesn't have sub_roles
                          const newSubRole = hasSubRoles(newRole) ? formData.component_sub_role : null;
                          
                          // If role is tube and in auto_select mode, set UOM to 'm'
                          let newUom = formData.uom;
                          const normalizedNewRole = normalizeRole(newRole);
                          if (normalizedNewRole === 'tube' && (formData.selection_mode || 'fixed') === 'auto_select') {
                            newUom = 'm'; // Default to meters for tube in auto_select mode
                          }
                          
                          setFormData({ ...formData, component_role: newRole, component_sub_role: newSubRole, uom: newUom });
                        }}
                      >
                        <SelectTrigger>
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
                    {/* Helper text for role */}
                    {formData.component_role && getRoleHelperText(formData.component_role) && (
                      <p className="text-xs text-gray-500 mt-1">
                        {getRoleHelperText(formData.component_role)}
                      </p>
                    )}
                  </div>
                  {/* Sub-Role - Only shown when role has sub_roles available */}
                  {hasSubRoles(formData.component_role) && (
                    <div className="col-span-3 flex flex-col">
                      <Label htmlFor="component_sub_role">
                        Sub-Role / Part Type (Optional)
                      </Label>
                      <div className="flex-1 flex flex-col justify-end">
                        <SelectShadcn
                          value={formData.component_sub_role || ''}
                          onValueChange={(value) => setFormData({ ...formData, component_sub_role: value === 'none' ? null : value })}
                        >
                          <SelectTrigger>
                            <SelectValue placeholder="Select sub-role (optional)" />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="none">— None —</SelectItem>
                            {getSubRolesForRole(formData.component_role)?.map((subRole) => (
                              <SelectItem key={subRole} value={subRole}>
                                {getSubRoleLabel(subRole)}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </SelectShadcn>
                      </div>
                    </div>
                  )}
                  <div className="col-span-2 flex flex-col">
                    <Label htmlFor="qty_per_unit" required>Qty/Unit</Label>
                    <div className="flex-1 flex flex-col justify-end">
                      <Input
                        id="qty_per_unit"
                        type="number"
                        step="1"
                        min="1"
                        value={formData.qty_per_unit}
                        onChange={(e) => {
                          const value = parseInt(e.target.value, 10) || 1;
                          setFormData({ ...formData, qty_per_unit: Math.max(1, value) });
                        }}
                      />
                    </div>
                  </div>
                  <div className="col-span-2 flex flex-col">
                    <Label htmlFor="uom" required>UOM</Label>
                    <div className="flex-1 flex flex-col justify-end">
                      <Input
                        id="uom"
                        value={formData.uom}
                        readOnly={isUomReadonlyForComponent(formData.component_role, formData.selection_mode)}
                        disabled={isUomReadonlyForComponent(formData.component_role, formData.selection_mode)}
                        className={isUomReadonlyForComponent(formData.component_role, formData.selection_mode) ? 'bg-gray-100 cursor-not-allowed' : ''}
                        placeholder="ea"
                        title={
                          formData.selection_mode === 'auto_select'
                            ? "UOM se define automáticamente según el SKU seleccionado al generar el BOM (CatalogItems.uom)"
                            : "UOM se toma automáticamente del CatalogItem seleccionado"
                        }
                      />
                      {/* Helper text for auto-select */}
                      {(formData.selection_mode || 'fixed') === 'auto_select' && (
                        <p className="text-xs text-gray-500 mt-1">
                          UOM se define automáticamente según el SKU seleccionado al generar el BOM.
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="col-span-2 flex flex-col">
                    <Label htmlFor="sequence_order">Order</Label>
                    <div className="flex-1 flex flex-col justify-end">
                      <Input
                        id="sequence_order"
                        type="number"
                        value={formData.sequence_order}
                        onChange={(e) => setFormData({ ...formData, sequence_order: parseInt(e.target.value) || 0 })}
                      />
                    </div>
                  </div>
                  <div className="col-span-1 flex items-end">
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

                {/* Auto-Select Fields - Only shown when selection_mode === 'auto_select' and conditionally by role */}
                {(formData.selection_mode || 'fixed') === 'auto_select' && (
                  <div className="mt-4 pt-4 border-t border-gray-300">
                    <h4 className="text-xs font-semibold text-gray-900 mb-3">Auto-Select Configuration</h4>
                    <div className="grid grid-cols-12 gap-3 items-end">
                      {/* Hardware Color - Only for specific roles */}
                      {shouldShowHardwareColor(formData.component_role) && (
                        <div className="col-span-3 flex flex-col">
                          <Label htmlFor="hardware_color">Hardware Color</Label>
                          <div className="flex-1 flex flex-col justify-end">
                            <SelectShadcn
                              value={formData.hardware_color || 'none'}
                              onValueChange={(value) => setFormData({ ...formData, hardware_color: value === 'none' ? null : value as HardwareColor })}
                            >
                              <SelectTrigger>
                                <SelectValue placeholder="Select color" />
                              </SelectTrigger>
                              <SelectContent>
                                <SelectItem value="none">— None —</SelectItem>
                                <SelectItem value="white">White</SelectItem>
                                <SelectItem value="black">Black</SelectItem>
                                <SelectItem value="silver">Silver</SelectItem>
                                <SelectItem value="bronze">Bronze</SelectItem>
                                <SelectItem value="grey">Grey</SelectItem>
                              </SelectContent>
                            </SelectShadcn>
                          </div>
                        </div>
                      )}

                      {/* SKU Resolution Rule - Only for specific roles */}
                      {shouldShowSKUResolutionRule(formData.component_role) && (
                        <div className="col-span-3 flex flex-col">
                          <Label htmlFor="sku_resolution_rule">Cómo se selecciona el SKU</Label>
                          <div className="flex-1 flex flex-col justify-end">
                            <SelectShadcn
                              value={formData.sku_resolution_rule || 'ROLE_AND_COLOR'}
                              onValueChange={(value) => setFormData({ ...formData, sku_resolution_rule: value as SKUResolutionRule })}
                            >
                            <SelectTrigger>
                              <SelectValue placeholder="Selecciona cómo se resuelve el SKU" />
                            </SelectTrigger>
                            <SelectContent>
                              {getValidSKUResolutionRules(formData.component_role).map((rule) => (
                                <SelectItem key={rule} value={rule}>
                                  {getSKUResolutionRuleLabel(rule, formData.component_role)}
                                </SelectItem>
                              ))}
                            </SelectContent>
                            </SelectShadcn>
                          </div>
                          {/* Helper text for SKU resolution */}
                          {getSKUResolutionHelperText(formData.component_role) && (
                            <p className="text-xs text-gray-500 mt-1">
                              {getSKUResolutionHelperText(formData.component_role)}
                            </p>
                          )}
                        </div>
                      )}

                      {/* Quantity Type - Hide if always fixed for this role */}
                      {!isQtyAlwaysFixed(formData.component_role) && (
                        <>
                          <div className="col-span-3 flex flex-col">
                            <Label htmlFor="qty_type">Quantity Type</Label>
                            <div className="flex-1 flex flex-col justify-end">
                              <SelectShadcn
                                value={formData.qty_type || 'fixed'}
                                onValueChange={(value) => setFormData({ ...formData, qty_type: value as BOMQtyType, qty_value: value === 'fixed' ? (formData.qty_value || 1) : formData.qty_value })}
                              >
                                <SelectTrigger>
                                  <SelectValue placeholder="Select type" />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="fixed">Fixed</SelectItem>
                                  <SelectItem value="per_width">Per Width (linear)</SelectItem>
                                  <SelectItem value="per_area">Per Area</SelectItem>
                                </SelectContent>
                              </SelectShadcn>
                            </div>
                          </div>

                          {/* Quantity Value */}
                          <div className="col-span-3 flex flex-col">
                            <Label htmlFor="qty_value">
                              Quantity Value {formData.qty_type === 'fixed' ? '(count)' : '(multiplier)'}
                            </Label>
                            <div className="flex-1 flex flex-col justify-end">
                              <Input
                                id="qty_value"
                                type="number"
                                step="0.01"
                                value={formData.qty_value || ''}
                                onChange={(e) => {
                                  const value = e.target.value === '' ? null : parseFloat(e.target.value);
                                  setFormData({ ...formData, qty_value: value });
                                }}
                                placeholder={formData.qty_type === 'fixed' ? '1' : '1.0'}
                              />
                            </div>
                          </div>
                        </>
                      )}

                      {/* Show fixed quantity message for roles that always use fixed qty */}
                      {isQtyAlwaysFixed(formData.component_role) && (
                        <div className="col-span-6 flex items-center">
                          <p className="text-xs text-gray-600">
                            Cantidad fija: {formData.qty_per_unit || 1} unidad{formData.qty_per_unit !== 1 ? 'es' : ''}
                          </p>
                        </div>
                      )}
                    </div>

                    {/* Block Condition - Only for specific roles */}
                    {shouldShowBlockCondition(formData.component_role) && (
                      <div className="mt-3 pt-3 border-t border-gray-200">
                        <Label className="text-xs font-medium mb-2 block">Block Condition (Opcional)</Label>
                        <div className="text-xs text-gray-600 mb-2">
                          Incluir este componente solo cuando estas condiciones se cumplan:
                        </div>
                        <div className="grid grid-cols-12 gap-2">
                          <div className="col-span-3 flex items-center gap-2">
                            <input
                              type="checkbox"
                              id="block_cassette"
                              checked={(formData.block_condition as any)?.cassette === true}
                              onChange={(e) => {
                                const newBlockCondition = { ...(formData.block_condition || {}), cassette: e.target.checked };
                                setFormData({ ...formData, block_condition: Object.keys(newBlockCondition).length > 0 ? newBlockCondition : null });
                              }}
                              className="h-4 w-4"
                            />
                            <Label htmlFor="block_cassette" className="mb-0">Cassette</Label>
                          </div>
                          <div className="col-span-3 flex items-center gap-2">
                            <input
                              type="checkbox"
                              id="block_side_channel"
                              checked={(formData.block_condition as any)?.side_channel === true}
                              onChange={(e) => {
                                const newBlockCondition = { ...(formData.block_condition || {}), side_channel: e.target.checked };
                                setFormData({ ...formData, block_condition: Object.keys(newBlockCondition).length > 0 ? newBlockCondition : null });
                              }}
                              className="h-4 w-4"
                            />
                            <Label htmlFor="block_side_channel" className="mb-0">Side Channel</Label>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )}
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
                            <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {categoryGroup.components.map((component) => {
                            const componentItem = catalogItems.find(item => item.id === component.component_item_id);
                            const hasComponentRole = component.component_role && !component.component_item_id;
                            return (
                              <tr key={component.id} className="hover:bg-gray-50">
                                <td className="py-2 px-4 text-xs text-gray-900">
                                  {hasComponentRole ? (
                                    <>
                                      <span className="font-medium">{component.component_role}</span>
                                      <div className="text-gray-500 text-xs mt-0.5">
                                        {component.auto_select ? 'Auto-select' : 'Manual'}
                                      </div>
                                    </>
                                  ) : (
                                    <>
                                      {componentItem?.name || componentItem?.item_name || component.component_name || 'Unknown'}
                                      <div className="text-gray-500 text-xs mt-0.5">
                                        SKU: {componentItem?.sku || component.component_sku || 'N/A'}
                                      </div>
                                    </>
                                  )}
                                </td>
                                <td className="py-2 px-4 text-xs text-gray-700 text-right">
                                  {Math.round(component.qty_per_unit || 0)}
                                </td>
                                <td className="py-2 px-4 text-xs text-gray-700">
                                  {component.auto_select ? (
                                    <span 
                                      className="text-gray-500 italic" 
                                      title="UOM se toma del SKU resuelto (CatalogItems.uom) al generar el BOM"
                                    >
                                      Auto
                                    </span>
                                  ) : (
                                    componentItem?.uom || component.uom || 'ea'
                                  )}
                                </td>
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.component_role ? (
                                    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                      isValidRole(component.component_role) 
                                        ? 'bg-blue-100 text-blue-800' 
                                        : 'bg-orange-100 text-orange-800'
                                    }`} title={!isValidRole(component.component_role) ? 'Legacy role - please update to a valid role' : ''}>
                                      {getRoleLabel(component.component_role)}
                                    </span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.block_condition ? (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800" title={JSON.stringify(component.block_condition)}>
                                      Conditional
                                    </span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                <td className="py-2 px-4 text-xs text-center">
                                  {component.applies_color ? (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800">
                                      Color
                                    </span>
                                  ) : (
                                    <span className="text-gray-400">—</span>
                                  )}
                                </td>
                                <td className="py-2 px-4 text-xs text-gray-700 text-center">
                                  {component.sequence_order || 0}
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
            onClick={handleSave}
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
