/**
 * useBOMTemplateOptionsSimple.ts
 * 
 * Hook para cargar opciones de SKUs desde BOMComponents (componentes padres).
 * SOPORTA FILTRADO PROGRESIVO: puede recibir templateIds pre-filtrados para
 * mostrar solo opciones que existen en esos templates específicos.
 * 
 * Flujo:
 * 1. ProductType + Color → Templates base
 * 2. Selección de Bottom Bar → Filtra templates
 * 3. Selección de HeadBox → Filtra más
 * 4. ... y así sucesivamente
 */

import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// ✅ Reglas según usuario: estos roles NO aplican color
const NON_COLOR_ROLES = new Set<string>(['motor', 'tube']);
// ✅ Reglas según usuario: estos roles SÍ aplican color
const COLOR_ROLES = new Set<string>(['bottom_bar', 'headbox', 'side_channel', 'bottom_channel', 'drive']);

export interface RoleOption {
  id: string;
  sku: string;
  name: string;
  image_url: string | null;
  color: string | null;
  cost_exw: number | null;
  category_id: string | null;
  /** IDs de templates que tienen este componente */
  templateIds?: string[];
  virtual?: boolean;
}

export interface RoleOptionsResult {
  options: RoleOption[];
  loading: boolean;
  error: string | null;
}

export interface TemplateFilterState {
  /** Templates base (filtrados por ProductType + Color) */
  baseTemplateIds: string[];
  /** Templates actualmente filtrados (después de selecciones) */
  currentTemplateIds: string[];
  /** Mapa de component_item_id -> template_ids que lo contienen */
  componentToTemplates: Map<string, Set<string>>;
}

/**
 * Hook principal para filtrado progresivo de templates.
 * Carga todos los templates y componentes base, luego permite filtrar progresivamente.
 */
export function useProgressiveTemplateFilter(
  productTypeId: string | null | undefined,
  hardwareColor: string | null | undefined
): {
  filterState: TemplateFilterState | null;
  loading: boolean;
  error: string | null;
  /** Filtra templates que contienen un componente específico (por SKU o ID) */
  filterByComponent: (role: string, componentItemId: string) => string[];
  /** Obtiene opciones para un rol, solo de los templates filtrados */
  getOptionsForRole: (role: string, filteredTemplateIds?: string[]) => Promise<RoleOption[]>;
  /** Resetea al estado base */
  reset: () => void;
} {
  const [filterState, setFilterState] = useState<TemplateFilterState | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  // Load base templates and all parent components
  useEffect(() => {
    if (!activeOrganizationId || !productTypeId) {
      setFilterState(null);
      setLoading(false);
      setError(null);
      return;
    }

    const normalizedColor = hardwareColor
      ? hardwareColor.trim().charAt(0).toUpperCase() + hardwareColor.trim().slice(1).toLowerCase()
      : null;

    const loadData = async () => {
      setLoading(true);
      setError(null);

      try {
        // Step 1: Get all active templates for ProductType
        // ✅ FIX: Primero buscar templates con color exacto, solo fallback a NULL si no hay
        let templates: Array<{ id: string; name: string; hardware_color: string | null }> = [];
        let templatesError: any = null;

        if (normalizedColor) {
          // Primero: buscar templates con el color EXACTO
          const { data: exactColorTemplates, error: exactError } = await supabase
            .from('BOMTemplates')
            .select('id, name, hardware_color')
            .eq('organization_id', activeOrganizationId)
            .eq('product_type_id', productTypeId)
            .eq('is_active', true)
            .eq('archived', false)
            .eq('hardware_color', normalizedColor);

          if (exactError) {
            templatesError = exactError;
          } else if (exactColorTemplates && exactColorTemplates.length > 0) {
            // Hay templates con color exacto → usar solo esos
            templates = exactColorTemplates;
            if (import.meta.env.DEV) {
              console.debug('[Progressive] Found templates with exact color match:', {
                color: normalizedColor,
                count: templates.length,
              });
            }
          } else {
            // No hay templates con color exacto → fallback a templates sin color (NULL)
            const { data: nullColorTemplates, error: nullError } = await supabase
              .from('BOMTemplates')
              .select('id, name, hardware_color')
              .eq('organization_id', activeOrganizationId)
              .eq('product_type_id', productTypeId)
              .eq('is_active', true)
              .eq('archived', false)
              .is('hardware_color', null);

            if (nullError) {
              templatesError = nullError;
            } else {
              templates = nullColorTemplates || [];
              if (import.meta.env.DEV) {
                console.warn('[Progressive] No exact color match, using NULL color templates as fallback:', {
                  requestedColor: normalizedColor,
                  count: templates.length,
                });
              }
            }
          }
        } else {
          // Sin color especificado → obtener todos los templates
          const { data: allTemplates, error: allError } = await supabase
            .from('BOMTemplates')
            .select('id, name, hardware_color')
            .eq('organization_id', activeOrganizationId)
            .eq('product_type_id', productTypeId)
            .eq('is_active', true)
            .eq('archived', false);

          templatesError = allError;
          templates = allTemplates || [];
        }

        if (templatesError) {
          throw new Error(templatesError.message);
        }

        if (!templates || templates.length === 0) {
          setFilterState({
            baseTemplateIds: [],
            currentTemplateIds: [],
            componentToTemplates: new Map(),
          });
          setLoading(false);
          return;
        }

        const templateIds = templates.map((t: { id: string }) => t.id);

        if (import.meta.env.DEV) {
          console.debug('[Progressive] Base templates loaded:', templateIds.length);
        }

        // Step 2: Get ALL parent components for these templates
        const { data: allComponents, error: componentsError } = await supabase
          .from('BOMComponents')
          .select('bom_template_id, component_item_id, component_role')
          .eq('organization_id', activeOrganizationId)
          .in('bom_template_id', templateIds)
          .is('parent_component_id', null) // Solo PADRES
          .eq('deleted', false)
          .eq('archived', false);

        if (componentsError) {
          throw new Error(componentsError.message);
        }

        // Build component -> templates map
        const componentToTemplates = new Map<string, Set<string>>();
        (allComponents || []).forEach((c: { component_item_id?: string; bom_template_id: string; component_role?: string }) => {
          if (c.component_item_id) {
            if (!componentToTemplates.has(c.component_item_id)) {
              componentToTemplates.set(c.component_item_id, new Set());
            }
            componentToTemplates.get(c.component_item_id)!.add(c.bom_template_id);
          }
        });

        if (import.meta.env.DEV) {
          console.debug('[Progressive] Components loaded:', allComponents?.length || 0);
          console.debug('[Progressive] Unique component_item_ids:', componentToTemplates.size);
        }

        setFilterState({
          baseTemplateIds: templateIds,
          currentTemplateIds: templateIds,
          componentToTemplates,
        });
      } catch (err: any) {
        console.error('[useProgressiveTemplateFilter] Error:', err?.message || err);
        setError(err?.message || 'Failed to load templates');
        setFilterState(null);
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, [activeOrganizationId, productTypeId, hardwareColor]);

  // Filter templates by component
  const filterByComponent = useCallback((role: string, componentItemId: string): string[] => {
    if (!filterState) return [];
    
    const templatesWithComponent = filterState.componentToTemplates.get(componentItemId);
    if (!templatesWithComponent) {
      if (import.meta.env.DEV) {
        console.warn('[Progressive] No templates found with component:', componentItemId, 'for role:', role);
      }
      return [];
    }

    // Intersect with current filtered templates
    const newFiltered = filterState.currentTemplateIds.filter(
      tid => templatesWithComponent.has(tid)
    );

    if (import.meta.env.DEV) {
      console.debug('[Progressive] filterByComponent', {
        role,
        componentItemId,
        before: filterState.currentTemplateIds.length,
        after: newFiltered.length,
      });
    }

    return newFiltered;
  }, [filterState]);

  // Get options for a role (from filtered templates)
  const getOptionsForRole = useCallback(async (
    role: string,
    filteredTemplateIds?: string[]
  ): Promise<RoleOption[]> => {
    if (!activeOrganizationId || !filterState) return [];

    const templateIds = filteredTemplateIds || filterState.currentTemplateIds;
    if (templateIds.length === 0) return [];

    const normalizedRole = role.toLowerCase().trim();

    try {
      // Get components for this role from the specified templates
      const { data: components, error: componentsError } = await supabase
        .from('BOMComponents')
        .select('component_item_id, bom_template_id')
        .eq('organization_id', activeOrganizationId)
        .in('bom_template_id', templateIds)
        .is('parent_component_id', null)
        .eq('deleted', false)
        .eq('archived', false);

      if (componentsError) {
        throw new Error(componentsError.message);
      }

      // Filter by role - we need to query again with role filter
      const { data: roleComponents, error: roleError } = await supabase
        .from('BOMComponents')
        .select('component_item_id, bom_template_id, component_role')
        .eq('organization_id', activeOrganizationId)
        .in('bom_template_id', templateIds)
        .is('parent_component_id', null)
        .eq('deleted', false)
        .eq('archived', false);

      if (roleError) {
        throw new Error(roleError.message);
      }

      // Filter by role case-insensitive
      const filteredComponents = (roleComponents || []).filter((c: { component_role: string }) =>
        (c.component_role || '').toLowerCase().trim() === normalizedRole
      );

      // Collect unique component_item_ids and track which templates have each
      const componentItemIds = new Set<string>();
      const itemToTemplates = new Map<string, string[]>();

      filteredComponents.forEach((c: { component_item_id: string; component_role: string; bom_template_id: string }) => {
        if (c.component_item_id) {
          componentItemIds.add(c.component_item_id);
          if (!itemToTemplates.has(c.component_item_id)) {
            itemToTemplates.set(c.component_item_id, []);
          }
          itemToTemplates.get(c.component_item_id)!.push(c.bom_template_id);
        }
      });

      if (componentItemIds.size === 0) {
        if (import.meta.env.DEV) {
          console.debug('[Progressive] No components for role:', normalizedRole);
        }
        return [];
      }

      // Fetch CatalogItems
      const { data: catalogItems, error: itemsError } = await supabase
        .from('CatalogItems')
        .select('id, sku, name, image_url, color, cost_exw, category_id')
        .in('id', Array.from(componentItemIds))
        .eq('organization_id', activeOrganizationId)
        .eq('is_active', true);

      if (itemsError) {
        throw new Error(itemsError.message);
      }

      // Build options with template IDs
      // ✅ SIMPLIFICADO: Usar item.id como key único (no normalizar SKU)
      const itemMap = new Map<string, RoleOption>();
      (catalogItems || []).forEach((item: any) => {
        if (!item.id || !item.sku) return;
        
        const key = item.id;
        const templateIds = itemToTemplates.get(item.id) || [];

        if (!itemMap.has(key)) {
          itemMap.set(key, {
            id: item.id,
            sku: item.sku, // SKU exacto sin normalizar
            name: item.name || item.sku,
            image_url: item.image_url ?? null,
            color: item.color ?? null,
            cost_exw: item.cost_exw ?? null,
            category_id: item.category_id ?? null,
            templateIds,
            virtual: false,
          });
        } else {
          // Merge template IDs (por si acaso)
          const existing = itemMap.get(key)!;
          existing.templateIds = [...new Set([...(existing.templateIds || []), ...templateIds])];
        }
      });

      const result = Array.from(itemMap.values()).sort((a, b) =>
        (a.name || '').localeCompare(b.name || '')
      );

      if (import.meta.env.DEV) {
        console.debug('[Progressive] Options for role', normalizedRole, ':', result.length);
      }

      return result;
    } catch (err: any) {
      console.error('[getOptionsForRole] Error:', err?.message || err);
      return [];
    }
  }, [activeOrganizationId, filterState]);

  // Reset to base state
  const reset = useCallback(() => {
    if (filterState) {
      setFilterState({
        ...filterState,
        currentTemplateIds: filterState.baseTemplateIds,
      });
    }
  }, [filterState]);

  return {
    filterState,
    loading,
    error,
    filterByComponent,
    getOptionsForRole,
    reset,
  };
}

/**
 * Hook simplificado para cargar opciones de SKUs para un rol específico.
 * AHORA SOPORTA filteredTemplateIds para filtrado progresivo.
 */
export function useBOMTemplateOptionsSimple(
  productTypeId: string | null | undefined,
  hardwareColor: string | null | undefined,
  role: string,
  /** Si se provee, solo busca en estos templates específicos */
  filteredTemplateIds?: string[] | null
): RoleOptionsResult {
  const [options, setOptions] = useState<RoleOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  // Memoize filteredTemplateIds to avoid infinite loops
  const templateIdsKey = useMemo(() => {
    if (!filteredTemplateIds) return 'all';
    // IMPORTANT: no mutar el array original (sort muta)
    return [...filteredTemplateIds].sort().join(',');
  }, [filteredTemplateIds]);

  useEffect(() => {
    if (!activeOrganizationId || !productTypeId || !role) {
      setOptions([]);
      setLoading(false);
      setError(null);
      return;
    }

    const normalizedRole = role.toLowerCase().trim();
    const requiresColor = COLOR_ROLES.has(normalizedRole) && !NON_COLOR_ROLES.has(normalizedRole);

    // Si requiere color y no hay color, retornar vacío (excepto si hay templateIds filtrados)
    if (requiresColor && !hardwareColor && !filteredTemplateIds) {
      setOptions([]);
      setLoading(false);
      setError(null);
      return;
    }

    const normalizedColor = hardwareColor
      ? hardwareColor.trim().charAt(0).toUpperCase() + hardwareColor.trim().slice(1).toLowerCase()
      : null;

    const fetchOptions = async () => {
      setLoading(true);
      setError(null);

      try {
        let templateIds: string[];

        if (filteredTemplateIds && filteredTemplateIds.length > 0) {
          // Usar los templates pre-filtrados
          templateIds = filteredTemplateIds;
          if (import.meta.env.DEV) {
            console.debug('[BOM] Using pre-filtered templates:', templateIds.length);
          }
        } else {
          // Buscar templates por ProductType + Color (match exacto primero)
          let templates: Array<{ id: string }> = [];
          let templatesError: any = null;

          if (requiresColor && normalizedColor) {
            const { data: exactTemplates, error: exactError } = await supabase
              .from('BOMTemplates')
              .select('id')
              .eq('organization_id', activeOrganizationId)
              .eq('product_type_id', productTypeId)
              .eq('is_active', true)
              .eq('archived', false)
              .eq('hardware_color', normalizedColor);

            if (exactError) {
              templatesError = exactError;
            } else if (exactTemplates && exactTemplates.length > 0) {
              templates = exactTemplates;
            } else {
              const { data: nullColorTemplates, error: nullError } = await supabase
                .from('BOMTemplates')
                .select('id')
                .eq('organization_id', activeOrganizationId)
                .eq('product_type_id', productTypeId)
                .eq('is_active', true)
                .eq('archived', false)
                .is('hardware_color', null);

              if (nullError) {
                templatesError = nullError;
              } else {
                templates = nullColorTemplates || [];
              }
            }
          } else {
            const { data: allTemplates, error: allError } = await supabase
              .from('BOMTemplates')
              .select('id')
              .eq('organization_id', activeOrganizationId)
              .eq('product_type_id', productTypeId)
              .eq('is_active', true)
              .eq('archived', false);

            templatesError = allError;
            templates = allTemplates || [];
          }

          if (templatesError) {
            throw new Error(templatesError.message);
          }

          if (!templates || templates.length === 0) {
            setOptions([]);
            setLoading(false);
            return;
          }

          templateIds = templates.map((t: { id: string }) => t.id);
        }

        if (templateIds.length === 0) {
          setOptions([]);
          setLoading(false);
          return;
        }

        if (import.meta.env.DEV) {
          console.debug(`[BOM] 📦 Loading role: ${normalizedRole}`, {
            templateCount: templateIds.length,
            templateIds: templateIds.slice(0, 3).join(', ') + (templateIds.length > 3 ? '...' : ''),
            hardwareColor: normalizedColor,
            productTypeId,
          });
        }

        // Get PARENT components from BOMComponents
        const { data: allComponents, error: componentsError } = await supabase
          .from('BOMComponents')
          .select('component_item_id, component_role, bom_template_id')
          .eq('organization_id', activeOrganizationId)
          .in('bom_template_id', templateIds)
          .is('parent_component_id', null)
          .eq('deleted', false)
          .eq('archived', false);

        if (componentsError) {
          throw new Error(componentsError.message);
        }

        // Filter by role case-insensitive
        const components = (allComponents || []).filter((c: { component_role: string; component_item_id?: string; bom_template_id: string }) =>
          (c.component_role || '').toLowerCase().trim() === normalizedRole
        );

        // Collect unique component_item_ids and track templates
        const componentItemIds = new Set<string>();
        const itemToTemplates = new Map<string, Set<string>>();

        components.forEach((c: { component_item_id: string; component_role: string; bom_template_id: string }) => {
          if (c.component_item_id) {
            componentItemIds.add(c.component_item_id);
            if (!itemToTemplates.has(c.component_item_id)) {
              itemToTemplates.set(c.component_item_id, new Set());
            }
            if (c.bom_template_id) {
              itemToTemplates.get(c.component_item_id)!.add(c.bom_template_id);
            }
          }
        });

        if (import.meta.env.DEV) {
          console.debug(`[BOM] 🔧 Components found for role ${normalizedRole}:`, {
            count: components.length,
            uniqueItems: componentItemIds.size,
            itemIds: Array.from(componentItemIds).slice(0, 3).join(', ') + (componentItemIds.size > 3 ? '...' : ''),
          });
        }

        if (componentItemIds.size === 0) {
          setOptions([]);
          setLoading(false);
          return;
        }

        // Fetch CatalogItems
        const { data: catalogItems, error: itemsError } = await supabase
          .from('CatalogItems')
          .select('id, sku, name, image_url, color, cost_exw, category_id')
          .in('id', Array.from(componentItemIds))
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true);

        if (itemsError) {
          throw new Error(itemsError.message);
        }

        if (import.meta.env.DEV) {
          console.debug(`[BOM] 📋 CatalogItems found for role ${normalizedRole}:`, {
            count: catalogItems?.length || 0,
            items: (catalogItems || []).slice(0, 3).map((i: any) => `${i.sku} (${i.name})`).join(', ') + ((catalogItems?.length || 0) > 3 ? '...' : ''),
          });
        }

        // Build options with template IDs
        // ✅ SIMPLIFICADO: Usar item.id como key único (no normalizar SKU)
        // Esto evita problemas de matching incorrecto y aprovecha que los datos vienen de la misma fuente
        const itemMap = new Map<string, RoleOption>();
        (catalogItems || []).forEach((item: any) => {
          if (!item.id || !item.sku) return;
          
          // Usar el ID del item como key único (garantiza no duplicados)
          const key = item.id;
          const templateIds = Array.from(itemToTemplates.get(item.id) || []);
          
          if (!itemMap.has(key)) {
            itemMap.set(key, {
              id: item.id,
              sku: item.sku, // SKU exacto sin normalizar
              name: item.name || item.sku,
              image_url: item.image_url ?? null,
              color: item.color ?? null,
              cost_exw: item.cost_exw ?? null,
              category_id: item.category_id ?? null,
              templateIds,
              virtual: false,
            });
          } else {
            // Merge template IDs (por si acaso)
            const existing = itemMap.get(key)!;
            existing.templateIds = [...new Set([...(existing.templateIds || []), ...templateIds])];
          }
        });

        const result = Array.from(itemMap.values()).sort((a, b) =>
          (a.name || '').localeCompare(b.name || '')
        );

        setOptions(result);

        if (import.meta.env.DEV) {
          console.debug('[BOM] options count', result.length, 'for role', normalizedRole);
        }
      } catch (err: any) {
        console.error('[useBOMTemplateOptionsSimple] Error:', err?.message || err);
        setError(err?.message || 'Failed to load options');
        setOptions([]);
      } finally {
        setLoading(false);
      }
    };

    fetchOptions();
  }, [activeOrganizationId, productTypeId, hardwareColor, role, templateIdsKey]);

  return { options, loading, error };
}

/**
 * Hook para cargar múltiples roles de una vez (optimizado).
 * AHORA SOPORTA filteredTemplateIds para filtrado progresivo.
 */
export function useBOMTemplateAllRoleOptions(
  productTypeId: string | null | undefined,
  hardwareColor: string | null | undefined,
  roles: string[],
  filteredTemplateIds?: string[] | null
): {
  optionsByRole: Map<string, RoleOption[]>;
  loading: boolean;
  error: string | null;
} {
  const [optionsByRole, setOptionsByRole] = useState<Map<string, RoleOption[]>>(new Map());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const rolesKey = useMemo(() => roles.join(','), [roles]);
  const templateIdsKey = useMemo(() => {
    if (!filteredTemplateIds) return 'all';
    return [...filteredTemplateIds].sort().join(',');
  }, [filteredTemplateIds]);

  useEffect(() => {
    if (!activeOrganizationId || !productTypeId || roles.length === 0) {
      setOptionsByRole(new Map());
      setLoading(false);
      setError(null);
      return;
    }

    const allNonColor = roles.every(r => NON_COLOR_ROLES.has(r.toLowerCase().trim()));
    if (!allNonColor && !hardwareColor && !filteredTemplateIds) {
      setOptionsByRole(new Map());
      setLoading(false);
      setError(null);
      return;
    }

    const normalizedColor = hardwareColor
      ? hardwareColor.trim().charAt(0).toUpperCase() + hardwareColor.trim().slice(1).toLowerCase()
      : null;

    const fetchAllOptions = async () => {
      setLoading(true);
      setError(null);

      try {
        let templateIds: string[];

        if (filteredTemplateIds && filteredTemplateIds.length > 0) {
          templateIds = filteredTemplateIds;
        } else {
          let templates: Array<{ id: string }> = [];
          let templatesError: any = null;

          if (!allNonColor && normalizedColor) {
            const { data: exactTemplates, error: exactError } = await supabase
              .from('BOMTemplates')
              .select('id')
              .eq('organization_id', activeOrganizationId)
              .eq('product_type_id', productTypeId)
              .eq('is_active', true)
              .eq('archived', false)
              .eq('hardware_color', normalizedColor);

            if (exactError) {
              templatesError = exactError;
            } else if (exactTemplates && exactTemplates.length > 0) {
              templates = exactTemplates;
            } else {
              const { data: nullColorTemplates, error: nullError } = await supabase
                .from('BOMTemplates')
                .select('id')
                .eq('organization_id', activeOrganizationId)
                .eq('product_type_id', productTypeId)
                .eq('is_active', true)
                .eq('archived', false)
                .is('hardware_color', null);

              if (nullError) {
                templatesError = nullError;
              } else {
                templates = nullColorTemplates || [];
              }
            }
          } else {
            const { data: allTemplates, error: allError } = await supabase
              .from('BOMTemplates')
              .select('id')
              .eq('organization_id', activeOrganizationId)
              .eq('product_type_id', productTypeId)
              .eq('is_active', true)
              .eq('archived', false);

            templatesError = allError;
            templates = allTemplates || [];
          }

          if (templatesError) {
            throw new Error(templatesError.message);
          }

          if (!templates || templates.length === 0) {
            setOptionsByRole(new Map());
            setLoading(false);
            return;
          }

          templateIds = templates.map((t: { id: string }) => t.id);
        }

        if (templateIds.length === 0) {
          setOptionsByRole(new Map());
          setLoading(false);
          return;
        }

        // Get ALL parent components
        const normalizedRoles = roles.map(r => r.toLowerCase().trim());

        const { data: allComponents, error: componentsError } = await supabase
          .from('BOMComponents')
          .select('component_item_id, component_role, bom_template_id')
          .eq('organization_id', activeOrganizationId)
          .in('bom_template_id', templateIds)
          .is('parent_component_id', null)
          .eq('deleted', false)
          .eq('archived', false);

        if (componentsError) {
          throw new Error(componentsError.message);
        }

        // Filter and group by role
        const componentIdsByRole = new Map<string, Map<string, Set<string>>>();
        normalizedRoles.forEach((r: string) => componentIdsByRole.set(r, new Map()));

        (allComponents || []).forEach((c: { component_item_id?: string; bom_template_id: string; component_role?: string }) => {
          const compRole = (c.component_role || '').toLowerCase().trim();
          if (normalizedRoles.includes(compRole) && c.component_item_id) {
            const roleMap = componentIdsByRole.get(compRole)!;
            if (!roleMap.has(c.component_item_id)) {
              roleMap.set(c.component_item_id, new Set());
            }
            if (c.bom_template_id) {
              roleMap.get(c.component_item_id)!.add(c.bom_template_id);
            }
          }
        });

        // Get all unique component_item_ids
        const allComponentItemIds = new Set<string>();
        componentIdsByRole.forEach(roleMap => {
          roleMap.forEach((_, id) => allComponentItemIds.add(id));
        });

        if (allComponentItemIds.size === 0) {
          setOptionsByRole(new Map());
          setLoading(false);
          return;
        }

        // Fetch all CatalogItems
        const { data: catalogItems, error: itemsError } = await supabase
          .from('CatalogItems')
          .select('id, sku, name, image_url, color, cost_exw, category_id')
          .in('id', Array.from(allComponentItemIds))
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true);

        if (itemsError) {
          throw new Error(itemsError.message);
        }

        // Build item map
        const itemById = new Map<string, any>();
        (catalogItems || []).forEach((item: { id: string; sku: string; name: string }) => {
          if (item.sku) {
            itemById.set(item.id, item);
          }
        });

        // Build result by role
        // ✅ SIMPLIFICADO: Usar item.id como key único (no normalizar SKU)
        const result = new Map<string, RoleOption[]>();
        normalizedRoles.forEach(role => {
          const roleMap = componentIdsByRole.get(role)!;
          const itemMap = new Map<string, RoleOption>();

          roleMap.forEach((templateIdsSet, itemId) => {
            const item = itemById.get(itemId);
            if (item && item.id && item.sku) {
              const templateIds = Array.from(templateIdsSet);
              if (!itemMap.has(itemId)) {
                itemMap.set(itemId, {
                  id: item.id,
                  sku: item.sku, // SKU exacto sin normalizar
                  name: item.name || item.sku,
                  image_url: item.image_url,
                  color: item.color,
                  cost_exw: item.cost_exw,
                  category_id: item.category_id,
                  templateIds,
                });
              } else {
                const existing = itemMap.get(itemId)!;
                existing.templateIds = [...new Set([...(existing.templateIds || []), ...templateIds])];
              }
            }
          });

          result.set(role, Array.from(itemMap.values()).sort((a, b) =>
            (a.name || '').localeCompare(b.name || '')
          ));
        });

        setOptionsByRole(result);

        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplateAllRoleOptions] Loaded options', {
            roles: normalizedRoles,
            templatesCount: templateIds.length,
            optionCounts: Object.fromEntries(
              Array.from(result.entries()).map(([r, opts]) => [r, opts.length])
            ),
          });
        }
      } catch (err: any) {
        console.error('[useBOMTemplateAllRoleOptions] Error:', err?.message || err);
        setError(err?.message || 'Failed to load options');
        setOptionsByRole(new Map());
      } finally {
        setLoading(false);
      }
    };

    fetchAllOptions();
  }, [activeOrganizationId, productTypeId, hardwareColor, rolesKey, templateIdsKey]);

  return { optionsByRole, loading, error };
}

/**
 * Utility: Filtra template IDs por un componente seleccionado
 */
export function filterTemplatesByComponent(
  currentTemplateIds: string[],
  selectedOption: RoleOption | null
): string[] {
  if (!selectedOption || !selectedOption.templateIds) {
    return currentTemplateIds;
  }
  
  const selectedTemplates = new Set(selectedOption.templateIds);
  return currentTemplateIds.filter(tid => selectedTemplates.has(tid));
}
