/**
 * Awning Product Module
 * Complete configuration flow for Awning products
 */

import { ProductType, AwningConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const AWNING_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'awning') return false;
  const awningConfig = config as AwningConfig;
  switch (stepId) {
    case 'measurements':
      return !!(awningConfig.width_mm && awningConfig.height_mm);
    case 'variants':
      return !!(awningConfig.fabric?.collectionId && awningConfig.fabric?.variantId);
    case 'operating-system':
      // Only require drive_type (or operatingSystem for backward compatibility)
      return !!((awningConfig as any).drive_type || awningConfig.operatingSystem);
    default:
      return true;
  }
}

// Register Awning product
registerProduct({
  type: 'awning',
  name: 'Awning',
  steps: AWNING_STEPS,
  validateStep,
});

