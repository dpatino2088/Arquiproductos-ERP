import { useState } from 'react';
import ProductStep from './curtain-config/ProductStep';
import MeasurementsStep from './curtain-config/MeasurementsStep';
import VariantsStep from './curtain-config/VariantsStep';
import OperatingSystemStep from './curtain-config/OperatingSystemStep';
import AccessoriesStep from './curtain-config/AccessoriesStep';
import ReviewStep from './curtain-config/ReviewStep';
import { ProductConfig } from './product-config/types';

export type ConfigStep = 
  | 'product' 
  | 'measurements' 
  | 'variants' 
  | 'operating-system' 
  | 'accessories' 
  | 'review';

export interface CurtainConfiguration {
  // Product
  productType?: string;
  
  // Measurements
  area?: string;
  position: number | string;
  quantity?: number;
  
  // Measurements
  width_mm?: number;
  height_mm?: number;
  fabricDrop?: 'normal' | 'inverted';
  installationType?: 'inside' | 'outside';
  installationLocation?: 'ceiling' | 'wall';
  // Legacy fields for backward compatibility
  mountingCassette?: 'VSL' | 'VLO';
  headboxFront?: string;
  
  // Film (Variants)
  variantManufacturer?: 'coulisse' | 'vertilux';
  filmType?: string;
  ralColor?: string;
  embossing?: string;
  pleating_mm?: number;
  operationSide?: 'left' | 'right';
  viewToOutside?: boolean;
  heatProtection?: boolean;
  glareProtection?: boolean;
  gValue?: string;
  
  // Operating System
  operatingSystem?: 'manual' | 'motorized';
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  operatingSystemSide?: 'left' | 'right';
  // Manual specific fields
  clutchSize?: 'S' | 'M' | 'L';
  operatingSystemColor?: 'white' | 'black';
  chainColor?: 'white' | 'black';
  operatingSystemHeight?: 'standard' | 'custom';
  tubeSize?: 'standard' | '42mm' | '65mm' | '80mm';
  
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

interface CurtainConfiguratorProps {
  quoteId: string;
  onComplete: (config: CurtainConfiguration) => Promise<void>;
  onClose: () => void;
}

const STEPS: { id: ConfigStep; label: string }[] = [
  { id: 'product', label: 'PRODUCT' },
  { id: 'measurements', label: 'MEASUREMENTS' },
  { id: 'variants', label: 'VARIANTS' },
  { id: 'operating-system', label: 'OPERATING SYSTEM' },
  { id: 'accessories', label: 'ACCESSORIES' },
  { id: 'review', label: 'QUOTE' },
];

export default function CurtainConfigurator({ quoteId, onComplete, onClose }: CurtainConfiguratorProps) {
  const [currentStep, setCurrentStep] = useState<ConfigStep>('product');
  const [config, setConfig] = useState<CurtainConfiguration>({
    position: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const currentStepIndex = STEPS.findIndex(s => s.id === currentStep);
  const canGoNext = currentStepIndex < STEPS.length - 1;
  const canGoBack = currentStepIndex > 0;

  const handleNext = () => {
    if (canGoNext) {
      // If productType is 'accessories' and we're on product step, jump directly to accessories
      if (config.productType === 'accessories' && currentStep === 'product') {
        setCurrentStep('accessories');
        return;
      }
      
      // Skip intermediate steps if productType is 'accessories'
      if (config.productType === 'accessories') {
        let nextIndex = currentStepIndex + 1;
        while (nextIndex < STEPS.length) {
          const nextStep = STEPS[nextIndex];
          if (nextStep && (nextStep.id === 'accessories' || nextStep.id === 'review')) {
            setCurrentStep(nextStep.id);
            return;
          }
          nextIndex++;
        }
      }
      
      const nextIndex = currentStepIndex + 1;
      const nextStep = STEPS[nextIndex];
      if (nextStep) {
        setCurrentStep(nextStep.id);
      }
    }
  };

  const handleBack = () => {
    if (canGoBack) {
      const prevIndex = currentStepIndex - 1;
      const prevStep = STEPS[prevIndex];
      if (prevStep) {
        setCurrentStep(prevStep.id);
      }
    }
  };

  const handleStepClick = (stepId: ConfigStep) => {
    setCurrentStep(stepId);
  };

  const handleUpdate = (updates: Partial<ProductConfig | CurtainConfiguration>) => {
    const newConfig = { ...config, ...updates } as CurtainConfiguration;
    setConfig(newConfig);
    
    // If productType is set to 'accessories', jump directly to accessories step
    if (updates.productType === 'accessories') {
      setCurrentStep('accessories');
    }
  };

  const handleComplete = async () => {
    setIsSubmitting(true);
    try {
      await onComplete(config);
      onClose();
    } catch (error) {
      console.error('Error completing configuration:', error);
      // Error handling is done in parent component
    } finally {
      setIsSubmitting(false);
    }
  };

  const canProceedToNext = () => {
    switch (currentStep) {
      case 'product':
        return !!config.productType;
      case 'measurements':
        // Skip measurements validation if productType is 'accessories'
        if (config.productType === 'accessories') return true;
        return !!config.width_mm && !!config.height_mm;
      default:
        return true;
    }
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 'product':
        return <ProductStep config={config} onUpdate={handleUpdate} />;
      case 'measurements':
        // If productType is 'accessories', skip measurements and show message
        if (config.productType === 'accessories') {
          return (
            <div className="max-w-4xl mx-auto">
              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <p className="text-sm text-gray-600">
                  Measurements are not required for accessories. Please proceed to the Accessories step.
                </p>
              </div>
            </div>
          );
        }
        return <MeasurementsStep config={config} onUpdate={handleUpdate} />;
      case 'variants':
        // If productType is 'accessories', skip variants and show message
        if (config.productType === 'accessories') {
          return (
            <div className="max-w-4xl mx-auto">
              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <p className="text-sm text-gray-600">
                  Variants are not required for accessories. Please proceed to the Accessories step.
                </p>
              </div>
            </div>
          );
        }
        return <VariantsStep config={config} onUpdate={handleUpdate} />;
      case 'operating-system':
        // If productType is 'accessories', skip operating system and show message
        if (config.productType === 'accessories') {
          return (
            <div className="max-w-4xl mx-auto">
              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <p className="text-sm text-gray-600">
                  Operating system is not required for accessories. Please proceed to the Accessories step.
                </p>
              </div>
            </div>
          );
        }
        return <OperatingSystemStep config={config} onUpdate={handleUpdate} />;
      case 'accessories':
        return <AccessoriesStep config={config} onUpdate={handleUpdate} />;
      case 'review':
        return <ReviewStep config={config} onUpdate={handleUpdate} />;
      default:
        return null;
    }
  };

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Left Navigation Sidebar */}
      <div className="w-64 bg-white border-r border-gray-200 p-4 overflow-y-auto">
        <div className="mb-4">
          <h2 className="text-lg font-semibold text-gray-900 mb-2">Configuration Steps</h2>
        </div>
        <div className="space-y-1">
          {STEPS.map((step, index) => {
            const isActive = currentStep === step.id;
            const isCompleted = index < currentStepIndex;
            // For accessories product type, skip intermediate steps
            const isSkipped = config.productType === 'accessories' && 
                            (step.id === 'measurements' || step.id === 'variants' || step.id === 'operating-system');
            const isAccessible = index <= currentStepIndex || (config.productType === 'accessories' && step.id === 'accessories');
            
            return (
              <button
                key={step.id}
                onClick={() => {
                  if (isSkipped && config.productType === 'accessories') {
                    // If clicking on a skipped step, jump to accessories
                    handleStepClick('accessories');
                  } else if (isAccessible) {
                    handleStepClick(step.id);
                  }
                }}
                disabled={!isAccessible && !isSkipped}
                className={`w-full text-left px-4 py-3 mb-1 rounded transition-colors ${
                  isActive
                    ? 'bg-primary text-white shadow-md'
                    : isSkipped
                    ? 'bg-gray-50 text-gray-400 line-through cursor-pointer hover:bg-gray-100'
                    : isCompleted
                    ? 'bg-green-50 text-green-700 hover:bg-green-100'
                    : isAccessible
                    ? 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                    : 'bg-gray-50 text-gray-400 cursor-not-allowed'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">{step.label}</span>
                  {isCompleted && !isActive && !isSkipped && (
                    <span className="text-green-600">✓</span>
                  )}
                  {isSkipped && (
                    <span className="text-gray-400 text-xs">Skip</span>
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
            {STEPS[currentStepIndex]?.label || 'Configuration'}
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            Step {currentStepIndex + 1} of {STEPS.length}
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
              disabled={!canGoBack || isSubmitting}
              className="px-4 py-2 border border-gray-300 rounded-lg bg-white text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
            >
              Back
            </button>
            
            <div className="flex items-center gap-2">
              {currentStep !== 'review' ? (
                <button
                  onClick={handleNext}
                  disabled={isSubmitting}
                  className="px-6 py-2 rounded-lg text-white transition-colors text-sm font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  Next
                </button>
              ) : (
                <button
                  onClick={handleComplete}
                  disabled={isSubmitting}
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

