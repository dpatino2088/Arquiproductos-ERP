/**
 * Drapery Product Module
 * Complete configuration flow for Drapery (Wave/Ripple Fold) products
 */

import { ProductType, DraperyConfig, ProductConfig } from '../../types';
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

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'drapery') return false;
  const draperyConfig = config as DraperyConfig;
  switch (stepId) {
    case 'measurements':
      return !!(draperyConfig.width_mm && draperyConfig.height_mm);
    case 'variants':
      return !!(draperyConfig.fabric?.collectionId && draperyConfig.fabric?.variantId);
    case 'operating-system':
      // Drapery doesn't have operating system in the same way - it's optional
      return true;
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

