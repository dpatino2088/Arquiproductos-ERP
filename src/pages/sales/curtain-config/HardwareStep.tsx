/**
 * Hardware Step - FILTRADO PROGRESIVO
 * 
 * ✅ NUEVA ARQUITECTURA:
 * - Cards se cargan desde BOMComponents para ProductType + Color
 * - Cada selección FILTRA los templates disponibles para el siguiente paso
 * - El usuario solo puede configurar productos que existen como templates
 * 
 * Componentes:
 * - Hardware Color (White/Black/Silver) - static cards
 * - Bottom Bar - desde templates del ProductType + Color, filtra para siguientes
 * - Headbox/Cassette - desde templates filtrados por Bottom Bar
 * - Side Channel - desde templates filtrados (opcional)
 * - Bottom Channel - desde templates filtrados (opcional)
 * 
 * IMPORTANT:
 * - Colors in DB are CAPITALIZED: 'White', 'Black', 'Silver'
 * - Cada opción incluye templateIds para filtrado progresivo
 * 
 * E) Edit prefill: Do NOT clear *_item_id or *_sku when options are still loading.
 * Only clear selection when options have loaded AND the itemId is not in the list.
 * (Avoids losing headbox/side_channel/bottom_channel selection on Edit open.)
 */

import { useEffect, useMemo, useRef, useState } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { useBOMTemplateOptionsSimple, filterTemplatesByComponent, RoleOption } from '../../../hooks/useBOMTemplateOptionsSimple';
import { Image as ImageIcon, X } from 'lucide-react';
import CatalogItemImage from '../../../components/ui/CatalogItemImage';
import { RoleSelection, toRoleSelection } from '../../../lib/bom/selection';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useUIStore } from '../../../stores/ui-store';
import { supabase } from '../../../lib/supabase/client';

interface HardwareStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (
    updates:
      | Partial<CurtainConfiguration | ProductConfig>
      | ((prev: CurtainConfiguration | ProductConfig) => Partial<CurtainConfiguration | ProductConfig>)
  ) => void;
  /** Templates filtrados desde pasos anteriores (opcionales) */
  filteredTemplateIds?: string[];
}

// Hardware Color options (CAPITALIZED to match DB)
const HARDWARE_COLOR_OPTIONS = [
  { id: 'White', name: 'White', color: '#FFFFFF' },
  { id: 'Black', name: 'Black', color: '#000000' },
  { id: 'Silver', name: 'Silver', color: '#C0C0C0' },
];

// HEADBOX_POLICY removed — headbox requirement is now data-driven from BOMComponents.is_required

export default function HardwareStep({ config, onUpdate, filteredTemplateIds }: HardwareStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;
  
  const productType = (config as any).productType || (config as any).product_type || '';
  const isRollerShade = productType === 'roller_shade' || productType === 'roller-shade' || productType === 'ROLLER';

  // headboxPolicy is derived from BOM data after headboxOptions load (see below)

  const showHardwareColor = true;
  // showCassette / showSideChannel are now derived after options load (see below)
  
  const mfrFilteredTemplates: string[] | null = Array.isArray((config as any)._manufacturer_filtered_templates)
    ? (config as any)._manufacturer_filtered_templates
    : null;
  const configManufacturer: string | undefined = (config as any).manufacturer;

  const applyMfrConstraint = (q: any) => {
    if (mfrFilteredTemplates && mfrFilteredTemplates.length > 0) return q.in('id', mfrFilteredTemplates);
    if (configManufacturer) return q.ilike('manufacturer', configManufacturer);
    return q;
  };

  // When the prop filteredTemplateIds is missing (edit/duplicate) but manufacturer
  // is known, derive template IDs so every downstream hook is manufacturer-scoped.
  const [mfrDerivedTemplateIds, setMfrDerivedTemplateIds] = useState<string[] | null>(null);

  useEffect(() => {
    if (filteredTemplateIds && filteredTemplateIds.length > 0) {
      setMfrDerivedTemplateIds(null);
      return;
    }
    if (!configManufacturer || !activeOrganizationId || !productTypeId) {
      setMfrDerivedTemplateIds(null);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase
        .from('BOMTemplates')
        .select('id')
        .eq('organization_id', activeOrganizationId)
        .eq('product_type_id', productTypeId)
        .ilike('manufacturer', configManufacturer)
        .eq('is_active', true)
        .eq('archived', false);
      if (!cancelled && !error) {
        const ids = (data || []).map((t: { id: string }) => t.id);
        setMfrDerivedTemplateIds(ids.length > 0 ? ids : null);
        if (import.meta.env.DEV) {
          console.debug('[HardwareStep] Derived mfr templates:', { manufacturer: configManufacturer, count: ids.length });
        }
      }
    })();
    return () => { cancelled = true; };
  }, [filteredTemplateIds, configManufacturer, activeOrganizationId, productTypeId]);

  const effectiveFilteredTemplateIds = filteredTemplateIds ?? mfrDerivedTemplateIds ?? undefined;

  const loadTemplatesForColor = async (color: string): Promise<string[]> => {
    if (!activeOrganizationId || !productTypeId) return [];
    
    const normalizedColor = color.trim().charAt(0).toUpperCase() + color.trim().slice(1).toLowerCase();
    
    let query = supabase
      .from('BOMTemplates')
      .select('id')
      .eq('organization_id', activeOrganizationId)
      .eq('product_type_id', productTypeId)
      .eq('hardware_color', normalizedColor)
      .eq('is_active', true)
      .eq('archived', false);

    query = applyMfrConstraint(query);
    
    const { data: templates, error } = await query;
    
    if (error) {
      console.error('[HardwareStep] Error loading templates for color:', error);
      return [];
    }
    
    if (!templates || templates.length === 0) {
      let fallbackQuery = supabase
        .from('BOMTemplates')
        .select('id')
        .eq('organization_id', activeOrganizationId)
        .eq('product_type_id', productTypeId)
        .is('hardware_color', null)
        .eq('is_active', true)
        .eq('archived', false);

      fallbackQuery = applyMfrConstraint(fallbackQuery);

      const { data: nullTemplates } = await fallbackQuery;
      return (nullTemplates || []).map((t: { id: string }) => t.id);
    }
    
    return templates.map((t: { id: string }) => t.id);
  };
  
  // Get current selections (CAPITALIZED)
  const currentHardwareColor = (config as any).hardwareColor || (config as any).hardware_color || (config as any).operatingSystemColor || null;
  const cassetteShape = (config as any).cassette_shape || 'none';

  // Helpers
  const normSku = (v: unknown): string => String(v ?? '').trim().toLowerCase();

  // Log solo primitivos (evitar [circular] en consola)
  const cfg = config as any;
  console.log('[HardwareStep] config', String(cfg.hardware_color ?? 'MISSING'), String(cfg.bottom_bar_sku ?? 'MISSING'), String(cfg.bottom_bar_item_id ?? 'MISSING'));

  const DEBUG_PREFILL = import.meta.env.DEV && (typeof window !== 'undefined' && (window as any).__DEBUG_PREFILL === true);
  const userInteractedRef = useRef(false);
  const prefillAppliedRef = useRef(false);
  
  // ✅ Helpers para RoleSelection
  const headboxSelection: RoleSelection = toRoleSelection(
    (config as any).headbox_sku,
    (config as any).headbox_item_id
  );
  
  const sideChannelSelection: RoleSelection = toRoleSelection(
    (config as any).side_channel_sku,
    (config as any).side_channel_item_id
  );
  
  const bottomChannelSelection: RoleSelection = toRoleSelection(
    (config as any).bottom_channel_sku,
    (config as any).bottom_channel_item_id
  );

  const uniq = (ids: string[] | null | undefined): string[] | null => {
    if (!ids) return null;
    const u = Array.from(new Set(ids.filter(Boolean)));
    return u.length > 0 ? u : null;
  };

  /** Returns template IDs that do NOT have the given role (in-memory: exclude IDs present in templatesWithRole set). */
  const filterTemplatesWithoutRole = (
    candidateIds: string[] | null | undefined,
    templatesWithRole: Set<string>
  ): string[] | null => {
    if (!candidateIds || candidateIds.length === 0) return null;
    if (templatesWithRole.size === 0) return [...candidateIds];
    const out = candidateIds.filter(tid => !templatesWithRole.has(tid));
    return out.length > 0 ? out : null;
  };

  const notifyError = (message: string) => {
    useUIStore.getState().addNotification({
      type: 'error',
      title: 'BOM Selection',
      message,
    });
  };

  // ✅ ConfiguredProduct-based flow: selections are local until "Add to Quote".
  // Only require an organization context (quote_line_id is not needed anymore).
  const selectionDisabled = !activeOrganizationId;

  const ensurePersistable = (): boolean => {
    if (!activeOrganizationId) {
      notifyError('Organization not ready. Please select an organization before configuring products.');
      return false;
    }
    return true;
  };

  const persistSelection = async (componentRole: string, catalogItemId: string) => {
    if (!ensurePersistable()) return false;
    // No-op (ConfiguredProduct snapshot will be created at completion).
    return true;
  };

  const removeSelection = async (componentRole: string) => {
    if (!ensurePersistable()) return false;
    // No-op (ConfiguredProduct snapshot will be created at completion).
    return true;
  };

  // ✅ Helpers UI para manejar selecciones
  const setHeadboxNone = async () => {
    const ok = await removeSelection('headbox');
    if (!ok) return;
    onUpdate({
      headbox_item_id: null,
      headbox_sku: null,
      cassette: false,
      cassette_shape: 'none',
    } as any);
  };
  
  /** X button: leave headbox UNSET (null), do NOT set NONE */
  const clearHeadboxSelection = async () => {
    const ok = await removeSelection('headbox');
    if (!ok) return;
    onUpdate({
      headbox_item_id: null,
      headbox_sku: null,
      cassette: false,
      cassette_shape: 'none',
    } as any);
  };
  
  const setHeadboxSelected = async (item: RoleOption) => {
    const id = String(item.id);
    const isVirtual = id.startsWith('sku:');
    if (isVirtual) {
      notifyError('Invalid headbox selection (virtual SKU).');
      return;
    }
    const ok = await persistSelection('headbox', id);
    if (!ok) return;
    // ✅ Calcular templates filtrados: intersección con los actuales
    let newFilteredTemplates = item.templateIds || [];
    const currentFiltered = (config as any)._hardware_filtered_templates as string[] | undefined;
    
    if (currentFiltered && currentFiltered.length > 0 && newFilteredTemplates.length > 0) {
      const set = new Set(newFilteredTemplates);
      newFilteredTemplates = currentFiltered.filter(tid => set.has(tid));
    }
    
    if (import.meta.env.DEV) {
      console.debug('[HardwareStep] Headbox selected:', {
        sku: item.sku,
        templateIds: newFilteredTemplates.length,
      });
    }
    
    onUpdate({
      headbox_item_id: item.id,
      headbox_sku: item.sku ? String(item.sku).trim() : null,
      cassette: true,
      cassette_shape: 'standard',
      cassette_type: 'standard',
      // ✅ Guardar templates filtrados
      _hardware_filtered_templates: uniq(newFilteredTemplates) ?? uniq(currentFiltered) ?? null,
    } as any);
  };
  
  // Panel count (1-3) for BOM template filtering (before color)
  const panelCount = (config as any).measurements?.panel_count ?? (config as any).panels?.length ?? 1;
  const hasHardwareColor = !!currentHardwareColor;
  
  // ✅ Bottom Bar: desde TODOS los templates del ProductType + panel_count + Color (primer filtro)
  const { options: bottomBarOptions, loading: loadingBottomBar, error: bottomBarError } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'bottom_bar',
    effectiveFilteredTemplateIds,
    panelCount
  );
  
  // ✅ Calcular templates filtrados por bottom_bar seleccionado
  const selectedBottomBar =
    bottomBarOptions.find((opt) => opt.id === (config as any).bottom_bar_item_id) ||
    // Fallback: legacy/mixed IDs (global vs org). If SKU matches, treat as selected.
    (normSku((config as any).bottom_bar_sku) ? bottomBarOptions.find((opt) => normSku(opt.sku) === normSku((config as any).bottom_bar_sku)) : undefined);

  // Prefill robusto (race-safe): aplicar UNA sola vez cuando options cargaron y hay bottom_bar_sku guardado.
  useEffect(() => {
    if (userInteractedRef.current) return;
    if (prefillAppliedRef.current) return;
    if (loadingBottomBar) return;
    if (!bottomBarOptions || bottomBarOptions.length === 0) return;
    const cfg: any = config as any;
    const cfgSku = normSku(cfg.bottom_bar_sku);
    if (!cfgSku) return;

    const hasId = typeof cfg.bottom_bar_item_id === 'string' && cfg.bottom_bar_item_id.trim().length > 0;
    const idMatches = hasId && bottomBarOptions.some((opt) => opt.id === cfg.bottom_bar_item_id);
    if (idMatches) {
      prefillAppliedRef.current = true;
      return;
    }

    const bySku = bottomBarOptions.find((opt) => normSku(opt.sku) === cfgSku);
    if (!bySku) return;

    prefillAppliedRef.current = true;
    if (DEBUG_PREFILL || import.meta.env.DEV) {
      console.debug('[HardwareStep] Prefill applied (once): bottom_bar from SKU', { bottom_bar_sku: cfg.bottom_bar_sku, bottom_bar_item_id: bySku.id });
    }
    onUpdate({
      bottom_bar_item_id: String(bySku.id),
      bottom_bar_sku: (bySku.sku || '').trim() || cfg.bottom_bar_sku,
    } as any);
  }, [loadingBottomBar, bottomBarOptions, config, onUpdate]);

  const savedSku = (config as any).bottom_bar_sku;
  const savedId = (config as any).bottom_bar_item_id;
  const bottomBarSkuInOptions = bottomBarOptions.some((o) => normSku(o.sku) === normSku(savedSku));
  const pinnedOption: RoleOption | null =
    savedSku && !bottomBarSkuInOptions
      ? {
          id: savedId ?? `pinned:${(savedSku || '').trim()}`,
          sku: typeof savedSku === 'string' ? savedSku.trim() : String(savedSku ?? ''),
          name: 'Bottom Bar (Saved)',
          image_url: null,
          color: null,
          cost_exw: null,
          category_id: null,
          templateIds: undefined,
          virtual: true,
        }
      : null;
  if (pinnedOption) (pinnedOption as any).__pinned = true;
  const optionsToRender: RoleOption[] = pinnedOption ? [pinnedOption, ...bottomBarOptions] : bottomBarOptions;

  if (DEBUG_PREFILL && pinnedOption) {
    console.log('[HardwareStep] bottom_bar_sku saved but not in options', {
      bottom_bar_sku: savedSku,
      available_skus: bottomBarOptions.slice(0, 10).map((o) => o.sku),
    });
  }

  const templatesAfterBottomBar = useMemo(() => {
    if (!selectedBottomBar || !selectedBottomBar.templateIds) {
      return effectiveFilteredTemplateIds || null;
    }
    if (effectiveFilteredTemplateIds) {
      const set = new Set(selectedBottomBar.templateIds);
      return effectiveFilteredTemplateIds.filter(tid => set.has(tid));
    }
    return selectedBottomBar.templateIds;
  }, [selectedBottomBar, effectiveFilteredTemplateIds]);
  
  // ✅ Headbox: desde templates filtrados por Bottom Bar
  const { options: headboxOptions, loading: loadingHeadbox, roleRequired: headboxIsRequired } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'headbox',
    templatesAfterBottomBar,
    panelCount
  );
  
  // Data-driven policies: derived from BOMComponents.is_required
  const headboxPolicy: 'required' | 'optional' | 'none' =
    headboxOptions.length === 0 && !loadingHeadbox ? 'none' :
    headboxIsRequired ? 'required' : 'optional';
  const showCassette = headboxOptions.length > 0 || loadingHeadbox;

  // ✅ Tri-state: UNSET (null/undefined) | NONE ('NONE') | SELECTED (uuid)
  const headboxItemId = (config as any).headbox_item_id;
  const selectedHeadbox = headboxOptions.find(opt => String(opt.id) === String(headboxItemId));
  const headboxItemIdInOptions = headboxOptions.some((o) => String(o.id) === String(headboxItemId));
  const pinnedHeadbox: RoleOption | null =
    headboxItemId && String(headboxItemId) !== 'NONE' && !headboxItemIdInOptions
      ? {
          id: String(headboxItemId),
          sku: (config as any).headbox_sku ?? '',
          name: 'Headbox (Saved)',
          image_url: null,
          color: null,
          cost_exw: null,
          category_id: null,
          templateIds: undefined,
          virtual: true,
        }
      : null;
  if (pinnedHeadbox) (pinnedHeadbox as any).__pinned = true;
  const headboxOptionsToRender: RoleOption[] = pinnedHeadbox ? [pinnedHeadbox, ...headboxOptions] : headboxOptions;
  
  // ✅ Solo templates donde el rol es REQUERIDO (is_required=true).
  // Usado al elegir NONE: si el rol es opcional, el template puede vivir sin él.
  const templatesWithRequiredHeadbox = useMemo(() => {
    const ids = new Set<string>();
    headboxOptions.forEach(opt => {
      if (opt.requiredTemplateIds) {
        opt.requiredTemplateIds.forEach(tid => ids.add(tid));
      }
    });
    return ids;
  }, [headboxOptions]);
  
  const templatesAfterHeadbox = useMemo(() => {
    const prev = templatesAfterBottomBar;
    if (!prev) return null;
    // SELECTED (uuid): filtrar a templates que tienen ese SKU
    if (typeof headboxItemId === 'string' && headboxItemId !== 'NONE' && selectedHeadbox?.templateIds) {
      const set = new Set(selectedHeadbox.templateIds);
      return prev.filter(tid => set.has(tid));
    }
    // NONE (explícito): solo dropear templates que REQUIEREN headbox.
    // Templates con headbox opcional permanecen (pueden configurarse sin headbox).
    if (headboxItemId === 'NONE') {
      return filterTemplatesWithoutRole(prev, templatesWithRequiredHeadbox) ?? prev;
    }
    // UNSET (null/undefined): NO filtrar por headbox
    return prev;
  }, [headboxItemId, selectedHeadbox, templatesAfterBottomBar, templatesWithRequiredHeadbox]);
  
  // ✅ Side Channel: desde templates filtrados
  const { options: sideChannelOptions, loading: loadingSideChannel, roleRequired: sideChannelIsRequired } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'side_channel',
    templatesAfterHeadbox,
    panelCount
  );
  const showSideChannel = sideChannelOptions.length > 0 || loadingSideChannel;
  
  const sideChannelItemId = (config as any).side_channel_item_id;
  const selectedSideChannel = sideChannelOptions.find(opt => String(opt.id) === String(sideChannelItemId));
  const sideChannelItemIdInOptions = sideChannelOptions.some((o) => String(o.id) === String(sideChannelItemId));
  const pinnedSideChannel: RoleOption | null =
    sideChannelItemId && String(sideChannelItemId) !== 'NONE' && !sideChannelItemIdInOptions
      ? {
          id: String(sideChannelItemId),
          sku: (config as any).side_channel_sku ?? '',
          name: 'Side Channel (Saved)',
          image_url: null,
          color: null,
          cost_exw: null,
          category_id: null,
          templateIds: undefined,
          virtual: true,
        }
      : null;
  if (pinnedSideChannel) (pinnedSideChannel as any).__pinned = true;
  const sideChannelOptionsToRender: RoleOption[] = pinnedSideChannel ? [pinnedSideChannel, ...sideChannelOptions] : sideChannelOptions;
  
  // ✅ Solo templates donde side_channel es REQUERIDO. NONE no debe excluir templates con rol opcional.
  const templatesWithRequiredSideChannel = useMemo(() => {
    const ids = new Set<string>();
    sideChannelOptions.forEach(opt => {
      if (opt.requiredTemplateIds) {
        opt.requiredTemplateIds.forEach(tid => ids.add(tid));
      }
    });
    return ids;
  }, [sideChannelOptions]);
  
  const templatesAfterSideChannel = useMemo(() => {
    const prev = templatesAfterHeadbox;
    if (!prev) return null;
    if (typeof sideChannelItemId === 'string' && sideChannelItemId !== 'NONE' && selectedSideChannel?.templateIds) {
      const set = new Set(selectedSideChannel.templateIds);
      return prev.filter(tid => set.has(tid));
    }
    if (sideChannelItemId === 'NONE') {
      return filterTemplatesWithoutRole(prev, templatesWithRequiredSideChannel) ?? prev;
    }
    return prev;
  }, [sideChannelItemId, selectedSideChannel, templatesAfterHeadbox, templatesWithRequiredSideChannel]);
  
  // ✅ Bottom Channel: desde templates filtrados
  const { options: bottomChannelOptions, loading: loadingBottomChannel, roleRequired: bottomChannelIsRequired } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'bottom_channel',
    templatesAfterSideChannel,
    panelCount
  );
  
  const bottomChannelItemId = (config as any).bottom_channel_item_id;
  const selectedBottomChannel = bottomChannelOptions.find(opt => String(opt.id) === String(bottomChannelItemId));
  const bottomChannelItemIdInOptions = bottomChannelOptions.some((o) => String(o.id) === String(bottomChannelItemId));
  const pinnedBottomChannel: RoleOption | null =
    bottomChannelItemId && String(bottomChannelItemId) !== 'NONE' && !bottomChannelItemIdInOptions
      ? {
          id: String(bottomChannelItemId),
          sku: (config as any).bottom_channel_sku ?? '',
          name: 'Bottom Channel (Saved)',
          image_url: null,
          color: null,
          cost_exw: null,
          category_id: null,
          templateIds: undefined,
          virtual: true,
        }
      : null;
  if (pinnedBottomChannel) (pinnedBottomChannel as any).__pinned = true;
  const bottomChannelOptionsToRender: RoleOption[] = pinnedBottomChannel ? [pinnedBottomChannel, ...bottomChannelOptions] : bottomChannelOptions;
  
  // ✅ Solo templates donde bottom_channel es REQUERIDO. NONE no debe excluir templates con rol opcional.
  const templatesWithRequiredBottomChannel = useMemo(() => {
    const ids = new Set<string>();
    bottomChannelOptions.forEach(opt => {
      if (opt.requiredTemplateIds) {
        opt.requiredTemplateIds.forEach(tid => ids.add(tid));
      }
    });
    return ids;
  }, [bottomChannelOptions]);
  
  const finalFilteredTemplates = useMemo(() => {
    const prev = templatesAfterSideChannel;
    if (!prev) return null;
    if (typeof bottomChannelItemId === 'string' && bottomChannelItemId !== 'NONE' && selectedBottomChannel?.templateIds) {
      const set = new Set(selectedBottomChannel.templateIds);
      return prev.filter(tid => set.has(tid));
    }
    if (bottomChannelItemId === 'NONE') {
      return filterTemplatesWithoutRole(prev, templatesWithRequiredBottomChannel) ?? prev;
    }
    return prev;
  }, [bottomChannelItemId, selectedBottomChannel, templatesAfterSideChannel, templatesWithRequiredBottomChannel]);
  
  // ✅ Guardar templates filtrados en config para el siguiente step
  useEffect(() => {
    if (finalFilteredTemplates && finalFilteredTemplates.length > 0) {
      const currentSaved = (config as any)._hardware_filtered_templates;
      const deduped = [...new Set(finalFilteredTemplates)];
      const newValue = JSON.stringify([...deduped].sort());
      const oldValue = currentSaved ? JSON.stringify(currentSaved.sort()) : '';
      
      if (newValue !== oldValue) {
        onUpdate({
          _hardware_filtered_templates: deduped,
        } as any);
      }
    }
  }, [finalFilteredTemplates]);
  
  // Sync hardware role policies into config so validation can read them
  useEffect(() => {
    if (loadingHeadbox || loadingSideChannel) return;
    const updates: any = {};
    if ((config as any)._headboxPolicy !== headboxPolicy) updates._headboxPolicy = headboxPolicy;
    const scPolicy: 'required' | 'optional' | 'none' =
      (!isRollerShade || !showSideChannel) ? 'none' : sideChannelIsRequired ? 'required' : 'optional';
    if ((config as any)._sideChannelPolicy !== scPolicy) updates._sideChannelPolicy = scPolicy;
    if (Object.keys(updates).length > 0) onUpdate(updates);
  }, [headboxPolicy, showSideChannel, sideChannelIsRequired, loadingHeadbox, loadingSideChannel]);

  // When Side Channel is deselected, cascade to Bottom Channel
  useEffect(() => {
    if (!isRollerShade) return;
    const scId = (config as any).side_channel_item_id;
    const bcId = (config as any).bottom_channel_item_id;
    if ((scId === 'NONE' || scId == null) && bcId != null && bcId !== 'NONE') {
      onUpdate({
        bottom_channel_item_id: 'NONE',
        bottom_channel_sku: null,
        bottom_channel: false,
      } as any);
    }
  }, [(config as any).side_channel_item_id]);

  // ✅ DEBUG: Tri-state y conteos (solo dev)
  if (import.meta.env.DEV && hasHardwareColor && !loadingBottomBar) {
    const headboxState = headboxItemId == null ? 'UNSET' : headboxItemId === 'NONE' ? 'NONE' : 'SELECTED';
    const sideChannelState = sideChannelItemId == null ? 'UNSET' : sideChannelItemId === 'NONE' ? 'NONE' : 'SELECTED';
    const bottomChannelState = bottomChannelItemId == null ? 'UNSET' : bottomChannelItemId === 'NONE' ? 'NONE' : 'SELECTED';
    console.debug("[HardwareStep] Progressive filtering", {
      productTypeId,
      hardwareColor: currentHardwareColor,
      bottomBarCount: bottomBarOptions.length,
      templatesAfterBottomBar: templatesAfterBottomBar?.length ?? 'all',
      headbox: { state: headboxState, count: headboxOptions.length, before: templatesAfterBottomBar?.length, after: templatesAfterHeadbox?.length },
      sideChannel: { state: sideChannelState, count: sideChannelOptions.length, before: templatesAfterHeadbox?.length, after: templatesAfterSideChannel?.length },
      bottomChannel: { state: bottomChannelState, count: bottomChannelOptions.length, before: templatesAfterSideChannel?.length, after: finalFilteredTemplates?.length },
      finalFilteredTemplates: finalFilteredTemplates?.length ?? 'all',
    });
  }
  
  // ✅ Inicializar valores por defecto
  useEffect(() => {
    const updates: any = {};
    let hasUpdates = false;
    
    if (showCassette && !cassetteShape) {
      updates.cassette_shape = 'none';
      hasUpdates = true;
    }
    
    if (hasUpdates) {
      onUpdate(updates);
    }
  }, []);
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">
        {selectionDisabled && (
          <div className="bg-amber-50 border border-amber-200 rounded p-3">
            <p className="text-xs text-amber-800">
              Save the quote first to enable BOM selections.
            </p>
          </div>
        )}
        <div className={`space-y-8 ${selectionDisabled ? 'pointer-events-none opacity-50' : ''}`}>

        {/* Headbox / Cassette toggle REMOVED — selection is handled by the card section below with "Not Included" button */}

        {/* Headbox required notice — for triple and other 'required' types */}
        {headboxPolicy === 'required' && (
          <div className="flex items-center gap-3 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="w-2 h-2 rounded-full bg-blue-500 shrink-0" />
            <p className="text-xs text-blue-700 font-medium">
              Headbox / Cassette is required for this product type and will be included automatically.
            </p>
          </div>
        )}

        {/* Hardware Color */}
        {showHardwareColor && (
          <div>
            <Label className="text-sm font-medium mb-5 block">
              HARDWARE COLOR
            </Label>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              {HARDWARE_COLOR_OPTIONS.map((option) => {
                const isSelected =
                  (currentHardwareColor && option.id && (currentHardwareColor === option.id || String(currentHardwareColor).trim().toLowerCase() === String(option.id).toLowerCase()));
                return (
                  <div
                    key={option.id}
                    onClick={async () => {
                      if (selectionDisabled) return;
                      const okBottomBar = await removeSelection('bottom_bar');
                      const okHeadbox = await removeSelection('headbox');
                      const okSide = await removeSelection('side_channel');
                      const okBottomChannel = await removeSelection('bottom_channel');
                      if (!okBottomBar || !okHeadbox || !okSide || !okBottomChannel) return;
                      
                      // ✅ FIX: Cargar templates base para el nuevo color ANTES de actualizar
                      const baseTemplates = await loadTemplatesForColor(option.id);
                      
                      if (import.meta.env.DEV) {
                        console.debug('[HardwareStep] Color changed, loaded base templates:', {
                          color: option.id,
                          templateCount: baseTemplates.length,
                        });
                      }
                      
                      // ✅ Limpiar selecciones de componentes cuando cambia el color
                      // PERO mantener templates base válidos (NO null)
                      onUpdate({ 
                        hardwareColor: option.id,
                        hardware_color: option.id,
                        operatingSystemColor: option.id,
                        // Limpiar selecciones de componentes que dependen del color
                        bottom_bar_item_id: null,
                        bottom_bar_sku: null,
                        headbox_item_id: null,
                        headbox_sku: null,
                        side_channel_item_id: null,
                        side_channel_sku: null,
                        bottom_channel_item_id: null,
                        bottom_channel_sku: null,
                        // ✅ FIX: Mantener templates base del nuevo color (NO null)
                        _hardware_filtered_templates: baseTemplates.length > 0 ? baseTemplates : null,
                      } as any);
                    }}
                    className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    } ${selectionDisabled ? 'opacity-50 pointer-events-none cursor-not-allowed' : ''}`}
                  >
                    {/* X to deselect */}
                    {isSelected && (
                      <button
                        type="button"
                        onClick={async (e) => {
                          e.stopPropagation();
                          if (selectionDisabled) return;
                          const okBottomBar = await removeSelection('bottom_bar');
                          const okHeadbox = await removeSelection('headbox');
                          const okSide = await removeSelection('side_channel');
                          const okBottomChannel = await removeSelection('bottom_channel');
                          if (!okBottomBar || !okHeadbox || !okSide || !okBottomChannel) return;
                          
                          // ✅ Al deseleccionar color, limpiar todo pero NO poner templates en null
                          // Dejar templates undefined para que steps siguientes carguen desde ProductType
                          onUpdate({
                            hardwareColor: undefined,
                            hardware_color: undefined,
                            operatingSystemColor: undefined,
                            bottom_bar_item_id: null,
                            bottom_bar_sku: null,
                            headbox_item_id: null,
                            headbox_sku: null,
                            side_channel_item_id: null,
                            side_channel_sku: null,
                            bottom_channel_item_id: null,
                            bottom_channel_sku: null,
                            // ✅ undefined (no null) para que siguiente step cargue templates
                            _hardware_filtered_templates: undefined,
                          } as any);
                        }}
                        className={`absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10 ${selectionDisabled ? 'pointer-events-none' : ''}`}
                        title="Remove selection"
                      >
                        <X className="w-4 h-4 text-gray-600" />
                      </button>
                    )}
                    <div 
                      className="aspect-square relative flex items-center justify-center overflow-hidden bg-white border-b border-gray-200"
                      style={{ backgroundColor: option.color }}
                    >
                      {option.id === 'Silver' && (
                        <div className="absolute inset-0 opacity-20 bg-gradient-to-br from-white to-gray-400" />
                      )}
                    </div>
                    <div className="p-4 bg-gray-100 flex-1">
                      <h3 className={`font-semibold text-sm text-center ${
                        isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'
                      }`}>
                        {option.name}
                      </h3>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Bottom Bar - Dynamic from CatalogItems */}
        {currentHardwareColor && (
          <div>
            <Label className="text-sm font-medium mb-5 block">BOTTOM BAR</Label>
            {loadingBottomBar ? (
              <div className="text-sm text-gray-500 mt-2">Loading bottom bar options...</div>
            ) : optionsToRender.length > 0 ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              {optionsToRender.map((item) => {
                const isSelected =
                  (savedId != null && String(item.id) === String(savedId)) ||
                  (savedSku != null && savedSku !== '' && normSku(item.sku) === normSku(savedSku));
                const isPinned = !!(item as any).__pinned;
                return (
                  <div
                    key={item.id}
                    className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all relative ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    } ${selectionDisabled ? 'opacity-50' : ''}`}
                  >
                    {isSelected && (
                      <button
                        type="button"
                        onClick={async (e) => {
                          e.stopPropagation();
                          userInteractedRef.current = true;
                          const okBottomBar = await removeSelection('bottom_bar');
                          const okHeadbox = await removeSelection('headbox');
                          const okSide = await removeSelection('side_channel');
                          const okBottomChannel = await removeSelection('bottom_channel');
                          if (!okBottomBar || !okHeadbox || !okSide || !okBottomChannel) return;
                          onUpdate({
                            bottom_bar_item_id: null,
                            bottom_bar_sku: null,
                            bottom_rail_type: null,
                            // Limpiar selecciones dependientes
                            headbox_item_id: null,
                            headbox_sku: null,
                            side_channel_item_id: null,
                            side_channel_sku: null,
                            bottom_channel_item_id: null,
                            bottom_channel_sku: null,
                          } as any);
                        }}
                        className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                        title="Remove selection"
                      >
                        <X className="w-4 h-4 text-gray-600" />
                      </button>
                    )}
                    <div
                      onClick={async () => {
                        if (selectionDisabled) return;
                        if (isPinned) {
                          useUIStore.getState().addNotification({
                            type: 'info',
                            title: 'Bottom Bar guardado',
                            message: 'Este Bottom Bar está guardado, pero no aparece en las opciones actuales. Ajusta color o filtros.',
                          });
                          return;
                        }
                        userInteractedRef.current = true;
                        const sku = (item.sku || "").trim();
                        const id = String(item.id);
                        const isVirtual = id.startsWith('sku:');
                        if (isVirtual) {
                          notifyError('Invalid bottom bar selection (virtual SKU).');
                          return;
                        }
                        if (!ensurePersistable()) return;
                        const ok = await persistSelection('bottom_bar', id);
                        if (!ok) return;

                        const newFilteredTemplates = uniq(item.templateIds) || [];
                        if (import.meta.env.DEV) {
                          console.debug('[HardwareStep] Bottom bar selected:', { sku, id, templateIds: newFilteredTemplates.length });
                        }

                        onUpdate({
                          bottom_bar_item_id: isVirtual ? null : id,
                          bottom_bar_sku: sku,
                          bottom_rail_type: 'standard',
                          headbox_item_id: null,
                          headbox_sku: null,
                          side_channel_item_id: null,
                          side_channel_sku: null,
                          bottom_channel_item_id: null,
                          bottom_channel_sku: null,
                          _hardware_filtered_templates: newFilteredTemplates.length > 0 ? newFilteredTemplates : null,
                        } as any);
                      }}
                      className="cursor-pointer flex flex-col flex-1"
                    >
                      <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                        {isPinned ? (
                          <span className="text-xs text-gray-500">Saved</span>
                        ) : (
                          <CatalogItemImage
                            src={item.image_url}
                            alt={item.name || item.sku}
                            size="lg"
                            objectFit="contain"
                            className="w-full h-full !rounded-none !border-0"
                          />
                        )}
                      </div>
                      <div className="p-4 bg-gray-100 flex-1">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            ) : (
              <div className="text-sm text-gray-500">
                No bottom bar options available for selected color.
              </div>
            )}

            {/* Bottom Bar Wrapped (Forrado) checkbox — Roller only */}
            {isRollerShade && (config as any).bottom_bar_item_id && (
              <div className="mt-4 pt-3 border-t border-gray-200">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={(config as any).bottom_bar_wrapped === true}
                    onChange={(e) => onUpdate({ bottom_bar_wrapped: e.target.checked } as any)}
                    className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
                  />
                  <span className="text-sm font-medium text-gray-900">Bottom Bar Wrapped (Forrado)</span>
                </label>
                <p className="text-xs text-gray-500 mt-1 ml-6">
                  Wrap the bottom bar with fabric. Adds a surcharge to the fabric cost.
                </p>
              </div>
            )}
          </div>
        )}

        {/* Headbox / Cassette */}
        {showCassette && currentHardwareColor && (config as any).bottom_bar_item_id && (
          <div>
            <div className="flex items-center gap-3 mb-5">
              <Label className="text-sm font-medium block min-w-[12rem]">HEADBOX / CASSETTE</Label>
              {headboxPolicy !== 'required' && (
                <button
                  type="button"
                  onClick={async () => {
                    if (selectionDisabled) return;
                    if ((config as any).headbox_item_id === 'NONE') {
                      await clearHeadboxSelection();
                    } else {
                      onUpdate({
                        headbox_item_id: 'NONE',
                        headbox_sku: null,
                        cassette: false,
                        cassette_shape: 'none',
                      } as any);
                    }
                  }}
                  className={`shrink-0 w-[7.5rem] px-3 py-1.5 text-xs font-medium rounded border transition-colors ${
                    String((config as any).headbox_item_id) === 'NONE'
                      ? 'border-2 border-gray-900 bg-gray-100 text-gray-900'
                      : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50 hover:border-gray-400'
                  } ${selectionDisabled ? 'opacity-50 pointer-events-none' : ''}`}
                >
                  Not Included
                </button>
              )}
            </div>
            {(headboxPolicy === 'required' || String((config as any).headbox_item_id) !== 'NONE') && (
              <>
                {loadingHeadbox ? (
                  <div className="text-sm text-gray-500 mt-2">Loading headbox options...</div>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {headboxOptionsToRender.map((item) => {
                  const isSelected = String((config as any).headbox_item_id) === String(item.id);
                  return (
                    <div
                      key={item.id}
                      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all relative ${
                        isSelected
                          ? 'border-2 border-gray-900 shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      } ${selectionDisabled ? 'opacity-50' : ''}`}
                    >
                      {isSelected && (
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.stopPropagation();
                            await clearHeadboxSelection();
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div
                        onClick={async () => {
                          if (selectionDisabled) return;
                          if (!ensurePersistable()) return;
                          await setHeadboxSelected(item);
                        }}
                        className="cursor-pointer flex flex-col flex-1"
                      >
                        <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                          <CatalogItemImage
                            src={item.image_url}
                            alt={item.name || item.sku}
                            size="lg"
                            objectFit="contain"
                            className="w-full h-full !rounded-none !border-0"
                          />
                        </div>
                        <div className="p-4 bg-gray-100 flex-1">
                          <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                            {item.name || item.sku}
                          </h3>
                          <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {/* Side Channel Items — Roller Shade only (optional) */}
        {isRollerShade && showSideChannel && currentHardwareColor && (config as any).bottom_bar_item_id && (
          <div>
            <div className="flex items-center gap-3 mb-5">
              <Label className="text-sm font-medium block min-w-[12rem]">SIDE CHANNEL ITEMS</Label>
              <button
                type="button"
                onClick={() => {
                  if (selectionDisabled) return;
                  if ((config as any).side_channel_item_id === 'NONE') {
                    onUpdate({
                      side_channel_item_id: null,
                      side_channel_sku: null,
                      side_channel: false,
                    } as any);
                  } else {
                    onUpdate({
                      side_channel_item_id: 'NONE',
                      side_channel_sku: null,
                      side_channel: false,
                      bottom_channel_item_id: 'NONE',
                      bottom_channel_sku: null,
                      bottom_channel: false,
                    } as any);
                  }
                }}
                className={`shrink-0 w-[7.5rem] px-3 py-1.5 text-xs font-medium rounded border transition-colors ${
                  String((config as any).side_channel_item_id) === 'NONE'
                    ? 'border-2 border-gray-900 bg-gray-100 text-gray-900'
                    : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50 hover:border-gray-400'
                } ${selectionDisabled ? 'opacity-50 pointer-events-none' : ''}`}
              >
                Not Included
              </button>
            </div>
            {String((config as any).side_channel_item_id) !== 'NONE' && (
              <>
                {loadingSideChannel ? (
                  <div className="text-sm text-gray-500 mt-2">Loading side channel options...</div>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {sideChannelOptionsToRender.map((item) => {
                  const isSelected = String((config as any).side_channel_item_id) === String(item.id);
                  return (
                    <div
                      key={item.id}
                      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all relative ${
                        isSelected
                          ? 'border-2 border-gray-900 shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      } ${selectionDisabled ? 'opacity-50' : ''}`}
                    >
                      {isSelected && (
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.stopPropagation();
                            onUpdate({
                              side_channel_item_id: null,
                              side_channel_sku: null,
                              side_channel: false,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Clear (UNSET)"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div
                        onClick={async () => {
                          if (selectionDisabled) return;
                          const id = String(item.id);
                          const isVirtual = id.startsWith('sku:');
                          if (isVirtual) {
                            notifyError('Invalid side channel selection (virtual SKU).');
                            return;
                          }
                          if (!ensurePersistable()) return;
                          const ok = await persistSelection('side_channel', id);
                          if (!ok) return;
                          // ✅ Calcular templates filtrados
                          let newFilteredTemplates = item.templateIds || [];
                          const currentFiltered = (config as any)._hardware_filtered_templates as string[] | undefined;
                          
                          if (currentFiltered && currentFiltered.length > 0 && newFilteredTemplates.length > 0) {
                            const set = new Set(newFilteredTemplates);
                            newFilteredTemplates = currentFiltered.filter(tid => set.has(tid));
                          }
                          
                          onUpdate({
                            side_channel_item_id: item.id,
                            side_channel_sku: item.sku ? String(item.sku).trim() : null,
                            side_channel: true,
                            _hardware_filtered_templates: uniq(newFilteredTemplates) ?? uniq(currentFiltered) ?? null,
                          } as any);
                        }}
                        className="cursor-pointer flex flex-col flex-1"
                      >
                        <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                          <CatalogItemImage
                            src={item.image_url}
                            alt={item.name || item.sku}
                            size="lg"
                            objectFit="contain"
                            className="w-full h-full !rounded-none !border-0"
                          />
                        </div>
                        <div className="p-4 bg-gray-100 flex-1">
                          <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                            {item.name || item.sku}
                          </h3>
                          <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {/* Add Bottom Channel — Roller only, requires Side Channel selected */}
        {isRollerShade && currentHardwareColor && (config as any).bottom_bar_item_id && String((config as any).side_channel_item_id ?? '') !== 'NONE' && (config as any).side_channel_item_id && (
          <div>
            <div className="flex items-center gap-3 mb-5">
              <Label className="text-sm font-medium block min-w-[12rem]">ADD BOTTOM CHANNEL</Label>
              <button
                type="button"
                onClick={() => {
                  if (selectionDisabled) return;
                  if ((config as any).bottom_channel_item_id === 'NONE') {
                    onUpdate({
                      bottom_channel_item_id: null,
                      bottom_channel_sku: null,
                      bottom_channel: false,
                    } as any);
                  } else {
                    onUpdate({
                      bottom_channel_item_id: 'NONE',
                      bottom_channel_sku: null,
                      bottom_channel: false,
                    } as any);
                  }
                }}
                className={`shrink-0 w-[7.5rem] px-3 py-1.5 text-xs font-medium rounded border transition-colors ${
                  String((config as any).bottom_channel_item_id) === 'NONE'
                    ? 'border-2 border-gray-900 bg-gray-100 text-gray-900'
                    : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50 hover:border-gray-400'
                } ${selectionDisabled ? 'opacity-50 pointer-events-none' : ''}`}
              >
                Not Included
              </button>
            </div>
            {String((config as any).bottom_channel_item_id) !== 'NONE' && (
              <>
                {loadingBottomChannel ? (
                  <div className="text-sm text-gray-500 mt-2">Loading bottom channel options...</div>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {bottomChannelOptionsToRender.map((item) => {
                  const isSelected = String((config as any).bottom_channel_item_id) === String(item.id);
                  return (
                    <div
                      key={item.id}
                      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all relative ${
                        isSelected
                          ? 'border-2 border-gray-900 shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      } ${selectionDisabled ? 'opacity-50' : ''}`}
                    >
                      {isSelected && (
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.stopPropagation();
                            onUpdate({
                              bottom_channel_item_id: null,
                              bottom_channel_sku: null,
                              bottom_channel: false,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Clear (UNSET)"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div
                        onClick={async () => {
                          if (selectionDisabled) return;
                          const id = String(item.id);
                          const isVirtual = id.startsWith('sku:');
                          if (isVirtual) {
                            notifyError('Invalid bottom channel selection (virtual SKU).');
                            return;
                          }
                          if (!ensurePersistable()) return;
                          const ok = await persistSelection('bottom_channel', id);
                          if (!ok) return;
                          // ✅ Calcular templates filtrados
                          let newFilteredTemplates = item.templateIds || [];
                          const currentFiltered = (config as any)._hardware_filtered_templates as string[] | undefined;
                          
                          if (currentFiltered && currentFiltered.length > 0 && newFilteredTemplates.length > 0) {
                            const set = new Set(newFilteredTemplates);
                            newFilteredTemplates = currentFiltered.filter(tid => set.has(tid));
                          }
                          
                          onUpdate({
                            bottom_channel_item_id: item.id,
                            bottom_channel_sku: item.sku ? String(item.sku).trim() : null,
                            bottom_channel: true,
                            _hardware_filtered_templates: uniq(newFilteredTemplates) ?? uniq(currentFiltered) ?? null,
                          } as any);
                        }}
                        className="cursor-pointer flex flex-col flex-1"
                      >
                        <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                          <CatalogItemImage
                            src={item.image_url}
                            alt={item.name || item.sku}
                            size="lg"
                            objectFit="contain"
                            className="w-full h-full !rounded-none !border-0"
                          />
                        </div>
                        <div className="p-4 bg-gray-100 flex-1">
                          <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                            {item.name || item.sku}
                          </h3>
                          <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
                  </div>
                )}
              </>
            )}
          </div>
        )}
        </div>
      </div>
    </div>
  );
}
