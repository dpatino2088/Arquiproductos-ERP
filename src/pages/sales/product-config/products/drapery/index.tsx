/**
 * Drapery Product Module
 * Complete configuration flow for Drapery (Wave/Ripple Fold) products
 */

import { ProductType, DraperyConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const DRAPERY_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: DraperyConfig): boolean {
  switch (stepId) {
    case 'measurements':
      return !!(config.width_mm && config.height_mm);
    case 'variants':
      return !!(config.fabric?.collectionId && config.fabric?.variantId);
    case 'operating-system':
      return !!(config.operatingSystem && config.operatingSystemManufacturer && config.operatingSystemVariant);
    default:
      return true;
  }
}

// Register Drapery product
registerProduct({
  type: 'drapery',
  name: 'Drapery Wave / Ripple Fold',
  steps: DRAPERY_STEPS,
  validateStep,
});

