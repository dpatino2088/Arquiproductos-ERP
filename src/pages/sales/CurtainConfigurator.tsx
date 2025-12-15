import { useState } from 'react';
import { X } from 'lucide-react';
import ProductStep from './curtain-config/ProductStep';
import HeadboxStep from './curtain-config/HeadboxStep';
import FilmStep from './curtain-config/FilmStep';
import GuidingStep from './curtain-config/GuidingStep';
import ChainStep from './curtain-config/ChainStep';
import GeometryStep from './curtain-config/GeometryStep';
import FixingStep from './curtain-config/FixingStep';
import AccessoriesStep from './curtain-config/AccessoriesStep';
import ReviewStep from './curtain-config/ReviewStep';

export type ConfigStep = 
  | 'product' 
  | 'headbox' 
  | 'film' 
  | 'guiding' 
  | 'chain' 
  | 'geometry' 
  | 'fixing' 
  | 'accessories' 
  | 'review';

export interface CurtainConfiguration {
  // Product
  productType?: string;
  position: number | string;
  
  // Headbox
  mountingCassette?: 'VSL' | 'VLO';
  width_mm?: number;
  height_mm?: number;
  headboxFront?: string;
  
  // Film
  filmType?: string;
  ralColor?: string;
  embossing?: string;
  pleating_mm?: number;
  operationSide?: 'left' | 'right';
  viewToOutside?: boolean;
  heatProtection?: boolean;
  glareProtection?: boolean;
  gValue?: string;
  
  // Guiding
  guidingProfile?: string;
  
  // Chain/Cord
  chainColor?: string;
  geometryType?: string;
  
  // Fixing
  fixingType?: string;
  
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
  { id: 'headbox', label: 'HEAD BOX' },
  { id: 'film', label: 'FILM' },
  { id: 'guiding', label: 'GUIDING' },
  { id: 'chain', label: 'CHAIN / CORD' },
  { id: 'geometry', label: 'GEOMETRY' },
  { id: 'fixing', label: 'FIXING' },
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

  const handleUpdate = (updates: Partial<CurtainConfiguration>) => {
    setConfig(prev => ({ ...prev, ...updates }));
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
      case 'headbox':
        return !!config.mountingCassette && !!config.width_mm && !!config.height_mm;
      default:
        return true;
    }
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 'product':
        return <ProductStep config={config} onUpdate={handleUpdate} />;
      case 'headbox':
        return <HeadboxStep config={config} onUpdate={handleUpdate} />;
      case 'film':
        return <FilmStep config={config} onUpdate={handleUpdate} />;
      case 'guiding':
        return <GuidingStep config={config} onUpdate={handleUpdate} />;
      case 'chain':
        return <ChainStep config={config} onUpdate={handleUpdate} />;
      case 'geometry':
        return <GeometryStep config={config} onUpdate={handleUpdate} />;
      case 'fixing':
        return <FixingStep config={config} onUpdate={handleUpdate} />;
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
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Close"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="space-y-1">
          {STEPS.map((step, index) => {
            const isActive = currentStep === step.id;
            const isCompleted = index < currentStepIndex;
            const isAccessible = index <= currentStepIndex;
            
            return (
              <button
                key={step.id}
                onClick={() => isAccessible && handleStepClick(step.id)}
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

