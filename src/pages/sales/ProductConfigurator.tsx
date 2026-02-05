/**
 * Product Configurator
 * Main component that dispatches to product-specific configuration flows
 */

import { useState, useEffect, useLayoutEffect, useMemo, useCallback, useRef } from 'react';
import { X } from 'lucide-react';
import { ProductType, ProductConfig } from './product-config/types';
import { canProceedToNext } from './product-config/product-registry';
import ProductStep from './curtain-config/ProductStep';
import { useBOMTemplateQuestions } from '../../hooks/useBOMTemplateQuestions';
import { UnifiedProductConfig, normalizeConfig } from './product-config/config-contract';
import { useUIStore } from '../../stores/ui-store';
import { createConfiguredProductPreview } from '../../lib/bom/createConfiguredProductPreview';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { RoleSelection, isUnset, isNone, isSelected, toRoleSelection, getSelectionSku } from '../../lib/bom/selection';
import { 
  getProductTypeId, 
  getHardwareColor, 
  getOperationType,
  logConfigDiff 
} from '../../lib/config-normalizers';

// Import step components for dynamic step building
import MeasurementsStepComponent from './curtain-config/MeasurementsStep';
import VariantsStepComponent from './curtain-config/VariantsStep';
import HardwareStepComponent from './curtain-config/HardwareStep';
import OperatingSystemStepComponent from './curtain-config/OperatingSystemStep';
import AccessoriesStepComponent from './curtain-config/AccessoriesStep';
import ReviewStepComponent from './curtain-config/ReviewStep';

// Import all product modules to register them
import './product-config/products';

interface ProductConfiguratorProps {
  quoteId: string;
  onComplete: (config: ProductConfig) => Promise<void>;
  onClose: () => void;
  initialConfig?: Partial<ProductConfig>; // Optional initial config for editing
}

export default function ProductConfigurator({ quoteId, onComplete, onClose, initialConfig }: ProductConfiguratorProps) {
  const draftKey = `productConfiguratorDraft:${quoteId}`;
  const { activeOrganizationId } = useOrganizationContext();
  
  // ✅ SOLUCIÓN DEFINITIVA: Ref para evitar loops en auto-commit
  const autoCommittedRef = useRef<string | null>(null);
  const draftHydratedRef = useRef(false);
  const isEditingMode = initialConfig && Object.keys(initialConfig).length > 0;

  // ✅ CRITICAL: Restore draft FIRST if not editing, THEN initialize state
  const getInitialState = () => {
    // Editing mode: use initialConfig
    if (isEditingMode) {
      draftHydratedRef.current = true;
      return {
        productType: initialConfig.productType || null,
        currentStepIndex: 0,
        config: initialConfig,
      };
    }

    // New line: try to restore from sessionStorage
    try {
      const raw = window.sessionStorage.getItem(draftKey);
      if (raw) {
        const parsed = JSON.parse(raw) as {
          productType?: ProductType | null;
          currentStepIndex?: number;
          config?: Partial<ProductConfig>;
        };
        
        if (import.meta.env.DEV) {
          console.log('[ProductConfigurator] RESTORED from sessionStorage', {
            draftKey,
            productType: parsed.productType,
            stepIndex: parsed.currentStepIndex,
            hasConfig: !!parsed.config,
          });
        }
        
        draftHydratedRef.current = true;
        return {
          productType: parsed.productType || null,
          currentStepIndex: parsed.currentStepIndex || 0,
          config: parsed.config || { position: '' },
        };
      }
    } catch (err) {
      console.warn('[ProductConfigurator] Failed to restore draft', err);
    }

    // No draft found: start fresh
    draftHydratedRef.current = true;
    return {
      productType: null,
      currentStepIndex: 0,
      config: { position: '' },
    };
  };

  const initialState = getInitialState();
  const [productType, setProductType] = useState<ProductType | null>(initialState.productType);
  const [currentStepIndex, setCurrentStepIndex] = useState(initialState.currentStepIndex);
  const [config, setConfig] = useState<Partial<ProductConfig>>(initialState.config);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const configRef = useRef<Partial<ProductConfig>>(initialState.config);

  useEffect(() => {
    configRef.current = config;
  }, [config]);

  // CRITICAL: Update state when initialConfig changes AFTER mount (e.g., when switching to edit mode)
  const initialConfigRef = useRef(initialConfig);
  useEffect(() => {
    // Only react if initialConfig actually changed (not on mount)
    if (initialConfig === initialConfigRef.current) return;
    initialConfigRef.current = initialConfig;

    if (initialConfig && Object.keys(initialConfig).length > 0) {
      // Switched to editing mode
      setConfig(initialConfig);
      if (initialConfig.productType) {
        setProductType(initialConfig.productType);
        setCurrentStepIndex(0);
      }
      
      if (import.meta.env.DEV) {
        console.log('[ProductConfigurator] Switched to EDIT mode', {
          productType: initialConfig.productType,
          productTypeId: (initialConfig as any).productTypeId,
        });
      }
    } else if (initialConfig === undefined) {
      // Switched to new mode: clear and try to restore draft
      try {
        const raw = window.sessionStorage.getItem(draftKey);
        if (raw) {
          const parsed = JSON.parse(raw);
          setProductType(parsed.productType || null);
          setCurrentStepIndex(parsed.currentStepIndex || 0);
          setConfig(parsed.config || { position: '' });
        } else {
          setProductType(null);
          setCurrentStepIndex(0);
          setConfig({ position: '' });
        }
      } catch {
        setProductType(null);
        setCurrentStepIndex(0);
        setConfig({ position: '' });
      }
      
      if (import.meta.env.DEV) {
        console.log('[ProductConfigurator] Switched to NEW mode');
      }
    }
  }, [initialConfig, draftKey]);

  useEffect(() => {
    // Save draft on any config change (only for new lines)
    if (isEditingMode) return;
    if (!draftHydratedRef.current) return;

    try {
      const payload = {
        productType,
        currentStepIndex,
        config,
        timestamp: Date.now(),
      };
      window.sessionStorage.setItem(draftKey, JSON.stringify(payload));
      
      if (import.meta.env.DEV) {
        console.log('[ProductConfigurator] SAVED to sessionStorage', {
          draftKey,
          productType,
          stepIndex: currentStepIndex,
          configKeys: Object.keys(config),
        });
      }
    } catch (err) {
      console.warn('[ProductConfigurator] Failed to persist draft', err);
    }
  }, [draftKey, productType, currentStepIndex, config, isEditingMode]);

  // ✅ Restore state when tab becomes visible (prevents loss on tab switch)
  useEffect(() => {
    if (isEditingMode) return; // Don't restore for edit mode

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        try {
          const raw = window.sessionStorage.getItem(draftKey);
          if (raw) {
            const parsed = JSON.parse(raw);
            // Only restore if timestamp is recent (within last hour) to avoid stale data
            const age = Date.now() - (parsed.timestamp || 0);
            if (age < 3600000) { // 1 hour
              setProductType(parsed.productType || null);
              setCurrentStepIndex(parsed.currentStepIndex || 0);
              setConfig(parsed.config || { position: '' });
              
              if (import.meta.env.DEV) {
                console.log('[ProductConfigurator] RESTORED from sessionStorage on visibility', {
                  draftKey,
                  productType: parsed.productType,
                  stepIndex: parsed.currentStepIndex,
                });
              }
            }
          }
        } catch (err) {
          console.warn('[ProductConfigurator] Failed to restore draft on visibility', err);
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [draftKey, isEditingMode]);

  const clearDraft = useCallback(() => {
    try {
      window.sessionStorage.removeItem(draftKey);
    } catch (err) {
      console.warn('[ProductConfigurator] Failed to clear draft', err);
    }
  }, [draftKey]);

  // ✅ NORMALIZACIÓN CENTRALIZADA: Un solo lugar para normalizar el config
  // Esto elimina inconsistencias entre camelCase y snake_case
  const normalizeCfg = useCallback((cfg: any) => {
    const product_type_id = cfg.product_type_id ?? cfg.productTypeId ?? null;
    const hardware_color = cfg.hardware_color ?? cfg.hardwareColor ?? cfg.operatingSystemColor ?? null;

    // OJO: tú tienes operation_type y también operatingSystem/manual flags
    const operation_type =
      cfg.operation_type ??
      cfg.operatingSystem ??
      cfg.operating_system ??
      null;

    const bottom_bar_sku = (cfg.bottom_bar_sku ?? cfg.bottomBarSku ?? "").trim() || null;
    const tube_sku = (cfg.tube_sku ?? cfg.tubeSku ?? cfg.tube_type ?? "").trim() || null;
    const headbox_sku = (cfg.headbox_sku ?? cfg.headboxSku ?? "").trim() || null;
    const drive_sku = (cfg.drive_sku ?? cfg.driveSku ?? "").trim() || null;
    const motor_sku = (cfg.motor_sku ?? cfg.motorSku ?? "").trim() || null;

    return {
      product_type_id,
      hardware_color,
      operation_type,
      bottom_bar_sku,
      tube_sku,
      headbox_sku,
      drive_sku,
      motor_sku,
    };
  }, []);

  // ✅ NORMALIZACIÓN: Usar getters canónicos para evitar inconsistencias camelCase vs snake_case
  // FASE 2: Get product_type_id to load templates (normalizado)
  const productTypeIdForTemplates = getProductTypeId(config as any);
  
  // FASE 2: Get hardware_color from config (normalizado y capitalizado)
  const hardwareColor = getHardwareColor(config as any);
  
  // FASE 2: Get operation type (normalizado: motor | manual)
  const operationType = getOperationType(config as any);
  
  // ✅ Convertir config legacy a RoleSelection para headbox
  // IMPORTANTE: 
  // - Si headbox_sku es null explícitamente Y headbox_item_id es null → NONE
  // - Si headbox_sku es undefined, string vacío, o no existe → UNSET
  // - Si headbox_sku es string válido → SELECTED
  const headboxSkuValue = (config as any).headbox_sku;
  const headboxItemIdValue = (config as any).headbox_item_id;
  const headboxSelection: RoleSelection = 
    headboxSkuValue === null && headboxItemIdValue === null
      ? { state: "none" } // Explícitamente NONE (usuario seleccionó "Sin headbox")
      : toRoleSelection(headboxSkuValue, headboxItemIdValue); // undefined/'' = UNSET, string = SELECTED
  
  // ✅ Convertir config legacy a RoleSelection para side_channel y bottom_channel
  // (Estos NO filtran templates, pero se guardan para BOM generation)
  const sideChannelSkuValue = (config as any).side_channel_sku;
  const sideChannelItemIdValue = (config as any).side_channel_item_id;
  const sideChannelSelection: RoleSelection = 
    sideChannelSkuValue === null && sideChannelItemIdValue === null
      ? { state: "none" }
      : toRoleSelection(sideChannelSkuValue, sideChannelItemIdValue);
  
  const bottomChannelSkuValue = (config as any).bottom_channel_sku;
  const bottomChannelItemIdValue = (config as any).bottom_channel_item_id;
  const bottomChannelSelection: RoleSelection = 
    bottomChannelSkuValue === null && bottomChannelItemIdValue === null
      ? { state: "none" }
      : toRoleSelection(bottomChannelSkuValue, bottomChannelItemIdValue);
  
  // ✅ Convertir config legacy a RoleSelection para bottom_bar y tube (roles obligatorios)
  const bottomBarSkuValue = (config as any).bottom_bar_sku;
  const bottomBarItemIdValue = (config as any).bottom_bar_item_id;
  const bottomBarSelection: RoleSelection = toRoleSelection(bottomBarSkuValue, bottomBarItemIdValue);
  
  const tubeSkuValue = (config as any).tube_sku;
  const tubeItemIdValue = (config as any).tube_item_id;
  const tubeSelection: RoleSelection = toRoleSelection(tubeSkuValue, tubeItemIdValue);
  
  // ✅ Construir filtros usando getSelectionSku() para asegurar SKU real
  // Bottom Bar y Tube: solo cuando SELECTED (string), undefined cuando UNSET
  const bottomBarSku = getSelectionSku(bottomBarSelection);
  const tubeSku = getSelectionSku(tubeSelection);
  
  // Headbox: null = NONE, undefined = UNSET, string = SELECTED
  const headboxSku = headboxSelection.state === "none" 
    ? null 
    : getSelectionSku(headboxSelection);
  
  const headboxItemId = headboxSelection.state === "selected"
    ? headboxSelection.catalog_item_id
    : null;
  
  const sideChannelSku = sideChannelSelection.state === "selected"
    ? getSelectionSku(sideChannelSelection)
    : null;
  
  const sideChannelItemId = sideChannelSelection.state === "selected"
    ? sideChannelSelection.catalog_item_id
    : null;
  
  const bottomChannelSku = bottomChannelSelection.state === "selected"
    ? getSelectionSku(bottomChannelSelection)
    : null;
  
  const bottomChannelItemId = bottomChannelSelection.state === "selected"
    ? bottomChannelSelection.catalog_item_id
    : null;
  
  // ✅ USAR NORMALIZACIÓN CENTRALIZADA para construir filtros
  const n = normalizeCfg(config);

  // ✅ LOG MÍNIMO (sin circular) para confirmar en 5 segundos
  if (import.meta.env.DEV) {
    console.debug("[CFG normalized]", {
      product_type_id: n.product_type_id,
      hardware_color: n.hardware_color,
      operation_type: n.operation_type,
      bottom_bar_sku: n.bottom_bar_sku,
      tube_sku: n.tube_sku,
      headbox_sku: n.headbox_sku,
      drive_sku: n.drive_sku,
      motor_sku: n.motor_sku,
    });
    console.debug("[CFG raw bottom_bar]", {
      bottom_bar_item_id: (config as any).bottom_bar_item_id,
      bottom_bar_sku: (config as any).bottom_bar_sku,
      bottomBarSku: (config as any).bottomBarSku,
    });
  }

  // ✅ NUEVA ARQUITECTURA (según dump): NO filtramos templates durante pasos.
  // El template se resuelve SOLO al final con matchBOMTemplate().
  // Por eso, para decidir pasos, usamos defaults (bomTemplateId = null).
  const questions = useBOMTemplateQuestions(null);

  const steps = useMemo(() => {
    if (!productType) return [];

    // Mantener el orden estable que ya funciona en el configurador
    const dynamicSteps: Array<{ id: string; label: string; component: any }> = [];
    dynamicSteps.push({ id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent });
    dynamicSteps.push({ id: 'variants', label: 'VARIANTS', component: VariantsStepComponent });

    if (questions.requiredSteps.hardware) {
      dynamicSteps.push({ id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent });
    }
    if (questions.requiredSteps.operatingSystem) {
      dynamicSteps.push({ id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent });
    }

    dynamicSteps.push({ id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent });
    dynamicSteps.push({ id: 'review', label: 'QUOTE', component: ReviewStepComponent });

    if (import.meta.env.DEV) {
      console.log('[ProductConfigurator] Steps built (no template filtering)', {
        stepsCount: dynamicSteps.length,
        stepIds: dynamicSteps.map((s) => s.id),
      });
    }

    return dynamicSteps;
  }, [productType, questions.requiredSteps.hardware, questions.requiredSteps.operatingSystem]);
  
  // currentStepIndex 0 = product selection, 1+ = product steps (steps[0], steps[1], etc.)
  const currentStep = productType && currentStepIndex > 0 ? steps[currentStepIndex - 1] : null;

  // Handle product type selection
  const handleProductTypeSelect = (type: ProductType, productTypeId?: string) => {
    setProductType(type);
    
    // ✅ SOLUCIÓN DEFINITIVA: Reset auto-commit ref cuando cambia ProductType
    autoCommittedRef.current = null;
    
    // CRITICAL: When editing, don't reset config - just update productType and productTypeId
    setConfig(prev => {
      const hasExistingConfig = prev && Object.keys(prev).length > 1;
      const prevProductTypeId = (prev as any).product_type_id || (prev as any).productTypeId;
      const isProductTypeChanging = prevProductTypeId && prevProductTypeId !== productTypeId;
      
      // If we already have a config with the same product type (editing scenario)
      // preserve ALL existing values including bom_template_id
      if (hasExistingConfig && prev.productType === type) {
        if (import.meta.env.DEV) {
          console.log('ProductConfigurator: Preserving existing config (editing)', {
            type,
            productTypeId,
            existingConfig: prev,
            bom_template_id: (prev as any).bom_template_id,
          });
        }
        return {
          ...prev,
          productType: type,
          ...(productTypeId ? { productTypeId, product_type_id: productTypeId } : {}),
          // Preserve bom_template_id if it exists
          ...((prev as any).bom_template_id ? { bom_template_id: (prev as any).bom_template_id } : {}),
        } as Partial<ProductConfig>;
      }
      
      // New selection or ProductType changed - update productType but preserve bom_template_id
      // if it was already set (auto-select might have set it before this runs)
      const baseConfig: Partial<ProductConfig> = { 
        productType: type, 
        position: prev.position || '',
        ...(productTypeId ? { productTypeId, product_type_id: productTypeId } : {}),
        // CRITICAL: If ProductType is changing, clear bom_template_id
        // Otherwise, preserve it if it exists (might have been set by auto-select)
        ...(isProductTypeChanging ? { bom_template_id: null } : ((prev as any).bom_template_id ? { bom_template_id: (prev as any).bom_template_id } : {})),
      };
      
      if (import.meta.env.DEV) {
        console.log('ProductConfigurator: New product type selected', {
          type,
          productTypeId,
          prevProductTypeId,
          isProductTypeChanging,
          newConfig: baseConfig,
          preservedBomTemplateId: (prev as any).bom_template_id,
        });
      }
      
      return baseConfig as Partial<ProductConfig>;
    });
    
    setCurrentStepIndex(1); // Move to first step after product selection
  };

  // FASE 2: Handle step updates - preserve critical fields
  // CRITICAL: Use useCallback to stabilize the function reference
  // ✅ Soporte para función o objeto (MERGE SIEMPRE)
  const handleUpdate = useCallback((updatesOrFn: Partial<ProductConfig> | ((prev: Partial<ProductConfig>) => Partial<ProductConfig>)) => {
    setConfig(prev => {
      // ✅ Resolver updates (función o objeto)
      const updates = typeof updatesOrFn === "function" ? updatesOrFn(prev) : updatesOrFn;
      
      console.log('[ProductConfigurator] 🔄 handleUpdate called', {
        updates,
        hasBomTemplateId: 'bom_template_id' in updates,
        bomTemplateId: (updates as any).bom_template_id,
      });
      // ✅ VALIDACIÓN CRÍTICA: Log de campos antes de merge
      if (import.meta.env.DEV) {
        logConfigDiff(prev as any, updates as any, 'handleUpdate');
        console.debug('[ProductConfigurator] handleUpdate BEFORE merge - critical fields', {
          prev: {
            product_type_id: getProductTypeId(prev as any),
            hardware_color: getHardwareColor(prev as any),
            operation_type: getOperationType(prev as any),
            bom_template_id: (prev as any).bom_template_id,
          },
          updates: {
            product_type_id: getProductTypeId(updates as any),
            hardware_color: getHardwareColor(updates as any),
            operation_type: getOperationType(updates as any),
            bom_template_id: (updates as any).bom_template_id,
          },
        });
      }
      
      // Merge updates while preserving critical fields
      const merged = { ...prev, ...updates };
      
      // ✅ CRITICAL: Preserve draft quote_line_id unless explicitly changed
      if ((prev as any).quote_line_id && !('quote_line_id' in (updates as any))) {
        (merged as any).quote_line_id = (prev as any).quote_line_id;
      }

      // CRITICAL: Always preserve productType, productTypeId, product_type_id, and bom_template_id
      if (prev.productType) {
        (merged as any).productType = prev.productType;
      }
      if ((prev as any).productTypeId) {
        (merged as any).productTypeId = (prev as any).productTypeId;
      }
      // CRITICAL: Sync product_type_id with productTypeId if one exists
      if ((prev as any).productTypeId && !(merged as any).product_type_id) {
        (merged as any).product_type_id = (prev as any).productTypeId;
      }
      if ((prev as any).product_type_id) {
        (merged as any).product_type_id = (prev as any).product_type_id;
      }
      // CRITICAL: Sync productTypeId with product_type_id if one exists (bidirectional sync)
      if ((prev as any).product_type_id && !(merged as any).productTypeId) {
        (merged as any).productTypeId = (prev as any).product_type_id;
      }
      // CRITICAL: bom_template_id should be updated if present in updates
      // Only preserve previous value if update doesn't include bom_template_id
      if ('bom_template_id' in updates) {
        // Explicit update - use the new value (even if null)
        (merged as any).bom_template_id = (updates as any).bom_template_id;
        console.log('[ProductConfigurator] ✅ bom_template_id EXPLICITLY SET', {
          bomTemplateId: (updates as any).bom_template_id,
          mergedBomTemplateId: (merged as any).bom_template_id,
        });
      } else if ((prev as any).bom_template_id !== undefined) {
        // No update for bom_template_id - preserve previous value
        (merged as any).bom_template_id = (prev as any).bom_template_id;
      }
      
      // ✅ VALIDACIÓN CRÍTICA: Log de campos después de merge
      if (import.meta.env.DEV) {
        const lostKeys = Object.keys(prev).filter(k => (prev as any)[k] !== undefined && (merged as any)[k] === undefined);
        console.debug('[ProductConfigurator] handleUpdate AFTER merge - critical fields', {
          merged: {
            product_type_id: getProductTypeId(merged as any),
            hardware_color: getHardwareColor(merged as any),
            operation_type: getOperationType(merged as any),
            bom_template_id: (merged as any).bom_template_id,
            bottom_bar_sku: (merged as any).bottom_bar_sku,
            tube_sku: (merged as any).tube_sku,
            motor_sku: (merged as any).motor_sku,
            drive_sku: (merged as any).drive_sku,
          },
          lostKeys: lostKeys.length > 0 ? lostKeys : 'none',
        });
        
        if (lostKeys.length > 0) {
          console.warn('[ProductConfigurator] ⚠️ KEYS LOST DURING MERGE', {
            lostKeys,
            prevValues: Object.fromEntries(lostKeys.map(k => [k, (prev as any)[k]])),
          });
        }
      }
      
      return merged as Partial<ProductConfig>;
    });
  }, []); // Empty deps - function is stable

  // ✅ Matching al final: ya no auto-seleccionamos bom_template_id durante pasos.

  // Navigation
  const handleNext = () => {
    if (!productType) {
      // Can't proceed without product type
      return;
    }
    if (currentStepIndex < steps.length) {
      setCurrentStepIndex(prev => prev + 1);
    }
  };

  // Clear selections from steps ahead when navigating backward
  const getClearUpdatesForStepId = (stepId: string): Partial<ProductConfig> => {
    switch (stepId) {
      case 'measurements':
        return {
          panels: undefined,
          width_mm: undefined,
          width_m: undefined,
          height_mm: undefined,
          height_m: undefined,
          area: undefined,
          position: undefined,
          installationType: undefined,
          installationLocation: undefined,
        } as any;
      case 'variants':
        return {
          collectionName: undefined,
          collection_name: undefined,
          collectionId: undefined,
          variantId: undefined,
          fabric_catalog_item_id: undefined,
          fabric_variant_id: undefined,
          variantName: undefined,
          variant_name: undefined,
        } as any;
      case 'hardware':
        return {
          hardwareColor: undefined,
          hardware_color: undefined,
          operatingSystemColor: undefined,
          bottom_bar_item_id: null,
          bottom_bar_sku: null,
          bottom_rail_type: null,
          headbox_item_id: null,
          headbox_sku: null,
          cassette: false,
          cassette_shape: 'none',
          cassette_type: undefined,
          side_channel_item_id: null,
          side_channel_sku: null,
          side_channel: false,
          bottom_channel: false,
          bottom_channel_item_id: null,
          bottom_channel_sku: null,
          side_channel_type: null,
          side_bottom_channel_selection: 'none',
          // ✅ Limpiar persistencia de templates para que al re-entrar se recalcule desde color
          _hardware_filtered_templates: undefined,
        } as any;
      case 'operating-system':
        return {
          operation_type: undefined,
          drive_type: undefined,
          operatingSystem: undefined,
          operating_system_variant: undefined,
          drive_item_id: undefined,
          drive_sku: null,
          manual_drive: undefined,
          motor_item_id: undefined,
          motor_sku: null,
          motor_family: undefined,
          remote_control: undefined,
          tube_item_id: undefined,
          tube_sku: null,
          tube_type: undefined,
          // ✅ Limpiar base y templates para que al re-entrar se recalculen desde Hardware
          _operating_system_base_templates: undefined,
          _hardware_filtered_templates: undefined,
        } as any;
      case 'accessories':
        return {
          accessories: [],
        } as any;
      default:
        return {};
    }
  };

  const clearSelectionsAfterStep = async (targetIndex: number) => {
    if (!steps.length) return;
    const stepArrayIndex = targetIndex - 1;
    const stepsToClear = targetIndex <= 0 ? steps : steps.slice(stepArrayIndex + 1);
    if (stepsToClear.length === 0) return;

    let updates: any = {};
    stepsToClear.forEach((step) => {
      updates = { ...updates, ...getClearUpdatesForStepId(step.id) };
    });

    if (Object.keys(updates).length > 0) {
      setConfig(prev => ({
        ...prev,
        ...updates,
      }));
    }
  };

  const handleBack = () => {
    if (currentStepIndex > 1) {
      // Go back to previous product step
      const nextIndex = currentStepIndex - 1;
      void clearSelectionsAfterStep(nextIndex);
      setCurrentStepIndex(nextIndex);
    } else if (currentStepIndex === 1) {
      // Go back to product selection (step 0)
      void clearSelectionsAfterStep(0);
      setCurrentStepIndex(0);
      // Optionally clear product type to allow reselection
      // setProductType(null);
      // setConfig(prev => ({ ...prev, productType: undefined }));
    }
  };

  const handleStepClick = (index: number) => {
    // When editing, allow navigation to any step (not just completed ones)
    // This is because all data is already loaded from DB
    const hasInitialConfig = initialConfig && Object.keys(initialConfig).length > 0;
    
    if (hasInitialConfig) {
      // When editing, allow free navigation to all steps
      if (index < currentStepIndex) {
        void clearSelectionsAfterStep(index);
      }
      setCurrentStepIndex(index);
    } else {
      // When creating new, only allow navigation to completed steps
      if (index <= currentStepIndex) {
        if (index < currentStepIndex) {
          void clearSelectionsAfterStep(index);
        }
        setCurrentStepIndex(index);
      }
    }
  };

  // FASE 3 & 4: Complete configuration with validation and normalization
  const handleComplete = async () => {
    if (!productType || !config.productType) {
      return;
    }

    // FASE 3: Validate required fields
    const normalizedConfig = normalizeConfig(config as Partial<UnifiedProductConfig>);
    
    // ✅ FIX CRÍTICO: Para validaciones de selección (drive/motor/tube/etc)
    // usar el config ORIGINAL porque normalizeConfig NO incluye esos campos.
    // normalizedConfig solo se usa para persistencia (contrato limpio).
    const configAny = config as any;
    const errors: string[] = [];
    
    if (import.meta.env.DEV) {
      console.debug('[BOM][handleComplete] raw config keys', Object.keys(config as any).filter(k => (config as any)[k] !== undefined));
      console.debug('[BOM][handleComplete] normalized keys', Object.keys(normalizedConfig as any).filter(k => (normalizedConfig as any)[k] !== undefined));
      console.debug('[BOM][handleComplete] drive/motor/tube raw', {
        drive_sku: configAny.drive_sku,
        drive_item_id: configAny.drive_item_id,
        manual_drive: configAny.manual_drive,
        motor_sku: configAny.motor_sku,
        motor_item_id: configAny.motor_item_id,
        tube_sku: configAny.tube_sku,
        tube_item_id: configAny.tube_item_id,
        tube_type: configAny.tube_type,
        control_sku: configAny.control_sku,
        control_item_id: configAny.control_item_id,
      });
    }
    
    // ✅ REMOVIDO: No inicializar hardware_color automáticamente
    // El usuario debe seleccionar explícitamente para evitar errores
    const isRollerShade = normalizedConfig.productType === 'roller-shade' || 
                         configAny.productType === 'roller_shade' || 
                         configAny.productType === 'ROLLER';
    
    // ✅ NO inicializar hardware_color automáticamente - usuario debe seleccionar
    
    // Core validations
    if (!normalizedConfig.product_type_id) {
      errors.push('Product Type is required');
    }
    // ✅ BOM Template is NOT required in validation - it's derived automatically
    // The template will be resolved when saving QuoteLine or generating BOM
    if (!normalizedConfig.width_m || normalizedConfig.width_m <= 0) {
      errors.push('Width is required');
    }
    if (!normalizedConfig.height_m || normalizedConfig.height_m <= 0) {
      errors.push('Height is required');
    }
    
    // FASE 3: Validate based on BOMTemplate questions (if template is available)
    // ✅ If no BOM Template, skip template-specific validations
    // The template will be resolved later when saving QuoteLine or generating BOM
      if (questions) {
      if (questions.requiredSteps.variants && !normalizedConfig.fabric_variant_id && !normalizedConfig.variantId) {
        errors.push('Fabric variant is required');
      }
      if (questions.requiredSteps.operatingSystem) {
        if (!normalizedConfig.drive_type) {
          errors.push('Operating system type is required (Manual or Motor)');
        } else {
          // ✅ CRÍTICO: Validar que se haya seleccionado un drive/motor específico
          // normalizedConfig.drive_type puede ser 'manual' o 'motorized'
          // configAny.operation_type puede ser 'motor' o 'manual'
          const operationType = (configAny as any).operation_type || normalizedConfig.drive_type;
          const isMotorized = operationType === 'motor' || operationType === 'motorized';
          const isManual = operationType === 'manual';
          
          if (import.meta.env.DEV) {
            console.log('[ProductConfigurator] Operating system validation:', {
              operationType,
              isMotorized,
              isManual,
              motor_sku: configAny.motor_sku,
              motorSku: configAny.motorSku,
              motor_item_id: configAny.motor_item_id,
              drive_sku: configAny.drive_sku,
              driveSku: configAny.driveSku,
              drive_item_id: configAny.drive_item_id,
              tube_sku: configAny.tube_sku,
              tubeSku: configAny.tubeSku,
              tube_type: configAny.tube_type,
              tube_item_id: configAny.tube_item_id,
            });
          }
          
          if (isMotorized) {
            // Buscar motor_sku o motor_item_id
            const hasMotor = !!(
              configAny.motor_sku || 
              configAny.motorSku || 
              configAny.motor_item_id ||
              configAny.motorItemId
            );
            if (!hasMotor) {
              errors.push('Motor selection is required');
            }
          } else if (isManual) {
            // Buscar drive_sku o drive_item_id
            const hasDrive = !!(
              configAny.drive_sku || 
              configAny.driveSku || 
              configAny.drive_item_id ||
              configAny.driveItemId ||
              configAny.manual_drive
            );
            if (!hasDrive) {
              errors.push('Manual drive selection is required');
            }
          }
          
          // ✅ Validar tube (obligatorio para ambos tipos)
          const hasTube = !!(
            configAny.tube_sku || 
            configAny.tubeSku || 
            configAny.tube_type || 
            configAny.tubeType ||
            configAny.tube_item_id ||
            configAny.tubeItemId
          );
          if (!hasTube) {
            errors.push('Tube selection is required');
          }
        }
      }
      // ✅ Validar hardware_color solo si el template lo requiere explícitamente
      // NO inicializar automáticamente - usuario debe seleccionar
      if (questions.selectQuestions.hardware_color && !normalizedConfig.hardware_color && !configAny.hardwareColor && !configAny.operatingSystemColor) {
        errors.push('Hardware color is required');
      }
    }
    
    // ✅ If no BOM Template available but user has completed basic fields, allow to proceed
    // The backend will resolve the template or show error at BOM generation time
    
    if (errors.length > 0) {
      if (import.meta.env.DEV) {
        console.error('[ProductConfigurator] Validation errors:', errors);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Configuration Incomplete',
        message: `Please complete the following fields:\n${errors.join('\n')}`,
      });
      setIsSubmitting(false);
      return;
    }

    setIsSubmitting(true);
    try {
      // ✅ NUEVA ARQUITECTURA: ConfiguredProduct es la base.
      // El matching de bom_template_id se resuelve de forma estricta al crear el ConfiguredProduct
      // (usando select_best_bom_template_v2_strict) y luego QuoteLine se genera desde ese snapshot.

      // Helpers
      const pickSku = (cfg: any, keys: string[]): string | null => {
        for (const k of keys) {
          const v = cfg?.[k];
          if (typeof v === 'string' && v.trim().length > 0) return v.trim();
        }
        return null;
      };
      const finalNormalizedConfig = normalizedConfig as any;

      // ✅ NUEVO: Crear ConfiguredProduct preview antes de llamar onComplete
      // Esto genera BOM preview y calcula totals (fabric + bom) ANTES de crear QuoteLine
      if (activeOrganizationId && finalNormalizedConfig.product_type_id) {
        try {
          // Preparar config_snapshot con todos los datos necesarios
          // ✅ CRÍTICO: Todos los SKUs deben ser EXACTOS (trim, case-sensitive)
          // ✅ CRÍTICO: hardware_color debe ser EXACTO (normalizado)
          const configSnapshot: Record<string, any> = {
            ...finalNormalizedConfig,
            // Asegurar que width_mm y height_mm estén en el snapshot
            width_mm: finalNormalizedConfig.width_m ? finalNormalizedConfig.width_m * 1000 : null,
            height_mm: finalNormalizedConfig.height_m ? finalNormalizedConfig.height_m * 1000 : null,
            // ✅ hardware_color: normalizar (capitalize first letter)
            hardware_color: (() => {
              const color = finalNormalizedConfig.hardware_color || configAny.hardwareColor || configAny.operatingSystemColor;
              if (!color) return null;
              // Normalizar: capitalize first letter
              return color.charAt(0).toUpperCase() + color.slice(1).toLowerCase();
            })(),
            // ✅ SKUs: asegurar que estén trim y no sean null/undefined
            bottom_bar_item_id: configAny.bottom_bar_item_id || null,
            bottom_bar_sku: pickSku(configAny, ['bottom_bar_sku', 'bottomBarSku', 'bottom_bar']) || null,
            // 'NONE' is UI-only tri-state; persist as null (no headbox/side/bottom channel)
            headbox_item_id: (configAny.headbox_item_id === 'NONE' ? null : configAny.headbox_item_id) || null,
            headbox_sku: configAny.headbox_sku ? String(configAny.headbox_sku).trim() : null,
            side_channel_item_id: (configAny.side_channel_item_id === 'NONE' ? null : configAny.side_channel_item_id) || null,
            side_channel_sku: configAny.side_channel_sku ? String(configAny.side_channel_sku).trim() : null,
            bottom_channel_item_id: (configAny.bottom_channel_item_id === 'NONE' ? null : configAny.bottom_channel_item_id) || null,
            bottom_channel_sku: configAny.bottom_channel_sku ? String(configAny.bottom_channel_sku).trim() : null,
            motor_item_id: configAny.motor_item_id || null,
            motor_sku: configAny.motor_sku ? String(configAny.motor_sku).trim() : null,
            drive_item_id: configAny.drive_item_id || null,
            drive_sku: configAny.drive_sku ? String(configAny.drive_sku).trim() : null,
            tube_item_id: configAny.tube_item_id || null,
            tube_sku: pickSku(configAny, ['tube_sku', 'tubeSku', 'tube_type', 'tubeType']) || null,
            operating_type: configAny.operation_type || configAny.drive_type || null,
            roll_catalog_item_id: finalNormalizedConfig.fabric_variant_id || configAny.variantId || configAny.catalogItemId || null,
            quantity: finalNormalizedConfig.quantity || 1,
            // ✅ Drop e instalación (para QuoteLines vía commit y config_snapshot)
            fabricDrop: configAny.fabricDrop ?? configAny.fabric_drop ?? null,
            installationType: configAny.installationType ?? configAny.installation_type ?? null,
            installationLocation: configAny.installationLocation ?? configAny.installation_location ?? null,
          };

          // ✅ Pass candidate templates from progressive filtering (for strict disambiguation).
          const filtered = (configAny as any)._hardware_filtered_templates;
          if (Array.isArray(filtered)) {
            const candidateIds = filtered.filter((x: any) => typeof x === 'string' && x.trim().length > 0);
            if (candidateIds.length > 0) {
              configSnapshot.candidate_template_ids = Array.from(new Set(candidateIds));
            }
            // If it is already narrowed to 1, use it directly.
            if (candidateIds.length === 1) {
              configSnapshot.bom_template_id = candidateIds[0];
            }
          }

          // ✅ DEBUG: Log config_snapshot antes de enviar
          if (import.meta.env.DEV) {
            console.log('[ProductConfigurator] Config snapshot prepared:', {
              hardware_color: configSnapshot.hardware_color,
              bottom_bar_sku: configSnapshot.bottom_bar_sku,
              headbox_sku: configSnapshot.headbox_sku,
              motor_sku: configSnapshot.motor_sku,
              drive_sku: configSnapshot.drive_sku,
              tube_sku: configSnapshot.tube_sku,
              product_type_id: finalNormalizedConfig.product_type_id,
            });
          }

          const previewResult = await createConfiguredProductPreview({
            organization_id: activeOrganizationId,
            product_type_id: finalNormalizedConfig.product_type_id,
            config_snapshot: configSnapshot,
            quote_id: quoteId || null,
          });

          if (import.meta.env.DEV) {
            console.log('[ProductConfigurator] ConfiguredProduct preview created:', {
              configured_product_id: previewResult.configured_product_id,
              bom_instance_id: previewResult.bom_instance_id,
              totals: previewResult.totals,
            });
          }

          // Agregar configured_product_id al config antes de pasar a onComplete
          (finalNormalizedConfig as any).configured_product_id = previewResult.configured_product_id;
          (finalNormalizedConfig as any).configured_product_totals = previewResult.totals;
          // ✅ CRITICAL: bom_template_id viene del ConfiguredProduct (strict matching)
          (finalNormalizedConfig as any).bom_template_id = previewResult.bom_template_id;
          // ✅ NEW: Pass bom_preview_snapshot for UI breakdown display
          if (previewResult.bom_preview_snapshot) {
            (finalNormalizedConfig as any).bom_preview_snapshot = previewResult.bom_preview_snapshot;
          }
          // ✅ Drop e instalación: normalizeConfig no los incluye; pasarlos para QuoteLines
          (finalNormalizedConfig as any).fabricDrop = configAny.fabricDrop ?? configAny.fabric_drop ?? null;
          (finalNormalizedConfig as any).installationType = configAny.installationType ?? configAny.installation_type ?? null;
          (finalNormalizedConfig as any).installationLocation = configAny.installationLocation ?? configAny.installation_location ?? null;
        } catch (previewError: any) {
          // ✅ REQUERIR ConfiguredProduct - NO continuar sin él
          console.error('[ProductConfigurator] Error creating ConfiguredProduct preview:', previewError);
          
          // ✅ MEJORAR mensaje de error si es por BOM Template no encontrado
          let errorMessage = previewError.message || 'Unknown error';
          const lowered = errorMessage.toLowerCase();
          if (lowered.includes('frontend fallback')) {
            errorMessage = `No BOMTemplate match found for your selections. Please verify the selected motor/drive + tube + bottom bar exist together in a BOM Template. Details: ${errorMessage}`;
          } else if (errorMessage.includes('No matching BOMTemplate')) {
            errorMessage = `No BOM Template found for this product type. Please create a BOM Template first in Catalog > BOM Templates. Original error: ${errorMessage}`;
          }
          
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Configuration Error',
            message: `Failed to create product preview: ${errorMessage}. Please try again.`,
          });
          setIsSubmitting(false);
          return; // NO continuar sin ConfiguredProduct
        }
      } else {
        // Si no hay organizationId, mostrar error
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Configuration Error',
          message: 'Organization ID is required to create product preview.',
        });
        setIsSubmitting(false);
        return;
      }

      await onComplete(finalNormalizedConfig as ProductConfig);
      clearDraft();
      onClose();
    } catch (error) {
      console.error('Error completing configuration:', error);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Configuration Error',
        message: error instanceof Error ? error.message : 'Failed to complete configuration',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  // Check if can proceed to next step
  const canProceed = (): boolean => {
    if (currentStepIndex === 0) {
      return !!productType;
    }
    // For other steps, use validation
    if (!productType || !currentStep) return false;
    
    // Custom validation for measurements step
    if (currentStep.id === 'measurements') {
      const width_m = (config as any).width_m || ((config as any).width_mm ? (config as any).width_mm / 1000 : null);
      const height_m = (config as any).height_m || ((config as any).height_mm ? (config as any).height_mm / 1000 : null);
      return !!(width_m && width_m > 0 && height_m && height_m > 0);
    }

    // Use existing per-step validation
    const result = canProceedToNext(currentStep.id, productType, config as ProductConfig);
    return !!result; // Ensure boolean return
  };

  // CRITICAL: Memoize the onUpdate callback to prevent unnecessary re-renders
  const productStepOnUpdate = useCallback((updates: Partial<ProductConfig>) => {
    const newProductType = (updates as any).productType;
    const newProductTypeId = (updates as any).productTypeId;
    
    if (newProductType) {
      // Validate that it's a valid ProductType
      const validTypes: ProductType[] = ['roller-shade', 'dual-shade', 'triple-shade', 'drapery', 'awning', 'window-film'];
      if (validTypes.includes(newProductType)) {
        handleProductTypeSelect(newProductType as ProductType, newProductTypeId);
      }
    } else if (newProductType === undefined && productType) {
      // If product type is cleared, reset to product selection
      setProductType(null);
      setConfig(prev => ({ ...prev, productType: undefined, productTypeId: undefined, product_type_id: null, bom_template_id: null }));
      setCurrentStepIndex(0);
    } else {
      // Handle other updates (including bom_template_id)
      // CRITICAL: bom_template_id updates should go through handleUpdate
      console.log('[ProductConfigurator] ProductStep onUpdate received', {
        updates,
        hasBomTemplateId: !!(updates as any).bom_template_id,
        bom_template_id: (updates as any).bom_template_id,
      });
      
      handleUpdate(updates);
    }
  }, [productType, handleUpdate]); // Depend on handleUpdate which is already memoized

  // Render step content
  const renderStepContent = () => {
    if (!productType || currentStepIndex === 0) {
      // Show product selection
      return (
        <ProductStep 
          config={config as any} 
          onUpdate={productStepOnUpdate as any}
        />
      );
    }

    // Get the actual step index in the steps array (currentStepIndex - 1 because step 0 is product selection)
    const stepArrayIndex = currentStepIndex - 1;
    const step = steps[stepArrayIndex];
    
    if (!step) return null;

    const StepComponent = step.component;
    
    // CRITICAL: Log config before passing to step
    if (import.meta.env.DEV) {
      console.log(`ProductConfigurator: Passing config to ${step.id}`, {
        productTypeId: (config as any).productTypeId,
        productType: config.productType,
        collectionName: (config as any).collectionName,
        variantId: (config as any).variantId,
        fullConfig: config,
      });
    }
    
    // Pass quoteId to ReviewStep if it's that component
    // ✅ RE-ARQUITECTURA: Pasar candidateTemplateIds a HardwareStep y OperatingSystemStep
    const stepProps: any = {
      config: config as any,
      onUpdate: handleUpdate,
    };
    
    // If this is the review step, pass quoteId
    if (step.id === 'review') {
      stepProps.quoteId = quoteId;
    }
    
    return (
      <StepComponent {...stepProps} />
    );
  };

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Left Navigation Sidebar */}
      <div className="w-64 bg-white border-r border-gray-200 p-4 overflow-y-auto">
        <div className="mb-4">
          <h2 className="text-lg font-semibold text-gray-900 mb-2">Configuration Steps</h2>
        </div>
        <div className="space-y-1">
          {/* Product Selection Step */}
          <button
            onClick={() => setCurrentStepIndex(0)}
            className={`w-full text-left px-4 py-3 mb-1 rounded transition-colors ${
              !productType
                ? 'bg-primary text-white shadow-md'
                : 'bg-green-50 text-green-700 hover:bg-green-100'
            }`}
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">PRODUCT</span>
              {productType && <span className="text-green-600">✓</span>}
            </div>
          </button>

          {/* Product-specific steps */}
          {steps.map((step, index) => {
            const stepIndex = index + 1; // +1 because product selection is step 0
            const isActive = currentStepIndex === stepIndex;
            
            // When editing (has initialConfig), all steps are accessible and show as completed
            const hasInitialConfig = initialConfig && Object.keys(initialConfig).length > 0;
            const isAccessible = productType && (hasInitialConfig || stepIndex <= currentStepIndex);
            
            // When editing, show all steps as completed (green) except the active one
            const isCompleted = hasInitialConfig ? !isActive : stepIndex < currentStepIndex;
            
            return (
              <button
                key={step.id}
                onClick={() => isAccessible && handleStepClick(stepIndex)}
                disabled={!isAccessible}
                className={`w-full text-left px-4 py-3 mb-1 rounded transition-colors ${
                  isActive
                    ? 'bg-primary text-white shadow-md'
                    : isCompleted
                    ? 'bg-green-50 text-green-700 hover:bg-green-100'
                    : isAccessible
                    ? 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                    : 'bg-gray-50 text-gray-400 cursor-not-allowed'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">{step.label}</span>
                  {isCompleted && !isActive && (
                    <span className="text-green-600">✓</span>
                  )}
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <div className="bg-white border-b border-gray-200 px-6 py-4">
          <h1 className="text-xl font-semibold text-gray-900">
            {!productType || currentStepIndex === 0 ? 'PRODUCT' : currentStep?.label || 'Configuration'}
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            {!productType || currentStepIndex === 0
              ? 'Select a product type to begin'
              : `Step ${currentStepIndex} of ${steps.length}`
            }
          </p>
        </div>

        {/* Step Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {renderStepContent()}
          
          {/* FASE 5: Debug Panel (DEV ONLY) */}
          {import.meta.env.DEV && (
            <div className="mt-6 border-t border-gray-200 pt-4">
              <details className="bg-gray-50 rounded-lg p-4">
                <summary className="cursor-pointer text-sm font-medium text-gray-700 hover:text-gray-900">
                  🔍 Debug Info (DEV)
                </summary>
                <div className="mt-4 space-y-2 text-xs">
                  <div>
                    <strong>Product Type:</strong> {productType || 'N/A'}
                  </div>
                  <div>
                    <strong>Current Step:</strong> {currentStepIndex + 1} / {steps.length}
                  </div>
                  <div>
                    <strong>Hardware Color:</strong> {hardwareColor || 'Not selected'}
                  </div>
                  <div>
                    <strong>Product Type ID:</strong> {productTypeIdForTemplates || 'N/A'}
                  </div>
                  <div>
                    <strong>Config Keys:</strong> {Object.keys(config || {}).join(', ') || 'Empty'}
                  </div>
                  {config && (config as any).width_m && (
                    <div>
                      <strong>Measurements:</strong> {(config as any).width_m}m × {(config as any).height_m}m
                    </div>
                  )}
                  {config && (config as any).variantId && (
                    <div>
                      <strong>Fabric Selected:</strong> Yes (ID: {(config as any).variantId})
                    </div>
                  )}
                  {config && (config as any).accessories && Array.isArray((config as any).accessories) && (
                    <div>
                      <strong>Accessories:</strong> {(config as any).accessories.length} items
                    </div>
                  )}
                  <details className="mt-2">
                    <summary className="cursor-pointer text-xs text-gray-600">Full Config (JSON)</summary>
                    <pre className="mt-2 text-xs bg-white p-2 rounded border overflow-auto max-h-40">
                      {JSON.stringify(config, null, 2)}
                    </pre>
                  </details>
                </div>
              </details>
            </div>
          )}
        </div>

        {/* Navigation Footer */}
        <div className="bg-white border-t border-gray-200 px-6 py-4">
          <div className="flex items-center justify-between">
            <button
              onClick={handleBack}
              disabled={currentStepIndex === 0 || isSubmitting}
              className="px-4 py-2 border border-gray-300 rounded-lg bg-white text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
            >
              Back
            </button>
            
            <div className="flex items-center gap-2">
              {!productType || currentStepIndex < steps.length ? (
                <button
                  onClick={handleNext}
                  disabled={!!(isSubmitting || (!productType && currentStepIndex === 0) || (productType && !canProceed()))}
                  className="px-6 py-2 rounded-lg text-white transition-colors text-sm font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  Next
                </button>
              ) : (
                <button
                  onClick={handleComplete}
                  disabled={!!(isSubmitting || !canProceed())}
                  className="px-6 py-2 bg-green-600 text-white rounded-lg transition-colors text-sm font-medium hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isSubmitting ? 'Adding...' : 'Add to Quote'}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

