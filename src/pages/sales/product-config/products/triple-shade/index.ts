/**
 * Triple Shade Product Module
 * Complete configuration flow for Triple Shade products
 */

import { ProductType, TripleShadeConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const TRIPLE_SHADE_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: TripleShadeConfig): boolean {
  switch (stepId) {
    case 'measurements':
      return !!(config.width_mm && config.height_mm);
    case 'variants':
      return !!(config.frontFabric?.collectionId && config.frontFabric?.variantId);
    case 'operating-system':
      // Only require drive_type (or operatingSystem for backward compatibility)
      return !!((config as any).drive_type || config.operatingSystem);
    default:
      return true;
  }
}

// Register Triple Shade product
registerProduct({
  type: 'triple-shade',
  name: 'Triple Shade',
  steps: TRIPLE_SHADE_STEPS,
  validateStep,
});

