/**
 * Product Configurator
 * Main component that dispatches to product-specific configuration flows
 */

import { useState, useEffect, useLayoutEffect, useMemo, useCallback, useRef } from 'react';
import { X } from 'lucide-react';
import { ProductType, ProductConfig } from './product-config/types';
import { getProductSteps, canProceedToNext, getProductDefinition } from './product-config/product-registry';
import ProductStep from './curtain-config/ProductStep';
import { useBOMTemplateQuestions } from '../../hooks/useBOMTemplateQuestions';
import { useBOMTemplates } from '../../hooks/useBOMTemplates';
import { UnifiedProductConfig, normalizeConfig } from './product-config/config-contract';
import ConfigDebugPanel from './curtain-config/_debug/ConfigDebugPanel';
import { useUIStore } from '../../stores/ui-store';

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
  // CRITICAL: Initialize with initialConfig values if editing
  const [productType, setProductType] = useState<ProductType | null>(initialConfig?.productType || null);
  const [currentStepIndex, setCurrentStepIndex] = useState(initialConfig?.productType ? 0 : 0); // Start at 0 to show selected product
  const [config, setConfig] = useState<Partial<ProductConfig>>(initialConfig || { position: '' });
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  // ✅ SOLUCIÓN DEFINITIVA: Ref para evitar loops en auto-commit
  const autoCommittedRef = useRef<string | null>(null);

  // CRITICAL: Update state when initialConfig changes (e.g., when loading config for editing)
  useEffect(() => {
    if (initialConfig && Object.keys(initialConfig).length > 0) {
      // When editing, completely replace config with initialConfig
      // This preserves ALL fields: productType, productTypeId, collectionName, variantName, etc.
      setConfig(initialConfig);
      
      // Update productType if provided in initialConfig
      if (initialConfig.productType) {
        setProductType(initialConfig.productType);
        // Start at step 0 (PRODUCT) to show the selected product
        // User can see what's selected and navigate through steps
        setCurrentStepIndex(0);
      }
      
      if (import.meta.env.DEV) {
        console.log('ProductConfigurator: initialConfig loaded for editing', {
          productType: initialConfig.productType,
          productTypeId: (initialConfig as any).productTypeId,
          hasArea: !!initialConfig.area,
          hasPosition: !!initialConfig.position,
          accessoriesCount: (initialConfig as any).accessories?.length || 0,
          hasCollection: !!(initialConfig as any).collectionName,
          variantName: (initialConfig as any).variantName,
          collectionName: (initialConfig as any).collectionName,
          width_mm: initialConfig.width_mm,
          height_mm: initialConfig.height_mm,
          fabric_catalog_item_id: (initialConfig as any).fabric_catalog_item_id,
          variantId: (initialConfig as any).variantId,
          drive_type: (initialConfig as any).drive_type,
          hardware_color: (initialConfig as any).hardware_color,
          cassette: (initialConfig as any).cassette,
          side_channel: (initialConfig as any).side_channel,
        });
      }
    } else if (initialConfig === undefined) {
      // If initialConfig is cleared (e.g., adding new line), reset to defaults
      setProductType(null);
      setCurrentStepIndex(0);
      setConfig({ position: '' });
      
      if (import.meta.env.DEV) {
        console.log('ProductConfigurator: initialConfig cleared - resetting to defaults');
      }
    }
  }, [initialConfig]);

  // FASE 2: Get product_type_id to load templates
  const productTypeIdForTemplates = (config as any).product_type_id || (config as any).productTypeId;
  
  // FASE 2: Load BOM Templates
  const { templates: bomTemplatesForDebug, loading: templatesLoading } = useBOMTemplates(productTypeIdForTemplates || undefined);
  
  // ✅ SOLUCIÓN DEFINITIVA: effectiveBomTemplateId (FUENTE DE VERDAD)
  // Derivar el bom_template_id efectivo - no depende de timing ni de useEffect
  const effectiveBomTemplateId = useMemo(() => {
    const current = (config as any)?.bom_template_id ?? null;
    if (current) return current;

    // Si no hay uno en config pero hay exactamente 1 template disponible, usarlo
    if (!templatesLoading && bomTemplatesForDebug?.length === 1) {
      return bomTemplatesForDebug[0].id;
    }

    return null;
  }, [config, templatesLoading, bomTemplatesForDebug]);

  // FASE 2: Use useBOMTemplateQuestions to determine which steps to show
  // CRITICAL: Usar effectiveBomTemplateId, no config.bom_template_id
  const questions = useBOMTemplateQuestions(effectiveBomTemplateId);
  
  // FASE 2: Build steps array dynamically based on BOMTemplate questions
  // If bom_template_id is not set, fall back to legacy product-registry steps
  // CRITICAL: Usar effectiveBomTemplateId
  const steps = useMemo(() => {
    if (!effectiveBomTemplateId || !questions) {
      // Fallback to legacy steps if no BOM template selected
      return productType ? getProductSteps(productType) : [];
    }
    
    // Build steps dynamically based on questions
    const dynamicSteps: Array<{ id: string; label: string; component: any }> = [];
    
    // Always include measurements step
    dynamicSteps.push({ id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent });
    
    // Variants step (if required)
    if (questions.requiredSteps.variants) {
      dynamicSteps.push({ id: 'variants', label: 'VARIANTS', component: VariantsStepComponent });
    }
    
    // Hardware step (if required)
    if (questions.requiredSteps.hardware) {
      dynamicSteps.push({ id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent });
    }
    
    // Operating System step (if required)
    if (questions.requiredSteps.operatingSystem) {
      dynamicSteps.push({ id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent });
    }
    
    // Accessories step (if required)
    if (questions.requiredSteps.accessories) {
      dynamicSteps.push({ id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent });
    }
    
    // Always include review step
    dynamicSteps.push({ id: 'review', label: 'QUOTE', component: ReviewStepComponent });
    
    // Debug log
    if (import.meta.env.DEV) {
      console.log('[ProductConfigurator] Dynamic steps built', { effectiveBomTemplateId, requiredSteps: questions.requiredSteps, stepsCount: dynamicSteps.length, stepIds: dynamicSteps.map(s => s.id) });
    }
    
    return dynamicSteps;
  }, [effectiveBomTemplateId, questions, productType]);
  
  // currentStepIndex 0 = product selection, 1+ = product steps (steps[0], steps[1], etc.)
  const currentStep = productType && currentStepIndex > 0 ? steps[currentStepIndex - 1] : null;
  const productDefinition = productType ? getProductDefinition(productType) : null;

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
        };
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
      
      return baseConfig;
    });
    
    setCurrentStepIndex(1); // Move to first step after product selection
  };

  // FASE 2: Handle step updates - preserve critical fields
  // CRITICAL: Use useCallback to stabilize the function reference
  const handleUpdate = useCallback((updates: Partial<ProductConfig>) => {
    console.log('[ProductConfigurator] 🔄 handleUpdate called', {
      updates,
      hasBomTemplateId: 'bom_template_id' in updates,
      bomTemplateId: (updates as any).bom_template_id,
    });
    
    setConfig(prev => {
      console.log('[ProductConfigurator] handleUpdate BEFORE merge', {
        prevBomTemplateId: (prev as any).bom_template_id,
        updatesBomTemplateId: (updates as any).bom_template_id,
        hasBomTemplateIdInUpdates: 'bom_template_id' in updates,
      });
      
      // Merge updates while preserving critical fields
      const merged = { ...prev, ...updates };
      
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
      
      console.log('[ProductConfigurator] handleUpdate AFTER merge', {
        prevBomTemplateId: (prev as any).bom_template_id,
        mergedBomTemplateId: (merged as any).bom_template_id,
        updatesBomTemplateId: (updates as any).bom_template_id,
      });
      
      return merged as Partial<ProductConfig>;
    });
  }, []); // Empty deps - function is stable

  // ✅ FIX A: Auto-select bom_template_id (único lugar, idempotente)
  // CRITICAL: Este effect debe estar DESPUÉS de handleUpdate para evitar "Cannot access before initialization"
  // IMPORTANT: Usar useLayoutEffect para ejecutar antes del paint (más determinístico)
  useLayoutEffect(() => {
    if (templatesLoading) return;
    if (!productTypeIdForTemplates) return;
    if (!bomTemplatesForDebug || bomTemplatesForDebug.length !== 1) return;

    const current = (config as any)?.bom_template_id ?? null;
    const uniqueId = bomTemplatesForDebug[0].id;

    // Si ya está seteado correctamente, no hagas nada
    if (current === uniqueId) {
      return;
    }

    // Evitar loops: solo una vez por productTypeId
    if (autoCommittedRef.current === productTypeIdForTemplates) {
      return;
    }

    autoCommittedRef.current = productTypeIdForTemplates;

    // Commit real al state usando setConfig directamente (para que debug panel lo vea y quede consistente)
    setConfig(prev => ({
      ...prev,
      bom_template_id: uniqueId,
    }));
  }, [templatesLoading, productTypeIdForTemplates, bomTemplatesForDebug, config]);

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

  const handleBack = () => {
    if (currentStepIndex > 1) {
      // Go back to previous product step
      setCurrentStepIndex(prev => prev - 1);
    } else if (currentStepIndex === 1) {
      // Go back to product selection (step 0)
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
      setCurrentStepIndex(index);
    } else {
      // When creating new, only allow navigation to completed steps
      if (index <= currentStepIndex) {
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
    const errors: string[] = [];
    
    // Core validations
    if (!normalizedConfig.product_type_id) {
      errors.push('Product Type is required');
    }
    // ✅ SOLUCIÓN DEFINITIVA: Validar usando effectiveBomTemplateId
    const finalBomTemplateId = normalizedConfig.bom_template_id || effectiveBomTemplateId;
    if (!finalBomTemplateId) {
      errors.push('BOM Template is required');
    }
    if (!normalizedConfig.width_m || normalizedConfig.width_m <= 0) {
      errors.push('Width is required');
    }
    if (!normalizedConfig.height_m || normalizedConfig.height_m <= 0) {
      errors.push('Height is required');
    }
    
    // FASE 3: Validate based on BOMTemplate questions
    // CRITICAL: Usar effectiveBomTemplateId para validación
    if (questions && effectiveBomTemplateId) {
      if (questions.requiredSteps.variants && !normalizedConfig.fabric_variant_id && !normalizedConfig.variantId) {
        errors.push('Fabric variant is required');
      }
      if (questions.requiredSteps.operatingSystem && !normalizedConfig.drive_type) {
        errors.push('Drive type is required');
      }
      if (questions.selectQuestions.hardware_color && !normalizedConfig.hardware_color) {
        errors.push('Hardware color is required');
      }
    }
    
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
      // FASE 4: Normalize config before passing to onComplete
      // ✅ SOLUCIÓN DEFINITIVA: Usar effectiveBomTemplateId en el config final
      const finalBomTemplateId = normalizedConfig.bom_template_id || effectiveBomTemplateId;
      
      if (!finalBomTemplateId) {
        throw new Error('BOM Template is required');
      }

      // Crear config con el bom_template_id efectivo
      const configWithEffectiveBom = {
        ...config,
        bom_template_id: finalBomTemplateId,
      };
      
      const finalNormalizedConfig = normalizeConfig(configWithEffectiveBom as Partial<UnifiedProductConfig>);
      
      if (import.meta.env.DEV) {
        console.log('[ProductConfigurator] Completing configuration', {
          product_type_id: finalNormalizedConfig.product_type_id,
          bom_template_id: finalNormalizedConfig.bom_template_id,
          effectiveBomTemplateId,
          finalBomTemplateId,
          width_m: finalNormalizedConfig.width_m,
          height_m: finalNormalizedConfig.height_m,
          normalizedConfig: finalNormalizedConfig,
        });
      }
      await onComplete(finalNormalizedConfig as ProductConfig);
      onClose();
    } catch (error) {
      console.error('Error completing configuration:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Check if can proceed to next step
  const canProceed = (): boolean => {
    // For product selection step (index 0), check if product type AND effectiveBomTemplateId are available
    // ✅ SOLUCIÓN DEFINITIVA: Usar effectiveBomTemplateId, no config.bom_template_id
    if (currentStepIndex === 0) {
      return !!productType && !!effectiveBomTemplateId;
    }
    // For other steps, use validation
    if (!productType || !currentStep) return false;
    
    // FASE 2: For dynamic steps, use custom validation
    // CRITICAL: Usar effectiveBomTemplateId
    if (effectiveBomTemplateId && questions) {
      // Custom validation for measurements step
      if (currentStep.id === 'measurements') {
        const width_m = (config as any).width_m || ((config as any).width_mm ? (config as any).width_mm / 1000 : null);
        const height_m = (config as any).height_m || ((config as any).height_mm ? (config as any).height_mm / 1000 : null);
        return !!(width_m && width_m > 0 && height_m && height_m > 0);
      }
      // For other steps, use legacy validation if available
      const result = canProceedToNext(currentStep.id, productType, config as ProductConfig);
      return !!result;
    }
    
    // Fallback to legacy validation
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
          onUpdate={productStepOnUpdate}
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
        <div className="bg-white border-b border-gray-200 px-6 py-4 relative">
          <button
            onClick={onClose}
            className="absolute top-4 right-6 p-1 hover:bg-gray-100 rounded transition-colors text-gray-500 hover:text-gray-700 z-10"
            title="Close"
          >
            <X className="w-5 h-5" />
          </button>
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
            <ConfigDebugPanel
              config={config as Partial<UnifiedProductConfig>}
              bomTemplateId={effectiveBomTemplateId} // ✅ Mostrar effectiveBomTemplateId en debug panel
              templatesLoading={templatesLoading}
              templatesCount={bomTemplatesForDebug.length}
              questions={questions}
              questionsLoading={false} // useBOMTemplateQuestions doesn't expose loading state yet
            />
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

