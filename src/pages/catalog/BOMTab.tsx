import { useState, useEffect, useMemo } from 'react';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useCatalogItems, useItemCategories, useLeafItemCategories } from '../../hooks/useCatalog';
import { useBOMCRUD, useBOMComponents } from '../../hooks/useBOM';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useBOMTemplates, useBOMTemplateCRUD } from '../../hooks/useBOMTemplates';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue, SelectGroup, SelectLabel } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import Input from '../../components/ui/Input';
import { Plus, Edit, Trash2, X, Package, Folder, ChevronDown, ChevronRight, Search } from 'lucide-react';

interface ComponentGroupedByCategory {
  category_id: string | null;
  category_name: string;
  category_code: string | null;
  components: any[];
}

export default function BOMTab() {
  const { activeOrganizationId } = useOrganizationContext();
  const { productTypes, loading: productTypesLoading } = useProductTypes();
  const { templates, loading: templatesLoading, refetch: refetchTemplates } = useBOMTemplates();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showBOMModal, setShowBOMModal] = useState(false);
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(null);

  // Group templates by product type - MUST be before early returns (React hooks rule)
  const templatesByProductType = useMemo(() => {
    const groups = new Map<string, any[]>();
    (templates || []).forEach((template: any) => {
      const productTypeId = template.product_type_id;
      if (!groups.has(productTypeId)) {
        groups.set(productTypeId, []);
      }
      groups.get(productTypeId)!.push(template);
    });
    return Array.from(groups.entries()).map(([productTypeId, templateList]) => {
      const productType = (productTypes || []).find(pt => pt.id === productTypeId);
      return {
        productType,
        templates: templateList,
      };
    });
  }, [templates, productTypes]);

  const handleAddBOM = () => {
    setEditingTemplateId(null);
    setShowBOMModal(true);
  };

  const handleEditBOM = (templateId: string) => {
    setEditingTemplateId(templateId);
    setShowBOMModal(true);
  };

  const handleDeleteBOM = async (templateId: string) => {
    if (!confirm('Are you sure you want to delete this BOM template? This action cannot be undone.')) {
      return;
    }

    try {
      const { error } = await supabase
        .from('BOMTemplates')
        .update({ deleted: true })
        .eq('id', templateId)
        .eq('organization_id', activeOrganizationId);

      if (error) {
        throw error;
      }

      // Refetch templates
      refetchTemplates();
    } catch (error) {
      console.error('Error deleting BOM template:', error);
      alert('Error deleting BOM template');
    }
  };

  const handleBOMSaved = () => {
    setShowBOMModal(false);
    setEditingTemplateId(null);
    // Refetch templates without reloading the page
    refetchTemplates();
  };

  // Early returns AFTER all hooks
  if (productTypesLoading || templatesLoading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg py-12 px-6 text-center">
        <p className="text-sm text-gray-600">Loading BOMs...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg py-12 px-6 text-center">
        <p className="text-sm text-red-600">Error: {error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Header with Add Button */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Bill of Materials</h2>
          <p className="text-sm text-gray-500 mt-1">
            Manage BOM configurations by Product Type
          </p>
        </div>
        <button
          onClick={handleAddBOM}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          Add BOM Template
        </button>
      </div>

      {/* BOM List Grouped by Product Type */}
      {templatesByProductType.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg py-12 px-6 text-center">
          <div className="flex flex-col items-center">
            <Package className="w-12 h-12 text-gray-400 mb-4" />
            <p className="text-gray-600 mb-2">No BOM templates configured yet</p>
            <p className="text-sm text-gray-500 mb-4">
              Click "Add BOM Template" to create your first Bill of Materials
            </p>
            <button
              onClick={handleAddBOM}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
            >
              <Plus className="w-4 h-4" />
              Add BOM Template
            </button>
          </div>
        </div>
      ) : (
        <div className="space-y-6">
          {templatesByProductType.map((group) => (
            <div
              key={group.productType?.id || 'unknown'}
              className="bg-white border border-gray-200 rounded-lg overflow-hidden"
            >
              {/* Product Type Header */}
              <div className="bg-gray-50 border-b border-gray-200 px-6 py-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-base font-semibold text-gray-900">
                      {group.productType?.name || 'Unknown Product Type'}
                    </h3>
                    <p className="text-xs text-gray-500 mt-1">
                      Code: {group.productType?.code || 'N/A'} • {group.templates.length} template{group.templates.length !== 1 ? 's' : ''}
                    </p>
                  </div>
                </div>
              </div>

              {/* Templates List */}
              <div className="divide-y divide-gray-200">
                {group.templates.map((template: any) => (
                  <BOMTemplateCard
                    key={template.id}
                    template={template}
                    onEdit={() => handleEditBOM(template.id)}
                    onDelete={() => handleDeleteBOM(template.id)}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* BOM Modal */}
      {showBOMModal && (
        <BOMModal
          isOpen={showBOMModal}
          onClose={() => {
            setShowBOMModal(false);
            setEditingTemplateId(null);
          }}
          onSave={handleBOMSaved}
          editingTemplateId={editingTemplateId}
        />
      )}
    </div>
  );
}

// BOM Template Card Component
function BOMTemplateCard({ template, onEdit, onDelete }: { template: any; onEdit: () => void; onDelete: () => void }) {
  const { components, loading } = useBOMComponents(template.id);
  const { categories } = useItemCategories();
  const [expanded, setExpanded] = useState(false);

  // Early return if template is not available
  if (!template || !template.id) {
    return null;
  }

  // Group components by category
  const componentsByCategory = useMemo(() => {
    if (!components || components.length === 0) {
      return [];
    }

    const groups = new Map<string | null, ComponentGroupedByCategory>();
    
    components.forEach((component: any) => {
      const categoryId = component.component_category_id || null;
      const categoryName = component.component_category_name || 'Uncategorized';
      const categoryCode = component.component_category_code || null;
      
      if (!groups.has(categoryId)) {
        groups.set(categoryId, {
          category_id: categoryId,
          category_name: categoryName,
          category_code: categoryCode,
          components: [],
        });
      }
      groups.get(categoryId)!.components.push(component);
    });

    // Sort categories by code or name
    const sortedGroups = Array.from(groups.values()).sort((a, b) => {
      if (a.category_code && b.category_code) {
        return a.category_code.localeCompare(b.category_code);
      }
      return a.category_name.localeCompare(b.category_name);
    });

    return sortedGroups;
  }, [components]);

  if (loading) {
    return (
      <div className="px-6 py-4">
        <p className="text-xs text-gray-500">Loading components...</p>
      </div>
    );
  }

  return (
    <div className="px-6 py-4">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setExpanded(!expanded)}
            className="p-1 hover:bg-gray-100 rounded transition-colors"
          >
            {expanded ? (
              <ChevronDown className="w-4 h-4 text-gray-600" />
            ) : (
              <ChevronRight className="w-4 h-4 text-gray-600" />
            )}
          </button>
          <div>
            <h4 className="text-sm font-medium text-gray-900">
              {template.name || 'Unnamed Template'}
            </h4>
            {template.description && (
              <p className="text-xs text-gray-500 mt-0.5">{template.description}</p>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={onEdit}
            className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <Edit className="w-4 h-4" />
            Edit
          </button>
          <button
            onClick={onDelete}
            className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-red-700 bg-white border border-red-200 rounded-lg hover:bg-red-50 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Delete
          </button>
        </div>
      </div>

      {expanded && (
        <div className="ml-8 space-y-4">
          {componentsByCategory.length === 0 ? (
            <p className="text-xs text-gray-500 py-2">No components configured</p>
          ) : (
            componentsByCategory.map((categoryGroup) => (
              <div key={categoryGroup.category_id || 'uncategorized'} className="border border-gray-200 rounded-lg overflow-hidden">
                {/* Category Header */}
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

                {/* Components Table */}
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">Component</th>
                        <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Qty/Unit</th>
                        <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">UOM</th>
                        <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Required</th>
                        <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Order</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {categoryGroup.components.map((component: any) => (
                        <tr key={component.id} className="hover:bg-gray-50">
                          <td className="py-2 px-4 text-xs text-gray-900">
                            <div>
                              <div className="font-medium">
                                {component.component_name || 'Unknown'}
                              </div>
                              <div className="text-gray-500 text-xs mt-0.5">
                                SKU: {component.component_sku || 'N/A'}
                              </div>
                            </div>
                          </td>
                          <td className="py-2 px-4 text-xs text-gray-700 text-right">
                            {component.qty_per_unit?.toFixed(4) || '0.0000'}
                          </td>
                          <td className="py-2 px-4 text-xs text-gray-700">
                            {component.uom || 'unit'}
                          </td>
                          <td className="py-2 px-4 text-xs text-center">
                            <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                              component.is_required
                                ? 'bg-green-100 text-green-800'
                                : 'bg-gray-100 text-gray-800'
                            }`}>
                              {component.is_required ? 'Yes' : 'No'}
                            </span>
                          </td>
                          <td className="py-2 px-4 text-xs text-gray-700 text-center">
                            {component.sequence_order || 0}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}

// BOM Modal Component
function BOMModal({ isOpen, onClose, onSave, editingTemplateId }: {
  isOpen: boolean;
  onClose: () => void;
  onSave: () => void;
  editingTemplateId: string | null;
}) {
  const { activeOrganizationId } = useOrganizationContext();
  const { productTypes } = useProductTypes();
  const { items: catalogItems, loading: catalogItemsLoading } = useCatalogItems();
  const { categories, loading: categoriesLoading } = useItemCategories();
  const { categories: leafCategories = [] } = useLeafItemCategories(); // For category filter dropdown
  const { createTemplate, updateTemplate, isCreating, isUpdating } = useBOMTemplateCRUD();
  const { createComponent, isCreating: isCreatingComponent } = useBOMCRUD();
  // Always call hook, but pass null if not editing (hook handles null internally)
  const { components: existingComponents, loading: loadingComponents } = useBOMComponents(editingTemplateId || null);

  // Debug: Log data when it changes
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('📊 BOM Modal - Data loaded:', {
        catalogItemsCount: catalogItems.length,
        categoriesCount: categories.length,
        catalogItemsLoading,
        categoriesLoading,
        sampleItem: catalogItems[0] ? {
          id: catalogItems[0].id,
          sku: catalogItems[0].sku,
          item_name: catalogItems[0].item_name,
          item_category_id: catalogItems[0].item_category_id,
        } : null,
        sampleCategory: categories[0] ? {
          id: categories[0].id,
          name: categories[0].name,
          code: categories[0].code,
        } : null,
      });
    }
  }, [catalogItems, categories, catalogItemsLoading, categoriesLoading]);
  
  const [productTypeId, setProductTypeId] = useState<string>('');
  const [templateName, setTemplateName] = useState<string>('');
  const [templateDescription, setTemplateDescription] = useState<string>('');
  const [components, setComponents] = useState<any[]>([]);
  const [showAddComponentForm, setShowAddComponentForm] = useState(false);
  const [editingComponentId, setEditingComponentId] = useState<string | null>(null);
  const [componentSearchTerm, setComponentSearchTerm] = useState<string>('');
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState<string>(''); // Category filter for components
  const [formData, setFormData] = useState({
    component_item_id: '',
    qty_per_unit: 1,
    uom: 'unit',
    is_required: true,
    sequence_order: 0,
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
            setTemplateName(data.name || '');
            setTemplateDescription(data.description || '');
          }
        });
    }
  }, [editingTemplateId, activeOrganizationId]);

  // Load existing components when template is loaded
  useEffect(() => {
    if (editingTemplateId && existingComponents && Array.isArray(existingComponents)) {
      setComponents(existingComponents.map((comp: any) => ({
        ...comp,
        id: comp.id, // Keep real ID for updates
      })));
    } else if (!editingTemplateId) {
      // Reset components when not editing
      setComponents([]);
    }
  }, [editingTemplateId, existingComponents]);

  // Group components by category for display
  const componentsByCategory = useMemo(() => {
    if (!components || components.length === 0) {
      return [];
    }

    const groups = new Map<string | null, ComponentGroupedByCategory>();
    
    components.forEach((component: any) => {
      const componentItem = catalogItems.find(item => item.id === component.component_item_id);
      const categoryId = componentItem?.item_category_id || component.component_category_id || null;
      const category = categories.find(cat => cat.id === categoryId);
      const categoryName = category?.name || component.component_category_name || 'Uncategorized';
      const categoryCode = category?.code || component.component_category_code || null;
      
      if (!groups.has(categoryId)) {
        groups.set(categoryId, {
          category_id: categoryId,
          category_name: categoryName,
          category_code: categoryCode,
          components: [],
        });
      }
      groups.get(categoryId)!.components.push(component);
    });

    // Sort categories by code or name
    const sortedGroups = Array.from(groups.values()).sort((a, b) => {
      if (a.category_code && b.category_code) {
        return a.category_code.localeCompare(b.category_code);
      }
      return a.category_name.localeCompare(b.category_name);
    });

    // Sort components within each category by sequence_order
    sortedGroups.forEach(group => {
      group.components.sort((a, b) => (a.sequence_order || 0) - (b.sequence_order || 0));
    });

    return sortedGroups;
  }, [components, catalogItems, categories]);

  const handleAddComponent = () => {
    if (!formData.component_item_id) return;

    const newComponent = {
      ...formData,
      id: `temp-${Date.now()}`,
    };
    setComponents([...components, newComponent]);
    setFormData({
      component_item_id: '',
      qty_per_unit: 1,
      uom: 'unit',
      is_required: true,
      sequence_order: components.length,
    });
    setShowAddComponentForm(false);
    setComponentSearchTerm('');
    setSelectedCategoryFilter('');
  };

  const handleUpdateComponent = () => {
    if (!editingComponentId) {
      console.error('❌ No editingComponentId set');
      return;
    }

    if (!formData.component_item_id) {
      alert('Please select a component');
      return;
    }

    console.log('💾 Updating component:', { editingComponentId, formData });

    // Mark component as modified by changing its ID to temp-* if it's an existing one
    // This ensures it will be recreated in handleSave
    setComponents(components.map(c => {
      if (c.id === editingComponentId) {
        const updated = { ...c, ...formData };
        console.log('📝 Component before update:', c);
        console.log('📝 Component after update:', updated);
        // If it's an existing component (not temp-), mark it for recreation
        if (!c.id.startsWith('temp-')) {
          updated.id = `temp-${Date.now()}-${c.id}`; // Mark for deletion and recreation
          updated._originalId = c.id; // Keep original ID for deletion
          console.log('🔄 Marked component for recreation:', { originalId: c.id, newId: updated.id });
        }
        return updated;
      }
      return c;
    }));
    setEditingComponentId(null);
    setFormData({
      component_item_id: '',
      qty_per_unit: 1,
      uom: 'unit',
      is_required: true,
      sequence_order: 0,
    });
    setShowAddComponentForm(false);
    setComponentSearchTerm('');
    setSelectedCategoryFilter('');
  };

  const handleDeleteComponent = (componentId: string) => {
    setComponents(components.filter(c => c.id !== componentId));
  };

  const handleSave = async () => {
    if (!productTypeId || !activeOrganizationId) {
      alert('Please select a Product Type');
      return;
    }

    try {
      let templateId = editingTemplateId;

      // Create or update template
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

      // Delete existing components if editing
      if (editingTemplateId) {
        const existingComponentIds = existingComponents.map((c: any) => c.id);
        // Also delete components that were edited (they have _originalId)
        const editedComponentIds = components
          .filter(c => (c as any)._originalId)
          .map(c => (c as any)._originalId);
        
        const allIdsToDelete = [...new Set([...existingComponentIds, ...editedComponentIds])];
        
        for (const compId of allIdsToDelete) {
          await supabase
            .from('BOMComponents')
            .update({ deleted: true })
            .eq('id', compId);
        }
      }

      // Create new components (including edited ones marked as temp-)
      for (const component of components) {
        // Skip components that weren't modified (they don't start with temp-)
        if (!component.id.startsWith('temp-')) {
          console.log('⏭️ Skipping component (not modified):', component.id);
          continue;
        }

        console.log('➕ Creating component:', {
          id: component.id,
          component_item_id: component.component_item_id,
          qty_per_unit: component.qty_per_unit,
        });

        try {
          await createComponent({
            bom_template_id: templateId,
            component_item_id: component.component_item_id || null, // Allow NULL for fabric
            component_role: component.component_role || null, // Support component_role
            auto_select: component.auto_select || false,
            applies_color: component.applies_color || false,
            allow_override: component.allow_override || false,
            qty_per_unit: component.qty_per_unit,
            uom: component.uom,
            is_required: component.is_required,
            sequence_order: component.sequence_order,
          } as any);
          console.log('✅ Component created successfully');
        } catch (error) {
          console.error('❌ Error creating component:', error);
          throw error;
        }
      }

      onSave();
    } catch (error) {
      console.error('Error saving BOM:', error);
      alert('Error saving BOM');
    }
  };

  if (!isOpen) return null;

  // Filter and group available components by category for the select dropdown
  const filteredAndGroupedComponents = useMemo(() => {
    const searchLower = componentSearchTerm.trim().toLowerCase();
    
    // Debug logs
    if (import.meta.env.DEV) {
      console.log('🔍 BOM Modal - Filtering components:', {
        totalItems: catalogItems.length,
        searchTerm: componentSearchTerm,
        categoryFilter: selectedCategoryFilter,
        categoriesCount: categories.length,
        componentsAdded: components.length,
      });
    }
    
    // Filter components by search term and category filter
    const filtered = catalogItems.filter(item => {
      if (!item.id) return false;
      
      // Check if already added to components
      const isAlreadyAdded = components.some(c => c.component_item_id === item.id);
      if (isAlreadyAdded) return false;
      
      // Category filter - if a category is selected, only show items from that category
      if (selectedCategoryFilter && selectedCategoryFilter !== '__all__') {
        if (item.item_category_id !== selectedCategoryFilter) {
          return false;
        }
      }
      
      // Search filter - search in SKU, name, description, and category name
      if (componentSearchTerm.trim()) {
        const sku = (item.sku || '').toLowerCase();
        const name = (item.name || item.item_name || '').toLowerCase();
        const description = (item.description || '').toLowerCase();
        
        // Also search in category name
        const categoryId = item.item_category_id;
        const category = categories.find(cat => cat.id === categoryId);
        const categoryName = (category?.name || '').toLowerCase();
        const categoryCode = (category?.code || '').toLowerCase();
        
        const matchesSearch = 
          sku.includes(searchLower) || 
          name.includes(searchLower) || 
          description.includes(searchLower) ||
          categoryName.includes(searchLower) ||
          categoryCode.includes(searchLower);
        
        if (!matchesSearch) return false;
      }
      
      return true;
    });

    // Group by category
    const groups = new Map<string | null, { category: any; items: any[] }>();
    
    filtered.forEach((item) => {
      const categoryId = item.item_category_id || null;
      const category = categories.find(cat => cat.id === categoryId);
      
      // Use category from lookup or create default
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

    // Sort categories and items
    const sortedGroups = Array.from(groups.values()).sort((a, b) => {
      // Always put "Uncategorized" at the end
      if (a.category.id === null && b.category.id !== null) return 1;
      if (b.category.id === null && a.category.id !== null) return -1;
      if (a.category.id === null && b.category.id === null) return 0;
      
      // Sort by code first, then by name
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

    // Debug logs
    if (import.meta.env.DEV) {
      console.log('✅ BOM Modal - Filtered and grouped:', {
        filteredCount: filtered.length,
        groupsCount: sortedGroups.length,
        groups: sortedGroups.map(g => ({
          category: g.category.name,
          code: g.category.code,
          itemsCount: g.items.length,
        })),
      });
    }

    return sortedGroups;
  }, [catalogItems, componentSearchTerm, selectedCategoryFilter, components, categories]);

  const availableComponents = catalogItems.filter(item => item.id);

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
          {/* Step 1: Product Type Selection */}
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
              <button
                onClick={() => {
                  setShowAddComponentForm(true);
                  setEditingComponentId(null);
                  setFormData({
                    component_item_id: '',
                    qty_per_unit: 1,
                    uom: 'unit',
                    is_required: true,
                    sequence_order: components.length,
                  });
                }}
                className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
              >
                <Plus className="w-4 h-4" />
                Add Component
              </button>
            </div>

            {/* Add/Edit Component Form */}
            {showAddComponentForm && (
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
                <div className="grid grid-cols-12 gap-3">
                  <div className="col-span-5">
                    <Label htmlFor="component_item_id" className="text-xs" required>Component</Label>
                    
                    {/* Category Filter */}
                    <div className="mb-2">
                      <Label htmlFor="category_filter" className="text-xs text-gray-600 mb-1 block">
                        Filter by Category (Optional)
                      </Label>
                      <SelectShadcn
                        value={selectedCategoryFilter || '__all__'}
                        onValueChange={(value) => {
                          setSelectedCategoryFilter(value === '__all__' ? '' : value);
                          if (import.meta.env.DEV) {
                            console.log('📂 Category filter changed:', value === '__all__' ? 'all' : value);
                          }
                        }}
                      >
                        <SelectTrigger className="py-1.5 text-xs h-8">
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
                    
                    {/* Search Bar - Outside the Select */}
                    <div className="mb-2">
                      <div className="relative">
                        <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                        <Input
                          type="text"
                          placeholder="Search by SKU, name, category..."
                          value={componentSearchTerm}
                          onChange={(e) => {
                            setComponentSearchTerm(e.target.value);
                            if (import.meta.env.DEV) {
                              console.log('🔍 Search term changed:', e.target.value);
                            }
                          }}
                          className="pl-8 py-1.5 text-xs"
                          autoComplete="off"
                        />
                        {componentSearchTerm && (
                          <button
                            onClick={() => setComponentSearchTerm('')}
                            className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                            type="button"
                          >
                            <X className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                      {import.meta.env.DEV && (
                        <div className="mt-1 text-xs text-gray-400">
                          Found {filteredAndGroupedComponents.reduce((sum, g) => sum + g.items.length, 0)} components in {filteredAndGroupedComponents.length} categories
                        </div>
                      )}
                    </div>
                    <SelectShadcn
                      value={formData.component_item_id || ''}
                      onValueChange={(value) => {
                        console.log('📦 Component selected:', value);
                        setFormData({ ...formData, component_item_id: value });
                      }}
                    >
                      <SelectTrigger className="py-1 text-xs">
                        <SelectValue placeholder={formData.component_item_id ? "Component selected" : "Select component"} />
                      </SelectTrigger>
                      <SelectContent className="max-h-[400px]">
                        {/* Grouped Components by Category */}
                        {filteredAndGroupedComponents.length === 0 ? (
                          <div className="px-2 py-4 text-xs text-gray-500 text-center">
                            {componentSearchTerm.trim() || selectedCategoryFilter ? 'No components found' : 'No components available'}
                          </div>
                        ) : (
                          filteredAndGroupedComponents.map((group) => {
                            // Skip empty groups
                            if (!group.items || group.items.length === 0) {
                              return null;
                            }
                            
                            const groupKey = group.category.id || `uncategorized-${group.category.name}`;
                            
                            return (
                              <SelectGroup key={groupKey}>
                                <SelectLabel className="flex items-center gap-2 py-1.5 px-2 bg-gray-50">
                                  <Folder className="w-3.5 h-3.5 text-gray-500 flex-shrink-0" />
                                  <span className="font-semibold text-gray-900">{group.category.name}</span>
                                  {group.category.code && (
                                    <span className="text-gray-500 font-normal text-xs">({group.category.code})</span>
                                  )}
                                  <span className="text-gray-400 text-xs ml-auto">
                                    {group.items.length} item{group.items.length !== 1 ? 's' : ''}
                                  </span>
                                </SelectLabel>
                                {group.items.map((item) => (
                                  <SelectItem key={item.id} value={item.id}>
                                    {item.sku} - {item.name || item.item_name || 'Unnamed'}
                                  </SelectItem>
                                ))}
                              </SelectGroup>
                            );
                          })
                        )}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                  <div className="col-span-2">
                    <Label htmlFor="qty_per_unit" className="text-xs" required>Qty/Unit</Label>
                    <Input
                      id="qty_per_unit"
                      type="number"
                      step="0.0001"
                      value={formData.qty_per_unit}
                      onChange={(e) => setFormData({ ...formData, qty_per_unit: parseFloat(e.target.value) || 0 })}
                      className="py-1 text-xs"
                    />
                  </div>
                  <div className="col-span-2">
                    <Label htmlFor="uom" className="text-xs" required>UOM</Label>
                    <Input
                      id="uom"
                      value={formData.uom}
                      onChange={(e) => setFormData({ ...formData, uom: e.target.value })}
                      className="py-1 text-xs"
                      placeholder="unit"
                    />
                  </div>
                  <div className="col-span-2">
                    <Label htmlFor="sequence_order" className="text-xs">Order</Label>
                    <Input
                      id="sequence_order"
                      type="number"
                      value={formData.sequence_order}
                      onChange={(e) => setFormData({ ...formData, sequence_order: parseInt(e.target.value) || 0 })}
                      className="py-1 text-xs"
                    />
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
                      <Label htmlFor="is_required" className="text-xs mb-0">Required</Label>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2 mt-3">
                  <button
                    onClick={editingComponentId ? handleUpdateComponent : handleAddComponent}
                    className="px-3 py-1.5 text-xs bg-primary text-white rounded hover:opacity-90"
                  >
                    {editingComponentId ? 'Update' : 'Add'} Component
                  </button>
                  <button
                    onClick={() => {
                      setShowAddComponentForm(false);
                      setEditingComponentId(null);
                      setFormData({
                        component_item_id: '',
                        qty_per_unit: 1,
                        uom: 'unit',
                        is_required: true,
                        sequence_order: 0,
                      });
                      setComponentSearchTerm('');
                      setSelectedCategoryFilter('');
                    }}
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
                    {/* Category Header */}
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

                    {/* Components Table */}
                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead className="bg-gray-50 border-b border-gray-200">
                          <tr>
                            <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">Component</th>
                            <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Qty/Unit</th>
                            <th className="text-left py-2 px-4 text-xs font-semibold text-gray-900">UOM</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Required</th>
                            <th className="text-center py-2 px-4 text-xs font-semibold text-gray-900">Order</th>
                            <th className="text-right py-2 px-4 text-xs font-semibold text-gray-900">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {categoryGroup.components.map((component) => {
                            const componentItem = catalogItems.find(item => item.id === component.component_item_id);
                            // Also check if component has component_role (for fabric or rule-based components)
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
                                  {component.qty_per_unit?.toFixed(4) || '0.0000'}
                                </td>
                                <td className="py-2 px-4 text-xs text-gray-700">
                                  {component.uom || 'unit'}
                                </td>
                                <td className="py-2 px-4 text-xs text-center">
                                  <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                    component.is_required
                                      ? 'bg-green-100 text-green-800'
                                      : 'bg-gray-100 text-gray-800'
                                  }`}>
                                    {component.is_required ? 'Yes' : 'No'}
                                  </span>
                                </td>
                                <td className="py-2 px-4 text-xs text-gray-700 text-center">
                                  {component.sequence_order || 0}
                                </td>
                                <td className="py-2 px-4 text-right">
                                  <div className="flex items-center gap-1 justify-end">
                                    <button
                                      onClick={() => {
                                        console.log('🔍 Editing component:', component);
                                        setEditingComponentId(component.id);
                                        setFormData({
                                          component_item_id: component.component_item_id || '',
                                          qty_per_unit: component.qty_per_unit || 1,
                                          uom: component.uom || 'unit',
                                          is_required: component.is_required ?? true,
                                          sequence_order: component.sequence_order || 0,
                                        });
                                        setShowAddComponentForm(true);
                                        setComponentSearchTerm('');
                                        setSelectedCategoryFilter('');
                                      }}
                                      className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                      title="Edit component"
                                    >
                                      <Edit className="w-4 h-4" />
                                    </button>
                                    <button
                                      onClick={() => handleDeleteComponent(component.id)}
                                      className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                      title="Delete component"
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
    </div>
  );
}
