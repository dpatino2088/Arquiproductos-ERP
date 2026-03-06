/**
 * Roller BOM Configurator
 * 
 * Wizard component for configuring Roller Shade BOM using fingerprint-based template matching.
 * 
 * Flow:
 * 1. ProductType - Select 'roller' product type
 * 2. Measurements - Width/Height (doesn't affect template, stored in metadata)
 * 3. Hardware - Headbox, System Size, Color, Bottom Bar, Side Channel (affects fingerprint)
 * 4. Operating System - Manual/Motor selection (affects fingerprint)
 * 
 * On completion: Generates BOMInstance and BOMInstanceLines
 */

import { useState, useCallback, useMemo } from 'react';
import { X, ChevronRight } from 'lucide-react';
import { RollerBOMConfigState, BomFingerprint } from '../../lib/bom/types';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useProductTypes, ProductType } from '../../hooks/useProductTypes';
import ProductTypeStep from './steps/ProductTypeStep';
import MeasurementsStep from './steps/MeasurementsStep';
import FabricStep from './steps/FabricStep';
import HardwareStep from './steps/HardwareStep';
import OperatingSystemStep from './steps/OperatingSystemStep';

interface RollerBOMConfiguratorProps {
  quoteId: string; // Quote ID (must exist before adding lines)
  onComplete: (config: RollerBOMConfigState & { fabric_catalog_item_id?: string; collection_name?: string; variant_name?: string; quantity?: number }) => Promise<void>;
  onClose: () => void;
  initialConfig?: Partial<RollerBOMConfigState>;
  editingLineId?: string | null;
}

const STEPS = [
  { id: 'product', label: 'Product Type' },
  { id: 'measurements', label: 'Measurements' },
  { id: 'fabric', label: 'Fabric Selection' },
  { id: 'hardware', label: 'Hardware' },
  { id: 'operating-system', label: 'Operating System' },
] as const;

type StepId = typeof STEPS[number]['id'];

export default function RollerBOMConfigurator({
  quoteId,
  onComplete,
  onClose,
  initialConfig,
  editingLineId,
}: RollerBOMConfiguratorProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { productTypes, loading: productTypesLoading } = useProductTypes();

  // Find roller product type
  const rollerProductType = useMemo(() => {
    return productTypes.find(pt => pt.code === 'roller_shade' || pt.code === 'roller');
  }, [productTypes]);

  // Initialize state
  const [currentStep, setCurrentStep] = useState<StepId>('product');
  const [configState, setConfigState] = useState<RollerBOMConfigState>({
    product_type_id: initialConfig?.product_type_id || rollerProductType?.id || null,
    product_type_code: 'roller',
    width_mm: initialConfig?.width_mm || null,
    height_mm: initialConfig?.height_mm || null,
    mount_type: initialConfig?.mount_type || null,
    location: initialConfig?.location || null,
    headbox_type: initialConfig?.headbox_type || 'none',
    system_size: initialConfig?.system_size || 'm',
    color: initialConfig?.color || 'white',
    bottom_bar_item_id: initialConfig?.bottom_bar_item_id || null,
    bottom_bar_wrapped: initialConfig?.bottom_bar_wrapped || false,
    side_channel_mode: initialConfig?.side_channel_mode || 'none',
    side_channel_item_id: initialConfig?.side_channel_item_id || null,
    bottom_channel_item_id: initialConfig?.bottom_channel_item_id || null,
    headbox_item_id: initialConfig?.headbox_item_id || null,
    operating_system: initialConfig?.operating_system || 'manual',
    motor_item_id: initialConfig?.motor_item_id || null,
    drive_item_id: initialConfig?.drive_item_id || null,
    tube_item_id: initialConfig?.tube_item_id || null,
    fabric_item_id: initialConfig?.fabric_item_id || null,
  });

  const [isGenerating, setIsGenerating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Update config state
  const handleUpdate = useCallback((updates: Partial<RollerBOMConfigState>) => {
    setConfigState(prev => {
      const next = { ...prev, ...updates };
      
      // Enforce rules
      // Rule: If headbox_type='cassette', system_size must be 'm'
      if (next.headbox_type === 'cassette' && next.system_size !== 'm') {
        next.system_size = 'm';
      }
      
      // Rule: If side_channel_mode includes bottom, it must be 'side_plus_bottom'
      // (This is already enforced by the enum, but we ensure consistency)
      if (next.side_channel_mode === 'side_plus_bottom') {
        // Ensure side_channel_item_id is set if bottom_channel is selected
        if (next.bottom_channel_item_id && !next.side_channel_item_id) {
          // This will be handled in HardwareStep
        }
      }
      
      return next;
    });
  }, []);

  // Build fingerprint from config state
  const fingerprint: BomFingerprint | null = useMemo(() => {
    if (!configState.product_type_code || !configState.headbox_type || !configState.system_size || 
        !configState.color || !configState.side_channel_mode || !configState.operating_system) {
      return null;
    }

    return {
      product_type: configState.product_type_code,
      headbox_type: configState.headbox_type,
      system_size: configState.system_size,
      color: configState.color,
      side_channel_mode: configState.side_channel_mode,
      operating_system: configState.operating_system,
    };
  }, [configState]);

  // Current step index
  const currentStepIndex = STEPS.findIndex(s => s.id === currentStep);
  const canGoNext = currentStepIndex < STEPS.length - 1;
  const canGoPrev = currentStepIndex > 0;

  // Navigation
  const handleNext = useCallback(() => {
    if (canGoNext) {
      const nextIndex = currentStepIndex + 1;
      const step = STEPS[nextIndex];
      if (step) {
        setCurrentStep(step.id);
        setError(null);
      }
    }
  }, [canGoNext, currentStepIndex]);

  const handlePrev = useCallback(() => {
    if (canGoPrev) {
      const prevIndex = currentStepIndex - 1;
      const step = STEPS[prevIndex];
      if (step) {
        setCurrentStep(step.id);
        setError(null);
      }
    }
  }, [canGoPrev, currentStepIndex]);

  // Complete and create QuoteLine + BOM
  const handleGenerate = useCallback(async () => {
    if (!activeOrganizationId || !rollerProductType?.id || !fingerprint) {
      setError('Missing required information to generate BOM');
      return;
    }

    setIsGenerating(true);
    setError(null);

    try {
      // Pass complete config back to QuoteNew for processing
      await onComplete(configState as any);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Error completing configuration';
      setError(errorMessage);
      console.error('[RollerBOMConfigurator] Error:', err);
    } finally {
      setIsGenerating(false);
    }
  }, [activeOrganizationId, rollerProductType, fingerprint, configState, onComplete]);

  // Validation
  const canGenerate = useMemo(() => {
    if (!fingerprint || !configState.product_type_id) {
      return false;
    }

    // Basic validation: measurements required
    if (!configState.width_mm || !configState.height_mm) {
      return false;
    }

    // Fabric required
    const fabric_catalog_item_id = (configState as any).fabric_catalog_item_id;
    if (!fabric_catalog_item_id) {
      return false;
    }

    // If cassette, headbox_item_id required
    if (configState.headbox_type === 'cassette' && !configState.headbox_item_id) {
      return false;
    }

    // If motor, motor_item_id required
    if (configState.operating_system === 'motor' && !configState.motor_item_id) {
      return false;
    }

    // If manual, drive_item_id required
    if (configState.operating_system === 'manual' && !configState.drive_item_id) {
      return false;
    }

    // If side_channel_mode is not 'none', side_channel_item_id required
    if (configState.side_channel_mode !== 'none' && !configState.side_channel_item_id) {
      return false;
    }

    // If side_channel_mode is 'side_plus_bottom', bottom_channel_item_id required
    if (configState.side_channel_mode === 'side_plus_bottom' && !configState.bottom_channel_item_id) {
      return false;
    }

    return true;
  }, [fingerprint, configState]);

  // Render current step
  const renderStep = () => {
    switch (currentStep) {
      case 'product':
        return (
          <ProductTypeStep
            config={configState}
            onUpdate={handleUpdate}
            productTypes={productTypes}
            loading={productTypesLoading}
          />
        );
      case 'measurements':
        return (
          <MeasurementsStep
            config={configState as any}
            onUpdate={handleUpdate}
          />
        );
      case 'fabric':
        return (
          <FabricStep
            config={configState as any}
            onUpdate={handleUpdate}
          />
        );
      case 'hardware':
        return (
          <HardwareStep
            config={configState}
            onUpdate={handleUpdate}
            organizationId={activeOrganizationId}
          />
        );
      case 'operating-system':
        return (
          <OperatingSystemStep
            config={configState}
            onUpdate={handleUpdate}
            organizationId={activeOrganizationId}
          />
        );
      default:
        return null;
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col overflow-hidden">
        {/* Top Progress Bar - Keep this */}
        <div className="px-6 py-4 border-b border-gray-200 bg-gray-50">
          <div className="flex items-center justify-between">
            {STEPS.map((step, index) => (
              <div key={step.id} className="flex items-center flex-1">
                <div className="flex items-center">
                  <div
                    className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                      index === currentStepIndex
                        ? 'bg-primary text-white'
                        : index < currentStepIndex
                        ? 'bg-green-500 text-white'
                        : 'bg-gray-200 text-gray-600'
                    }`}
                  >
                    {index + 1}
                  </div>
                  <span
                    className={`ml-2 text-sm font-medium ${
                      index === currentStepIndex ? 'text-primary' : 'text-gray-600'
                    }`}
                  >
                    {step.label}
                  </span>
                </div>
                {index < STEPS.length - 1 && (
                  <ChevronRight className="w-4 h-4 text-gray-400 mx-2" />
                )}
              </div>
            ))}
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
              {STEPS.find(s => s.id === currentStep)?.label || 'Configuration'}
            </h1>
            <p className="text-sm text-gray-500 mt-1">
              {currentStep === 'product' && 'Select a product type to begin'}
              {currentStep === 'measurements' && 'Enter the measurements for your product'}
              {currentStep === 'fabric' && 'Select fabric collection and variant'}
              {currentStep === 'hardware' && 'Configure hardware options'}
              {currentStep === 'operating-system' && 'Select operating system and components'}
            </p>
          </div>

          {/* Step Content */}
          <div className="flex-1 overflow-y-auto p-6">
            {error && (
              <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
                {error}
              </div>
            )}
            {renderStep()}
          </div>

          {/* Footer Navigation */}
          <div className="bg-white border-t border-gray-200 px-6 py-4">
            <div className="flex items-center justify-between">
              <button
                onClick={handlePrev}
                disabled={!canGoPrev || isGenerating}
                className="px-4 py-2 border border-gray-300 rounded-lg bg-white text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
              >
                Back
              </button>
              
              <div className="flex items-center gap-2">
                {currentStep === 'operating-system' ? (
                  <button
                    onClick={handleGenerate}
                    disabled={!canGenerate || isGenerating}
                    className="px-6 py-2 rounded-lg text-white transition-colors text-sm font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                    style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                  >
                    {isGenerating ? 'Generating...' : 'Add to Quote'}
                  </button>
                ) : (
                  <button
                    onClick={handleNext}
                    disabled={!canGoNext}
                    className="px-6 py-2 rounded-lg text-white transition-colors text-sm font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                    style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                  >
                    Next
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
