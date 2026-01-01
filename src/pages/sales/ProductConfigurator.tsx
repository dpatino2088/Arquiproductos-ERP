/**
 * Product Configurator
 * Main component that dispatches to product-specific configuration flows
 */

import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { ProductType, ProductConfig } from './product-config/types';
import { getProductSteps, canProceedToNext, getProductDefinition } from './product-config/product-registry';
import ProductStep from './curtain-config/ProductStep';

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

  // Get steps for selected product type
  const steps = productType ? getProductSteps(productType) : [];
  // currentStepIndex 0 = product selection, 1+ = product steps (steps[0], steps[1], etc.)
  const currentStep = productType && currentStepIndex > 0 ? steps[currentStepIndex - 1] : null;
  const productDefinition = productType ? getProductDefinition(productType) : null;

  // Handle product type selection
  const handleProductTypeSelect = (type: ProductType, productTypeId?: string) => {
    setProductType(type);
    
    // CRITICAL: When editing, don't reset config - just update productType and productTypeId
    setConfig(prev => {
      const hasExistingConfig = prev && Object.keys(prev).length > 1;
      
      // If we already have a config with the same product type (editing scenario)
      // preserve ALL existing values
      if (hasExistingConfig && prev.productType === type) {
        if (import.meta.env.DEV) {
          console.log('ProductConfigurator: Preserving existing config (editing)', {
            type,
            productTypeId,
            existingConfig: prev,
          });
        }
        return {
          ...prev,
          productType: type,
          ...(productTypeId ? { productTypeId } : {}),
        };
      }
      
      // New selection - reset config
      const baseConfig: Partial<ProductConfig> = { 
        productType: type, 
        position: prev.position || '',
        ...(productTypeId ? { productTypeId } : {}),
      };
      
      if (import.meta.env.DEV) {
        console.log('ProductConfigurator: New product type selected', {
          type,
          productTypeId,
          newConfig: baseConfig,
        });
      }
      
      return baseConfig;
    });
    
    setCurrentStepIndex(1); // Move to first step after product selection
  };

  // Handle step updates
  const handleUpdate = (updates: Partial<ProductConfig>) => {
    setConfig(prev => {
      // Merge updates while preserving critical fields (productType, productTypeId)
      const merged = { ...prev, ...updates };
      
      // CRITICAL: Always preserve productType and productTypeId
      if (prev.productType) {
        (merged as any).productType = prev.productType;
      }
      if ((prev as any).productTypeId) {
        (merged as any).productTypeId = (prev as any).productTypeId;
      }
      
      if (import.meta.env.DEV) {
        console.log('ProductConfigurator: handleUpdate', {
          updates,
          prevProductTypeId: (prev as any).productTypeId,
          mergedProductTypeId: (merged as any).productTypeId,
        });
      }
      
      return merged as Partial<ProductConfig>;
    });
  };

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

  // Complete configuration
  const handleComplete = async () => {
    if (!productType || !config.productType) {
      return;
    }

    setIsSubmitting(true);
    try {
      await onComplete(config as ProductConfig);
      onClose();
    } catch (error) {
      console.error('Error completing configuration:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Check if can proceed to next step
  const canProceed = (): boolean => {
    // For product selection step (index 0), just check if product type is selected
    if (currentStepIndex === 0) {
      return !!productType;
    }
    // For other steps, use validation
    if (!productType || !currentStep) return false;
    const result = canProceedToNext(currentStep.id, productType, config as ProductConfig);
    return !!result; // Ensure boolean return
  };

  // Render step content
  const renderStepContent = () => {
    if (!productType || currentStepIndex === 0) {
      // Show product selection
      return (
        <ProductStep 
          config={config as any} 
          onUpdate={(updates) => {
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
              setConfig(prev => ({ ...prev, productType: undefined, productTypeId: undefined }));
              setCurrentStepIndex(0);
            }
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

