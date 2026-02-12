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
import { useDealerConfiguratorPolicy } from '../../hooks/useDealerConfiguratorPolicy';
import { ConfiguratorPolicyProvider } from '../../context/ConfiguratorPolicyContext';
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
  const { policy, loading: policyLoading } = useDealerConfiguratorPolicy();
  
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
  const productTypeRef = useRef<ProductType | null>(initialState.productType);
  const currentStepIndexRef = useRef(initialState.currentStepIndex);

  useEffect(() => {
    configRef.current = config;
  }, [config]);
  useEffect(() => {
    productTypeRef.current = productType;
  }, [productType]);
  useEffect(() => {
    currentStepIndexRef.current = currentStepIndex;
  }, [currentStepIndex]);

  // ✅ Garantizar que el config del snapshot (Edit/Duplicate) se aplica al estado para que las cards salgan seleccionadas
  const SNAPSHOT_KEYS = [
    'bottom_bar_sku', 'bottom_bar_item_id', 'hardware_color', 'hardwareColor',
    'headbox_item_id', 'headbox_sku', 'side_channel_item_id', 'side_channel_sku',
    'bottom_channel_item_id', 'bottom_channel_sku', 'tube_item_id', 'tube_sku',
    'drive_item_id', 'drive_sku', 'motor_item_id', 'motor_sku', 'operation_type', 'drive_type',
    '_hardware_filtered_templates',
    'measurements', 'panels',
  ] as const;

  useEffect(() => {
    if (!initialConfig || Object.keys(initialConfig).length === 0) return;
    // Log solo primitivos (evitar [circular])
    const ic = initialConfig as any;
    console.log('[ProductConfigurator] initialConfig', String(ic.hardware_color ?? 'MISSING'), String(ic.bottom_bar_sku ?? 'MISSING'), String(ic.bottom_bar_item_id ?? 'MISSING'));
    setConfig(prev => {
      const snap = initialConfig as Record<string, unknown>;
      let hasMissing = false;
      const patch: Record<string, unknown> = {};
      for (const k of SNAPSHOT_KEYS) {
        if (snap[k] != null && (prev as any)[k] == null) {
          patch[k] = snap[k];
          hasMissing = true;
        }
      }
      if (!hasMissing) return prev;
      console.log('[ProductConfigurator] Patching missing snapshot keys', Object.keys(patch));
      return { ...prev, ...patch };
    });
  }, [initialConfig]);

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

  // ✅ Persist on tab hide + restore when tab visible (prevents loss on tab switch)
  useEffect(() => {
    if (isEditingMode) return; // Don't persist/restore for edit mode

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') {
        // Flush current state to sessionStorage when user leaves the tab (refs have latest)
        try {
          const payload = {
            productType: productTypeRef.current,
            currentStepIndex: currentStepIndexRef.current,
            config: configRef.current,
            timestamp: Date.now(),
          };
          window.sessionStorage.setItem(draftKey, JSON.stringify(payload));
          if (import.meta.env.DEV) {
            console.log('[ProductConfigurator] SAVED to sessionStorage on tab hide', {
              draftKey,
              stepIndex: payload.currentStepIndex,
            });
          }
        } catch (err) {
          console.warn('[ProductConfigurator] Failed to save draft on tab hide', err);
        }
      } else if (document.visibilityState === 'visible') {
        // Restore when user comes back (in case component remounted or state was lost)
        try {
          const raw = window.sessionStorage.getItem(draftKey);
          if (raw) {
            const parsed = JSON.parse(raw);
            const age = Date.now() - (parsed.timestamp || 0);
            if (age < 3600000) {
              setProductType(parsed.productType ?? null);
              setCurrentStepIndex(parsed.currentStepIndex ?? 0);
              setConfig(parsed.config ?? { position: '' });
              if (import.meta.env.DEV) {
                console.log('[ProductConfigurator] RESTORED from sessionStorage on tab visible', {
                  draftKey,
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

  const allowHardware = !policy || policy.allow_hardware;
  const allowOperatingSystem = !policy || policy.allow_operating_system;
  const accessoriesOnlyMode = !!policy && policy.allow_accessories_only === true;

  const steps = useMemo(() => {
    if (!productType) return [];

    const dynamicSteps: Array<{ id: string; label: string; component: any }> = [];

    // Accessories as product type: only ACCESSORIES step then REVIEW (no measurements/variants/hardware)
    if (productType === 'accessories') {
      dynamicSteps.push({ id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent });
      dynamicSteps.push({ id: 'review', label: 'REVIEW', component: ReviewStepComponent });
      return dynamicSteps;
    }

    dynamicSteps.push({ id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent });
    dynamicSteps.push({ id: 'variants', label: 'VARIANTS', component: VariantsStepComponent });

    if (questions.requiredSteps.hardware && allowHardware) {
      dynamicSteps.push({ id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent });
    }
    if (questions.requiredSteps.operatingSystem && allowOperatingSystem) {
      dynamicSteps.push({ id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent });
    }

    dynamicSteps.push({ id: 'review', label: 'REVIEW', component: ReviewStepComponent });

    if (import.meta.env.DEV) {
      console.log('[ProductConfigurator] Steps built (policy filtering)', {
        stepsCount: dynamicSteps.length,
        stepIds: dynamicSteps.map((s) => s.id),
        policy: policy ? { allow_hardware: policy.allow_hardware, allow_operating_system: policy.allow_operating_system, allow_accessories_only: policy.allow_accessories_only } : null,
      });
    }

    return dynamicSteps;
  }, [productType, questions.requiredSteps.hardware, questions.requiredSteps.operatingSystem, policy, allowHardware, allowOperatingSystem, accessoriesOnlyMode]);
  
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

      // ✅ CRITICAL: Preserve snapshot keys (cards prefill) when updates OMIT them.
      // If the update explicitly sends null for a key, respect that (intentional clear).
      for (const k of SNAPSHOT_KEYS) {
        const explicitlyInUpdate = k in (updates as any);
        if (!explicitlyInUpdate && (prev as any)[k] != null && (merged as any)[k] == null) {
          (merged as any)[k] = (prev as any)[k];
        }
      }
      
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

    // Accessories-only: no validations for width, height, fabric, hardware, operating system
    const isAccessoriesOnly = productType === 'accessories' || configAny.productType === 'accessories';
    if (isAccessoriesOnly) {
      // Only ensure we have productType; no product_type_id required (no DB ProductType for accessories-only)
      if (!productType && !configAny.productType) {
        errors.push('Product Type is required');
      }
    } else {
    // Core validations (full products)
    if (!normalizedConfig.product_type_id) {
      errors.push('Product Type is required');
    }
    // ✅ BOM Template is NOT required in validation - it's derived automatically
    // ✅ Derive width/height from multiple sources (config.width_m, config.width_mm, panels sum, measurements)
    const panelsForValidation = Array.isArray(configAny.panels) ? configAny.panels : (configAny.measurements?.panels ?? []);
    const panelsSumMm = panelsForValidation.reduce((s: number, p: any) => s + (Number(p?.width_mm) || 0), 0);
    const effectiveWidthM = normalizedConfig.width_m 
      || (configAny.width_mm ? configAny.width_mm / 1000 : null) 
      || (configAny.measurements?.width_total_mm ? configAny.measurements.width_total_mm / 1000 : null) 
      || (panelsSumMm > 0 ? panelsSumMm / 1000 : null);
    const effectiveHeightM = normalizedConfig.height_m 
      || (configAny.height_mm ? configAny.height_mm / 1000 : null) 
      || (configAny.measurements?.height_mm ? configAny.measurements.height_mm / 1000 : null);
    
    if (import.meta.env.DEV) {
      console.log('[ProductConfigurator] Dimension validation', {
        normalizedWidth: normalizedConfig.width_m,
        normalizedHeight: normalizedConfig.height_m,
        configWidth_mm: configAny.width_mm,
        configHeight_mm: configAny.height_mm,
        panelsSumMm,
        effectiveWidthM,
        effectiveHeightM,
      });
    }
    
    if (!effectiveWidthM || effectiveWidthM <= 0) {
      errors.push('Width is required');
    }
    if (!effectiveHeightM || effectiveHeightM <= 0) {
      errors.push('Height is required');
    }
    
    // FASE 3: Validate based on BOMTemplate questions (if template is available)
      if (questions) {
      const hasVariant = !!(normalizedConfig.fabric_variant_id || normalizedConfig.variantId);
      if (questions.requiredSteps.variants && !hasVariant) {
        errors.push('Fabric variant is required');
      }
      if (questions.requiredSteps.operatingSystem) {
        if (!normalizedConfig.drive_type) {
          errors.push('Operating system type is required (Manual or Motor)');
        } else {
          const operationType = (configAny as any).operation_type || normalizedConfig.drive_type;
          const isMotorized = operationType === 'motor' || operationType === 'motorized';
          const isManual = operationType === 'manual';
          
          if (import.meta.env.DEV) {
            console.log('[ProductConfigurator] Operating system validation:', {
              operationType,
              isMotorized,
              isManual,
              motor_sku: configAny.motor_sku,
              drive_sku: configAny.drive_sku,
              tube_sku: configAny.tube_sku,
            });
          }
          
          if (isMotorized) {
            const hasMotor = !!(configAny.motor_sku || configAny.motorSku || configAny.motor_item_id || configAny.motorItemId);
            if (!hasMotor) errors.push('Motor selection is required');
          } else if (isManual) {
            const hasDrive = !!(configAny.drive_sku || configAny.driveSku || configAny.drive_item_id || configAny.driveItemId || configAny.manual_drive);
            if (!hasDrive) errors.push('Manual drive selection is required');
          }
          const hasTube = !!(configAny.tube_sku || configAny.tubeSku || configAny.tube_type || configAny.tubeType || configAny.tube_item_id || configAny.tubeItemId);
          if (!hasTube) errors.push('Tube selection is required');
        }
      }
      if (questions.selectQuestions.hardware_color && !normalizedConfig.hardware_color && !configAny.hardwareColor && !configAny.operatingSystemColor) {
        errors.push('Hardware color is required');
      }
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
      const finalNormalizedConfig = normalizedConfig as any;
      const panelsForValidation = Array.isArray((config as any).panels) ? (config as any).panels : ((config as any).measurements?.panels ?? []);
      const panelsSumMm = panelsForValidation.reduce((s: number, p: any) => s + (Number(p?.width_mm) || 0), 0);

      // ✅ Accessories-only: no ConfiguredProduct; pass minimal config and let QuoteNew create line with metadata
      if (isAccessoriesOnly) {
        const accessoriesPayload = {
          ...finalNormalizedConfig,
          productType: 'accessories' as const,
          position: (config as any).position ?? '',
          quantity: (config as any).quantity ?? 1,
          accessories: Array.isArray((config as any).accessories) ? (config as any).accessories : [],
        } as ProductConfig;
        await onComplete(accessoriesPayload);
        clearDraft();
        onClose();
        return;
      }

      // Helpers
      const pickSku = (cfg: any, keys: string[]): string | null => {
        for (const k of keys) {
          const v = cfg?.[k];
          if (typeof v === 'string' && v.trim().length > 0) return v.trim();
        }
        return null;
      };

      // ✅ NUEVO: Crear ConfiguredProduct preview antes de llamar onComplete
      if (activeOrganizationId && finalNormalizedConfig.product_type_id) {
        try {
          // Preparar config_snapshot con todos los datos necesarios
          // ✅ CRÍTICO: Todos los SKUs deben ser EXACTOS (trim, case-sensitive)
          // ✅ CRÍTICO: hardware_color debe ser EXACTO (normalizado)
          const panelsList = Array.isArray(configAny.panels) ? configAny.panels : (configAny.panels ? [configAny.panels] : []);
          const panelCount = configAny.measurements?.panel_count ?? (panelsList.length || 1);
          const widthTotalMm = configAny.measurements?.width_total_mm ?? panelsList.reduce((s: number, p: any) => s + (p?.width_mm || 0), 0);
          const measurements = configAny.measurements ?? {
            height_mm: finalNormalizedConfig.height_m ? finalNormalizedConfig.height_m * 1000 : configAny.height_mm ?? null,
            width_total_mm: widthTotalMm,
            panel_count: panelCount,
            panels: (panelsList.length ? panelsList : [{ index: 1, width_mm: configAny.width_mm || 0 }]).map((p: any, i: number) => ({ index: i + 1, width_mm: p?.width_mm ?? 0 })),
            is_interconnected: panelCount > 1,
          };
          // BOM/backend: use total width when multi-panel (sum of all paños) for fabric area and per-width components
          const widthMmForBom = panelCount > 1 ? widthTotalMm : (panelsList[0]?.width_mm ?? configAny.width_mm ?? null);
          const configSnapshot: Record<string, any> = {
            ...finalNormalizedConfig,
            width_mm: widthMmForBom ?? (finalNormalizedConfig.width_m ? finalNormalizedConfig.width_m * 1000 : null),
            height_mm: finalNormalizedConfig.height_m ? finalNormalizedConfig.height_m * 1000 : (measurements.height_mm ?? configAny.height_mm ?? null),
            measurements,
            // ✅ Persist top-level panels so MeasurementsStep can restore multi-panel configs on Edit
            panels: Array.isArray(configAny.panels) ? configAny.panels : (measurements.panels || null),
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
            // ✅ Persist 'NONE' as-is so Edit can distinguish between UNSET (null) and "Not Included" ('NONE')
            headbox_item_id: configAny.headbox_item_id === 'NONE' ? 'NONE' : (configAny.headbox_item_id || null),
            headbox_sku: configAny.headbox_item_id === 'NONE' ? null : (configAny.headbox_sku ? String(configAny.headbox_sku).trim() : null),
            side_channel_item_id: configAny.side_channel_item_id === 'NONE' ? 'NONE' : (configAny.side_channel_item_id || null),
            side_channel_sku: configAny.side_channel_item_id === 'NONE' ? null : (configAny.side_channel_sku ? String(configAny.side_channel_sku).trim() : null),
            bottom_channel_item_id: configAny.bottom_channel_item_id === 'NONE' ? 'NONE' : (configAny.bottom_channel_item_id || null),
            bottom_channel_sku: configAny.bottom_channel_item_id === 'NONE' ? null : (configAny.bottom_channel_sku ? String(configAny.bottom_channel_sku).trim() : null),
            motor_item_id: configAny.motor_item_id || null,
            motor_sku: configAny.motor_sku ? String(configAny.motor_sku).trim() : null,
            drive_item_id: configAny.drive_item_id || null,
            drive_sku: configAny.drive_sku ? String(configAny.drive_sku).trim() : null,
            tube_item_id: configAny.tube_item_id || null,
            tube_sku: pickSku(configAny, ['tube_sku', 'tubeSku', 'tube_type', 'tubeType']) || null,
            operating_type: configAny.operation_type || configAny.drive_type || null,
            roll_catalog_item_id: (finalNormalizedConfig.fabric_variant_id || configAny.variantId || configAny.catalogItemId) || null,
            quantity: finalNormalizedConfig.quantity || 1,
            // ✅ Drop e instalación (para QuoteLines vía commit y config_snapshot)
            fabricDrop: configAny.fabricDrop ?? configAny.fabric_drop ?? null,
            installationType: configAny.installationType ?? configAny.installation_type ?? null,
            installationLocation: configAny.installationLocation ?? configAny.installation_location ?? null,
            // ✅ Accesorios: incluir en snapshot para ConfiguredProduct.config_snapshot y cálculo de accessories_total
            accessories: Array.isArray(configAny.accessories) ? configAny.accessories : (finalNormalizedConfig.accessories || []),
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

      // ✅ CRITICAL: Ensure width_m/height_m are set from all available sources before passing to onComplete
      // normalizeConfig may have lost width_mm, measurements, panels — re-derive here
      if (!(finalNormalizedConfig as any).width_m || (finalNormalizedConfig as any).width_m <= 0) {
        const w = configAny.width_mm ?? configAny.measurements?.width_total_mm ?? (panelsSumMm > 0 ? panelsSumMm : null);
        if (w && w > 0) (finalNormalizedConfig as any).width_m = w / 1000;
      }
      if (!(finalNormalizedConfig as any).height_m || (finalNormalizedConfig as any).height_m <= 0) {
        const h = configAny.height_mm ?? configAny.measurements?.height_mm ?? null;
        if (h && h > 0) (finalNormalizedConfig as any).height_m = h / 1000;
      }
      // Carry over width_mm, height_mm, panels, measurements so Edit Save can use them
      if (configAny.width_mm != null) (finalNormalizedConfig as any).width_mm = configAny.width_mm;
      if (configAny.height_mm != null) (finalNormalizedConfig as any).height_mm = configAny.height_mm;
      if (Array.isArray(configAny.panels)) (finalNormalizedConfig as any).panels = configAny.panels;
      if (configAny.measurements) (finalNormalizedConfig as any).measurements = configAny.measurements;

      // ✅ CRITICAL: Carry over hardware and component selections so Edit Save and getConfigFromQuoteLine get full config.
      // normalizeConfig does not include these; without this, saved lines lose card selections when reopening.
      (finalNormalizedConfig as any).hardware_color = (finalNormalizedConfig as any).hardware_color ?? configAny.hardware_color ?? configAny.hardwareColor ?? configAny.operatingSystemColor ?? null;
      (finalNormalizedConfig as any).hardwareColor = (finalNormalizedConfig as any).hardware_color;
      (finalNormalizedConfig as any).bottom_bar_item_id = configAny.bottom_bar_item_id ?? null;
      (finalNormalizedConfig as any).bottom_bar_sku = configAny.bottom_bar_sku ?? configAny.bottomBarSku ?? null;
      (finalNormalizedConfig as any).headbox_item_id = configAny.headbox_item_id ?? null;
      (finalNormalizedConfig as any).headbox_sku = configAny.headbox_sku ?? null;
      (finalNormalizedConfig as any).side_channel_item_id = configAny.side_channel_item_id ?? null;
      (finalNormalizedConfig as any).side_channel_sku = configAny.side_channel_sku ?? null;
      (finalNormalizedConfig as any).bottom_channel_item_id = configAny.bottom_channel_item_id ?? null;
      (finalNormalizedConfig as any).bottom_channel_sku = configAny.bottom_channel_sku ?? null;
      (finalNormalizedConfig as any).tube_item_id = configAny.tube_item_id ?? null;
      (finalNormalizedConfig as any).tube_sku = configAny.tube_sku ?? configAny.tubeSku ?? configAny.tube_type ?? null;
      (finalNormalizedConfig as any).drive_item_id = configAny.drive_item_id ?? null;
      (finalNormalizedConfig as any).drive_sku = configAny.drive_sku ?? null;
      (finalNormalizedConfig as any).motor_item_id = configAny.motor_item_id ?? null;
      (finalNormalizedConfig as any).motor_sku = configAny.motor_sku ?? null;
      (finalNormalizedConfig as any).operation_type = configAny.operation_type ?? configAny.drive_type ?? (finalNormalizedConfig as any).operation_type ?? null;
      (finalNormalizedConfig as any).drive_type = (finalNormalizedConfig as any).operation_type;
      (finalNormalizedConfig as any).accessories = Array.isArray(configAny.accessories) ? configAny.accessories : (finalNormalizedConfig as any).accessories ?? [];
      (finalNormalizedConfig as any).fabricDrop = configAny.fabricDrop ?? configAny.fabric_drop ?? (finalNormalizedConfig as any).fabricDrop ?? null;
      (finalNormalizedConfig as any).installationType = configAny.installationType ?? configAny.installation_type ?? (finalNormalizedConfig as any).installationType ?? null;
      (finalNormalizedConfig as any).installationLocation = configAny.installationLocation ?? configAny.installation_location ?? (finalNormalizedConfig as any).installationLocation ?? null;
      
      if (import.meta.env.DEV) {
        console.log('[ProductConfigurator] Passing to onComplete', {
          width_m: (finalNormalizedConfig as any).width_m,
          height_m: (finalNormalizedConfig as any).height_m,
          width_mm: (finalNormalizedConfig as any).width_mm,
          height_mm: (finalNormalizedConfig as any).height_mm,
          panels: (finalNormalizedConfig as any).panels,
          hardware_color: (finalNormalizedConfig as any).hardware_color,
          bottom_bar_item_id: (finalNormalizedConfig as any).bottom_bar_item_id,
          bottom_bar_sku: (finalNormalizedConfig as any).bottom_bar_sku,
        });
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
      // Validate that it's a valid ProductType (including 'accessories' for accessories-only flow)
      const validTypes: ProductType[] = ['roller-shade', 'dual-shade', 'triple-shade', 'drapery', 'awning', 'window-film', 'accessories'];
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
          onNavigateToStep={(stepId) => {
            const idx = steps.findIndex((s) => s.id === stepId);
            if (idx >= 0) setCurrentStepIndex(idx + 1);
          }}
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

    return <StepComponent {...stepProps} />;
  };

  return (
    <ConfiguratorPolicyProvider value={{ policy, loading: policyLoading }}>
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
                ? 'bg-gray-900 text-white shadow-md'
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
              const stepIndex = steps.findIndex((s) => s.id === step.id) + 1; // +1 because product selection is step 0
              const isActive = currentStepIndex === stepIndex;
              const hasInitialConfig = initialConfig && Object.keys(initialConfig).length > 0;
              const isAccessible = productType && (hasInitialConfig || stepIndex <= currentStepIndex);
              const isCompleted = hasInitialConfig ? !isActive : stepIndex < currentStepIndex;
              return (
                <button
                  key={step.id}
                  onClick={() => isAccessible && handleStepClick(stepIndex)}
                  disabled={!isAccessible}
                  className={`w-full text-left px-4 py-3 mb-1 rounded transition-colors ${
                    isActive
                      ? 'bg-gray-900 text-white shadow-md'
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
                  className="px-6 py-2 rounded-lg bg-gray-900 text-white transition-colors text-sm font-medium hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
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
    </ConfiguratorPolicyProvider>
  );
}

