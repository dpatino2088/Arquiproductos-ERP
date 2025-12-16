/**
 * Roller Shade Product Module
 * Complete configuration flow for Roller Shade products
 */

import { ProductType, RollerShadeConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const ROLLER_SHADE_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: RollerShadeConfig): boolean {
  switch (stepId) {
    case 'measurements':
      return !!(config.width_mm && config.height_mm);
    case 'variants':
      return !!(config.collectionId && config.variantId);
    case 'operating-system':
      return !!(config.operatingSystem && config.operatingSystemManufacturer && config.operatingSystemVariant);
    default:
      return true;
  }
}

// Register Roller Shade product
registerProduct({
  type: 'roller-shade',
  name: 'Roller Shade',
  steps: ROLLER_SHADE_STEPS,
  validateStep,
});

