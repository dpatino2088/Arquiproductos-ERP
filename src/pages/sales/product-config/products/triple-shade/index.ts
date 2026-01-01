/**
 * Triple Shade Product Module
 * Complete configuration flow for Triple Shade products
 */

import { ProductType, TripleShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const TRIPLE_SHADE_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'triple-shade') return false;
  const tripleConfig = config as TripleShadeConfig;
  switch (stepId) {
    case 'measurements':
      return !!(tripleConfig.width_mm && tripleConfig.height_mm);
    case 'variants':
      return !!(tripleConfig.frontFabric?.collectionId && tripleConfig.frontFabric?.variantId);
    case 'operating-system':
      // Only require drive_type (or operatingSystem for backward compatibility)
      return !!((tripleConfig as any).drive_type || tripleConfig.operatingSystem);
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

